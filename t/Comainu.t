package t::Comainu;
use strict;
use warnings;
use utf8;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

use Encode;
use File::Temp;

use Comainu;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu';
};


# sub METHOD_bccwj2longout : Tests {};
# sub bccwj2longout_internal : Tests {};
# sub METHOD_bccwj2bnstout : Tests {};
# sub bccwj2bnstout_internal : Tests {};
# sub METHOD_bccwj2longbnstout : Tests {};
# sub bccwj2longbnstout_internal : Tests {};
# sub METHOD_bccwj2midout : Tests {};
# sub bccwj2midout_internal : Tests {};
# sub METHOD_bccwj2midbnstout : Tests {};
# sub bccwj2midbnstout_internal : Tests {};
# sub METHOD_bccwjlong2midout : Tests {};
# sub bccwjlong2midout_internal : Tests {};

# sub METHOD_plain2longout : Tests {};
# sub plain2longout_internal : Tests {};
# sub METHOD_plain2bnstout : Tests {};
# sub plain2bnstout_internal : Tests {};
# sub METHOD_plain2longbnstout : Tests {};
# sub plain2longbnstout_internal : Tests {};
# sub METHOD_plain2midout : Tests {};
# sub plain2midout_internal : Tests {};
# sub METHOD_plain2midbnstout : Tests {};
# sub plain2midbnstout_internal : Tests {};

# sub plain2mecab_file : Tests {};
# sub mecab2kc_file : Tests {};

# sub METHOD_kc2longmodel : Tests {};
# sub make_luw_traindata : Tests {};
# sub add_luw_label : Tests {};
# sub train_luwmodel_svm : Tests {};
# sub train_luwmodel_crf : Tests {};
# sub train_bi_model : Tests {};

# sub METHOD_kc2bnstmodel : Tests {};
# sub train_bnstmodel : Tests {};
# sub add_bnst_label : Tests {};

# sub METHOD_kclong2midmodel : Tests {};
# sub create_mid_traindata : Tests {};
# sub train_midmodel : Tests {};

# sub METHOD_kc2longeval : Tests {};
# sub kc2longeval_internal : Tests {};
# sub compare : Tests {};

# sub METHOD_kc2bnsteval : Tests {};
# sub kc2bnsteval_internal : Tests {};
# sub compare_bnst : Tests {};

# sub METHOD_kclong2mideval : Tests {};
# sub kclong2mideval_internal : Tests {};
# sub compare_mid : Tests {};

# sub eval_long : Tests {};
# sub diff_perl : Tests {};

sub create_long_lemma : Test(4) {
    my $comainu = Comainu->new;
    my $comp_file = "t/sample/Comp.txt";

    subtest "create_long_lemma" => sub {
        my $data = <<DATA;
Ba ミスター ミスター ミスター 名詞-普通名詞-一般 * * ミスター ミスター ミスター ミスター * * 外 名詞-普通名詞-一般 * * ミスター ミスター ミスター
Ba の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
Ba 「 * 「 補助記号-括弧開 * *   「 「 * * 記号 補助記号-括弧開 * * 「 「 「
B 甘い アマイ 甘い 形容詞-一般 形容詞 連体形-一般 アマイ アマイ 甘い 甘い * * 和 名詞-普通名詞-一般 * * アマイモノギライ 甘い物嫌い 甘いもの嫌い
I もの モノ 物 名詞-普通名詞-サ変可能 * * モノ モノ 物 物 * * 和 * * * * * *
I 嫌い キライ 嫌い 名詞-普通名詞-形状詞可能 * * ギライ キライ 嫌い 嫌い * * 和 * * * * * *
Ba 」 * 」 補助記号-括弧閉 * *   」 」 * * 記号 補助記号-括弧閉 * * 」 」 」
Ba は ハ は 助詞-係助詞 * * ハ ハ は は * * 和 助詞-係助詞 * * ハ は は
Ba キャラ作り キャラヅクリ キャラ作り 名詞-普通名詞-一般 * * キャラヅクリ キャラヅクリ キャラ作り キャラ作り * * 混 名詞-普通名詞-一般 * * キャラヅクリ キャラ作り キャラ作り
Ba だ ダ だ 助動詞 助動詞-ダ 終止形-一般 ダ ダ だ だ * * 和 助動詞 助動詞-ダ 終止形-一般 ダ だ だ
B と ト と 助詞-格助詞 * * ト ト と と * * 和 助詞-格助詞 * * トイウ という という
I いう イウ 言う 動詞-一般 五段-ワア行-イウ 連体形-一般 イウ イウ 言う 言う * * 和 * * * * * *
B 噂 ウワサ 噂 名詞-普通名詞-サ変可能 * * ウワサ ウワサ 噂 噂 * * 和 名詞-普通名詞-一般 * * ウワサ 噂 噂
Ba も モ も 助詞-係助詞 * * モ モ も も * * 和 助詞-係助詞 * * モ も も
Ba 。 * 。 補助記号-句点 * *   。 。 * * 記号 補助記号-句点 * *  。 。
EOS
DATA

        my $gold = <<GOLD;
Ba ミスター ミスター ミスター 名詞-普通名詞-一般 * * ミスター ミスター ミスター ミスター * * 外 名詞-普通名詞-一般 * * ミスター ミスター ミスター
Ba の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
Ba 「 * 「 補助記号-括弧開 * *   「 「 * * 記号 補助記号-括弧開 * *  「 「
B 甘い アマイ 甘い 形容詞-一般 形容詞 連体形-一般 アマイ アマイ 甘い 甘い * * 和 名詞-普通名詞-一般 * * アマイモノギライ 甘い物嫌い 甘いもの嫌い
I もの モノ 物 名詞-普通名詞-サ変可能 * * モノ モノ 物 物 * * 和 * * * * * *
I 嫌い キライ 嫌い 名詞-普通名詞-形状詞可能 * * ギライ キライ 嫌い 嫌い * * 和 * * * * * *
Ba 」 * 」 補助記号-括弧閉 * *   」 」 * * 記号 補助記号-括弧閉 * *  」 」
Ba は ハ は 助詞-係助詞 * * ハ ハ は は * * 和 助詞-係助詞 * * ハ は は
Ba キャラ作り キャラヅクリ キャラ作り 名詞-普通名詞-一般 * * キャラヅクリ キャラヅクリ キャラ作り キャラ作り * * 混 名詞-普通名詞-一般 * * キャラヅクリ キャラ作り キャラ作り
Ba だ ダ だ 助動詞 助動詞-ダ 終止形-一般 ダ ダ だ だ * * 和 助動詞 助動詞-ダ 終止形-一般 ダ だ だ
B と ト と 助詞-格助詞 * * ト ト と と * * 和 助詞-格助詞 * * トイウ という という
I いう イウ 言う 動詞-一般 五段-ワア行-イウ 連体形-一般 イウ イウ 言う 言う * * 和 * * * * * *
B 噂 ウワサ 噂 名詞-普通名詞-サ変可能 * * ウワサ ウワサ 噂 噂 * * 和 名詞-普通名詞-一般 * * ウワサ 噂 噂
Ba も モ も 助詞-係助詞 * * モ モ も も * * 和 助詞-係助詞 * * モ も も
Ba 。 * 。 補助記号-句点 * *   。 。 * * 記号 補助記号-句点 * *  。 。
EOS
GOLD

        is $comainu->create_long_lemma($data, $comp_file), $gold;
    };

    subtest "parential" => sub {
        my $data = <<DATA;
Ba テレビ テレビ テレビ 名詞-普通名詞-一般 * * テレビ テレビ テレビ テレビ * * 外 名詞-普通名詞-一般 * * テレビ テレビ テレビ
Ba で デ で 助詞-格助詞 * * デ デ で で * * 和 助詞-格助詞 * * デ で で
Ba は ハ は 助詞-係助詞 * * ハ ハ は は * * 和 助詞-係助詞 * * ハ は は
Ba 人気 ニンキ 人気 名詞-普通名詞-一般 * * ニンキ ニンキ 人気 人気 * * 漢 名詞-普通名詞-一般 * * ニンキコメディ「フレンズ」 人気コメディ「フレンズ」 人気コメディ「フレンズ」
I コメディ コメディー コメディー 名詞-普通名詞-一般 * * コメディ コメディ コメディ コメディ * * 外 * * * * * *
I 「 * 「 補助記号-括弧開 * * * * 「 「 * * 記号 * * * * * *
I フレンズ フレンド フレンド 名詞-普通名詞-一般 * * フレンズ フレンズ フレンズ フレンズ * * 外 * * * * * *
I 」 * 」 補助記号-括弧閉 * * * * 」 」 * * 記号 * * * * * *
Ba （ * （ 補助記号-括弧開 * * * * （ （ * * 記号 補助記号-括弧開 * * * （ （
Ba 二千 ニセン 二千 名詞-数詞 * * ニセン ニセン 二千 二千 * * 漢 名詞-数詞 * * ニセンネン 二千年 二千年
I 年 ネン 年 名詞-普通名詞-助数詞可能 * * ネン ネン 年 年 * * 漢 * * * * * *
Ba ） * ） 補助記号-括弧閉 * * * * ） ） * * 記号 補助記号-括弧閉 * * * ） ）
Ba に ニ に 助詞-格助詞 * * ニ ニ に に * * 和 助詞-格助詞 * * ニ に に
B ゲスト ゲスト ゲスト 名詞-普通名詞-一般 * * ゲスト ゲスト ゲスト ゲスト * * 外 動詞-一般 サ行変格 連用形-一般 ゲストシュツエンスル ゲスト出演する ゲスト出演し
I 出演 シュツエン 出演 名詞-普通名詞-サ変可能 * * シュツエン シュツエン 出演 出演 * * 漢 * * * * * *
I し スル 為る 動詞-非自立可能 サ行変格 連用形-一般 シ スル する する * * 和 * * * * * *
DATA

        my $gold = <<GOLD;
Ba テレビ テレビ テレビ 名詞-普通名詞-一般 * * テレビ テレビ テレビ テレビ * * 外 名詞-普通名詞-一般 * * テレビ テレビ テレビ
Ba で デ で 助詞-格助詞 * * デ デ で で * * 和 助詞-格助詞 * * デ で で
Ba は ハ は 助詞-係助詞 * * ハ ハ は は * * 和 助詞-係助詞 * * ハ は は
Ba 人気 ニンキ 人気 名詞-普通名詞-一般 * * ニンキ ニンキ 人気 人気 * * 漢 名詞-普通名詞-一般 * * ニンキコメディフレンズ 人気コメディフレンズ 人気コメディ「フレンズ」
I コメディ コメディー コメディー 名詞-普通名詞-一般 * * コメディ コメディ コメディ コメディ * * 外 * * * * * *
I 「 * 「 補助記号-括弧開 * *   「 「 * * 記号 * * * * * *
I フレンズ フレンド フレンド 名詞-普通名詞-一般 * * フレンズ フレンズ フレンズ フレンズ * * 外 * * * * * *
I 」 * 」 補助記号-括弧閉 * *   」 」 * * 記号 * * * * * *
Ba （ * （ 補助記号-括弧開 * *   （ （ * * 記号 補助記号-括弧開 * *  （ （
Ba 二千 ニセン 二千 名詞-数詞 * * ニセン ニセン 二千 二千 * * 漢 名詞-数詞 * * ニセンネン 二千年 二千年
I 年 ネン 年 名詞-普通名詞-助数詞可能 * * ネン ネン 年 年 * * 漢 * * * * * *
Ba ） * ） 補助記号-括弧閉 * *   ） ） * * 記号 補助記号-括弧閉 * *  ） ）
Ba に ニ に 助詞-格助詞 * * ニ ニ に に * * 和 助詞-格助詞 * * ニ に に
B ゲスト ゲスト ゲスト 名詞-普通名詞-一般 * * ゲスト ゲスト ゲスト ゲスト * * 外 動詞-一般 サ行変格 連用形-一般 ゲストシュツエンスル ゲスト出演する ゲスト出演し
I 出演 シュツエン 出演 名詞-普通名詞-サ変可能 * * シュツエン シュツエン 出演 出演 * * 漢 * * * * * *
I し スル 為る 動詞-非自立可能 サ行変格 連用形-一般 シ スル する する * * 和 * * * * * *
GOLD

        is $comainu->create_long_lemma($data, $comp_file), $gold;
    };

    subtest "parential 2" => sub {
        my $data = <<DATA;
Ba 経済 ケイザイ 経済 名詞-普通名詞-一般 * * ケイザイ ケイザイ 経済 経済 * * 漢 名詞-普通名詞-一般 * * ケイザイカツドウ 経済活動 経済活動
I 活動 カツドウ 活動 名詞-普通名詞-サ変可能 * * カツドウ カツドウ 活動 活動 * * 漢 * * * * * *
Ba を ヲ を 助詞-格助詞 * * ヲ ヲ を を * * 和 助詞-格助詞 * * ヲ を を
B 萎縮 イシュク 萎縮 名詞-普通名詞-サ変可能 * * イシュク イシュク 萎縮 萎縮 * * 漢 動詞-一般 サ行変格 未然形-サ イシュク（イシュク）スル 萎縮（いしゅく）する 萎縮(いしゅく)さ
I （ * （ 補助記号-括弧開 * *   （ （ * * * * * * * * *
I いしゅく イシュク 萎縮 名詞-普通名詞-サ変可能 * * イシュク イシュク 萎縮 萎縮 * * 漢 * * * * * *
I ） * ） 補助記号-括弧閉 * *   ） ） * * * * * * * * *
I さ スル 為る 動詞-非自立可能 サ行変格 未然形-サ サ スル する する * * 和 * * * * * *
Ba せる セル せる 助動詞 下一段-サ行 連体形-一般 セル セル せる せる * * 和 助動詞 下一段-サ行 連体形-一般 セル せる せる
DATA

        my $gold = <<GOLD;
Ba 経済 ケイザイ 経済 名詞-普通名詞-一般 * * ケイザイ ケイザイ 経済 経済 * * 漢 名詞-普通名詞-一般 * * ケイザイカツドウ 経済活動 経済活動
I 活動 カツドウ 活動 名詞-普通名詞-サ変可能 * * カツドウ カツドウ 活動 活動 * * 漢 * * * * * *
Ba を ヲ を 助詞-格助詞 * * ヲ ヲ を を * * 和 助詞-格助詞 * * ヲ を を
B 萎縮 イシュク 萎縮 名詞-普通名詞-サ変可能 * * イシュク イシュク 萎縮 萎縮 * * 漢 動詞-一般 サ行変格 未然形-サ イシュクスル 萎縮する 萎縮(いしゅく)さ
I （ * （ 補助記号-括弧開 * *   （ （ * * * * * * * * *
I いしゅく イシュク 萎縮 名詞-普通名詞-サ変可能 * * イシュク イシュク 萎縮 萎縮 * * 漢 * * * * * *
I ） * ） 補助記号-括弧閉 * *   ） ） * * * * * * * * *
I さ スル 為る 動詞-非自立可能 サ行変格 未然形-サ サ スル する する * * 和 * * * * * *
Ba せる セル せる 助動詞 下一段-サ行 連体形-一般 セル セル せる せる * * 和 助動詞 下一段-サ行 連体形-一般 セル せる せる
GOLD

        is $comainu->create_long_lemma($data, $comp_file), $gold;
    };

    subtest "compose" => sub {
        my $data = <<DATA;
B 遠く トオク 遠く 名詞-普通名詞-副詞可能 * * トオク トオク 遠く 遠く * * 和 名詞-普通名詞-一般 * * トオク 遠く 遠く
Ba の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
B お オ 御 接頭辞 * * オ オ 御 御 * * 和 名詞-普通名詞-一般 * * オミセ 御店 お店
Ia 店 ミセ 店 名詞-普通名詞-一般 * * ミセ ミセ 店 店 * * 和 * * * * * *
Ba に ニ に 助詞-格助詞 * * ニ ニ に に * * 和 助詞-格助詞 * * ニ に に
B 行っ イク 行く 動詞-非自立可能 五段-カ行-イク 連用形-促音便 イッ イク 行く 行っ * * 和 動詞-一般 五段-カ行-イク 連用形-促音便 イク 行く 行っ
B て テ て 助詞-接続助詞 * * テ テ て て * * 和 助動詞 五段-ワア行-一般 連用形-促音便 テシマウ て仕舞う てしまっ
I しまっ シマウ 仕舞う 動詞-非自立可能 五段-ワア行-一般 連用形-促音便 シマッ シマウ 仕舞う 仕舞っ * * 和 * * * * * *
Ba て テ て 助詞-接続助詞 * * テ テ て て * * 和 助詞-接続助詞 * * テ て て
Ba は ハ は 助詞-係助詞 * * ハ ハ は は * * 和 助詞-係助詞 * * ハ は は
DATA

        my $gold = <<GOLD;
B 遠く トオク 遠く 名詞-普通名詞-副詞可能 * * トオク トオク 遠く 遠く * * 和 名詞-普通名詞-一般 * * トオク 遠く 遠く
Ba の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
B お オ 御 接頭辞 * * オ オ 御 御 * * 和 名詞-普通名詞-一般 * * オミセ 御店 お店
Ia 店 ミセ 店 名詞-普通名詞-一般 * * ミセ ミセ 店 店 * * 和 * * * * * *
Ba に ニ に 助詞-格助詞 * * ニ ニ に に * * 和 助詞-格助詞 * * ニ に に
B 行っ イク 行く 動詞-非自立可能 五段-カ行-イク 連用形-促音便 イッ イク 行く 行っ * * 和 動詞-一般 五段-カ行-イク 連用形-促音便 イク 行く 行っ
B て テ て 助詞-接続助詞 * * テ テ て て * * 和 助動詞 五段-ワア行-一般 連用形-促音便 テシマウ てしまう てしまっ
I しまっ シマウ 仕舞う 動詞-非自立可能 五段-ワア行-一般 連用形-促音便 シマッ シマウ 仕舞う 仕舞っ * * 和 * * * * * *
Ba て テ て 助詞-接続助詞 * * テ テ て て * * 和 助詞-接続助詞 * * テ て て
Ba は ハ は 助詞-係助詞 * * ハ ハ は は * * 和 助詞-係助詞 * * ハ は は
GOLD

        is $comainu->create_long_lemma($data, $comp_file), $gold;
    };
};

sub generate_long_lemma : Test(1) {
    my $comainu = Comainu->new;

    my $create_luw = sub {
        my $data = shift;
        my @lines = split /\n/, $data;
        return [ map {
            my @items = split / /, $_;
            do { $items[$_] = "" if $items[$_] eq "*"; } for (7..10);
            \@items;
        } @lines ];
    };

    subtest '括弧' => sub {
        my $data = "Ba 「 * 「 補助記号-括弧開 * * * * 「 「 * * 記号 補助記号-括弧開 * *   「";
        my $luw = $create_luw->($data);

        $comainu->generate_long_lemma($luw, 0);
        is $luw->[0]->[17], "";
        is $luw->[0]->[18], "「";
    };
};

sub create_mstfeature : Test(1) {
    my $comainu = Comainu->new;
    my $short_terms = [
        "詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋",
        "将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * * *",
    ];

    my $gold = <<GOLD;
1\t詰め\t詰める\t動詞\t動詞-一般\t下一段|下一段-マ行|連用形|連用形-一般\t0\t_\t_
2\t将棋\t将棋\t名詞\t名詞-普通名詞-一般\t名詞-普通名詞\t0\t_\t_

GOLD

    is $comainu->create_mstfeature($short_terms, 2), $gold;
};

# TODO
# sub create_middle : Tests {};

sub add_pivot_to_kc2 : Test(1) {
    my $kc_data = <<KC;
*B
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * * *
の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
*B
本 ホン 本 名詞-普通名詞-一般 * * ホン ホン 本 本 * * 漢 名詞-普通名詞-一般 * * ホン 本 本
を ヲ を 助詞-格助詞 * * ヲ ヲ を を * * 和 助詞-格助詞 * * ヲ を を
KC
    my $kc_file = create_tmp_file($kc_data);

    my $kc2_data = <<KC2;
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 一般 * * 下一段 マ行 * 連用形 一般 * * 0 0
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * * * 漢 名詞 普通名詞 一般 * * * * * * * * 0 0
の ノ の 助詞-格助詞 * * * * 和 助詞 格助詞 * * * * * * * * * 0 0
本 ホン 本 名詞-普通名詞-一般 * * * * 漢 名詞 普通名詞 一般 * * * * * * * * 0 0
を ヲ を 助詞-格助詞 * * * * 和 助詞 格助詞 * * * * * * * * * 0 0
KC2
    my $kc2_file = create_tmp_file($kc2_data);

    my $out_file = create_tmp_file("");
    my $comainu = Comainu->new;

    open(my $fh_ref, "<", $kc_file);
    open(my $fh_in, "<", $kc2_file);
    open(my $fh_out, ">", $out_file);
    binmode($fh_out);
    $comainu->add_pivot_to_kc2($fh_ref, $fh_in, $fh_out);
    close($fh_out);
    close($fh_in);
    close($fh_ref);

    my $gold = <<GOLD;
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 一般 * * 下一段 マ行 * 連用形 一般 * * 0 0 B
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * * * 漢 名詞 普通名詞 一般 * * * * * * * * 0 0 Ia
の ノ の 助詞-格助詞 * * * * 和 助詞 格助詞 * * * * * * * * * 0 0 Ba
本 ホン 本 名詞-普通名詞-一般 * * * * 漢 名詞 普通名詞 一般 * * * * * * * * 0 0 Ba
を ヲ を 助詞-格助詞 * * * * 和 助詞 格助詞 * * * * * * * * * 0 0 Ba

GOLD

    is $comainu->read_from_file($out_file), $gold;
};

sub delete_column_long : Test(1) {
    my $comainu = Comainu->new;

    is $comainu->delete_column_long(
        "詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋"
    ), "詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和\n";
};

sub move_future_front : Test(2) {
    my $comainu = Comainu->new;

    is $comainu->move_future_front(
        "詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 一般 * * 下一段 マ行 * 連用形 一般 * * 0 0 B"
    ), "B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 一般 * * 下一段 マ行 * 連用形 一般 * * 0 0\n";

    is $comainu->move_future_front(
        "詰め\tツメル\t詰める\t動詞-一般\t下一段-マ行\t連用形-一般\t*\t*\t和\t動詞\t一般\t*\t*\t下一段\tマ行\t*\t連用形\t一般\t*\t*\t0\t0\tB"
    ), "B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 一般 * * 下一段 マ行 * 連用形 一般 * * 0 0\n";
};

sub truncate_last_column : Test(3) {
    my $comainu = Comainu->new;

    is $comainu->truncate_last_column(
        "B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 一般 * * 下一段 マ行 * 連用形 一般 * * 0 0"
    ), "B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 一般 * * 下一段 マ行 * 連用形 一般 * * 0 0\n";

    is $comainu->truncate_last_column(
        "B\t詰め\tツメル\t詰める\t動詞-一般\t下一段-マ行\t連用形-一般\t*\t*\t和\t動詞\t一般\t*\t*\t下一段\tマ行\t*\t連用形\t一般\t*\t*\t0\t0"
    ), "B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 一般 * * 下一段 マ行 * 連用形 一般 * * 0 0\n";

    is $comainu->truncate_last_column(
        "B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般"
    ), "B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般     \n";
};

sub pp_partial : Test(2) {
    my $comainu = Comainu->new;

    subtest "long" => sub {
        my $data = <<DATA;
*B
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * * * 漢
の ノ の 助詞-格助詞 * * * * 和
*B
本 ホン 本 名詞-普通名詞-一般 * * * * 漢
を ヲ を 助詞-格助詞 * * * * 和
DATA

        my $gold = <<GOLD;
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 B Ba
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * * * 漢 B Ba I Ia
の ノ の 助詞-格助詞 * * * * 和 B Ba I Ia
本 ホン 本 名詞-普通名詞-一般 * * * * 漢 B Ba
を ヲ を 助詞-格助詞 * * * * 和 B Ba I Ia
GOLD

        is $comainu->pp_partial($data), $gold;
    };

    subtest "bnst" => sub {
        my $data = <<DATA;
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 動詞 一般 * * 下一段 マ行 * 連用形 一般 * O
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * O
の ノ の 助詞-格助詞 * * 助詞 格助詞 * * * * * * * * O
本 ホン 本 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * O
を ヲ を 助詞-格助詞 * * 助詞 格助詞 * * * * * * * * O
DATA

        my $gold = <<GOLD;
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 動詞 一般 * * 下一段 マ行 * 連用形 一般 * O B
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * O B I
の ノ の 助詞-格助詞 * * 助詞 格助詞 * * * * * * * * O B I
本 ホン 本 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * O B I
を ヲ を 助詞-格助詞 * * 助詞 格助詞 * * * * * * * * O B I
GOLD

        is $comainu->pp_partial($data, {is_bnst => 1}), $gold;
    };

};

sub pp_partial_bnst_with_luw : Test(1) {
    my $data = <<DATA;
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 動詞 一般 * * 下一段 マ行 * 連用形 一般 * O
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * O
の ノ の 助詞-格助詞 * * 助詞 格助詞 * * * * * * * * O
本 ホン 本 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * O
を ヲ を 助詞-格助詞 * * 助詞 格助詞 * * * * * * * * O
DATA

    my $svmout_data = <<SVMOUT;
B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 一般 * * 下一段 マ行 * 連用形 一般 * * 0 0
Ia 将棋 ショウギ 将棋 名詞-普通名詞-一般 * * * * 漢 名詞 普通名詞 一般 * * * * * * * * 0 0
Ba の ノ の 助詞-格助詞 * * * * 和 助詞 格助詞 * * * * * * * * * 0 0
Ba 本 ホン 本 名詞-普通名詞-一般 * * * * 漢 名詞 普通名詞 一般 * * * * * * * * 0 0
Ba を ヲ を 助詞-格助詞 * * * * 和 助詞 格助詞 * * * * * * * * * 0 0
SVMOUT
    my $svmout_file = create_tmp_file($svmout_data);

    my $gold = <<GOLD;
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 動詞 一般 * * 下一段 マ行 * 連用形 一般 * O B
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * O I
の ノ の 助詞-格助詞 * * 助詞 格助詞 * * * * * * * * O B I
本 ホン 本 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * O B I
を ヲ を 助詞-格助詞 * * 助詞 格助詞 * * * * * * * * O B I
GOLD

    my $comainu = Comainu->new;
    is $comainu->pp_partial_bnst_with_luw($data, $svmout_file), $gold;
};

# sub bccwj2kc_file : Tests {};
# sub bccwjlong2kc_file : Tests {};
sub bccwj2kc : Test(2) {
    my $comainu = Comainu->new;

    subtest 'bccwj' => sub {
        my $data = <<DATA;
OC01_00001_c\t10\t30\tB\t詰め\tツメル\t詰める\t\t動詞-一般\t下一段-マ行\t連用形-一般\t\tツメ\tツメル\tツメ\tツメル\tツメ\tツメル\t詰める\t詰め\t詰める\t和
OC01_00001_c\t30\t50\t\t将棋\tショウギ\t将棋\t\t名詞-普通名詞-一般\t\t\t\tショーギ\tショーギ\tショウギ\tショウギ\tショウギ\tショウギ\t将棋\t将棋\t将棋\t漢
OC01_00001_c\t50\t60\t\tの\tノ\tの\t\t助詞-格助詞\t\t\t\tノ\tノ\tノ\tノ\tノ\tノ\tの\tの\tの\t和
OC01_00001_c\t60\t70\t\t本\tホン\t本\t\t名詞-普通名詞-一般\t\t\t\tホン\tホン\tホン\tホン\tホン\tホン\t本\t本\t本\t漢
OC01_00001_c\t70\t80\t\tを\tヲ\tを\t\t助詞-格助詞\t\t\t\tオ\tオ\tヲ\tヲ\tヲ\tヲ\tを\tを\tを\t和
DATA

        my $gold = <<GOLD;
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 * * * * * *
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * * *
の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 * * * * * *
本 ホン 本 名詞-普通名詞-一般 * * ホン ホン 本 本 * * 漢 * * * * * *
を ヲ を 助詞-格助詞 * * ヲ ヲ を を * * 和 * * * * * *
GOLD

        is $comainu->bccwj2kc($data), $gold;
    };

    subtest "with_luw" => sub {
        my $data = <<DATA;
OC01_00001_c\t10\t30\tB\t詰め\tツメル\t詰める\t\t動詞-一般\t下一段-マ行\t連用形-一般\t\tツメ\tツメル\tツメ\tツメル\tツメ\tツメル\t詰める\t詰め\t詰める\t和\t\t\t詰め\t10\tB\tB\t詰め将棋\tツメショウギ\t詰め将棋\t名詞-普通名詞-一般
OC01_00001_c\t30\t50\t\t将棋\tショウギ\t将棋\t\t名詞-普通名詞-一般\t\t\t\tショーギ\tショーギ\tショウギ\tショウギ\tショウギ\tショウギ\t将棋\t将棋\t将棋\t漢\t\t\t将棋\t20\t\tE\t詰め将棋\tツメショウギ\t詰め将棋\t名詞-普通名詞-一般
OC01_00001_c\t50\t60\t\tの\tノ\tの\t\t助詞-格助詞\t\t\t\tノ\tノ\tノ\tノ\tノ\tノ\tの\tの\tの\t和\t\t\tの\t30\t\tBE\tの\tノ\tの\t助詞-格助詞
OC01_00001_c\t60\t70\t\t本\tホン\t本\t\t名詞-普通名詞-一般\t\t\t\tホン\tホン\tホン\tホン\tホン\tホン\t本\t本\t本\t漢\t\t\t本\t40\tB\tBE\t本\tホン\t本\t名詞-普通名詞-一般
OC01_00001_c\t70\t80\t\tを\tヲ\tを\t\t助詞-格助詞\t\t\t\tオ\tオ\tヲ\tヲ\tヲ\tヲ\tを\tを\tを\t和\t\t\tを\t50\t\tBE\tを\tヲ\tを\t助詞-格助詞
DATA

        my $gold = <<GOLD;
*B
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * * *
*B
の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
*B
本 ホン 本 名詞-普通名詞-一般 * * ホン ホン 本 本 * * 漢 名詞-普通名詞-一般 * * ホン 本 本
*B
を ヲ を 助詞-格助詞 * * ヲ ヲ を を * * 和 助詞-格助詞 * * ヲ を を
GOLD

        is $comainu->bccwj2kc($data, "with_luw"), $gold;
    };
};

sub kc2bnstsvmdata : Test(2) {
    my $comainu = Comainu->new;

    subtest 'train' => sub {
        my $data = <<DATA;
*B
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * * *
の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
*B
本 ホン 本 名詞-普通名詞-一般 * * ホン ホン 本 本 * * 漢 名詞-普通名詞-一般 * * ホン 本 本
を ヲ を 助詞-格助詞 * * ヲ ヲ を を * * 和 助詞-格助詞 * * ヲ を を
DATA

        my $gold = <<GOLD;
*B
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 動詞 一般 * * 下一段 マ行 * 連用形 一般 * O
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * O
の ノ の 助詞-格助詞 * * 助詞 格助詞 * * * * * * * * O
*B
本 ホン 本 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * O
を ヲ を 助詞-格助詞 * * 助詞 格助詞 * * * * * * * * O
GOLD

        is $comainu->kc2bnstsvmdata($data, 1), $gold;
    };

    subtest 'test' => sub {
        my $data = <<DATA;
*B
「 * 「 補助記号-括弧開 * * * * 「 「 * * 記号 補助記号-括弧開 * * * 「 「
竜 リュウ 竜 名詞-普通名詞-一般 * * リュウ リュウ 竜 竜 * * 漢 名詞-普通名詞-一般 * * リュウキシ 竜騎士 竜騎士
騎士 キシ 騎士 名詞-普通名詞-一般 * * キシ キシ 騎士 騎士 * * 漢 * * * * * *
０ レイ 零 名詞-数詞 * * レイ レイ 零 零 * * 漢 名詞-数詞 * * レイナナ 零七 ０７
７ ナナ 七 名詞-数詞 * * ナナ ナナ 七 七 * * 和 * * * * * *
」 * 」 補助記号-括弧閉 * * * * 」 」 * * 記号 補助記号-括弧閉 * * * 」 」
って ッテ って 助詞-副助詞 * * ッテ ッテ って って * * 和 助詞-副助詞 * * ッテ って って
DATA

        my $gold = <<GOLD;
「 * 「 補助記号-括弧開 * * 補助記号 括弧開 * * * * * * * * B
竜 リュウ 竜 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * I
騎士 キシ 騎士 名詞-普通名詞-一般 * * 名詞 普通名詞 一般 * * * * * * * I
０ レイ 零 名詞-数詞 * * 名詞 数詞 * * * * * * * * I
７ ナナ 七 名詞-数詞 * * 名詞 数詞 * * * * * * * * I
」 * 」 補助記号-括弧閉 * * 補助記号 括弧閉 * * * * * * * * I
って ッテ って 助詞-副助詞 * * 助詞 副助詞 * * * * * * * * O
GOLD

        is $comainu->kc2bnstsvmdata($data, 0), $gold;
    };
};

sub kc2mstin : Test(1) {
    my $data = <<KCLONG;
*B
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * * *
の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
KCLONG

    my $gold = <<GOLD;
1\t詰め\t詰める\t動詞\t動詞-一般\t下一段|下一段-マ行|連用形|連用形-一般\t0\t_\t_
2\t将棋\t将棋\t名詞\t名詞-普通名詞-一般\t名詞-普通名詞\t0\t_\t_

GOLD

    my $comainu = Comainu->new;
    is $comainu->kc2mstin($data), $gold;
};

sub lout2kc4mid_file : Test(1) {
    my $data = <<KC_LOUT;
B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋
Ia 将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * * *
Ba の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の
KC_LOUT

    my $gold = <<GOLD;
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * *
の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の
GOLD

    my $kc_lout_file = create_tmp_file($data);
    my $kc_buff;
    my $g = guard_write_to_file(\$kc_buff);

    my $comainu = Comainu->new;
    $comainu->lout2kc4mid_file($kc_lout_file, "kc_file");

    is $kc_buff, $gold;
};

sub mecab2kc : Test(1) {
    my $data = <<MECAB_EXT;
B\t村山\tムラヤマ\tムラヤマ\tムラヤマ\t名詞-固有名詞-人名-姓\t\t\t固\tムラヤマ\tムラヤマ\tムラヤマ\tムラヤマ
\t富一\tトミイチ\tトミイチ\tトミイチ\t名詞-固有名詞-人名-名\t\t\t固\tトミイチ\tトミイチ\tトミイチ\tトミイチ
\t首相\tシュショー\t シュショウ\t首相\t名詞-普通名詞-一般\t\t\t漢\tシュショウ\tシュショウ\t首相\t首相
\tは\tワ\tハ\tは\t助詞-係助詞\t\t\t和\tハ\tハ\tは\tは
MECAB_EXT

    my $gold = <<GOLD;
村山 ムラヤマ ムラヤマ 名詞-固有名詞-人名-姓 * * ムラヤマ ムラヤマ ムラヤマ ムラヤマ * * 固 * * * * * * * *
富一 トミイチ トミイチ 名詞-固有名詞-人名-名 * * トミイチ トミイチ トミイチ トミイチ * * 固 * * * * * * * *
首相  シュショウ 首相 名詞-普通名詞-一般 * * シュショウ シュショウ 首相 首相 * * 漢 * * * * * * * *
は ハ は 助詞-係助詞 * * ハ ハ は は * * 和 * * * * * * * *
EOS
GOLD

    my $comainu = Comainu->new;
    is $comainu->mecab2kc($data), $gold;
};

# sub format_inputdata : Tests {};
sub trans_dataformat : Test(3) {
    my $comainu = Comainu->new;
    my $format_data = "";
    my $g = mock_guard('Comainu', {
        read_from_file => sub { $format_data },
    });

    subtest "input-kc to kc (same)" => sub {
        $format_data = "input-kc\t" . "orthToken,reading,lemma,pos,cType,cForm,form,formBase,formOrthBase,formOrth,charEncloserOpen,charEncloserClose,wType,l_pos,l_cType,l_cForm,l_reading,l_lemma,l_orthToken,depend,MID,m_orthToken";
        my $data = "詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋";

        is $comainu->trans_dataformat($data, 'input-kc', 'kc'), $data;
    };

    subtest "input-kc to kc (diff)" => sub {
        $format_data = "input-kc\t" . "lemma,reading,orthToken,pos,cType,cForm,form,formBase,formOrthBase,formOrth,charEncloserOpen,charEncloserClose,wType,l_pos,l_cType,l_cForm,l_reading,l_lemma,l_orthToken,depend,MID,m_orthToken";
        my $data = "詰める ツメル 詰め 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋";
        my $gold = "詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋";

        is $comainu->trans_dataformat($data, 'input-kc', 'kc'), $gold;
    };

    subtest "input-bccwj to bccwj" => sub {
        $format_data = "input-bccwj\t" . "start,end,file,BOS,orthToken,reading,lemma,meaning,pos,cType,cForm,usage,pronToken,pronBase,kana,kanaBase,form,formBase,formOrthBase,formOrth,orthBase,wType,charEncloserOpen,charEncloserClose,originalText,order,BOB,LUW,l_orthToken,l_reading,l_lemma,l_pos,l_cType,l_cForm";

        my $data = "10\t30\tOC01_00001_c\tB\t詰め\tツメル\t詰める\t動詞-一般\t下一段-マ行\t連用形-一般\tツメ\tツメル\tツメ\tツメル\tツメ\tツメル\t詰める\t詰め\t 詰める\t和\t詰め\t10\tB\tB\t詰め将棋\tツメショウギ\t詰め将棋\t名詞-普通名詞-一般";
        my $gold = "OC01_00001_c\t10\t30\tB\t詰め\tツメル\t詰める\t動詞-一般\t下一段-マ行\t連用形-一般\tツメ\tツメル\tツメ\tツメル\tツメ\tツメル\t詰める\t詰め\t 詰める\t和\t詰め\t10\tB\tB\t詰め将棋\tツメショウギ\t詰め将棋\t名詞-普通名詞-一般\t*\t*\t*\t*\t*\t*";

        is $comainu->trans_dataformat($data, 'input-bccwj', 'bccwj'), $gold;
    };
};

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

    my $comainu = Comainu->new;
    is $comainu->short2long($data), $gold;
};

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

    my $comainu = Comainu->new;
    is $comainu->short2bnst($data), "詰め将棋の\n本を\n買って\nきました。";
};

sub short2middle : Test(1) {
    my $data = <<MOUT;
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋 1 0 詰め将棋
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * ショウギ ショウギ 将棋 将棋 * * 漢 * * * * * * * 0
の ノ の 助詞-格助詞 * * ノ ノ の の * * 和 助詞-格助詞 * * ノ の の * 1 の
本 ホン 本 名詞-普通名詞-一般 * * ホン ホン 本 本 * * 漢 名詞-普通名詞-一般 * * ホン 本 本 * 2 本
を ヲ を 助詞-格助詞 * * ヲ ヲ を を * * 和 助詞-格助詞 * * ヲ を を * 3 を
買っ カウ 買う 動詞-一般 五段-ワア行-一般 連用形-促音便 カッ カウ 買う 買っ * * 和 動詞-一般 五段-ワア行-一般 連用形-促音便 カウ 買う 買っ * 4 買っ
て テ て 助詞-接続助詞 * * テ テ て て * * 和 助詞-接続助詞 * * テ て て * 5 て
き クル 来る 動詞-非自立可能 カ行変格 連用形-一般 キ クル 来る 来 * * 和 動詞-一般 カ行変格 連用形-一般 クル 来る き * 6 き
まし マス ます 助動詞 助動詞-マス 連用形-一般 マシ マス ます まし * * 和 助動詞 助動詞-マス 連用形-一般 マス ます まし * 7 まし
た タ た 助動詞 助動詞-タ 終止形-一般 タ タ た た * * 和 助動詞 助動詞-タ 終止形-一般 タ た た * 8 た
。 * 。 補助記号-句点 * * * * 。 。 * * 記号 補助記号-句点 * * * 。 。 * 9 。
EOS
MOUT

    my $comainu = Comainu->new;
    is $comainu->short2middle($data), "詰め将棋\nの\n本\nを\n買っ\nて\nき\nまし\nた\n。\n";
};


sub merge_bccwj_with_kc_lout_file : Test(1) {
    my $lout_buff = "";
    my $g = guard_write_to_file(\$lout_buff);

    my $comainu = Comainu->new;
    $comainu->merge_bccwj_with_kc_lout_file("t/sample/test.bccwj.txt", "t/sample/test.bccwj.KC.lout", "lout_file");

    my $gold_lout_buff = $comainu->read_from_file("t/sample/test.bccwj.lout");

    is $gold_lout_buff, $lout_buff;
};

# sub merge_iof : Tests {};

sub merge_bccwj_with_kc_bout_file : Test(1) {
    my $bout_buff = "";
    my $g = guard_write_to_file(\$bout_buff);

    my $comainu = Comainu->new;
    $comainu->merge_bccwj_with_kc_bout_file("t/sample/test.bccwj.txt", "t/sample/test.bccwj.KC.bout", "bout_file");

    my $gold_bout_buff = $comainu->read_from_file("t/sample/test.bccwj.bout");

    is $gold_bout_buff, $bout_buff;
};

sub merge_bccwj_with_kc_mout_file : Test(1) {
    my $mout_buff = "";
    my $g = guard_write_to_file(\$mout_buff);

    my $comainu = Comainu->new;
    $comainu->merge_bccwj_with_kc_mout_file("t/sample/test.bccwj.long.txt", "t/sample/test.bccwj.long.KC.mout", "mout_file");

    my $gold_mout_buff = $comainu->read_from_file("t/sample/test.bccwj.long.mout");

    is $gold_mout_buff, $mout_buff;
};

sub merge_mecab_with_kc_lout_file : Test(1) {
    my $lout_buff = "";
    my $g = guard_write_to_file(\$lout_buff);

    my $comainu = Comainu->new;
    $comainu->merge_mecab_with_kc_lout_file("t/sample/test.plain.mecab", "t/sample/test.plain.KC.lout", "lout_file");

    my $gold_lout_buff = $comainu->read_from_file("t/sample/test.plain.lout");

    is $gold_lout_buff, $lout_buff;
};

sub merge_mecab_with_kc_bout_file : Test(1) {
    my $bout_buff = "";
    my $g = guard_write_to_file(\$bout_buff);

    my $comainu = Comainu->new;
    $comainu->merge_mecab_with_kc_bout_file("t/sample/test.plain.mecab", "t/sample/test.plain.KC.bout", "bout_file");

    my $gold_bout_buff = $comainu->read_from_file("t/sample/test.plain.bout");

    is $gold_bout_buff, $bout_buff;
};

sub merge_mecab_with_kc_mout_file : Test(1) {
    my $mout_buff = "";
    my $g = guard_write_to_file(\$mout_buff);

    my $comainu = Comainu->new;
    $comainu->merge_mecab_with_kc_mout_file("t/sample/test.plain.mecab", "t/sample/test.plain.KC.mout", "mout_file");

    my $gold_mout_buff = $comainu->read_from_file("t/sample/test.plain.mout");

    is $gold_mout_buff, $mout_buff;
};

sub merge_kc_with_mstout : Test(1) {
    my $comainu = Comainu->new;
    my $buff = $comainu->merge_kc_with_mstout("t/sample/test.plain.KC", "t/sample/test.plain.mstout");
    my $gold_buff = $comainu->read_from_file("t/sample/test.plain.KC.mout");

    is $gold_buff, $buff;
};

sub merge_kc_with_svmout : Test(1) {
    my $comainu = Comainu->new;
    my $buff = $comainu->merge_kc_with_svmout("t/sample/test.plain.KC", "t/sample/test.plain.svmout");
    my $gold_buff = $comainu->read_from_file("t/sample/test.plain.KC.svmout.lout");

    is $gold_buff, $buff;
};

sub merge_kc_with_bout : Test(1) {
    my $comainu = Comainu->new;
    my $buff = $comainu->merge_kc_with_bout("t/sample/test.KC", "t/sample/test.svmdata.bout");
    my $gold_buff = $comainu->read_from_file("t/sample/test.bout");

    is $gold_buff, $buff;
};

sub create_template : Test(1) {
    my $template_buff = "";
    my $g = guard_write_to_file(\$template_buff);

    my $comainu = Comainu->new;
    $comainu->create_template("file", 6);

    my $expected_buff = <<FEATURE;
U1:%x[-2,0]
U2:%x[-1,0]
U3:%x[0,0]
U4:%x[1,0]
U5:%x[2,0]
U6:%x[-2,0]/%x[-1,0]
U7:%x[-1,0]/%x[0,0]
U8:%x[0,0]/%x[1,0]
U9:%x[1,0]/%x[2,0]
U10:%x[-2,0]/%x[-1,0]/%x[0,0]
U11:%x[-1,0]/%x[0,0]/%x[1,0]
U12:%x[0,0]/%x[1,0]/%x[2,0]
U13:%x[-2,2]
U14:%x[-1,2]
U15:%x[0,2]
U16:%x[1,2]
U17:%x[2,2]
U18:%x[-2,2]/%x[-1,2]
U19:%x[-1,2]/%x[0,2]
U20:%x[0,2]/%x[1,2]
U21:%x[1,2]/%x[2,2]
U22:%x[-2,2]/%x[-1,2]/%x[0,2]
U23:%x[-1,2]/%x[0,2]/%x[1,2]
U24:%x[0,2]/%x[1,2]/%x[2,2]
U25:%x[-2,3]
U26:%x[-1,3]
U27:%x[0,3]
U28:%x[1,3]
U29:%x[2,3]
U30:%x[-2,3]/%x[-1,3]
U31:%x[-1,3]/%x[0,3]
U32:%x[0,3]/%x[1,3]
U33:%x[1,3]/%x[2,3]
U34:%x[-2,3]/%x[-1,3]/%x[0,3]
U35:%x[-1,3]/%x[0,3]/%x[1,3]
U36:%x[0,3]/%x[1,3]/%x[2,3]
U37:%x[-2,4]
U38:%x[-1,4]
U39:%x[0,4]
U40:%x[1,4]
U41:%x[2,4]
U42:%x[-2,4]/%x[-1,4]
U43:%x[-1,4]/%x[0,4]
U44:%x[0,4]/%x[1,4]
U45:%x[1,4]/%x[2,4]
U46:%x[-2,4]/%x[-1,4]/%x[0,4]
U47:%x[-1,4]/%x[0,4]/%x[1,4]
U48:%x[0,4]/%x[1,4]/%x[2,4]
U49:%x[-2,5]
U50:%x[-1,5]
U51:%x[0,5]
U52:%x[1,5]
U53:%x[2,5]
U54:%x[-2,5]/%x[-1,5]
U55:%x[-1,5]/%x[0,5]
U56:%x[0,5]/%x[1,5]
U57:%x[1,5]/%x[2,5]
U58:%x[-2,5]/%x[-1,5]/%x[0,5]
U59:%x[-1,5]/%x[0,5]/%x[1,5]
U60:%x[0,5]/%x[1,5]/%x[2,5]
U61:%x[-2,6]
U62:%x[-1,6]
U63:%x[0,6]
U64:%x[1,6]
U65:%x[2,6]
U66:%x[-2,6]/%x[-1,6]
U67:%x[-1,6]/%x[0,6]
U68:%x[0,6]/%x[1,6]
U69:%x[1,6]/%x[2,6]
U70:%x[-2,6]/%x[-1,6]/%x[0,6]
U71:%x[-1,6]/%x[0,6]/%x[1,6]
U72:%x[0,6]/%x[1,6]/%x[2,6]

U73:%x[-2,2]/%x[-1,3]
U74:%x[-2,3]/%x[-1,2]
U75:%x[-1,2]/%x[0,3]
U76:%x[-1,3]/%x[0,2]
U77:%x[0,2]/%x[1,3]
U78:%x[0,3]/%x[1,2]
U79:%x[1,2]/%x[2,3]
U80:%x[1,3]/%x[2,2]

U81:%x[-2,2]/%x[-1,4]
U82:%x[-2,4]/%x[-1,2]
U83:%x[-1,2]/%x[0,4]
U84:%x[-1,4]/%x[0,2]
U85:%x[0,2]/%x[1,4]
U86:%x[0,4]/%x[1,2]
U87:%x[1,2]/%x[2,4]
U88:%x[1,4]/%x[2,2]

U89:%x[-2,2]/%x[-1,5]
U90:%x[-2,5]/%x[-1,2]
U91:%x[-1,2]/%x[0,5]
U92:%x[-1,5]/%x[0,2]
U93:%x[0,2]/%x[1,5]
U94:%x[0,5]/%x[1,2]
U95:%x[1,2]/%x[2,5]
U96:%x[1,5]/%x[2,2]

U97:%x[-2,2]/%x[-2,3]/%x[-1,3]
U98:%x[-2,3]/%x[-1,2]/%x[-1,3]
U99:%x[-1,2]/%x[-1,3]/%x[0,3]
U100:%x[-1,3]/%x[0,2]/%x[0,3]
U101:%x[0,2]/%x[0,3]/%x[1,3]
U102:%x[0,3]/%x[1,2]/%x[1,3]
U103:%x[1,2]/%x[1,3]/%x[2,3]
U104:%x[1,3]/%x[2,2]/%x[2,3]

U105:%x[-2,2]/%x[-2,4]/%x[-1,4]
U106:%x[-2,4]/%x[-1,2]/%x[-1,4]
U107:%x[-1,2]/%x[-1,4]/%x[0,4]
U108:%x[-1,4]/%x[0,2]/%x[0,4]
U109:%x[0,2]/%x[0,4]/%x[1,4]
U110:%x[0,4]/%x[1,2]/%x[1,4]
U111:%x[1,2]/%x[1,4]/%x[2,4]
U112:%x[1,4]/%x[2,2]/%x[2,4]

U113:%x[-2,2]/%x[-2,5]/%x[-1,5]
U114:%x[-2,5]/%x[-1,2]/%x[-1,5]
U115:%x[-1,2]/%x[-1,5]/%x[0,5]
U116:%x[-1,5]/%x[0,2]/%x[0,5]
U117:%x[0,2]/%x[0,5]/%x[1,5]
U118:%x[0,5]/%x[1,2]/%x[1,5]
U119:%x[1,2]/%x[1,5]/%x[2,5]
U120:%x[1,5]/%x[2,2]/%x[2,5]


B
FEATURE

    is $template_buff, $expected_buff;
};

# sub create_BI_template : Tests {};
# sub check_luwmodel : Tests {};
# sub create_yamcha_makefile : Tests {};
# sub get_yamcha_tool_dir : Tests {};

sub load_yamcha_training_conf : Test(1) {
    my $confdata = <<CONF;
# Template file of YamCha settings     #
# use YamCha  : DIRECTION, FEATURE     #
# use TinySVM : SVM_PARAM, MULTI_CLASS #

SVM_PARAM="-t 1 -d 3 -c 1 -m 514"
FEATURE=
DIRECTION="-B"
MULTI_CLASS=2

CONF

    my $file = create_tmp_file($confdata);
    my $comainu = Comainu->new;
    my $conf = $comainu->load_yamcha_training_conf($file);

    is_deeply $conf, {
        SVM_PARAM   => "-t 1 -d 3 -c 1 -m 514",
        FEATURE     => '',
        DIRECTION   => "-B",
        MULTI_CLASS => 2,
    };
};


# sub check_yamcha_training_makefile_template : Tests {};

# sub add_column : Tests {};
# sub poscreate : Tests {};
# sub pp_ctype : Tests {};
# sub check_args : Tests {};
# sub check_file : Tests {};
# sub read_from_file : Tests {};
# sub write_to_file : Tests {};

sub proc_stdin2stdout : Test(1) {
    my $comainu = Comainu->new;
    is $comainu->proc_stdin2stdout('cat', 'test'), 'test';
};

sub proc_stdin2file : Test(1) {
    my $outfile = create_tmp_file("");
    my $comainu = Comainu->new;
    $comainu->proc_stdin2file('cat', 'test', $outfile);

    open(IN, $outfile);
    my $out_data = "";
    while (<IN>) {
        chomp;
        $out_data .= $_ . "\n";
    }
    close(IN);

    is $out_data, "test\n";
};

sub proc_file2file : Test(1) {
    my $infile  = create_tmp_file("test");
    my $outfile = create_tmp_file("");

    my $comainu = Comainu->new;
    $comainu->proc_file2file('cat', $infile, $outfile);

    open(IN, $outfile);
    my $out_data = "";
    while (<IN>) {
        chomp;
        $out_data .= $_ . "\n";
    }
    close(IN);

    is $out_data, "test\n";
};




sub create_tmp_file {
    my $data = shift;

    my $fh   = File::Temp->new;
    my $file = $fh->filename;
    print $fh encode_utf8 $data;
    close $fh;

    return ($file, $fh);
}

sub guard_write_to_file {
    my $data = shift;

    mock_guard('Comainu', {
        write_to_file => sub {
            my ($self, $tmp_file, $buff) = @_;
            $$data = $buff;
        }
    });
}



__PACKAGE__->runtests;
