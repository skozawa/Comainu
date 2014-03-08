package Comainu::Method::Bccwjlong2midout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Format;
use Comainu::Method::Kclong2midout;

# Analyze middle-unit-word for BCCWJ with long-unit-word
sub usage {
    my $self = shift;
    while ( <DATA> ) {
        print $_;
    }
}

sub run {
    my ($self, $test_bccwj, $save_dir) = @_;

    $self->before_analyze({
        dir => $save_dir, muwmodel => $self->{muwmodel}
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

    my $kc_file         = $tmp_dir  . "/" . $basename . ".KC";
    my $kc_mout_file    = $tmp_dir  . "/" . $basename . ".KC.mout";

    Comainu::Format->bccwjlong2kc_file($tmp_test_bccwj, $kc_file, $self->{boundary});
    my $kclong2midout = Comainu::Method::Kclong2midout->new(%$self);
    $kclong2midout->analyze($kc_file, $tmp_dir);

    my $buff = Comainu::Format->merge_bccwj_with_kc_mout_file($tmp_test_bccwj, $kc_mout_file);
    $self->output_result($buff, $save_dir, $basename . ".mout");
    undef $buff;

    unless ( $self->{debug} ) {
        do { unlink $_ if -f $_; } for ($kc_mout_file, $tmp_test_bccwj);
    }

    return 0;
}


1;


__DATA__
COMAINU-METHOD: bccwjlong2midout
  Usage: ./script/comainu.pl bccwjlong2midout [options]
    This command analyzes middle-unit-word of <input>(file or STDIN) with <muwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --muwmodel                specify the middle-unit-word model (default: trian/MST/train.KC.model)

  ex.)
  $ perl ./script/comainu.pl bccwjlong2midout
  $ perl ./script/comainu.pl bccwjlong2midout --input=sample/sample.bccwj.txt --output-dir=out
    -> out/sample.bccwj.txt.mout
  $ perl ./script/comainu.pl bccwjlong2midout --muwmodel=sample_train/sample_mid.KC.model

