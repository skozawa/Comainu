# -*- mode: perl; coding: utf-8; -*-

package Comainu;

use strict;
use FindBin qw($Bin);
use utf8;
use Encode;
use File::Basename;
use File::Temp qw(tempfile);
use Config;

use SUW2LUW;
use LCSDiff;

use Comainu::Dictionary;
use AddFeature;
use BIProcessor;

my $DEFAULT_VALUES = {
    "debug" => 0,
    "comainu-home" => $Bin."/..",
    "comainu-temp" => $Bin."/../tmp/temp",
    "comainu-svm-bip-model" => $Bin."/../train/BI_process_model",
    "data_format" => $Bin."/../etc/data_format.conf",
    "mecab_rcfile" => $Bin."/../etc/dicrc",
    "perl" => "/usr/bin/perl",
    "java" => "/usr/bin/java",
    "yamcha-dir" => "/usr/local/bin",
    "mecab-dir" => "/usr/local/bin",
    "mecab-dic-dir" => "/usr/local/lib/mecab/dic",
    "unidic-db" => "/usr/local/unidic2/share/unidic.db",
    "svm-tool-dir" => "/usr/local/bin",
    "crf-dir" => "/usr/local/bin",
    "mstparser-dir" => "mstparser",
    "boundary" => "none",
    "luwmrph" => "with",
    "suwmodel" => "mecab",
    "luwmodel" => "CRF",
    "bnst_process" => "none",
};

my $KC_MECAB_TABLE_FOR_UNIDIC = {
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

my $KC_MECAB_TABLE_FOR_CHAMAME = {
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

my $UNIDIC_MECAB_TYPE = "chamame";
my $KC_MECAB_TABLE = $KC_MECAB_TABLE_FOR_CHAMAME;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {%$DEFAULT_VALUES, @_};
    bless $self, $class;
    return $self;
}


# 平文からの中単位解析
sub USAGE_plain2midout {
    my $self = shift;
    printf("COMAINU-METHOD: plain2midout\n");
    printf("  Usage: %s plain2midout <test-text> <long-model-file> <mid-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-text> with Mecab and <long-model-file> and <mid-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl plain2midout sample/plain/sample.txt train/CRF/train.KC.model train/MST/train.KC.model out\n");
    printf("    -> out/sample.txt.mout\n");
    printf("\n");
}

sub METHOD_plain2midout {
    my ($self, $test_file, $luwmodel, $muwmodel, $save_dir) = @_;

    $self->check_args(scalar @_ == 5);
    $self->check_luwmodel($luwmodel);
    $self->check_file($muwmodel);
    mkdir $save_dir unless -d $save_dir;

    if ( -f $test_file ) {
        $self->plain2midout_internal($test_file, $luwmodel, $muwmodel, $save_dir);
    } elsif ( -d $test_file ) {
        opendir(my $dh, $test_file);
        while ( my $test_file2 = readdir($dh) ) {
            if ( $test_file2 =~ /.txt$/ ) {
                $self->plain2midout_internal($test_file2, $luwmodel, $muwmodel, $save_dir);
            }
        }
        closedir($dh);
    }

    return 0;
}

sub plain2midout_internal {
    my ($self, $test_file, $luwmodel, $muwmodel, $save_dir) = @_;

    my $tmp_dir = $self->{"comainu-temp"};
    my $basename = File::Basename::basename($test_file);
    my $mecab_file   = $tmp_dir . "/" . $basename . ".mecab";
    my $kc_file      = $tmp_dir . "/" . $basename . ".KC";
    my $kc_lout_file = $tmp_dir . "/" . $basename . ".KC.lout";
    my $kc_mout_file = $tmp_dir . "/" . $basename . ".KC.mout";
    my $mout_file   = $save_dir . "/" . $basename . ".mout";

    $self->plain2mecab_file($test_file, $mecab_file);
    $self->mecab2kc_file($mecab_file, $kc_file);
    $self->METHOD_kc2longout($kc_file, $luwmodel, $tmp_dir);
    $self->lout2kc4mid_file($kc_lout_file, $kc_file);
    $self->METHOD_kclong2midout($kc_file, $muwmodel, $tmp_dir);
    $self->merge_mecab_with_kc_mout_file($mecab_file, $kc_mout_file, $mout_file);

    unless ( $self->{debug} ) {
        do { unlink $_ if -f $_; } for ($mecab_file, $kc_lout_file, $kc_mout_file);
    }

    return 0;
}


# 平文からの中単位・文節解析
sub USAGE_plain2midbnstout {
    my $self = shift;
    printf("COMAINU-METHOD: plain2midbnstout\n");
    printf("  Usage: %s plain2midbnstout <test-text> <long-model-file> <mid-model-file> <bnst-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-text> with Mecab and <long-model-file>, <mid-model-file> and <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl plain2midbnstout sample/plain/sample.txt train/CRF/train.KC.model train/MST/train.KC.model train/bnst.model out\n");
    printf("    -> out/sample.txt.mbout\n");
    printf("\n");
}

sub METHOD_plain2midbnstout {
    my ($self, $test_file, $luwmodel, $muwmodel, $bnstmodel, $save_dir) = @_;

    $self->check_args(scalar @_ == 6);
    $self->check_luwmodel($luwmodel);
    $self->check_file($muwmodel);
    $self->check_file($bnstmodel);
    mkdir $save_dir unless -d $save_dir;

    if ( -f $test_file ) {
        $self->plain2midbnstout_internal($test_file, $luwmodel, $muwmodel, $bnstmodel, $save_dir);
    } elsif ( -d $test_file ) {
        opendir(my $dh, $test_file);
        while ( my $test_file2 = readdir($dh) ) {
            if ( $test_file2 =~ /.txt$/ ) {
                $self->plain2midbnstout_internal($test_file2, $luwmodel, $muwmodel, $bnstmodel, $save_dir);
            }
        }
        closedir($dh);
    }

    return 0;
}

sub plain2midbnstout_internal {
    my ($self, $test_file, $luwmodel, $muwmodel, $bnstmodel, $save_dir) = @_;

    my $tmp_dir = $self->{"comainu-temp"};
    my $basename = File::Basename::basename($test_file);
    my $mecab_file   = $tmp_dir . "/" . $basename . ".mecab";
    my $kc_file      = $tmp_dir . "/" . $basename . ".KC";
    my $kc_lout_file = $tmp_dir . "/" . $basename . ".KC.lout";
    my $kc_mout_file = $tmp_dir . "/" . $basename . ".KC.mout";
    my $kc_bout_file = $tmp_dir . "/" . $basename . ".KC.bout";
    my $mbout_file  = $save_dir . "/" . $basename . ".mbout";

    $self->{"bnst_process"} = "with_luw";

    $self->plain2mecab_file($test_file, $mecab_file);
    $self->mecab2kc_file($mecab_file, $kc_file);
    $self->METHOD_kc2longout($kc_file, $luwmodel, $tmp_dir);
    $self->METHOD_kc2bnstout($kc_file, $bnstmodel, $tmp_dir);
    $self->lout2kc4mid_file($kc_lout_file, $kc_file);
    $self->METHOD_kclong2midout($kc_file, $muwmodel, $tmp_dir);
    $self->merge_mecab_with_kc_mout_file($mecab_file, $kc_mout_file, $mbout_file);
    $self->merge_mecab_with_kc_bout_file($mbout_file, $kc_bout_file, $mbout_file);

    unless ( $self->{debug} ) {
        do { unlink $_ if -f $_; }
            for ($mecab_file, $kc_lout_file, $kc_mout_file, $kc_bout_file);
    }

    return 0;
}


############################################################
# 形態素解析
############################################################
sub plain2mecab_file {
    my ($self, $test_file, $mecab_file) = @_;

    my $mecab_dic_dir = $self->{"mecab-dic-dir"};
    my $mecab_dir = $self->{"mecab-dir"};
    my $mecabdic = $mecab_dic_dir . '/unidic';
    $mecabdic = $mecab_dic_dir."/unidic-mecab" unless -d $mecabdic;
    my $com = sprintf("\"%s/mecab\" -O%s -d\"%s\" -r\"%s\"",
                      $mecab_dir, $UNIDIC_MECAB_TYPE, $mecabdic, $self->{mecab_rcfile});
    $com =~ s/\//\\/g if $Config{osname} eq "MSWin32";

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

    $self->write_to_file($mecab_file, $out_buff);
    undef $out_buff;
}

# extcorput.plを利用して付加情報を付与
sub mecab2kc_file {
    my ($self, $mecab_file, $kc_file) = @_;
    my $mecab_ext_file = $mecab_file."_ext";
    my $ext_def_file = $self->{"comainu-temp"}."/mecab_ext.def";

    my $def_buff = "";
    $def_buff .= "dbfile:".$self->{"unidic-db"}."\n";
    $def_buff .= "table:lex\n";
    $def_buff .= "input:sLabel,orth,pron,lForm,lemma,pos,cType?,cForm?\n";
    $def_buff .= "output:sLabel,orth,pron,lForm,lemma,pos,cType?,cForm?,goshu,form,formBase,formOrthBase,formOrth\n";
    $def_buff .= "key:lForm,lemma,pos,cType,cForm,orth,pron\n";
    $self->write_to_file($ext_def_file, $def_buff);
    undef $def_buff;

    my $perl = $self->{perl};
    my $com = sprintf("\"%s\" \"%s/script/extcorpus.pl\" -C \"%s\"",
                      $perl, $self->{"comainu-home"}, $ext_def_file);
    $self->proc_file2file($com, $mecab_file, $mecab_ext_file);

    my $buff = $self->read_from_file($mecab_ext_file);
    $buff = $self->mecab2kc($buff);
    $self->write_to_file($kc_file, $buff);

    unlink $mecab_ext_file if !$self->{debug} && -f $mecab_ext_file;

    undef $buff;
}


############################################################
# 訓練対象KCファイルからモデルを訓練する。
############################################################
# 長単位解析モデルを学習する
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

    $self->check_args(scalar @_ == 3);

    $model_dir = File::Basename::dirname($train_kc) unless $model_dir;
    mkdir $model_dir unless -d $model_dir;

    my $tmp_train_kc = $self->{"comainu-temp"} . "/" .
        File::Basename::basename($train_kc);
    $self->format_inputdata($train_kc, $tmp_train_kc, "input-kc", "kc");

    $self->make_luw_traindata($tmp_train_kc, $model_dir);
    $self->add_luw_label($tmp_train_kc, $model_dir);

    if ( $self->{"luwmodel"} eq "SVM" ) {
        $self->train_luwmodel_svm($tmp_train_kc, $model_dir);
    } elsif ( $self->{"luwmodel"} eq "CRF" ) {
        $self->train_luwmodel_crf($tmp_train_kc, $model_dir);
    }
    if ( $self->{"luwmrph"} eq "with" ) {
        $self->train_bi_model($tmp_train_kc, $model_dir);
    }
    unlink($tmp_train_kc);

    return 0;
}

# 長単位解析モデル学習用データを作成
sub make_luw_traindata {
    my ($self, $tmp_train_kc, $model_dir) = @_;
    print STDERR "# MAKE TRAIN DATA\n";

    my $basename = File::Basename::basename($tmp_train_kc);
    my $buff = $self->read_from_file($tmp_train_kc);
    $buff =~ s/^EOS.*?\n|^\*B.*?\n//mg;
    $buff = $self->delete_column_long($buff);
    # $buff = $self->add_column($buff);

    ## 辞書の作成
    my $comainu_dic = Comainu::Dictionary->new;
    $comainu_dic->create($tmp_train_kc, $model_dir, $basename);
    ## 素性の追加
    my $AF = AddFeature->new;
    $buff = $AF->add_feature($buff, $basename, $model_dir);

    $self->write_to_file($model_dir . "/" . $basename . ".KC2", $buff);
    undef $buff;

    print STDERR "Make " . $model_dir . "/" . $basename . ".KC2\n";

    return 0;
}

# 長単位学習用のラベルを付与
# BIのみから構成されるデータを作成
sub add_luw_label {
    my ($self, $tmp_train_kc, $model_dir) = @_;
    print STDERR "# ADD LUW LABEL\n";

    if ( -s $model_dir . "/" . $tmp_train_kc . ".svmin" ) {
        print "Use Cache '$3/$1.svmin'.\n";
        return 0;
    }

    my $basename = File::Basename::basename($tmp_train_kc);
    my $kc2_file = $model_dir . "/" . $basename . ".KC2";
    my $output_file = $model_dir . "/" . $basename .".svmin";

    open(my $fh_ref, "<", $tmp_train_kc) or die "Cannot open '$tmp_train_kc'";
    open(my $fh_in, "<", $kc2_file)      or die "Cannot open '$kc2_file'";
    open(my $fh_out, ">", $output_file)  or die "Cannot open '$output_file'";
    binmode($fh_out);
    $self->add_pivot_to_kc2($fh_ref, $fh_in, $fh_out);
    close($fh_out);
    close($fh_in);
    close($fh_ref);

    ## 後処理用学習データの作成
    {
        open(my $fh_ref, "<", $tmp_train_kc)  or die "Cannot open '$tmp_train_kc'";
        open(my $fh_svmin, "<", $output_file) or die "Cannot open'$output_file'";
        my $BIP = BIProcessor->new;
        $BIP->extract_from_train($fh_ref, $fh_svmin, $model_dir, $basename);
        close($fh_ref);
        close($fh_svmin);
    }

    unlink $output_file unless -s $output_file;

    return 0;
}

sub train_luwmodel_svm {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# TRAIN LUWMODEL\n";

    my $basename = File::Basename::basename($train_kc);
    my $svmin = $model_dir . "/" . $basename . ".svmin";

    my $makefile = $self->create_yamcha_makefile($model_dir, $basename);
    my $perl = $self->{perl};
    my $com = sprintf("make -f \"%s\" PERL=\"%s\" CORPUS=\"%s\" MODEL=\"%s\" train",
                      $makefile, $perl, $svmin, $model_dir . "/" . $basename);
    printf(STDERR "# COM: %s\n", $com);
    system($com);

    return 0;
}

sub train_luwmodel_crf {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# TRAIN LUWMODEL\n";

    my $basename = File::Basename::basename($train_kc);

    $ENV{"LD_LIBRARY_PATH"} = "/usr/lib;/usr/local/lib";

    my $crf_learn = $self->{"crf-dir"} . "/crf_learn";
    my $crf_template = $model_dir . "/" . $basename . ".template";

    my $svmin = $model_dir . "/" . $basename . ".svmin";
    ## 素性数を取得
    open(my $fh_svmin, $svmin);
    my $line = <$fh_svmin>;
    $line = Encode::decode("utf-8", $line);
    my $feature_num = scalar(split(/ /,$line))-2;
    close($fh_svmin);

    $self->create_template($crf_template, $feature_num);

    my $crf_model = $model_dir . "/" . $basename .".model";
    my $com = "\"$crf_learn\" \"$crf_template\" \"$svmin\" \"$crf_model\"";
    printf(STDERR "# COM: %s\n", $com);
    system($com);

    return 0;
}

## BIのみに関する処理（後処理用）
sub train_bi_model {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# TRAIN BI MODEL\n";

    my $basename = File::Basename::basename($train_kc);
    my $makefile = $self->create_yamcha_makefile($model_dir, $basename);
    my $perl = $self->{perl};

    my $pos_dat = $model_dir . "/pos/" . $basename . ".BI_pos.dat";
    my $pos_model = $model_dir . "/pos/" . $basename . ".BI_pos";
    my $BI_com1 = sprintf("make -f \"%s\" PERL=\"%s\" MULTI_CLASS=2 FEATURE=\"F:0:0.. \" CORPUS=\"%s\" MODEL=\"%s\" train",
                          $makefile, $perl, $pos_dat, $pos_model);
    system($BI_com1);

    my $cType_dat = $model_dir . "/cType/" . $basename . ".BI_cType.dat";
    my $cType_model = $model_dir . "/cType/" . $basename . ".BI_cType";
    my $BI_com2 = sprintf("make -f \"%s\" PERL=\"%s\" MULTI_CLASS=2 FEATURE=\"F:0:0.. \" CORPUS=\"%s\" MODEL=\"%s\" train",
                          $makefile, $perl, $cType_dat, $cType_model);
    system($BI_com2);

    my $cForm_dat = $model_dir . "/cForm/" . $basename . ".BI_cForm.dat";
    my $cForm_model = $model_dir . "/cForm/" . $basename . ".BI_cForm";
    my $BI_com3 = sprintf("make -f \"%s\" PERL=\"%s\" MULTI_CLASS=2 FEATURE=\"F:0:0.. \" CORPUS=\"%s\" MODEL=\"%s\" train",
                          $makefile, $perl, $cForm_dat, $cForm_model);
    system($BI_com3);

    return 0;
}

# 文節境界解析モデルの学習
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

    $self->check_args(scalar @_ == 3);
    $model_dir = File::Basename::dirname($train_kc) unless $model_dir;
    mkdir $model_dir unless -d $model_dir;

    $self->train_bnstmodel($train_kc, $model_dir);

    return 0;
}

sub train_bnstmodel {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# TRAIN BNST MODEL\n";

    my $basename = File::Basename::basename($train_kc);
    my $svmin = $model_dir . "/" . $basename . ".svmin";
    my $svmin_buff = $self->read_from_file($train_kc);
    $svmin_buff = $self->trans_dataformat($svmin_buff, "input-kc", "kc");
    $svmin_buff = $self->kc2bnstsvmdata($svmin_buff, 1);
    $svmin_buff = $self->add_bnst_label($svmin_buff);
    $svmin_buff =~ s/^EOS.*?\n//mg;
    $svmin_buff .= "\n";
    $self->write_to_file($svmin, $svmin_buff);
    undef $svmin_buff;

    my $makefile = $self->create_yamcha_makefile($model_dir, $basename);
    my $perl = $self->{perl};
    my $com = sprintf("make -f \"%s\" PERL=\"%s\" CORPUS=\"%s\" MODEL=\"%s\" train",
                      $makefile, $perl, $svmin, $model_dir . "/" . $basename);

    printf(STDERR "# COM: %s\n", $com);
    system($com);

    return 0;
}

# 文節境界ラベルを付与
sub add_bnst_label {
    my ($self, $data) = @_;
    my $res = "";
    my ($prev, $curr, $next) = (0, 1, 2);
    my $buff_list = [undef, undef];
    $data .= "*B\n";
    foreach my $line ( (split(/\r?\n/, $data), undef, undef) ) {
        push(@$buff_list, $line);
        if ( defined $buff_list->[$curr] && $buff_list->[$curr] !~ /^EOS|^\*B/ ) {
            my $mark = $buff_list->[$prev] =~ /^\*B/ ? "B" : "I";
            $buff_list->[$curr] .= " ".$mark;
        }
        my $new_line = shift @$buff_list;
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line . "\n";
        }
    }
    undef $data;

    while ( my $new_line = shift(@$buff_list) ) {
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line . "\n";
        }
    }
    undef $buff_list;

    return $res;
}


# 中単位解析モデルの学習
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

    $self->check_args(scalar @_ == 3);
    $model_dir = File::Basename::dirname($train_kc) unless $model_dir;
    mkdir $model_dir unless -d $model_dir;

    $self->create_mid_traindata($train_kc, $model_dir);
    $self->train_midmodel($train_kc, $model_dir);

    return 0;
}

## 中単位解析モデル学習用データの作成
sub create_mid_traindata {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# CREATE MUW TRAINDATA\n";

    my $basename = File::Basename::basename($train_kc);
    my $buff = $self->read_from_file($train_kc);
    $buff = $self->trans_dataformat($buff, "input-kc", "kc_mid");
    $buff = $self->kc2mstin($buff);

    $self->write_to_file($model_dir . "/" . $basename . ".mstin", $buff);
    undef $buff;

    return 0;
}

## 中単位解析モデルの学習
sub train_midmodel {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# TRAIN MUW MODEL\n";

    my $java = $self->{java};
    my $mstparser_dir = $self->{"mstparser-dir"};

    my $basename   = File::Basename::basename($train_kc);
    my $inputFile  = $model_dir . "/" . $basename . ".mstin";
    my $outputFile = $model_dir . "/" . $basename . ".model";

    my $mst_classpath = $mstparser_dir . "/output/classes:"
        . $mstparser_dir . "/lib/trove.jar";
    my $memory = "-Xmx1800m";
    if ( $Config{osname} eq "MSWin32" ) {
        $mst_classpath = $mstparser_dir . "/output/classes;"
            . $mstparser_dir . "/lib/trove.jar";
        $memory = "-Xmx1000m";
        # remove drive letter for MS-Windows
        $inputFile =~ s/^[a-zA-Z]\://;
        $outputFile =~ s/^[a-zA-Z]\://;
    }
    my $cmd = sprintf("\"%s\" -classpath \"%s\" %s mstparser.DependencyParser train train-file:\"%s\" model-name:\"%s\" order:1",
                      $java, $mst_classpath, $memory, $inputFile, $outputFile);
    print STDERR $cmd,"\n";
    system($cmd);

    return 0;
}


############################################################
# 解析モデルの評価
############################################################
# 正解の情報が付与されたKCファイルと、長単位解析結果のKCファイルを比較し、
# diff結果と精度を出力する。
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

    $self->check_args(scalar @_ == 4);
    mkdir $save_dir unless -d $save_dir;

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
    $self->compare($correct_kc, $result_kc_lout, $save_dir);
}

# 正解KCファイルと長単位解析結果KCファイルを受け取り、
# 処理して".eval.long"ファイルを出力する。
sub compare {
    my ($self, $kc_file, $lout_file, $save_dir) = @_;
    print STDERR "_compare\n";
    my $res = "";

    # 中間ファイル
    my $tmp1_file = $self->{"comainu-temp"} . "/" .
        File::Basename::basename($kc_file, ".KC").".long";

    # すでに中間ファイルが出来ていれば処理しない
    if ( -s $tmp1_file ) {
        print STDERR "Use Cache \'$tmp1_file\'.\n";
    } else {
        unless ( -f $kc_file ) {
            print STDERR "ERROR: \'$1\' not Found.\n";
            return $res;
        }
        my $buff = $self->read_from_file($kc_file);
        $buff = $self->trans_dataformat($buff, "input-kc", "kc");
        $buff = $self->short2long($buff);
        $self->write_to_file($tmp1_file, $buff);
        undef $buff;
    }

    unless ( -f $lout_file ) {
        print STDERR "ERROR: \'$2\' not Found.\n";
        return $res;
    }

    # 中間ファイル
    my $tmp2_file = $self->{"comainu-temp"} . "/" .
        File::Basename::basename($lout_file, ".lout") . ".svmout_create.long";
    my $buff = $self->read_from_file($lout_file);
    $buff = $self->short2long($buff);
    $self->write_to_file($tmp2_file, $buff);
    undef $buff;

    my $output_file = $save_dir . "/" .
        File::Basename::basename($lout_file, ".lout").".eval.long";

    $res = $self->eval_long($tmp1_file, $tmp2_file);
    $self->write_to_file($output_file, $res);
    print $res;

    return $res;
}


# 文節境界モデルの評価
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
    my ($self, $correct_kc, $result_kc_bout, $save_dir) = @_;

    $self->check_args(scalar @_ == 4);
    mkdir $save_dir unless -d $save_dir;

    if ( -f $result_kc_bout ) {
        $self->kc2bnsteval_internal($correct_kc, $result_kc_bout, $save_dir);
    } elsif ( -d $result_kc_bout ) {
        opendir(my $dh, $result_kc_bout);
        while ( my $result_kc_lout_file = readdir($dh) ) {
            if ( $result_kc_lout_file =~ /.KC$/ ) {
                $self->kc2bnsteval_internal($correct_kc, $result_kc_lout_file, $save_dir);
            }
        }
        closedir($dh);
    } else {
        printf(STDERR "# Error: Not found result_kc_bout '%s'\n", $result_kc_bout);
    }

    return 0;
}

sub kc2bnsteval_internal {
    my ($self, $correct_kc, $result_kc_bout, $save_dir) = @_;
    $self->compare_bnst($correct_kc, $result_kc_bout, $save_dir);
}

sub compare_bnst {
    my ($self, $kc_file, $bout_file, $save_dir) = @_;
    print STDERR "_compare\n";
    my $res = "";

    # 中間ファイル
    my $tmp1_file = $self->{"comainu-temp"} . "/" .
        File::Basename::basename($kc_file, ".KC") . ".bnst";

    if ( -s $tmp1_file ) {
        print STDERR "Use Cache \'$tmp1_file\'.\n";
    } else {
        unless ( -f $kc_file ) {
            print STDERR "ERROR: \'$1\' not Found.\n";
            return $res;
        }
        my $buff = $self->read_from_file($kc_file);
        $buff = $self->short2bnst($buff);
        $self->write_to_file($tmp1_file, $buff);
        undef $buff;
    }

    unless ( -f $bout_file ) {
        print STDERR "ERROR: \'$2\' not Found.\n";
        return $res;
    }

    # 中間ファイル
    my $tmp2_file = $self->{"comainu-temp"} . "/" .
        File::Basename::basename($bout_file, ".bout") . ".svmout_create.bnst";
    my $buff = $self->read_from_file($bout_file);
    $buff = $self->short2bnst($buff);
    $self->write_to_file($tmp2_file, $buff);
    undef $buff;

    my $output_file = $save_dir . "/" .
        File::Basename::basename($bout_file, ".bout") . ".eval.bnst";

    $res = $self->eval_long($tmp1_file, $tmp2_file, 1);
    $self->write_to_file($output_file, $res);
    print $res;

    return $res;
}


# 中単位解析モデルの評価
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

    $self->check_args(scalar @_ == 4);
    mkdir $save_dir unless -d $save_dir;

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
    $self->compare_mid($correct_kc, $result_kc_mout, $save_dir);
}

sub compare_mid {
    my ($self, $kc_file, $mout_file, $save_dir) = @_;
    print STDERR "_compare\n";
    my $res = "";

    # 中間ファイル
    my $tmp1_file = $self->{"comainu-temp"} . "/" .
        File::Basename::basename($kc_file, ".KC") . ".mid";

    if ( -s $tmp1_file ) {
        print STDERR "Use Cache \'$tmp1_file\'.\n";
    } else {
        unless ( -f $kc_file ) {
            print STDERR "ERROR: \'$1\' not Found.\n";
            return $res;
        }
        my $buff = $self->read_from_file($kc_file);
        $buff = $self->short2middle($buff);
        $self->write_to_file($tmp1_file, $buff);
        undef $buff;
    }

    unless ( -f $mout_file ) {
        print STDERR "ERROR: \'$2\' not Found.\n";
        return $res;
    }

    my $tmp2_file = $self->{"comainu-temp"} . "/" .
        File::Basename::basename($mout_file, ".mout") . ".svmout_create.mid";
    my $buff = $self->read_from_file($mout_file);
    $buff = $self->short2middle($buff);
    $self->write_to_file($tmp2_file, $buff);
    undef $buff;

    my $output_file = $save_dir . "/" .
        File::Basename::basename($mout_file, ".mout").".eval.mid";

    $res = $self->eval_long($tmp1_file, $tmp2_file, 1);
    $self->write_to_file($output_file, $res);
    print $res;

    return $res;
}

# *.KC と *.out (システムの出力)を比較し、精度を求める
# segmentaion と POS information (発音を除くすべて)
sub eval_long {
    my ($self, $gldf, $sysf, $is_middle) = @_;
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
        if ( $is_middle ) {
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
        if ( $is_middle ) {
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


########################################
# 語彙素・語彙素読みを生成
sub create_long_lemma {
    my ($self, $data, $comp_file) = @_;

    my $comp_data = $self->read_from_file($comp_file);
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

# 中単位解析用の素性を生成
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
            if ( scalar @features > 0 ) {
                $res .= join("|",@features);
            } else {
                $res .= "_";
            }
            $res .= "\t".$items[19]."\t".$depend."\t_\n";
        }
        $res .= "\n";
    }

    return $res;
}

# 中単位境界を判定
sub create_middle {
    my ($self, $kc_long, $out_long, $ref_mid, $pos) = @_;
    my $res = "";

    my %sp_prefix = ("各"=>1, "計"=>1, "現"=>1, "全"=>1, "非"=>1, "約"=>1);

    if ( scalar(@$kc_long) < 1 ) {
        return "";
    } elsif ( scalar(@$kc_long) == 1 ) {
        my @items = split(/[ \t]/, $$kc_long[0]);
        $$ref_mid++;
        $res .= join(" ",@{$$kc_long[0]}[0..18])." * ".$$ref_mid." ".join(" ",@{$$kc_long[0]}[0..0])."\n";
    } elsif ( ${$$kc_long[0]}[13] =~ /^形状詞/ ) {
        $$ref_mid++;
        my @out = map {
            [ split /\t/ ]
        } split(/\r?\n/, shift @$out_long);

        my @mid_text;
        for my $i ( 0 .. $#{$kc_long} ) {
            $mid_text[0] .= ${$$kc_long[$i]}[0];
        }

        $res .= join(" ",@{$$kc_long[0]}[0..18])." ".($pos+${$out[0]}[6]-1)." ".$$ref_mid." ".join(" ",@mid_text)."\n";
        for my $i ( 1 .. $#{$kc_long}-1 ) {
            $res .= join(" ",@{$$kc_long[$i]}[0..18])." ".($pos+${$out[$i]}[6]-1)." ".$$ref_mid."\n";
        }
        $res .= join(" ",@{$$kc_long[$#{$kc_long}]}[0..18])." * ".$$ref_mid."\n";
    } else {
        my @out = map {
            [ split /\t/ ]
        } split(/\r?\n/, shift @$out_long);

        my $mid_pos = 0;
        for my $i ( 0 .. $#out ) {
            my $long = $$kc_long[$i];
            @$long[21..25] = ("","","","","");
            ${$$kc_long[$mid_pos]}[21] .= $$long[0];

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
            } elsif ( $i < $#out-1 && ${$out[$i+1]}[0] != ${$out[$i]}[6] ) {
                if ( ${$out[$i+2]}[0] == ${$out[$i]}[6] &&
                         ( (${$out[$i+2]}[3] eq "名詞" && ${$out[$i+1]}[3] eq "接頭辞") ||
                               (${$out[$i+2]}[3] eq "接尾辞" && ${$out[$i+1]}[3] eq "名詞")) ) {
                    #$mid_pos = $i+1;
                } else {
                    $mid_pos = $i+1;
                }
            }
            $$long[19] = $pos+${$out[$i]}[6]-1;
        }
        for my $i ( 0 .. scalar(@$kc_long)-1 ) {
            my $long = $$kc_long[$i];
            if ( $$long[21] ne "" ) {
                $$ref_mid++;
                $res .= join(" ",@$long[0..19])." ".$$ref_mid." ".$$long[21];
            } else {
                $res .= join(" ",@$long[0..19])." ".$$ref_mid;
            }
            $res .= "\n";
        }
    }

    return $res;
}


############################################################
# 形式の変換
############################################################
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
        my $long_pos  = join(" ", @$items[13 .. 15]);

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
        }
        my $res = $front ? "$pivot $line_out\n" : "$line_out $pivot\n";
        $res = Encode::encode("utf-8", $res);
        print $fh_out $res;
    }
    print $fh_out "\n";

    undef $line_in_list;
}

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
        if ( scalar(@$items) > 2 ) {
            $items = [@$items[0 .. 5, 10 .. 12]];
        }
        $res .= join(" ", @$items)."\n";
    }
    undef $data;

    return $res;
}

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
        $items = [ @$items[scalar(@$items) - 1, 0 .. scalar(@$items) - 2 ]];
        $res .= join(" ", @$items)."\n";
    }
    undef $data;
    return $res;
}

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


############################################################
# partial chunking
############################################################
# 前処理（partial chunkingの入力フォーマットへの変換）
sub pp_partial {
    my ($self, $data, $args) = @_;
    my $res = "";
    my ($prev, $curr, $next) = (0, 1, 2);
    my $buff_list = [undef, undef];

    my $B_label  = $args->{is_bnst} ? "B" : "B Ba";
    my $BI_label = $args->{is_bnst} ? "B I" :
        $self->{boundary} ne "word" ? "B Ba I Ia" : "I Ia";

    foreach my $line ((split(/\r?\n/, $data), undef, undef)) {
        push @$buff_list, $line;
        if ( defined $buff_list->[$curr] && $buff_list->[$curr] !~ /^EOS|^\*B/ ) {
            my $mark = "";
            if ( $buff_list->[$prev] =~ /^EOS|^\*B/) {
                $mark = $B_label;
            } elsif ( !defined $buff_list->[$prev] ) {
                $mark = $B_label;
            } else {
                $mark = $BI_label;
            }
            $buff_list->[$curr] .= " " . $mark;
        }
        my $new_line = shift @$buff_list;
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
        push @$buff_list, $line;
        if ( defined $buff_list->[$curr] && $buff_list->[$curr] !~ /^EOS|^\*B/ ) {
            my $mark = "";
            my $lw = shift @$svmout_item_list;
            my @svmout = split(/[ \t]/,$lw);
            if ( $buff_list->[$prev] =~ /^EOS|^\*B/) {
                $mark = "B";
            } elsif ( !defined $buff_list->[$prev] ) {
                $mark = "B";
            } elsif ( $svmout[0] =~ /I/ ) {
                $mark = "I";
            } elsif ( $svmout[4] =~ /^動詞/ ) {
                $mark = "B";
            } elsif ( $svmout[4] =~ /^名詞|^形容詞|^副詞|^形状詞/ &&
                          ($svmout[21] == 1 || $svmout[22] == 1) ) {
                $mark = "B";
            } else {
                $mark = "B I";
            }
            $buff_list->[$curr] .= " ".$mark;
        }
        my $new_line = shift @$buff_list;
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line . "\n";
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


############################################################
# フォーマットの変換
############################################################
# BCCWJの形式をComainu長単位解析の入力形式に変換
sub bccwj2kc_file {
    my ($self, $bccwj_file, $kc_file) = @_;
    my $buff = $self->read_from_file($bccwj_file);
    $buff = $self->bccwj2kc($buff, "");
    $self->write_to_file($kc_file, $buff);
    undef $buff;
}

sub bccwjlong2kc_file {
    my ($self, $bccwj_file, $kc_file) = @_;
    my $buff = $self->read_from_file($bccwj_file);
    $buff = $self->bccwj2kc($buff, "with_luw");
    $self->write_to_file($kc_file, $buff);
    undef $buff;
}

# BCCWJの形式をComainu長単位解析の入力形式に変換
sub bccwj2kc {
    my ($self, $data, $type) = @_;
    # my $cn = 17;
    my $cn = 27;
    if ( $self->{boundary} eq "word" || $type eq "with_luw" ) {
        # $cn = 24;
        # $cn = 25;
        $cn = 34;
    }
    my $res = "";
    foreach ( split(/\r?\n/, $data) ) {
        # chomp;
        my @suw = split(/\t/);
        $res .= "EOS\n" if $res ne "" && $suw[3] =~ /^B/;

        if( ($self->{boundary} eq "word" || $type eq "with_luw") && $suw[27] =~ /B/ ) {
            $res .= "*B\n";
        }
        $suw[6] = $suw[5] if $suw[6] eq "" || $suw[6] =~ /NULL/;
        $suw[7] = $suw[5] if $suw[7] eq "" || $suw[7] =~ /NULL/;

        for my $i ( 0 .. $cn ) {
            $suw[$i] = "*" if $suw[$i] eq "" || $suw[$i] =~ /NULL/;
        }

        $res .= "$suw[4] $suw[5] $suw[6] $suw[8] $suw[9] $suw[10] ";
        $res .= "$suw[16] $suw[17] $suw[18] $suw[19] $suw[22] $suw[23] $suw[21] ";

        if ( $type eq "with_luw" && $suw[27] =~ /B/ ) {
            $res .= "$suw[31] $suw[32] $suw[33] $suw[29] $suw[30] $suw[28]\n";
        } else {
            $res .= "* * * * * *\n";
        }
    }

    undef $data;

    return $res;
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
            $res .= $line."\n" if $is_train;
        } else {
            my @items = split(/[ \t]/, $line);
            my @pos   = split(/\-/, $items[3]."-*-*-*");
            my @cType = split(/\-/, $items[4]."-*-*");
            my @cForm = split(/\-/, $items[5]."-*-*");
            $res .= join(" ",@items[0..5]);
            $res .= " ".join(" ",@pos[0..3])." ".join(" ",@cType[0..2])." ".join(" ",@cForm[0..2]);
            if ( $items[3] eq "補助記号-括弧開" ) {
                $res .= $parenthetic ? " I" : " B";
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
        }
        push @$short_terms, $line;
        $pos++;
    }

    undef $data;
    undef $short_terms;

    return $res;
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

# 入力用のフォーマットに変換
sub format_inputdata {
    my ($self, $test_kc, $tmp_test_kc, $input_type, $output_type) = @_;

    my $buff = $self->read_from_file($test_kc);
    $buff = $self->trans_dataformat($buff, $input_type, $output_type);
    $self->write_to_file($tmp_test_kc, $buff);
    undef $buff;
}

# 入力形式を内部形式に変換
sub trans_dataformat {
    my ($self, $input_data, $in_type, $out_type) = @_;

    my $data_format_conf = $self->{data_format};
    $self->check_file($data_format_conf);

    my $data = $self->read_from_file($data_format_conf);
    my %formats;
    foreach my $line (split(/\r?\n/, $data)) {
        my ($type, $format) = split(/\t/,$line);
        $formats{$type} = $format;
    }
    $formats{kc} = "orthToken,reading,lemma,pos,cType,cForm,form,formBase,formOrthBase,formOrth,charEncloserOpen,charEncloserClose,wType,l_pos,l_cType,l_cForm,l_reading,l_lemma,l_orthToken";
    $formats{bccwj} = "file,start,end,BOS,orthToken,reading,lemma,meaning,pos,cType,cForm,usage,pronToken,pronBase,kana,kanaBase,form,formBase,formOrthBase,formOrth,orthBase,wType,charEncloserOpen,charEncloserClose,originalText,order,BOB,LUW,l_orthToken,l_reading,l_lemma,l_pos,l_cType,l_cForm";
    $formats{kc_mid} = "orthToken,reading,lemma,pos,cType,cForm,form,formBase,formOrthBase,formOrth,charEncloserOpen,charEncloserClose,wType,l_pos,l_cType,l_cForm,l_reading,l_lemma,l_orthToken,depend,MID,m_orthToken";

    my %in_format = ();
    my @items = split(/,/,$formats{$in_type});
    for my $i ( 0 .. $#items ) {
        $in_format{$items[$i]} = $i;
    }

    return $input_data if($formats{$in_type} eq $formats{$out_type});

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
        my @items = $in_type =~ /bccwj/ ? split(/\t/, $line) : split(/ /, $line);

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


############################################################
# ファイルのマージ
############################################################
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

# bccwj形式のファイルに長単位解析結果をマージ
sub merge_iof {
    my ($self, $bccwj_data, $lout_data) = @_;
    my $res = "";
    my $cn1 = 16;
    # my $cn1 = 26;
    if ( $self->{"boundary"} eq "word" ) {
        # $cn1 = 23;
        $cn1 = 27;
        # $cn1 = 34;
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
        $lw = shift(@m) if($lw =~ /^EOS|^\*B/);
        my @ml = split(/[ \t]/, $lw);
        if ($#ml+1 < $cn2) {
            print STDERR "Some columns are missing in bccwj_data!\n";
            print STDERR "  ml(".($#ml+1).") < cn2(".$cn2.")\n";
            print STDERR "$ml[1]\n";
        }
        if ($morph[4] ne $ml[1]) {
            print STDERR "Two files cannot be marged!: '$morph[4]' ; '$ml[1]'\n";
        }
        if ($ml[0] =~ /^B/) {
            $long_pos = $ml[14];
        }
        if ( $self->{boundary} eq "word" ) {
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

sub merge_bccwj_with_kc_bout_file {
    my ($self, $bccwj_file, $kc_bout_file, $bout_file) = @_;
    my $bccwj_data = $self->read_from_file($bccwj_file);
    my $kc_bout_data = $self->read_from_file($kc_bout_file);
    my @m = split(/\r?\n/, $kc_bout_data);
    undef $kc_bout_data;

    my $bout_data = "";
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

sub merge_bccwj_with_kc_mout_file {
    my ($self, $bccwj_file, $kc_mout_file, $mout_file) = @_;
    my $bccwj_data = $self->read_from_file($bccwj_file);
    my $kc_mout_data = $self->read_from_file($kc_mout_file);
    my @m = split(/\r?\n/, $kc_mout_data);
    undef $kc_mout_data;

    my $mout_data = "";
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

sub merge_mecab_with_kc_lout_file {
    my ($self, $mecab_file, $kc_lout_file, $lout_file) = @_;
    my $mecab_data = $self->read_from_file($mecab_file);
    my $kc_lout_data = $self->read_from_file($kc_lout_file);
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
        push(@$mecab_item_list, splice(@$kc_lout_item_list, 14, 6));
        $lout_data .= sprintf("%s\n", join("\t", @$mecab_item_list));
    }
    undef $mecab_data;
    undef $kc_lout_data_list;

    $self->write_to_file($lout_file, $lout_data);
    undef $lout_data;
}

sub merge_mecab_with_kc_bout_file {
    my ($self, $mecab_file, $kc_bout_file, $bout_file) = @_;
    my $mecab_data = $self->read_from_file($mecab_file);
    my $kc_bout_data = $self->read_from_file($kc_bout_file);
    my $kc_bout_data_list = [split(/\r?\n/, $kc_bout_data)];
    undef $kc_bout_data;

    my $bout_data = "";
    foreach my $mecab_line ( split(/\r?\n/, $mecab_data) ) {
        my $kc_bout_line = shift @$kc_bout_data_list;
        $bout_data .= "*B\n" if $kc_bout_line =~ /B/;
        $bout_data .= $mecab_line."\n" if $mecab_line !~ /^\*B/;
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
    my $kc_mout_data_list = [split(/\r?\n/, $kc_mout_data)];
    undef $kc_mout_data;

    my $mout_data = "";
    foreach my $mecab_line ( split(/\r?\n/, $mecab_data) ) {
        if ( $mecab_line =~ /^EOS|^\*B/ ) {
            $mout_data .= $mecab_line."\n";
            next;
        }
        my $mecab_item_list = [ split(/\t/, $mecab_line, -1) ];
        my $kc_mout_line = shift @$kc_mout_data_list;
        $kc_mout_line = shift @$kc_mout_data_list if $kc_mout_line =~ /^EOS/;
        my $kc_mout_item_list = [ split(/[ \t]/, $kc_mout_line) ];
        push(@$mecab_item_list, splice(@$kc_mout_item_list, 14, 9));
        $mout_data .= sprintf("%s\n", join("\t", @$mecab_item_list));
    }
    undef $mecab_data;
    undef $kc_mout_data_list;

    $self->write_to_file($mout_file, $mout_data);
    undef $mout_data;
}

sub merge_kc_with_mstout {
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

sub merge_kc_with_svmout {
    my ($self, $kc_file, $svmout_file) = @_;

    my $res = "";
    my @long;
    my $kc_data = $self->read_from_file($kc_file);
    my $svmout_data = $self->read_from_file($svmout_file);
    my $svmout_data_list = [split(/\r?\n/, $svmout_data)];
    undef $svmout_data;

    foreach my $kc_data_line ( split(/\r?\n/, $kc_data) ) {
    	if ( $kc_data_line =~ /^EOS/ && $self->{luwmrph} eq "without" ) {
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


############################################################
# Tool関連
############################################################
# CRF++用のテンプレート作成
sub create_template {
    my ($self, $template_file, $feature_num) = @_;

    my $buff = "";
    my $index = 1;

    for my $i (0, 2 .. $feature_num) {
        for my $j (-2..2) { $buff .= "U".$index++.":%x[$j,$i]\n"; }
        for my $k (-2..1) { $buff .= "U".$index++.":%x[$k,$i]/%x[".($k+1).",$i]\n"; }
        for my $l (-2..0) { $buff .= "U".$index++.":%x[$l,$i]/%x[".($l+1).",$i]/%x[".($l+2).",$i]\n"; }
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
    $buff .= "\n";
    $self->write_to_file($template_file, $buff);
    undef $buff;
}


sub check_luwmodel {
   my ($self, $luwmodel) = @_;

   if ( $self->{luwmodel} eq "SVM" || $self->{luwmodel} eq "CRF" ) {
       unless ( -f $luwmodel ) {
           printf(STDERR "ERROR: '%s' not found or not a file.\n",
                  $luwmodel);
           die;
       }
   } else {
       printf(STDERR "ERROR: '%s' not found model name.\n",
              $self->{luwmodel});
       die;
   }
}

# yamchaのMakefileを作成
sub create_yamcha_makefile {
    my ($self, $model_dir, $basename) = @_;

    my $yamcha = $self->{"yamcha-dir"} . "/yamcha";
    my $yamcha_tool_dir = $self->get_yamcha_tool_dir;
    my $svm_tool_dir = $self->{"svm-tool-dir"};
    my $svm_learn = $svm_tool_dir . "/svm_learn";

    my $comainu_etc_dir = $self->{"comainu-home"} . "/etc";
    my $conf_file = $comainu_etc_dir . "/yamcha_training.conf";

    printf(STDERR "# use yamcha_training_conf_file=\"%s\"\n", $conf_file);
    my $conf = $self->load_yamcha_training_conf($conf_file);
    my $makefile_template = $yamcha_tool_dir . "/Makefile";
    my $check = $self->check_yamcha_training_makefile_template($makefile_template);

    if ( $check == 0 ) {
        $makefile_template = $comainu_etc_dir . "/yamcha_training.mk";
    }
    printf(STDERR "# use yamcha_training_makefile_template=\"%s\"\n",
           $makefile_template);
    my $makefile = $model_dir . "/" . $basename . ".Makefile";

    my $buff = $self->read_from_file($makefile_template);

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
    if ( $conf->{SVM_PARAM} ne "" ) {
        $buff =~ s/^(SVM_PARAM.*)$/\# $1\nSVM_PARAM  = $conf->{"SVM_PARAM"}/mg;
        printf(STDERR "# changed SVM_PARAM : %s\n", $conf->{"SVM_PARAM"});
    }
    if ( $conf->{FEATURE} ne "" ) {
        $buff =~ s/^(FEATURE.*)$/\# $1\nFEATURE    = $conf->{"FEATURE"}/mg;
        printf(STDERR "# changed FEATURE : %s\n", $conf->{"FEATURE"});
    }
    if ( $conf->{DIRECTION} ne "" ) {
        $buff =~ s/^(DIRECTION.*)$/\# $1\nDIRECTION  = $conf->{"DIRECTION"}/mg;
        printf(STDERR "# changed DIRECTION : %s\n", $conf->{"DIRECTION"});
    }
    if ( $self->{method} ne 'kc2bnstmodel' && $conf->{"MULTI_CLASS"} ne "" ) {
        $buff =~ s/^(MULTI_CLASS.*)$/\# $1\nMULTI_CLASS = $conf->{"MULTI_CLASS"}/mg;
        printf(STDERR "# changed MULTI_CLASS : %s\n", $conf->{"MULTI_CLASS"});
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

    $self->write_to_file($makefile, $buff);
    undef $buff;

    return $makefile;
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

sub load_yamcha_training_conf {
    my ($self, $file) = @_;
    my $conf = {};
    open(my $fh, $file) or die "Cannot open '$file'";
    while ( my $line = <$fh> ) {
        $line =~ s/\r?\n$//;
        next if $line =~ /^\#|^\s*$/;

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
    undef $buff;
    return 1;
}

############################################################
# 使ってない関数
############################################################
# 文節情報に基づいたカラムを追加して出力する
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

# 後処理（「動詞」となる長単位の活用型、活用形）
# アドホックな後処理-->書き換え規則を変更する方針
sub pp_ctype {
    my ($self, $data) = @_;
    my $res = "";
    my @lw;
    foreach ( split(/\r?\n/, $data) ) {
        if (/^B/) {
            if ($#lw > -1) {
                my @last = split(/[ \t]/, $lw[$#lw]);
                if ($last[8] ne "*") {
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
        my @last = split(/[ \t]/, $lw[$#lw]); # fixed by jkawai
        if ($last[8] ne "*") {
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


############################################################
# Utilities
############################################################
sub check_args {
    my ($self, $args_ok) = @_;

    unless ( $args_ok ) {
        printf(STDERR "Error: invalid arg\n");
        my $method = "USAGE_" . $self->{method};
        $self->$method;
        exit 0;
    }
}

sub check_file {
    my ($self, $file) = @_;
    unless ( -f $file ) {
        printf(STDERR "Error: '%s' not Found.\n", $file);
        die;
    }
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

sub proc_stdin2stdout {
    my ($self, $proc, $in_data, $file_in_p) = @_;
    my $out_data = "";
    my ($tmp_in_fh, $tmp_in)   = tempfile(DIR => $self->{"comainu-temp"});
    my ($tmp_out_fh, $tmp_out) = tempfile(DIR => $self->{"comainu-temp"});
    close($tmp_in_fh);
    close($tmp_out_fh);
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
