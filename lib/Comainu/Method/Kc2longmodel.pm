package Comainu::Method::Kc2longmodel;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename dirname);
use Encode qw(decode_utf8);
use Config;

use Comainu::Util qw(read_from_file write_to_file);
use Comainu::Format;
use Comainu::Feature;
use Comainu::ExternalTool;
use Comainu::BIProcessor;

sub new {
    my ($class, %args) = @_;
    $class->SUPER::new( %args, args_num => 3 );
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
    $self->before_analyze({ dir => $model_dir, args_num => scalar @_ });

    my $tmp_train_kc = $self->{"comainu-temp"} . "/" . basename($train_kc);
    Comainu::Format->format_inputdata({
        input_file       => $train_kc,
        input_type       => 'input-kc',
        output_file      => $tmp_train_kc,
        output_type      => 'kc',
        data_format_file => $self->{data_format},
    });

    my $basename = basename($tmp_train_kc);
    my $kc2_file   = $model_dir . "/" . $basename . ".KC2";
    my $svmin_file = $model_dir . "/" . $basename .".svmin";

    $self->make_luw_traindata($tmp_train_kc, $svmin_file);
    $self->add_luw_label($tmp_train_kc, $model_dir);

    if ( $self->{"luwmodel"} eq "SVM" ) {
        $self->train_luwmodel_svm($tmp_train_kc, $svmin_file, $model_dir);
    } elsif ( $self->{"luwmodel"} eq "CRF" ) {
        $self->train_luwmodel_crf($tmp_train_kc, $svmin_file, $model_dir);
    }
    if ( $self->{"luwmrph"} eq "with" ) {
        $self->train_bi_model($tmp_train_kc, $model_dir);
    }
    unlink($tmp_train_kc);

    return 0;
}


# 長単位解析モデル学習用データを作成
sub make_luw_traindata {
    my ($self, $tmp_train_kc, $svmin_file) = @_;
    print STDERR "# MAKE TRAIN DATA\n";

    my $buff = Comainu::Feature->create_longmodel_feature($tmp_train_kc);
    write_to_file($svmin_file, $buff);
    undef $buff;

    print STDERR "Make $svmin_file\n";

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
    my $output_file = $model_dir . "/" . $basename .".svmin";

    ## 後処理用学習データの作成
    {
        open(my $fh_ref, "<", $tmp_train_kc)  or die "Cannot open '$tmp_train_kc'";
        open(my $fh_svmin, "<", $output_file) or die "Cannot open'$output_file'";
        my $bip_processor = Comainu::BIProcessor->new;
        $bip_processor->extract_from_train($fh_ref, $fh_svmin, $model_dir, $basename);
        close($fh_ref);
        close($fh_svmin);
    }

    unlink $output_file unless -s $output_file;

    return 0;
}

sub train_luwmodel_svm {
    my ($self, $train_kc, $svmin_file, $model_dir) = @_;
    print STDERR "# TRAIN LUWMODEL\n";

    my $basename = basename($train_kc);
    my $makefile = Comainu::ExternalTool->create_yamcha_makefile(
        $self, $model_dir, $basename
    );
    my $com = sprintf("make -f \"%s\" PERL=\"%s\" CORPUS=\"%s\" MODEL=\"%s\" train",
                      $makefile, $self->{perl}, $svmin_file, $model_dir . "/" . $basename);
    printf(STDERR "# COM: %s\n", $com);
    system($com);

    return 0;
}

sub train_luwmodel_crf {
    my ($self, $train_kc, $svmin_file, $model_dir) = @_;
    print STDERR "# TRAIN LUWMODEL\n";

    $ENV{"LD_LIBRARY_PATH"} = "/usr/lib;/usr/local/lib";

    my $basename = basename($train_kc);
    my $crf_learn = $self->{"crf-dir"} . "/crf_learn";
    my $crf_template = $model_dir . "/" . $basename . ".template";

    ## 素性数を取得
    open(my $fh_svmin, $svmin_file);
    my $line = <$fh_svmin>;
    $line = decode_utf8 $line;
    my $feature_num = scalar(split(/ /,$line))-2;
    close($fh_svmin);

    Comainu::ExternalTool->create_crf_template($crf_template, $feature_num);

    my $crf_model = $model_dir . "/" . $basename .".model";
    my $com = "\"$crf_learn\" \"$crf_template\" \"$svmin_file\" \"$crf_model\"";
    printf(STDERR "# COM: %s\n", $com);
    system($com);

    return 0;
}

## BIのみに関する処理（後処理用）
sub train_bi_model {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# TRAIN BI MODEL\n";

    my $basename = basename($train_kc);
    my $makefile = Comainu::ExternalTool->create_yamcha_makefile(
        $self, $model_dir, $basename
    );
    my $perl = $self->{perl};

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
