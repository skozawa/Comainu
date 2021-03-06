package t::Comainu::SUWAnalysis;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

use Comainu::Method;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::SUWAnalysis';
}

# sub plain2mecab_file : Tests {};

sub mecab2kc_file : Tests {
    my $comainu = Comainu::Method->new(
        "mecab-dir"     => "local/bin",
        "mecab-dic-dir" => "local/lib/mecab/dic",
        "unidic-db"     => "local/unidic2/unidic.db",
    );
    my $suwanalysis = Comainu::SUWAnalysis->new(%$comainu);

    for my $i ( 1 .. 30 ) {
        my $input_file  = sprintf 't/sample/extcorpus/input%02d', $i;
        my $output_file = sprintf 't/sample/extcorpus/output%02d', $i;
        my ($tmp_file, $tmp_fh) = create_tmp_file("");

        $suwanalysis->mecab2kc_file($input_file, $tmp_file);

        is read_from_file($tmp_file), $suwanalysis->mecab2kc(read_from_file($output_file));
    }
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

    my $comainu = Comainu::Method->new;
    my $suwanalysis = Comainu::SUWAnalysis->new(%$comainu);
    is $suwanalysis->mecab2kc($data), $gold;
};

__PACKAGE__->runtests;
