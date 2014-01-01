package Comainu::Method::Bccwj2midout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Format;
use Comainu::Method::Kc2longout;
use Comainu::Method::Kclong2midout;

sub new {
    my ($class, %args) = @_;
    $class->SUPER::new( %args, args_num => 5 );
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

    $self->before_analyze({
        dir       => $save_dir,
        luwmodel  => $luwmodel,
        muwmodel  => $muwmodel,
        args_num  => scalar @_
    });

    $self->analyze_files($test_bccwj, $luwmodel, $muwmodel, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_bccwj, $luwmodel, $muwmodel, $save_dir) = @_;

    my $basename = basename($test_bccwj);
    my $tmp_dir = $self->{"comainu-temp"};
    my $tmp_test_bccwj = $tmp_dir . "/" . $basename;
    Comainu::Format->format_inputdata({
        input_file       => $test_bccwj,
        input_type       => 'input-bccwj',
        output_file      => $tmp_test_bccwj,
        output_type      => 'bccwj',
        data_format_file => $self->{data_format},
    });

    my $kc_file         = $tmp_dir  . "/" . $basename . ".KC";
    my $kc_lout_file    = $tmp_dir  . "/" . $basename . ".KC.lout";
    my $kc_mout_file    = $tmp_dir  . "/" . $basename . ".KC.mout";
    my $bccwj_mout_file = $save_dir . "/" . $basename . ".mout";

    Comainu::Format->bccwj2kc_file($tmp_test_bccwj, $kc_file, $self->{boundary});
    my $kc2longout = Comainu::Method::Kc2longout->new(%$self);
    $kc2longout->run($kc_file, $luwmodel, $tmp_dir);
    Comainu::Format->lout2kc4mid_file($kc_lout_file, $kc_file);
    my $kclong2midout = Comainu::Method::Kclong2midout->new(%$self);
    $kclong2midout->run($kc_file, $muwmodel, $tmp_dir);
    Comainu::Format->merge_bccwj_with_kc_lout_file($tmp_test_bccwj, $kc_lout_file, $bccwj_mout_file, $self->{boundary});
    Comainu::Format->merge_bccwj_with_kc_mout_file($bccwj_mout_file, $kc_mout_file, $bccwj_mout_file);

    unless ( $self->{debug} ) {
        do { unlink $_ if -f $_; } for ($kc_lout_file, $kc_mout_file, $tmp_test_bccwj);
    }

    return 0;
}


1;
