package Comainu::Method::Plain2midout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::SUWAnalysis;
use Comainu::Method::Kc2longout;
use Comainu::Method::Kclong2midout;

# Analyze middle-unit-word
sub usage {
    my $self = shift;
    while ( <DATA> ) {
        print $_;
    }
}

sub run {
    my ($self, $test_file, $save_dir) = @_;

    $self->before_analyze({
        dir       => $save_dir,
        luwmodel  => $self->{luwmodel},
        muwmodel  => $self->{muwmodel},
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
    my $kc_lout_file = $tmp_dir  . "/" . $basename . ".KC.lout";
    my $kc_mout_file = $tmp_dir  . "/" . $basename . ".KC.mout";

    my $suwanalysis = Comainu::SUWAnalysis->new(%$self);
    $suwanalysis->plain2kc_file($test_file, $mecab_file, $kc_file);

    my $kc2longout = Comainu::Method::Kc2longout->new(%$self);
    $kc2longout->analyze($kc_file, $tmp_dir);
    Comainu::Format->lout2kc4mid_file($kc_lout_file, $kc_file);

    my $kclong2midout = Comainu::Method::Kclong2midout->new(%$self);
    $kclong2midout->analyze($kc_file, $tmp_dir);

    my $buff = Comainu::Format->merge_mecab_with_kc_mout_file($mecab_file, $kc_mout_file);
    $self->output_result($buff, $save_dir, $basename . ".mout");
    undef $buff;

    unless ( $self->{debug} ) {
        do { unlink $_ if -f $_; } for ($mecab_file, $kc_lout_file, $kc_mout_file);
    }

    return 0;
}


1;


__DATA__
COMAINU-METHOD: plain2midout
  Usage: ./script/comainu.pl plain2midout [options]
    This command analyzes long-unit-word and middle-unit-word of <input>(file or STDIN) with <luwmodel> and <muwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --comainu-bi-model-dir    speficy the model directory for the category models
    --muwmodel                specify the middle-unit-word model (default: trian/MST/train.KC.model)

  ex.)
  $ perl ./script/comainu.pl plain2midout
  $ perl ./script/comainu.pl plain2midout --input=sample/plain/sample.txt --output-dir=out
    -> out/sample.txt.mout
  $ perl ./script/comainu.pl plain2midout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

