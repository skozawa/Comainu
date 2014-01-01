package t::Comainu::Method::Kc2longeval;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::Method::Kc2longeval';
}

# sub run : Tests {};
# sub evaluate : Tests {};
# sub _compare : Tests {};

sub short2long : Test(1) {
    my $data = <<LOUT;
B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋
Ia 将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * * *
Ba の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
Ba 本 ホン 本 名詞-普通名詞-一般 * * ホン ホン 本 本 * * 漢 名詞-普通名詞-一般 * * ホン 本 本
Ba を ヲ を 助詞-格助詞 * * ヲ ヲ を を * * 和 助詞-格助詞 * * ヲ を を
Ba 買っ カウ 買う 動詞-一般 五段-ワア行-一般 連用形-促音便 カッ カウ 買う 買っ * * 和 動詞-一般 五段-ワア行-一般 連用形-促音便 カウ 買う 買っ
Ba て テ て 助詞-接続助詞 * * テ テ て て * * 和 助詞-接続助詞 * * テ て て
B き クル 来る 動詞-非自立可能 カ行変格 連用形-一般 キ クル 来る 来 * * 和 動詞-一般 カ行変格 連用形-一般 クル 来る き
Ba まし マス ます 助動詞 助動詞-マス 連用形-一般 マシ マス ます まし * * 和 助動詞 助動詞-マス 連用形-一般 マス ます まし
Ba た タ た 助動詞 助動詞-タ 終止形-一般 タ タ た た * * 和 助動詞 助動詞-タ 終止形-一般 タ た た
Ba 。 * 。 補助記号-句点 * *   。 。 * * 記号 補助記号-句点 * *  。 。
EOS
LOUT

    my $gold = <<GOLD;
詰め将棋 ツメショウギ 詰め将棋 名詞-普通名詞-一般 * *
の ノ の 助詞-格助詞 * *
本 ホン 本 名詞-普通名詞-一般 * *
を ヲ を 助詞-格助詞 * *
買っ カウ 買う 動詞-一般 五段-ワア行-一般 連用形-促音便
て テ て 助詞-接続助詞 * *
き クル 来る 動詞-一般 カ行変格 連用形-一般
まし マス ます 助動詞 助動詞-マス 連用形-一般
た タ た 助動詞 助動詞-タ 終止形-一般
。 * 。 補助記号-句点 * *
GOLD

    my $kc2longeval = Comainu::Method::Kc2longeval->new;
    is $kc2longeval->short2long($data), $gold;
};


__PACKAGE__->runtests;
