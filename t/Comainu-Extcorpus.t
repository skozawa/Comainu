package t::Comainu::Extcorpus;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;
use Encode;

use Comainu::Method;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::Extcorpus';
}

sub cache_key : Tests {
    my $extcorpus = Comainu::Extcorpus->new;
    is $extcorpus->cache_key({
        sLabel => 'B',
        orth   => '村山',
        pron   => 'ムラヤマ',
        lForm  => 'ムラヤマ',
        lemma  => 'ムラヤマ',
        pos    => '名詞-固有名詞-人名-姓',
        cType  => '*',
        cForm  => '*',
    }), '*;*;ムラヤマ;ムラヤマ;村山;名詞-固有名詞-人名-姓;ムラヤマ;B';

    is $extcorpus->cache_key({
        sLabel => '',
        orth   => '年頭',
        pron   => 'ネントー',
        lForm  => 'ネントウ',
        lemma  => '年頭',
        pos    => '名詞-普通名詞-一般',
        cType  => '*',
        cForm  => '*',
    }), '*;*;ネントウ;年頭;年頭;名詞-普通名詞-一般;ネントー;';

    is $extcorpus->cache_key({
        sLabel => '',
        orth   => '。',
        pron   => '',
        lForm  => '',
        lemma  => '。',
        pos    => '補助記号-句点',
        cType  => '*',
        cForm  => '*',
    }), '*;*;;。;。;補助記号-句点;;';
}

sub run : Tests {
    my $comainu = Comainu::Method->new(
        "unidic-db" => "local/unidic2/unidic.db",
    );
    my $extcorpus = Comainu::Extcorpus->new(%$comainu);

    for my $i ( 1 .. 30 ) {
        my $input_file  = sprintf 't/sample/extcorpus/input%02d', $i;
        my $output_file = sprintf 't/sample/extcorpus/output%02d', $i;

        my $buff = $extcorpus->run($input_file);
        is $buff, read_from_file($output_file);
    }
}

sub _parse_input : Tests {
    my $comainu = Comainu::Method->new;
    my $extcorpus = Comainu::Extcorpus->new(%$comainu);

    is_deeply $extcorpus->_parse_input("B\t村山\tムラヤマ\tムラヤマ\tムラヤマ\t名詞-固有名詞-人名-姓\t\t"), {
        sLabel => 'B',
        orth   => '村山',
        pron   => 'ムラヤマ',
        lForm  => 'ムラヤマ',
        lemma  => 'ムラヤマ',
        pos    => '名詞-固有名詞-人名-姓',
        cType  => '*',
        cForm  => '*',
    };

    is_deeply $extcorpus->_parse_input("\t年頭\tネントー\tネントウ\t年頭\t名詞-普通名詞-一般\t\t"), {
        sLabel => '',
        orth   => '年頭',
        pron   => 'ネントー',
        lForm  => 'ネントウ',
        lemma  => '年頭',
        pos    => '名詞-普通名詞-一般',
        cType  => '*',
        cForm  => '*',
    };

    is_deeply $extcorpus->_parse_input("\tし\tシ\tスル\t為る\t動詞-非自立可能\tサ変可能\t連用形-一般"), {
        sLabel => '',
        orth   => 'し',
        pron   => 'シ',
        lForm  => 'スル',
        lemma  => '為る',
        pos    => '動詞-非自立可能',
        cType  => 'サ変可能',
        cForm  => '連用形-一般',
    };
}

sub search_outputs : Tests {
    my $comainu = Comainu::Method->new;
    my $extcorpus = Comainu::Extcorpus->new(%$comainu);

    subtest 'search normally' => sub {
        my $g = mock_guard('Comainu::Extcorpus', {
            select_from_db => sub {
                return +{
                    formOrthBase => 'ムラヤマ',
                    formOrth     => 'ムラヤマ',
                    formBase     => 'ムラヤマ',
                    form         => 'ムラヤマ',
                    goshu        => '固',
                };
            }
        });

        is_deeply $extcorpus->search_outputs({
            sLabel => 'B',
            orth   => '村山',
            pron   => 'ムラヤマ',
            lForm  => 'ムラヤマ',
            lemma  => 'ムラヤマ',
            pos    => '名詞-固有名詞-人名-姓',
            cType  => '*',
            cForm  => '*',
        }), {
            sLabel => 'B',
            orth   => '村山',
            pron   => 'ムラヤマ',
            lForm  => 'ムラヤマ',
            lemma  => 'ムラヤマ',
            pos    => '名詞-固有名詞-人名-姓',
            cType  => '',
            cForm  => '',
            formOrthBase => 'ムラヤマ',
            formOrth     => 'ムラヤマ',
            formBase     => 'ムラヤマ',
            form         => 'ムラヤマ',
            goshu        => '固',
        };
    };

    subtest 'search normally#2' => sub {
        my $g = mock_guard('Comainu::Extcorpus', {
            select_from_db => sub {
                return +{
                    formOrthBase => '。',
                    formOrth     => '。',
                    formBase     => '',
                    form         => '',
                    goshu        => '記号',
                };
            }
        });

        is_deeply $extcorpus->search_outputs({
            sLabel => '',
            orth   => '。',
            pron   => '',
            lForm  => '',
            lemma  => '。',
            pos    => '補助記号-句点',
            cType  => '*',
            cForm  => '*',
        }), {
            sLabel => '',
            orth   => '。',
            pron   => '',
            lForm  => '',
            lemma  => '。',
            pos    => '補助記号-句点',
            cType  => '',
            cForm  => '',
            formOrthBase => '。',
            formOrth     => '。',
            formBase     => '',
            form         => '',
            goshu        => '記号',
        };
    };
}

__PACKAGE__->runtests;
