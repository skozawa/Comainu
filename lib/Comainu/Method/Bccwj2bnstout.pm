package Comainu::Method::Bccwj2bnstout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Format;
use Comainu::Method::Kc2bnstout;

sub new {
    my ($class, %args) = @_;
    bless {
        args_num => 4,
        comainu  => delete $args{comainu},
        %args
    }, $class;
}

# 文節境界解析 BCCWJ
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: bccwj2bnstout\n");
    printf("  Usage: %s bccwj2bnstout <test-kc> <bnst-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl bccwj2bnstout sample/sample.bccwj.txt train/bnst.model out\n");
    printf("    -> out/sample.bccwj.txt.bout\n");
    printf("\n");
}

sub run {
    my ($self, $test_bccwj, $bnstmodel, $save_dir) = @_;

    $self->before_analyze({
        dir => $save_dir, bnstmodel => $bnstmodel, args_num => scalar @_
    });

    $self->analyze_files($test_bccwj, $bnstmodel, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_bccwj, $bnstmodel, $save_dir) = @_;

    my $tmp_dir = $self->comainu->{"comainu-temp"};
    my $basename = basename($test_bccwj);
    my $tmp_test_bccwj = $tmp_dir . "/" . $basename;
    Comainu::Format->format_inputdata({
        input_file       => $test_bccwj,
        input_type       => 'input-bccwj',
        output_file      => $tmp_test_bccwj,
        output_type      => 'bccwj',
        data_format_file => $self->comainu->{data_format},
    });

    my $kc_file = $tmp_dir . "/" . $basename . ".KC";
    my $kc_bout_file = $tmp_dir . "/" . $basename . ".KC.bout";
    my $bccwj_bout_file = $save_dir . "/" . $basename . ".bout";

    $self->comainu->bccwj2kc_file($tmp_test_bccwj, $kc_file);
    my $kc2bnstout = Comainu::Method::Kc2bnstout->new(comainu => $self->comainu);
    $kc2bnstout->run($kc_file, $bnstmodel, $tmp_dir);
    $self->comainu->merge_bccwj_with_kc_bout_file($tmp_test_bccwj, $kc_bout_file, $bccwj_bout_file);

    unless ( $self->comainu->{debug} ) {
        do { unlink $_ if -f $_; } for ($kc_bout_file, $tmp_test_bccwj);
    }

    return 0;
}


1;
