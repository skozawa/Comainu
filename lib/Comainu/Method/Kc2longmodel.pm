package Comainu::Method::Kc2longmodel;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename dirname);
use Encode qw(decode_utf8);
use Config;

use Comainu::Util qw(read_from_file write_to_file);
use Comainu::Dictionary;
use AddFeature;
use BIProcessor;

sub new {
    my ($class, %args) = @_;
    bless {
        args_num => 3,
        comainu  => delete $args{comainu},
        %args
    }, $class;
}

# 訓練対象KCファイルからモデルを訓練する。
# 長単位解析モデルを学習する
sub usage {
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

sub run {
    my ($self, $train_kc, $model_dir) = @_;

    $model_dir = dirname($train_kc) if $train_kc && !$model_dir;
    $self->before_analyze(scalar @_, $model_dir);

    my $tmp_train_kc = $self->comainu->{"comainu-temp"} . "/" . basename($train_kc);
    $self->comainu->format_inputdata($train_kc, $tmp_train_kc, "input-kc", "kc");

    $self->make_luw_traindata($tmp_train_kc, $model_dir);
    $self->add_luw_label($tmp_train_kc, $model_dir);

    if ( $self->comainu->{"luwmodel"} eq "SVM" ) {
        $self->train_luwmodel_svm($tmp_train_kc, $model_dir);
    } elsif ( $self->comainu->{"luwmodel"} eq "CRF" ) {
        $self->train_luwmodel_crf($tmp_train_kc, $model_dir);
    }
    if ( $self->comainu->{"luwmrph"} eq "with" ) {
        $self->train_bi_model($tmp_train_kc, $model_dir);
    }
    unlink($tmp_train_kc);

    return 0;
}


# 長単位解析モデル学習用データを作成
sub make_luw_traindata {
    my ($self, $tmp_train_kc, $model_dir) = @_;
    print STDERR "# MAKE TRAIN DATA\n";

    my $basename = basename($tmp_train_kc);
    my $buff = read_from_file($tmp_train_kc);
    $buff =~ s/^EOS.*?\n|^\*B.*?\n//mg;
    $buff = $self->comainu->delete_column_long($buff);
    # $buff = $self->add_column($buff);

    ## 辞書の作成
    my $comainu_dic = Comainu::Dictionary->new;
    $comainu_dic->create($tmp_train_kc, $model_dir, $basename);
    ## 素性の追加
    my $AF = AddFeature->new;
    $buff = $AF->add_feature($buff, $basename, $model_dir);

    write_to_file($model_dir . "/" . $basename . ".KC2", $buff);
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

    my $basename = basename($tmp_train_kc);
    my $kc2_file    = $model_dir . "/" . $basename . ".KC2";
    my $output_file = $model_dir . "/" . $basename .".svmin";

    open(my $fh_ref, "<", $tmp_train_kc) or die "Cannot open '$tmp_train_kc'";
    open(my $fh_in, "<", $kc2_file)      or die "Cannot open '$kc2_file'";
    open(my $fh_out, ">", $output_file)  or die "Cannot open '$output_file'";
    binmode($fh_out);
    $self->comainu->add_pivot_to_kc2($fh_ref, $fh_in, $fh_out);
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

    my $basename = basename($train_kc);
    my $svmin = $model_dir . "/" . $basename . ".svmin";

    my $makefile = $self->comainu->create_yamcha_makefile($model_dir, $basename);
    my $perl = $self->comainu->{perl};
    my $com = sprintf("make -f \"%s\" PERL=\"%s\" CORPUS=\"%s\" MODEL=\"%s\" train",
                      $makefile, $perl, $svmin, $model_dir . "/" . $basename);
    printf(STDERR "# COM: %s\n", $com);
    system($com);

    return 0;
}

sub train_luwmodel_crf {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# TRAIN LUWMODEL\n";

    my $basename = basename($train_kc);

    $ENV{"LD_LIBRARY_PATH"} = "/usr/lib;/usr/local/lib";

    my $crf_learn = $self->comainu->{"crf-dir"} . "/crf_learn";
    my $crf_template = $model_dir . "/" . $basename . ".template";

    my $svmin = $model_dir . "/" . $basename . ".svmin";
    ## 素性数を取得
    open(my $fh_svmin, $svmin);
    my $line = <$fh_svmin>;
    $line = decode_utf8 $line;
    my $feature_num = scalar(split(/ /,$line))-2;
    close($fh_svmin);

    $self->comainu->create_template($crf_template, $feature_num);

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

    my $basename = basename($train_kc);
    my $makefile = $self->comainu->create_yamcha_makefile($model_dir, $basename);
    my $perl = $self->comainu->{perl};

    my $pos_dat   = $model_dir . "/pos/" . $basename . ".BI_pos.dat";
    my $pos_model = $model_dir . "/pos/" . $basename . ".BI_pos";
    my $BI_com1 = sprintf("make -f \"%s\" PERL=\"%s\" MULTI_CLASS=2 FEATURE=\"F:0:0.. \" CORPUS=\"%s\" MODEL=\"%s\" train",
                          $makefile, $perl, $pos_dat, $pos_model);
    system($BI_com1);

    my $cType_dat   = $model_dir . "/cType/" . $basename . ".BI_cType.dat";
    my $cType_model = $model_dir . "/cType/" . $basename . ".BI_cType";
    my $BI_com2 = sprintf("make -f \"%s\" PERL=\"%s\" MULTI_CLASS=2 FEATURE=\"F:0:0.. \" CORPUS=\"%s\" MODEL=\"%s\" train",
                          $makefile, $perl, $cType_dat, $cType_model);
    system($BI_com2);

    my $cForm_dat   = $model_dir . "/cForm/" . $basename . ".BI_cForm.dat";
    my $cForm_model = $model_dir . "/cForm/" . $basename . ".BI_cForm";
    my $BI_com3 = sprintf("make -f \"%s\" PERL=\"%s\" MULTI_CLASS=2 FEATURE=\"F:0:0.. \" CORPUS=\"%s\" MODEL=\"%s\" train",
                          $makefile, $perl, $cForm_dat, $cForm_model);
    system($BI_com3);

    return 0;
}


1;
