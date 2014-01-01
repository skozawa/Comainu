package Comainu::Method::Kclong2midmodel;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename dirname);
use Config;

use Comainu::Util qw(read_from_file write_to_file);
use Comainu::Format;

sub new {
    my ($class, %args) = @_;
    bless {
        args_num => 3,
        comainu  => delete $args{comainu},
        %args
    }, $class;
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

    $self->create_mid_traindata($train_kc, $model_dir);
    $self->train_midmodel($train_kc, $model_dir);

    return 0;
}

## 中単位解析モデル学習用データの作成
sub create_mid_traindata {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# CREATE MUW TRAINDATA\n";

    my $basename = basename($train_kc);
    my $buff = read_from_file($train_kc);
    Comainu::Format->trans_dataformat($buff, {
        input_type       => 'input-kc',
        output_type      => 'kc_mid',
        data_format_file => $self->comainu->{data_format},
    });
    $buff = Comainu::Format->kc2mstin($buff);

    write_to_file($model_dir . "/" . $basename . ".mstin", $buff);
    undef $buff;

    return 0;
}

## 中単位解析モデルの学習
sub train_midmodel {
    my ($self, $train_kc, $model_dir) = @_;
    print STDERR "# TRAIN MUW MODEL\n";

    my $java = $self->comainu->{java};
    my $mstparser_dir = $self->comainu->{"mstparser-dir"};

    my $basename   = basename($train_kc);
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


1;
