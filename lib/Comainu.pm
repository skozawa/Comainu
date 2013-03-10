# -*- mode: perl; coding: utf-8; -*-

package Comainu;

use strict;
use FindBin qw($Bin);
use utf8;
use Encode;
use File::Basename;
use Config;

use SUW2LUW;
use LCSDiff;

use CreateDictionary;
use AddFeature;
use BIProcessor;

my $DEFAULT_VALUES =
{
    "debug" => 0,
    "comainu-home" => $Bin."/..",
    "comainu-temp" => $Bin."/../tmp/temp",
    "comainu-svm-bip-model" => $Bin."/../train/BI_process_model",
    "data_format" => $Bin."/../etc/data_format.conf",
    "mecab_rcfile" => $Bin."/../etc/dicrc",
    "perl" => "/usr/bin/perl",
    "java" => "/usr/bin/java",
    "yamcha-dir" => "/usr/local/bin",
    "chasen-dir" => "/usr/local/bin",
    "mecab-dir" => "/usr/local/bin",
    "unidic-dir" => "/usr/local/unidic",
    "unidic2-dir" => "/usr/local/unidic2",
    "unidic-db" => "/usr/local/unidic2/share/unidic.db",
    "svm-tool-dir" => "/usr/local/bin",
    "crf-dir" => "/usr/local/bin",
    "mira-dir" => "/usr/local/bin",
    "mstparser-dir" => "mstparser",
    "boundary" => "none",
    "luwmrph" => "with",
    "suwmodel" => "mecab",
    "luwmodel" => "CRF",
    "bnst_process" => "none",
};

my $MECAB_CHASEN_TABLE_FOR_UNIDIC =
{
    # MECAB => CHASEN
    "0" => "orth",
    "1" => "pron",
    "2" => "lForm",
    "3" => "lemma",
    "4" => "pos",
    "5" => "cType",
    "6" => "cForm",
    "7" => "goshu",
};

my $KC_MECAB_TABLE_FOR_UNIDIC =
{
    # KC => MECAB
    "0" => "0",
    "1" => "0",
    "2" => "2",
    "3" => "3",
    "4" => "1",
    "5" => "4",
    "6" => "5",
    "7" => "6",
    "8" => "*",
    "9" => "*",
    "10" => "*",
};

my $MECAB_CHASEN_TABLE_FOR_CHAMAME =
{
    # MECAB => CHASEN
    "0" => "",
    "1" => "orth",
    "2" => "pron",
    "3" => "lForm",
    "4" => "lemma",
    "5" => "pos",
    "6" => "cType",
    "7" => "cForm",
    #"8" => "form",
    #"9" => "goshu",
};

my $KC_MECAB_TABLE_FOR_CHAMAME =
{
    # KC => MECAB
    "0" => "1",
    "1" => "3",
    "2" => "4",
    "3" => "5",
    "4" => "6",
    "5" => "7",
    #"6" => "10",
    #"7" => "11",
    #"8" => "12",
    #"9" => "13",
    "6" => "9",
    "7" => "10",
    "8" => "11",
    "9" => "12",
    "10" => "*",
    "11" => "*",
    #"12" => "9",
    "12" => "8",
};

# my $UNIDIC_MECAB_TYPE = "unidic";
# my $MECAB_CHASEN_TABLE = $MECAB_CHASEN_TABLE_FOR_UNIDIC;
# my $KC_MECAB_TABLE = $KC_MECAB_TABLE_FOR_UNIDIC;

my $UNIDIC_MECAB_TYPE = "chamame";
my $MECAB_CHASEN_TABLE = $MECAB_CHASEN_TABLE_FOR_CHAMAME;
my $KC_MECAB_TABLE = $KC_MECAB_TABLE_FOR_CHAMAME;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {%$DEFAULT_VALUES, @_};
    bless $self, $class;
    return $self;
}


# 概要
# 訓練対象KCファイルからモデルを訓練する。
#
# 使用方法
# $self->METHOD_kc2longmodel(訓練対象KCファイル, モデルディレクトリ);
#
sub USAGE_kc2longmodel {
    my $self = shift;
    printf("COMAINU-METHOD: kc2longmodel\n");
    printf("  Usage: %s kc2longmodel <train-kc> <long-model-dir>\n", $0);
    printf("    This command trains model from <train-kc> into <long-model-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl kc2longmodel sample/sample.KC train\n");
    printf("    -> train/sample.KC.model\n");
    printf("\n");
}

sub METHOD_kc2longmodel {
    my ($self, $train_kc, $model_dir) = @_;
    if ( $self->{"luwmodel"} eq "SVM" ) {
        # yamchaのディレクトリの存在確認
        unless ( -d $self->{"yamcha-dir"} ) {
            printf(STDERR "ERROR: Not found YAMCHA_DIR '%s'.\n",
                   $self->{"yamcha-dir"});
            return 1;
        }
        my $yamcha_tool_dir = $self->get_yamcha_tool_dir();
        my $svm_tool_dir = $self->get_svm_tool_dir();

        return 1 unless defined $yamcha_tool_dir;
    } elsif ($self->{"luwmodel"} eq "CRF" ) {
        # CRF++のディレクトリの存在確認
        unless ( -d $self->{"crf-dir"} ) {
            printf(STDERR "ERROR: Not found CRF_DIR '%s'.\n",
                   $self->{"crf-dir"});
            return 1;
        }
        my $crf_dir = $self->get_crf_dir();

        return 1 unless defined $crf_dir;
    } elsif ( $self->{"luwmodel"} eq "MIRA" ) {
        # MIRAのディレクトリの存在確認
        unless ( -d $self->{"mira-dir"} ) {
            printf(STDERR "ERROR: Not found MIRA_DIR '%s'.\n",
                   $self->{"mira-dir"});
            return 1;
        }
        my $mira_dir = $self->get_mira_dir();

        return 1 unless defined $mira_dir;
    }
    unless ( $model_dir ) {
        $model_dir = File::Basename::dirname($train_kc);
    }

    my $tmp_train_kc = $self->{"comainu-temp"}."/".File::Basename::basename($train_kc);
    my $buff = $self->read_from_file($train_kc);
    $buff = $self->trans_dataformat($buff, "input-kc", "kc");
    $self->write_to_file($tmp_train_kc, $buff);
    undef $buff;

    $self->training_process1($tmp_train_kc, $model_dir);
    $self->training_train2($tmp_train_kc, $model_dir, $model_dir);

    if ( $self->{"luwmodel"} eq "SVM" ) {
        $self->training_train3($tmp_train_kc, $model_dir);
    } elsif ( $self->{"luwmodel"} eq "CRF" ) {
        $self->training_crftrain3($tmp_train_kc, $model_dir);
    } elsif ( $self->{"luwmodel"} eq "MIRA" ) {
        $self->training_miratrain3($tmp_train_kc, $model_dir);
    }
    if ( $self->{"luwmrph"} eq "with" ) {
        $self->training_train4($tmp_train_kc, $model_dir);
    }
    unlink($tmp_train_kc);

    return 0;
}


# 概要
# 辞書用KCファイル、解析対象KCファイル、モデルファイルの３つを用いて
# 解析対象KCファイルに長単位情報を付与する。
#
# 使用方法
# $self->METHOD_kc2longout(辞書用KCファイル名, 解析対象KCファイル,
#                             解析で作成したモデルファイル名, 変換後ファイルの保存先ディレクトリ);
#
#
sub USAGE_kc2longout {
    my $self = shift;
    printf("COMAINU-METHOD: kc2longout\n");
    printf("  Usage: %s kc2longout <train-kc> <test-kc> <long-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <train-kc> and <long-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl kc2longout sample/sample.KC sample/sample.KC sample/sample.KC.model out\n");
    printf("    -> out/sample.lout\n");
    printf("  \$ perl ./script/comainu.pl kc2longout --luwmodel=SVM sample/sample.KC sample/sample.KC sample/sample.KC.model out\n");
    printf("    -> out/sample.KC.lout\n");
    printf("  \$ perl ./script/comainu.pl kc2longout --luwmodel=MIRA sample/sample.KC sample train out\n");
    printf("    -> out/sample.lout\n");
    printf("\n");
}

sub METHOD_kc2longout {
    my ($self, $train_kc, $test_kc, $luwmodel, $save_dir ) = @_;

    if ( -f $test_kc ) {
        # unless ( -f $train_kc ) {
        #     printf(STDERR "ERROR: '%s' not found or not a file.\n",
        # 		   $train_kc);
        #     die;
        # }
        $self->check_luwmodel($luwmodel);

        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_kc ) {
            $self->kc2longout_internal($train_kc, $test_kc, $luwmodel, $save_dir);
        } elsif ( -d $test_kc ) {
            opendir(my $dh, $test_kc);
            while ( my $test_kc_file = readdir($dh) ) {
                if ( $test_kc_file =~ /.KC$/ ) {
                    $self->kc2longout_internal($train_kc, $test_kc_file, $luwmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid [test_kc] arg\n");
    }
    return 0;
}

sub kc2longout_internal {
    my ($self, $train_kc, $test_kc, $luwmodel, $save_dir ) = @_;

    my $tmp_test_kc = $self->{"comainu-temp"}."/".File::Basename::basename($test_kc);
    my $buff = $self->read_from_file($test_kc);
    $buff = $self->trans_dataformat($buff, "input-kc", "kc");
    $self->write_to_file($tmp_test_kc, $buff);
    undef $buff;

    $self->_process1($tmp_test_kc, $train_kc, $luwmodel);

    if ( $self->{"luwmodel"} eq "SVM" ) {
        $self->_process2($tmp_test_kc, $luwmodel);
    } elsif ( $self->{"luwmodel"} eq "CRF" ) {
        $self->_crf_process2($tmp_test_kc, $luwmodel);
    } elsif ( $self->{"luwmodel"} eq "MIRA" ) {
    	$luwmodel =~ s/[\/\\]$//;
    	$self->_mira_process2($tmp_test_kc, $luwmodel);
    	$luwmodel .= "/".File::Basename::basename($train_kc);
    }
    # $self->_process3($train_kc);
    # $self->_process4($train_kc);
    $self->_process5($train_kc, $tmp_test_kc, $save_dir);
    $self->_process6($train_kc, $tmp_test_kc, $luwmodel, $save_dir);
}


# 概要
# 正解の情報が付与されたKCファイルと、長単位解析結果のKCファイルを比較し、
# diff結果と精度を出力する。
#
# 使用方法
# $self->METHOD_kc2longeval(正解KCファイル, 解析結果KCファイル(.lout),
#                           保存先ディレクトリ);
#
# 動作
# 第１引数をよび第２引数の種類によって解析対象を変える。
# ・どちらもファイルの場合
#   それぞれのファイルを使って処理し、解析結果KCファイル名の拡張子を".eval",
#   ".eval.long"を付けた名前で、第３引数のパスに保存する。
# ・どちらもディレクトリの場合
#   第一引数のディレクトリ内に有る"*.KC"ファイル全てを対象として処理を行う。
#   ".lout"ファイルは、第二引数で与えられたディレクトリ内のファイルで、".KC"ファイル
#   とペアとなる".lout"ファイルを順次適用する。無ければエラーとする。
#   処理結果は、".KC"ファイル名から拡張子を除いた文字列に".eval",
#   ".eval.long"を付けた名前で、第３引数のパスに保存する。
# ・上記２つの場合に該当しない組合せはエラーとする。
#
# 2005/08/04
sub USAGE_kc2longeval {
    my $self = shift;
    printf("COMAINU-METHOD: kc2longeval\n");
    printf("  Usage: %s kc2longeval <ref-kc> <kc-lout> <out-dir>\n", $0);
    printf("    This command make a evaluation for <kc-lout> with <ref-kc>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  perl ./script/comainu.pl kc2longeval sample/sample.KC out/sample.KC.lout out\n");
    printf("    -> out/sample.eval.long\n");
    printf("\n");
}

sub METHOD_kc2longeval {
    my ($self, $correct_kc, $result_kc_lout, $save_dir) = @_;

    mkdir($save_dir) unless -d $save_dir;

    if ( -f $result_kc_lout ) {
        $self->kc2longeval_internal($correct_kc, $result_kc_lout, $save_dir);
    } elsif ( -d $result_kc_lout ) {
        opendir(my $dh, $result_kc_lout);
        while ( my $result_kc_lout_file = readdir($dh) ) {
            if ( $result_kc_lout_file =~ /.KC$/ ) {
                $self->kc2longeval_internal($correct_kc, $result_kc_lout_file, $save_dir);
            }
        }
        closedir($dh);
    } else {
        printf(STDERR "# Error: Not found result_kc_lout '%s'\n", $result_kc_lout);
    }
    return 0;
}

sub kc2longeval_internal {
    my ($self, $correct_kc, $result_kc_lout, $save_dir) = @_;
    $self->_compare($correct_kc, $result_kc_lout, $save_dir);
}


# 概要
# 辞書用KCファイル、解析対象BCCWJファイル、モデルファイルの３つを用いて
# 解析対象BCCWJファイルに長単位情報を付与する。
#
# 使用方法
# $self->METHOD_bccwj2longout(辞書用KCファイル名, 解析対象BCCWJファイル,
#                                   解析で作成したモデルファイル名,
#                                   変換後ファイルの保存先ディレクトリ);
#
# 動作
# 第２引数の種類によって解析対象を変える。
# ・ファイルの場合
#   第２引数のファイルを解析する。
#   処理結果は第２引数のファイル名に".lout"を付与したファイル名で
#   第４引数のパスに保存する。
# ・ディレクトリの場合
#   第２引数のディレクトリ内に有る"*.txt"ファイル全てを対象として変換処理を行う。
#   処理結果は、第２引数のディレクトリで見付けたファイル名に
#   ".lout"を付与したファイル名で第４引数のパスに保存する。
# ・上記２つの場合に該当しない組合せはエラーとする。
#
sub USAGE_bccwj2longout {
    my $self = shift;
    printf("COMAINU-METHOD: bccwj2longout\n");
    printf("  Usage: %s bccwj2longout <train-kc> <test-bccwj> <long-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-bccwj> with <train-kc> and <long-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwj2longout train.KC sample/sample.bccwj.txt train/CRF/sample.KC.model out\n");
    printf("    -> out/sample.bccwj.txt.lout\n");
    printf("  \$ perl ./script/comainu.pl bccwj2longout --luwmodel=SVM train.KC sample/sample.bccwj.txt train/SVM/sample.KC.model out\n");
    printf("    -> out/sample.bccwj.txt.lout\n");
    printf("  \$ perl ./script/comainu.pl bccwj2longout --luwmodel=MIRA train.KC sample/sample.bccwj.txt train/MIRA out\n");
    printf("    -> out/sample.bccwj.txt.lout\n");
    printf("\n");
}

sub METHOD_bccwj2longout {
    my ($self, $train_kc, $test_bccwj, $luwmodel, $save_dir ) = @_;

    if ( -f $test_bccwj ) {
        # unless ( -f $train_kc ) {
        #     printf(STDERR "ERROR: '%s' not found or not a file.\n",
        #            $train_kc);
        #     die;
        # }
        $self->check_luwmodel($luwmodel);
        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_bccwj ) {
            $self->bccwj2longout_internal($train_kc, $test_bccwj, $luwmodel, $save_dir);
        } elsif ( -d $test_bccwj ) {
            opendir(my $dh, $test_bccwj);
            while ( my $test_bccwj_file = readdir($dh) ) {
                if ( $test_bccwj_file =~ /.txt$/ ) {
                    $self->bccwj2longout_internal($train_kc, $test_bccwj_file, $luwmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid test_bccwj='%s' arg\n", $test_bccwj);
    }
    return 0;
}

sub bccwj2longout_internal {
    my ($self, $train_kc, $test_bccwj, $luwmodel, $save_dir) = @_;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    my $tmp_dir = $self->{"comainu-temp"};
    my $tmp_test_bccwj = $tmp_dir."/".File::Basename::basename($test_bccwj);
    my $buff = $self->read_from_file($test_bccwj);
    $buff = $self->trans_dataformat($buff, "input-bccwj", "bccwj");
    $self->write_to_file($tmp_test_bccwj, $buff);
    undef $buff;

    my $kc_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC";
    my $kc_lout_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC.lout";
    my $bccwj_lout_file = $save_dir."/".File::Basename::basename($test_bccwj).".lout";

    $self->bccwj2kc_file($tmp_test_bccwj, $kc_file);
    $self->METHOD_kc2longout($train_kc, $kc_file, $luwmodel, $tmp_dir);
    $self->merge_bccwj_with_kc_lout_file($tmp_test_bccwj, $kc_lout_file, $bccwj_lout_file);

    return;
}


sub bccwj2kc_file {
    my ($self, $bccwj_file, $kc_file) = @_;
    my $buff = $self->read_from_file($bccwj_file);
    $buff = $self->bccwj2kc($buff);
    $self->write_to_file($kc_file, $buff);
    undef $buff;
}

sub merge_bccwj_with_kc_lout_file {
    my ($self, $bccwj_file, $kc_lout_file, $lout_file) = @_;
    my $bccwj_data = $self->read_from_file($bccwj_file);
    my $kc_lout_data = $self->read_from_file($kc_lout_file);
    my $lout_data = $self->merge_iof($bccwj_data, $kc_lout_data);
    undef $bccwj_data;
    undef $kc_lout_data;

    $self->write_to_file($lout_file, $lout_data);
    undef $lout_data;
}

##############################################
## 文節境界解析
##############################################
sub USAGE_kc2bnstmodel {
    my $self = shift;
    printf("COMAINU-METHOD: kc2bnstmodel\n");
    printf("  Usage: %s kc2bnstmodel <train-kc> <bnst-model-dir>\n", $0);
    printf("    This command trains model from <train-kc> into <bnst-model-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl kc2bnstmodel sample/sample.KC train\n");
    printf("    -> train/sample.KC.model\n");
    printf("\n");
}

sub METHOD_kc2bnstmodel {
    my ($self, $train_kc, $model_dir) = @_;
    # yamchaのディレクトリの存在確認
    unless ( -d $self->{"yamcha-dir"} ) {
        printf(STDERR "ERROR: Not found YAMCHA_DIR '%s'.\n",
               $self->{"yamcha-dir"});
        return 1;
    }
    unless ( $model_dir ) {
        $model_dir = File::Basename::dirname($train_kc);
    }
    my $yamcha_tool_dir = $self->get_yamcha_tool_dir();
    my $svm_tool_dir = $self->get_svm_tool_dir();
    unless ( defined($yamcha_tool_dir) ) {
        return 1;
    }
    $self->training_bnst($train_kc, $model_dir);
    return 0;
}


sub USAGE_kc2bnstout {
    my $self = shift;
    printf("COMAINU-METHOD: kc2bnstout\n");
    printf("  Usage: %s kc2bnstout <test-kc> <bnst-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl kc2bnstout sample/sample.KC train/bnst.model out\n");
    printf("    -> out/sample.KC.bout\n");
    printf("\n");
}

sub METHOD_kc2bnstout {
    my ($self, $test_kc, $bnstmodel, $save_dir ) = @_;

    if ( -f $test_kc ) {
        unless ( -f $bnstmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $bnstmodel);
            die;
        }
        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_kc ) {
            $self->kc2bnstout_internal($test_kc, $bnstmodel, $save_dir);
        } elsif ( -d $test_kc ) {
            opendir(my $dh, $test_kc);
            while ( my $test_kc_file = readdir($dh) ) {
                if ( $test_kc_file =~ /.KC$/ ) {
                    $self->kc2bnstout_internal($test_kc_file, $bnstmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid [test_kc] arg\n");
    }
    return 0;
}

sub kc2bnstout_internal {
    my ($self, $test_kc, $bnstmodel, $save_dir) = @_;

    my $tmp_test_kc = $self->{"comainu-temp"}."/".File::Basename::basename($test_kc);
    my $buff = $self->read_from_file($test_kc);
    $buff = $self->trans_dataformat($buff, "input-kc", "kc");
    $self->write_to_file($tmp_test_kc, $buff);
    undef $buff;

    $self->_bnst_process1($tmp_test_kc);
    $self->_bnst_process2($tmp_test_kc, $bnstmodel, $save_dir);
}


sub USAGE_bccwj2bnstout {
    my $self = shift;
    printf("COMAINU-METHOD: bccwj2bnstout\n");
    printf("  Usage: %s bccwj2bnstout <test-kc> <bnst-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwj2bnstout sample/sample.bccwj.txt train/bnst.model out\n");
    printf("    -> out/sample.bccwj.txt.bout\n");
    printf("\n");
}

sub METHOD_bccwj2bnstout {
    my ($self, $test_bccwj, $bnstmodel, $save_dir ) = @_;

    if ( -f $test_bccwj ) {
        unless ( -f $bnstmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $bnstmodel);
            die;
        }
        mkdir($save_dir) unless -d $save_dir;

        if (-f $test_bccwj ) {
            $self->bccwj2bnstout_internal($test_bccwj, $bnstmodel, $save_dir);
        } elsif ( -d $test_bccwj ) {
            opendir(my $dh, $test_bccwj);
            while ( my $test_bccwj_file = readdir($dh) ) {
                if ( $test_bccwj_file =~ /.txt$/ ) {
                    $self->bccwj2bnstout_internal($test_bccwj_file, $bnstmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid test_bccwj='%s' arg\n", $test_bccwj);
    }
    return 0;
}

sub bccwj2bnstout_internal {
    my ($self, $test_bccwj, $bnstmodel, $save_dir ) = @_;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    my $tmp_dir = $self->{"comainu-temp"};
    my $tmp_test_bccwj = $tmp_dir."/".File::Basename::basename($test_bccwj);
    my $buff = $self->read_from_file($test_bccwj);
    $buff = $self->trans_dataformat($buff, "input-bccwj", "bccwj");
    $self->write_to_file($tmp_test_bccwj, $buff);
    undef $buff;

    my $kc_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC";
    my $kc_bout_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC.bout";
    my $bccwj_bout_file = $save_dir."/".File::Basename::basename($test_bccwj).".bout";

    $self->bccwj2kc_file($tmp_test_bccwj, $kc_file);
    $self->METHOD_kc2bnstout($kc_file, $bnstmodel, $tmp_dir);
    $self->merge_bccwj_with_kc_bout_file($tmp_test_bccwj, $kc_bout_file, $bccwj_bout_file);
}

sub merge_bccwj_with_kc_bout_file {
    my ($self, $bccwj_file, $kc_bout_file, $bout_file) = @_;
    my $bccwj_data = $self->read_from_file($bccwj_file);
    my $kc_bout_data = $self->read_from_file($kc_bout_file);

    my $bout_data = "";
    my @m = split(/\r?\n/, $kc_bout_data);
    undef $kc_bout_data;

    foreach ( split(/\r?\n/, $bccwj_data) ) {
        my $item_list = [split(/\t/)];
        my $lw = shift(@m);
        $lw = shift(@m) if $lw =~ /^EOS|^\*B/;
        my @ml = split(/[ \t]/, $lw);
        $$item_list[26] = $ml[0];
        $bout_data .= join("\t",@$item_list)."\n";
    }
    undef $bccwj_data;

    $self->write_to_file($bout_file, $bout_data);
    undef $bout_data;
}


sub USAGE_kc2bnsteval {
    my $self = shift;
    printf("COMAINU-METHOD: kc2bnsteval\n");
    printf("  Usage: %s kc2bnsteval <ref-kc> <kc-lout> <out-dir>\n", $0);
    printf("    This command make a evaluation for <kc-lout> with <ref-kc>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  perl ./script/comainu.pl kc2bnsteval sample/sample.KC out/sample.KC.bout out\n");
    printf("    -> out/sample.eval.bnst\n");
    printf("\n");
}

sub METHOD_kc2bnsteval {
    my ($self, $correct_kc, $result_kc_lout, $save_dir) = @_;

    mkdir($save_dir) unless -d $save_dir;

    if ( -f $result_kc_lout ) {
        $self->kc2bnsteval_internal($correct_kc, $result_kc_lout, $save_dir);
    } elsif ( -d $result_kc_lout ) {
        opendir(my $dh, $result_kc_lout);
        while ( my $result_kc_lout_file = readdir($dh) ) {
            if ( $result_kc_lout_file =~ /.KC$/ ) {
                $self->kc2bnsteval_internal($correct_kc, $result_kc_lout_file, $save_dir);
            }
        }
        closedir($dh);
    } else {
        printf(STDERR "# Error: Not found result_kc_lout '%s'\n", $result_kc_lout);
    }
    return 0;
}

sub kc2bnsteval_internal {
    my ($self, $correct_kc, $result_kc_lout, $save_dir) = @_;
    $self->_compare_bnst($correct_kc, $result_kc_lout, $save_dir);
}


############################################################

########################################
# 文節，長単位の同時出力
########################################
sub USAGE_bccwj2longbnstout {
    my $self = shift;
    printf("COMAINU-METHOD: bccwj2longbnstout\n");
    printf("  Usage: %s bccwj2longbnstout <long-train-kc> <test-bccwj> <long-model-file> <bnst-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-bccwj> with <long-train-kc>, <long-model-file> and <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwj2longbnstout train.KC sample/sample.bccwj.txt train/CRF/train.KC.model train/bnst.model out\n");
    printf("    -> out/sample.bccwj.txt.lbout\n");
    printf("\n");
}

sub METHOD_bccwj2longbnstout {
    my ($self, $long_train_kc, $test_bccwj, $luwmodel, $bnstmodel, $save_dir ) = @_;

    if ( -f $test_bccwj ) {
        # unless ( -f $long_train_kc ) {
        #     printf(STDERR "ERROR: '%s' not found or not a file.\n",
        #            $long_train_kc);
        #     die;
        # }
        $self->check_luwmodel($luwmodel);
        unless ( -f $bnstmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $bnstmodel);
            die;
        }
        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_bccwj ) {
            $self->bccwj2longbnstout_internal($long_train_kc, $test_bccwj, $luwmodel, $bnstmodel, $save_dir);
        } elsif ( -d $test_bccwj ) {
            opendir(my $dh, $test_bccwj);
            while ( my $test_bccwj_file = readdir($dh) ) {
                if ( $test_bccwj_file =~ /.txt$/ ) {
                    $self->bccwj2longbnstout_internal($long_train_kc, $test_bccwj_file, $luwmodel, $bnstmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid test_bccwj='%s' arg\n", $test_bccwj);
    }
    return 0;
}

sub bccwj2longbnstout_internal {
    my ($self, $long_train_kc, $test_bccwj, $luwmodel, $bnstmodel, $save_dir) = @_;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    my $tmp_dir = $self->{"comainu-temp"};
    my $tmp_test_bccwj = $tmp_dir."/".File::Basename::basename($test_bccwj);
    my $buff = $self->read_from_file($test_bccwj);
    $buff = $self->trans_dataformat($buff, "input-bccwj", "bccwj");
    $self->write_to_file($tmp_test_bccwj, $buff);
    undef $buff;

    my $kc_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC";
    my $kc_lout_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC.lout";
    my $kc_bout_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC.bout";
    my $bccwj_lbout_file = $save_dir."/".File::Basename::basename($test_bccwj).".lbout";

    $self->{"bnst_process"} = "with_luw";

    $self->bccwj2kc_file($tmp_test_bccwj, $kc_file);
    $self->METHOD_kc2longout($long_train_kc, $kc_file, $luwmodel, $tmp_dir);
    $self->METHOD_kc2bnstout($kc_file, $bnstmodel, $tmp_dir);
    $self->merge_bccwj_with_kc_lout_file($tmp_test_bccwj, $kc_lout_file, $bccwj_lbout_file);
    $self->merge_bccwj_with_kc_bout_file($bccwj_lbout_file, $kc_bout_file, $bccwj_lbout_file);

    return;
}

############################################################

########################################
# 中単位解析
########################################

sub USAGE_kclong2midmodel {
    my $self = shift;
    printf("COMAINU-METHOD: kclong2midmodel\n");
    printf("  Usage: %s kclong2midmodel <train-kc> <mid-model-dir>\n", $0);
    printf("    This command trains model from <train-kc> into <mid-model-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl kclong2midmodel sample/sample.KC train\n");
    printf("    -> train/sample.KC.model\n");
    printf("\n");
}

sub METHOD_kclong2midmodel {
    my ($self, $train_kc, $model_dir) = @_;
    # mstparserのディレクトリの存在確認
    unless ( -d $self->{"mstparser-dir"} ) {
        printf(STDERR "ERROR: Not found MSTPARSER_DIR '%s'.\n",
               $self->{"mstparser-dir"});
        return 1;
    }
    unless ( $model_dir ) {
        $model_dir = File::Basename::dirname($train_kc);
    }
    my $mstparser_dir = $self->get_mstparser_dir();

    return 1 unless defined($mstparser_dir);

    $self->training_mid_train1($train_kc, $model_dir);
    $self->training_mid_train2($train_kc, $model_dir);

    return 0;
}


sub USAGE_kclong2midout {
    my $self = shift;
    printf("COMAINU-METHOD: kclong2midout\n");
    printf("  Usage: %s kclong2midout <test-kc> <mid-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <mid-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl kclong2midout sample/sample.KC train/sample.KC.model out\n");
    printf("    -> out/sample.KC.mout\n");
    printf("\n");
}

sub METHOD_kclong2midout {
    my ($self, $test_kc, $muwmodel, $save_dir ) = @_;

    if ( -f $test_kc ) {
        unless ( -f $muwmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $muwmodel);
            die;
        }
        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_kc ) {
            $self->kclong2midout_internal($test_kc, $muwmodel, $save_dir);
        } elsif ( -d $test_kc ) {
            opendir(my $dh, $test_kc);
            while ( my $test_kc_file = readdir($dh) ) {
                if ( $test_kc_file =~ /.KC$/ ) {
                    $self->kclong2midout_internal($test_kc_file, $muwmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid [test_kc] arg\n");
    }
    return 0;
}

sub kclong2midout_internal {
    my ($self, $test_kc, $muwmodel, $save_dir ) = @_;

    my $tmp_test_kc = $self->{"comainu-temp"}."/".File::Basename::basename($test_kc);
    my $buff = $self->read_from_file($test_kc);
    $buff = $self->trans_dataformat($buff, "input-kc", "kc_mid");
    $self->write_to_file($tmp_test_kc, $buff);
    undef $buff;

    $self->_mid_process1($tmp_test_kc);
    $self->_mid_process2($tmp_test_kc, $muwmodel, $save_dir);
    $self->_mid_process3($tmp_test_kc, $save_dir);
}

sub USAGE_kclong2mideval {
    my $self = shift;
    printf("COMAINU-METHOD: kclong2mideval\n");
    printf("  Usage: %s kclong2mideval <ref-kc> <kc-mout> <out-dir>\n", $0);
    printf("    This command make a evaluation for <kc-mout> with <ref-kc>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  perl ./script/comainu.pl kclong2mideval sample/sample.KC out/sample.KC.mout out\n");
    printf("    -> out/sample.eval.mid\n");
    printf("\n");
}

sub METHOD_kclong2mideval {
    my ($self, $correct_kc, $result_kc_mout, $save_dir) = @_;

    if ( -f $result_kc_mout ) {
        $self->kclong2mideval_internal($correct_kc, $result_kc_mout, $save_dir);
    } elsif ( -d $result_kc_mout ) {
        opendir(my $dh, $result_kc_mout);
        while ( my $result_kc_mout_file = readdir($dh) ) {
            if ( $result_kc_mout_file =~ /.KC$/ ) {
                $self->kclong2mideval_internal($correct_kc, $result_kc_mout_file, $save_dir);
            }
        }
        closedir($dh);
    } else {
        printf(STDERR "# Error: Not found result_kc_mout '%s'\n", $result_kc_mout);
    }
    return 0;
}

sub kclong2mideval_internal {
    my ($self, $correct_kc, $result_kc_mout, $save_dir) = @_;
    $self->_compare_mid($correct_kc, $result_kc_mout, $save_dir);
}


sub lout2kc4mid_file {
    my ($self, $kc_lout_file, $kc_file) = @_;

    my $kc_lout_data = $self->read_from_file($kc_lout_file);
    my $kc_buff = "";
    foreach my $line ( split(/\r?\n/, $kc_lout_data) ) {
        my @items = split(/[ \t]/, $line);
        if ( $items[0] =~ /^EOS/ ) {
            $kc_buff .= "EOS\n";
            next;
        }
        $kc_buff .= join(" ", @items[1..$#items-1])."\n";
    }
    $self->write_to_file($kc_file, $kc_buff);

    undef $kc_lout_data;
    undef $kc_buff;
}

sub USAGE_bccwjlong2midout {
    my $self = shift;
    printf("COMAINU-METHOD: bccwjlong2midout\n");
    printf("  Usage: %s bccwjlong2midout <test-kc> <mid-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <mid-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwjlong2midout sample/sample.bccwj.txt train/MST/train.KC.model out\n");
    printf("    -> out/sample.bccwj.txt.mout\n");
    printf("\n");
}

sub METHOD_bccwjlong2midout {
    my ($self, $test_bccwj, $muwmodel, $save_dir ) = @_;

    if ( -f $test_bccwj ) {
        unless ( -f $muwmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $muwmodel);
            die;
        }
        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_bccwj ) {
            $self->bccwjlong2midout_internal($test_bccwj, $muwmodel, $save_dir);
        } elsif ( -d $test_bccwj ) {
            opendir(my $dh, $test_bccwj);
            while ( my $test_bccwj_file = readdir($dh) ) {
                if ( $test_bccwj_file =~ /.txt$/ ) {
                    $self->bccwjlong2midout_internal($test_bccwj_file, $muwmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid test_bccwj='%s' arg\n", $test_bccwj);
    }
    return 0;
}

sub bccwjlong2midout_internal {
    my ($self, $test_bccwj, $muwmodel, $save_dir ) = @_;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    my $tmp_dir = $self->{"comainu-temp"};
    my $tmp_test_bccwj = $tmp_dir."/".File::Basename::basename($test_bccwj);
    my $buff = $self->read_from_file($test_bccwj);
    $buff = $self->trans_dataformat($buff, "input-bccwj", "bccwj");
    $self->write_to_file($tmp_test_bccwj, $buff);
    undef $buff;

    my $kc_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC";
    my $kc_mout_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC.mout";
    my $bccwj_mout_file = $save_dir."/".File::Basename::basename($test_bccwj).".mout";

    $self->bccwj2kc_file2($tmp_test_bccwj, $kc_file);
    $self->METHOD_kclong2midout($kc_file, $muwmodel, $tmp_dir);
    # $self->merge_bccwj_with_mout_file($tmp_test_bccwj, $kc_mout_file, $bccwj_mout_file);
    $self->merge_bccwj_with_kc_mout_file($tmp_test_bccwj, $kc_mout_file, $bccwj_mout_file);
}

sub bccwj2kc_file2 {
    my ($self, $bccwj_file, $kc_file) = @_;
    my $buff = $self->read_from_file($bccwj_file);
    $buff = $self->bccwj2kc_with_luw($buff);
    $self->write_to_file($kc_file, $buff);
    undef $buff;
}


sub USAGE_bccwj2midout {
    my $self = shift;
    printf("COMAINU-METHOD: bccwj2midout\n");
    printf("  Usage: %s bccwj2midout <long-train-kc> <test-kc> <long-model-file> <mid-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <long-train-kc>, <long-model-file> and <mid-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwj2midout train.KC sample/sample.bccwj.txt trian/SVM/train.KC.model train/MST/train.KC.model out\n");
    printf("    -> out/sample.bccwj.txt.mout\n");
    printf("\n");
}

sub METHOD_bccwj2midout {
    my ($self, $long_train_kc, $test_bccwj, $luwmodel, $muwmodel, $save_dir ) = @_;

    if ( -f $test_bccwj ) {
    	$self->check_luwmodel($luwmodel);
        unless ( -f $muwmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $muwmodel);
            die;
        }
        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_bccwj ) {
            $self->bccwj2midout_internal($long_train_kc, $test_bccwj, $luwmodel, $muwmodel, $save_dir);
        } elsif ( -d $test_bccwj ) {
            opendir(my $dh, $test_bccwj);
            while ( my $test_bccwj_file = readdir($dh) ) {
                if ( $test_bccwj_file =~ /.txt$/ ) {
                    $self->bccwj2midout_internal($long_train_kc, $test_bccwj_file, $luwmodel, $muwmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid test_bccwj='%s' arg\n", $test_bccwj);
    }
    return 0;
}

sub bccwj2midout_internal {
    my ($self, $long_train_kc, $test_bccwj, $luwmodel, $muwmodel, $save_dir) = @_;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    my $tmp_dir = $self->{"comainu-temp"};
    my $tmp_test_bccwj = $tmp_dir."/".File::Basename::basename($test_bccwj);
    my $buff = $self->read_from_file($test_bccwj);
    $buff = $self->trans_dataformat($buff, "input-bccwj", "bccwj");
    $self->write_to_file($tmp_test_bccwj, $buff);
    undef $buff;

    my $kc_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC";
    my $kc_lout_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC.lout";
    my $kc_mout_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC.mout";
    my $bccwj_mout_file = $save_dir."/".File::Basename::basename($test_bccwj).".mout";

    $self->bccwj2kc_file($tmp_test_bccwj, $kc_file);
    $self->METHOD_kc2longout($long_train_kc, $kc_file, $luwmodel, $tmp_dir);
    $self->lout2kc4mid_file($kc_lout_file, $kc_file);
    $self->METHOD_kclong2midout($kc_file, $muwmodel, $tmp_dir);
    $self->merge_bccwj_with_kc_lout_file($tmp_test_bccwj, $kc_lout_file, $bccwj_mout_file);
    $self->merge_bccwj_with_kc_mout_file($bccwj_mout_file, $kc_mout_file, $bccwj_mout_file);
}

sub merge_bccwj_with_kc_mout_file {
    my ($self, $bccwj_file, $kc_mout_file, $mout_file) = @_;

    my $bccwj_data = $self->read_from_file($bccwj_file);
    my $kc_mout_data = $self->read_from_file($kc_mout_file);

    my $mout_data = "";
    my @m = split(/\r?\n/, $kc_mout_data);
    undef $kc_mout_data;

    foreach ( split(/\r?\n/, $bccwj_data) ) {
        my $item_list = [split(/\t/)];
        my $lw = shift(@m);
        $lw = shift(@m) if $lw =~ /^EOS|^\*B/;
        my @ml = split(/[ \t]/, $lw);
        @$item_list[34..36] = @ml[19..21];
        $mout_data .= join("\t",@$item_list)."\n";
    }
    undef $bccwj_data;

    $self->write_to_file($mout_file, $mout_data);
    undef $mout_data;
}

sub USAGE_bccwj2midbnstout {
    my $self = shift;
    printf("COMAINU-METHOD: bccwj2midbnstout\n");
    printf("  Usage: %s bccwj2midbnstout <long-train-kc> <test-kc> <long-model-file> <mid-model-file> <bnst-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <long-train-kc>, <long-model-file>, <mid-model-file> and <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwj2midbnstout train.KC sample/sample.bccwj.txt trian/SVM/train.KC.model train/MST/train.KC.model train/bnst.model out\n");
    printf("    -> out/sample.bccwj.txt.mbout\n");
    printf("\n");
}

sub METHOD_bccwj2midbnstout {
    my ($self, $long_train_kc, $test_bccwj, $luwmodel, $muwmodel, $bnstmodel, $save_dir ) = @_;

    if ( -f $test_bccwj ) {
    	$self->check_luwmodel($luwmodel);
        unless ( -f $muwmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $muwmodel);
            die;
        }
        unless ( -f $bnstmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $bnstmodel);
            die;
        }

        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_bccwj ) {
            $self->bccwj2midbnstout_internal($long_train_kc, $test_bccwj, $luwmodel, $muwmodel, $bnstmodel, $save_dir);
        } elsif ( -d $test_bccwj ) {
            opendir(my $dh, $test_bccwj);
            while ( my $test_bccwj_file = readdir($dh) ) {
                if ( $test_bccwj_file =~ /.txt$/ ) {
                    $self->bccwj2midbnstout_internal($long_train_kc, $test_bccwj_file, $luwmodel, $muwmodel, $bnstmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid test_bccwj='%s' arg\n", $test_bccwj);
    }
    return 0;
}

sub bccwj2midbnstout_internal {
    my ($self, $long_train_kc, $test_bccwj, $luwmodel, $muwmodel, $bnstmodel, $save_dir ) = @_;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    my $tmp_dir = $self->{"comainu-temp"};
    my $tmp_test_bccwj = $tmp_dir."/".File::Basename::basename($test_bccwj);
    my $buff = $self->read_from_file($test_bccwj);
    $buff = $self->trans_dataformat($buff, "input-bccwj", "bccwj");
    $self->write_to_file($tmp_test_bccwj, $buff);
    undef $buff;

    my $kc_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC";
    my $kc_lout_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC.lout";
    my $kc_mout_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC.mout";
    my $kc_bout_file = $tmp_dir."/".File::Basename::basename($test_bccwj).".KC.bout";
    my $bccwj_mbout_file = $save_dir."/".File::Basename::basename($test_bccwj).".mbout";

    $self->{"bnst_process"} = "with_luw";

    $self->bccwj2kc_file($tmp_test_bccwj, $kc_file);
    $self->METHOD_kc2longout($long_train_kc, $kc_file, $luwmodel, $tmp_dir);
    $self->METHOD_kc2bnstout($kc_file, $bnstmodel, $tmp_dir);
    $self->lout2kc4mid_file($kc_lout_file, $kc_file);
    $self->METHOD_kclong2midout($kc_file, $muwmodel, $tmp_dir);
    $self->merge_bccwj_with_kc_lout_file($tmp_test_bccwj, $kc_lout_file, $bccwj_mbout_file);
    $self->merge_bccwj_with_kc_bout_file($bccwj_mbout_file, $kc_bout_file, $bccwj_mbout_file);
    $self->merge_bccwj_with_kc_mout_file($bccwj_mbout_file, $kc_mout_file, $bccwj_mbout_file);

    return;
}


########################################
# 平文からの長単位解析
########################################
sub USAGE_plain2longout {
    my $self = shift;
    printf("COMAINU-METHOD: plain2longout\n");
    printf("  Usage: %s plain2longout <train-kc> <test-text> <long-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-text> with MeCab or Chasen and <train-kc> and <long-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl plain2longout train.KC sample/plain/sample.txt train/CRF/train.KC.model out\n");
    printf("    -> out/sample.txt.lout\n");
    printf("  \$ perl ./script/comainu.pl plain2longout --suwmodel=chasen train.KC sample/plain/sample.txt train/CRF/train.KC.model out\n");
    printf("    -> out/sample.txt.lout\n");
    printf("\n");
}

sub METHOD_plain2longout {
    my ($self, $train_kc, $test_file, $luwmodel, $save_dir ) = @_;

    if ( -f $test_file ) {
        # unless ( -f $train_kc ) {
        #     printf(STDERR "ERROR: '%s' not found or not a file.\n",
        #            $train_kc);
        #     die;
        # }
        $self->check_luwmodel($luwmodel);
        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_file ) {
            $self->plain2longout_internal($train_kc, $test_file, $luwmodel, $save_dir);
        } elsif ( -d $test_file ) {
            opendir(my $dh, $test_file);
            while ( my $test_file2 = readdir($dh) ) {
                if ( $test_file2 =~ /.txt$/ ) {
                    $self->plain2longout_internal($train_kc, $test_file2, $luwmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid test_file='%s' arg\n", $test_file);
    }
    return 0;
}

sub plain2longout_internal {
    my ($self, $train_kc, $test_file, $luwmodel, $save_dir) = @_;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    my $tmp_dir = $self->{"comainu-temp"};
    my $chasen_file = $tmp_dir."/".File::Basename::basename($test_file).".chasen";
    my $mecab_file = $tmp_dir."/".File::Basename::basename($test_file).".mecab";
    my $kc_file = $tmp_dir."/".File::Basename::basename($test_file).".KC";
    my $kc_lout_file = $tmp_dir."/".File::Basename::basename($test_file).".KC.lout";
    my $mecab_lout_file = $save_dir."/".File::Basename::basename($test_file).".lout";

    $self->plain2mecab_file($test_file, $chasen_file, $mecab_file);
    $self->mecab2kc_file($mecab_file, $kc_file);
    $self->METHOD_kc2longout($train_kc, $kc_file, $luwmodel, $tmp_dir);
    $self->merge_mecab_with_kc_lout_file($mecab_file, $kc_lout_file, $mecab_lout_file);
    return;
}

########################################
# 平文からの文節解析
########################################
sub USAGE_plain2bnstout {
    my $self = shift;
    printf("COMAINU-METHOD: plain2bnstout\n");
    printf("  Usage: %s plain2bnstout <test-text> <bnst-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-text> with MeCab or Chasen and <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl plain2bnstout sample/plain/sample.txt train/bnst.model out\n");
    printf("    -> out/sample.txt.bout\n");
    printf("\n");
}

sub METHOD_plain2bnstout {
    my ($self, $test_file, $bnstmodel, $save_dir ) = @_;

    if ( -f $test_file ) {
        unless ( -f $bnstmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $bnstmodel);
            die;
        }
        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_file ) {
            $self->plain2bnstout_internal($test_file, $bnstmodel, $save_dir);
        } elsif ( -d $test_file ) {
            opendir(my $dh, $test_file);
            while ( my $test_file2 = readdir($dh) ) {
                if ( $test_file2 =~ /.txt$/ ) {
                    $self->plain2bnstout_internal($test_file2, $bnstmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid test_mecab='%s' arg\n", $test_file);
    }
    return 0;
}

sub plain2bnstout_internal {
    my ($self, $test_file, $bnstmodel, $save_dir) = @_;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    my $tmp_dir = $self->{"comainu-temp"};
    my $chasen_file = $tmp_dir."/".File::Basename::basename($test_file).".chasen";
    my $mecab_file = $tmp_dir."/".File::Basename::basename($test_file).".mecab";
    my $kc_file = $tmp_dir."/".File::Basename::basename($test_file).".KC";
    my $kc_bout_file = $tmp_dir."/".File::Basename::basename($test_file).".KC.bout";
    my $bout_file = $save_dir."/".File::Basename::basename($test_file).".bout";

    $self->plain2mecab_file($test_file, $chasen_file, $mecab_file);
    $self->mecab2kc_file($mecab_file, $kc_file);
    $self->METHOD_kc2bnstout($kc_file, $bnstmodel, $tmp_dir);
    $self->merge_mecab_with_kc_bout_file($mecab_file, $kc_bout_file, $bout_file);

    return;
}


########################################
# 平文からの長単位・文節解析
########################################
sub USAGE_plain2longbnstout {
    my $self = shift;
    printf("COMAINU-METHOD: plain2longbnstout\n");
    printf("  Usage: %s plain2longbnstout <long-train-kc> <test-text> <long-model-file> <bnst-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-text> with Mecab or ChaSen and <long-train-kc> and <long-model-file> and <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl plain2longbnstout train.KC sample/plain/sample.txt train/CRF/train.KC.model train/bnst.model out\n");
    printf("    -> out/sample.txt.lbout\n");
    printf("\n");
}

sub METHOD_plain2longbnstout {
    my ($self, $long_train_kc, $test_file, $luwmodel, $bnstmodel, $save_dir ) = @_;

    if ( -f $test_file ) {
        # unless ( -f $train_kc ) {
        #     printf(STDERR "ERROR: '%s' not found or not a file.\n",
        #            $train_kc);
        #     die;
        # }
        $self->check_luwmodel($luwmodel);
        unless ( -f $bnstmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $bnstmodel);
            die;
        }
        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_file ) {
            $self->plain2longbnstout_internal($long_train_kc, $test_file, $luwmodel, $bnstmodel, $save_dir);
        } elsif ( -d $test_file ) {
            opendir(my $dh, $test_file);
            while ( my $test_file2 = readdir($dh) ) {
                if ( $test_file2 =~ /.txt$/ ) {
                    $self->plain2longbnstout_internal($long_train_kc, $test_file2, $luwmodel, $bnstmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid test_file='%s' arg\n", $test_file);
    }
    return 0;
}

sub plain2longbnstout_internal {
    my ($self, $long_train_kc, $test_file, $luwmodel, $bnstmodel, $save_dir) = @_;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    my $tmp_dir = $self->{"comainu-temp"};
    my $chasen_file = $tmp_dir."/".File::Basename::basename($test_file).".chasen";
    my $mecab_file = $tmp_dir."/".File::Basename::basename($test_file).".mecab";
    my $kc_file = $tmp_dir."/".File::Basename::basename($test_file).".KC";
    my $kc_lout_file = $tmp_dir."/".File::Basename::basename($test_file).".KC.lout";
    my $kc_bout_file = $tmp_dir."/".File::Basename::basename($test_file).".KC.bout";
    my $lbout_file = $save_dir."/".File::Basename::basename($test_file).".lbout";

    $self->{"bnst_process"} = "with_luw";

    $self->plain2mecab_file($test_file, $chasen_file, $mecab_file);
    $self->mecab2kc_file($mecab_file, $kc_file);
    $self->METHOD_kc2longout($long_train_kc, $kc_file, $luwmodel, $tmp_dir);
    $self->METHOD_kc2bnstout($kc_file, $bnstmodel, $tmp_dir);
    $self->merge_mecab_with_kc_lout_file($mecab_file, $kc_lout_file, $lbout_file);
    $self->merge_mecab_with_kc_bout_file($lbout_file, $kc_bout_file, $lbout_file);
    return;
}


########################################
# 平文からの中単位解析
########################################
sub USAGE_plain2midout {
    my $self = shift;
    printf("COMAINU-METHOD: plain2midout\n");
    printf("  Usage: %s plain2midout <long-train-kc> <test-text> <long-model-file> <mid-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-text> with Mecab or ChaSen and <long-train-kc> and <long-model-file> and <mid-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl plain2midout train.KC sample/plain/sample.txt train/CRF/train.KC.model train/MST/train.KC.model out\n");
    printf("    -> out/sample.txt.mout\n");
    printf("\n");
}

sub METHOD_plain2midout {
    my ($self, $long_train_kc, $test_file, $luwmodel, $muwmodel, $save_dir ) = @_;

    if ( -f $test_file ) {
        # unless ( -f $train_kc ) {
        #     printf(STDERR "ERROR: '%s' not found or not a file.\n",
        #            $train_kc);
        #     die;
        # }
        $self->check_luwmodel($luwmodel);
        unless ( -f $muwmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $muwmodel);
            die;
        }
        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_file ) {
            $self->plain2midout_internal($long_train_kc, $test_file, $luwmodel, $muwmodel, $save_dir);
        } elsif ( -d $test_file ) {
            opendir(my $dh, $test_file);
            while ( my $test_file2 = readdir($dh) ) {
                if ( $test_file2 =~ /.txt$/ ) {
                    $self->plain2midout_internal($long_train_kc, $test_file2, $luwmodel, $muwmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid test_file='%s' arg\n", $test_file);
    }
    return 0;
}

sub plain2midout_internal {
    my ($self, $long_train_kc, $test_file, $luwmodel, $muwmodel, $save_dir) = @_;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    my $tmp_dir = $self->{"comainu-temp"};
    my $chasen_file = $tmp_dir."/".File::Basename::basename($test_file).".chasen";
    my $mecab_file = $tmp_dir."/".File::Basename::basename($test_file).".mecab";
    my $kc_file = $tmp_dir."/".File::Basename::basename($test_file).".KC";
    my $kc_lout_file = $tmp_dir."/".File::Basename::basename($test_file).".KC.lout";
    my $kc_mout_file = $tmp_dir."/".File::Basename::basename($test_file).".KC.mout";
    my $mout_file = $save_dir."/".File::Basename::basename($test_file).".mout";

    $self->plain2mecab_file($test_file, $chasen_file, $mecab_file);
    $self->mecab2kc_file($mecab_file, $kc_file);
    $self->METHOD_kc2longout($long_train_kc, $kc_file, $luwmodel, $tmp_dir);
    $self->lout2kc4mid_file($kc_lout_file, $kc_file);
    $self->METHOD_kclong2midout($kc_file, $muwmodel, $tmp_dir);
    $self->merge_mecab_with_kc_mout_file($mecab_file, $kc_mout_file, $mout_file);

    return;
}


########################################
# 平文からの中単位・文節解析
########################################
sub USAGE_plain2midbnstout {
    my $self = shift;
    printf("COMAINU-METHOD: plain2midbnstout\n");
    printf("  Usage: %s plain2midbnstout <long-train-kc> <test-text> <long-model-file> <mid-model-file> <bnst-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-text> with Mecab or ChaSen and <long-train-kc> and <long-model-file>, <mid-model-file> and <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl plain2midbnstout train.KC sample/plain/sample.txt train/CRF/train.KC.model train/MST/train.KC.model train/bnst.model out\n");
    printf("    -> out/sample.txt.mbout\n");
    printf("\n");
}

sub METHOD_plain2midbnstout {
    my ($self, $long_train_kc, $test_file, $luwmodel, $muwmodel, $bnstmodel, $save_dir ) = @_;

    if ( -f $test_file ) {
        # unless ( -f $train_kc ) {
        #     printf(STDERR "ERROR: '%s' not found or not a file.\n",
        #            $train_kc);
        #     die;
        # }
        $self->check_luwmodel($luwmodel);
        unless ( -f $muwmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $muwmodel);
            die;
        }
        unless ( -f $bnstmodel ) {
            printf(STDERR "ERROR: '%s' not found or not a file.\n",
                   $bnstmodel);
            die;
        }
        mkdir($save_dir) unless -d $save_dir;

        if ( -f $test_file ) {
            $self->plain2midbnstout_internal($long_train_kc, $test_file, $luwmodel, $muwmodel, $bnstmodel, $save_dir);
        } elsif ( -d $test_file ) {
            opendir(my $dh, $test_file);
            while ( my $test_file2 = readdir($dh) ) {
                if ( $test_file2 =~ /.txt$/ ) {
                    $self->plain2midbnstout_internal($long_train_kc, $test_file2, $luwmodel, $muwmodel, $bnstmodel, $save_dir);
                }
            }
            closedir($dh);
        }
    } else {
        printf(STDERR "Error: invalid test_file='%s' arg\n", $test_file);
    }
    return 0;
}

sub plain2midbnstout_internal {
    my ($self, $long_train_kc, $test_file, $luwmodel, $muwmodel, $bnstmodel, $save_dir) = @_;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    my $tmp_dir = $self->{"comainu-temp"};
    my $chasen_file = $tmp_dir."/".File::Basename::basename($test_file).".chasen";
    my $mecab_file = $tmp_dir."/".File::Basename::basename($test_file).".mecab";
    my $kc_file = $tmp_dir."/".File::Basename::basename($test_file).".KC";
    my $kc_lout_file = $tmp_dir."/".File::Basename::basename($test_file).".KC.lout";
    my $kc_mout_file = $tmp_dir."/".File::Basename::basename($test_file).".KC.mout";
    my $kc_bout_file = $tmp_dir."/".File::Basename::basename($test_file).".KC.bout";
    my $mbout_file = $save_dir."/".File::Basename::basename($test_file).".mbout";

    $self->{"bnst_process"} = "with_luw";

    $self->plain2mecab_file($test_file, $chasen_file, $mecab_file);
    $self->mecab2kc_file($mecab_file, $kc_file);
    $self->METHOD_kc2longout($long_train_kc, $kc_file, $luwmodel, $tmp_dir);
    $self->METHOD_kc2bnstout($kc_file, $bnstmodel, $tmp_dir);
    $self->lout2kc4mid_file($kc_lout_file, $kc_file);
    $self->METHOD_kclong2midout($kc_file, $muwmodel, $tmp_dir);
    $self->merge_mecab_with_kc_mout_file($mecab_file, $kc_mout_file, $mbout_file);
    $self->merge_mecab_with_kc_bout_file($mbout_file, $kc_bout_file, $mbout_file);
    return;
}

sub plain2mecab_file {
    my ($self, $test_file, $chasen_file, $mecab_file) = @_;

    my $unidic_dir = $self->{"unidic-dir"};
    my $com = "";
    if ( $self->{"suwmodel"} eq "chasen" ) {
        my $chasen_dir = $self->{"chasen-dir"};
        my $chasenrc = $unidic_dir."/dic/unidic-chasen/chasenrc";
        $com = sprintf("\"%s/chasen\" -r \"%s\" -i w",
                       $chasen_dir, $chasenrc);
    } elsif ( $self->{"suwmodel"} eq "mecab" ) {
        my $mecab_dir = $self->{"mecab-dir"};
        my $mecabdic = $unidic_dir."/dic/unidic-mecab";
        $com = sprintf("\"%s/mecab\" -O%s -d\"%s\" -r\"%s\"",
                       $mecab_dir, $UNIDIC_MECAB_TYPE, $mecabdic, $self->{"mecab_rcfile"});
    }
    if ( $Config{"osname"} eq "MSWin32" ) {
        $com =~ s/\//\\/g;
    }
    print STDERR "# COM: ".$com."\n";
    my $in_buff = $self->read_from_file($test_file);
    my $out_buffs = [];
    $in_buff =~ s/\r?\n$//s;
    foreach my $line (split(/\r?\n/, $in_buff)) {
        $line .= "\n";
        my $out = $self->proc_stdin2stdout($com, $line);
        $out =~ s/\x0d\x0a/\x0a/sg;
        $out .= "EOS" if $out !~ /EOS\s*$/s;
        push @$out_buffs, $out;
    }
    my $out_buff = join "\n", @$out_buffs;
    undef $out_buffs;
    undef $in_buff;

    if ( $self->{"suwmodel"} eq "chasen" ) {
        $self->write_to_file($chasen_file, $out_buff);
        $self->chasen2mecab_file($chasen_file, $mecab_file);
    } elsif ( $self->{"suwmodel"} eq "mecab" ) {
        $self->write_to_file($mecab_file, $out_buff);
    }
    undef $out_buff;
}

sub chasen2mecab_file {
    my ($self, $chasen_file, $kc_file) = @_;
    my $buff = $self->read_from_file($chasen_file);
    $buff = $self->chasen2mecab($buff);
    $self->write_to_file($kc_file, $buff);
    undef $buff;
}

sub mecab2kc_file {
    my ($self, $chasen_file, $kc_file) = @_;
    my $chasen_ext_file = $chasen_file."_ext";
    my $ext_def_file = $self->{"comainu-temp"}."/mecab_ext.def";

    my $def_buff = "";
    $def_buff .= "dbfile:".$self->{"unidic-db"}."\n";
    $def_buff .= "table:lex\n";
    #$def_buff .= "input:sLabel,orth,pron,lForm,lemma[-subLemma],pos,cType?,cForm?,tmp1?,tmp2?\n";
    #$def_buff .= "output:sLabel,orth,pron,lForm,lemma[-subLemma],pos,cType?,cForm?,tmp1?,goshu,form,formBase,formOrthBase,formOrth\n";
    $def_buff .= "input:sLabel,orth,pron,lForm,lemma[-subLemma],pos,cType?,cForm?\n";
    $def_buff .= "output:sLabel,orth,pron,lForm,lemma[-subLemma],pos,cType?,cForm?,goshu,form,formBase,formOrthBase,formOrth\n";
    $def_buff .= "key:lForm,lemma,subLemma,pos,cType,cForm,orth,pron\n";
    $self->write_to_file($ext_def_file, $def_buff);
    undef $def_buff;

    my $perl = $self->{"perl"};
    my $com = sprintf("\"%s\" \"%s/bin/extcorpus.pl\" -C \"%s\"",
		      $perl,
		      $self->{"unidic2-dir"}, $ext_def_file);
    $self->proc_file2file($com, $chasen_file, $chasen_ext_file);

    my $buff = $self->read_from_file($chasen_ext_file);
    $buff = $self->mecab2kc($buff);
    $self->write_to_file($kc_file, $buff);

    undef $buff;
}

sub mecab2kc_file_old {
    my ($self, $chasen_file, $kc_file) = @_;
    my $buff = $self->read_from_file($chasen_file);
    $buff = $self->mecab2kc($buff);
    $self->write_to_file($kc_file, $buff);
    undef $buff;
}

# convert chasen(unidic) to mecab(unidic)
sub chasen2mecab {
    my ($self, $buff) = @_;

    my $table = $MECAB_CHASEN_TABLE;
    my $res_str = "";
    my $item_name_list = [map {$table->{$_};} keys %$table];
    $buff =~ s/\r?\n$//;

    foreach my $line ( split(/\r?\n/, $buff) ) {
        if ( $line =~ /^EOS/ ) {
            $res_str .= $line."\n";
            next;
        }
        if ( $line !~ /<cha:W1.*?<\/cha:W1>/ ) {
            next;
        }
        my $item_map = {};
        foreach my $item_name (@$item_name_list) {
            my ($item_value) = ($line =~ / $item_name=\"(.*?)\"/);
            if(($item_name eq "cType" or $item_name eq "cForm") && !defined($item_value)) {
                $item_value = "";
            }
            $item_value =~ s/\&lt;/\</gs;
            $item_value =~ s/\&gt;/\>/gs;
            $item_value =~ s/\&quot;/\'/gs;
            $item_value =~ s/\&apos;/\"/gs;
            $item_value =~ s/\&amp;/\&/gs;
            $item_map->{$item_name} = $item_value;
        }
        my $value_list = [ map {
            $item_map->{$table->{$_}};
        } sort {$a <=> $b} keys %$table ];
        $res_str .= sprintf("%s\n", join("\t", @$value_list));
    }
    if ( $res_str !~ /EOS\s*$/ ) {
        $res_str .= "EOS\n";
    }

    undef $buff;
    undef $item_name_list;

    return $res_str;
}

sub mecab2kc {
    my ($self, $buff) = @_;
    my $table = $KC_MECAB_TABLE;
    my $res_str = "";
    my $first_flag = 0;
    my $item_name_list = [keys %$table];
    $buff =~ s/\r?\n$//;
    foreach my $line ( split(/\r?\n/, $buff) ) {
        if ( $line =~ /^EOS/ ) {
            $first_flag = 1;
            next;
        }
        my $item_list = [ split(/\t/, $line) ];
        $item_list->[2] = $item_list->[1] if $item_list->[2] eq "";
        $item_list->[3] = $item_list->[1] if $item_list->[3] eq "";
        $item_list->[5] = "*"             if $item_list->[5] eq "";
        $item_list->[6] = "*"             if $item_list->[6] eq "";
        $item_list->[7] = "*"             if $item_list->[7] eq "";

        my $value_list = [ map {
            $table->{$_} eq "*" ? "*" : $item_list->[$table->{$_}];
        } sort {$a <=> $b} keys %$table ];
        $value_list = [ @$value_list, "*", "*", "*", "*", "*", "*", "*", "*" ];
        if ( $first_flag == 1 ) {
            $first_flag = 0;
            $res_str .= "EOS\n";
        }
        $res_str .= sprintf("%s\n", join(" ", @$value_list));
    }
    $res_str .= "EOS\n";

    undef $buff;
    undef $item_name_list;

    return $res_str;
}

sub merge_mecab_with_kc_lout_file {
    my ($self, $mecab_file, $kc_lout_file, $lout_file) = @_;
    my $mecab_data = $self->read_from_file($mecab_file);
    my $kc_lout_data = $self->read_from_file($kc_lout_file);
    my $lout_data = $self->merge_mecab_with_kc($mecab_data, $kc_lout_data);
    undef $mecab_data;
    undef $kc_lout_data;
    $self->write_to_file($lout_file, $lout_data);
    undef $lout_data;
}

sub merge_mecab_with_kc {
    my ($self, $mecab_data, $kc_lout_data) = @_;
    my $kc_lout_data_list = [ split(/\r?\n/, $kc_lout_data) ];
    undef $kc_lout_data;

    my $lout_data = "";
    foreach my $mecab_line ( split(/\r?\n/, $mecab_data) ) {
        if ( $mecab_line =~ /^EOS|^\*B/ ) {
            $lout_data .= $mecab_line."\n";
            next;
        }
        my $mecab_item_list = [ split(/\t/, $mecab_line, -1) ];
        my $kc_lout_line = shift(@$kc_lout_data_list);
        $kc_lout_line = shift(@$kc_lout_data_list) if $kc_lout_line =~ /^EOS/;
        my $kc_lout_item_list = [ split(/[ \t]/, $kc_lout_line) ];
        if ( $mecab_item_list->[0] ne $kc_lout_item_list->[0] ) {
        }
        push(@$mecab_item_list, splice(@$kc_lout_item_list, 14, 6));
        $lout_data .= sprintf("%s\n", join("\t", @$mecab_item_list));
    }
    undef $mecab_data;
    undef $kc_lout_data_list;
    return $lout_data;
}

sub merge_mecab_with_kc_bout_file {
    my ($self, $mecab_file, $kc_bout_file, $bout_file) = @_;
    my $mecab_data = $self->read_from_file($mecab_file);
    my $kc_bout_data = $self->read_from_file($kc_bout_file);

    my $bout_data = "";
    my $kc_bout_data_list = [split(/\r?\n/, $kc_bout_data)];
    undef $kc_bout_data;

    foreach my $mecab_line ( split(/\r?\n/, $mecab_data) ) {
        my $kc_bout_line = shift(@$kc_bout_data_list);
        #$kc_bout_line = shift(@$kc_bout_data_list) if($kc_bout_line =~ /^EOS/);
        if ( $kc_bout_line =~ /B/ ) {
            $bout_data .= "*B\n";
        }
        if ( $mecab_line !~ /^\*B/ ) {
            $bout_data .= $mecab_line."\n";
        }
    }
    undef $mecab_data;
    undef $kc_bout_data_list;

    $self->write_to_file($bout_file, $bout_data);
    undef $bout_data;
}

sub merge_mecab_with_kc_mout_file {
    my ($self, $mecab_file, $kc_mout_file, $mout_file) = @_;
    my $mecab_data = $self->read_from_file($mecab_file);
    my $kc_mout_data = $self->read_from_file($kc_mout_file);

    my $mout_data = "";
    my $kc_mout_data_list = [split(/\r?\n/, $kc_mout_data)];
    undef $kc_mout_data;

    foreach my $mecab_line ( split(/\r?\n/, $mecab_data) ) {
        if ( $mecab_line =~ /^EOS|^\*B/ ) {
            $mout_data .= $mecab_line."\n";
            next;
        }
        my $mecab_item_list = [ split(/\t/, $mecab_line, -1) ];
        my $kc_mout_line = shift(@$kc_mout_data_list);
        $kc_mout_line = shift(@$kc_mout_data_list) if $kc_mout_line =~ /^EOS/;
        my $kc_mout_item_list = [ split(/[ \t]/, $kc_mout_line) ];
        push(@$mecab_item_list, splice(@$kc_mout_item_list, 14, 9));
        $mout_data .= sprintf("%s\n", join("\t", @$mecab_item_list));
    }
    undef $mecab_data;
    undef $kc_mout_data_list;

    $self->write_to_file($mout_file, $mout_data);
    undef $mout_data;
}

# 概要
# 正解KCファイルと長単位解析結果KCファイルを受け取り、
# 処理して".eval.long"ファイルを出力する。
#
# 使用方法
# _compare.sh （正解KCファイル名）（長単位解析結果KCファイル名）（出力ファイル名（拡張子無し））
#
sub _compare {
    my ($self, $arg1, $arg2, $arg3) = @_;
    print STDERR "_compare\n";
    my $res = "";

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    # 中間ファイル名の生成 (1)
    my $tmp1FileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".long";

    # すでに中間ファイルが出来ていれば処理しない
    if ( -s $tmp1FileName ) {
        print STDERR "Use Cache \'$tmp1FileName\'.\n";
    } else {
        # 入力ファイルの存在確認 (1)
        unless ( -f $arg1 ) {
            print STDERR "ERROR: \'$1\' not Found.\n";
            return $res;
        }
        my $buff = $self->read_from_file($arg1);
        $buff = $self->trans_dataformat($buff, "input-kc", "kc");
        $buff = $self->short2long($buff);
        $self->write_to_file($tmp1FileName, $buff);
        undef $buff;
    }

    # 入力ファイルの存在確認 (2)
    unless ( -f $arg2 ) {
        print STDERR "ERROR: \'$2\' not Found.\n";
        return $res;
    }

    # 中間ファイル名の生成 (2)
    my $tmp2FileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg2, ".lout").".svmout_poscreate.long";
    my $buff = $self->read_from_file($arg2);
    $buff = $self->short2long($buff);
    $self->write_to_file($tmp2FileName, $buff);
    undef $buff;

    # 出力ファイル名の生成
    my $outputFileName = $arg3."/".File::Basename::basename($arg2, ".lout").".eval.long";

    $res = $self->eval_long($tmp1FileName, $tmp2FileName);
    $self->write_to_file($outputFileName, $res);
    print $res;

    return $res;
}

sub _compare_mid {
    my ($self, $arg1, $arg2, $arg3) = @_;
    print STDERR "_compare\n";
    my $res = "";

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    # 中間ファイル名の生成 (1)
    my $tmp1FileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".mid";

    # すでに中間ファイルが出来ていれば処理しない
    if ( -s $tmp1FileName ) {
        print STDERR "Use Cache \'$tmp1FileName\'.\n";
    } else {
        # 入力ファイルの存在確認 (1)
        unless ( -f $arg1 ) {
            print STDERR "ERROR: \'$1\' not Found.\n";
            return $res;
        }
        my $buff = $self->read_from_file($arg1);
        $buff = $self->short2middle($buff);
        $self->write_to_file($tmp1FileName, $buff);
        undef $buff;
    }

    # 入力ファイルの存在確認 (2)
    unless ( -f $arg2 ) {
        print STDERR "ERROR: \'$2\' not Found.\n";
        return $res;
    }

    # 中間ファイル名の生成 (2)
    my $tmp2FileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg2, ".lout").".svmout_poscreate.mid";
    my $buff = $self->read_from_file($arg2);
    $buff = $self->short2middle($buff);
    $self->write_to_file($tmp2FileName, $buff);
    undef $buff;

    # 出力ファイル名の生成
    my $outputFileName = $arg3."/".File::Basename::basename($arg2, ".mout").".eval.mid";

    $res = $self->eval_long($tmp1FileName, $tmp2FileName, 1);
    $self->write_to_file($outputFileName, $res);
    print $res;

    return $res;
}

sub _compare_bnst {
    my ($self, $arg1, $arg2, $arg3) = @_;
    print STDERR "_compare\n";
    my $res = "";

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    # 中間ファイル名の生成 (1)
    my $tmp1FileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".bnst";

    # すでに中間ファイルが出来ていれば処理しない
    if ( -s $tmp1FileName ) {
        print STDERR "Use Cache \'$tmp1FileName\'.\n";
    } else {
	# 入力ファイルの存在確認 (1)
        unless ( -f $arg1 ) {
            print STDERR "ERROR: \'$1\' not Found.\n";
            return $res;
        }
        my $buff = $self->read_from_file($arg1);
        $buff = $self->short2bnst($buff);
        $self->write_to_file($tmp1FileName, $buff);
        undef $buff;
    }

    # 入力ファイルの存在確認 (2)
    unless ( -f $arg2 ) {
        print STDERR "ERROR: \'$2\' not Found.\n";
        return $res;
    }

    # 中間ファイル名の生成 (2)
    my $tmp2FileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg2, ".lout").".svmout_poscreate.bnst";
    my $buff = $self->read_from_file($arg2);
    $buff = $self->short2bnst($buff);
    $self->write_to_file($tmp2FileName, $buff);
    undef $buff;

    # 出力ファイル名の生成
    my $outputFileName = $arg3."/".File::Basename::basename($arg2, ".bout").".eval.bnst";

    $res = $self->eval_long($tmp1FileName, $tmp2FileName, 1);
    $self->write_to_file($outputFileName, $res);
    print $res;

    return $res;
}

# 概要
# 解析対象KCファイル名を受け取り、処理して一時保存ディレクトリへ保存する。
#
# 使用方法
# _process1.sh （解析対象KCファイル名）
#
sub _process1 {
    my ($self, $arg1, $arg2, $arg3) = @_;
    print STDERR "_process1\n";
    my $ret = 0;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    # 出力ファイル名の生成
    my $outputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".KC2";

    # すでに同じ名前の中間ファイルがあれば削除
    unlink($outputFileName) if -s $outputFileName;

    my $buff = $self->read_from_file($arg1);
    if ( $self->{"boundary"} ne "sentence" && $self->{"boundary"} ne "word" ) {
        $buff =~ s/^EOS.*?\n//mg;
    }

    $buff = $self->delete_column_long($buff);

    # $buff = $self->add_column($buff);
    # if($self->{"boundary"} ne "none" && $self->{"luwmodel"} eq "SVM") {
	#     $buff = $self->pp_partial($buff);
    # }

    if ( $self->{"boundary"} eq "sentence" ) {
        $buff =~ s/^\*B.*?\n//mg;
    }
    if ( $self->{"luwmodel"} eq "SVM" ) {
        $buff = $self->pp_partial($buff);
    }

    ## 素性の追加
    my $AF = new AddFeature();
    my $NAME = File::Basename::basename($arg2);

    if ( $self->{"luwmodel"} eq "SVM" || $self->{"luwmodel"} eq "CRF" ) {
        my ($Filename, $Path) = File::Basename::fileparse($arg3);
        $buff = $AF->add_feature($buff, $NAME, $Path);
    } elsif ( $self->{"luwmodel"} eq "MIRA" ) {
        $buff = $AF->add_feature($buff, $NAME, $arg3);
    }

    $self->write_to_file($outputFileName, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink($outputFileName) unless -s $outputFileName;

    return $ret;
}

# 概要
# 解析対象KCファイル名とモデルファイル名を受け取り、処理して一時保存ディレクトリへ保存する。
# yamchaを使う
#
# 使用方法
# _process2.sh （解析対象KCファイル名）（モデルファイル名）
# _process2_2.sh （解析対象KCファイル名）（モデルファイル名）
#
sub _process2 {
    my ($self, $arg1, $arg2) = @_;
    print STDERR "_process2\n";
    my $yamcha_opt = "";
    if($self->{"boundary"} eq "sentence" || $self->{"boundary"} eq "word") {
        # sentence/word boundary
        $yamcha_opt = "-C";
    }
    my $ret = 0;

    my $YAMCHA = $self->{"yamcha-dir"}."/yamcha";
    if($Config{"osname"} eq "MSWin32") {
        $YAMCHA .= ".exe";
    }

    if(! -x $YAMCHA) {
        printf(STDERR "WARNING: %s Not Found or executable YAMCHA module.\n",
               $YAMCHA);
        exit 0;
    }

    # 入力ファイル名の生成
    my $inputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".KC2";

    # 出力ファイル名の生成
    my $outputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".svmout";

    # すでに同じ名前の中間ファイルがあれば削除
    unlink($outputFileName) if -s $outputFileName;

    # 入力ファイルの存在確認 (1)
    exit 0 unless $self->exists_file($arg2);

    # 入力ファイルの存在確認 (2)
    exit 0 unless $self->exists_file($inputFileName);

    my $buff = $self->read_from_file($inputFileName);
    # YAMCHA用に明示的に最終行に改行を付けさせる
    $buff .= "\n";
    $self->write_to_file($inputFileName, $buff);

    my $yamcha_com = "\"".$YAMCHA."\" ".$yamcha_opt." -m \"".$arg2."\"";
    printf(STDERR "# YAMCHA_COM: %s\n", $yamcha_com);
    if ( $self->{"debug"} > 0 ) {
        printf(STDERR "# YAMCHA_COM: %s\n", $yamcha_com);
    }
    $buff = $self->proc_stdin2stdout($yamcha_com, $buff);
    $buff =~ s/\x0d\x0a/\x0a/sg;
    $buff =~ s/^\r?\n//mg;
    $buff = $self->move_future_front($buff);
    $buff = $self->truncate_last_column($buff);
    $self->write_to_file($outputFileName, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink($outputFileName) unless -s $outputFileName;

    return $ret;
}

##############################################
## for CRF
##############################################
sub _crf_process2 {
    my ($self, $arg1, $arg2) = @_;
    print STDERR "_process2\n";
    my $crf_opt = "";
    my $ret = 0;

    my $CRF = $self->{"crf-dir"}."/crf_test";
    if ( $Config{"osname"} eq "MSWin32" ) {
        $CRF .= ".exe";
    }

    unless ( -x $CRF ) {
        printf(STDERR "WARNING: %s Not Found or executable CRF module.\n",
               $CRF);
        exit 0;
    }

    # 入力ファイル名の生成
    my $inputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".KC2";

    # 出力ファイル名の生成
    my $outputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".svmout";

    # すでに同じ名前の中間ファイルがあれば削除
    unlink($outputFileName) if -s $outputFileName;

    # 入力ファイルの存在確認 (1)
    exit 0 unless $self->exists_file($arg2);

    # 入力ファイルの存在確認 (2)
    exit 0 unless $self->exists_file($inputFileName);

    my $buff = $self->read_from_file($inputFileName);
    $buff =~ s/^EOS.*?//mg;
    # CRF++用に明示的に最終行に改行を付けさせる
    $buff .= "\n";
    $self->write_to_file($inputFileName, $buff);

    my $crf_com = "\"$CRF\" -m \"$arg2\"";
    printf(STDERR "# CRF_COM: %s\n", $crf_com);
    if ( $self->{"debug"} > 0 ) {
        printf(STDERR "# CRF_COM: %s\n", $crf_com);
    }

    $buff = $self->proc_stdin2stdout($crf_com, $buff);
    $buff =~ s/\x0d\x0a/\x0a/sg;
    $buff =~ s/^\r?\n//mg;
    $buff = $self->move_future_front($buff);
    $buff = $self->truncate_last_column($buff);
    $self->write_to_file($outputFileName, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink($outputFileName) unless -s $outputFileName;

    return $ret;
}

##############################################
## for MIRA
##############################################
sub _mira_process2 {
    my ($self, $arg1, $arg2) = @_;
    print STDERR "_process2\n";
    my $mira_opt = "";
    my $ret = 0;

    my $MIRA = $self->{"mira-dir"}."/mira-predict";
    if ( $Config{"osname"} eq "MSWin32" ) {
        $MIRA .= ".exe";
    }

    unless ( -x $MIRA ) {
        printf(STDERR "WARNING: %s Not Found or executable MIRA module.\n",
               $MIRA);
        exit 0;
    }

    # 入力ファイル名の生成
    my $inputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".KC2";

    # 出力ファイル名の生成
    my $outputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".svmout";

    # すでに同じ名前の中間ファイルがあれば削除
    unlink($outputFileName) if -s $outputFileName;

    # 入力ディレクトリの存在確認
    exit 0 unless -d $arg2;

    # 入力ファイルの存在確認
    exit 0 unless $self->exists_file($inputFileName);

    my $buff = $self->read_from_file($inputFileName);
    $buff =~ s/ /\t/mg;
    $buff =~ s/^EOS.*?//mg;
    # MIRA用に明示的に最終行に改行を付けさせる
    $buff .= "\n";
    $self->write_to_file($inputFileName, $buff);

    my $mira_com = "\"$MIRA\" -m \"$arg2\"";
    printf(STDERR "# MIRA_COM: %s\n", $mira_com);
    if ( $self->{"debug"} > 0 ) {
        printf(STDERR "# MIRA_COM: %s\n", $mira_com);
    }
    $buff = $self->proc_stdin2stdout($mira_com, $buff);
    $buff =~ s/\x0d\x0a/\x0a/sg;
    $buff = $self->move_future_front($buff);
    $buff =~ s/^ EOS.*\r?\n//mg;
    $buff = $self->truncate_last_column($buff);
    $self->write_to_file($outputFileName, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink($outputFileName) unless -s $outputFileName;

    return $ret;
}

# 概要
# 辞書用KCファイル名を受け取り、処理して一時保存ディレクトリへ保存する。
#
# 使用方法
# _process3.sh （辞書用KCファイル名）
#
sub _process3 {
    my ($self, $arg1) = @_;
    print STDERR "_process3\n";
    my $ret = 0;
    # databaseファイル名
    my $databaseFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".database";
    # 出力ファイル名の生成
    my $outputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".db.1";

    # すでにdatabaseファイルが出来ていれば処理しない
    if ( -s $databaseFileName ) {
        printf(STDERR "Use Cache '%s'\n", $databaseFileName);
        return 0;
    }

    # すでに中間ファイルが出来ていれば処理しない
    if ( -s $outputFileName ) {
        printf(STDERR "Use Cache '%s'\n", $outputFileName);
        return 0;
    }

    # 入力ファイルの存在確認 (1)
    exit 0 unless $self->exists_file($arg1);

    # 先頭が'*' で始まる行と、 EOS となる行を削除
    open(my $fh_in, "<", $arg1) or die "Cannot open '$arg1'";
    open(my $fh_out, ">", $outputFileName) or die "Cannot open '$outputFileName'";
    binmode($fh_out);
    while ( my $line = <$fh_in> ) {
        $line = Encode::decode("utf-8", $line);
        $line =~ s/\r?\n/\n/;
        next if $line =~ /^\*.*$/ or $line =~ /^EOS.*$/;
        $line = Encode::encode("utf-8", $line);
        printf($fh_out "%s", $line);
    }
    close($fh_out);
    close($fh_in);

    # 不十分な中間ファイルならば、削除しておく
    unlink($outputFileName) unless -s $outputFileName;

    return $ret;
}

# _process4.sh
#
# 概要
# 辞書用KCファイル名を受け取り、処理して一時保存ディレクトリへ保存する。
#
# 使用方法
# _process4.sh （辞書用KCファイル名）
#
sub _process4 {
    my ($self, $arg1) = @_;
    print STDERR "_process4\n";
    my $ret = 0;
    # 入力ファイル名の生成
    my $inputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".db.1";
    # 出力ファイル名の生成
    my $outputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".database";

    # すでに中間ファイルが出来ていれば処理しない
    if ( -s $outputFileName ) {
        printf(STDERR "Use Cache '%s'\n", $outputFileName);
        return 0;
    }

    # 入力ファイルの存在確認 (1)
    exit 0 unless $self->exists_file($arg1);

    # 入力ファイルの存在確認 (2)
    exit 0 unless $self->exists_file($inputFileName);

    open(my $fh_ref, "<", $inputFileName) or die "Cannot open '$inputFileName'";
    open(my $fh_in, "<", $inputFileName) or die "Cannot open '$inputFileName'";
    open(my $fh_out, ">", $outputFileName) or die "Cannot open '$outputFileName'";
    binmode($fh_out);
    $self->add_pivot_to_kc2($fh_ref, $fh_in, $fh_out, 0);
    close($fh_out);
    close($fh_in);
    close($fh_ref);

    # 不十分な中間ファイルならば、削除しておく
    unlink($outputFileName) unless -s $outputFileName;

    return $ret;
}

# 概要
# 辞書用KCファイル名と解析対象KCファイル名と出力ディレクトリ名を受け取り、
# 処理して指定のディレクトリへ結果を保存する。
#
# 使用方法
# _process5.sh （辞書用KCファイル名）（解析対象KCファイル名）（保存先ディレクトリ名）
#
sub _process5 {
    my ($self, $arg1, $arg2, $arg3) = @_;
    print STDERR "_process5\n";
    my $ret = 0;
    # 入力ファイル名の生成 (1)
    # my $input1FileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".database";
    # 入力ファイル名の生成 (2)
    my $input2FileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg2, ".KC").".svmout";
    # 出力ファイル名の生成
    my $outputFileName = $arg3."/".File::Basename::basename($arg2).".lout";

    # 入力ファイルの存在確認 (1)
    # exit 1 unless $self->exists_file($input1FileName);
    # 入力ファイルの存在確認 (2)
    exit 1 unless $self->exists_file($input2FileName);

    ## poscreate
    # my $POSCREATE;
    # print $ENV{"PRCCHARCODE"}."\n";
    # if($ENV{"PRCCHARCODE"} ne "euc") {
    #     print "poscreate\n";
    #     $POSCREATE = $self->{"poscreate"}."/poscreate";
    # } else {
    #     print "poscreate_euc\n";
    #     printf(STDERR "ERROR: poscreate_euc not found.\n");
    #     exit 1;
    # }

    ## suw2luw
    # my $SUW2LUW=$self->{"comainu-home"}."/suw2luw";
    # my $InflFile=$SUW2LUW."/Infl.txt";
    # my $DerivFile=$SUW2LUW."/Deriv.txt";
    # my $CompFile=$SUW2LUW."/Comp.txt";
    # my $suw2luw = SUW2LUW->new();

    # my $buff = "";
    # my $proc1 = "\"".$POSCREATE."\" \"".$input1FileName."\" \"".$input2FileName."\"";
    # $buff = $self->proc_stdin2stdout($proc1, $buff);
    # $buff = $self->poscreate($input2FileName);
    # $buff = $self->pp_ctype($buff);
    # $buff = $suw2luw->suw2luw($buff, $InflFile, $DerivFile, $CompFile);

    my $buff = $self->merge_kc_with_svmout($arg2, $input2FileName);
    $self->write_to_file($outputFileName, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink($outputFileName) unless -s $outputFileName;

    return $ret;
}

sub _process6 {
    my ($self, $arg1, $arg2, $arg3, $arg4) = @_;
    my $ret = 0;
    print STDERR "_process6\n";

    my $YAMCHA = $self->{"yamcha-dir"}."/yamcha";
    if($Config{"osname"} eq "MSWin32") {
        $YAMCHA .= ".exe";
    }
    $YAMCHA = sprintf("\"%s\" -C", $YAMCHA);

    my $TRAINNAME = File::Basename::basename($arg3, ".model");
    my $TESTNAME = File::Basename::basename($arg2);
    my $loutFile = $arg4."/".$TESTNAME.".lout";
    my $lout_data = $self->read_from_file($loutFile);
    my $temp_dir = $self->{"comainu-temp"};
    my $model_dir = File::Basename::dirname($arg3);
    my $BIP_model_dir = $self->{"comainu-svm-bip-model"};

    ## suw2luw
    my $SUW2LUW=$self->{"comainu-home"}."/suw2luw";
    # my $InflFile=$SUW2LUW."/Infl.txt";
    # my $DerivFile=$SUW2LUW."/Deriv.txt";
    my $CompFile=$SUW2LUW."/Comp.txt";

    if($self->{"debug"} > 0) {
        printf(STDERR "# BIP_model_dir: %s\n", $BIP_model_dir);
    }

    my $BIP = new BIProcessor();
    my $buff = $BIP->execute_test($YAMCHA, $TRAINNAME, $TESTNAME, $lout_data,
                                  $temp_dir, $BIP_model_dir, $arg4, $CompFile);
    undef $lout_data;

    $buff = $self->create_long_lemma($buff, $CompFile);

    # my $suw2luw = SUW2LUW->new();
    # $buff = $self->pp_ctype($buff);
    # $buff = $suw2luw->suw2luw($buff, $InflFile, $DerivFile, $CompFile);

    my $outputFileName = $loutFile;
    #$buff = $self->pp_ctype($buff);
    $self->write_to_file($outputFileName, $buff);
    undef $buff;

    return $ret;
}

#####################
## for CRF++
#####################
sub _crf_process6 {
    my ($self, $arg1, $arg2, $arg3, $arg4) = @_;
    my $ret = 0;
    print STDERR "_process6\n";

    my $CRF = $self->{"crf-dir"}."/crf_test";
    if ( $Config{"osname"} eq "MSWin32" ) {
        $CRF .= ".exe";
    }
    my $TRAINNAME = File::Basename::basename($arg3, ".model");
    my $TESTNAME = File::Basename::basename($arg2);
    my $loutFile = $arg4."/".$TESTNAME.".lout";
    my $lout_data = $self->read_from_file($loutFile);
    my $temp_dir = $self->{"comainu-temp"};
    my $model_dir = File::Basename::dirname($arg3);

    my $BIP = new BIProcessor("model_type"=>1);
    my $buff = $BIP->execute_test($CRF, $TRAINNAME, $TESTNAME, $lout_data,
                                  $temp_dir, $model_dir, $arg4);
    undef $lout_data;

    ## suw2luw
    my $SUW2LUW=$self->{"comainu-home"}."/suw2luw";
    my $InflFile=$SUW2LUW."/Infl.txt";
    my $DerivFile=$SUW2LUW."/Deriv.txt";
    my $CompFile=$SUW2LUW."/Comp.txt";
    my $suw2luw = SUW2LUW->new();
    #$buff = $self->pp_ctype($buff);
    $buff = $suw2luw->suw2luw($buff, $InflFile, $DerivFile, $CompFile);

    my $outputFileName = $loutFile;
    #$buff = $self->pp_ctype($buff);
    $self->write_to_file($outputFileName, $buff);
    undef $buff;

    return $ret;
}

#######################
## for MIRA
#######################
sub _mira_process6 {
    my ($self, $arg1, $arg2, $arg3, $arg4) = @_;
    my $ret = 0;
    print STDERR "_process6\n";

    my $MIRA = $self->{"mira-dir"}."/mira-predict";
    if ( $Config{"osname"} eq "MSWin32" ) {
        $MIRA .= ".exe";
    }
    my $TRAINNAME = File::Basename::basename($arg1);
    my $TESTNAME = File::Basename::basename($arg2);
    my $loutFile = $arg4."/".$TESTNAME.".lout";
    my $lout_data = $self->read_from_file($loutFile);
    my $temp_dir = $self->{"comainu-temp"};

    my $BIP = new BIProcessor("model_type"=>2);
    my $buff = $BIP->execute_test($MIRA, $TRAINNAME, $TESTNAME, $lout_data,
                                  $temp_dir, $arg3, $arg4);
    undef $lout_data;

    ## suw2luw
    my $SUW2LUW=$self->{"comainu-home"}."/suw2luw";
    my $InflFile=$SUW2LUW."/Infl.txt";
    my $DerivFile=$SUW2LUW."/Deriv.txt";
    my $CompFile=$SUW2LUW."/Comp.txt";
    my $suw2luw = SUW2LUW->new();
    #$buff = $self->pp_ctype($buff);
    $buff = $suw2luw->suw2luw($buff, $InflFile, $DerivFile, $CompFile);

    my $outputFileName = $loutFile;
    #$buff = $self->pp_ctype($buff);
    $self->write_to_file($outputFileName, $buff);
    undef $buff;

    return $ret;
}

# 概要
# 文節解析用ファイルの作成
#
sub _bnst_process1 {
    my ($self, $arg1) = @_;
    print STDERR "_process1\n";
    my $ret = 0;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    # 出力ファイル名の生成
    my $outputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".svmdata";

    # すでに同じ名前の中間ファイルがあれば削除
    unlink($outputFileName) if -s $outputFileName;

    my $buff = $self->read_from_file($arg1);
    $buff = $self->kc2bnstsvmdata($buff, 0);
    #$buff = $self->add_column("*B\n".$buff);

    if ( $self->{"bnst_process"} eq "with_luw" ) {
        ## 長単位解析の出力結果
        my $svmoutFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".svmout";
        $buff = $self->pp_partial_bnst_with_luw($buff, $svmoutFileName);
    } elsif ( $self->{"boundary"} ne "none" ) {
        $buff = $self->pp_partial_bnst($buff);
    }

    $self->write_to_file($outputFileName, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink($outputFileName) unless -s $outputFileName;

    return $ret;
}

# 概要
# 解析対象KCファイル名とモデルファイル名を受け取り、処理して一時保存ディレクトリへ保存する。
# yamchaを使う
#
#
sub _bnst_process2 {
    my ($self, $arg1, $arg2, $save_dir) = @_;
    print STDERR "_process2\n";
    my $yamcha_opt = "";
    if ($self->{"boundary"} eq "sentence" || $self->{"boundary"} eq "word") {
        # sentence/word boundary
        $yamcha_opt = "-C";
    }
    my $ret = 0;

    my $YAMCHA = $self->{"yamcha-dir"}."/yamcha";
    if ( $Config{"osname"} eq "MSWin32" ) {
        $YAMCHA .= ".exe";
    }

    unless ( -x $YAMCHA ) {
        printf(STDERR "WARNING: %s Not Found or executable YAMCHA module.\n",
               $YAMCHA);
        exit 0;
    }

    # 入力ファイル名の生成
    my $inputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".svmdata";

    # 出力ファイル名の生成
    my $outputFileName = $save_dir."/".File::Basename::basename($arg1).".bout";

    # すでに同じ名前の中間ファイルがあれば削除
    unlink($outputFileName) if -s $outputFileName;

    # 入力ファイルの存在確認 (1)
    exit 0 unless $self->exists_file($arg2);

    # 入力ファイルの存在確認 (2)
    exit 0 unless $self->exists_file($inputFileName);

    my $buff = $self->read_from_file($inputFileName);
    # YAMCHA用に明示的に最終行に改行を付けさせる
    $buff .= "\n";
    $self->write_to_file($inputFileName, $buff);

    my $yamcha_com = "\"".$YAMCHA."\" ".$yamcha_opt." -m \"".$arg2."\"";
    if ( $self->{"debug"} > 0 ) {
        printf(STDERR "# YAMCHA_COM: %s\n", $yamcha_com);
    }
    $buff = $self->proc_stdin2stdout($yamcha_com, $buff);
    $buff =~ s/\x0d\x0a/\x0a/sg;
    $buff =~ s/^\r?\n//mg;
    $buff = $self->move_future_front($buff);
    #$buff = $self->truncate_last_column($buff);
    $self->write_to_file($outputFileName, $buff);

    $buff = $self->merge_kc_with_bout($arg1, $outputFileName);
    $self->write_to_file($outputFileName, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink($outputFileName) unless -s $outputFileName;

    return $ret;
}


sub _mid_process1 {
    my ($self, $arg1) = @_;
    print STDERR "# mid_process1\n";
    my $ret = 0;

    mkdir($self->{"comainu-temp"}) unless -d $self->{"comainu-temp"};

    # 出力ファイル名の生成
    my $outputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".mstin";

    my $NAME = File::Basename::basename($arg1);
    my $buff = $self->read_from_file($arg1);
    $buff = $self->kc2mstin($buff);

    $self->write_to_file($outputFileName, $buff);
    undef $buff;

    return $ret;
}

sub _mid_process2 {
    my ($self, $arg1, $arg2) = @_;
    print STDERR "# mid_process2\n";
    my $ret = 0;

    my $java = $self->{"java"};
    my $mstparser_dir = $self->{"mstparser-dir"};

    my $inputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".mstin";
    my $outputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".mstout";

    my $mst_classpath = $mstparser_dir."/output/classes:".$mstparser_dir."/lib/trove.jar";
    my $memory = "-Xmx1800m";
    if ( $Config{"osname"} eq "MSWin32" ) {
        $mst_classpath = $mstparser_dir."/output/classes;".$mstparser_dir."/lib/trove.jar";
        $memory = "-Xmx1000m";
        # remove drive letter for MS-Windows
        $arg2 =~ s/^[a-zA-Z]\://;
        $inputFileName =~ s/^[a-zA-Z]\://;
        $outputFileName =~ s/^[a-zA-Z]\://;
    }
    ## 入力ファイルが空だった場合
    if ( -z $inputFileName ) {
    	$self->write_to_file($outputFileName, "");
    	return $ret;
    }
    my $cmd = sprintf("\"%s\" -classpath \"%s\" %s mstparser.DependencyParser test model-name:\"%s\" test-file:\"%s\" output-file:\"%s\" order:1",
                      $java, $mst_classpath, $memory, $arg2, $inputFileName, $outputFileName);
    print STDERR $cmd,"\n";
    system($cmd);

    return $ret;
}

sub _mid_process3 {
    my ($self, $arg1, $arg2) = @_;
    print STDERR "# mid_process3\n";
    my $ret = 0;

    mkdir($arg2) unless -d $arg2;

    my $inputFileName = $self->{"comainu-temp"}."/".File::Basename::basename($arg1, ".KC").".mstout";
    my $outputFileName = $arg2."/".File::Basename::basename($arg1).".mout";

    my $buff = $self->merge_mout_with_kc_mstout_file($arg1, $inputFileName);

    $self->write_to_file($outputFileName, $buff);
    undef $buff;

    return $ret;
}


# from unix/bat/subBat/training_process1.sh
sub training_process1 {
    my ($self, $arg1, $arg2) = @_;
    print STDERR "# training_process1\n";
    my $ret = 0;

    mkdir($arg2) unless -d $arg2;

    my $NAME = File::Basename::basename($arg1);
    my $buff = $self->read_from_file($arg1);
    # unless ( -f $arg2."/".$NAME ) {
    #     $self->write_to_file($arg2."/".$NAME, $buff);
    # }
    $buff =~ s/^EOS.*?\n|^\*B.*?\n//mg;
    $buff = $self->delete_column_long($buff);
    # $buff = $self->add_column($buff);

    ## 辞書の作成
    my $C_Dic = new CreateDictionary();
    $C_Dic->create_dictionary($arg1, $arg2, $NAME);
    ## 素性の追加
    my $AF = new AddFeature();
    $buff = $AF->add_feature($buff, $NAME, $arg2);

    $self->write_to_file($arg2."/".$NAME.".KC2", $buff);
    undef $buff;

    print STDERR "Make ".$arg2."/".$NAME.".KC2\n";
    return $ret;
}

# from unix/bat/subBat/training_train2.sh
sub training_train2 {
    my ($self, $arg1, $arg2, $arg3) = @_;
    print STDERR "# training_train2\n";
    my $ret = 0;

    if ( -s $arg3."/".$arg1.".svmin" ) {
        print "Use Cache '$3/$1.svmin'.\n";
        return $ret;
    }
    mkdir($arg3) unless -d $arg3;

    my $NAME = File::Basename::basename($arg1);
    my $inputFileName = $arg2."/".$NAME.".KC2";
    my $outputFileName = $arg3."/".$NAME.".svmin";

    open(my $fh_ref, "<", $arg1) or die "Cannot open '$arg1'";
    open(my $fh_in, "<", $inputFileName) or die "Cannot open '$inputFileName'";
    open(my $fh_out, ">", $outputFileName) or die "Cannot open '$outputFileName'";
    binmode($fh_out);
    $self->add_pivot_to_kc2($fh_ref, $fh_in, $fh_out);
    close($fh_out);
    close($fh_in);
    close($fh_ref);

    ## 後処理用学習データの作成
    open(my $fh_ref, "<", $arg1) or die "Cannot open '$arg1'";
    open(my $fh_svmin, "<", $outputFileName) or die "Cannot open'$outputFileName'";
    my $BIP = new BIProcessor();
    $BIP->extract_from_train($fh_ref, $fh_svmin, $arg3, $NAME);
    close($fh_ref);
    close($fh_svmin);

    unlink($outputFileName) unless -s $outputFileName;

    # my $buff = $self->read_from_file($outputFileName);
    # $buff .= "\n";
    # $self->write_to_file($outputFileName, $buff);
    return $ret;
}

# from unix/bat/subBat/training_train3.sh
sub training_train3 {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# training_train3\n";
    my $ret = 0;
    my $name = File::Basename::basename($train_kc);
    my $yamcha = $self->{"yamcha-dir"}."/yamcha";
    my $yamcha_tool_dir = $self->get_yamcha_tool_dir();
    my $svm_tool_dir = $self->get_svm_tool_dir();

    return 1 unless defined $yamcha_tool_dir;

    my $svm_learn = $svm_tool_dir."/svm_learn";
    my $comainu_home = $self->{"comainu-home"};
    my $comainu_etc_dir = $comainu_home."/etc";
    my $yamcha_training_conf_file = $comainu_etc_dir."/yamcha_training.conf";
    printf(STDERR "# use yamcha_training_conf_file=\"%s\"\n",
           $yamcha_training_conf_file);
    my $yamcha_training_conf = $self->load_yamcha_training_conf($yamcha_training_conf_file);
    my $yamcha_training_makefile_template = $yamcha_tool_dir."/Makefile";

    my $check = $self->check_yamcha_training_makefile_template($yamcha_training_makefile_template);
    if ( $check == 0 ) {
        $yamcha_training_makefile_template = $comainu_etc_dir."/yamcha_training.mk";
    }
    printf(STDERR "# use yamcha_training_makefile_template=\"%s\"\n",
           $yamcha_training_makefile_template);
    my $yamcha_training_makefile = $model_dir."/".$name.".Makefile";
    my $buff = $self->read_from_file($yamcha_training_makefile_template);
    if ( $check == 0 ) {
        $buff =~ s/^(TOOLDIR.*)$/\# $1\nTOOLDIR    = $yamcha_tool_dir/mg;
        printf(STDERR "# changed TOOLDIR : %s\n", $yamcha_tool_dir);
        $buff =~ s/^(YAMCHA.*)$/\# $1\nYAMCHA    = $yamcha/mg;
        printf(STDERR "# changed YAMCHA : %s\n", $yamcha);
    }
    if ( $svm_tool_dir ne "" ) {
        $buff =~ s/^(SVM_LEARN.*)$/\# $1\nSVM_LEARN = $svm_learn/mg;
        printf(STDERR "# changed SVM_LEARN : %s\n", $svm_learn);
    }
    if ( $yamcha_training_conf->{"SVM_PARAM"} ne "" ) {
        $buff =~ s/^(SVM_PARAM.*)$/\# $1\nSVM_PARAM  = $yamcha_training_conf->{"SVM_PARAM"}/mg;
        printf(STDERR "# changed SVM_PARAM : %s\n", $yamcha_training_conf->{"SVM_PARAM"});
    }
    if ( $yamcha_training_conf->{"FEATURE"} ne "" ) {
        $buff =~ s/^(FEATURE.*)$/\# $1\nFEATURE    = $yamcha_training_conf->{"FEATURE"}/mg;
        printf(STDERR "# changed FEATURE : %s\n", $yamcha_training_conf->{"FEATURE"});
    }
    if ( $yamcha_training_conf->{"DIRECTION"} ne "" ) {
        $buff =~ s/^(DIRECTION.*)$/\# $1\nDIRECTION  = $yamcha_training_conf->{"DIRECTION"}/mg;
        printf(STDERR "# changed DIRECTION : %s\n", $yamcha_training_conf->{"DIRECTION"});
    }
    if ( $yamcha_training_conf->{"MULTI_CLASS"} ne "" ) {
        $buff =~ s/^(MULTI_CLASS.*)$/\# $1\nMULTI_CLASS = $yamcha_training_conf->{"MULTI_CLASS"}/mg;
        printf(STDERR "# changed MULTI_CLASS : %s\n", $yamcha_training_conf->{"MULTI_CLASS"});
    }

    {
        # patch for zip
        # remove '#' at end of line by svm_light
        my $patch_for_zip_str = "### patch for zip ###\n\t\$(PERL) -pe 's/#\\r?\$\$//;' \$(MODEL).svmmodel > \$(MODEL).svmmodel.patched\n\tmv -f \$(MODEL).svmmodel.patched \$(MODEL).svmmodel\n#####################\n";
        $buff =~ s/(zip:\n)/$1$patch_for_zip_str/;
        printf(STDERR "# patched zip target\n");
    }

    {
        # patch for compile
        # fixed the problem that it uses /bin/gzip in mkmodel.
        my $patch_for_compile_str = "### patch for compile ###\n\t\$(GZIP) -dc \$(MODEL).txtmodel.gz | \$(PERL) \$(TOOLDIR)/mkmodel -t \$(TOOLDIR) - \$(MODEL).model\n#########################\n";
        $buff =~ s/(compile:\n)([^\n]+\n)/$1\#$2$patch_for_compile_str/;
        printf(STDERR "# patched compile target\n");
    }

    $self->write_to_file($yamcha_training_makefile, $buff);
    undef $buff;

    my $perl = $self->{"perl"};
    my $svmin = $model_dir."/".$name.".svmin";
    my $com = sprintf("make -f \"%s\" PERL=\"%s\" CORPUS=\"%s\" MODEL=\"%s\" train",
                      $yamcha_training_makefile, $perl, $svmin, $model_dir."/".$name);
    printf(STDERR "# COM: %s\n", $com);
    system($com);

    return $ret;
}

# from unix/bat/subBat/training_train3.sh
sub training_train3_old {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# training_train3\n";
    my $ret = 0;
    my $name = File::Basename::basename($train_kc);
    my $yamcha_tool_dir = $self->get_yamcha_tool_dir();
    my $svm_tool_dir = $self->get_svm_tool_dir();
    if ( !defined($yamcha_tool_dir) or !defined($svm_tool_dir) ) {
        return 1;
    }
    my $svm_learn = $svm_tool_dir."/svm_learn";
    my $yamcha_train_opts = {
        "TOOL_DIR" => $yamcha_tool_dir,
        # "SVM_PARAM" => "-t1 -d2 -c1",
        "SVM_PARAM" => "-t 1  -d 3 -c 1 -m 514",
        "FEATURE" => "F:-2..2:0.. T:-2..-1",
        # "DIRECTION" => "",
        "DIRECTION" => "-B",
        # "MULTI_CLASS" => "1",
        "MULTI_CLASS" => "2",
        "CORPUS" => $model_dir."/".$name.".svmin",
        "MODEL" => $model_dir."/".$name,
        "SVM_LEARN" => $svm_learn,
        "PERL" => $self->{"perl"},
        "GZIP" => "gzip",
        "SORT" => "sort",
        "UNIQ" => "uniq",
        "YAMCHA" => $self->{"yamcha-dir"}."/yamcha",
    };
    $self->yamcha_train(%$yamcha_train_opts);
    return $ret;
}

## training by crf++
sub training_crftrain3 {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# training_crftrain3\n";
    my $ret = 0;
    my $name = File::Basename::basename($train_kc);
    my $crf_dir = $self->get_crf_dir();
    return 1 unless defined $crf_dir;

    $ENV{"LD_LIBRARY_PATH"} = "/usr/lib;/usr/local/lib";

    my $crf_learn = $crf_dir."/crf_learn";
    my $comainu_home = $self->{"comainu-home"};
    my $crf_template = $model_dir."/".$name.".template";

    my $svmin = $model_dir."/".$name.".svmin";
    ## 素性数を取得
    open(my $fh_svmin, $svmin);
    my $line = <$fh_svmin>;
    $line = Encode::decode("utf-8", $line);
    my $feature_num = scalar(split(/ /,$line))-2;
    close($fh_svmin);

    $self->create_template($crf_template, $feature_num);

    my $crf_model = $model_dir."/".$name.".model";
    my $com = "\"$crf_learn\" \"$crf_template\" \"$svmin\" \"$crf_model\"";
    printf(STDERR "# COM: %s\n", $com);
    system($com);

    return $ret;
}

## training by mira
sub training_miratrain3 {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# training_miratrain3\n";
    my $ret = 0;
    my $name = File::Basename::basename($train_kc);
    my $mira_dir = $self->get_mira_dir();
    return 1 unless defined $mira_dir;

    my $mira_learn = $mira_dir."/mira-train";
    my $comainu_home = $self->{"comainu-home"};
    my $mira_template = $model_dir."/".$name.".template";

    ## SVMINの修正
    my $svmin = $model_dir."/".$name.".svmin";
    my $svmin_buff = $self->read_from_file($svmin);
    my $svmin_buff2 = "";
    foreach my $line ( split(/\r?\n/, $svmin_buff) ) {
        my @items = split(/ /,$line);
        $svmin_buff2 .= join("\t",@items)."\n";
    }
    my $line = (split(/\r?\n/,$svmin_buff))[0];
    my $feature_num = scalar(split(/ /,$line))-2;
    $self->write_to_file($svmin, $svmin_buff2);
    $self->create_template($mira_template, $feature_num);
    undef $svmin_buff;
    undef $svmin_buff2;

    my $com = "\"$mira_learn\" -t \"$mira_template\" -c \"$svmin\" -m \"$model_dir\"";
    printf(STDERR "# COM: %s\n", $com);
    system($com);

    return $ret;
}

## BIのみに関する処理（後処理用）
sub training_train4 {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# training_train4\n";
    my $ret = 0;

    my $name = File::Basename::basename($train_kc);
    my $yamcha = $self->{"yamcha-dir"}."/yamcha";
    my $yamcha_tool_dir = $self->get_yamcha_tool_dir();
    my $svm_tool_dir = $self->get_svm_tool_dir();
    return 1 unless defined $yamcha_tool_dir;

    my $svm_learn = $svm_tool_dir."/svm_learn";
    my $comainu_home = $self->{"comainu-home"};
    my $comainu_etc_dir = $comainu_home."/etc";
    my $yamcha_training_conf_file = $comainu_etc_dir."/yamcha_training.conf";
    printf(STDERR "# use yamcha_training_conf_file=\"%s\"\n",
           $yamcha_training_conf_file);
    my $yamcha_training_conf = $self->load_yamcha_training_conf($yamcha_training_conf_file);
    my $yamcha_training_makefile_template = $yamcha_tool_dir."/Makefile";

    my $check = $self->check_yamcha_training_makefile_template($yamcha_training_makefile_template);
    if ( $check == 0 ) {
        $yamcha_training_makefile_template = $comainu_etc_dir."/yamcha_training.mk";
    }
    printf(STDERR "# use yamcha_training_makefile_template=\"%s\"\n",
           $yamcha_training_makefile_template);
    my $yamcha_training_makefile = $model_dir."/".$name.".Makefile";
    my $buff = $self->read_from_file($yamcha_training_makefile_template);
    if ( $check == 0 ) {
        $buff =~ s/^(TOOLDIR.*)$/\# $1\nTOOLDIR    = $yamcha_tool_dir/mg;
        printf(STDERR "# changed TOOLDIR : %s\n", $yamcha_tool_dir);
        $buff =~ s/^(YAMCHA.*)$/\# $1\nYAMCHA    = $yamcha/mg;
        printf(STDERR "# changed YAMCHA : %s\n", $yamcha);
    }
    if ( $svm_tool_dir ne "" ) {
        $buff =~ s/^(SVM_LEARN.*)$/\# $1\nSVM_LEARN = $svm_learn/mg;
        printf(STDERR "# changed SVM_LEARN : %s\n", $svm_learn);
    }
    if ( $yamcha_training_conf->{"SVM_PARAM"} ne "" ) {
        $buff =~ s/^(SVM_PARAM.*)$/\# $1\nSVM_PARAM  = $yamcha_training_conf->{"SVM_PARAM"}/mg;
        printf(STDERR "# changed SVM_PARAM : %s\n", $yamcha_training_conf->{"SVM_PARAM"});
    }
    if ( $yamcha_training_conf->{"FEATURE"} ne "" ) {
        $buff =~ s/^(FEATURE.*)$/\# $1\nFEATURE    = $yamcha_training_conf->{"FEATURE"}/mg;
        printf(STDERR "# changed FEATURE : %s\n", $yamcha_training_conf->{"FEATURE"});
    }
    if ( $yamcha_training_conf->{"DIRECTION"} ne "" ) {
        $buff =~ s/^(DIRECTION.*)$/\# $1\nDIRECTION  = $yamcha_training_conf->{"DIRECTION"}/mg;
        printf(STDERR "# changed DIRECTION : %s\n", $yamcha_training_conf->{"DIRECTION"});
    }
    if ( $yamcha_training_conf->{"MULTI_CLASS"} ne "" ) {
        $buff =~ s/^(MULTI_CLASS.*)$/\# $1\nMULTI_CLASS = $yamcha_training_conf->{"MULTI_CLASS"}/mg;
        printf(STDERR "# changed MULTI_CLASS : %s\n", $yamcha_training_conf->{"MULTI_CLASS"});
    }

    {
        # patch for zip
        # remove '#' at end of line by svm_light
        my $patch_for_zip_str = "### patch for zip ###\n\t\$(PERL) -pe 's/#\\r?\$\$//;' \$(MODEL).svmmodel > \$(MODEL).svmmodel.patched\n\tmv -f \$(MODEL).svmmodel.patched \$(MODEL).svmmodel\n#####################\n";
        $buff =~ s/(zip:\n)/$1$patch_for_zip_str/;
        printf(STDERR "# patched zip target\n");
    }

    {
        # patch for compile
        # fixed the problem that it uses /bin/gzip in mkmodel.
        my $patch_for_compile_str = "### patch for compile ###\n\t\$(GZIP) -dc \$(MODEL).txtmodel.gz | \$(PERL) \$(TOOLDIR)/mkmodel -t \$(TOOLDIR) - \$(MODEL).model\n#########################\n";
        $buff =~ s/(compile:\n)([^\n]+\n)/$1\#$2$patch_for_compile_str/;
        printf(STDERR "# patched compile target\n");
    }

    $self->write_to_file($yamcha_training_makefile, $buff);
    my $perl = $self->{"perl"};
    my $svmin = $model_dir."/".$name.".svmin";

    my $BI_com1 = sprintf("make -f \"%s\" PERL=\"%s\" MULTI_CLASS=2 FEATURE=\"F:0:0.. \" CORPUS=\"%s\" MODEL=\"%s\" train",
                          $yamcha_training_makefile,$perl,
                          $model_dir."/pos/".$name.".BI_pos.dat",
                          $model_dir."/pos/".$name.".BI_pos");
    system($BI_com1);

    my $BI_com2 = sprintf("make -f \"%s\" PERL=\"%s\" MULTI_CLASS=2 FEATURE=\"F:0:0.. \" CORPUS=\"%s\" MODEL=\"%s\" train",
                          $yamcha_training_makefile,$perl,
                          $model_dir."/cType/".$name.".BI_cType.dat",
                          $model_dir."/cType/".$name.".BI_cType");
    system($BI_com2);

    my $BI_com3 = sprintf("make -f \"%s\" PERL=\"%s\" MULTI_CLASS=2 FEATURE=\"F:0:0.. \" CORPUS=\"%s\" MODEL=\"%s\" train",
                          $yamcha_training_makefile,$perl,
                          $model_dir."/cForm/".$name.".BI_cForm.dat",
                          $model_dir."/cForm/".$name.".BI_cForm");
    system($BI_com3);

    return $ret;
}


sub training_bnst {
    my ($self, $arg1, $arg2) = @_;
    print STDERR "# training_bnst_process\n";
    my $ret = 0;
    mkdir($arg2) unless -d $arg2;

    my $NAME = File::Basename::basename($arg1);
    my $svmin = $arg2."/".$NAME.".svmin";
    my $buff = $self->read_from_file($arg1);
    $buff = $self->trans_dataformat($buff, "input-kc", "kc");
    $buff = $self->kc2bnstsvmdata($buff, 1);
    $buff = $self->add_bnst_label($buff);
    $buff =~ s/^EOS.*?\n//mg;
    $buff .= "\n";
    $self->write_to_file($svmin, $buff);
    undef $buff;

    my $yamcha = $self->{"yamcha-dir"}."/yamcha";
    my $yamcha_tool_dir = $self->get_yamcha_tool_dir();
    my $svm_tool_dir = $self->get_svm_tool_dir();
    return 1 unless defined $yamcha_tool_dir;

    my $svm_learn = $svm_tool_dir."/svm_learn";
    my $comainu_home = $self->{"comainu-home"};
    my $comainu_etc_dir = $comainu_home."/etc";
    my $yamcha_training_conf_file = $comainu_etc_dir."/yamcha_training.conf";
    printf(STDERR "# use yamcha_training_conf_file=\"%s\"\n",
           $yamcha_training_conf_file);
    my $yamcha_training_conf = $self->load_yamcha_training_conf($yamcha_training_conf_file);
    my $yamcha_training_makefile_template = $yamcha_tool_dir."/Makefile";

    my $check = $self->check_yamcha_training_makefile_template($yamcha_training_makefile_template);
    if ( $check == 0 ) {
        $yamcha_training_makefile_template = $comainu_etc_dir."/yamcha_training.mk";
    }
    printf(STDERR "# use yamcha_training_makefile_template=\"%s\"\n",
           $yamcha_training_makefile_template);
    my $yamcha_training_makefile = $arg2."/".$NAME.".Makefile";
    my $buff = $self->read_from_file($yamcha_training_makefile_template);
    if ( $check == 0 ) {
        $buff =~ s/^(TOOLDIR.*)$/\# $1\nTOOLDIR    = $yamcha_tool_dir/mg;
        printf(STDERR "# changed TOOLDIR : %s\n", $yamcha_tool_dir);
        $buff =~ s/^(YAMCHA.*)$/\# $1\nYAMCHA    = $yamcha/mg;
        printf(STDERR "# changed YAMCHA : %s\n", $yamcha);
    }
    if ( $svm_tool_dir ne "" ) {
        $buff =~ s/^(SVM_LEARN.*)$/\# $1\nSVM_LEARN = $svm_learn/mg;
        printf(STDERR "# changed SVM_LEARN : %s\n", $svm_learn);
    }
    if ( $yamcha_training_conf->{"SVM_PARAM"} ne "" ) {
        $buff =~ s/^(SVM_PARAM.*)$/\# $1\nSVM_PARAM  = $yamcha_training_conf->{"SVM_PARAM"}/mg;
        printf(STDERR "# changed SVM_PARAM : %s\n", $yamcha_training_conf->{"SVM_PARAM"});
    }
    if ( $yamcha_training_conf->{"FEATURE"} ne "" ) {
        $buff =~ s/^(FEATURE.*)$/\# $1\nFEATURE    = $yamcha_training_conf->{"FEATURE"}/mg;
        printf(STDERR "# changed FEATURE : %s\n", $yamcha_training_conf->{"FEATURE"});
    }
    if ( $yamcha_training_conf->{"DIRECTION"} ne "" ) {
        $buff =~ s/^(DIRECTION.*)$/\# $1\nDIRECTION  = $yamcha_training_conf->{"DIRECTION"}/mg;
        printf(STDERR "# changed DIRECTION : %s\n", $yamcha_training_conf->{"DIRECTION"});
    }
    # if ( $yamcha_training_conf->{"MULTI_CLASS"} ne "" ) {
    #     $buff =~ s/^(MULTI_CLASS.*)$/\# $1\nMULTI_CLASS = $yamcha_training_conf->{"MULTI_CLASS"}/mg;
    #     printf(STDERR "# changed MULTI_CLASS : %s\n", $yamcha_training_conf->{"MULTI_CLASS"});
    # }

    {
        # patch for zip
        # remove '#' at end of line by svm_light
        my $patch_for_zip_str = "### patch for zip ###\n\t\$(PERL) -pe 's/#\\r?\$\$//;' \$(MODEL).svmmodel > \$(MODEL).svmmodel.patched\n\tmv -f \$(MODEL).svmmodel.patched \$(MODEL).svmmodel\n#####################\n";
        $buff =~ s/(zip:\n)/$1$patch_for_zip_str/;
        printf(STDERR "# patched zip target\n");
    }

    {
        # patch for compile
        # fixed the problem that it uses /bin/gzip in mkmodel.
        my $patch_for_compile_str = "### patch for compile ###\n\t\$(GZIP) -dc \$(MODEL).txtmodel.gz | \$(PERL) \$(TOOLDIR)/mkmodel -t \$(TOOLDIR) - \$(MODEL).model\n#########################\n";
        $buff =~ s/(compile:\n)([^\n]+\n)/$1\#$2$patch_for_compile_str/;
        printf(STDERR "# patched compile target\n");
    }

    $self->write_to_file($yamcha_training_makefile, $buff);
    undef $buff;

    my $perl = $self->{"perl"};
    my $com = sprintf("make -f \"%s\" PERL=\"%s\" CORPUS=\"%s\" MODEL=\"%s\" train",
                      $yamcha_training_makefile, $perl, $svmin, $arg2."/".$NAME);

    printf(STDERR "# COM: %s\n", $com);
    system($com);

    return $ret;
}

sub add_bnst_label {
    my ($self, $data) = @_;
    my $res = "";
    my ($prev, $curr, $next) = (0, 1, 2);
    my $buff_list = [undef, undef];
    $data .= "*B\n";
    foreach my $line ( (split(/\r?\n/, $data), undef, undef) ) {
        push(@$buff_list, $line);
        if ( defined($buff_list->[$curr]) && $buff_list->[$curr] !~ /^EOS/ &&
                 $buff_list->[$curr] !~ /^\*B/ ) {
            my $mark = "";
            if ( $buff_list->[$prev] =~ /^\*B/ ) {
                $mark = "B";
            } else {
                $mark = "I";
            }
            $buff_list->[$curr] .= " ".$mark;
        }
        my $new_line = shift(@$buff_list);
        if ( defined($new_line) && $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }
    undef $data;

    while ( my $new_line = shift(@$buff_list) ) {
        if ( defined($new_line) && $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }
    undef $buff_list;

    return $res;
}


## 中単位解析学習用関数
sub training_mid_train1 {
    my ($self, $arg1, $arg2) = @_;
    print STDERR "# training_mid_train1\n";
    my $ret = 0;

    mkdir($arg2) unless -d $arg2;

    my $NAME = File::Basename::basename($arg1);
    my $buff = $self->read_from_file($arg1);
    $buff = $self->trans_dataformat($buff, "input-kc", "kc_mid");
    $buff = $self->kc2mstin($buff);

    $self->write_to_file($arg2."/".$NAME.".mstin", $buff);
    undef $buff;

    return $ret;
}

## 中単位解析学習用関数
sub training_mid_train2 {
    my ($self, $arg1, $arg2) = @_;
    print STDERR "# training_mid_train2\n";
    my $ret = 0;

    my $java = $self->{"java"};
    my $mstparser_dir = $self->{"mstparser-dir"};

    my $NAME = File::Basename::basename($arg1);
    my $inputFile = $arg2."/".$NAME.".mstin";
    my $outputFile = $arg2."/".$NAME.".model";

    my $mst_classpath = $mstparser_dir."/output/classes:".$mstparser_dir."/lib/trove.jar";
    my $memory = "-Xmx1800m";
    if ( $Config{"osname"} eq "MSWin32" ) {
        $mst_classpath = $mstparser_dir."/output/classes;".$mstparser_dir."/lib/trove.jar";
        $memory = "-Xmx1000m";
        # remove drive letter for MS-Windows
        $inputFile =~ s/^[a-zA-Z]\://;
        $outputFile =~ s/^[a-zA-Z]\://;
    }
    my $cmd = sprintf("\"%s\" -classpath \"%s\" %s mstparser.DependencyParser train train-file:\"%s\" model-name:\"%s\" order:1",
                      $java, $mst_classpath, $memory, $inputFile, $outputFile);
    print STDERR $cmd,"\n";
    system($cmd);

    return $ret;
}

sub kc2mstin {
    my ($self, $data) = @_;
    my $res = "";

    my $short_terms = [];
    my $pos = 0;
    foreach my $line ( split(/\r?\n/, $data) ) {
        next if $line =~ /^\*B/ || $line eq "";
        if ( $line =~ /^EOS/ ) {
            $res .= $self->create_mstfeature($short_terms, $pos);
            $short_terms = [];
            $pos = 0;
            next;
        }
        my @items = split(/[ \t]/, $line);
        if ( $items[13] ne "*" ) {
            $res .= $self->create_mstfeature($short_terms, $pos);
            $short_terms = [];
            push @$short_terms, $line;
        } else {
            push @$short_terms, $line;
        }
        $pos++;
    }

    undef $data;
    undef $short_terms;

    return $res;
}

sub create_mstfeature {
    my ($self, $short_terms, $pos) = @_;
    my $res = "";

    my $id = 1;
    if ( scalar(@$short_terms) > 1 ) {
        foreach my $line ( @$short_terms ) {
            my @items = split(/[ \t]/, $line);
            my $depend = "_";
            if ( $items[19] =~ /Ｐ/ ) {
                $depend = "P";
            }
            if ( $items[19] ne "*" && $items[19] ne "" ) {
                $items[19] -= $pos-scalar(@$short_terms)-1;
            } else {
                $items[19] = 0;
            }
            if ( scalar(@$short_terms) < $items[19] || $items[19] < 0 ) {
                print STDERR "error: $items[0]: $line\n";
                print STDERR $pos," ",$items[19]," ",scalar(@$short_terms),"\n";
            }
            my @cpos = split(/\-/, $items[3]);
            my @features;

            foreach my $i ( 3 .. 5 ) {
                next if $items[$i] eq "*";
                my @pos = split(/\-/, $items[$i]);
                foreach my $j ( 0 .. $#pos ) {
                    next if ($i == 3 && ($j == 0 || $j == $#pos));
                    push @features, join("-",@pos[0..$j]);
                }
            }

            $res .= $id++."\t".$items[0]."\t".$items[2]."\t".$cpos[0]."\t".$items[3]."\t";
            if ( scalar(@features) > 0 ) {
                $res .= join("|",@features);
            } else {
                $res .= "_";
            }
            $res .= "\t".$items[19]."\t".$depend."\t_\n";
            #$res .= join("\t", @items[21..$#items])."\n";
        }
        $res .= "\n";
    }

    return $res;
}

sub merge_mout_with_kc_mstout_file {
    my ($self, $kc_file, $out_file) = @_;
    my $res = "";

    my $out_long = [];
    my $long_word = "";
    foreach my $line ( split(/\r?\n/, $self->read_from_file($out_file)) ) {
        if ( $line eq "" ){
            next if $long_word eq "";
            push @$out_long, $long_word;
            $long_word = "";
        } else {
            $long_word .= $line."\n";
        }
    }
    push @$out_long, $long_word if $long_word ne "";

    my $pos = 0;
    my $mid = -1;
    my $kc_long = [];
    foreach my $line ( split(/\r?\n/, $self->read_from_file($kc_file)) ) {
    	next if $line eq "";
        if ( $line =~ /^EOS/ ) {
            $res .= $self->create_middle($kc_long, $out_long, \$mid, $pos);
            $pos = 0;
            $res .= "EOS\n";
            $mid = -1;
            $kc_long = [];
        } elsif ( $line =~ /^\*B/ ) {
        } else {
            my @items = split(/[ \t]/, $line);
            if ( $items[13] ne "*" ) {
                $res .= $self->create_middle($kc_long, $out_long, \$mid, $pos);
                $pos += scalar(@$kc_long);
                $kc_long = [];
                push @$kc_long, \@items;
            } else {
                push @$kc_long, \@items;
            }
        }
    }

    undef $out_long;
    undef $kc_long;

    return $res;
}

sub create_middle {
    my ($self, $kc_long, $out_long, $ref_mid, $pos) = @_;
    my $res = "";

    my %sp_prefix = ("各"=>1, "計"=>1, "現"=>1, "全"=>1, "非"=>1, "約"=>1);

    if ( scalar(@$kc_long) < 1 ) {
        return "";
    } elsif ( scalar(@$kc_long) == 1 ) {
        my @items = split(/[ \t]/, $$kc_long[0]);
        $$ref_mid++;
        #$res .= join(" ",@{$$kc_long[0]}[0..18])." * ".$$ref_mid." ".join(" ",@{$$kc_long[0]}[0..4])."\n";
        $res .= join(" ",@{$$kc_long[0]}[0..18])." * ".$$ref_mid." ".join(" ",@{$$kc_long[0]}[0..0])."\n";
    } elsif ( ${$$kc_long[0]}[13] =~ /^形状詞/ ) {
        $$ref_mid++;
        my @out;
        foreach my $line ( split(/\r?\n/,shift @$out_long) ) {
            push @out, [ split(/\t/,$line) ];
        }
        my @mid_text;
        for my $i ( 0 .. $#{$kc_long} ) {
            $mid_text[0] .= ${$$kc_long[$i]}[0];
            # $mid_text[1] .= ${$$kc_long[$i]}[1];
            # $mid_text[2] .= ${$$kc_long[$i]}[2];
            # $mid_text[3] .= ${$$kc_long[$i]}[3];
            # $mid_text[4] .= ${$$kc_long[$i]}[4];
        }
        $res .= join(" ",@{$$kc_long[0]}[0..18])." ".($pos+${$out[0]}[6]-1)." ".$$ref_mid." ".join(" ",@mid_text)."\n";
        for my $i ( 1 .. $#{$kc_long}-1 ) {
            $res .= join(" ",@{$$kc_long[$i]}[0..18])." ".($pos+${$out[$i]}[6]-1)." ".$$ref_mid."\n";
        }
        $res .= join(" ",@{$$kc_long[$#{$kc_long}]}[0..18])." * ".$$ref_mid."\n";
    } else {
        my @out;
        foreach my $line ( split(/\r?\n/,shift @$out_long) ) {
            push @out, [split(/\t/,$line)];
        }
        my $mid_pos = 0;
        for my $i ( 0 .. $#out ) {
            my $long = $$kc_long[$i];
            @$long[21..25] = ("","","","","");
            ${$$kc_long[$mid_pos]}[21] .= $$long[0];
            # ${$$kc_long[$mid_pos]}[22] .= $$long[1];
            # ${$$kc_long[$mid_pos]}[23] .= $$long[2];
            # ${$$kc_long[$mid_pos]}[24] .= $$long[3];
            # ${$$kc_long[$mid_pos]}[25] .= $$long[4];

            if ( ${$out[$i]}[6] == 0 ) {
                $$long[19] = "*";
                $mid_pos = $i+1;
                next;
            }
            if ( $i < $#out && ${$out[$i+1]}[3] eq "補助記号" ) {
                $mid_pos = $i+1;
            } elsif ( $i < $#out && ${$out[$i+1]}[3] eq "接頭辞" &&
                          defined $sp_prefix{${$out[$i+1]}[2]} ) {
                $mid_pos = $i+1;
            } elsif ( ${$out[$i]}[3] eq "補助記号" ) {
                $mid_pos = $i+1;
            } elsif ( ${$out[$i]}[7] eq "P" ) {
                if ( ${$out[$i]}[3] ne "接頭辞" ) {
                    $mid_pos = $i+1;
                }
            } elsif ( $$long[3] =~ /^接頭辞/ ) {
                if ( defined $sp_prefix{$$long[2]} ) {
                    $mid_pos = $i+1;
                }
            # } elsif ( $i < $#out-1 && ${$out[$i+1]}[0]!=${$out[$i]}[6] ) {
            #     my $depend = ${$out[$i]}[6];
            #     if( (${$out[$depend-1]}[3] eq "名詞" && ${$out[$depend-2]}[3] eq "接頭辞") ||
            #             (${$out[$depend-1]}[3] eq "接尾辞" && ${$out[$depend-2]}[3] eq "名詞") ) {
            #         $mid_pos = $i+1;
            #     } else {
            #         $mid_pos = $i+1;
            #     }
            # }
            } elsif ( $i < $#out-1 && ${$out[$i+1]}[0]!=${$out[$i]}[6] ) {
                if ( ${$out[$i+2]}[0]==${$out[$i]}[6] &&
                         ( (${$out[$i+2]}[3] eq "名詞" && ${$out[$i+1]}[3] eq "接頭辞") ||
                               (${$out[$i+2]}[3] eq "接尾辞" && ${$out[$i+1]}[3] eq "名詞")) ) {
                    #$mid_pos = $i+1;
                } else {
                    $mid_pos = $i+1;
                }
            }
            $$long[19] = $pos+${$out[$i]}[6]-1;
        }
        # for my $i ( 0 .. $#{$kc_long} ) {
        for my $i ( 0 .. scalar(@$kc_long)-1 ) {
            my $long = $$kc_long[$i];
            if ( $$long[21] ne "" ) {
                $$ref_mid++;
                #$res .= join(" ",@$long[0..19])." ".$$ref_mid." ".join(" ",@$long[21..25]);
                $res .= join(" ",@$long[0..19])." ".$$ref_mid." ".$$long[21];
            } else {
                $res .= join(" ",@$long[0..19])." ".$$ref_mid;
            }
            $res .= "\n";
        }
    }

    return $res;
}


## 入力形式を内部形式に変換
sub trans_dataformat {
    my ($self, $input_data, $in_type, $out_type) = @_;

    my $data_format_conf = $self->{"data_format"};
    exit 0 unless $self->exists_file($data_format_conf);

    my $data = $self->read_from_file($data_format_conf);
    my %formats;
    foreach my $line (split(/\r?\n/, $data)) {
        my ($type, $format) = split(/\t/,$line);
        $formats{$type} = $format;
    }
    $formats{"kc"} = "orthToken,reading,lemma,pos,cType,cForm,form,formBase,formOrthBase,formOrth,charEncloserOpen,charEncloserClose,wType,l_pos,l_cType,l_cForm,l_reading,l_lemma,l_orthToken";
    $formats{"bccwj"} = "file,start,end,BOS,orthToken,reading,lemma,meaning,pos,cType,cForm,usage,pronToken,pronBase,kana,kanaBase,form,formBase,formOrthBase,formOrth,orthBase,wType,charEncloserOpen,charEncloserClose,originalText,order,BOB,LUW,l_orthToken,l_reading,l_lemma,l_pos,l_cType,l_cForm";
    $formats{"kc_mid"} = "orthToken,reading,lemma,pos,cType,cForm,form,formBase,formOrthBase,formOrth,charEncloserOpen,charEncloserClose,wType,l_pos,l_cType,l_cForm,l_reading,l_lemma,l_orthToken,depend,MID,m_orthToken";

    my %in_format = ();
    my @items = split(/,/,$formats{$in_type});
    for my $i ( 0 .. $#items ) {
        $in_format{$items[$i]} = $i;
    }

    # return $input_data if($formats{$in_type} eq $formats{$out_type});

    my @out_format = split(/,/,$formats{$out_type});
    my @trans_table = ();
    for my $i ( 0 .. $#out_format ) {
        $trans_table[$i] = $in_format{$out_format[$i]} // '*';
    }
    my $res = [];
    foreach my $line ( split(/\r?\n/,$input_data) ) {
        if ( $line =~ /^EOS|^\*B/ ) {
            push @$res, $line;
            next;
        }
        my @items;
        if ( $in_type =~ /bccwj/ ) {
            @items = split(/\t/,$line);
        } else {
            @items = split(/ /, $line);
        }
        my @tmp_buff = ();
        for my $i ( 0 .. $#trans_table ) {
            if ( $trans_table[$i] eq "*" || $trans_table[$i] eq "NULL" ) {
                $tmp_buff[$i] = "*";
            } else {
                my $item = $items[$trans_table[$i]];
                if($item eq "" || $item eq "NULL" || $item eq "\0") {
                    $tmp_buff[$i] = "*";
                } else {
                    $tmp_buff[$i] = $item;
                }
            }
        }
        my $out;
        if ( $out_type eq "kc" ) {
            $out = join(" ",@tmp_buff);
        } elsif ( $out_type eq "bccwj" ) {
            $out = join("\t",@tmp_buff);
        } elsif ( $out_type eq "kc_mid" ) {
            $out = join(" ",@tmp_buff);
        }
        push @$res, $out;
    }

    undef $input_data;

    return join "\n", @$res;
}

## テンプレートの作成
sub create_template {
    my ($self, $template_file, $feature_num) = @_;

    my $buff = "";
    my $index = 1;

    for my $i (0, 2 .. $feature_num) {
        for my $j (-2..2){ $buff .= "U".$index++.":%x[$j,$i]\n";}
        for my $k (-2..1){ $buff .= "U".$index++.":%x[$k,$i]/%x[".($k+1).",$i]\n";}
        for my $l (-2..0){ $buff .= "U".$index++.":%x[$l,$i]/%x[".($l+1).",$i]/%x[".($l+2).",$i]\n";}
    }
    $buff .= "\n";

    my @features = qw(2_3_1 2_4_1 2_5_1 2_3_3 2_4_3 2_5_3);
    foreach my $feature ( @features ) {
        my ($arg1, $arg2, $type) = split(/\_/, $feature);
        if ( $type == 0 ) {
            for my $l ( -2 .. 2 ) {
                $buff .= "U".$index++.":%x[$l,$arg1]/%x[$l,$arg2]\n";
            }
            $buff .= "\n";
        } elsif ( $type == 1 ) {
            for my $l ( -2 .. 1 ) {
                $buff .= "U".$index++.":%x[$l,$arg1]/%x[".($l+1).",$arg2]\n";
                $buff .= "U".$index++.":%x[$l,$arg2]/%x[".($l+1).",$arg1]\n";
            }
            $buff .= "\n";
        } elsif ( $type == 2 ) {
            for my $l ( -2 .. 1 ) {
                $buff .= "U".$index++.":%x[$l,$arg1]/%x[".($l+1).",$arg2]\n";
                $buff .= "U".$index++.":%x[$l,$arg2]/%x[".($l+1).",$arg1]\n";
            }
            for my $l ( -2 .. 0 ) {
                $buff .= "U".$index++.":%x[$l,$arg1]/%x[".($l+2).",$arg2]\n";
                $buff .= "U".$index++.":%x[$l,$arg2]/%x[".($l+2).",$arg1]\n";
            }
            $buff .= "\n";
        } elsif ( $type == 3 ) {
            for my $l ( -2 .. 1 ) {
                if ( $arg1 > 3 ) {
                    $buff .= "U".$index++.":%x[$l,$arg1]/%x[$l,$arg2]/%x[".($l+1).",$arg1]\n";
                    $buff .= "U".$index++.":%x[$l,$arg1]/%x[".($l+1).",$arg1]/%x[".($l+1).",$arg2]\n";
                }
                $buff .= "U".$index++.":%x[$l,$arg1]/%x[$l,$arg2]/%x[".($l+1).",$arg2]\n";
                $buff .= "U".$index++.":%x[$l,$arg2]/%x[".($l+1).",$arg1]/%x[".($l+1).",$arg2]\n";
            }
            $buff .= "\n";
        }
    }

    $buff .= "\nB\n";

    $self->write_to_file($template_file, $buff);
    undef $buff;
}

## テンプレート(後処理用)の作成
sub create_BI_template {
    my ($self, $template_file, $feature_num, $num) = @_;

    my $buff = "";
    my $index = 0;
    foreach my $i ( 0 .. $feature_num ) {
        $buff .= "U".$index++.":%x[0,".$i."]\n";
    }
    $buff .= "\n";
    foreach my $i ( 0 .. $feature_num/3 ) {
        $buff .= "U".$index++.":%x[0,".$i."]/%x[0,".($i+$feature_num/3)."]\n";
        $buff .= "U".$index++.":%x[0,".($i+$feature_num/3)."]/%x[0,".($i+$feature_num/3*2)."]\n";
    }
    for my $i ( 1 .. $num ) {
        $buff .= "U".$index++.":%x[0,".($feature_num+$i)."]\n";
    }
    #$buff .= "\nB\n";
    $buff .= "\n";
    $self->write_to_file($template_file, $buff);
    undef $buff;
}

## CRFとMIRAでは行毎に改行を追加
## MIRAではセパレータをスペースからタブに変更
sub change_format {
    my ($self, $file, $is_mira) = @_;

    my $buff = $self->read_from_file($file);
    $buff =~ s/\n\n/\n/g;
    $buff =~ s/\n/\n\n/g;
    if ( $is_mira ) {
        $buff =~ s/ /\t/g;
    }

    $self->write_to_file($file, $buff);
    undef $buff;
}

sub check_luwmodel {
   my ($self, $luwmodel) = @_;

   if ( $self->{"luwmodel"} eq "SVM" || $self->{"luwmodel"} eq "CRF" ) {
       unless ( -f $luwmodel ) {
           printf(STDERR "ERROR: '%s' not found or not a file.\n",
                  $luwmodel);
           die;
       }
   } elsif ( $self->{"luwmodel"} eq "MIRA" ) {
       unless ( -d $luwmodel ) {
           printf(STDERR "ERROR: '%s' not found or not a dir.\n",
                  $luwmodel);
           die;
       }
   } else {
       printf(STDERR "ERROR: '%s' not found model name.\n",
              $self->{"luwmodel"});
       die;
   }
}

sub get_yamcha_tool_dir {
    my $self = shift;
    my $yamcha_tool_dir = $self->{"yamcha-dir"}."/libexec/yamcha";
    unless ( -d $yamcha_tool_dir ) {
        $yamcha_tool_dir = $self->{"yamcha-dir"}."/../libexec/yamcha";
    }
    unless ( -d $yamcha_tool_dir ) {
        printf(STDERR "# Error: not found YAMCHA TOOL_DIR (libexec/yamcha) '%s'\n",
               $yamcha_tool_dir);
        $yamcha_tool_dir = undef;
    }
    return $yamcha_tool_dir;
}

sub get_svm_tool_dir {
    my $self = shift;
    my $svm_tool_dir = $self->{"svm-tool-dir"};
    unless ( -d $svm_tool_dir ) {
        $svm_tool_dir = undef;
    }
    return $svm_tool_dir;
}

sub get_crf_dir {
    my $self = shift;
    my $crf_dir = $self->{"crf-dir"};
    unless ( -d $crf_dir ) {
        $crf_dir = undef;
    }
    return $crf_dir;
}

sub get_mira_dir {
    my $self = shift;
    my $mira_dir = $self->{"mira-dir"};
    unless ( -d $mira_dir ) {
        $mira_dir = undef;
    }
    return $mira_dir;
}

sub get_mstparser_dir {
    my $self = shift;
    my $mstparser_dir = $self->{"mstparser-dir"};
    unless ( -d $mstparser_dir ) {
        $mstparser_dir = undef;
    }
    return $mstparser_dir;
}

sub load_yamcha_training_conf {
    my ($self, $file) = @_;
    my $conf = {};
    open(my $fh, $file) or die "Cannot open '$file'";
    while ( my $line = <$fh> ) {
        $line =~ s/\r?\n$//;
        if ( $line =~ /^\#/ or $line =~ /^\s*$/ ) {
            next;
        }
        if ( $line =~ /^(.*?)=(.*)/ ) {
            my ($key, $value) = ($1, $2);
            $value =~ s/^\s*\"(.*)\"$\s*$/$1/;
            $value =~ s/^\s*\'(.*)\'$\s*$/$1/;
            $conf->{$key} = $value;
        }
    }
    close($fh);
    return $conf;
}

sub check_yamcha_training_makefile_template {
    my ($self, $yamcha_training_makefile_template) = @_;

    unless ( -f $yamcha_training_makefile_template ) {
        printf(STDERR "# Warning: Not found yamcha_training_makefile_template \"%s\"\n", $yamcha_training_makefile_template);
        return 0;
    }

    my $buff = $self->read_from_file($yamcha_training_makefile_template);
    if ( $buff !~ /^train:/ms ) {
        printf(STDERR "# Warning: Not found \"train:\" target in yamcha_training_makefile_template \"%s\"\n", $yamcha_training_makefile_template);
        return 0;
    }
    return 1;
}

## KCファイルを文節用の学習データに変換
sub kc2bnstsvmdata {
    my ($self, $data, $is_train) = @_;
    my $res = "";

    my $parenthetic = 0;
    foreach my $line ( split(/\r?\n/,$data) ) {
        if ( $line eq "EOS" ) {
            if ( $is_train == 1 ) {
                $res .= $line."\n";
            } else {
                $res .= $line."\n*B\n";
            }
            $parenthetic = 0;
        } elsif ( $line =~ /^\*B/ ) {
            if ( $is_train ) {
                $res .= $line."\n";
            }
        } else {
            my @items = split(/[ \t]/, $line);
            my @pos = split(/\-/, $items[3]."-*-*-*");
            my @cType = split(/\-/, $items[4]."-*-*");
            my @cForm = split(/\-/, $items[5]."-*-*");
            $res .= join(" ",@items[0..5]);
            #$res .= join(" ",@items[1,3,5..7]);
            $res .= " ".join(" ",@pos[0..3])." ".join(" ",@cType[0..2])." ".join(" ",@cForm[0..2]);
            #$res .= " $pos[0] $pos[1] $cType[0] $cType[1] $cForm[0] $cForm[1]\n";
            if ( $items[3] eq "補助記号-括弧開" ) {
                if ( !$parenthetic ) {
                    $res .= " B";
                } else {
                    $res .= " I";
                }
                $parenthetic++;
            } elsif ( $items[3] eq "補助記号-括弧閉" ) {
                $parenthetic--;
                $res .= " I";
            } elsif ( $parenthetic ) {
                $res .= " I";
            } else {
                $res .= " O";
            }
            $res .= "\n";
        }
    }

    undef $data;

    return $res;
}


# from unix/perls/bccwj2kc
# -----------------------------------------------------------------------------
# BCCWJの形式をComainu長単位解析の入力形式に変換
# -----------------------------------------------------------------------------
sub bccwj2kc {
    my ($self, $data) = @_;
    return $self->bccwj2kc_internal($data, "");
}

# from unix/perls/bccwj2kc2.perl
# -----------------------------------------------------------------------------
# BCCWJの形式をComainu長単位解析の入力形式に変換
# -----------------------------------------------------------------------------
sub bccwj2kc2 {
    my ($self, $data) = @_;
    return $self->bccwj2kc_internal($data, "2");
}

# from unix/perls/bccwj2kc_with_luw.perl
# -----------------------------------------------------------------------------
# BCCWJの形式をComainu長単位解析の入力形式に変換
# -----------------------------------------------------------------------------
sub bccwj2kc_with_luw {
    my ($self, $data) = @_;
    return $self->bccwj2kc_internal($data, "with_luw");
}

sub bccwj2kc_internal {
    my ($self, $data, $type) = @_;
    # my $cn = 17;
    my $cn = 27;
    if ( $self->{"boundary"} eq "word" || $type eq "with_luw" ) {
        # $cn = 24;
        # $cn = 25;
        $cn = 34;
    }
    my $res = "";
    foreach ( split(/\r?\n/, $data) ) {
        # chomp;
        my @suw = split(/\t/);
        # if ($suw[4] =~ /^B/ || ($self->{"boundary"} eq "word" and $suw[14] ne "NULL")) {
        # if ($suw[4] =~ /^B/ || ($self->{"boundary"} eq "word" and $suw[18] ne "NULL")) {
	    # print "*B\n";
	    # $res .= "*B\n";
        # }
        # if ($res ne "" && $suw[3] =~ /^B/ || ($self->{"boundary"} eq "word" and $suw[28] ne "NULL")) {
        if ( $res ne "" && $suw[3] =~ /^B/ ) {
            $res .= "EOS\n";
        }
        if( ($self->{"boundary"} eq "word" || $type eq "with_luw") && $suw[27] =~ /B/ ) {
            $res .= "*B\n";
        }
        if ($suw[6] eq "" || $suw[6] =~ /NULL/) {
            $suw[6] = $suw[5];
        }
        if ($suw[7] eq "" || $suw[7] =~ /NULL/) {
            $suw[7] = $suw[5];
        }
        for my $i ( 0 .. $cn ) {
            if ( $suw[$i] eq "" || $suw[$i] =~ /NULL/ ) {
                $suw[$i] = "*";
            }
        }

        #$res .= "$suw[5] $suw[5] $suw[7] $suw[8] $suw[6] ";
        $res .= "$suw[4] $suw[5] $suw[6] $suw[8] $suw[9] $suw[10] ";
        $res .= "$suw[16] $suw[17] $suw[18] $suw[19] $suw[22] $suw[23] $suw[21] ";
        # if($self->{"boundary"} eq "word") {
	    # print "$suw[5] $suw[5] $suw[7] $suw[8] $suw[6] ";
	    # print "$suw[10] $suw[11] $suw[12] * * * ";
	    # $res .= "$suw[5] $suw[5] $suw[7] $suw[8] $suw[6] ";
	    # $res .= "$suw[10] $suw[11] $suw[12] * * * ";
        # } else {
	    # print "$suw[5] $suw[5] $suw[7] $suw[8] $suw[6] $suw[9] ";
	    # print "$suw[10] $suw[11] * * * ";
	    # $res .= "$suw[5] $suw[5] $suw[7] $suw[8] $suw[6] $suw[9] ";
	    # $res .= "$suw[10] $suw[11] * * * ";
        # }
        if ( $type eq "with_luw" && $suw[27] =~ /B/ ) {
            # print "$suw[16] $suw[17] $suw[18] * * * $suw[22] $suw[23]\n";
            # $res .= "$suw[16] $suw[17] $suw[18] * * * $suw[22] $suw[23]\n";
            # $res .= "$suw[19] $suw[20] $suw[21] * * * $suw[22] $suw[23]\n";
            $res .= "$suw[31] $suw[32] $suw[33] $suw[29] $suw[30] $suw[28]\n";
        } else {
            # print "* * * * * * * *\n";
            $res .= "* * * * * *\n";
        }
    }

    undef $data;

    return $res;
}

# from unix/perls/eval_long.perl
# -----------------------------------------------------------------------------
# *.KC (京大コーパス形式を少し変更したデータ) と *.out (システムの出力)を
# 比較し、精度を求める
# segmentaion と POS information (発音を除くすべて)
# -----------------------------------------------------------------------------
sub eval_long {
    my ($self, $gldf, $sysf, $middle) = @_;
    my $gld;
    my $sys;
    my $agr;
    my $tmp = $self->{"comainu-temp"};
    my $tmpFile1 = "$tmp/".$$."tmp1";
    my $tmpFile2 = "$tmp/".$$."tmp2";
    open(GLD, $gldf) || die "Can't open $gldf: $!\n";
    open(TMP, ">$tmpFile1") || die "Can't open $tmpFile1: $!\n";
    while ( <GLD> ) {
        if ( /^\#/ || /^\*/ ) {
            next;
        }
        if ( /^EOS/ ) {
            # print TMP;
            next;
        }
        chomp;
        my @morph = split(/\s+/);
        my @pos;
        if ( $middle ) {
            print TMP "$morph[0]\n";
        } else {
            print TMP "$morph[0] $morph[1] $morph[2] $morph[3] $morph[4] $morph[5]\n";
        }
    }
    close(GLD);
    close(TMP);

    open(SYS, $sysf) || die "Can't open $sysf: $!\n";
    open(TMP, ">$tmpFile2") || die "Can't open $tmpFile2: $!\n";
    while ( <SYS> ) {
        if (/^\#/ || /^\*/) {
            next;
        }
        if (/^EOS/) {
            # print TMP "EOS\n";
            next;
        }
        chomp;
        my @morph = split(/\s+/);
        if ( $middle ) {
            print TMP "$morph[0]\n";
        } else {
            print TMP "$morph[0] $morph[1] $morph[2] $morph[3] $morph[4] $morph[5]\n";
        }
    }
    close(SYS);
    close(TMP);

    my $dif = $sysf.".diff";
    $self->diff_perl($tmpFile1, $tmpFile2, $dif);

    my $fg = 0;
    my $fs = 0;
    open(TMP, $dif) || die "Can't open $dif: $!\n";
    while ( <TMP> ) {
        if (/^\;\_/) {
            $fg++;
            next;
        } elsif (/^\;\*/) {
            $fg = 0;
            $fs++;
            next;
        } elsif (/^\;\~/) {
            $fs = 0;
            next;
        } elsif (/^EOS/) {
            next;
        }

        if ($fg == 0 && $fs == 0) {
            $gld++;
            $sys++;
            $agr++;
        } elsif ($fg > 0) {
            $gld++;
        } elsif ($fs > 0) {
            $sys++;
        } else {
            print STDERR "ERROR!\n";
        }
    }
    close(TMP);

    my $rec = 0.0;
    if ($gld > 0) { $rec = $agr / $gld * 100; }
    my $prec = 0.0;
    if ($sys > 0) { $prec = $agr / $sys * 100; }
    my $f = 0.0;
    if (($rec + $prec) > 0) { $f = 2 * $rec * $prec / ($rec + $prec); }

    # printf("Recall: %.2f\% ($agr/$gld) ", $rec);
    # printf("Precision: %.2f\% ($agr/$sys) ", $prec);
    # printf("F-measure: %.2f\%\n", $f);

    my $res = "";
    $res .= sprintf("Recall: %.2f\% ($agr/$gld) ", $rec);
    $res .= sprintf("Precision: %.2f\% ($agr/$sys) ", $prec);
    $res .= sprintf("F-measure: %.2f\%\n", $f);

    unlink "$tmpFile1";
    unlink "$tmpFile2";

    return $res;
}

sub diff_perl {
    my ($self, $tmpFile1, $tmpFile2, $dif) = @_;
    my $tmp = $self->{"comainu-temp"};
    my $tmpFile = "$tmp/".$$.".tmp";

    system("diff -D".$;." \"$tmpFile1\" \"$tmpFile2\" > \"$tmpFile\"");

    # my $diff = LCSDiff->new("-D" => $;);
    # open(my $fh, ">", $tmpFile) or die "Cannot open '$tmpFile'";
    # $diff->diff($tmpFile1, $tmpFile2, sub { print $fh $_[0]; });
    # close($fh);

    open(DIF, ">", $dif) or die "Cannot open '$dif'";

    my $flag;
    open(DF, "$tmpFile");
    while (<DF>) {
        chomp;
        if (/^\#ifn/ && /$;/) {
            $flag = 1;
            # print ";______\n";
            print DIF ";______\n";
        } elsif (/^\#if/ && /$;/) {
            $flag = 2;
            # print ";______\n";
            # print ";***\n";
            print DIF ";______\n";
            print DIF ";***\n";
        } elsif (/^\#else/ && /$;/) {
            $flag = 2;
            # print ";***\n";
            print DIF ";***\n";
        } elsif (/^\#end/ && $flag == 1 && /$;/) {
            $flag = 0;
            # print ";***\n";
            # print ";~~~~~~\n";
            print DIF ";***\n";
            print DIF ";~~~~~~\n";
        } elsif (/^\#end/ && $flag == 2 && /$;/) {
            $flag = 0;
            # print ";~~~~~~\n";
            print DIF ";~~~~~~\n";
        } else {
            # print "$_\n";
            print DIF "$_\n";
        }
    }
    close(DF);
    unlink "$tmpFile";
    close(DIF);
}

# from unix/perls/marge_iof.perl
# from unix/perls/marge_iof2.perl
# -----------------------------------------------------------------------------
# bccwj形式のファイルに長単位解析結果をマージ
# -----------------------------------------------------------------------------
sub merge_iof {
    my ($self, $bccwj_data, $lout_data) = @_;
    my $res = "";
    my $cn1 = 16;
    #my $cn1 = 26;
    if ( $self->{"boundary"} eq "word" ) {
        #$cn1 = 23;
        $cn1 = 27;
        #$cn1 = 34;
    }
    my $cn2 = 19;
    $lout_data =~ s/^EOS.*?\n//mg;
    my @m = split(/\r?\n/, $lout_data);
    undef $lout_data;

    my $long_pos = "";
    foreach ( split(/\r?\n/, $bccwj_data) ) {
        my @morph = split(/\t/);
        if ($#morph+1 < $cn1) {
            print STDERR "Some columns are missing in bccwj_data!\n";
            print STDERR "  morph(".($#morph+1).") < sn1(".$cn1.")\n";
        }
        my $lw = shift(@m);
        # my @ml = split(/\s/, $lw);
        $lw = shift(@m) if($lw =~ /^EOS|^\*B/);
        my @ml = split(/[ \t]/, $lw);
        if ($#ml+1 < $cn2) {
            print STDERR "Some columns are missing in bccwj_data!\n";
            print STDERR "  ml(".($#ml+1).") < cn2(".$cn2.")\n";
            print STDERR "$ml[1]\n";
        }
        #if ($morph[5] ne $ml[1]) {
        if ($morph[4] ne $ml[1]) {
            print STDERR "Two files cannot be marged!: '$morph[4]' ; '$ml[1]'\n";
        }
        if ($ml[0] =~ /^B/) {
            $long_pos = $ml[14];
        }
        if ( $self->{"boundary"} eq "word" ) {
            @morph[28..33] = @ml[19,17..18,14..16];
        } else {
            @morph[27..33] = @ml[0,19,17..18,14..16];
        }
        if ( $morph[8] eq "名詞-普通名詞-形状詞可能" ||
                 $morph[8] eq "名詞-普通名詞-サ変形状詞可能" ) {
            if ( $long_pos eq "形状詞-一般" ) {
                $morph[11] = "形状詞";
            } else {
                $morph[11] = "名詞";
            }
        } elsif ( $morph[8] eq "名詞-普通名詞-副詞可能" ) {
            if ( $long_pos eq "副詞" ) {
                $morph[11] = "副詞";
            } else {
                $morph[11] = "名詞";
            }
        }
        my $nm = join("\t", @morph);
        $res .= "$nm\n";
    }

    undef $bccwj_data;

    if ( $#m > -1 ) {
        print STDERR "Two files do not correspond to each other!\n";
    }
    return $res;
}

# from unix/perls/pp_ctype.pl
# -----------------------------------------------------------------------------
# 後処理（「動詞」となる長単位の活用型、活用形）
# アドホックな後処理-->書き換え規則を変更する方針
# -----------------------------------------------------------------------------
sub pp_ctype {
    my ($self, $data) = @_;
    my $res = "";
    my @lw;
    foreach ( split(/\r?\n/, $data) ) {
        if (/^B/) {
            if ($#lw > -1) {
                # modified by jkawai
                # my @last = split(/\s/, $lw[$#lw]);
                my @last = split(/[ \t]/, $lw[$#lw]);
                if ($last[8] ne "*") {
                    # modified by jkawai
                    # my @first = split(/\s/, shift(@lw));
                    my @first = split(/[ \t]/, shift(@lw));
                    if ($first[13] eq "*" && $first[12] =~ /^動詞/) {
                        $first[13] = $last[7];
                   }
                    if ($first[14] eq "*" && $first[12] =~ /^動詞/) {
                        $first[14] = $last[8];
                    }
                    unshift(@lw, join(" ", @first));
                }
                foreach (@lw) {
                    # print "$_\n";
                    $res .= "$_\n";
                }
                @lw = ();
                push(@lw, $_);
            } else {
                push(@lw, $_);
            }
        } else {
            push(@lw, $_);
        }
    }
    undef $data;

    if ($#lw > -1) {
        # my @last = split(/\s/, $lw[$#]);
        # my @last = split(/\s/, $lw[$#lw]); # fixed by jkawai
        my @last = split(/[ \t]/, $lw[$#lw]); # fixed by jkawai
        if ($last[8] ne "*") {
            # my @first = split(/\s/, $lw[0]);
            my @first = split(/[ \t]/, $lw[0]);
            if ($first[13] eq "*" && $first[12] =~ /^動詞/) {
                $first[13] = $last[7];
            }
            if ($first[14] eq "*" && $first[12] =~ /^動詞/) {
                $first[14] = $last[8];
            }
        }
        foreach (@lw) {
            # print "$_\n";
            $res .= "$_\n";
        }
    }
    return $res;
}


# -----------------------------------------------------------------------------
# 前処理（partial chunkingの入力フォーマットへの変換）
# -----------------------------------------------------------------------------
sub pp_partial {
    my ($self, $data) = @_;
    my $res = "";
    my ($prev, $curr, $next) = (0, 1, 2);
    my $buff_list = [undef, undef];

    foreach my $line ((split(/\r?\n/, $data), undef, undef)) {
        push(@$buff_list, $line);
        if ( defined($buff_list->[$curr]) && $buff_list->[$curr] !~ /^EOS/ &&
                 $buff_list->[$curr] !~ /^\*B/) {
            my $mark = "";
            if ( $buff_list->[$prev] =~ /^EOS/ || $buff_list->[$prev] =~ /^\*B/) {
                $mark = "B Ba";
            } elsif ( !defined $buff_list->[$prev] ) {
                $mark = "B Ba";
            } else {
                if ( $self->{"boundary"} ne "word" ) {
                    $mark = "B Ba I Ia";
                } else {
                    $mark = "I Ia";
                }
            }
            $buff_list->[$curr] .= " ".$mark;
        }
        my $new_line = shift(@$buff_list);
        if ( defined($new_line) and $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }
    while ( my $new_line = shift(@$buff_list) ) {
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }

    undef $data;
    undef $buff_list;

    return $res;
}

sub pp_partial_bnst {
    my ($self, $data) = @_;
    my $res = "";
    my ($prev, $curr, $next) = (0, 1, 2);
    my $buff_list = [undef, undef];

    foreach my $line ((split(/\r?\n/, $data), undef, undef)) {
        push(@$buff_list, $line);
        if ( defined $buff_list->[$curr] && $buff_list->[$curr] !~ /^EOS/ &&
                 $buff_list->[$curr] !~ /^\*B/) {
            my $mark = "";
            if ( $buff_list->[$prev] =~ /^EOS/ || $buff_list->[$prev] =~ /^\*B/) {
                $mark = "B";
            } elsif ( !defined $buff_list->[$prev] ) {
                $mark = "B";
            } else {
                $mark = "B I";
            }
            $buff_list->[$curr] .= " ".$mark;
        }
        my $new_line = shift(@$buff_list);
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }
    while ( my $new_line = shift(@$buff_list) ) {
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }

    undef $data;
    undef $buff_list;

    return $res;
}

sub pp_partial_bnst_with_luw {
    my ($self, $data, $svmout_file) = @_;
    my $res = "";
    my ($prev, $curr, $next) = (0, 1, 2);
    my $buff_list = [undef, undef];

    my $svmout_data = $self->read_from_file($svmout_file);
    my $svmout_item_list = [split(/\r?\n/, $svmout_data)];
    undef $svmout_data;

    foreach my $line ( (split(/\r?\n/, $data), undef, undef) ) {
        push(@$buff_list, $line);
        if ( defined $buff_list->[$curr] && $buff_list->[$curr] !~ /^EOS/ &&
                 $buff_list->[$curr] !~ /^\*B/) {
            my $mark = "";
            my $lw = shift(@$svmout_item_list);
            my @svmout = split(/[ \t]/,$lw);
            if ( $buff_list->[$prev] =~ /^EOS/ || $buff_list->[$prev] =~ /^\*B/) {
                $mark = "B";
            } elsif ( !defined $buff_list->[$prev] ) {
                $mark = "B";
            } else {
                if ( $svmout[0] =~ /I/ ) {
                    $mark = "I";
                } else {
                    if ( $svmout[4] =~ /^動詞/ ) {
                        $mark = "B";
                    } elsif ( $svmout[4] =~ /^名詞|^形容詞|^副詞|^形状詞/ &&
                                  ($svmout[21] == 1 || $svmout[22] == 1) ) {
                        $mark = "B";
                    } else {
                        $mark = "B I";
                    }
                }
            }
            $buff_list->[$curr] .= " ".$mark;
        }
        my $new_line = shift(@$buff_list);
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }
    while ( my $new_line = shift(@$buff_list) ) {
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }

    undef $data;
    undef $buff_list;
    undef $svmout_item_list;

    return $res;
}


# from unix/perls/pp_partial.perl
# -----------------------------------------------------------------------------
# 前処理(旧)（partial chunkingの入力フォーマットへの変換）
# -----------------------------------------------------------------------------
sub pp_partial_old {
    my ($self, $data) = @_;
    my $res = "";
    foreach ( split(/\r?\n/, $data) ) {
        # my @line = split(/\s/);
        my @line = split(/[ \t]/);
        # if ($line[$#line] eq "LRBN") {
        if ($line[$#line] eq "L" || $line[$#line] eq "B") {
            push(@line, "B", "Ba");
        } elsif ($line[$#line] eq "R" || $line[$#line] eq "N") {
            if ( $self->{"boundary"} eq "sentence" ) {
                # sentence boundary
                push(@line, "B", "Ba", "I", "Ia");
            } else {
                # word boundary
                push(@line, "I", "Ia");
            }
        } else {
            # print "$_\n";
            # $res .= "$_\n";
        }
        # print "@line\n";
        $res .= "@line\n";
    }
    return $res;
}

sub pp_partial_bnst_old {
    my $self = shift;
    my ($data) = @_;
    my $res = "";
    foreach $_  (split(/\r?\n/, $data)) {
	my @line = split(/[ \t]/);
	if ($line[$#line] eq "L" || $line[$#line] eq "B") {
	    push(@line, "B");
	} elsif ($line[$#line] eq "R" || $line[$#line] eq "N") {
	    if($self->{"boundary"} eq "sentence") {
		# sentence boundary
		push(@line, "B", "I");
	    } else {
		# word boundary
		push(@line, "I");
	    }
	} else {
	    #$res .= "$_\n";
	}
	$res .= "@line\n";
    }
    return $res;
}


# from unix/perls/short2long.perl
# -----------------------------------------------------------------------------
# *.KCの長単位の情報を短単位に置き換える。
# -----------------------------------------------------------------------------
sub short2long_old {
    my ($self, $data) = @_;
    my $res = "";
    my @morph;
    foreach ( split(/\r?\n/, $data) ) {
        my @elem = split(/[ \t]/);
        if ($elem[0] =~ /^[BI]/) { # remove B,Ba,I,Ia field *.lout
            shift(@elem);
            $elem[17] = "*" if($elem[17] eq "");
            $elem[18] = "*" if($elem[18] eq "");
        }
        if (/^\*B/ || /^EOS/) {
            next;
        } elsif ($elem[11] eq '*') {
            push(@morph, join(' ', @elem));
        } else {
            my $next = join(' ', @elem);
            my $str;
            my @com;
            my @com2;
            my @longm;
            my @longm2;
            my $m;
            while ($m = shift(@morph)) {
                # my @melem = split(/\s/, $m);
                my @melem = split(/[ \t]/, $m);
                my $flag;
                if ($#melem < 18) {
                    # $m =~ s/\*([^\s]+)/\* $1/g;
                    $m =~ s/\*([^ \t]+)/\* $1/g;
                }
                if ($m =~ /^\*B/) {
                    push(@com, $m);
                } else {
                    # my @h = split(/\s/, $m);
                    my @h = split(/[ \t]/, $m);
                    if (defined($str)) {
                        $str .= $h[0];
                        if (@com && $#com > -1) {
                            push(@com2, @com);
                            @com = ();
                        }
                    } else {
                        $str = $h[0];
                        @longm = splice(@h, 11);
                        @longm2 = splice(@longm, 6);
                        if ($#longm2 > 1) {
                            pop(@longm2);
                        }
                    }
                }
            }

            if ($#com > -1 && $#com2 > -1 && defined($str)) {
                my $c = join('', @com);
                my $c2 = join('', @com2);
                unshift(@longm, $str, @longm2);
                # print "$c2\n@longm\n$c\n";
                $res .= "$c2\n@longm\n$c\n";
            } elsif ($#com > -1 && $#com2 > -1) {
                my $c = join('', @com);
                my $c2 = join('', @com2);
                # print "$c$c2\n";
                $res .= "$c$c2\n";
            } elsif ($#com > -1 && defined($str)) {
                my $c = join('', @com);
                unshift(@longm, $str, @longm2);
                # print "@longm\n$c\n";
                $res .= "@longm\n$c\n";
            } elsif ($#com2 > -1 && defined($str)) {
                my $c2 = join('', @com2);
                unshift(@longm, $str, @longm2);
                # print "$c2\n@longm\n";
                $res .= "$c2\n@longm\n";
            } elsif ($#com > -1 ) {
                my $c = join('', @com);
                # print "$c\n";
                $res .= "$c\n";
            } elsif ($#com2 > -1) {
                my $c2 = join('', @com2);
                # print "$c2\n";
                $res .= "$c2\n";
            } elsif (defined($str)) {
                unshift(@longm, $str, @longm2);
                # print "@longm\n";
                $res .= "@longm\n";
            } elsif ($#morph > -1) {
                print STDERR "ERROR!!: @morph : @elem\n";
            } else {
            }
            @morph = ();
            push(@morph, $next);
        }
    }
    return $res;
}

sub short2long {
    my ($self, $data) = @_;
    my $res = "";

    foreach ( split(/\r?\n/, $data) ) {
    	next if /^\*B/ || /^EOS/;

        my @elem = split(/[ \t]/);
        if ($elem[0] =~ /^[BI]/) { # remove B,Ba,I,Ia field *.lout
            shift(@elem);
        }
        $elem[16] = "*" if($elem[16] eq "");
        $elem[17] = "*" if($elem[17] eq "");
        if ($elem[13] ne "" && $elem[13] ne "*") {
            $res .= join(" ",@elem[18,16,17,13..15])."\n";
        }
    }
    undef $data;

    return $res;
}

sub short2middle_old {
    my ($self, $data) = @_;
    my $res = "";

    foreach ( split(/\r?\n/, $data) ) {
        my @morph = split(/[ \t]/);
        next if $morph[0] =~ /^\*B|^EOS/;

        if ( $morph[21] ne "" ) {
            #$res .= join(" ", @morph[21..25])."\n";
            $res .= $morph[21]."\n";
        }
    }
    return $res;
}

sub short2middle {
    my ($self, $data) = @_;
    my $res = "";

    my @muws;
    my $muw_id = -1;
    foreach my $line ( split(/\r?\n/,$data) ) {
        my $mrph = [split(/[ \t]/, $line)];
        next if $$mrph[0] =~ /^\*B|^EOS/;

        $muw_id++ if $$mrph[21] ne "" && $$mrph[21] ne "*";
        push @{$muws[$muw_id]},$mrph;
    }
    foreach my $muw (@muws) {
        if ( scalar(@$muw) > 0 ) {
            my $first = $$muw[0];
            $res .= $$first[21]."\n";
        }
    }

    undef $data;

    return $res;
}

sub short2bnst {
    my ($self, $data) = @_;
    my $res = "";

    my $BOB = "B";
    foreach ( split(/\r?\n/, $data) ) {
        my @morph = split(/[ \t]/);
        if ( $morph[0] =~ /^\*B|^EOS/ ) {
            $BOB = "B";
            next;
        } elsif ( $morph[0] eq "B" || $morph[0] eq "I" ) {
            $BOB = shift(@morph);
        }
        if ( $BOB eq "B" ) {
            $BOB = "I";
            $res .= "\n" if $res ne "";
        }
        $res .= $morph[0];
    }

    undef $data;

    return $res;
}


# from unix/src/longanalyze/src/add_column.cpp
# 文節情報に基づいたカラムを追加して出力する
#
# 付加条件：
# 前の行に*Bや*Pがある場合は L
# 後ろの行に*Bや*Pがある場合は R
# 両方にある場合は B
# どちらにも無い場合はN
# ファイル終端行は R または B
sub add_column {
    my ($self, $data) = @_;
    my $res = "";
    my ($prev, $curr, $next) = (0, 1, 2);
    my $buff_list = [undef, undef];

    $data .= "*B\n";
    foreach my $line ((split(/\r?\n/, $data), undef, undef)) {
        push(@$buff_list, $line);
        if ( defined $buff_list->[$curr] && $buff_list->[$curr] !~ /^EOS/ &&
                 $buff_list->[$curr] !~ /^\*B/ ) {
            my $mark = "";
            if ( $buff_list->[$prev] =~ /^\*B/ && $buff_list->[$next] =~ /^\*B/) {
                $mark = "B";
            } elsif ( $buff_list->[$prev] =~ /^\*B/ ) {
                $mark = "L";
            } elsif ( $buff_list->[$next] =~ /^\*B/ ) {
                $mark = "R";
            } else {
                $mark = "N";
            }
            $buff_list->[$curr] .= " ".$mark;
        }
        my $new_line = shift(@$buff_list);
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }
    while ( my $new_line = shift(@$buff_list) ) {
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }

    undef $data;
    undef $buff_list;

    return $res;
}

# from unix/src/longanalyze/src/delete_column_long.cpp
# 動作：ホワイトスペースで区切られた１１カラム以上からなる行を一行ずつ読み、
# 　　　２カラム目の内容を取り除いて１から１１カラムまでの内容（１０個の要素がスペース
# 　　　一つで区切られている）の行にして出力する。
# 　　　元のレコードが１１カラムに満たない場合は、該当箇所のデータをブランクとして扱う。
sub delete_column_long {
    my ($self, $data) = @_;
    my $res = "";
    my $num_of_column = 11;
    foreach my $line ( split(/\r?\n/, $data) ) {
        my $items = [split(/[ \t]/, $line)];
        # while(scalar(@$items) < $num_of_column) {
        #    push(@$items, "");
        # }
        if ( scalar(@$items) > 2 ) {
            # $items = [@$items[0, 2 .. $num_of_column - 1]];
            $items = [@$items[0 .. 5, 10 .. 12]];
        }
        $res .= join(" ", @$items)."\n";
    }
    undef $data;

    return $res;
}

# KC2ファイルに対してpivot(Ba, B, I, Ia)を判定し、
# 行頭または行末のカラムとして追加する。
# これは従来のmkep + join_pivot_to_kc2 を置き換える。
# pivot
#    Ba  長単位先頭     品詞一致
#    B   長単位先頭     品詞不一致
#    Ia  長単位先頭以外 品詞一致
#    I   長単位先頭以外 品詞不一致
sub add_pivot_to_kc2 {
    my ($self, $fh_ref_kc2, $fh_kc2, $fh_out, $flag) = @_;
    my $front = (defined($flag) && $flag eq "0");
    my $line_in_list = [<$fh_ref_kc2>];
    my $curr_long_pos = "";

    foreach my $i ( 0 .. $#{$line_in_list} ) {
        my $line = Encode::decode("utf-8", $$line_in_list[$i]);
        #$line = Encode::decode("utf-8", $line);
        $line =~ s/\r?\n$//;
        next if $line =~ /^\*B/;

        if ( $line =~ /^EOS/ ) {
            my $res = "\n";
            $res = Encode::encode("utf-8", $res);
            print $fh_out $res;
            next;
        }

        my $pivot = "";
        my $items = [split(/ /, $line)];
        my $short_pos = join(" ", @$items[3 .. 5]);
        my $long_pos = join(" ", @$items[13 .. 15]);

        if ( $long_pos =~ /^\*/ ) {
            $pivot = "I";
        } else {
            $pivot = "B";
            $curr_long_pos = $long_pos;
        }

        my $line_out = <$fh_kc2>;
        $line_out = Encode::decode("utf-8", $line_out);
        $line_out =~ s/\r?\n$//;

        if ( $short_pos eq $curr_long_pos ) {
            if ( $i < $#{$line_in_list} ) {
                my $next_items = [split(/ /, $$line_in_list[$i+1])];
                my $next_long_pos = join(" ", @$next_items[13 .. 15]);
                if ( $next_long_pos !~ /^\*/ ) {
                    $pivot .= "a";
                }
            } else {
                $pivot .= "a";
            }
            # $pivot .= "a";
        }
        my $res = "";
        if ( $front ) {
            $res = $pivot." ".$line_out."\n";
        } else {
            $res = $line_out." ".$pivot."\n";
        }
        $res = Encode::encode("utf-8", $res);
        print $fh_out $res;
    }
    print $fh_out "\n";

    undef $line_in_list;
}

# from unix/src/longanalyze/src/move_future_front.cpp
# 動作：ホワイトスペースで区切られた１２カラム以上からなる行を１行ずつ読み、
# 　　　次の順に並べなおして出力する。（数字は元のカラム位置。","は説明のために使用。
# 　　　実際の区切りはスペース一つ）
# 　　　（順番： 12, 1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11）
# 　　　元のレコードが１２カラムに満たない場合は、該当箇所のデータをブランクとして扱う。
# 　　　ただし、１レコード以下の行は、その存在を無視する。
sub move_future_front {
    my ($self, $data) = @_;
    my $res = "";
    my $num_of_column = 12;
    foreach my $line ( split(/\r?\n/, $data) ) {
        my $items = [ split(/[ \t]/, $line) ];
        while ( scalar(@$items) < $num_of_column ) {
            push(@$items, "");
        }
        #$items = [@$items[$num_of_column - 1, 0, 0 .. $num_of_column - 2]];
        $items = [ @$items[scalar(@$items) - 1, 0 .. scalar(@$items) - 2 ]];
        $res .= join(" ", @$items)."\n";
    }
    undef $data;
    return $res;
}

# from unix/src/longanalyze/src/truncate_last_column.cpp
# 動作：ホワイトスペースで区切られた１２カラム以上からなる行を１行ずつ読み、
# 　　　１カラム目から１２カラム目までの内容をスペース一つで区切って出力する。
sub truncate_last_column {
    my ($self, $data) = @_;
    my $res = "";
    my $num_of_column = 12;
    foreach my $line ( split(/\r?\n/, $data) ) {
        my $items = [ split(/[ \t]/, $line) ];
        while ( scalar(@$items) < $num_of_column ) {
            push(@$items, "");
        }
        $res .= join(" ", @$items)."\n";
    }
    undef $data;
    return $res;
}

# We don't need them any more.
#   unix/src/longanalyze/src/join_pivot_to_kc2.cpp
#   unix/src/mkep/src/mkep.cpp


#
# poscreateの代わりの関数
# 長単位の品詞・活用型・活用形を生成
#
sub poscreate {
    my ($self, $file) = @_;
    my $res = "";

    my @long;
    open(IN, $file);
    while ( my $line = <IN> ) {
        $line = Encode::decode("utf-8", $line);
        $line =~ s/\r?\n//;
        next if $line eq "";
        my @items = split(/[ \t]/, $line);

        # $items[10] = "*";
        # $items[11] = "*";
        @items[10..15] = ("*","*","*","*","*","*");

        if ( $self->{"luwmrph"} ne "without" ) {
            if ( $items[0] eq "B" || $items[0] eq "Ba" ) {
                map { $res .= join(" ",@$_)."\n" } @long;

                @long = ();
                @items[10..15] = @items[4..6,2,3,1];
            } else {
                my $first = $long[0];
                $$first[13] .= $items[2];
                $$first[14] .= $items[3];
                $$first[15] .= $items[1];
                if ( $items[0] eq "Ia" ) {
                    @$first[10..12] = @items[4..6];
                }
            }
        }
        push @long, [@items[0..15]];
    }
    close(IN);
    map { $res .= join(" ",@$_)."\n" } @long;

    undef @long;

    return $res;
}


sub merge_kc_with_svmout {
    my ($self, $kc_file, $svmout_file) = @_;

    my $res = "";
    my @long;
    my $kc_data = $self->read_from_file($kc_file);
    my $svmout_data = $self->read_from_file($svmout_file);
    my $svmout_data_list = [split(/\r?\n/, $svmout_data)];
    undef $svmout_data;

    foreach my $kc_data_line ( split(/\r?\n/, $kc_data) ) {
    	if ( $kc_data_line =~ /^EOS/ && $self->{"luwmrph"} eq "without" ) {
    	    $res .= "EOS\n";
    	    next;
    	}
    	next if $kc_data_line =~ /^\*B|^EOS/;
    	my @kc_item_list = split(/[ \t]/, $kc_data_line);

    	my $svmout_line = shift(@$svmout_data_list);
    	my $svmout_item_list = [split(/[ \t]/, $svmout_line)];
    	@$svmout_item_list[10..15] = ("*","*","*","*","*","*");

        if ( $$svmout_item_list[0] eq "B" || $$svmout_item_list[0] eq "Ba") {
            map { $res .= join(" ",@$_)."\n" } @long;

            @long = ();
            if ( $self->{"luwmrph"} ne "without" ) {
                @$svmout_item_list[10..15] = @$svmout_item_list[4..6,2,3,1];
            } else {
                @$svmout_item_list[13..15] = @$svmout_item_list[2,3,1];
            }
        } else {
            my $first = $long[0];
            $$first[17] .= $$svmout_item_list[2];
            $$first[18] .= $$svmout_item_list[3];
            $$first[19] .= $$svmout_item_list[1];
            if ( $$svmout_item_list[0] eq "Ia" &&
                     $self->{"luwmrph"} ne "without") {
                @$first[14..16] = @$svmout_item_list[4..6];
            }
        }
        push @long, [@$svmout_item_list[0],@kc_item_list[0..12],@$svmout_item_list[10..15]];
    }

    map { $res .= join(" ",@$_)."\n" } @long;

    undef $kc_data;
    undef $svmout_data_list;
    undef @long;

    return $res;
}

sub merge_kc_with_bout {
    my ($self, $kc_file, $bout_file) = @_;

    my $res = "";
    my $kc_data = $self->read_from_file($kc_file);
    my $bout_data = $self->read_from_file($bout_file);
    my $bout_data_list = [split(/\r?\n/, $bout_data)];
    undef $bout_data;

    foreach my $kc_data_line (split(/\r?\n/, $kc_data)) {
    	next if $kc_data_line =~ /^\*B/;

        if ( $kc_data_line =~ /^EOS/ ) {
    	    $res .= "EOS\n";
    	    next;
    	}
    	my @kc_item_list = split(/[ \t]/, $kc_data_line);
    	my $bout_line = shift(@$bout_data_list);
    	my $bout_item_list = [split(/[ \t]/, $bout_line)];
    	$res .= $$bout_item_list[0]." ".join(" ",@kc_item_list[0..12])."\n";
    }

    undef $kc_data;
    undef $bout_data_list;

    return $res;
}

#
# 語彙素・語彙素読みを生成
#
sub create_long_lemma {
    my ($self, $data, $comp_file) = @_;

    my $comp_data = $self->read_from_file($comp_file);
    my %comp;
    foreach my $line (split(/\r?\n/, $comp_data)) {
    	next if $line eq "";
    	my @items = split(/\t/, $line);
    	$comp{$items[0]."_".$items[1]."_".$items[2]} = $items[3]."_".$items[4];
    }

    my $res = "";
    my @luws;
    my $luw_id = 0;
    foreach my $line (split(/\r?\n/,$data)) {
        my @items = split(/[ \t]/, $line);
        if ( $items[0] eq "EOS" ) {
            $luw_id = $#luws+1;
        } elsif ( $items[0] =~ /B/ ) {
            $luw_id = $#luws+1;
        } else {
            @items[17..19] = ("*","*","*");
        }
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

    for my $i ( 0 .. $#luws ) {
        my $luw = $luws[$i];
        my $first = $$luw[0];
        if ( $$first[0] eq "EOS" ) {
            $res .= "EOS\n";
            next;
        }
        if ( $$first[14] =~ /助詞|助動詞/ && $#{$luw} == 0 ) {
        } elsif ( $$first[14] ~~ ["英単語", "URL", "言いよどみ", "漢文", "web誤脱", "ローマ字文"] ) {
            @$first[17,18] = ("","");
        } elsif ( $$first[19] ~~ ["（）内", "〔〕内", "「」内", "｛｝内",
                                  "〈〉内", "［］内", "《　》内"] ) {
            @$first[17,18] = ("カッコナイ","括弧内");
        } else {
            @$first[17,18] = ("","");
            my $parential = -1;
            for my $j ( 0 .. $#{$luw}-1 ) {
                my $suw = $$luw[$j];
                $self->generate_long_lemma($luw, $first, $suw, 0, 0);
                if ( $$suw[4] eq "補助記号-括弧開" || $$suw[4] eq "補助記号-括弧閉") {
                    $parential++;
                }
            }
            my $last = $$luw[$#{$luw}];
            if($$last[8] eq "補助記号-括弧開" || $$last[8] eq "補助記号-括弧閉") {
                $parential++;
            }
            $self->generate_long_lemma($luw, $first, $last, 1, 0);

            if ( $parential >= 0 && $#{$luw} > 1 ) {
                if($$first[8] eq "補助記号-括弧開" || $$first[8] eq "補助記号-括弧閉") {
                    @$first[17,18] = ("","");
                } elsif ( $$first[4] =~ /名詞-固有名詞-人名|名詞-固有名詞-地名/ ) {
                    @$first[17,18] = @$first[7,1]; ## form, orthToken
                } elsif ( $$first[3] eq "○" && $#{$luw} > 1 ) {
                    @$first[17,18] = @$first[3,9]; ## lemma, formOrthBase
                } elsif ( $$first[5] eq "*" || $$first[5] eq "" ) {
                    @$first[17,18] = @$first[7,9]; ## form, formOrthBase
                } else {
                    @$first[17,18] = @$first[7,10]; ## form, formOrth
                }
                my $j;
                for ($j =1; $j <= $#{$luw}-2; $j++) {
                    my $suw = $$luw[$j];
                    my $suw2 = $$luw[$j+2];
                    if ( $$suw[8] eq "補助記号-括弧開" && $$suw2[8] eq "補助記号-括弧閉" ) {
                        my $pre_suw = $$luw[$j-1];
                        my $post_suw = $$luw[$j+1];
                        if ( join(" ", @$pre_suw[3,2,4..6]) eq join(" ",@$post_suw[3,2,4..6]) ) {
                            $j += 2;
                            next;
                        }
                    }
                    $self->generate_long_lemma($luw, $first, $suw, 0, 1);
                }
                for ($j; $j <= $#{$luw}-1; $j++) {
                    my $suw = $$luw[$j];
                    $self->generate_long_lemma($luw, $first, $suw, 0, 1);
                }
                $self->generate_long_lemma($luw, $first, $last, 1, 1);
            }
            if ( defined $comp{$$first[14]."_".$$first[17]."_".$$first[18]} ) {
                my ($reading, $lemma) = split(/\_/, $comp{$$first[14]."_".$$first[17]."_".$$first[18]});
                if( $$first[18] ~~ ["に因る", "に拠る", "による"] && $$last[6] eq "連用形-一般" ) {
                    ($reading, $lemma) = ("ニヨリ", "により");
                } elsif ( $$first[18] eq "に対する" && $$last[6] eq "連用形-一般" ) {
                    ($reading, $lemma) = ("ニタイシ", "に対し");
                } elsif ( $$first[18] eq "に渡る" && $$last[6] eq "連用形-一般" ) {
                    ($reading, $lemma) = ("ニワタリ", "にわたり");
                }
                $$first[17] = $reading;
                $$first[18] = $lemma;
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
    my ($self, $luw, $first, $suw, $is_last, $is_multi) = @_;

    if( ($$suw[8] eq "補助記号-括弧開" || $$suw[8] eq "補助記号-括弧閉") && !$is_multi ) {
    	$$first[17] .= $$suw[8]; ## fromBase
        $$first[18] .= $$suw[9]; ## formOrthBase
    } elsif ( $$suw[4] =~ /名詞-固有名詞-人名|名詞-固有名詞-地名/ ) {
        $$first[17] .= $$suw[7]; ## form
        $$first[18] .= $$suw[1]; ## orthToken
    } elsif ( $$suw[3] eq "○" && $#{$luw} > 1 ) {
        $$first[17] .= $$suw[3]; ## lemma
        $$first[18] .= $$suw[9]; ## formOrthBase
    } elsif ( $$suw[5] eq "*" || $$suw[5] eq "" ) {
        $$first[17] .= $$suw[7]; ## form
        $$first[18] .= $$suw[9]; ## formOrthBase
    } else {
    	if ( !$is_last ) {
            $$first[17] .= $$suw[7]; ## form
            $$first[18] .= $$suw[10]; ## formOrth
        } else {
            $$first[17] .= $$suw[8]; ## fromBase
            $$first[18] .= $$suw[9]; ## formOrthBase
        }
    }
}


############################################################
# Utilities
############################################################

sub exists_file {
    my ($self, $file) = @_;
    my $flag = (-f $file);
    unless ($flag) {
        printf(STDERR "WARNING: '%s' not Found.\n", $file);
    }
    return $flag;
}

sub read_from_file {
    my ($self, $file) = @_;
    my $data = "";
    open(my $fh, $file) or die "Cannot open '$file'";
    binmode($fh);
    while ( my $line = <$fh> ) {
        $data .= $line;
    }
    close($fh);
    $data = Encode::decode("utf-8", $data);
    return $data;
}

sub write_to_file {
    my ($self, $file, $data) = @_;
    $data = Encode::encode("utf-8", $data) if Encode::is_utf8($data);
    open(my $fh, ">", $file) or die "Cannot open '$file'";
    binmode($fh);
    print $fh $data;
    close($fh);
    undef $data;
}

sub copy_file {
    my ($self, $src_file, $dest_file) = @_;
    my $buff = $self->read_from_file($src_file);
    $self->write_to_file($dest_file, $buff);
    undef $buff;
}

sub proc_stdin2stdout {
    my ($self, $proc, $in_data, $file_in_p) = @_;
    my $out_data = "";
    my $tmp_in = $self->{"comainu-temp"}."/tmp_in";
    my $tmp_out = $self->{"comainu-temp"}."/tmp_out";
    $self->write_to_file($tmp_in, $in_data);
    $self->proc_file2file($proc, $tmp_in, $tmp_out, $file_in_p);
    $out_data = $self->read_from_file($tmp_out);
    unlink($tmp_in);
    unlink($tmp_out);
    undef $in_data;
    return $out_data;
}

sub proc_stdin2file {
    my ($self, $proc, $in_data, $out_file, $file_in_p) = @_;
    my $tmp_in = $self->{"comainu-temp"}."/tmp_in";
    $self->write_to_file($tmp_in, $in_data);
    $self->proc_file2file($proc, $tmp_in, $out_file, $file_in_p);
    unlink($tmp_in);
    undef $in_data;
    return;
}

sub proc_file2file {
    my ($self, $proc, $in_file, $out_file, $file_in_p) = @_;
    my $out_data = "";
    my $redirect_in = $file_in_p ? "" : "<";
    my $proc_com = $proc." ".$redirect_in." \"".$in_file."\" > \"".$out_file."\"";
    if ( $Config{"osname"} eq "MSWin32" ) {
        $proc_com =~ s/\//\\/gs;
    }
    if ( $self->{"debug"} > 0 ) {
        print STDERR "PROC_COM=".$proc_com."\n";
    }
    system($proc_com);
    return;
}

1;
#################### END OF FILE ####################
