package t::Comainu::Method::Bccwjlong2midout;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::Method::Bccwjlong2midout';
}

# sub run : Tests {};
# sub analyze : Tests {};

sub dummy : Test(1) {
    ok 1;
}

__PACKAGE__->runtests;
