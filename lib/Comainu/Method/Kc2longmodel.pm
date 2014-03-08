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
use Comainu::BIProcessor;

sub new {
    my ($class, %args) = @_;
    $class->SUPER::new( %args, args_num => 3 );
}

# Train the model for analyzing long-unid-word with KC fiel
sub usage {
    my $self = shift;
    while ( <DATA> ) {
        print $_;
    }
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

    $self->make_luw_traindata($tmp_train_kc, $svmin_file, $model_dir);

    if ( $self->{"luwmodel-type"} eq "SVM" ) {
        $self->train_luwmodel_svm($tmp_train_kc, $svmin_file, $model_dir);
    } elsif ( $self->{"luwmodel-type"} eq "CRF" ) {
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
    my ($self, $tmp_train_kc, $svmin_file, $model_dir) = @_;
    print STDERR "# MAKE TRAIN DATA\n";

    my $buff = Comainu::Feature->create_longmodel_feature($tmp_train_kc);
    write_to_file($svmin_file, $buff);
    undef $buff;

    print STDERR "Make $svmin_file\n";

    my $basename = basename($tmp_train_kc);
    my $bi_processor = Comainu::BIProcessor->new(%$self);
    $bi_processor->create_train_data($tmp_train_kc, $svmin_file, $model_dir, $basename);

    return 0;
}

sub train_luwmodel_svm {
    my ($self, $train_kc, $svmin_file, $model_dir) = @_;
    print STDERR "# TRAIN LUWMODEL\n";

    my $basename = basename($train_kc);
    my $external_tool = Comainu::ExternalTool->new(%$self);
    my $makefile = $external_tool->create_yamcha_makefile($model_dir, $basename);
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

    # get the number of the feature for training
    open(my $fh_svmin, $svmin_file);
    my $line = <$fh_svmin>;
    $line = decode_utf8 $line;
    my @items = split / /, $line;
    my $feature_num = scalar @items - 2;
    close($fh_svmin);

    my $external_tool = Comainu::ExternalTool->new(%$self);
    $external_tool->create_crf_template($crf_template, $feature_num);

    my $crf_model = $model_dir . "/" . $basename .".model";
    my $com = "\"$crf_learn\" \"$crf_template\" \"$svmin_file\" \"$crf_model\"";
    printf(STDERR "# COM: %s\n", $com);
    system($com);

    return 0;
}

# train BI model (analyzing pos, cForm and cType categories)
sub train_bi_model {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# TRAIN BI MODEL\n";

    my $basename = basename($train_kc);
    my $bi_processor = Comainu::BIProcessor->new(%$self);
    $bi_processor->train($basename, $model_dir);

    return 0;
}


1;


__DATA__
COMAINU-METHOD: kc2longmodel
  Usage: ./script/comainu.pl kc2longmodel <train-kc> <long-model-dir>
    This command trains the model for analyzing long-unit-word with <train-kc>.
    The model is put into <long-model-dir>

  option
    --help                    show this message and exit
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)

  ex.)
  $ perl ./script/comainu.pl kc2longmodel sample/sample.KC sample_train
    -> sample_train/sample.KC.model

