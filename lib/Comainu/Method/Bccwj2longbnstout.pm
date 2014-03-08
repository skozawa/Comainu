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

# Analyze bunsetsu boundary and long-unit-word for BCCWJ
sub usage {
    my $self = shift;
    while ( <DATA> ) {
        print $_;
    }
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


__DATA__
COMAINU-METHOD: bccwj2longbnstout
  Usage: ./script/comainu.pl bccwj2longbnstout [options]
    This command analyzes bunsetsu boudnary and long-unit-word of <input>(file or STDIN) with <bnstmodel> and <luwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --bnstmodel               specify the bnst model (default: train/bnst.model)
    --luwmodel                specify the model of boundary of long-unit-word (default: train/CRF/train.KC.model)
    --luwmodel-type           specify the type of the model for boundary of long-unit-word (default: CRF)
                              (CRF or SVM)
    --boundary                specify the type of boundary (default: sentence)
                              (sentence or word)
    --luwmrph                 whether to output morphology of long-unit-word (default: with)
                              (with or without)
    --comainu-bi-model-dir    speficy the model directory for the category models

  ex.)
  $ perl ./script/comainu.pl bccwj2longbnstout
  $ perl ./script/comainu.pl bccwj2longbnstout --input=sample/sample.bccwj.txt --output-dir=out
    -> out/sample.bccwj.txt.lbout
  $ perl ./script/comainu.pl bccwj2longbnstout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

