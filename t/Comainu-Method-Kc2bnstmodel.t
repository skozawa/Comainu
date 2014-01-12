package t::Comainu::Method::Kc2bnstmodel;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::Method::Kc2bnstmodel';
}

# sub run : Tests {};

sub create_svmin : Test(1) {
    my $svmin_data = "";
    my $g1 = guard_write_to_file('Comainu::Method::Kc2bnstmodel', \$svmin_data);

    my $kc2bnstmodel = Comainu::Method::Kc2bnstmodel->new;
    $kc2bnstmodel->create_svmin('t/sample/test.KC', 't/sample/kc2bnstmodel/test.KC.svmin');

    is $svmin_data, read_from_file('t/sample/kc2bnstmodel/test.KC.svmin.gold');
}

__PACKAGE__->runtests;
