package t::Comainu::Method::Kc2longout;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

use Comainu;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::Method::Kc2longout';
}

sub _create_features : Test(3) {
    my $g = mock_guard("AddFeature", {
        load_dic => sub { {}; },
    });

    my $kc2_data = "";
    my $g = guard_write_to_file('Comainu::Method::Kc2longout', \$kc2_data);

    subtest "sentence boundary" => sub {
        my $comainu = Comainu->new(boundary => "sentence");
        my $kc2longout = Comainu::Method::Kc2longout->new(comainu => $comainu);
        $kc2longout->_create_features("t/sample/test.KC", "t/sample/test.model");
        is $kc2_data, read_from_file('t/sample/test.KC2');
    };

    subtest "word boundary" => sub {
        my $comainu = Comainu->new(boundary => "word");
        my $kc2longout = Comainu::Method::Kc2longout->new(comainu => $comainu);
        $kc2longout->_create_features("t/sample/test.KC", "t/sample/test.model");
        is $kc2_data, read_from_file('t/sample/test.KC2.word');
    };

    subtest "none boundary" => sub {
        my $comainu = Comainu->new(boundary => "none");
        my $kc2longout = Comainu::Method::Kc2longout->new(comainu => $comainu);
        $kc2longout->_create_features("t/sample/test.KC", "t/sample/test.model");
        is $kc2_data, read_from_file('t/sample/test.KC2.none');
    };
};

sub _chunk_luw : Test(1) {
    my $comainu = Comainu->new(
        boundary => "sentence",
        "comainu-temp" => "t/sample",
    );
    my $kc2longout = Comainu::Method::Kc2longout->new(comainu => $comainu);

    my $svmout_data = "";
    my $g1 = guard_write_to_file('Comainu::Method::Kc2longout', \$svmout_data);
    my $g2 = mock_guard('Comainu', {
        proc_stdin2stdout => sub { read_from_file('t/sample/test.KC.svm.output') },
    });

    $kc2longout->_chunk_luw('t/sample/test.KC', 't/sample/test.KC.model');

    is $svmout_data, read_from_file('t/sample/test.KC.svmout.gold');
};

# sub merge_chunk_result : Tests {};
# sub post_process : Tests {};


__PACKAGE__->runtests;
