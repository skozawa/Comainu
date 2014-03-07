package t::Comainu::Method::Kc2bnstout;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::Method::Kc2bnstout';
}

# sub METHOD_kc2bnstout : Tests {};
# sub kc2bnstout_internal : Tests {};

sub format_bnstdata : Test(2) {
    subtest 'boundary sentence' => sub {
        my $kc2bnstout = Comainu::Method::Kc2bnstout->new(boundary => "sentence");

        my $svmdata = "";
        my $g = guard_write_to_file('Comainu::Method::Kc2bnstout', \$svmdata);

        $kc2bnstout->format_bnstdata("t/sample/test.KC", 't/sample/kc2bnstout/test.KC.svmdata');

        is $svmdata, read_from_file("t/sample/kc2bnstout/test.KC.svmdata.sentence");
    };

    subtest 'with_luw' => sub {
        my $kc2bnstout = Comainu::Method::Kc2bnstout->new(
            boundary => "sentence",
            bnst_process => 'with_luw',
            "comainu-temp" => 't/sample/kc2bnstout',
            debug => 1,
        );

        my $svmdata = "";
        my $g = guard_write_to_file('Comainu::Method::Kc2bnstout', \$svmdata);

        $kc2bnstout->format_bnstdata("t/sample/test.KC", 't/sample/kc2bnstout/test.KC.svmdata');

        is $svmdata, read_from_file("t/sample/kc2bnstout/test.KC.svmdata.with_luw");
    };
};

sub chunk_bnst : Test(1) {
    my $kc2bnstout = Comainu::Method::Kc2bnstout->new(
        boundary => 'sentence',
        debug    => 1,
    );

    my $bout_data = "";
    my $g1 = guard_write_to_file('Comainu::Method::Kc2bnstout', \$bout_data);
    my $g2 = mock_guard('Comainu::Method::Kc2bnstout', {
        proc_file2stdout => sub { read_from_file('t/sample/kc2bnstout/test.KC.svmdata.system') },
    });

    $kc2bnstout->chunk_bnst('t/sample/kc2bnstout/test.KC.svmdata.system', 't/sample/kc2bnstout/test.KC.bout');

    is $bout_data, read_from_file('t/sample/kc2bnstout/test.KC.bout.bnst_gold');
}

# sub merge_chunk_result : Tests {}

__PACKAGE__->runtests;
