package t::Comainu::Method::Bccwj2midout;
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
    use_ok 'Comainu::Method::Bccwj2midout';
}

# sub run : Tests {};
# sub analyze : Tests {};

sub dummy : Test(1) {
    ok 1;
}

__PACKAGE__->runtests;
