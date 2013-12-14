package t::Comainu::Method::Kc2bnstout;
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
    use_ok 'Comainu::Method::Kc2bnstout';
}

# sub METHOD_kc2bnstout : Tests {};
# sub kc2bnstout_internal : Tests {};
sub _format_bnstdata : Test(1) {
    my $comainu = Comainu->new(boundary => "sentence");
    my $kc2bnstout = Comainu::Method::Kc2bnstout->new(comainu => $comainu);

    my $svmdata = "";
    my $g = guard_write_to_file('Comainu::Method::Kc2bnstout', \$svmdata);

    $kc2bnstout->_format_bnstdata("t/sample/test.KC");

    is $svmdata, read_from_file("t/sample/test.KC.bnst.svmdata");
};
# sub chunk_bnst : Tests {}


__PACKAGE__->runtests;
