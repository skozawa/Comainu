package t::Comainu::Method::Kc2bnsteval;
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
    use_ok 'Comainu::Method::Kc2bnsteval';
}

# sub run : Tests {};
# sub evaluate : Tests {};
# sub _compare : Tests {};

sub short2bnst : Test(1) {
    my $data = <<BOUT;
B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 動詞 一般 * * 下一段 マ行 * 連用形 一般 * O
I 将棋 ショウギ 将棋 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * O
I の ノ の 助詞-格助詞 * * 助詞 格助詞 * * * * * * * * O
B 本 ホン 本 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * O
I を ヲ を 助詞-格助詞 * * 助詞 格助詞 * * * * * * * * O
B 買っ カウ 買う 動詞-一般 五段-ワア行-一般 連用形-促音便 動詞 一般 * * 五段 ワア行 一般 連用形 促音便 * O
I て テ て 助詞-接続助詞 * * 助詞 接続助詞 * * * * * * * * O
B き クル 来る 動詞-非自立可能 カ行変格 連用形-一般 動詞 非自立可能 * * カ行変格 * * 連用形 一般 * O
I まし マス ます 助動詞 助動詞-マス 連用形-一般 助動詞 * * * 助動詞 マス * 連用形 一般 * O
I た タ た 助動詞 助動詞-タ 終止形-一般 助動詞 * * * 助動詞 タ * 終止形 一般 * O
I 。 * 。 補助記号-句点 * * 補助記号 句点 * * * * * * * * O
BOUT

    my $kc2bnsteval = Comainu::Method::Kc2bnsteval->new;
    is $kc2bnsteval->short2bnst($data), "詰め将棋の\n本を\n買って\nきました。";
};


__PACKAGE__->runtests;
