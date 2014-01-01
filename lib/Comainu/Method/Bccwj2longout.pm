package Comainu::Method::Bccwj2longout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Format;
use Comainu::Method::Kc2longout;

sub new {
    my ($class, %args) = @_;
    bless {
        args_num => 4,
        comainu  => delete $args{comainu},
        %args
    }, $class;
}

# 長単位解析 BCCWJ
# 解析対象BCCWJファイル、モデルファイルの３つを用いて
# 解析対象BCCWJファイルに長単位情報を付与する。
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: bccwj2longout\n");
    printf("  Usage: %s bccwj2longout <test-bccwj> <long-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-bccwj> with <long-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwj2longout sample/sample.bccwj.txt train/CRF/train.KC.model out\n");
    printf("    -> out/sample.bccwj.txt.lout\n");
    printf("  \$ perl ./script/comainu.pl bccwj2longout --luwmodel=SVM sample/sample.bccwj.txt train/SVM/train.KC.model out\n");
    printf("    -> out/sample.bccwj.txt.lout\n");
    printf("\n");
}

sub run {
    my ($self, $test_bccwj, $luwmodel, $save_dir) = @_;

    $self->before_analyze({
        dir => $save_dir, luwmodel  => $luwmodel, args_num  => scalar @_
    });

    $self->analyze_files($test_bccwj, $luwmodel, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_bccwj, $luwmodel, $save_dir) = @_;

    my $tmp_dir = $self->comainu->{"comainu-temp"};
    my $basename = basename($test_bccwj);
    my $tmp_test_bccwj =  $tmp_dir . "/" . $basename;
    Comainu::Format->format_inputdata({
        input_file       => $test_bccwj,
        input_type       => 'input-bccwj',
        output_file      => $tmp_test_bccwj,
        output_type      => 'bccwj',
        data_format_file => $self->comainu->{data_format},
    });

    my $kc_file         = $tmp_dir  . "/" . $basename . ".KC";
    my $kc_lout_file    = $tmp_dir  . "/" . $basename . ".KC.lout";
    my $bccwj_lout_file = $save_dir . "/" . $basename . ".lout";

    Comainu::Format->bccwj2kc_file($tmp_test_bccwj, $kc_file, $self->comainu->{boundary});
    my $kc2longout = Comainu::Method::Kc2longout->new(comainu => $self->comainu);
    $kc2longout->run($kc_file, $luwmodel, $tmp_dir);
    $self->comainu->merge_bccwj_with_kc_lout_file($tmp_test_bccwj, $kc_lout_file, $bccwj_lout_file);

    unless ( $self->comainu->{debug} ) {
        do { unlink $_ if -f $_; } for ($kc_lout_file, $tmp_test_bccwj);
    }

    return 0;
}


1;
