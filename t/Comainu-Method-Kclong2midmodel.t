package t::Comainu::Method::Kclong2midmodel;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::Method::Kclong2midmodel';
}

# sub run : Tests {};

sub create_mid_traindata : Test(1) {
    my $data = <<KCLONG;
*B
近 キン 近 接頭辞 * * キン キン 近 近 * * 漢 名詞-普通名詞-一般 * * キンミライレーシングゲーム 近未来レーシングゲーム 近未来レーシングゲーム 1 0 近未来
未来 ミライ 未来 名詞-普通名詞-一般 * * ミライ ミライ 未来 未来 * * 漢 * * * * * * 3 0
レーシング レーシング レーシング 名詞-普通名詞-一般 * * レーシング レーシング レーシング レーシング * * 外 * * * * * * 3 1 レーシングゲーム
ゲーム ゲーム ゲーム 名詞-普通名詞-一般 * * ゲーム ゲーム ゲーム ゲーム * * 外 * * * * * * * 1
EOS
KCLONG

    my $g1 = mock_guard('Comainu::Feature' => { read_from_file => sub { $data } });
    my $mstin_data = '';
    my $g2 = guard_write_to_file('Comainu::Method::Kclong2midmodel', \$mstin_data);

    my $gold = <<GOLD;
1\t近\t近\t接頭辞\t接頭辞\t_\t2\t_\t_
2\t未来\t未来\t名詞\t名詞-普通名詞-一般\t名詞-普通名詞\t4\t_\t_
3\tレーシング\tレーシング\t名詞\t名詞-普通名詞-一般\t名詞-普通名詞\t4\t_\t_
4\tゲーム\tゲーム\t名詞\t名詞-普通名詞-一般\t名詞-普通名詞\t0\t_\t_

GOLD

    my $kclong2midmodel = Comainu::Method::Kclong2midmodel->new;
    $kclong2midmodel->create_mid_traindata('t/sample/test.KC', 't/sample/test.KC.mstin');

    is $mstin_data, $gold;
};


__PACKAGE__->runtests;
