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

sub create_mstin : Test(1) {
    my $data = <<KCLONG;
*B
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * * *
の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
KCLONG

    my $g1 = mock_guard('Comainu::Feature' => {
        read_from_file => sub { $data },
    });
    my $mstin_data = '';
    my $g2 = guard_write_to_file('Comainu::Method::Kclong2midout', \$mstin_data);

    my $gold = <<GOLD;
1\t詰め\t詰める\t動詞\t動詞-一般\t下一段|下一段-マ行|連用形|連用形-一般\t0\t_\t_
2\t将棋\t将棋\t名詞\t名詞-普通名詞-一般\t名詞-普通名詞\t0\t_\t_

GOLD

    my $kclong2midout = Comainu::Method::Kclong2midout->new;
    $kclong2midout->create_mstin('t/sample/test.KC', 't/sample/test.KC.mstin');

    is $mstin_data, $gold;
}

# sub parse_muw : Tests {};
# sub merge_mst_result : Tests {};

sub dummy : Test(1) {
    ok 1;
}

__PACKAGE__->runtests;
