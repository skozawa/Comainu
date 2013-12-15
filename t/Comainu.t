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

# sub plain2mecab_file : Tests {};
# sub mecab2kc_file : Tests {};

# sub eval_long : Tests {};
# sub diff_perl : Tests {};

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
