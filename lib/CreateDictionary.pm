# -*- mode: perl; coding: utf-8; -*-
#
# 訓練対象KCファイルから辞書を構築する
#
package CreateDictionary;

use strict;
use warnings;
use utf8;

use Comainu::Util qw(read_from_file write_to_file);

sub new {
    my ($class, %args) = @_;

    bless {
        %args
    }, $class;
}

# 辞書を構築
# 以下の辞書を構築
#
# 複数の短単位から成る長単位「助詞」辞書
# 複数の短単位から成る長単位「助動詞」辞書
#
sub create_dictionary {
    my ($self, $train_kc, $dir, $NAME) = @_;

    my %postp;
    my %auxv;
    my $pre_sterm = "";

    my $buff = read_from_file($train_kc);
    my $state = 0;
    my $long_term = "";
    my @short_terms;
    foreach my $line (split(/\r?\n/,$buff)) {
        next unless $line;
        next if $line =~ /^\*B/;
        if ($line eq 'EOS') {
            if ($state == 8 && $#short_terms >= 2) {
                $postp{join("\n",@short_terms)} = $#short_terms;
            } elsif ($state == 9 && $#short_terms >= 2) {
                $auxv{join("\n",@short_terms)} = $#short_terms;
            }
            @short_terms = ();
            $state = 0;
            next;
        }

        my @items = split(/ /,$line);

        ## 長単位の先頭の短単位でない場合
        if ($items[13] eq '*') {
            if ($state == 8 || $state == 9) {
                push @short_terms,join(" ",@items[0..5]);
            }
        }
        ## 長単位を構成する先頭の短単位の場合
        else {
            ## 複数の短単位から成る場合は辞書に追加
            if($state == 8 && $#short_terms >= 2){
                # push @short_terms, "$items[3]";
                push @short_terms, (split(/\-/, $items[3]))[0];
                $postp{join("\n",@short_terms)} = $#short_terms;
            } elsif ($state == 9 && $#short_terms >= 2) {
                # push @short_terms, "$items[3]";
                push @short_terms, (split(/\-/, $items[3]))[0];
                $auxv{join("\n",@short_terms)} = $#short_terms;
            }

            if ($items[13] =~ /^助詞/) {
                $state = 8;
            } elsif ($items[13] =~ /^助動詞/) {
                $state = 9;
            } else {
                $state = 0;
            }

            @short_terms = ();
            if ($state == 8 || $state == 9) {
                push @short_terms,$pre_sterm;
                push @short_terms,join(" ",@items[0..5]);
            }
        }
        $pre_sterm = (split(/\-/, $items[3]))[0]." ".(split(/\-/, $items[4]))[0]." ".(split(/\-/, $items[5]))[0];
    }

    write_to_file(
        $dir . "/" . $NAME . ".Postp.dic",
        join("\n\n",sort {$postp{$b} <=> $postp{$a}} keys %postp)
    );
    write_to_file(
        $dir . "/" . $NAME . ".AuxV.dic",
        join("\n\n",sort {$auxv{$b}<=>$auxv{$a}} keys %auxv)
    );
}


1;
#################### END OF FILE ####################
