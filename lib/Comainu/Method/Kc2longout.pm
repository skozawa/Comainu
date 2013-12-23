package Comainu::Method::Kc2longout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename fileparse);
use Config;

use Comainu::Util qw(read_from_file write_to_file check_file proc_stdin2stdout);
use Comainu::Format;
use AddFeature;
use BIProcessor;

sub new {
    my ($class, %args) = @_;
    bless {
        args_num => 4,
        comainu  => delete $args{comainu},
        %args
    }, $class;
}

sub usage {
    my ($self) = @_;
    printf("COMAINU-METHOD: kc2longout\n");
    printf("  Usage: %s kc2longout <test-kc> <long-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <long-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl kc2longout sample/sample.KC train/CRF/train.KC.model out\n");
    printf("    -> out/sample.lout\n");
    printf("  \$ perl ./script/comainu.pl kc2longout --luwmodel=SVM sample/sample.KC train/SVM/train.KC.model out\n");
    printf("    -> out/sample.KC.lout\n");
    printf("\n");
}

sub run {
    my ($self, $test_kc, $luwmodel, $save_dir) = @_;

    $self->before_analyze({
        dir => $save_dir, luwmodel => $luwmodel, args_num => scalar @_,
    });

    $self->analyze($test_kc, $luwmodel, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_kc, $luwmodel, $save_dir) = @_;

    my $tmp_test_kc = $self->comainu->{"comainu-temp"} . "/" . basename($test_kc);
    Comainu::Format->format_inputdata({
        input_file       => $test_kc,
        input_type       => 'input-kc',
        output_file      => $tmp_test_kc,
        output_type      => 'kc',
        data_format_file => $self->comainu->{data_format},
    });

    $self->create_features($tmp_test_kc, $luwmodel);

    $self->chunk_luw($tmp_test_kc, $luwmodel);
    $self->merge_chunk_result($tmp_test_kc, $save_dir);
    $self->post_process($tmp_test_kc, $luwmodel, $save_dir);

    unlink $tmp_test_kc if !$self->comainu->{debug} &&
        -f $tmp_test_kc && $self->comainu->{bnst_process} ne 'with_luw';
}


# 解析用KC２ファイルへ素性追加
sub create_features {
    my ($self, $tmp_test_kc, $luwmodel) = @_;
    print STDERR "# CREATE FEATURE DATA\n";

    # 出力ファイル名の生成
    my $output_file = $self->comainu->{"comainu-temp"} . "/" .
        basename($tmp_test_kc, ".KC") . ".KC2";
    # すでに同じ名前の中間ファイルがあれば削除
    unlink($output_file) if -s $output_file;

    my $buff = read_from_file($tmp_test_kc);
    if ( $self->comainu->{boundary} ne "sentence" &&
             $self->comainu->{boundary} ne "word" ) {
        $buff =~ s/^EOS.*?\n//mg;
    }
    $buff = $self->comainu->delete_column_long($buff);
    $buff =~ s/^\*B.*?\n//mg if $self->comainu->{boundary} eq "sentence";

    # SVMの場合、partial chunking
    $buff = $self->comainu->pp_partial($buff) if $self->comainu->{luwmodel} eq "SVM";

    # 素性の追加
    my $AF = AddFeature->new;
    my $basename = basename($luwmodel, ".model");
    my ($filename, $path) = fileparse($luwmodel);
    $buff = $AF->add_feature($buff, $basename, $path);

    write_to_file($output_file, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink $output_file unless -s $output_file;

    return 0;
}

# 解析用KC２ファイルをチャンキングモデル(yamcha, crf++)で解析
sub chunk_luw {
    my ($self, $tmp_test_kc, $luwmodel) = @_;
    print STDERR "# CHUNK LUW\n";

    my $tool_cmd;
    my $opt = "";
    if ( $self->comainu->{luwmodel} eq 'SVM' ) {
        # sentence/word boundary
        $opt = "-C" if $self->comainu->{boundary} eq "sentence"
            || $self->comainu->{boundary} eq "word";
        $tool_cmd = $self->comainu->{"yamcha-dir"} . "/yamcha";
    } elsif ( $self->comainu->{luwmodel} eq 'CRF' ) {
        $tool_cmd = $self->comainu->{"crf-dir"} . "/crf_test";
    }
    $tool_cmd .= ".exe" if $Config{osname} eq "MSWin32";

    if(! -x $tool_cmd) {
        printf(STDERR "WARNING: %s Not Found or executable.\n", $tool_cmd);
        exit 0;
    }

    my $input_file = $self->comainu->{"comainu-temp"} . "/" .
        basename($tmp_test_kc, ".KC") . ".KC2";
    my $output_file = $self->comainu->{"comainu-temp"} . "/" .
        basename($tmp_test_kc) . ".svmout";
    # すでに同じ名前の中間ファイルがあれば削除
    unlink($output_file) if -s $output_file;
    check_file($input_file);

    my $buff = read_from_file($input_file);
    $buff =~ s/^EOS.*?//mg if $self->comainu->{luwmodel} eq'CRF';
    # yamchaやCRF++のために、明示的に最終行に改行を付与
    $buff .= "\n";
    write_to_file($input_file, $buff);

    my $com = "";
    if ( $self->comainu->{luwmodel} eq "SVM" ) {
        $com = "\"" . $tool_cmd . "\" " . $opt . " -m \"" . $luwmodel . "\"";
    } elsif ( $self->comainu->{luwmodel} eq "CRF" ) {
        $com = "\"$tool_cmd\" -m \"$luwmodel\"";
    }
    printf(STDERR "# COM: %s\n", $com) if $self->comainu->{debug};

    $buff = proc_stdin2stdout($com, $buff, $self->comainu->{"comainu-temp"});
    $buff =~ s/\x0d\x0a/\x0a/sg;
    $buff =~ s/^\r?\n//mg;
    $buff = $self->comainu->move_future_front($buff);
    $buff = $self->comainu->truncate_last_column($buff);
    write_to_file($output_file, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink $output_file unless -s $output_file;

    return 0;
}

# チャンクの結果をマージして出力ディレクトリへ結果を保存
sub merge_chunk_result {
    my ($self, $tmp_test_kc, $save_dir) = @_;
    print STDERR "# MERGE CHUNK RESULT\n";

    my $basename = basename($tmp_test_kc);
    my $svmout_file = $self->comainu->{"comainu-temp"} . "/" . $basename . ".svmout";
    my $lout_file = $save_dir . "/" . $basename . ".lout";

    check_file($svmout_file);

    my $buff = $self->comainu->merge_kc_with_svmout($tmp_test_kc, $svmout_file);
    write_to_file($lout_file, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink $lout_file unless -s $lout_file;

    unlink $svmout_file if !$self->comainu->{debug} && -f $svmout_file &&
        $self->comainu->{bnst_process} ne 'with_luw';

    return 0;
}

# 後処理:BIのみのチャンクを再処理
sub post_process {
    my ($self, $tmp_test_kc, $luwmodel, $save_dir) = @_;
    my $ret = 0;
    print STDERR "# POST PROCESS\n";

    my $cmd = $self->comainu->{"yamcha-dir"}."/yamcha";
    $cmd .= ".exe" if $Config{osname} eq "MSWin32";
    $cmd = sprintf("\"%s\" -C", $cmd);

    my $train_name = basename($luwmodel, ".model");
    my $test_name = basename($tmp_test_kc);
    my $lout_file = $save_dir . "/" . $test_name . ".lout";
    my $lout_data = read_from_file($lout_file);
    my $comp_file = $self->comainu->{"comainu-home"} . '/suw2luw/Comp.txt';

    my $BIP = BIProcessor->new(
        debug      => $self->comainu->{debug},
        model_type => 0,
    );
    my $buff = $BIP->execute_test($cmd, $lout_data, {
        train_name => $train_name,
        test_name  => $test_name,
        temp_dir   => $self->comainu->{"comainu-temp"},
        model_dir  => $self->comainu->{"comainu-svm-bip-model"},
        comp_file  => $comp_file,
    });
    undef $lout_data;

    $buff = $self->create_long_lemma($buff, $comp_file);

    write_to_file($lout_file, $buff);
    undef $buff;

    return $ret;
}

# 語彙素・語彙素読みを生成
sub create_long_lemma {
    my ($self, $data, $comp_file) = @_;

    my $comp_data = read_from_file($comp_file);
    my %comp;
    foreach my $line (split(/\r?\n/, $comp_data)) {
    	next if $line eq "";
    	my @items = split(/\t/, $line);
    	$comp{$items[0]."_".$items[1]."_".$items[2]} = $items[3]."_".$items[4];
    }

    # 長単位の配列を生成
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
        # form,formBase,formOrthBase,formOrth がない場合
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
        # 1短単位から構成される助詞、助動詞はそのまま(何もしない)
        if ( $first->[14] =~ /助詞|助動詞/ && $#{$luw} == 0 ) {
        }
        # 特定の品詞の場合は、長単位語彙素、語彙素読みを空文字にする
        elsif ( $first->[14] ~~ ["英単語", "URL", "言いよどみ", "漢文", "web誤脱", "ローマ字文"] ) {
            @$first[17,18] = ("","");
        }
        # 括弧内
        elsif ( $$first[19] ~~ ["（）内", "〔〕内", "「」内", "｛｝内",
                                  "〈〉内", "［］内", "《　》内"] ) {
            @$first[17,18] = ("カッコナイ","括弧内");
        }
        else {
            @$first[17,18] = ("","");
            my $parential = 0; # 括弧があるか
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

            # 括弧がある複数短単位から構成される長単位の場合は、
            # 語彙素、語彙素読みを作り直す
            if ( $parential && $#{$luw} > 1 ) {
                @$first[17,18] = ("","");
                $self->generate_long_lemma($luw, 0);

                my $j;
                for ($j =1; $j <= $#{$luw}-2; $j++) {
                    my $suw  = $luw->[$j];
                    my $suw2 = $luw->[$j+2];
                    # 括弧の前後の短単位の語形が同じ場合は
                    # 語彙素、語彙素読みには追加しないので、スキップする
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
                for ($j; $j <= $#{$luw}-1; $j++) {
                    $self->generate_long_lemma($luw, $j);
                }
                $self->generate_long_lemma($luw, $#{$luw});
            }

            # 複合辞
            my $pos_lemma_reading = join("_", @$first[14,17,18]);
            if ( defined $comp{$pos_lemma_reading} ) {
                my ($reading, $lemma) = split(/\_/, $comp{$pos_lemma_reading});
                if( $first->[18] ~~ ["に因る", "に拠る", "による"] && $last->[6] eq "連用形-一般" ) {
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
            $first->[17] .= $suw->[8]; ## fromBase
            $first->[18] .= $suw->[9]; ## formOrthBase
        }
    } elsif ( $suw->[4] =~ /名詞-固有名詞-人名|名詞-固有名詞-地名/ ) {
        $first->[17] .= $suw->[7]; ## form
        $first->[18] .= $suw->[1]; ## orthToken
    } elsif ( $suw->[3] eq "○" && $#{$luw} > 1 ) {
        $first->[17] .= $suw->[3]; ## lemma
        $first->[18] .= $suw->[9]; ## formOrthBase
    } elsif ( $suw->[5] eq "*" || $suw->[5] eq "" ) {
        $first->[17] .= $suw->[7]; ## form
        $first->[18] .= $suw->[9]; ## formOrthBase
    } else {
        if ( $#{$luw} != $index ) { # not last suw
            $first->[17] .= $suw->[7];  ## form
            $first->[18] .= $suw->[10]; ## formOrth
        } else {
            $first->[17] .= $suw->[8]; ## fromBase
            $first->[18] .= $suw->[9]; ## formOrthBase
        }
    }
}


1;
