package t::Comainu::Method::Kclong2midout;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::Method::Kclong2midout';
}

# sub METHOD_kclong2midout : Tests {};
# sub kclong2midout_internal : Tests {};
# sub create_mstin : Tests {};
# sub parse_muw : Tests {};
# sub merge_mst_result : Tests {};

sub dummy : Test(1) {
    ok 1;
}

__PACKAGE__->runtests;
