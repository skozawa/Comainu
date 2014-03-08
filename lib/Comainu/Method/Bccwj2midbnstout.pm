package Comainu::Method::Bccwj2midbnstout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Format;
use Comainu::Method::Kc2longout;
use Comainu::Method::Kc2bnstout;
use Comainu::Method::Kclong2midout;

# Analyze bunsetsu boundary, long-unit-word and middle-unit-word for BCCWJ
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
        luwmodel  => $self->{luwmodel},
        muwmodel  => $self->{muwmodel},
        bnstmodel => $self->{bnstmodel},
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
    my $kc_mout_file   = $tmp_dir . "/" . $basename . ".KC.mout";
    my $kc_bout_file   = $tmp_dir . "/" . $basename . ".KC.bout";
    my $tmp_mbout_file = $tmp_dir . "/" . $basename . ".tmp.mbout";

    $self->{"bnst_process"} = "with_luw";

    Comainu::Format->bccwj2kc_file($tmp_test_bccwj, $kc_file, $self->{boundary});

    my $kc2longout = Comainu::Method::Kc2longout->new(%$self);
    $kc2longout->analyze($kc_file, $tmp_dir);

    my $kc2bnstout = Comainu::Method::Kc2bnstout->new(%$self);
    $kc2bnstout->analyze($kc_file, $tmp_dir);

    Comainu::Format->lout2kc4mid_file($kc_lout_file, $kc_file);
    my $kclong2midout = Comainu::Method::Kclong2midout->new(%$self);
    $kclong2midout->analyze($kc_file, $tmp_dir);

    Comainu::Format->merge_bccwj_with_kc_lout_file($tmp_test_bccwj, $kc_lout_file, $self->{boundary}, $tmp_mbout_file);
    Comainu::Format->merge_bccwj_with_kc_bout_file($tmp_mbout_file, $kc_bout_file, $tmp_mbout_file);
    my $buff = Comainu::Format->merge_bccwj_with_kc_mout_file($tmp_mbout_file, $kc_mout_file);
    $self->output_result($buff, $save_dir, $basename . ".mbout");
    undef $buff;

    unless ( $self->{debug} ) {
        do { unlink $_ if -f $_; }
            for ($kc_lout_file, $kc_mout_file, $kc_bout_file, $tmp_test_bccwj, $tmp_mbout_file);
    }

    return 0;
}


1;


__DATA__
COMAINU-METHOD: bccwj2midbnstout
  Usage: ./script/comainu.pl bccwj2midbnstout [options]
    This command analyzes bunsetsu boudnary, long-unit-word and middle-unit-word of <input>(file or STDIN) with <bnstmodel>, <luwmodel> and <muwmodel>

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
    --comainu-bi-model-dir    speficy the model directory for the category models
    --muwmodel                specify the middle-unit-word model (default: trian/MST/train.KC.model)

  ex.)
  $ perl ./script/comainu.pl bccwj2midbnstout
  $ perl ./script/comainu.pl bccwj2midbnstout --input=sample/sample.bccwj.txt --output-dir=out
    -> out/sample.bccwj.txt.mbout
  $ perl ./script/comainu.pl bccwj2midbnstout --luwmodel-type=SVM --luwmodel=train/SVM/train.KC.model

