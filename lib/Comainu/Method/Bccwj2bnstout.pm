package Comainu::Method::Bccwj2bnstout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Format;
use Comainu::Method::Kc2bnstout;

# 文節境界解析 BCCWJ
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: bccwj2bnstout\n");
    printf("  Usage: %s bccwj2bnstout <test-kc> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwj2bnstout sample/sample.bccwj.txt out\n");
    printf("    -> out/sample.bccwj.txt.bout\n");
    printf("\n");
}

sub run {
    my ($self, $test_bccwj, $save_dir) = @_;

    $self->before_analyze({
        dir => $save_dir, bnstmodel => $self->{bnstmodel}
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

    my $kc_file = $tmp_dir . "/" . $basename . ".KC";
    my $kc_bout_file = $tmp_dir . "/" . $basename . ".KC.bout";

    Comainu::Format->bccwj2kc_file($tmp_test_bccwj, $kc_file, $self->{boundary});
    my $kc2bnstout = Comainu::Method::Kc2bnstout->new(%$self);
    $kc2bnstout->analyze($kc_file, $tmp_dir);
    my $buff = Comainu::Format->merge_bccwj_with_kc_bout_file($tmp_test_bccwj, $kc_bout_file);
    $self->output_result($buff, $save_dir, $basename . ".bout");
    undef $buff;

    unless ( $self->{debug} ) {
        do { unlink $_ if -f $_; } for ($kc_bout_file, $tmp_test_bccwj);
    }

    return 0;
}


1;
