package Comainu::Format;

use strict;
use warnings;
use utf8;

use Comainu::Util qw(read_from_file write_to_file check_file);

# 入力用のフォーマットに変換
sub format_inputdata {
    my ($class, $args) = @_;

    my $buff = read_from_file($args->{input_file});
    $buff = $class->trans_dataformat($buff, $args);
    write_to_file($args->{output_file}, $buff);
    undef $buff;
}

# 入力形式を内部形式に変換
sub trans_dataformat {
    my ($class, $input_data, $args) = @_;

    check_file($args->{data_format_file});

    my $data = read_from_file($args->{data_format_file});
    my %formats;
    foreach my $line (split(/\r?\n/, $data)) {
        my ($type, $format) = split(/\t/,$line);
        $formats{$type} = $format;
    }
    $formats{kc} = "orthToken,reading,lemma,pos,cType,cForm,form,formBase,formOrthBase,formOrth,charEncloserOpen,charEncloserClose,wType,l_pos,l_cType,l_cForm,l_reading,l_lemma,l_orthToken";
    $formats{bccwj} = "file,start,end,BOS,orthToken,reading,lemma,meaning,pos,cType,cForm,usage,pronToken,pronBase,kana,kanaBase,form,formBase,formOrthBase,formOrth,orthBase,wType,charEncloserOpen,charEncloserClose,originalText,order,BOB,LUW,l_orthToken,l_reading,l_lemma,l_pos,l_cType,l_cForm";
    $formats{kc_mid} = "orthToken,reading,lemma,pos,cType,cForm,form,formBase,formOrthBase,formOrth,charEncloserOpen,charEncloserClose,wType,l_pos,l_cType,l_cForm,l_reading,l_lemma,l_orthToken,depend,MID,m_orthToken";

    my %in_format = ();
    my @items = split(/,/,$formats{$args->{input_type}});
    for my $i ( 0 .. $#items ) {
        $in_format{$items[$i]} = $i;
    }

    return $input_data if $formats{$args->{input_type}} eq $formats{$args->{output_type}};

    my @out_format = split /,/, $formats{$args->{output_type}};
    my @trans_table = ();
    for my $i ( 0 .. $#out_format ) {
        $trans_table[$i] = $in_format{$out_format[$i]} // '*';
    }
    my $res = [];
    foreach my $line ( split(/\r?\n/,$input_data) ) {
        if ( $line =~ /^EOS|^\*B/ ) {
            push @$res, $line;
            next;
        }
        my @items = $args->{input_type} =~ /bccwj/ ? split(/\t/, $line) : split(/ /, $line);

        my @tmp_buff = ();
        for my $i ( 0 .. $#trans_table ) {
            if ( $trans_table[$i] eq "*" || $trans_table[$i] eq "NULL" ) {
                $tmp_buff[$i] = "*";
            } else {
                my $item = $items[$trans_table[$i]] // "";
                if ( $item eq "" || $item eq "NULL" || $item eq "\0" ) {
                    $tmp_buff[$i] = "*";
                } else {
                    $tmp_buff[$i] = $item;
                }
            }
        }
        my $out;
        if ( $args->{output_type} eq "kc" ) {
            $out = join " ", @tmp_buff;
        } elsif ( $args->{output_type} eq "bccwj" ) {
            $out = join "\t", @tmp_buff;
        } elsif ( $args->{output_type} eq "kc_mid" ) {
            $out = join " ", @tmp_buff;
        }
        push @$res, $out;
    }

    undef $input_data;

    return join "\n", @$res;
}


1;
