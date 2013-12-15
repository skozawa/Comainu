package t::Comainu::Format;
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
    use_ok 'Comainu::Format';
}

# sub format_inputdata : Tests {};
sub trans_dataformat : Test(3) {
    my $comainu = Comainu->new;
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
};


__PACKAGE__->runtests;
