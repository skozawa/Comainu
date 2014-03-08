package Comainu::Method::Plain2longout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::SUWAnalysis;
use Comainu::Method::Kc2longout;

# Analyze long-unit-word
sub usage {
    my $self = shift;
    while ( <DATA> ) {
        print $_;
    }
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


__DATA__
COMAINU-METHOD: plain2longout
  Usage: ./script/comainu.pl plain2longout [options]
    This command analyzes long-unit-word of <input>(file or STDIN) with <luwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --comainu-bi-model-dir    speficy the model directory for the category models

  ex.)
  $ perl ./script/comainu.pl plain2longout
  $ perl ./script/comainu.pl plain2longout --input=sample/plain/sample.txt --output-dir=out
    -> out/sample.txt.lout
  $ perl ./script/comainu.pl plain2longout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

