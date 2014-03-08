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

# Analyze middle-unit-word
sub usage {
    my $self = shift;
    while ( <DATA> ) {
        print $_;
    }
}

sub run {
    my ($self, $test_kc, $save_dir) = @_;

    $self->before_analyze({
        dir => $save_dir, muwmodel => $self->{muwmodel}
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

    $self->create_mstin($tmp_test_kc, $mstin_file);
    $self->parse_muw($mstin_file, $mstout_file);
    my $buff = Comainu::Format->merge_kc_with_mstout($test_kc, $mstout_file);
    $self->output_result($buff, $save_dir, basename($test_kc) . ".mout");
    undef $buff;

    unlink $tmp_test_kc if !$self->{debug} && -f $tmp_test_kc;
    unlink $mstout_file if !$self->{debug} && -f $mstout_file;

    return 0;
}

# create test data for MST Parser
sub create_mstin {
    my ($self, $test_kc, $mstin_file) = @_;
    print STDERR "# CREATE MSTIN\n";

    my $buff = Comainu::Feature->create_mst_feature($test_kc);
    write_to_file($mstin_file, $buff);
    undef $buff;

    return 0;
}

# analyze middle-unit-word using MST Parser
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
    # input file is empty
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


1;


__DATA__
COMAINU-METHOD: kclong2midout
  Usage: ./script/comainu.pl kclong2midout [options]
    This command analyzes middle-unit-word of <input>(file or STDIN) with <muwmodel>

  option
    --help                    show this message and exit
    --input                   specify input file or directory
    --output-dir              specify output directory
    --muwmodel                specify the middle-unit-word model (default: train/MST/train.KC.model)

  ex.)
  $ perl ./script/comainu.pl kclong2midout
  $ perl ./script/comainu.pl kclong2midout --input=sample/sample_mid.KC --output-dir=out
    -> out/sample_mid.KC.mout

