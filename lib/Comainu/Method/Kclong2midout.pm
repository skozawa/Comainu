package Comainu::Method::Kclong2midout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Util qw(read_from_file write_to_file);

sub new {
    my ($class, %args) = @_;
    bless {
        args_num => 4,
        comainu  => delete $args{comainu},
        %args
    }, $class;
}

# 中単位解析
# 解析対象KCファイル、モデルファイルを用いて、
# 解析対象KCファイルに中単位を付与する。
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: kclong2midout\n");
    printf("  Usage: %s kclong2midout <test-kc> <mid-model-file> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <mid-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl kclong2midout sample/sample.KC train/MST/train.KC.model out\n");
    printf("    -> out/sample.KC.mout\n");
    printf("\n");
}

sub run {
    my ($self, $test_kc, $muwmodel, $save_dir) = @_;

    $self->before_analyze(scalar @_, $save_dir);
    $self->comainu->check_file($muwmodel);

    $self->analyze_files($test_kc, $muwmodel, $save_dir);

    return 0;
}

sub analyze {
    my ($self, $test_kc, $muwmodel, $save_dir) = @_;

    my $tmp_test_kc = $self->comainu->{"comainu-temp"} . "/" . basename($test_kc);
    $self->comainu->format_inputdata($test_kc, $tmp_test_kc, 'input-kc', 'kc');
    $self->_create_mstin($tmp_test_kc);
    $self->_parse_muw($tmp_test_kc, $muwmodel);
    $self->_merge_mst_result($tmp_test_kc, $save_dir);

    unlink $tmp_test_kc if !$self->comainu->{debug} && -f $tmp_test_kc;
}

# 中単位解析(MST)用のデータを作成
sub _create_mstin {
    my ($self, $test_kc) = @_;
    print STDERR "# CREATE MSTIN\n";

    my $output_file = $self->comainu->{"comainu-temp"} . "/" .
        basename($test_kc, ".KC") . ".mstin";

    my $buff = read_from_file($test_kc);
    $buff = $self->comainu->kc2mstin($buff);

    write_to_file($output_file, $buff);
    undef $buff;

    return 0;
}

# mstparserを利用して中単位解析
sub _parse_muw {
    my ($self, $test_kc, $muwmodel) = @_;
    print STDERR "# PARSE MUW\n";

    my $java = $self->comainu->{"java"};
    my $mstparser_dir = $self->comainu->{"mstparser-dir"};

    my $basename = basename($test_kc, ".KC");
    my $mstin = $self->comainu->{"comainu-temp"} . "/" . $basename . ".mstin";
    my $output_file = $self->comainu->{"comainu-temp"} . "/" . $basename . ".mstout";

    my $mst_classpath = $mstparser_dir."/output/classes:".$mstparser_dir."/lib/trove.jar";
    my $memory = "-Xmx1800m";
    if ( $Config{osname} eq "MSWin32" ) {
        $mst_classpath = $mstparser_dir."/output/classes;".$mstparser_dir."/lib/trove.jar";
        $memory = "-Xmx1000m";
        # remove drive letter for MS-Windows
        $muwmodel =~ s/^[a-zA-Z]\://;
        $mstin =~ s/^[a-zA-Z]\://;
        $output_file =~ s/^[a-zA-Z]\://;
    }
    ## 入力ファイルが空だった場合
    if ( -z $mstin ) {
    	write_to_file($output_file, "");
    	return 0;
    }
    my $cmd = sprintf("\"%s\" -classpath \"%s\" %s mstparser.DependencyParser test model-name:\"%s\" test-file:\"%s\" output-file:\"%s\" order:1",
                      $java, $mst_classpath, $memory, $muwmodel, $mstin, $output_file);
    print STDERR $cmd,"\n" if $self->comainu->{debug};
    system($cmd);

    unlink $mstin if !$self->comainu->{debug} && -f $mstin;

    return 0;
}

sub _merge_mst_result {
    my ($self, $test_kc, $save_dir) = @_;
    print STDERR "# MERGE RESULT\n";
    my $ret = 0;

    my $mstout_file = $self->comainu->{"comainu-temp"} . "/" .
        basename($test_kc, ".KC") . ".mstout";
    my $output_file = $save_dir . "/" . basename($test_kc) . ".mout";

    my $buff = $self->comainu->merge_kc_with_mstout($test_kc, $mstout_file);
    write_to_file($output_file, $buff); undef $buff;

    unlink $mstout_file if !$self->comainu->{debug} && -f $mstout_file;

    return $ret;
}


1;
