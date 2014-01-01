# 文節境界解析
# 解析対象KCファイルとモデルファイルを用いて解析対象ファイルに文節境界を付与する。
package Comainu::Method::Kc2bnstout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Util qw(read_from_file write_to_file check_file proc_stdin2stdout);
use Comainu::Format;

sub new {
    my ($class, %args) = @_;
    $class->SUPER::new( %args, args_num => 4 );
}

sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: kc2bnstout\n");
    printf("  Usage: %s kc2bnstout <test-kc> <bnst-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <bnst-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl kc2bnstout sample/sample.KC train/bnst.model out\n");
    printf("    -> out/sample.KC.bout\n");
    printf("\n");
}

sub run {
    my ($self, $test_kc, $bnstmodel, $save_dir) = @_;

    $self->before_analyze({
        dir => $save_dir, bnstmodel => $bnstmodel, args_num => scalar @_
    });

    $self->analyze_files($test_kc, $bnstmodel, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_kc, $bnstmodel, $save_dir) = @_;

    my $tmp_test_kc = $self->{"comainu-temp"} . "/" . basename($test_kc);
    Comainu::Format->format_inputdata({
        input_file       => $test_kc,
        input_type       => 'input-kc',
        output_file      => $tmp_test_kc,
        output_type      => 'kc',
        data_format_file => $self->{data_format},
    });
    $self->format_bnstdata($tmp_test_kc);
    $self->chunk_bnst($tmp_test_kc, $bnstmodel, $save_dir);

    unlink $tmp_test_kc if !$self->{debug} && -f $tmp_test_kc;
}


# 文節解析用の形式に変換
sub format_bnstdata {
    my ($self, $tmp_test_kc) = @_;
    print STDERR "# FORMAT FOR BNSTDATA\n";

    my $basename = basename($tmp_test_kc);
    my $output_file = $self->{"comainu-temp"} . "/" . $basename . ".svmdata";
    # すでに同じ名前の中間ファイルがあれば削除
    unlink $output_file if -s $output_file;

    my $buff = read_from_file($tmp_test_kc);
    $buff = Comainu::Format->kc2bnstsvmdata($buff, 0);

    if ( $self->{bnst_process} eq "with_luw" ) {
        ## 長単位解析の出力結果
        my $svmout_file = $self->{"comainu-temp"} . "/" . $basename . ".svmout";
        $buff = Comainu::Format->pp_partial_bnst_with_luw($buff, $svmout_file);
        unlink $svmout_file if !$self->{debug} && -f $svmout_file;
    } elsif ( $self->{boundary} ne "none" ) {
        $buff = Comainu::Format->pp_partial($buff, {
            is_bnst  => 1,
            boundary => $self->{boundary},
        });
    }

    write_to_file($output_file, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink $output_file unless -s $output_file;

    return 0;
}

# yamchaを利用して文節境界解析
sub chunk_bnst {
    my ($self, $tmp_test_kc, $bnstmodel, $save_dir) = @_;
    print STDERR "# CHUNK BNST\n";
    my $yamcha_opt = "";
    if ($self->{"boundary"} eq "sentence" || $self->{"boundary"} eq "word") {
        # sentence/word boundary
        $yamcha_opt = "-C";
    }
    my $ret = 0;

    my $YAMCHA = $self->{"yamcha-dir"}."/yamcha";
    $YAMCHA .= ".exe" if $Config{osname} eq "MSWin32";
    unless ( -x $YAMCHA ) {
        printf(STDERR "WARNING: %s Not Found or executable.\n", $YAMCHA);
        exit 0;
    }

    my $basename = basename($tmp_test_kc);
    my $svmdata_file = $self->{"comainu-temp"} . "/" . $basename . ".svmdata";
    my $output_file = $save_dir . "/" . $basename . ".bout";
    # すでに同じ名前の中間ファイルがあれば削除
    unlink $output_file if -s $output_file;

    check_file($svmdata_file);

    my $buff = read_from_file($svmdata_file);
    # YAMCHA用に明示的に最終行に改行を付けさせる
    $buff .= "\n";

    my $yamcha_com = "\"".$YAMCHA."\" ".$yamcha_opt." -m \"".$bnstmodel."\"";
    printf(STDERR "# YAMCHA_COM: %s\n", $yamcha_com) if $self->{debug};

    $buff = proc_stdin2stdout($yamcha_com, $buff, $self->{"comainu-temp"});
    $buff =~ s/\x0d\x0a/\x0a/sg;
    $buff =~ s/^\r?\n//mg;
    $buff = Comainu::Format->move_future_front($buff);
    write_to_file($output_file, $buff);

    $buff = Comainu::Format->merge_kc_with_bout($tmp_test_kc, $output_file);
    write_to_file($output_file, $buff);
    undef $buff;

    # 不十分な中間ファイルならば、削除しておく
    unlink $output_file unless -s $output_file;

    unlink $svmdata_file if !$self->{debug} && -f $svmdata_file;

    return $ret;
}


1;
