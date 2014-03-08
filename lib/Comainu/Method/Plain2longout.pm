package Comainu::Method::Plain2longout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::SUWAnalysis;
use Comainu::Method::Kc2longout;

# 平文からの長単位解析
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: plain2longout\n");
    printf("  Usage: %s plain2longout <test-text> <out-dir>\n", $0);
    printf("    This command analyzes <test-text> with MeCab and <long-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl plain2longout sample/plain/sample.txt out\n");
    printf("    -> out/sample.txt.lout\n");
    printf("\n");
}

sub run {
    my ($self, $test_file, $save_dir) = @_;

    $self->before_analyze({
        dir => $save_dir, luwmodel => $self->{luwmodel}
    });
    $self->analyze_files($test_file, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_file, $save_dir) = @_;

    my $tmp_dir = $self->{"comainu-temp"};
    my $basename = basename($test_file);

    my $mecab_file      = $tmp_dir  . "/" . $basename . ".mecab";
    my $kc_file         = $tmp_dir  . "/" . $basename . ".KC";
    my $kc_lout_file    = $tmp_dir  . "/" . $basename . ".KC.lout";

    my $suwanalysis = Comainu::SUWAnalysis->new(%$self);
    $suwanalysis->plain2kc_file($test_file, $mecab_file, $kc_file);

    my $kc2longout = Comainu::Method::Kc2longout->new(%$self);
    $kc2longout->analyze($kc_file, $tmp_dir);

    my $buff = Comainu::Format->merge_mecab_with_kc_lout_file($mecab_file, $kc_lout_file);
    $self->output_result($buff, $save_dir, $basename . ".lout");
    undef $buff;

    unless ( $self->{debug} ) {
        do { unlink $_ if -f $_; } for ($mecab_file, $kc_lout_file);
    }

    return 0;
}


1;
