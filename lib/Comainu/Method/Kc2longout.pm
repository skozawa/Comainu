package Comainu::Method::Kc2longout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename dirname fileparse);
use Config;

use Comainu::Util qw(any read_from_file write_to_file check_file proc_file2stdout);
use Comainu::Format;
use Comainu::Feature;
use Comainu::BIProcessor;

# Analyze long-unit-word
sub usage {
    my ($self) = @_;
    while (<DATA>) {
        print $_;
    }
}

sub run {
    my ($self, $test_kc, $save_dir) = @_;

    $self->before_analyze({
        dir => $save_dir, luwmodel => $self->{luwmodel}
    });
    $self->analyze_files($test_kc, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_kc, $save_dir) = @_;

    my $tmp_test_kc = $self->{"comainu-temp"} . "/" . basename($test_kc);
    Comainu::Format->format_inputdata({
        input_file       => $test_kc,
        input_type       => 'input-kc',
        output_file      => $tmp_test_kc,
        output_type      => 'kc',
        data_format_file => $self->{data_format},
    });

    my $basename = basename($tmp_test_kc);
    my $kc2_file      = $self->{"comainu-temp"} . "/" . basename($tmp_test_kc, ".KC") . ".KC2";
    my $svmout_file   = $self->{"comainu-temp"} . "/" . $basename . ".svmout";
    my $tmp_lout_file = $self->{"comainu-temp"} . "/" . $basename . ".tmp.lout";

    $self->create_features($tmp_test_kc, $kc2_file);
    $self->chunk_luw($kc2_file, $svmout_file);
    $self->merge_chunk_result($tmp_test_kc, $svmout_file, $tmp_lout_file);
    my $buff = $self->post_process($tmp_test_kc, $tmp_lout_file, $kc2_file);
    $self->output_result($buff, $save_dir, $basename . ".lout");
    undef $buff;

    unlink $tmp_test_kc if !$self->{debug} &&
        -f $tmp_test_kc && $self->{bnst_process} ne 'with_luw';

    return 0;
}


# create test data for analyzing long-unit-word
sub create_features {
    my ($self, $tmp_test_kc, $kc2_file) = @_;
    print STDERR "# CREATE FEATURE DATA\n";

    # delte kc2_file if already exist
    unlink $kc2_file if -s $kc2_file;

    my $buff = Comainu::Feature->create_longout_feature($tmp_test_kc, $self->{boundary});
    # Use partial parsing if the luwmodel-type is SVM
    $buff = Comainu::Feature->pp_partial($buff, { boundary => $self->{boundary} })
        if $self->{"luwmodel-type"} eq 'SVM';
    if ( $self->{"luwmodel-type"} eq 'CRF' ) {
        $buff =~ s/^EOS.*?//mg;
        # delete B* (CRF++ can't recognize boundary)
        $buff =~ s/^\*B.*?//mg if $self->{boundary} eq "word";
    }
    # add line break at last for Yamcha and CRF++
    $buff .= "\n";

    write_to_file($kc2_file, $buff);
    undef $buff;

    unlink $kc2_file unless -s $kc2_file;

    return 0;
}

# chunk kc2 file using Yamcha or CRF++
sub chunk_luw {
    my ($self, $kc2_file, $svmout_file) = @_;
    print STDERR "# CHUNK LUW\n";

    my $tool_cmd;
    my $opt = "";
    if ( $self->{"luwmodel-type"} eq 'SVM' ) {
        # sentence/word boundary
        $opt = "-C" if $self->{boundary} eq "sentence" || $self->{boundary} eq "word";
        $tool_cmd = $self->{"yamcha-dir"} . "/yamcha";
    } elsif ( $self->{"luwmodel-type"} eq 'CRF' ) {
        $tool_cmd = $self->{"crf-dir"} . "/crf_test";
    }
    $tool_cmd .= ".exe" if $Config{osname} eq "MSWin32";

    if(! -x $tool_cmd) {
        printf(STDERR "WARNING: %s Not Found or executable.\n", $tool_cmd);
        exit 0;
    }

    my $com = "";
    if ( $self->{"luwmodel-type"} eq "SVM" ) {
        $com = "\"" . $tool_cmd . "\" " . $opt . " -m \"" . $self->{luwmodel} . "\"";
    } elsif ( $self->{"luwmodel-type"} eq "CRF" ) {
        $com = "\"$tool_cmd\" -m \"". $self->{luwmodel} . "\"";
    }
    printf(STDERR "# COM: %s\n", $com) if $self->{debug};

    unlink $svmout_file if -s $svmout_file;
    check_file($kc2_file);

    my $buff = proc_file2stdout($com, $kc2_file, $self->{"comainu-temp"});
    $buff =~ s/\x0d\x0a/\x0a/sg;
    $buff =~ s/^\r?\n//mg;
    $buff = Comainu::Format->move_future_front($buff);
    write_to_file($svmout_file, $buff);
    undef $buff;

    unlink $svmout_file unless -s $svmout_file;

    return 0;
}


sub merge_chunk_result {
    my ($self, $tmp_test_kc, $svmout_file, $lout_file) = @_;
    print STDERR "# MERGE CHUNK RESULT\n";

    check_file($svmout_file);

    my $buff = Comainu::Format->merge_kc_with_svmout($tmp_test_kc, $svmout_file, $self->{luwmrph});
    write_to_file($lout_file, $buff);
    undef $buff;

    unlink $lout_file unless -s $lout_file;

    unlink $svmout_file if !$self->{debug} && -f $svmout_file &&
        $self->{bnst_process} ne 'with_luw';

    return 0;
}

# analyze the pos, cForm, cType
# target: the long-unit-word labeled with only B and I
sub post_process {
    my ($self, $tmp_test_kc, $tmp_lout_file, $kc2_file) = @_;
    print STDERR "# POST PROCESS\n";

    my $train_name = basename($self->{luwmodel}, ".model");
    my $test_name = basename($tmp_test_kc);

    $self->set_comainu_bi_model;
    my $bip_processor = Comainu::BIProcessor->new(
        model_type => 0,
        %$self,
    );
    my $buff = $bip_processor->analyze($kc2_file, $tmp_lout_file, {
        train_name => $train_name,
        test_name  => $test_name,
    });
    unlink $tmp_lout_file if !$self->{debug} && -f $tmp_lout_file;

    return $self->create_long_lemma($buff);
}

# set comainu-bi-model-dir
# 1. comainu-bi-model-dir
# 2. pos, cForm, cType models in luwmodel directory
sub set_comainu_bi_model {
    my ($self) = @_;
    return if $self->{"comainu-bi-model-dir"};

    my $train_name = basename($self->{luwmodel}, ".model");
    my $train_dir  = dirname($self->{luwmodel});

    for my $type ( ("pos", "cForm", "cType") ) {
        return unless -d $train_dir . "/" . $type;
        return unless -f $train_dir . "/" . $type . "/" . $train_name . ".BI_" . $type . ".model"
    }

    $self->{"comainu-bi-model-dir"} = $train_dir;
}

# create long-word lemma and reading
sub create_long_lemma {
    my ($self, $data) = @_;

    my $comp_data = read_from_file($self->{comp_file});
    my %comp;
    foreach my $line (split(/\r?\n/, $comp_data)) {
    	next if $line eq "";
    	my @items = split(/\t/, $line);
    	$comp{$items[0]."_".$items[1]."_".$items[2]} = $items[3]."_".$items[4];
    }

    # create array of long-unit-word
    my @luws;
    my $luw_id = 0;
    foreach my $line (split(/\r?\n/,$data)) {
        my @items = split(/[ \t]/, $line);
        if ( $items[0] eq "EOS" ) {
            $luw_id = $#luws+1;
            push @{$luws[$luw_id]}, \@items;
            next;
        } elsif ( $items[0] =~ /B/ ) {
            $luw_id = $#luws+1;
        } else {
            @items[17..19] = ("*","*","*");
        }
        # Don't have form,formBase,formOrthBase,formOrth (ex. don't use unidic-db)
        if ( $items[7] eq "*" && $items[8] eq "*" &&
                 $items[9] eq "*" && $items[10] eq "*") {
            @items[7..10] = @items[2,2,3,3];
        }
        for my $i ( 7 .. 10 ) {
            $items[$i] = "" if $items[$i] eq "*";
        }
        push @{$luws[$luw_id]}, \@items;
    }
    undef $data;

    my $res = "";
    for my $i ( 0 .. $#luws ) {
        my $luw = $luws[$i];
        my $first = $luw->[0];
        if ( $first->[0] eq "EOS" ) {
            $res .= "EOS\n";
            next;
        }
        # long-unit-word composed of one short-unit-word
        # pos is 助詞 or 助動詞
        if ( $first->[14] =~ /助詞|助動詞/ && $#{$luw} == 0 ) {
            # no operation
        }
        # lemma and reading set empty
        elsif ( any { $first->[14] eq $_ } ("英単語", "URL", "言いよどみ", "漢文", "web誤脱", "ローマ字文") ) {
            @$first[17,18] = ("", "");
        }
        # 括弧内
        elsif ( any { $first->[19] eq $_ } ("（）内", "〔〕内", "「」内", "｛｝内",
                                            "〈〉内", "［］内", "《　》内") ) {
            @$first[17,18] = ("カッコナイ", "括弧内");
        }
        else {
            @$first[17,18] = ("", "");
            my $parential = 0; # has bracket
            for my $j ( 0 .. $#{$luw} - 1 ) {
                $self->generate_long_lemma($luw, $j);
                my $suw = $luw->[$j];
                if ( $suw->[4] eq "補助記号-括弧開" || $suw->[4] eq "補助記号-括弧閉") {
                    $parential++;
                }
            }
            $self->generate_long_lemma($luw, $#{$luw});
            my $last = $luw->[-1];
            if($last->[8] eq "補助記号-括弧開" || $last->[8] eq "補助記号-括弧閉") {
                $parential++;
            }

            # regenerate lemma and reading if long-unit-word
            # which is composed of multiple short-unit-word and contains bracket
            if ( $parential && $#{$luw} > 1 ) {
                @$first[17,18] = ("","");
                $self->generate_long_lemma($luw, 0);

                my $j;
                for ($j =1; $j <= $#{$luw}-2; $j++) {
                    my $suw  = $luw->[$j];
                    my $suw2 = $luw->[$j+2];
                    # Don't add short-unit-word lemma and reading to long-unit-word
                    # if the word form of short-unit-word is same to short-unit-word in brackets.
                    # ex. 萎縮(いしゅく)する
                    if ( $suw->[4] eq "補助記号-括弧開" && $suw2->[4] eq "補助記号-括弧閉" ) {
                        my $pre_suw  = $luw->[$j-1];
                        my $post_suw = $luw->[$j+1];
                        if ( join(" ", @$pre_suw[3,2,4..6]) eq join(" ",@$post_suw[3,2,4..6]) ) {
                            $j += 2;
                            next;
                        }
                    }
                    $self->generate_long_lemma($luw, $j);
                }
                for (; $j <= $#{$luw}-1; $j++) {
                    $self->generate_long_lemma($luw, $j);
                }
                $self->generate_long_lemma($luw, $#{$luw});
            }

            # Composition
            my $pos_lemma_reading = join("_", @$first[14,17,18]);
            if ( defined $comp{$pos_lemma_reading} ) {
                my ($reading, $lemma) = split(/\_/, $comp{$pos_lemma_reading});
                if( (any { $first->[18] eq $_ } ("に因る", "に拠る", "による"))
                        && $last->[6] eq "連用形-一般" ) {
                    ($reading, $lemma) = ("ニヨリ", "により");
                } elsif ( $first->[18] eq "に対する" && $last->[6] eq "連用形-一般" ) {
                    ($reading, $lemma) = ("ニタイシ", "に対し");
                } elsif ( $first->[18] eq "に渡る" && $last->[6] eq "連用形-一般" ) {
                    ($reading, $lemma) = ("ニワタリ", "にわたり");
                }
                $first->[17] = $reading;
                $first->[18] = $lemma;
            }
        }
        foreach my $suw (@$luw) {
            $res .= join(" ", @$suw)."\n";
        }
    }

    undef @luws;

    return $res;
}

sub generate_long_lemma {
    my ($self, $luw, $index) = @_;

    my $first = $luw->[0];
    my $suw   = $luw->[$index];
    if( $suw->[4] eq "補助記号-括弧開" || $suw->[4] eq "補助記号-括弧閉" ) {
        if ( $#{$luw} == 0) {
            $first->[17] .= $suw->[8];  # fromBase
            $first->[18] .= $suw->[9];  # formOrthBase
        }
    } elsif ( $suw->[4] =~ /名詞-固有名詞-人名|名詞-固有名詞-地名/ ) {
        $first->[17] .= $suw->[7];      # form
        $first->[18] .= $suw->[1];      # orthToken
    } elsif ( $suw->[3] eq "○" && $#{$luw} > 1 ) {
        $first->[17] .= $suw->[3];      # lemma
        $first->[18] .= $suw->[9];      # formOrthBase
    } elsif ( $suw->[5] eq "*" || $suw->[5] eq "" ) {
        $first->[17] .= $suw->[7];      # form
        $first->[18] .= $suw->[9];      # formOrthBase
    } else {
        if ( $#{$luw} != $index ) { # not last suw
            $first->[17] .= $suw->[7];  # form
            $first->[18] .= $suw->[10]; # formOrth
        } else {
            $first->[17] .= $suw->[8];  # fromBase
            $first->[18] .= $suw->[9];  # formOrthBase
        }
    }
}


1;


__DATA__
COMAINU-METHOD: kc2longout
  Usage: ./script/comainu.pl kc2longout [options]
    This command analyzes long-unit-word of <input>(file or STDIN) with <luwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --boundary                specify the type of boundary (default: sentence)
                              (sentence or word)
    --luwmrph                 whether to output morphology of long-unit-word (default: with)
                              (with or without)
    --comainu-bi-model-dir    speficy the model directory for the category models

  ex.)
  $ perl ./script/comainu.pl kc2longout
  $ perl ./script/comainu.pl kc2longout --input=sample/sample.KC --output-dir=out
    -> out/sample.KC.lout
  $ perl ./script/comainu.pl kc2longout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

