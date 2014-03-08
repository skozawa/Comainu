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

# 中単位解析 BCCWJ
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: bccwj2midout\n");
    printf("  Usage: %s bccwj2midout <test-kc> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <long-model-file> and <mid-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwj2midout sample/sample.bccwj.txt out\n");
    printf("    -> out/sample.bccwj.txt.mout\n");
    printf("\n");
}

sub run {
    my ($self, $test_bccwj, $save_dir) = @_;

    $self->before_analyze({
        dir       => $save_dir,
        luwmodel  => $self->{luwmodel},
        muwmodel  => $self->{muwmodel},
    });
    $self->analyze_files($test_bccwj, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_bccwj, $save_dir) = @_;

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

    my $kc_file       = $tmp_dir . "/" . $basename . ".KC";
    my $kc_lout_file  = $tmp_dir . "/" . $basename . ".KC.lout";
    my $kc_mout_file  = $tmp_dir . "/" . $basename . ".KC.mout";
    my $tmp_mout_file = $tmp_dir . "/" . $basename . ".tmp.mout";

    Comainu::Format->bccwj2kc_file($tmp_test_bccwj, $kc_file, $self->{boundary});
    my $kc2longout = Comainu::Method::Kc2longout->new(%$self);
    $kc2longout->analyze($kc_file, $tmp_dir);
    Comainu::Format->lout2kc4mid_file($kc_lout_file, $kc_file);
    my $kclong2midout = Comainu::Method::Kclong2midout->new(%$self);
    $kclong2midout->analyze($kc_file, $tmp_dir);
    Comainu::Format->merge_bccwj_with_kc_lout_file($tmp_test_bccwj, $kc_lout_file, $self->{boundary}, $tmp_mout_file);
    my $buff = Comainu::Format->merge_bccwj_with_kc_mout_file($tmp_mout_file, $kc_mout_file);
    $self->output_result($buff, $save_dir, $basename . ".mout");
    undef $buff;

    unless ( $self->{debug} ) {
        do { unlink $_ if -f $_; }
            for ($kc_lout_file, $kc_mout_file, $tmp_test_bccwj, $tmp_mout_file);
    }

    return 0;
}


1;
