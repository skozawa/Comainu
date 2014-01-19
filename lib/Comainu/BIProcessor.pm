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
    "model_type"   => MODEL_TYPE_SVM,
    "h_label"      => {},
    "k1_label"     => {},
    "k2_label"     => {},
    "debug"        => 0,
    "perl"         => '/usr/bin/perl',
    "yamcha-dir"   => '/usr/local/bin',
    "comainu-temp" => 'tmp/temp',
    "comp_file"    => 'suw2luw/Comp.txt',
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

    $self->create_label;
    my $is_test = $args->{is_test} ? 1 : 0;

    my $pos_feature   = "";
    my $cType_feature = "";
    my $cForm_feature = "";

    my $label_text = "";
    my $comp = {};
    if ( $is_test ) {
        my %h_label  = reverse %{$self->{h_label}};
        # 助詞・助動詞の除去
        delete $h_label{$_} for (qw(H100 H110 H111 H112 H113 H114 H115));
        $label_text = join " ", keys %h_label;
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
                $pos_feature .= " " . $self->{h_label}->{$comp->{$long_yomi . "_" . $long_lemma}};
            }
            $pos_feature .= "\n";
        } else {
            $pos_feature   .= join(" ", $feature, $self->{h_label}->{$f_pos}) . "\n";
            $cType_feature .= join(" ", $feature, $self->{h_label}->{$f_pos}, $self->{k1_label}->{$f_cType}) . "\n";
            $cForm_feature .= join(" ", $feature, $self->{h_label}->{$f_pos}, $self->{k1_label}->{$f_cType}, $self->{k2_label}->{$f_cForm}) . "\n";
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

    my $labels = { verb => [], adj => [], aux => [] };
    for ( keys %{$self->{k1_label}} ) {
        my $label = $self->{k1_label}->{$_};
        push @{$labels->{verb}}, $label if $label =~ /^K10|^K11[12]|^K120/;
        push @{$labels->{adj}}, $label  if $label =~ /^K11[34]/;
        push @{$labels->{aux}}, $label  if $label =~ /^K11[56789]/;
    }

    my $label_text = {
        verb => join(" ", @{$labels->{verb}}),
        adj  => join(" ", @{$labels->{adj}}),
        aux  => join(" ", @{$labels->{aux}}),
    };
    undef $labels;

    my $buff = "";
    open(my $fh, $out) or die "Cannot open '$out'";
    binmode($fh);
    while ( my $line = <$fh> ) {
        $line = decode_utf8 $line;
        $line =~ s/\r?\n//g;
        $line =~ s/^EOS//g if $self->{model_type} == 2;
        next unless $line;

        my @items = split /\t/, $line;
        $buff .= join " ", @items;
        if ( $items[$#items] eq "H080" || $items[$#items] eq "H081" ) {
            $buff .= " " . $label_text->{verb} . "\n";
        } elsif ( $items[$#items] eq "H090" || $items[$#items] eq "H091" ) {
            $buff .= " " . $label_text->{adj} . "\n";
        } elsif ( $items[$#items] eq "H100" ) {
            $buff .= " " . $label_text->{verb} .
                     " " . $label_text->{adj} .
                     " " . $label_text->{aux} . "\n";
        } else {
            $buff .= " K1999\n";
        }
    }
    close($fh);

    if ( $self->{model_type} == MODEL_TYPE_CRF ) {
        $buff =~ s/\n/\n\n/mg;
    }
    $buff .= "\n";
    write_to_file($file, $buff);
    undef $buff;
}

sub create_cForm_dat {
    my ($self, $out, $file) = @_;

    my %labels  = reverse %{$self->{k2_label}};
    delete $labels{K2999};
    my $label_text = join(" ", keys %labels);

    my $buff = "";
    open(my $fh, $out) or die "Cannot open '$file'";
    binmode($fh);
    while ( my $line = <$fh> ) {
        $line = decode_utf8 $line;
        $line =~ s/\r?\n//g;
        $line =~ s/^EOS//g if $self->{model_type} == 2;

        my @items = split(/\t/, $line);
        $buff .= join(" ",@items);
        if ( $items[$#items - 1] ~~ ["H080", "H081", "H090", "H091", "H100"] ) {
            $buff .= " " . $label_text . "\n";
        } else {
            $buff .= " K2999\n";
        }
    }
    if ( $self->{model_type} == MODEL_TYPE_CRF ) {
        $buff =~ s/\n/\n\n/mg;
    }
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
    my %h_label  = reverse %{$self->{h_label}};
    my %k1_label = reverse %{$self->{k1_label}};
    my %k2_label = reverse %{$self->{k2_label}};

    for my $i ( 0 .. $#{$BI_units} ) {
        my $l_term = $long_units->[$BI_units->[$i]];
        my @first = split / /, $l_term->[0];
        $first[14] = $h_label{$pos[$i]};
        if ( $pos[$i] ~~ ["H080", "H081", "H090", "H091", "H100"] ) {
            for my $j ( 0 .. $#{$l_term} ) {
                my @items = split(/ /, $l_term->[$#{$l_term}-$j]);
                $first[15] = $items[5];
                $first[16] = $items[6];
                last if $first[15] ne "*" && $first[16] ne "*";
            }
            if ( $first[15] eq "*" && $first[16] eq "*" ) {
                $first[15] = $k1_label{$cType[$i]};
                $first[16] = $k2_label{$cForm[$i]};
            }
        }else{
            $first[15] = "*";
            $first[16] = "*";
        }
        $$long_units[$$BI_units[$i]]->[0] = join " ", @first;
    }
    undef @pos;
    undef @cType;
    undef @cForm;
    undef %h_label;
    undef %k1_label;
    undef %k2_label;

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
        my @items = split(/\t/, $line);
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

        my @items = split(/\t/, $line);
        next if $items[0] !~ /助詞|助動詞/;
        $comp->{join("_",@items[1..2])} = $items[0];
    }
    close($fh);

    return $comp;
}

sub create_label {
    my $self = shift;

    $self->{h_label} = {
        "名詞-普通名詞-一般" => "H000",
        # "名詞-普通名詞-サ変可能" => "H001",
        # "名詞-普通名詞-形状詞可能" => "H002",
        # "名詞-普通名詞-サ変形状詞可能" => "H003",
        # "名詞-普通名詞-副詞可能" => "H004",
        "名詞-固有名詞-一般" => "H005",
        "名詞-固有名詞-人名-一般" => "H006",
        "名詞-固有名詞-人名-姓" => "H007",
        "名詞-固有名詞-人名-名" => "H008",
        "名詞-固有名詞-組織名" => "H009",
        "名詞-固有名詞-地名-一般" => "H010",
        "名詞-固有名詞-地名-国" => "H011",
        "名詞-数詞" => "H012",
        "名詞-助動詞語幹" => "H013",
        "代名詞" => "H020",
        "形状詞-一般" => "H030",
        "形状詞-タリ" => "H031",
        "形状詞-助動詞語幹" => "H032",
        "連体詞" => "H040",
        "副詞" => "H050",
        "接続詞" => "H060",
        "感動詞-一般" => "H070",
        "感動詞-フィラー" => "H071",
        "動詞-一般" => "H080",
        # "動詞-非自立可能" => "H081",
        "形容詞-一般" => "H090",
        # "形容詞-非自立可能" => "H091",
        "助動詞" => "H100",
        "助詞-格助詞" => "H110",
        "助詞-副助詞" => "H111",
        "助詞-係助詞" => "H112",
        "助詞-接続助詞" => "H113",
        "助詞-終助詞" => "H114",
        "助詞-準体助詞" => "H115",
        "接頭辞" => "H120",
        "接尾辞-名詞的-一般" => "H130",
        # "接尾辞-名詞的-サ変可能" => "H131",
        # "接尾辞-名詞的-形状詞可能" => "H132",
        # "接尾辞-名詞的-サ変形状詞可能" => "H133",
        # "接尾辞-名詞的-副詞可能" => "H134",
        "接尾辞-名詞的-助数詞" => "H135",
        "接尾辞-形状詞的" => "H136",
        "接尾辞-動詞的" => "H137",
        "接尾辞-形容詞的" => "H138",
        "記号-一般" => "H140",
        "記号-文字" => "H141",
        "補助記号-一般" => "H150",
        "補助記号-句点" => "H151",
        "補助記号-読点" => "H152",
        "補助記号-括弧開" => "H153",
        "補助記号-括弧閉" => "H154",
        "補助記号-ＡＡ-顔文字" => "H155",
        "補助記号-ＡＡ-一般" => "H156",
        "空白" => "H160",
        "英単語" => "H170",
        "URL" => "H180",
        "言いよどみ" => "H190",
        "新規未知語" => "H200",
        "web誤脱" => "H210",
        "ローマ字文" => "H220",
        "当て字・誤変換" => "H230",
        "漢文" => "H240",
    };

    $self->{k1_label} = {
        "五段-ガ行" => "K1000",
        "五段-カ行-一般" => "K1001",
        "五段-カ行-イク" => "K1002",
        "五段-カ行-ユク" => "K1003",
        "五段-サ行" => "K1004",
        "五段-タ行" => "K1005",
        "五段-ナ行" => "K1006",
        "五段-バ行" => "K1007",
        "五段-マ行" => "K1008",
        "五段-ラ行" => "K1009",
        # "五段-ラ行-一般" => "K1009",
        # "五段-ラ行-アル" => "K1010",
        "五段-ワア行-一般" => "K1011",
        "五段-ワア行-イウ" => "K1012",
        "五段-ワア行-ャウ+一般" => "K1013",
        "五段-カ行" => "K1014",
        "五段-ワア行" => "K1015",
        "上一段-ア行" => "K1020",
        "上一段-カ行" => "K1021",
        "上一段-ガ行" => "K1022",
        "上一段-ザ行" => "K1023",
        "上一段-タ行" => "K1024",
        "上一段-ナ行" => "K1025",
        "上一段-ハ行" => "K1026",
        "上一段-バ行" => "K1027",
        "上一段-マ行" => "K1028",
        "上一段-ラ行" => "K1029",
        "下一段-ア行" => "K1030",
        "下一段-カ行" => "K1031",
        "下一段-ガ行" => "K1032",
        "下一段-ザ行" => "K1033",
        "下一段-サ行" => "K1034",
        "下一段-タ行" => "K1035",
        "下一段-ダ行" => "K1036",
        "下一段-ナ行" => "K1037",
        "下一段-ハ行" => "K1038",
        "下一段-バ行" => "K1039",
        "下一段-マ行" => "K1040",
        "下一段-ラ行-一般" => "K1041",
        "下一段-ラ行-呉レル" => "K1042",
        "下一段-ラ行" => "K1043",
        "カ行変格" => "K1050",
        "サ行変格" => "K1051",
        "ザ行変格" => "K1052",
        "文語四段-カ行" => "K1060",
        "文語四段-ガ行" => "K1061",
        "文語四段-サ行" => "K1062",
        "文語四段-タ行" => "K1063",
        "文語四段-バ行" => "K1064",
        "文語四段-ハ行" => "K1065",
        "文語四段-ハ行-イウ" => "K1066",
        "文語四段-マ行" => "K1067",
        "文語四段-ラ行" => "K1068",
        "文語上二段-カ行" => "K1070",
        "文語上二段-ガ行" => "K1071",
        "文語上二段-タ行" => "K1072",
        "文語上二段-ダ行" => "K1073",
        "文語上二段-ハ行" => "K1074",
        "文語上二段-バ行" => "K1075",
        "文語上二段-マ行" => "K1076",
        "文語上二段-ヤ行" => "K1077",
        "文語上二段-ラ行" => "K1078",
        "文語下二段-ア行" => "K1080",
        "文語下二段-カ行" => "K1081",
        "文語下二段-ガ行" => "K1082",
        "文語下二段-サ行" => "K1083",
        "文語下二段-タ行" => "K1084",
        "文語下二段-ダ行" => "K1085",
        "文語下二段-ナ行" => "K1086",
        "文語下二段-ハ行" => "K1087",
        "文語下二段-バ行" => "K1088",
        "文語下二段-マ行" => "K1089",
        "文語下二段-ヤ行" => "K1090",
        "文語下二段-ラ行" => "K1091",
        "文語下二段-ワ行" => "K1092",
        "文語上一段-カ行" => "K1100",
        "文語上一段-ナ行" => "K1101",
        "文語上一段-ハ行" => "K1102",
        "文語上一段-マ行" => "K1103",
        "文語上一段-ヤ行" => "K1104",
        "文語上一段-ワ行" => "K1105",
        "文語下一段-カ行" => "K1110",
        "文語カ行変格" => "K1120",
        "文語サ行変格" => "K1121",
        "文語ザ行変格" => "K1122",
        "文語ナ行変格" => "K1123",
        "文語ラ行変格" => "K1124",
        "形容詞" => "K1130",
        "文語形容詞-ク" => "K1140",
        "文語形容詞-シク" => "K1141",
        "文語形容詞-多シ" => "K1142",
        "助動詞-ジャ" => "K1150",
        "助動詞-タ" => "K1151",
        "助動詞-タイ" => "K1152",
        "助動詞-ダ" => "K1153",
        "助動詞-デス" => "K1154",
        "助動詞-ナイ" => "K1155",
        "助動詞-ヌ" => "K1156",
        "助動詞-ヘン" => "K1157",
        "助動詞-マス" => "K1158",
        "助動詞-ヤ" => "K1159",
        "助動詞-ヤス" => "K1160",
        "助動詞-ラシイ" => "K1161",
        "助動詞-レル" => "K1162",
        "助動詞-ナンダ" => "K1163",
        "助動詞-マイ" => "K1164",
        "助動詞-ドス" => "K1165",
        "文語助動詞-キ" => "K1170",
        "文語助動詞-ケム" => "K1171",
        "文語助動詞-ゴトシ" => "K1173",
        "文語助動詞-ザマス" => "K1174",
        "文語助動詞-ザンス" => "K1175",
        "文語助動詞-ズ" => "K1176",
        "文語助動詞-タリ-完了" => "K1177",
        "文語助動詞-タリ-断定" => "K1178",
        "文語助動詞-ツ" => "K1179",
        "文語助動詞-テフ" => "K1180",
        "文語助動詞-ナリ-伝聞" => "K1181",
        "文語助動詞-ナリ-断定" => "K1182",
        "文語助動詞-ヌ" => "K1183",
        "文語助動詞-ベシ" => "K1184",
        "文語助動詞-マシ" => "K1185",
        "文語助動詞-マジ" => "K1186",
        "文語助動詞-ム" => "K1187",
        "文語助動詞-ラシ" => "K1188",
        "文語助動詞-ラム" => "K1189",
        "文語助動詞-リ" => "K1190",
        "文語助動詞-ンス" => "K1191",
        "文語助動詞-ケリ" => "K1192",
        "文語助動詞-ジ" => "K1193",
        "文語助動詞-コス" => "K1194",
        "文語助動詞-ムズ" => "K1195",
        "文語助動詞-メリ" => "K1196",
        "無変形" => "K1200",
        "*" => "K1999",
    };

    $self->{k2_label} = {
        "語幹-一般" => "K2000",
        "語幹-サ" => "K2001",
        "未然形-一般" => "K2010",
        "未然形-サ" => "K2011",
        "未然形-セ" => "K2012",
        "未然形-撥音便" => "K2013",
        "未然形-ヘ" => "K2014",
        "未然形-補助" => "K2015",
        "意志推量形" => "K2020",
        "連用形-一般" => "K2030",
        "連用形-イ音便" => "K2031",
        "連用形-ウ音便" => "K2032",
        "連用形-促音便" => "K2033",
        "連用形-撥音便" => "K2034",
        "連用形-融合" => "K2035",
        "連用形-チャ" => "K2036",
        "連用形-シ" => "K2037",
        "連用形-スッ" => "K2038",
        "連用形-ト" => "K2039",
        "連用形-ニ" => "K2040",
        "連用形-補助" => "K2041",
        "連用形-省略" => "K2042",
        "終止形-一般" => "K2050",
        "終止形-ウ音便" => "K2051",
        "終止形-促音便" => "K2052",
        "終止形-撥音便" => "K2053",
        "終止形-エ" => "K2054",
        "終止形-チャ" => "K2055",
        "終止形-補助" => "K2056",
        "終止形-融合" => "K2057",
        "連体形-一般" => "K2060",
        "連体形-エ短縮" => "K2061",
        "連体形-撥音便" => "K2062",
        "連体形-省略" => "K2063",
        "連体形-補助" => "K2064",
        "仮定形-一般" => "K2070",
        "仮定形-融合" => "K2071",
        "仮定形-キャ" => "K2072",
        "仮定形-ニャ" => "K2073",
        "已然形-一般" => "K2080",
        "已然形-補助" => "K2081",
        "命令形" => "K2090",
        "ク語法" => "K2100",
        "*" => "K2999",
    };
}

1;
#################### END OF FILE ####################
