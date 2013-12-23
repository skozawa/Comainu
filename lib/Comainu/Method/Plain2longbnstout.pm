package Comainu::Method::Plain2longbnstout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::SUWAnalysis;
use Comainu::Method::Kc2longout;
use Comainu::Method::Kc2bnstout;

sub new {
    my ($class, %args) = @_;
    bless {
        args_num => 5,
        comainu  => delete $args{comainu},
        %args
    }, $class;
}

# 平文からの長単位・文節解析
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: plain2longbnstout\n");
    printf("  Usage: %s plain2longbnstout <test-text> <long-model-file> <bnst-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-text> with Mecab and <long-model-file> and <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl plain2longbnstout sample/plain/sample.txt train/CRF/train.KC.model train/bnst.model out\n");
    printf("    -> out/sample.txt.lbout\n");
    printf("\n");
}

sub run {
    my ($self, $test_file, $luwmodel, $bnstmodel, $save_dir) = @_;

    $self->before_analyze({
        dir       => $save_dir,
        luwmodel  => $luwmodel,
        bnstmodel => $bnstmodel,
        args_num  => scalar @_
    });

    $self->analyze($test_file, $luwmodel, $bnstmodel, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_file, $luwmodel, $bnstmodel, $save_dir) = @_;

    my $tmp_dir = $self->comainu->{"comainu-temp"};
    my $basename = basename($test_file);

    my $mecab_file   = $tmp_dir  . "/" . $basename . ".mecab";
    my $kc_file      = $tmp_dir  . "/" . $basename . ".KC";
    my $kc_lout_file = $tmp_dir  . "/" . $basename . ".KC.lout";
    my $kc_bout_file = $tmp_dir  . "/" . $basename . ".KC.bout";
    my $lbout_file   = $save_dir . "/" . $basename . ".lbout";

    $self->comainu->{"bnst_process"} = "with_luw";

    my $suwanalysis = Comainu::SUWAnalysis->new(comainu => $self->comainu);
    $suwanalysis->plain2kc_file($test_file, $mecab_file, $kc_file);

    my $kc2longout = Comainu::Method::Kc2longout->new(comainu => $self->comainu);
    $kc2longout->run($kc_file, $luwmodel, $tmp_dir);

    my $kc2bnstout = Comainu::Method::Kc2bnstout->new(comainu => $self->comainu);
    $kc2bnstout->run($kc_file, $bnstmodel, $tmp_dir);

    $self->comainu->merge_mecab_with_kc_lout_file($mecab_file, $kc_lout_file, $lbout_file);
    $self->comainu->merge_mecab_with_kc_bout_file($lbout_file, $kc_bout_file, $lbout_file);

    unless ( $self->comainu->{debug} ) {
        do { unlink $_ if -f $_; } for ($mecab_file, $kc_lout_file, $kc_bout_file);
    }

    return 0;
}


1;
