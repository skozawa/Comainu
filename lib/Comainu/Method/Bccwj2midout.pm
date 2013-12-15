package Comainu::Method::Bccwj2midout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Method::Kc2longout;
use Comainu::Method::Kclong2midout;

sub new {
    my ($class, %args) = @_;
    bless {
        args_num => 5,
        comainu  => delete $args{comainu},
        %args
    }, $class;
}

# 中単位解析 BCCWJ
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: bccwj2midout\n");
    printf("  Usage: %s bccwj2midout <test-kc> <long-model-file> <mid-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <long-model-file> and <mid-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwj2midout sample/sample.bccwj.txt trian/CRF/train.KC.model train/MST/train.KC.model out\n");
    printf("    -> out/sample.bccwj.txt.mout\n");
    printf("\n");
}

sub run {
    my ($self, $test_bccwj, $luwmodel, $muwmodel, $save_dir) = @_;

    $self->before_analyze(scalar @_, $save_dir);
    $self->comainu->check_luwmodel($luwmodel);
    $self->comainu->check_file($muwmodel);

    $self->analyze_files($test_bccwj, $luwmodel, $muwmodel, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_bccwj, $luwmodel, $muwmodel, $save_dir) = @_;

    my $basename = basename($test_bccwj);
    my $tmp_dir = $self->comainu->{"comainu-temp"};
    my $tmp_test_bccwj = $tmp_dir . "/" . $basename;
    $self->comainu->format_inputdata($test_bccwj, $tmp_test_bccwj, "input-bccwj", "bccwj");

    my $kc_file         = $tmp_dir  . "/" . $basename . ".KC";
    my $kc_lout_file    = $tmp_dir  . "/" . $basename . ".KC.lout";
    my $kc_mout_file    = $tmp_dir  . "/" . $basename . ".KC.mout";
    my $bccwj_mout_file = $save_dir . "/" . $basename . ".mout";

    $self->comainu->bccwj2kc_file($tmp_test_bccwj, $kc_file);
    my $kc2longout = Comainu::Method::Kc2longout->new(comainu => $self->comainu);
    $kc2longout->run($kc_file, $luwmodel, $tmp_dir);
    $self->comainu->lout2kc4mid_file($kc_lout_file, $kc_file);
    my $kclong2midout = Comainu::Method::Kclong2midout->new(comainu => $self->comainu);
    $kclong2midout->run($kc_file, $muwmodel, $tmp_dir);
    $self->comainu->merge_bccwj_with_kc_lout_file($tmp_test_bccwj, $kc_lout_file, $bccwj_mout_file);
    $self->comainu->merge_bccwj_with_kc_mout_file($bccwj_mout_file, $kc_mout_file, $bccwj_mout_file);

    unless ( $self->comainu->{debug} ) {
        do { unlink $_ if -f $_; } for ($kc_lout_file, $kc_mout_file, $tmp_test_bccwj);
    }

    return 0;
}


1;
