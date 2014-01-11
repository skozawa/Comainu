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

sub _make_luw_traindata : Tests {
    my $buff = <<DATA;
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * * *
の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
*B
本 ホン 本 名詞-普通名詞-一般 * * ホン ホン 本 本 * * 漢 名詞-普通名詞-一般 * * ホン 本 本
を ヲ を 助詞-格助詞 * * ヲ ヲ を を * * 和 助詞-格助詞 * * ヲ を を
*B
買っ カウ 買う 動詞-一般 五段-ワア行-一般 連用形-促音便 カッ カウ 買う 買っ * * 和 動詞-一般 五段-ワア行-一般 連用形-促音便 カウ 買う 買っ
て テ て 助詞-接続助詞 * * テ テ て て * * 和 助詞-接続助詞 * * テ て て
*B
き クル 来る 動詞-非自立可能 カ行変格 連用形-一般 キ クル 来る 来 * * 和 動詞-一般 カ行変格 連用形-一般 クル 来る き
まし マス ます 助動詞 助動詞-マス 連用形-一般 マシ マス ます まし * * 和 助動詞 助動詞-マス 連用形-一般 マス ます まし
た タ た 助動詞 助動詞-タ 終止形-一般 タ タ た た * * 和 助動詞 助動詞-タ 終止形-一般 タ た た
。 * 。 補助記号-句点 * * * * 。 。 * * 記号 補助記号-句点 * * * 。 。
DATA

    my $g = mock_guard(
        'Comainu::Feature' => {
            read_from_file => sub { $buff },
        },
    );
    my $kc2_data = '';
    my $g2 = guard_write_to_file('Comainu::Method::Kc2longmodel', \$kc2_data);

    my $kc2longmodel = Comainu::Method::Kc2longmodel->new;
    $kc2longmodel->make_luw_traindata('', '');
    my @lines = split /\n/, $kc2_data;

    is $lines[0], "詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 一般 * * 下一段 マ行 * 連用形 一般 * B";
    is $lines[1], "将棋 ショウギ 将棋 名詞-普通名詞-一般 * * * * 漢 名詞 普通名詞 一般 * * * * * * * Ia";
    is $lines[2], "の ノ の 助詞-格助詞 * * * * 和 助詞 格助詞 * * * * * * * * Ba";
    is $lines[3], "本 ホン 本 名詞-普通名詞-一般 * * * * 漢 名詞 普通名詞 一般 * * * * * * * Ba";
    is $lines[4], "を ヲ を 助詞-格助詞 * * * * 和 助詞 格助詞 * * * * * * * * Ba";
    is $lines[5], "買っ カウ 買う 動詞-一般 五段-ワア行-一般 連用形-促音便 * * 和 動詞 一般 * * 五段 ワア行 一般 連用形 促音便 * Ba";
    is $lines[6], "て テ て 助詞-接続助詞 * * * * 和 助詞 接続助詞 * * * * * * * * Ba";
    is $lines[7], "き クル 来る 動詞-非自立可能 カ行変格 連用形-一般 * * 和 動詞 非自立可能 * * カ行変格 * * 連用形 一般 * B";
    is $lines[8], "まし マス ます 助動詞 助動詞-マス 連用形-一般 * * 和 助動詞 * * * 助動詞 マス * 連用形 一般 * Ba";
    is $lines[9], "た タ た 助動詞 助動詞-タ 終止形-一般 * * 和 助動詞 * * * 助動詞 タ * 終止形 一般 * Ba";
    is $lines[10], "。 * 。 補助記号-句点 * * * * 記号 補助記号 句点 * * * * * * * * Ba";
};

# sub _add_luw_label : Tests {};
# sub _train_luwmodel_svm : Tests {};
# sub _train_luwmodel_crf : Tests {};
# sub _train_bi_model : Tests {};


__PACKAGE__->runtests;
