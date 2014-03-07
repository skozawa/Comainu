package Comainu::Method::Kclong2midout;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename);
use Config;

use Comainu::Util qw(read_from_file write_to_file);
use Comainu::Format;
use Comainu::Feature;

sub new {
    my ($class, %args) = @_;
    $class->SUPER::new( %args, args_num => 3 );
}

# 中単位解析
# 解析対象KCファイル、モデルファイルを用いて、
# 解析対象KCファイルに中単位を付与する。
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: kclong2midout\n");
    printf("  Usage: %s kclong2midout (--muwmodel=<mid-model-file>) <test-kc> <out-dir>\n", $0);
    printf("    This command analyzes <test-kc> with <mid-model-file>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  \$ perl ./script/comainu.pl kclong2midout sample/sample.KC out\n");
    printf("    -> out/sample.KC.mout\n");
    printf("  \$ perl ./script/comainu.pl kclong2midout --muwmodel=train/MST/train.KC.model sample/sample.KC out\n");
    printf("    -> out/sample.KC.mout\n");
    printf("\n");
}

sub run {
    my ($self, $test_kc, $save_dir) = @_;

    $self->before_analyze({
        dir => $save_dir, muwmodel => $self->{muwmodel}, args_num => scalar @_
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

    my $basename = basename($tmp_test_kc, ".KC");
    my $mstin_file  = $self->{"comainu-temp"} . "/" . $basename . ".mstin";
    my $mstout_file = $self->{"comainu-temp"} . "/" . $basename . ".mstout";
    my $mout_file   = $save_dir . "/" . basename($test_kc) . ".mout";

    $self->create_mstin($tmp_test_kc, $mstin_file);
    $self->parse_muw($mstin_file, $mstout_file);
    $self->merge_mst_result($tmp_test_kc, $mstout_file, $mout_file);

    unlink $tmp_test_kc if !$self->{debug} && -f $tmp_test_kc;
}

# 中単位解析(MST)用のデータを作成
sub create_mstin {
    my ($self, $test_kc, $mstin_file) = @_;
    print STDERR "# CREATE MSTIN\n";

    my $buff = Comainu::Feature->create_mst_feature($test_kc);
    write_to_file($mstin_file, $buff);
    undef $buff;

    return 0;
}

# mstparserを利用して中単位解析
sub parse_muw {
    my ($self, $mstin_file, $mstout_file) = @_;
    print STDERR "# PARSE MUW\n";

    my $java = $self->{"java"};
    my $mstparser_dir = $self->{"mstparser-dir"};

    my $mst_classpath = $mstparser_dir . "/output/classes:" . $mstparser_dir . "/lib/trove.jar";
    my $memory = "-Xmx1800m";
    my $muwmodel = $self->{muwmodel};
    if ( $Config{osname} eq "MSWin32" ) {
        $mst_classpath = $mstparser_dir . "/output/classes;" . $mstparser_dir . "/lib/trove.jar";
        $memory = "-Xmx1000m";
        # remove drive letter for MS-Windows
        $muwmodel    =~ s/^[a-zA-Z]\://;
        $mstin_file  =~ s/^[a-zA-Z]\://;
        $mstout_file =~ s/^[a-zA-Z]\://;
    }
    ## 入力ファイルが空だった場合
    if ( -z $mstin_file ) {
    	write_to_file($mstout_file, "");
    	return 0;
    }
    my $cmd = sprintf("\"%s\" -classpath \"%s\" %s mstparser.DependencyParser test model-name:\"%s\" test-file:\"%s\" output-file:\"%s\" order:1",
                      $java, $mst_classpath, $memory, $muwmodel, $mstin_file, $mstout_file);
    print STDERR $cmd,"\n" if $self->{debug};
    system($cmd);

    unlink $mstin_file if !$self->{debug} && -f $mstin_file;

    return 0;
}

sub merge_mst_result {
    my ($self, $test_kc, $mstout_file, $mout_file) = @_;
    print STDERR "# MERGE RESULT\n";
    my $ret = 0;

    my $buff = Comainu::Format->merge_kc_with_mstout($test_kc, $mstout_file);
    write_to_file($mout_file, $buff);
    undef $buff;

    unlink $mstout_file if !$self->{debug} && -f $mstout_file;

    return $ret;
}


1;
