package Comainu::Method::Bccwj2longbnstout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Format;
use Comainu::Method::Kc2longout;
use Comainu::Method::Kc2bnstout;

# 文節，長単位の同時出力
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: bccwj2longbnstout\n");
    printf("  Usage: %s bccwj2longbnstout <test-bccwj> <out-dir>\n", $0);
    printf("    This command analyzes <test-bccwj> with <long-model-file> and <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwj2longbnstout sample/sample.bccwj.txt out\n");
    printf("    -> out/sample.bccwj.txt.lbout\n");
    printf("\n");
}

sub run {
    my ($self, $test_bccwj, $save_dir) = @_;

    $self->before_analyze({
        dir       => $save_dir,
        bnstmodel => $self->{bnstmodel},
        luwmodel  => $self->{luwmodel},
    });
    $self->analyze_files($test_bccwj, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_bccwj, $save_dir) = @_;

    my $tmp_dir = $self->{"comainu-temp"};
    my $basename = basename($test_bccwj);
    my $tmp_test_bccwj = $tmp_dir . "/" . $basename;
    Comainu::Format->format_inputdata({
        input_file       => $test_bccwj,
        input_type       => 'input-bccwj',
        output_file      => $tmp_test_bccwj,
        output_type      => 'bccwj',
        data_format_file => $self->{data_format},
    });

    my $kc_file        = $tmp_dir . "/" . $basename . ".KC";
    my $kc_lout_file   = $tmp_dir . "/" . $basename . ".KC.lout";
    my $kc_bout_file   = $tmp_dir . "/" . $basename . ".KC.bout";
    my $tmp_lbout_file = $tmp_dir . "/" . $basename . ".tmp.lbout";

    $self->{"bnst_process"} = "with_luw";

    Comainu::Format->bccwj2kc_file($tmp_test_bccwj, $kc_file, $self->{boundary});
    my $kc2longout = Comainu::Method::Kc2longout->new(%$self);
    $kc2longout->analyze($kc_file, $tmp_dir);
    my $kc2bnstout = Comainu::Method::Kc2bnstout->new(%$self);
    $kc2bnstout->analyze($kc_file, $tmp_dir);
    Comainu::Format->merge_bccwj_with_kc_lout_file($tmp_test_bccwj, $kc_lout_file, $self->{boundary}, $tmp_lbout_file);
    my $buff = Comainu::Format->merge_bccwj_with_kc_bout_file($tmp_lbout_file, $kc_bout_file);
    $self->output_result($buff, $save_dir, $basename . ".lbout");
    undef $buff;

    unless ( $self->{debug} ) {
        do { unlink $_ if -f $_; }
            for ($kc_lout_file, $kc_bout_file, $tmp_test_bccwj, $tmp_lbout_file);
    }

    return 0;
}


1;
