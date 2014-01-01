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

sub new {
    my ($class, %args) = @_;
    $class->SUPER::new( %args, args_num => 5 );
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

    $self->before_analyze({
        dir       => $save_dir,
        bnstmodel => $bnstmodel,
        luwmodel  => $luwmodel,
        args_num  => scalar @_
    });

    $self->analyze_files($test_bccwj, $luwmodel, $bnstmodel, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_bccwj, $luwmodel, $bnstmodel, $save_dir) = @_;

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

    my $kc_file          = $tmp_dir  . "/" . $basename . ".KC";
    my $kc_lout_file     = $tmp_dir  . "/" . $basename . ".KC.lout";
    my $kc_bout_file     = $tmp_dir  . "/" . $basename . ".KC.bout";
    my $bccwj_lbout_file = $save_dir . "/" . $basename . ".lbout";

    $self->{"bnst_process"} = "with_luw";

    Comainu::Format->bccwj2kc_file($tmp_test_bccwj, $kc_file, $self->{boundary});
    my $kc2longout = Comainu::Method::Kc2longout->new(%$self);
    $kc2longout->run($kc_file, $luwmodel, $tmp_dir);
    my $kc2bnstout = Comainu::Method::Kc2bnstout->new(%$self);
    $kc2bnstout->run($kc_file, $bnstmodel, $tmp_dir);
    Comainu::Format->merge_bccwj_with_kc_lout_file($tmp_test_bccwj, $kc_lout_file, $bccwj_lbout_file, $self->{boundary});
    Comainu::Format->merge_bccwj_with_kc_bout_file($bccwj_lbout_file, $kc_bout_file, $bccwj_lbout_file);

    unless ( $self->{debug} ) {
        do { unlink $_ if -f $_; } for ($kc_lout_file, $kc_bout_file, $tmp_test_bccwj);
    }

    return 0;
}


1;
