package Comainu::Method::Kclong2midmodel;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename dirname);
use Config;

use Comainu::Util qw(read_from_file write_to_file);
use Comainu::Format;
use Comainu::Feature;

sub new {
    my ($class, %args) = @_;
    $class->SUPER::new( %args, args_num => 3 );
}

# 中単位解析モデルの学習
sub usage {
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
        output_type      => 'kc_mid',
        data_format_file => $self->{data_format},
    });

    my $mstin_file = $model_dir . "/" . $basename . ".mstin";
    my $model_file = $model_dir . "/" . $basename . ".model";

    $self->create_mid_traindata($train_kc, $mstin_file);
    $self->train_midmodel($mstin_file, $model_file);

    return 0;
}

## 中単位解析モデル学習用データの作成
sub create_mid_traindata {
    my ($self, $train_kc, $mstin_file) = @_;
    print STDERR "# CREATE MUW TRAINDATA\n";

    my $buff = Comainu::Feature->create_mst_feature($train_kc);
    write_to_file($mstin_file, $buff);
    undef $buff;

    return 0;
}

## 中単位解析モデルの学習
sub train_midmodel {
    my ($self, $mstin_file, $model_file) = @_;
    print STDERR "# TRAIN MUW MODEL\n";

    my $java = $self->{java};
    my $mstparser_dir = $self->{"mstparser-dir"};

    my $mst_classpath = $mstparser_dir . "/output/classes:"
        . $mstparser_dir . "/lib/trove.jar";
    my $memory = "-Xmx1800m";
    if ( $Config{osname} eq "MSWin32" ) {
        $mst_classpath = $mstparser_dir . "/output/classes;"
            . $mstparser_dir . "/lib/trove.jar";
        $memory = "-Xmx1000m";
        # remove drive letter for MS-Windows
        $mstin_file =~ s/^[a-zA-Z]\://;
        $model_file =~ s/^[a-zA-Z]\://;
    }
    my $cmd = sprintf("\"%s\" -classpath \"%s\" %s mstparser.DependencyParser train train-file:\"%s\" model-name:\"%s\" order:1",
                      $java, $mst_classpath, $memory, $mstin_file, $model_file);
    print STDERR $cmd,"\n";
    system($cmd);

    return 0;
}


1;
