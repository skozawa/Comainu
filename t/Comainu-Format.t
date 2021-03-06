package t::Comainu::Format;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::Format';
}

# sub format_inputdata : Tests {};
sub trans_dataformat : Test(3) {
    my $format_data = "";
    my $g = mock_guard('Comainu::Format', {
        read_from_file => sub { $format_data },
    });

    subtest "input-kc to kc (same)" => sub {
        $format_data = "input-kc\t" . "orthToken,reading,lemma,pos,cType,cForm,form,formBase,formOrthBase,formOrth,charEncloserOpen,charEncloserClose,wType,l_pos,l_cType,l_cForm,l_reading,l_lemma,l_orthToken,depend,MID,m_orthToken";
        my $data = "詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋";

        is Comainu::Format->trans_dataformat($data, {
            input_type       => 'input-kc',
            output_type      => 'kc',
            data_format_file => 'etc/data_format.conf',
        }), $data;
    };

    subtest "input-kc to kc (diff)" => sub {
        $format_data = "input-kc\t" . "lemma,reading,orthToken,pos,cType,cForm,form,formBase,formOrthBase,formOrth,charEncloserOpen,charEncloserClose,wType,l_pos,l_cType,l_cForm,l_reading,l_lemma,l_orthToken,depend,MID,m_orthToken";
        my $data = "詰める ツメル 詰め 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋";
        my $gold = "詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 ツメ ツメル 詰める 詰め * * 和 名詞-普通名詞-一般 * * ツメショウギ 詰め将棋 詰め将棋";

        is Comainu::Format->trans_dataformat($data, {
            input_type       => 'input-kc',
            output_type      => 'kc',
            data_format_file => 'etc/data_format.conf',
        }), $gold;
    };

    subtest "input-bccwj to bccwj" => sub {
        $format_data = "input-bccwj\t" . "start,end,file,BOS,orthToken,reading,lemma,meaning,pos,cType,cForm,usage,pronToken,pronBase,kana,kanaBase,form,formBase,formOrthBase,formOrth,orthBase,wType,charEncloserOpen,charEncloserClose,originalText,order,BOB,LUW,l_orthToken,l_reading,l_lemma,l_pos,l_cType,l_cForm";

        my $data = "10\t30\tOC01_00001_c\tB\t詰め\tツメル\t詰める\t動詞-一般\t下一段-マ行\t連用形-一般\tツメ\tツメル\tツメ\tツメル\tツメ\tツメル\t詰める\t詰め\t 詰める\t和\t詰め\t10\tB\tB\t詰め将棋\tツメショウギ\t詰め将棋\t名詞-普通名詞-一般";
        my $gold = "OC01_00001_c\t10\t30\tB\t詰め\tツメル\t詰める\t動詞-一般\t下一段-マ行\t連用形-一般\tツメ\tツメル\tツメ\tツメル\tツメ\tツメル\t詰める\t詰め\t 詰める\t和\t詰め\t10\tB\tB\t詰め将棋\tツメショウギ\t詰め将棋\t名詞-普通名詞-一般\t*\t*\t*\t*\t*\t*";

        is Comainu::Format->trans_dataformat($data, {
            input_type       => 'input-bccwj',
            output_type      => 'bccwj',
            data_format_file => 'etc/data_format.conf',
        }), $gold;
    };
}

sub merge_kc_with_mstout : Test(1) {
    my $buff = Comainu::Format->merge_kc_with_mstout("t/sample/test.plain.KC", "t/sample/test.plain.mstout");
    my $gold_buff = read_from_file("t/sample/test.plain.KC.mout");

    is $gold_buff, $buff;
}

sub move_future_front : Test(2) {
    is Comainu::Format->move_future_front(
        "詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 * * 下一段 * 連用形 * * 0 0 B"
    ), "B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 * * 下一段 * 連用形 * * 0 0\n";

    is Comainu::Format->move_future_front(
        "詰め\tツメル\t詰める\t動詞-一般\t下一段-マ行\t連用形-一般\t*\t*\t和\t動詞\t*\t*\t下一段\t*\t連用形\t*\t*\t0\t0\tB"
    ), "B 詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 * * 下一段 * 連用形 * * 0 0\n";
}

# sub bccwj2kc_file : Tests {}
# sub bccwjlong2kc_file : Tests {}
sub bccwj2kc : Test(2) {
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

        is Comainu::Format->bccwj2kc($data, '', 'none'), $gold;
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

        is Comainu::Format->bccwj2kc($data, "with_luw", "none"), $gold;
    };
}

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
    my $g = guard_write_to_file('Comainu::Format', \$kc_buff);

    Comainu::Format->lout2kc4mid_file($kc_lout_file, "kc_file");

    is $kc_buff, $gold;
}


sub merge_bccwj_with_kc_lout_file : Test(1) {
    my $lout_buff = "";
    my $g = guard_write_to_file('Comainu::Format', \$lout_buff);

    Comainu::Format->merge_bccwj_with_kc_lout_file("t/sample/test.bccwj.txt", "t/sample/test.bccwj.KC.lout", "lout_file", "sentence");

    my $gold_lout_buff = read_from_file("t/sample/test.bccwj.lout");

    is $gold_lout_buff, $lout_buff;
}

# sub merge_iof : Tests {};

sub merge_bccwj_with_kc_bout_file : Test(1) {
    my $bout_buff = "";
    my $g = guard_write_to_file('Comainu::Format', \$bout_buff);

    Comainu::Format->merge_bccwj_with_kc_bout_file("t/sample/test.bccwj.txt", "t/sample/test.bccwj.KC.bout", "bout_file");

    my $gold_bout_buff = read_from_file("t/sample/test.bccwj.bout");

    is $gold_bout_buff, $bout_buff;
}

sub merge_bccwj_with_kc_mout_file : Test(1) {
    my $mout_buff = "";
    my $g = guard_write_to_file('Comainu::Format', \$mout_buff);

    Comainu::Format->merge_bccwj_with_kc_mout_file("t/sample/test.bccwj.long.txt", "t/sample/test.bccwj.long.KC.mout", "mout_file");

    my $gold_mout_buff = read_from_file("t/sample/test.bccwj.long.mout");

    is $gold_mout_buff, $mout_buff;
}

sub merge_mecab_with_kc_lout_file : Test(1) {
    my $lout_buff = "";
    my $g = guard_write_to_file('Comainu::Format', \$lout_buff);

    Comainu::Format->merge_mecab_with_kc_lout_file("t/sample/test.plain.mecab", "t/sample/test.plain.KC.lout", "lout_file");

    my $gold_lout_buff = read_from_file("t/sample/test.plain.lout");

    is $gold_lout_buff, $lout_buff;
}

sub merge_mecab_with_kc_bout_file : Test(1) {
    my $bout_buff = "";
    my $g = guard_write_to_file('Comainu::Format', \$bout_buff);

    Comainu::Format->merge_mecab_with_kc_bout_file("t/sample/test.plain.mecab", "t/sample/test.plain.KC.bout", "bout_file");

    my $gold_bout_buff = read_from_file("t/sample/test.plain.bout");

    is $gold_bout_buff, $bout_buff;
};

sub merge_mecab_with_kc_mout_file : Test(1) {
    my $mout_buff = "";
    my $g = guard_write_to_file('Comainu::Format', \$mout_buff);

    Comainu::Format->merge_mecab_with_kc_mout_file("t/sample/test.plain.mecab", "t/sample/test.plain.KC.mout", "mout_file");

    my $gold_mout_buff = read_from_file("t/sample/test.plain.mout");

    is $gold_mout_buff, $mout_buff;
}

sub merge_kc_with_svmout : Test(1) {
    my $buff = Comainu::Format->merge_kc_with_svmout("t/sample/test.plain.KC", "t/sample/test.plain.svmout", "with");
    my $gold_buff = read_from_file("t/sample/test.plain.KC.svmout.lout");

    is $gold_buff, $buff;
}

sub merge_kc_with_bout : Test(1) {
    my $buff = Comainu::Format->merge_kc_with_bout("t/sample/test.KC", "t/sample/test.svmdata.bout");
    my $gold_buff = read_from_file("t/sample/test.bout");

    is $gold_buff, $buff;
};


__PACKAGE__->runtests;
