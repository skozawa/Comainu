package t::Comainu::Method::Kc2longmodel;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::Method::Kc2longmodel';
}

# sub run : Tests {};
# sub _make_luw_traindata : Tests {};
# sub _add_luw_label : Tests {};
# sub _train_luwmodel_svm : Tests {};
# sub _train_luwmodel_crf : Tests {};
# sub _train_bi_model : Tests {};


sub dummy : Test(1) {
    ok 1;
}

__PACKAGE__->runtests;
