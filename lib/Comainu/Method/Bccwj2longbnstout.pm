package Comainu::Method::Bccwj2longbnstout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Method::Kc2longout;
use Comainu::Method::Kc2bnstout;

sub new {
    my ($class, %args) = @_;
    bless {
        args_num => 5,
        comainu  => delete $args{comainu},
        %args
    }, $class;
}

# 文節，長単位の同時出力
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: bccwj2longbnstout\n");
    printf("  Usage: %s bccwj2longbnstout <test-bccwj> <long-model-file> <bnst-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-bccwj> with <long-model-file> and <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwj2longbnstout sample/sample.bccwj.txt train/CRF/train.KC.model train/bnst.model out\n");
    printf("    -> out/sample.bccwj.txt.lbout\n");
    printf("\n");
}

sub run {
    my ($self, $test_bccwj, $luwmodel, $bnstmodel, $save_dir) = @_;

    $self->before_analyze(scalar @_, $save_dir);
    $self->comainu->check_luwmodel($luwmodel);
    $self->comainu->check_file($bnstmodel);

    $self->analyze_files($test_bccwj, $luwmodel, $bnstmodel, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_bccwj, $luwmodel, $bnstmodel, $save_dir) = @_;

    my $tmp_dir = $self->comainu->{"comainu-temp"};
    my $basename = basename($test_bccwj);
    my $tmp_test_bccwj = $tmp_dir . "/" . $basename;
    $self->comainu->format_inputdata($test_bccwj, $tmp_test_bccwj, "input-bccwj", "bccwj");

    my $kc_file          = $tmp_dir  . "/" . $basename . ".KC";
    my $kc_lout_file     = $tmp_dir  . "/" . $basename . ".KC.lout";
    my $kc_bout_file     = $tmp_dir  . "/" . $basename . ".KC.bout";
    my $bccwj_lbout_file = $save_dir . "/" . $basename . ".lbout";

    $self->comainu->{"bnst_process"} = "with_luw";

    $self->comainu->bccwj2kc_file($tmp_test_bccwj, $kc_file);
    my $kc2longout = Comainu::Method::Kc2longout->new(comainu => $self->comainu);
    $kc2longout->run($kc_file, $luwmodel, $tmp_dir);
    my $kc2bnstout = Comainu::Method::Kc2bnstout->new(comainu => $self->comainu);
    $kc2bnstout->run($kc_file, $bnstmodel, $tmp_dir);
    $self->comainu->merge_bccwj_with_kc_lout_file($tmp_test_bccwj, $kc_lout_file, $bccwj_lbout_file);
    $self->comainu->merge_bccwj_with_kc_bout_file($bccwj_lbout_file, $kc_bout_file, $bccwj_lbout_file);

    unless ( $self->comainu->{debug} ) {
        do { unlink $_ if -f $_; } for ($kc_lout_file, $kc_bout_file, $tmp_test_bccwj);
    }

    return 0;
}


1;
