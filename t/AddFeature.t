package t::AddFeature;
use strict;
use warnings;
use utf8;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

use Encode;
use File::Temp;
use File::Basename;

use AddFeature;

sub _use_ok : Test(startup => 1) {
    use_ok 'AddFeature';
};

sub add_feature_pos : Test(11) {
    my $buff = <<DATA;
詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和
将棋 ショウギ 将棋 名詞-普通名詞-一般 * * * * 漢
の ノ の 助詞-格助詞 * * * * 和
本 ホン 本 名詞-普通名詞-一般 * * * * 漢
を ヲ を 助詞-格助詞 * * * * 和
買っ カウ 買う 動詞-一般 五段-ワア行-一般 連用形-促音便 * * 和
て テ て 助詞-接続助詞 * * * * 和
き クル 来る 動詞-非自立可能 カ行変格 連用形-一般 * * 和
まし マス ます 助動詞 助動詞-マス 連用形-一般 * * 和
た タ た 助動詞 助動詞-タ 終止形-一般 * * 和
。 * 。 補助記号-句点 * * * * 記号
DATA

    my $add_feature = AddFeature->new;
    my $res = $add_feature->add_feature($buff, "", "");
    my @lines = split /\n/, $res;

    is $lines[0], "詰め ツメル 詰める 動詞-一般 下一段-マ行 連用形-一般 * * 和 動詞 一般 * * 下一段 マ行 * 連用形 一般 *";
    is $lines[1], "将棋 ショウギ 将棋 名詞-普通名詞-一般 * * * * 漢 名詞 普通名詞 一般 * * * * * * *";
    is $lines[2], "の ノ の 助詞-格助詞 * * * * 和 助詞 格助詞 * * * * * * * *";
    is $lines[3], "本 ホン 本 名詞-普通名詞-一般 * * * * 漢 名詞 普通名詞 一般 * * * * * * *";
    is $lines[4], "を ヲ を 助詞-格助詞 * * * * 和 助詞 格助詞 * * * * * * * *";
    is $lines[5], "買っ カウ 買う 動詞-一般 五段-ワア行-一般 連用形-促音便 * * 和 動詞 一般 * * 五段 ワア行 一般 連用形 促音便 *";
    is $lines[6], "て テ て 助詞-接続助詞 * * * * 和 助詞 接続助詞 * * * * * * * *";
    is $lines[7], "き クル 来る 動詞-非自立可能 カ行変格 連用形-一般 * * 和 動詞 非自立可能 * * カ行変格 * * 連用形 一般 *";
    is $lines[8], "まし マス ます 助動詞 助動詞-マス 連用形-一般 * * 和 助動詞 * * * 助動詞 マス * 連用形 一般 *";
    is $lines[9], "た タ た 助動詞 助動詞-タ 終止形-一般 * * 和 助動詞 * * * 助動詞 タ * 終止形 一般 *";
    is $lines[10], "。 * 。 補助記号-句点 * * * * 記号 補助記号 句点 * * * * * * * *";
};

sub add_feature_postp : Test(5) {
    my $data = <<DATA;
代名詞 * *
と ト と 助詞-格助詞 * *
し スル 為る 動詞-非自立可能 サ行変格 連用形-一般
て テ て 助詞-接続助詞 * *
助詞

DATA

    my $fh = File::Temp->new(DIR => '/tmp', SUFFIX => '.Postp.dic');
    my $filename = $fh->filename;
    my $basename = File::Basename::basename($filename, '.Postp.dic');
    print $fh encode_utf8 $data;
    close $fh;

    my $g = mock_guard(
        "File::Temp" => {
            _replace_XX => sub { '/tmp/' . $basename . '.AuxV.dic' },
        },
    );

    my $fh2 = File::Temp->new;
    close $fh2;

    my $buff = <<DATA;
私 ワタクシ 私 代名詞 * * * * 和
と ト と 助詞-格助詞 * * * * 和
し スル 為る 動詞-非自立可能 サ行変格 連用形-一般 * * 和
て テ て 助詞-接続助詞 * * * * 和
は ハ は 助詞-係助詞 * * * * 和
DATA

    my $add_feature = AddFeature->new;
    my $res = $add_feature->add_feature($buff, $basename, "/tmp");
    my @lines = split /\n/, $res;

    is $lines[0], "私 ワタクシ 私 代名詞 * * * * 和 代名詞 * * * * * * * * *";
    is $lines[1], "と ト と 助詞-格助詞 * * * * 和 助詞 格助詞 * * * * * * * *";
    is $lines[2], "し スル 為る 動詞-非自立可能 サ行変格 連用形-一般 * * 和 動詞 非自立可能 * * サ行変格 * * 連用形 一般 *";
    is $lines[3], "て テ て 助詞-接続助詞 * * * * 和 助詞 接続助詞 * * * * * * * *";
    is $lines[4], "は ハ は 助詞-係助詞 * * * * 和 助詞 係助詞 * * * * * * * *";
};


sub add_feature_auxv : Test(4) {
    my $data = <<DATA;
動詞 下一段 連用形
て テ て 助詞-接続助詞 * *
下さい クダサル 下さる 動詞-非自立可能 五段-ラ行 命令形
補助記号

DATA

    my $fh = File::Temp->new(DIR => '/tmp', SUFFIX => '.AuxV.dic');
    my $filename = $fh->filename;
    my $basename = File::Basename::basename($filename, '.AuxV.dic');
    print $fh encode_utf8 $data;
    close $fh;

    my $g = mock_guard(
        "File::Temp" => {
            _replace_XX => sub { '/tmp/' . $basename . '.Postp.dic' },
        },
    );

    my $fh2 = File::Temp->new;
    close $fh2;

    my $buff = <<DATA;
教え オシエル 教える 動詞-一般 下一段-ア行 連用形-一般 * * 和
て テ て 助詞-接続助詞 * * * * 和
下さい クダサル 下さる 動詞-非自立可能 五段-ラ行 命令形 * * 和
！ * ！ 補助記号-句点 * * * * 記号
DATA

    my $add_feature = AddFeature->new;
    my $res = $add_feature->add_feature($buff, $basename, "/tmp");
    my @lines = split /\n/, $res;

    is $lines[0], "教え オシエル 教える 動詞-一般 下一段-ア行 連用形-一般 * * 和 動詞 一般 * * 下一段 ア行 * 連用形 一般 *";
    is $lines[1], "て テ て 助詞-接続助詞 * * * * 和 助詞 接続助詞 * * * * * * * *";
    is $lines[2], "下さい クダサル 下さる 動詞-非自立可能 五段-ラ行 命令形 * * 和 動詞 非自立可能 * * 五段 ラ行 * 命令形 * *";
    is $lines[3], "！ * ！ 補助記号-句点 * * * * 記号 補助記号 句点 * * * * * * * *";
};

sub load_dic_auxv : Test(1) {
    my $data = <<DATA;
名詞 * *
か カ か 助詞-副助詞 * *
も モ も 助詞-係助詞 * *
しれ シレル 知れる 動詞-一般 下一段-ラ行-一般 連用形-一般
ませ マス ます 助動詞 助動詞-マス 未然形-一般
ん ズ ず 助動詞 助動詞-ヌ 終止形-撥音便
助詞

形容詞 形容詞 連体形
ん ノ の 助詞-準体助詞 * *
じゃ ダ だ 助動詞 助動詞-ダ 連用形-融合
ない ナイ 無い 形容詞-非自立可能 形容詞 終止形-一般
助詞

動詞 下一段 連用形
て テ て 助詞-接続助詞 * *
やり ヤル 遣る 動詞-非自立可能 五段-ラ行-一般 連用形-一般
助動詞

助動詞 下一段 連体形
の ノ の 助詞-準体助詞 * *
で ダ だ 助動詞 助動詞-ダ 連用形-一般
副詞

DATA

    my $fh = File::Temp->new;
    my $filename = $fh->filename;
    print $fh encode_utf8 $data;
    close $fh;

    my $add_feature = AddFeature->new;
    my $dic = $add_feature->load_dic($filename);

    is_deeply $dic, {
        5 => {
            "か カ か 助詞-副助詞 * *\nも モ も 助詞-係助詞 * *\nしれ シレル 知れる 動詞-一般 下一段-ラ行-一般 連用形-一般\nませ マス ます 助動詞 助動詞-マス 未然形-一般\nん ズ ず 助動詞 助動詞-ヌ 終止形-撥音便\n" => {
                "名詞 * *|助詞" => 1,
            },
        },
        3 => {
            "ん ノ の 助詞-準体助詞 * *\nじゃ ダ だ 助動詞 助動詞-ダ 連用形-融合\nない ナイ 無い 形容詞-非自立可能 形容詞 終止形-一般\n" => {
                "形容詞 形容詞 連体形|助詞" => 1,
            },
        },
        2 => {
            "て テ て 助詞-接続助詞 * *\nやり ヤル 遣る 動詞-非自立可能 五段-ラ行-一般 連用形-一般\n" => {
                "動詞 下一段 連用形|助動詞" => 1
            },
            "の ノ の 助詞-準体助詞 * *\nで ダ だ 助動詞 助動詞-ダ 連用形-一般\n" => {
                "助動詞 下一段 連体形|副詞" => 1
            },
        },
    };
};

sub load_dic_postp : Test(1) {
    my $data = <<DATA;
名詞 * *
と ト と 助詞-格助詞 * *
いえ イウ 言う 動詞-一般 五段-ワア行-イウ 仮定形-一般
ど ド ど 助詞-接続助詞 * *
も モ も 助詞-係助詞 * *
名詞

代名詞 * *
に ニ に 助詞-格助詞 * *
よれ ヨル 因る 動詞-一般 五段-ラ行-一般 仮定形-一般
ば バ ば 助詞-接続助詞 * *
補助記号

動詞 サ行変格 意志推量形
と ト と 助詞-格助詞 * *
いう イウ 言う 動詞-一般 五段-ワア行-イウ 連体形-一般
名詞

DATA

    my $fh = File::Temp->new;
    my $filename = $fh->filename;
    print $fh encode_utf8 $data;
    close $fh;

    my $add_feature = AddFeature->new;
    my $dic = $add_feature->load_dic($filename);

    is_deeply $dic, {
        4 => {
            "と ト と 助詞-格助詞 * *\nいえ イウ 言う 動詞-一般 五段-ワア行-イウ 仮定形-一般\nど ド ど 助詞-接続助詞 * *\nも モ も 助詞-係助詞 * *\n" => {
                "名詞 * *|名詞" => 1
            },
        },
        3 => {
            "に ニ に 助詞-格助詞 * *\nよれ ヨル 因る 動詞-一般 五段-ラ行-一般 仮定形-一般\nば バ ば 助詞-接続助詞 * *\n" => {
                "代名詞 * *|補助記号" => 1
            },
        },
        2 => {
            "と ト と 助詞-格助詞 * *\nいう イウ 言う 動詞-一般 五段-ワア行-イウ 連体形-一般\n" => {
                "動詞 サ行変格 意志推量形|名詞" => 1
            },
        },
    };
};

__PACKAGE__->runtests;

