# -*- mode: perl; coding: utf-8; -*-

package Comainu;

use strict;
use FindBin qw($Bin);
use utf8;
use Encode;
use File::Basename;
use Config;

use SUW2LUW;
use LCSDiff;

my $DEFAULT_VALUES = {
    "debug" => 0,
    "comainu-home" => $Bin."/..",
    "comainu-temp" => $Bin."/../tmp/temp",
    "comainu-svm-bip-model" => $Bin."/../train/BI_process_model",
    "data_format" => $Bin."/../etc/data_format.conf",
    "mecab_rcfile" => $Bin."/../etc/dicrc",
    "perl" => "/usr/bin/perl",
    "java" => "/usr/bin/java",
    "yamcha-dir" => "/usr/local/bin",
    "mecab-dir" => "/usr/local/bin",
    "mecab-dic-dir" => "/usr/local/lib/mecab/dic",
    "unidic-db" => "/usr/local/unidic2/share/unidic.db",
    "svm-tool-dir" => "/usr/local/bin",
    "crf-dir" => "/usr/local/bin",
    "mstparser-dir" => "mstparser",
    "boundary" => "none",
    "luwmrph" => "with",
    "suwmodel" => "mecab",
    "luwmodel" => "CRF",
    "bnst_process" => "none",
};

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {%$DEFAULT_VALUES, @_};
    bless $self, $class;
    return $self;
}



############################################################
# ファイルのマージ
############################################################
sub merge_bccwj_with_kc_lout_file {
    my ($self, $bccwj_file, $kc_lout_file, $lout_file) = @_;
    my $bccwj_data = $self->read_from_file($bccwj_file);
    my $kc_lout_data = $self->read_from_file($kc_lout_file);
    my $lout_data = $self->merge_iof($bccwj_data, $kc_lout_data);
    undef $bccwj_data;
    undef $kc_lout_data;

    $self->write_to_file($lout_file, $lout_data);
    undef $lout_data;
}

# bccwj形式のファイルに長単位解析結果をマージ
sub merge_iof {
    my ($self, $bccwj_data, $lout_data) = @_;
    my $res = "";
    my $cn1 = 16;
    # my $cn1 = 26;
    if ( $self->{"boundary"} eq "word" ) {
        # $cn1 = 23;
        $cn1 = 27;
        # $cn1 = 34;
    }
    my $cn2 = 19;
    $lout_data =~ s/^EOS.*?\n//mg;
    my @m = split(/\r?\n/, $lout_data);
    undef $lout_data;

    my $long_pos = "";
    foreach ( split(/\r?\n/, $bccwj_data) ) {
        my @morph = split(/\t/);
        if ($#morph+1 < $cn1) {
            print STDERR "Some columns are missing in bccwj_data!\n";
            print STDERR "  morph(".($#morph+1).") < sn1(".$cn1.")\n";
        }
        my $lw = shift(@m);
        $lw = shift(@m) if($lw =~ /^EOS|^\*B/);
        my @ml = split(/[ \t]/, $lw);
        if ($#ml+1 < $cn2) {
            print STDERR "Some columns are missing in bccwj_data!\n";
            print STDERR "  ml(".($#ml+1).") < cn2(".$cn2.")\n";
            print STDERR "$ml[1]\n";
        }
        if ($morph[4] ne $ml[1]) {
            print STDERR "Two files cannot be marged!: '$morph[4]' ; '$ml[1]'\n";
        }
        if ($ml[0] =~ /^B/) {
            $long_pos = $ml[14];
        }
        if ( $self->{boundary} eq "word" ) {
            @morph[28..33] = @ml[19,17..18,14..16];
        } else {
            @morph[27..33] = @ml[0,19,17..18,14..16];
        }
        if ( $morph[8] eq "名詞-普通名詞-形状詞可能" ||
                 $morph[8] eq "名詞-普通名詞-サ変形状詞可能" ) {
            if ( $long_pos eq "形状詞-一般" ) {
                $morph[11] = "形状詞";
            } else {
                $morph[11] = "名詞";
            }
        } elsif ( $morph[8] eq "名詞-普通名詞-副詞可能" ) {
            if ( $long_pos eq "副詞" ) {
                $morph[11] = "副詞";
            } else {
                $morph[11] = "名詞";
            }
        }
        my $nm = join("\t", @morph);
        $res .= "$nm\n";
    }

    undef $bccwj_data;

    if ( $#m > -1 ) {
        print STDERR "Two files do not correspond to each other!\n";
    }
    return $res;
}

sub merge_bccwj_with_kc_bout_file {
    my ($self, $bccwj_file, $kc_bout_file, $bout_file) = @_;
    my $bccwj_data = $self->read_from_file($bccwj_file);
    my $kc_bout_data = $self->read_from_file($kc_bout_file);
    my @m = split(/\r?\n/, $kc_bout_data);
    undef $kc_bout_data;

    my $bout_data = "";
    foreach ( split(/\r?\n/, $bccwj_data) ) {
        my $item_list = [split(/\t/)];
        my $lw = shift(@m);
        $lw = shift(@m) if $lw =~ /^EOS|^\*B/;
        my @ml = split(/[ \t]/, $lw);
        $$item_list[26] = $ml[0];
        $bout_data .= join("\t",@$item_list)."\n";
    }
    undef $bccwj_data;

    $self->write_to_file($bout_file, $bout_data);
    undef $bout_data;
}

sub merge_bccwj_with_kc_mout_file {
    my ($self, $bccwj_file, $kc_mout_file, $mout_file) = @_;
    my $bccwj_data = $self->read_from_file($bccwj_file);
    my $kc_mout_data = $self->read_from_file($kc_mout_file);
    my @m = split(/\r?\n/, $kc_mout_data);
    undef $kc_mout_data;

    my $mout_data = "";
    foreach ( split(/\r?\n/, $bccwj_data) ) {
        my $item_list = [split(/\t/)];
        my $lw = shift(@m);
        $lw = shift(@m) if $lw =~ /^EOS|^\*B/;
        my @ml = split(/[ \t]/, $lw);
        @$item_list[34..36] = @ml[19..21];
        $mout_data .= join("\t",@$item_list)."\n";
    }
    undef $bccwj_data;

    $self->write_to_file($mout_file, $mout_data);
    undef $mout_data;
}

sub merge_mecab_with_kc_lout_file {
    my ($self, $mecab_file, $kc_lout_file, $lout_file) = @_;
    my $mecab_data = $self->read_from_file($mecab_file);
    my $kc_lout_data = $self->read_from_file($kc_lout_file);
    my $kc_lout_data_list = [ split(/\r?\n/, $kc_lout_data) ];
    undef $kc_lout_data;

    my $lout_data = "";
    foreach my $mecab_line ( split(/\r?\n/, $mecab_data) ) {
        if ( $mecab_line =~ /^EOS|^\*B/ ) {
            $lout_data .= $mecab_line."\n";
            next;
        }
        my $mecab_item_list = [ split(/\t/, $mecab_line, -1) ];
        my $kc_lout_line = shift(@$kc_lout_data_list);
        $kc_lout_line = shift(@$kc_lout_data_list) if $kc_lout_line =~ /^EOS/;
        my $kc_lout_item_list = [ split(/[ \t]/, $kc_lout_line) ];
        push(@$mecab_item_list, splice(@$kc_lout_item_list, 14, 6));
        $lout_data .= sprintf("%s\n", join("\t", @$mecab_item_list));
    }
    undef $mecab_data;
    undef $kc_lout_data_list;

    $self->write_to_file($lout_file, $lout_data);
    undef $lout_data;
}

sub merge_mecab_with_kc_bout_file {
    my ($self, $mecab_file, $kc_bout_file, $bout_file) = @_;
    my $mecab_data = $self->read_from_file($mecab_file);
    my $kc_bout_data = $self->read_from_file($kc_bout_file);
    my $kc_bout_data_list = [split(/\r?\n/, $kc_bout_data)];
    undef $kc_bout_data;

    my $bout_data = "";
    foreach my $mecab_line ( split(/\r?\n/, $mecab_data) ) {
        my $kc_bout_line = shift @$kc_bout_data_list;
        $bout_data .= "*B\n" if $kc_bout_line =~ /B/;
        $bout_data .= $mecab_line."\n" if $mecab_line !~ /^\*B/;
    }
    undef $mecab_data;
    undef $kc_bout_data_list;

    $self->write_to_file($bout_file, $bout_data);
    undef $bout_data;
}

sub merge_mecab_with_kc_mout_file {
    my ($self, $mecab_file, $kc_mout_file, $mout_file) = @_;
    my $mecab_data = $self->read_from_file($mecab_file);
    my $kc_mout_data = $self->read_from_file($kc_mout_file);
    my $kc_mout_data_list = [split(/\r?\n/, $kc_mout_data)];
    undef $kc_mout_data;

    my $mout_data = "";
    foreach my $mecab_line ( split(/\r?\n/, $mecab_data) ) {
        if ( $mecab_line =~ /^EOS|^\*B/ ) {
            $mout_data .= $mecab_line."\n";
            next;
        }
        my $mecab_item_list = [ split(/\t/, $mecab_line, -1) ];
        my $kc_mout_line = shift @$kc_mout_data_list;
        $kc_mout_line = shift @$kc_mout_data_list if $kc_mout_line =~ /^EOS/;
        my $kc_mout_item_list = [ split(/[ \t]/, $kc_mout_line) ];
        push(@$mecab_item_list, splice(@$kc_mout_item_list, 14, 9));
        $mout_data .= sprintf("%s\n", join("\t", @$mecab_item_list));
    }
    undef $mecab_data;
    undef $kc_mout_data_list;

    $self->write_to_file($mout_file, $mout_data);
    undef $mout_data;
}

sub merge_kc_with_svmout {
    my ($self, $kc_file, $svmout_file) = @_;

    my $res = "";
    my @long;
    my $kc_data = $self->read_from_file($kc_file);
    my $svmout_data = $self->read_from_file($svmout_file);
    my $svmout_data_list = [split(/\r?\n/, $svmout_data)];
    undef $svmout_data;

    foreach my $kc_data_line ( split(/\r?\n/, $kc_data) ) {
    	if ( $kc_data_line =~ /^EOS/ && $self->{luwmrph} eq "without" ) {
    	    $res .= "EOS\n";
    	    next;
    	}
    	next if $kc_data_line =~ /^\*B|^EOS/;
    	my @kc_item_list = split(/[ \t]/, $kc_data_line);

    	my $svmout_line = shift(@$svmout_data_list);
    	my $svmout_item_list = [split(/[ \t]/, $svmout_line)];
    	@$svmout_item_list[10..15] = ("*","*","*","*","*","*");

        if ( $$svmout_item_list[0] eq "B" || $$svmout_item_list[0] eq "Ba") {
            map { $res .= join(" ",@$_)."\n" } @long;

            @long = ();
            if ( $self->{"luwmrph"} ne "without" ) {
                @$svmout_item_list[10..15] = @$svmout_item_list[4..6,2,3,1];
            } else {
                @$svmout_item_list[13..15] = @$svmout_item_list[2,3,1];
            }
        } else {
            my $first = $long[0];
            $$first[17] .= $$svmout_item_list[2];
            $$first[18] .= $$svmout_item_list[3];
            $$first[19] .= $$svmout_item_list[1];
            if ( $$svmout_item_list[0] eq "Ia" &&
                     $self->{"luwmrph"} ne "without") {
                @$first[14..16] = @$svmout_item_list[4..6];
            }
        }
        push @long, [@$svmout_item_list[0],@kc_item_list[0..12],@$svmout_item_list[10..15]];
    }

    map { $res .= join(" ",@$_)."\n" } @long;

    undef $kc_data;
    undef $svmout_data_list;
    undef @long;

    return $res;
}

sub merge_kc_with_bout {
    my ($self, $kc_file, $bout_file) = @_;

    my $res = "";
    my $kc_data = $self->read_from_file($kc_file);
    my $bout_data = $self->read_from_file($bout_file);
    my $bout_data_list = [split(/\r?\n/, $bout_data)];
    undef $bout_data;

    foreach my $kc_data_line (split(/\r?\n/, $kc_data)) {
    	next if $kc_data_line =~ /^\*B/;

        if ( $kc_data_line =~ /^EOS/ ) {
    	    $res .= "EOS\n";
    	    next;
    	}
    	my @kc_item_list = split(/[ \t]/, $kc_data_line);
    	my $bout_line = shift(@$bout_data_list);
    	my $bout_item_list = [split(/[ \t]/, $bout_line)];
    	$res .= $$bout_item_list[0]." ".join(" ",@kc_item_list[0..12])."\n";
    }

    undef $kc_data;
    undef $bout_data_list;

    return $res;
}


############################################################
# 使ってない関数
############################################################
# 文節情報に基づいたカラムを追加して出力する
# 付加条件：
# 前の行に*Bや*Pがある場合は L
# 後ろの行に*Bや*Pがある場合は R
# 両方にある場合は B
# どちらにも無い場合はN
# ファイル終端行は R または B
sub add_column {
    my ($self, $data) = @_;
    my $res = "";
    my ($prev, $curr, $next) = (0, 1, 2);
    my $buff_list = [undef, undef];

    $data .= "*B\n";
    foreach my $line ((split(/\r?\n/, $data), undef, undef)) {
        push(@$buff_list, $line);
        if ( defined $buff_list->[$curr] && $buff_list->[$curr] !~ /^EOS/ &&
                 $buff_list->[$curr] !~ /^\*B/ ) {
            my $mark = "";
            if ( $buff_list->[$prev] =~ /^\*B/ && $buff_list->[$next] =~ /^\*B/) {
                $mark = "B";
            } elsif ( $buff_list->[$prev] =~ /^\*B/ ) {
                $mark = "L";
            } elsif ( $buff_list->[$next] =~ /^\*B/ ) {
                $mark = "R";
            } else {
                $mark = "N";
            }
            $buff_list->[$curr] .= " ".$mark;
        }
        my $new_line = shift(@$buff_list);
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }
    while ( my $new_line = shift(@$buff_list) ) {
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }

    undef $data;
    undef $buff_list;

    return $res;
}

#
# poscreateの代わりの関数
# 長単位の品詞・活用型・活用形を生成
#
sub poscreate {
    my ($self, $file) = @_;
    my $res = "";

    my @long;
    open(IN, $file);
    while ( my $line = <IN> ) {
        $line = Encode::decode("utf-8", $line);
        $line =~ s/\r?\n//;
        next if $line eq "";
        my @items = split(/[ \t]/, $line);

        # $items[10] = "*";
        # $items[11] = "*";
        @items[10..15] = ("*","*","*","*","*","*");

        if ( $self->{"luwmrph"} ne "without" ) {
            if ( $items[0] eq "B" || $items[0] eq "Ba" ) {
                map { $res .= join(" ",@$_)."\n" } @long;

                @long = ();
                @items[10..15] = @items[4..6,2,3,1];
            } else {
                my $first = $long[0];
                $$first[13] .= $items[2];
                $$first[14] .= $items[3];
                $$first[15] .= $items[1];
                if ( $items[0] eq "Ia" ) {
                    @$first[10..12] = @items[4..6];
                }
            }
        }
        push @long, [@items[0..15]];
    }
    close(IN);
    map { $res .= join(" ",@$_)."\n" } @long;

    undef @long;

    return $res;
}

# 後処理（「動詞」となる長単位の活用型、活用形）
# アドホックな後処理-->書き換え規則を変更する方針
sub pp_ctype {
    my ($self, $data) = @_;
    my $res = "";
    my @lw;
    foreach ( split(/\r?\n/, $data) ) {
        if (/^B/) {
            if ($#lw > -1) {
                my @last = split(/[ \t]/, $lw[$#lw]);
                if ($last[8] ne "*") {
                    my @first = split(/[ \t]/, shift(@lw));
                    if ($first[13] eq "*" && $first[12] =~ /^動詞/) {
                        $first[13] = $last[7];
                   }
                    if ($first[14] eq "*" && $first[12] =~ /^動詞/) {
                        $first[14] = $last[8];
                    }
                    unshift(@lw, join(" ", @first));
                }
                foreach (@lw) {
                    # print "$_\n";
                    $res .= "$_\n";
                }
                @lw = ();
                push(@lw, $_);
            } else {
                push(@lw, $_);
            }
        } else {
            push(@lw, $_);
        }
    }
    undef $data;

    if ($#lw > -1) {
        my @last = split(/[ \t]/, $lw[$#lw]); # fixed by jkawai
        if ($last[8] ne "*") {
            my @first = split(/[ \t]/, $lw[0]);
            if ($first[13] eq "*" && $first[12] =~ /^動詞/) {
                $first[13] = $last[7];
            }
            if ($first[14] eq "*" && $first[12] =~ /^動詞/) {
                $first[14] = $last[8];
            }
        }
        foreach (@lw) {
            # print "$_\n";
            $res .= "$_\n";
        }
    }
    return $res;
}


############################################################
# Utilities
############################################################
sub read_from_file {
    my ($self, $file) = @_;
    my $data = "";
    open(my $fh, $file) or die "Cannot open '$file'";
    binmode($fh);
    while ( my $line = <$fh> ) {
        $data .= $line;
    }
    close($fh);
    $data = Encode::decode("utf-8", $data);
    return $data;
}

sub write_to_file {
    my ($self, $file, $data) = @_;
    $data = Encode::encode("utf-8", $data) if Encode::is_utf8($data);
    open(my $fh, ">", $file) or die "Cannot open '$file'";
    binmode($fh);
    print $fh $data;
    close($fh);
    undef $data;
}


1;
#################### END OF FILE ####################
