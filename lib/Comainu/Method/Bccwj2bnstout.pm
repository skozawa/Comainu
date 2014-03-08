package Comainu::Method::Bccwj2bnstout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Format;
use Comainu::Method::Kc2bnstout;

# Analyze bunsetsu boundary for BCCWJ
sub usage {
    my $self = shift;
    while ( <DATA> ) {
        print $_;
    }
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


__DATA__
COMAINU-METHOD: bccwj2bnstout [options]
  Usage: ./script/comainu.pl bccwj2bnstout
    This command analyzes the bunsetsu boundary with <bnstmodel>.

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --bnstmodel               specify the bnst model (default: train/bnst.model)

  ex.)
  $ perl ./script/comainu.pl bccwj2bnstout
  $ perl ./script/comainu.pl bccwj2bnstout --input=sample/sample.bccwj.txt --output-dir=out
    -> out/sample.bccwj.txt.bout
  $ perl ./script/comainu.pl bccwj2bnstout --bnstmodel=sample_train/sample.KC.model

