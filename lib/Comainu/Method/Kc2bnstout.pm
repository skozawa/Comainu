# 文節境界解析
# 解析対象KCファイルとモデルファイルを用いて解析対象ファイルに文節境界を付与する。
package Comainu::Method::Kc2bnstout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Util qw(read_from_file write_to_file check_file proc_file2stdout);
use Comainu::Feature;
use Comainu::Format;

# Analyze bunsetsu boudanry
sub usage {
    my $self = shift;
    while ( <DATA> ) {
        print $_;
    }
}

sub run {
    my ($self, $test_kc, $save_dir) = @_;

    $self->before_analyze({
        dir => $save_dir, bnstmodel => $self->{bnstmodel}
    });
    $self->analyze_files($test_kc, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_kc, $save_dir) = @_;

    my $tmp_test_kc = $self->{"comainu-temp"} . "/" . basename($test_kc);
    Comainu::Format->format_inputdata({
        input_file       => $test_kc,
        input_type       => 'input-kc',
        output_file      => $tmp_test_kc,
        output_type      => 'kc',
        data_format_file => $self->{data_format},
    });

    my $basename = basename($tmp_test_kc);
    my $svmdata_file  = $self->{"comainu-temp"} . "/" . $basename . ".svmdata";
    my $tmp_bout_file = $self->{"comainu-temp"} . "/" . $basename . ".tmp.bout";

    $self->format_bnstdata($tmp_test_kc, $svmdata_file);
    $self->chunk_bnst($svmdata_file, $tmp_bout_file);
    my $buff = Comainu::Format->merge_kc_with_bout($tmp_test_kc, $tmp_bout_file);

    $self->output_result($buff, $save_dir, $basename . ".bout");
    undef $buff;

    unlink $tmp_test_kc   if !$self->{debug} && -f $tmp_test_kc;
    unlink $tmp_bout_file if !$self->{debug} && -f $tmp_bout_file;

    return 0;
}


# 文節解析用の形式に変換
sub format_bnstdata {
    my ($self, $tmp_test_kc, $svmdata_file) = @_;
    print STDERR "# FORMAT FOR BNSTDATA\n";

    # すでに同じ名前の中間ファイルがあれば削除
    unlink $svmdata_file if -s $svmdata_file;

    my $buff = Comainu::Feature->create_bnstout_feature($tmp_test_kc);

    if ( $self->{bnst_process} eq "with_luw" ) {
        ## 長単位解析の出力結果
        my $basename = basename($tmp_test_kc);
        my $svmout_file = $self->{"comainu-temp"} . "/" . $basename . ".svmout";
        $buff = Comainu::Feature->pp_partial_bnst_with_luw($buff, $svmout_file);
        unlink $svmout_file if !$self->{debug} && -f $svmout_file;
    } elsif ( $self->{boundary} ne "none" ) {
        $buff = Comainu::Feature->pp_partial($buff, {
            is_bnst  => 1,
            boundary => $self->{boundary},
        });
    }

    # YAMCHA用に明示的に最終行に改行を付けさせる
    $buff .= "\n";
    write_to_file($svmdata_file, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink $svmdata_file unless -s $svmdata_file;
}

# yamchaを利用して文節境界解析
sub chunk_bnst {
    my ($self, $svmdata_file, $bout_file) = @_;
    print STDERR "# CHUNK BNST\n";
    my $yamcha_opt = "";
    if ($self->{"boundary"} eq "sentence" || $self->{"boundary"} eq "word") {
        # sentence/word boundary
        $yamcha_opt = "-C";
    }
    my $YAMCHA = $self->{"yamcha-dir"}."/yamcha";
    $YAMCHA .= ".exe" if $Config{osname} eq "MSWin32";
    unless ( -x $YAMCHA ) {
        printf(STDERR "WARNING: %s Not Found or executable.\n", $YAMCHA);
        exit 0;
    }

    # すでに同じ名前の中間ファイルがあれば削除
    unlink $bout_file if -s $bout_file;
    check_file($svmdata_file);

    my $yamcha_com = "\"".$YAMCHA."\" ".$yamcha_opt." -m \"".$self->{bnstmodel}."\"";
    printf(STDERR "# YAMCHA_COM: %s\n", $yamcha_com) if $self->{debug};

    my $buff = proc_file2stdout($yamcha_com, $svmdata_file, $self->{"comainu-temp"});
    $buff =~ s/\x0d\x0a/\x0a/sg;
    $buff =~ s/^\r?\n//mg;
    $buff = Comainu::Format->move_future_front($buff);
    write_to_file($bout_file, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink $bout_file unless -s $bout_file;

    unlink $svmdata_file if !$self->{debug} && -f $svmdata_file;
}


1;


__DATA__
COMAINU-METHOD: kc2bnstout [options]
  Usage: ./script/comainu.pl kc2bnstout
    This command analyzes the bunsetsu boundary with <bnstmodel>.

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --bnstmodel               specify the bnst model (default: train/bnst.model)

  ex.)
  $ perl ./script/comainu.pl kc2bnstout
  $ perl ./script/comainu.pl kc2longout --input=sample/sample.KC --output-dir=out
    -> out/sample.KC.bout
  $ perl ./script/comainu.pl kc2longout --bnstmodel=sample_train/sample.KC.model

