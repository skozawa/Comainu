package Comainu::Method::Plain2bnstout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::SUWAnalysis;
use Comainu::Method::Kc2bnstout;

# Analyze bunsetsu boundary
sub usage {
    my $self = shift;
    while ( <DATA> ) {
        print $_;
    }
}

sub run {
    my ($self, $test_file, $save_dir) = @_;

    $self->before_analyze({
        dir => $save_dir, bnstmodel => $self->{bnstmodel}
    });
    $self->analyze_files($test_file, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_file, $save_dir) = @_;

    my $tmp_dir = $self->{"comainu-temp"};
    my $basename = basename($test_file);
    my $mecab_file   = $tmp_dir  . "/" . $basename . ".mecab";
    my $kc_file      = $tmp_dir  . "/" . $basename . ".KC";
    my $kc_bout_file = $tmp_dir  . "/" . $basename . ".KC.bout";

    my $suwanalysis = Comainu::SUWAnalysis->new(%$self);
    $suwanalysis->plain2kc_file($test_file, $mecab_file, $kc_file);

    my $kc2bnstout = Comainu::Method::Kc2bnstout->new(%$self);
    $kc2bnstout->analyze($kc_file, $tmp_dir);

    my $buff = Comainu::Format->merge_mecab_with_kc_bout_file($mecab_file, $kc_bout_file);
    $self->output_result($buff, $save_dir, $basename . ".bout");
    undef $buff;

    unless ( $self->{debug} ) {
        do { unlink $_ if -f $_; } for ($mecab_file, $kc_bout_file);
    }

    return 0;
}


1;


__DATA__
COMAINU-METHOD: plain2bnstout [options]
  Usage: ./script/comainu.pl plain2bnstout
    This command analyzes the bunsetsu boundary with <bnstmodel>.

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --bnstmodel               specify the bnst model (default: train/bnst.model)

  ex.)
  $ perl ./script/comainu.pl plain2bnstout
  $ perl ./script/comainu.pl plain2bnstout --input=sample/plain/sample.txt --output-dir=out
    -> out/sample.txt.bout
  $ perl ./script/comainu.pl palin2bnstout --bnstmodel=sample_train/sample.KC.model

