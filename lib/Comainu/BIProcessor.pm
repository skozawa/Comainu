# -*- mode: perl; coding: utf-8; -*-
# BIのみから成る長単位を処理する
package Comainu::BIProcessor;

use strict;
use warnings;
use utf8;
use Encode;
use Config;

use Comainu::Util qw(write_to_file);
use Comainu::ExternalTool;

use constant MODEL_TYPE_SVM  => 0;
use constant MODEL_TYPE_CRF  => 1;

my $DEFAULT_VALUES = {
    "debug"                => 0,
    "perl"                 => '/usr/bin/perl',
    "yamcha-dir"           => '/usr/local/bin',
    "comainu-temp"         => 'tmp/temp',
    "comp_file"            => 'suw2luw/Comp.txt',
    "pos_label_file"       => 'etc/pos_label',
    "cType_label_file"     => 'etc/cType_label',
    "cForm_label_file"     => 'etc/cForm_label',

    "model_type"           => MODEL_TYPE_SVM,
    "pos_label"            => {},
    "cType_label"          => {},
    "cForm_label"          => {},
    "verb_labels"          => [],
    "adj_labels"           => [],
    "aux_labels"           => [],
    "part_labels"          => [],
    "cType_verb_labels"    => [],
    "cType_adj_labels"     => [],
    "cType_all_labels"     => [],
    "cType_asterisk_label" => 'K1999',
    "cForm_asterisk_label" => 'K2999',
};

sub new {
    my ($class, %args) = @_;
    bless { %$DEFAULT_VALUES, %args }, $class;
}

## 学習用KCファイルから学習データを取得
sub create_train_data {
    my ($self, $kc_file, $svmin_file, $train_dir, $basename) = @_;

    my ($long_units, $BI_units) = $self->create_long_BI_units($kc_file, $svmin_file);
    $self->create_BI_data($long_units, $BI_units, {
        dir      => $train_dir,
        basename => $basename,
        is_test  => 0,
    });

    undef $long_units;
    undef $BI_units;
}


sub analyze {
    my ($self, $kc2_file, $lout_file, $args) = @_;

    my ($long_units, $BI_units) = $self->create_long_BI_units($kc2_file, $lout_file, 1);
    $self->create_BI_data($long_units, $BI_units, {
        dir      => $self->{"comainu-temp"},
        basename => $args->{test_name},
        is_test  => 1,
    });

    $self->test($args->{train_name}, $args->{test_name});

    $self->merge_data($args->{test_name}, $long_units, $BI_units);

    my $res = "";
    foreach (@$long_units) {
        if ( $$_[0] =~ /^\* \*/ ) {
            $res .= "EOS\n";
            next;
        }
        $res .= join("\n", @$_)."\n";
    }
    undef $long_units;
    undef $BI_units;

    unlink $kc2_file if !$self->{debug} && -f $kc2_file;

    return $res."\n";
}


# 学習時:   kc_file, svmin_file
# テスト時: kc2_file, lout_file
sub create_long_BI_units {
    my ($self, $kc_file, $labeled_file, $is_test) = @_;

    open(my $fh_kc, "<", $kc_file) or die "Cannot open '$kc_file'";
    open(my $fh_label, "<", $labeled_file) or die "Cannot open '$labeled_file'";

    my $long_units = [];
    my $BI_units = [];

    my $line = decode_utf8 <$fh_label>;
    $line =~ s/\r?\n//mg;

    while ( my $kc = <$fh_kc> ) {
        $kc = decode_utf8 $kc;
        $kc =~ s/\r?\n//mg;

        if ( $kc eq '' || $kc eq '*B' || $kc eq 'EOS' ) {
            if ( $is_test ) {
                # BI_unitsのindexがおかしくならないように, EOSの代わりに追加
                push @$long_units, [("* * * * * * * * * * * * * * * * * * * *")];
                # CRF++, Yamchaのため最後は空行が2つある
                # EOSが重複しないようにlastする
                last unless $line;
            } elsif ( $line eq "" || $line eq 'EOS' ) {
                $line = decode_utf8 <$fh_label>;
                $line =~ s/\r?\n//mg;
                # BI_unitsのindexがおかしくならないように, EOSの代わりに追加
                push @$long_units, [("* * * * * * * * * * * * * * * * * * * *")];
            }
            next;
        }

        my $short = $is_test ? $line : $kc;
        my $label = (split / /, $line)[$is_test ? 0 : -1];

        $line = decode_utf8 <$fh_label> // '';
        $line =~ s/\r?\n//mg;
        next unless $label && ($label eq 'B' || $label eq 'Ba');

        while ( $line =~ /^Ia? | Ia?$/ ) {
            $kc = decode_utf8 <$fh_kc>;
            $kc =~ s/\r?\n//mg;
            last if !$is_test && $kc =~ /^\*B|^EOS/;

            $short .= "\n" . ($is_test ? $line : $kc);
            $label .= " " . (split / /, $line)[$is_test ? 0 : -1];

            $line = decode_utf8 <$fh_label>;
            last unless $line;
            $line =~ s/\r?\n//mg;
        }
        next if $short eq "";

        push @$long_units, [ split /\n/, $short ];
        push @$BI_units, $#{$long_units} if $label !~ /[BI]a/;
    }

    return ($long_units, $BI_units);
}

sub create_BI_data {
    my ($self, $long_units, $BI_units, $args) = @_;

    $self->load_label;
    my $is_test = $args->{is_test} ? 1 : 0;

    my $pos_feature   = "";
    my $cType_feature = "";
    my $cForm_feature = "";

    my $label_text = "";
    my $comp = {};
    if ( $is_test ) {
        my %pos_label  = reverse %{$self->{pos_label}};
        # 助詞・助動詞の除去
        delete $pos_label{$_} for (@{$self->{aux_labels}}, @{$self->{part_labels}});
        $label_text = join " ", keys %pos_label;
        $comp = $self->load_comp_file;
    }

    foreach my $i ( @$BI_units ) {
        my $long_unit = $long_units->[$i];

        ## 長単位の先頭の短単位
        my @first = split / /, $long_unit->[0];
        my $long_lemma = $first[17 + $is_test];
        my $feature = $long_lemma;

        $feature .= $self->create_feature($long_units, $i, $is_test);

        # 長単位の品詞、活用型、活用形
        my $f_pos   = $first[13 + $is_test];
        my $f_cType = $first[14 + $is_test];
        my $f_cForm = $first[15 + $is_test];

        if ( $is_test ) {
            my $long_yomi = $first[16 + $is_test];
            $pos_feature .= $feature;
            $pos_feature .= " " . $label_text;
            if ( defined $comp->{$long_yomi . "_" . $long_lemma} ) {
                $pos_feature .= " " . $self->{pos_label}->{$comp->{$long_yomi . "_" . $long_lemma}};
            }
            $pos_feature .= "\n";
        } else {
            $pos_feature   .= join(" ", $feature, $self->{pos_label}->{$f_pos}) . "\n";
            $cType_feature .= join(" ", $feature, $self->{pos_label}->{$f_pos}, $self->{cType_label}->{$f_cType}) . "\n";
            $cForm_feature .= join(" ", $feature, $self->{pos_label}->{$f_pos}, $self->{cType_label}->{$f_cType}, $self->{cForm_label}->{$f_cForm}) . "\n";
        }
    }
    if ( $self->{model_type} == MODEL_TYPE_CRF ) {
        $pos_feature   =~ s/\n/\n\n/g;
        $cType_feature =~ s/\n/\n\n/g;
        $cForm_feature =~ s/\n/\n\n/g;
    }
    undef $comp;

    my $dir = $args->{dir};
    my $basename = $args->{basename};
    my $pos_dat = $dir . "/pos/" . $basename . ".BI_pos.dat";
    mkdir $dir . "/pos" unless -d $dir . "/pos";
    write_to_file($pos_dat, $pos_feature."\n");
    undef $pos_feature;

    my $cType_dat = $dir . "/cType/" . $basename . ".BI_cType.dat";
    mkdir $dir . "/cType" unless -d $dir . "/cType";
    write_to_file($cType_dat, $cType_feature."\n");
    undef $cType_feature;

    my $cForm_dat = $dir . "/cForm/" . $basename . ".BI_cForm.dat";
    mkdir $dir . "/cForm" unless -d $dir . "/cForm";
    write_to_file($cForm_dat, $cForm_feature."\n");
    undef $cForm_feature;
}

sub create_feature {
    my ($self, $long_units, $bi_index, $is_test) = @_;

    my $feature = '';
    if ( $bi_index <= 0 ) {
        $feature .= " *" x 52;
    } else {
        $feature .= $self->long2feature($long_units->[$bi_index - 1], $is_test);
    }
    $feature .= $self->long2feature($long_units->[$bi_index], $is_test);

    if ( $bi_index >= $#{$long_units} ) {
        $feature .= " *" x 52;
    } else {
        $feature .= $self->long2feature($long_units->[$bi_index + 1], $is_test);
    }

    return $feature;
}

sub long2feature {
    my ($self, $long_unit, $is_test) = @_;
    $is_test //= 0;

    my $feature = "";
    if ( $#{$long_unit} >= 1 ) {
        for my $i ( 0 .. 1 ) {
            $feature .= $self->short2feature($long_unit->[$i], $is_test);
        }
        for my $i ( 0 .. 1 ) {
            $feature .= $self->short2feature($long_unit->[$#{$long_unit}+$i-1], $is_test);
        }
    } else {
        $feature .= $self->short2feature($$long_unit[0], $is_test);
        $feature .= (" *" x 26) . $feature;
    }
    return $feature;
}

sub short2feature {
    my ($self, $short_unit, $is_test) = @_;
    $is_test //= 0;

    my $feature = "";
    my @short = split / /, $short_unit;

    ## 見出し、読み、語彙素
    $feature .= " " . $short[$_ + $is_test] for ( 0 .. 2 );

    ## 品詞
    $feature .= " " . $short[3 + $is_test];
    my @pos = split /\-/, $short[3 + $is_test];
    $feature .= " " . ($pos[$_+1] ? join("-", @pos[0..$_]) : '*') for ( 0 .. 2 );

    ## 活用型
    $feature .= " " . $short[4 + $is_test];
    my @cType = split /\-/, $short[4 + $is_test];
    $feature .= " " . ($cType[$_+1] ? join("-", @cType[0..$_]) : '*') for ( 0 .. 1 );

    ## 活用形
    $feature .= " " . $short[5 + $is_test];
    my @cForm = split /\-/, $short[5 + $is_test];
    $feature .= " " . ($cForm[$_+1] ? join("-", @cForm[0..$_]) : '*') for ( 0 .. 1 );

    undef @short;
    return $feature;
}


sub train {
    my ($self, $name, $model_dir) = @_;

    my $external_tool = Comainu::ExternalTool->new(%$self);
    my $makefile = $external_tool->create_yamcha_makefile($model_dir, $name);

    my $pos_dat   = $model_dir . "/pos/" . $name . ".BI_pos.dat";
    my $pos_model = $model_dir . "/pos/" . $name . ".BI_pos";
    my $com1 = sprintf("make -f \"%s\" PERL=\"%s\" MULTI_CLASS=2 FEATURE=\"F:0:0.. \" CORPUS=\"%s\" MODEL=\"%s\" train",
                       $makefile, $self->{perl}, $pos_dat, $pos_model);
    system($com1);

    my $cType_dat   = $model_dir . "/cType/" . $name . ".BI_cType.dat";
    my $cType_model = $model_dir . "/cType/" . $name . ".BI_cType";
    my $com2 = sprintf("make -f \"%s\" PERL=\"%s\" MULTI_CLASS=2 FEATURE=\"F:0:0.. \" CORPUS=\"%s\" MODEL=\"%s\" train",
                       $makefile, $self->{perl}, $cType_dat, $cType_model);
    system($com2);

    my $cForm_dat   = $model_dir . "/cForm/" . $name . ".BI_cForm.dat";
    my $cForm_model = $model_dir . "/cForm/" . $name . ".BI_cForm";
    my $com3 = sprintf("make -f \"%s\" PERL=\"%s\" MULTI_CLASS=2 FEATURE=\"F:0:0.. \" CORPUS=\"%s\" MODEL=\"%s\" train",
                      $makefile, $self->{perl}, $cForm_dat, $cForm_model);
    system($com3);
}

sub test {
    my ($self, $train_name, $test_name) = @_;

    my $cmd = $self->{"yamcha-dir"} . "/yamcha";
    $cmd .= ".exe" if $Config{osname} eq "MSWin32";
    $cmd = sprintf("\"%s\" -C", $cmd);

    my $tmp_dir = $self->{"comainu-temp"};
    my $model_dir = $self->{"comainu-svm-bip-model"};

    my $pos_dat   = $tmp_dir   . "/pos/" . $test_name  . ".BI_pos.dat";
    my $pos_out   = $tmp_dir   . "/pos/" . $test_name  . ".BI_pos.out";
    my $pos_model = $model_dir . "/pos/" . $train_name . ".BI_pos.model";
    my $com1 = sprintf("%s -m \"%s\" < \"%s\" > \"%s\"",
                       $cmd, $pos_model, $pos_dat, $pos_out);
    print STDERR "# $com1\n";
    system($com1);
    unlink $pos_dat if !$self->{debug} && -f $pos_dat;

    my $cType_dat   = $tmp_dir   . "/cType/" . $test_name  . ".BI_cType.dat";
    my $cType_out   = $tmp_dir   . "/cType/" . $test_name  . ".BI_cType.out";
    my $cType_model = $model_dir . "/cType/" . $train_name . ".BI_cType.model";
    $self->create_cType_dat($pos_out, $cType_dat);
    my $com2 = sprintf("%s -m \"%s\" < \"%s\" > \"%s\"",
                       $cmd, $cType_model, $cType_dat, $cType_out);
    print STDERR "# $com2\n";
    system($com2);
    unlink $cType_dat if !$self->{debug} && -f $cType_dat;

    my $cForm_dat   = $tmp_dir   . "/cForm/" . $test_name  . ".BI_cForm.dat";
    my $cForm_out   = $tmp_dir   . "/cForm/" . $test_name  . ".BI_cForm.out";
    my $cForm_model = $model_dir . "/cForm/" . $train_name . ".BI_cForm.model";
    $self->create_cForm_dat($cType_out, $cForm_dat);
    my $com3 = sprintf("%s -m \"%s\" < \"%s\" > \"%s\"",
                       $cmd, $cForm_model, $cForm_dat, $cForm_out);
    print STDERR "# $com3\n";
    system($com3);
    unlink $cForm_dat if !$self->{debug} && -f $cForm_dat;
}

sub create_cType_dat {
    my ($self, $out, $file) = @_;

    my $label_text = {
        verb => join(' ', @{$self->{cType_verb_labels}}),
        adj  => join(' ', @{$self->{cType_adj_labels}}),
        all  => join(' ', @{$self->{cType_all_labels}}),
    };

    my $buff = "";
    open(my $fh, $out) or die "Cannot open '$out'";
    binmode($fh);
    while ( my $line = <$fh> ) {
        $line = decode_utf8 $line;
        $line =~ s/\r?\n//g;
        next unless $line;

        my @items = split /\t/, $line;
        $buff .= join " ", @items;
        if ( grep { $items[-1] eq $_ } @{$self->{verb_labels}} ) {
            $buff .= " " . $label_text->{verb} . "\n";
        } elsif ( grep { $items[-1] eq $_ } @{$self->{adj_labels}} ) {
            $buff .= " " . $label_text->{adj} . "\n";
        } elsif ( grep { $items[-1] eq $_ } @{$self->{aux_labels}} ) {
            $buff .= " " . $label_text->{all} . "\n";
        } else {
            $buff .= " " . $self->{cType_asterisk_label} . "\n";
        }
    }
    close($fh);

    $buff =~ s/\n/\n\n/mg if $self->{model_type} == MODEL_TYPE_CRF;
    $buff .= "\n";
    write_to_file($file, $buff);
    undef $buff;
}

sub create_cForm_dat {
    my ($self, $out, $file) = @_;

    my %labels  = reverse %{$self->{cForm_label}};
    delete $labels{$self->{cForm_asterisk_label}};
    my $label_text = join " ", keys %labels;

    my $buff = "";
    open(my $fh, $out) or die "Cannot open '$file'";
    binmode($fh);
    while ( my $line = <$fh> ) {
        $line = decode_utf8 $line;
        $line =~ s/\r?\n//g;
        next unless $line;

        my @items = split /\t/, $line;
        $buff .= join(" ",@items);
        if ( grep { $items[$#items - 1] eq $_ } @{$self->{verb_labels}}, @{$self->{adj_labels}}, @{$self->{aux_labels}} ) {
            $buff .= " " . $label_text . "\n";
        } else {
            $buff .= " " . $self->{cForm_asterisk_label} . "\n";
        }
    }

    $buff =~ s/\n/\n\n/mg if $self->{model_type} == MODEL_TYPE_CRF;
    $buff .= "\n";
    write_to_file($file, $buff);
    undef $buff;
}


sub merge_data {
    my ($self, $test_name, $long_units, $BI_units) = @_;
    my $tmp_dir = $self->{"comainu-temp"};

    my $pos_file   = $tmp_dir . "/pos/"   . $test_name . ".BI_pos.out";
    my $cType_file = $tmp_dir . "/cType/" . $test_name . ".BI_cType.out";
    my $cForm_file = $tmp_dir . "/cForm/" . $test_name . ".BI_cForm.out";

    my @pos   = split / /, $self->read_from_out($pos_file);
    my @cType = split / /, $self->read_from_out($cType_file);
    my @cForm = split / /, $self->read_from_out($cForm_file);
    my %pos_label   = reverse %{$self->{pos_label}};
    my %cType_label = reverse %{$self->{cType_label}};
    my %cForm_label = reverse %{$self->{cForm_label}};

    for my $i ( 0 .. $#{$BI_units} ) {
        my $l_term = $long_units->[$BI_units->[$i]];
        my @first = split / /, $l_term->[0];
        $first[14] = $pos_label{$pos[$i]};

        if ( grep { $pos[$i] eq $_ } @{$self->{verb_labels}}, @{$self->{adj_labels}}, @{$self->{aux_labels}} ) {
            for my $j ( 0 .. $#{$l_term} ) {
                my @items = split(/ /, $l_term->[$#{$l_term}-$j]);
                $first[15] = $items[5];
                $first[16] = $items[6];
                last if $first[15] ne "*" && $first[16] ne "*";
            }
            if ( $first[15] eq "*" && $first[16] eq "*" ) {
                $first[15] = $cType_label{$cType[$i]};
                $first[16] = $cForm_label{$cForm[$i]};
            }
        }else{
            $first[15] = "*";
            $first[16] = "*";
        }
        $long_units->[$BI_units->[$i]]->[0] = join " ", @first;
    }
    undef @pos;
    undef @cType;
    undef @cForm;
    undef %pos_label;
    undef %cType_label;
    undef %cForm_label;

    unlink $pos_file   if !$self->{debug} && -f $pos_file;
    unlink $cType_file if !$self->{debug} && -f $cType_file;
    unlink $cForm_file if !$self->{debug} && -f $cForm_file;
}


sub read_from_out {
    my ($self, $file) = @_;
    my $data = "";
    open(my $fh, $file) or die "Cannot open '$file'";
    binmode($fh);
    while ( my $line = <$fh> ) {
        $line = decode_utf8 $line;
        $line =~ s/\r?\n//g;
        next if $line eq "" || $line eq "EOS";
        my @items = split /\t/, $line;
        $data .= $items[$#items]." ";
    }
    close($fh);
    return $data;
}

sub load_comp_file {
    my ($self) = @_;

    my $comp = {};
    open(my $fh, $self->{comp_file}) or die "Cannot open '" . $self->{comp_file} . "'";
    binmode($fh);
    while ( my $line = <$fh> ) {
        $line = decode_utf8 $line;
        $line =~ s/\r?\n//g;
        next unless $line;

        my @items = split /\t/, $line;
        next if $items[0] !~ /助詞|助動詞/;
        $comp->{join("_",@items[1..2])} = $items[0];
    }
    close($fh);

    return $comp;
}

sub load_label {
    my $self = shift;

    $self->{pos_label}   = $self->load_label_file($self->{pos_label_file}, 'pos');
    $self->{cType_label} = $self->load_label_file($self->{cType_label_file}, 'cType');
    $self->{cForm_label} = $self->load_label_file($self->{cForm_label_file}, 'cForm');
}

sub load_label_file {
    my ($self, $file, $type) = @_;

    my $labels = {};
    open(my $fh, $file) or die "Cannot open '$file'";
    binmode $fh;
    while ( my $line = <$fh> ) {
        $line = decode_utf8 $line;
        $line =~ s/\r?\n//g;
        next unless $line;
        next if $line =~ /^\#/;

        my @items = split /\t/, $line;
        $labels->{$items[0]} = $items[1];

        if ( $type eq 'pos' ) {
            push @{$self->{verb_labels}}, $items[1] if $items[0] =~ /^動詞/;
            push @{$self->{adj_labels}},  $items[1] if $items[0] =~ /^形容詞/;
            push @{$self->{aux_labels}},  $items[1] if $items[0] =~ /^助動詞/;
            push @{$self->{part_labels}}, $items[1] if $items[0] =~ /^助詞/;
        } elsif ( $type eq 'cType' ) {
            if ( $items[0] eq '*' ) {
                $self->{cType_asterisk_label} = $items[1];
                next;
            }
            push @{$self->{cType_all_labels}}, $items[1];
            push @{$self->{'cType_' . $items[2] . '_labels'}}, $items[1] if $items[2];
        } elsif ( $type eq 'cForm' ) {
            $self->{cForm_asterisk_label} = $items[1] if $items[0] eq '*';
        }
    }
    close($fh);

    return $labels;
}

1;
#################### END OF FILE ####################
