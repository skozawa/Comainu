package Comainu::Method::Kc2bnstmodel;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename dirname);
use Config;

use Comainu::Util qw(read_from_file write_to_file);
use Comainu::Feature;
use Comainu::Format;
use Comainu::ExternalTool;

sub new {
    my ($class, %args) = @_;
    $class->SUPER::new( %args, args_num => 3 );
}

# 文節境界解析モデルの学習
sub usage {
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

sub run {
    my ($self, $train_kc, $model_dir) = @_;

    $model_dir = dirname($train_kc) if $train_kc && !$model_dir;
    $self->before_analyze({ dir => $model_dir, args_num => scalar @_ });

    my $basename = basename($train_kc);
    my $tmp_train_kc = $self->{"comainu-temp"} . "/" . $basename;
    Comainu::Format->format_inputdata({
        input_file       => $train_kc,
        input_type       => 'input-kc',
        output_file      => $tmp_train_kc,
        output_type      => 'kc',
        data_format_file => $self->{data_format},
    });

    my $svmin_file = $model_dir . "/" . $basename . ".svmin";

    $self->create_svmin($tmp_train_kc, $svmin_file);
    $self->train($tmp_train_kc, $svmin_file, $model_dir);

    return 0;
}

sub create_svmin {
    my ($self, $tmp_train_kc, $svmin_file) = @_;

    my $buff = Comainu::Feature->create_bnstmodel_feature($tmp_train_kc);
    write_to_file($svmin_file, $buff);
    undef $buff;
}

sub train {
    my ($self, $tmp_train_kc, $svmin_file, $model_dir) = @_;
    print STDERR "# TRAIN BNST MODEL\n";

    my $basename = basename($tmp_train_kc);
    my $external_tool = Comainu::ExternalTool->new(%$self);
    my $makefile = $external_tool->create_yamcha_makefile($model_dir, $basename);
    my $com = sprintf("make -f \"%s\" PERL=\"%s\" CORPUS=\"%s\" MODEL=\"%s\" train",
                      $makefile, $self->{perl}, $svmin_file, $model_dir . "/" . $basename);

    printf(STDERR "# COM: %s\n", $com);
    system($com);
}

1;
