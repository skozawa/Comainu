package t::Comainu::Util;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

use Comainu;
use Comainu::Util qw(
    proc_stdin2stdout
    proc_stdin2file
    proc_file2file
);

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::Util';
}

# sub _check_file : Tests {};
# sub _read_from_file : Tests {};
# sub _write_to_file : Tests {};

sub _proc_stdin2stdout : Test(1) {
    my $comainu = Comainu->new;
    is proc_stdin2stdout('cat', 'test', $comainu->{"comainu-temp"}), 'test';
};

sub _proc_stdin2file : Test(1) {
    my $outfile = create_tmp_file("");
    proc_stdin2file('cat', 'test', $outfile);

    open(IN, $outfile);
    my $out_data = "";
    while (<IN>) {
        chomp;
        $out_data .= $_ . "\n";
    }
    close(IN);

    is $out_data, "test\n";
};

sub _proc_file2file : Test(1) {
    my $infile  = create_tmp_file("test");
    my $outfile = create_tmp_file("");

    my $comainu = Comainu->new;
    proc_file2file('cat', $infile, $outfile);

    open(IN, $outfile);
    my $out_data = "";
    while (<IN>) {
        chomp;
        $out_data .= $_ . "\n";
    }
    close(IN);

    is $out_data, "test\n";
};



__PACKAGE__->runtests;
