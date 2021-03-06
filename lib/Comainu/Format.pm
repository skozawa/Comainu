package Comainu::Format;

use strict;
use warnings;
use utf8;
use Encode;

use Comainu::Util qw(read_from_file write_to_file check_file);

# format input data
sub format_inputdata {
    my ($class, $args) = @_;

    my $buff = read_from_file($args->{input_file});
    $buff = $class->trans_dataformat($buff, $args);
    write_to_file($args->{output_file}, $buff);
    undef $buff;
}

# translate input data into internal format data
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


## kclong2midout
sub merge_kc_with_mstout {
    my ($class, $kc_file, $out_file) = @_;
    my $res = "";

    my $out_long = [];
    my $long_word = "";
    foreach my $line ( split(/\r?\n/, read_from_file($out_file)) ) {
        if ( $line eq "" ){
            next if $long_word eq "";
            push @$out_long, $long_word;
            $long_word = "";
        } else {
            $long_word .= $line."\n";
        }
    }
    push @$out_long, $long_word if $long_word ne "";

    my $pos = 0;
    my $mid = -1;
    my $kc_long = [];
    foreach my $line ( split(/\r?\n/, read_from_file($kc_file)) ) {
    	next if $line eq "";
        if ( $line =~ /^EOS/ ) {
            $res .= $class->create_middle($kc_long, $out_long, \$mid, $pos);
            $pos = 0;
            $res .= "EOS\n";
            $mid = -1;
            $kc_long = [];
        } elsif ( $line =~ /^\*B/ ) {
        } else {
            my @items = split(/[ \t]/, $line);
            if ( $items[13] ne "*" ) {
                $res .= $class->create_middle($kc_long, $out_long, \$mid, $pos);
                $pos += scalar(@$kc_long);
                $kc_long = [];
                push @$kc_long, \@items;
            } else {
                push @$kc_long, \@items;
            }
        }
    }

    undef $out_long;
    undef $kc_long;

    return $res;
}

# recognize boundary of middle-unit-word
sub create_middle {
    my ($class, $kc_long, $out_long, $ref_mid, $pos) = @_;
    my $res = "";

    my %sp_prefix = ("各" => 1, "計" => 1, "現" => 1, "全" => 1, "非" => 1, "約" => 1);

    if ( scalar(@$kc_long) < 1 ) {
        return "";
    } elsif ( scalar(@$kc_long) == 1 ) {
        my @items = split(/[ \t]/, $$kc_long[0]);
        $$ref_mid++;
        $res .= join(" ", @{$$kc_long[0]}[0..18]) . " * " . $$ref_mid . " " . join(" ",@{$$kc_long[0]}[0..0]) . "\n";
    } elsif ( ${$$kc_long[0]}[13] =~ /^形状詞/ ) {
        $$ref_mid++;
        my @out = map {
            [ split /\t/ ]
        } split(/\r?\n/, shift @$out_long);

        my @mid_text;
        for my $i ( 0 .. $#{$kc_long} ) {
            $mid_text[0] .= ${$$kc_long[$i]}[0];
        }

        $res .= join(" ",@{$$kc_long[0]}[0..18]) . " " . ($pos+${$out[0]}[6]-1) . " " . $$ref_mid . " " . join(" ",@mid_text) . "\n";
        for my $i ( 1 .. $#{$kc_long}-1 ) {
            $res .= join(" ",@{$$kc_long[$i]}[0..18]) . " " . ($pos+${$out[$i]}[6]-1) . " " . $$ref_mid . "\n";
        }
        $res .= join(" ",@{$$kc_long[$#{$kc_long}]}[0..18]) . " * " . $$ref_mid . "\n";
    } else {
        my @out = map {
            [ split /\t/ ]
        } split(/\r?\n/, shift @$out_long);

        my $mid_pos = 0;
        for my $i ( 0 .. $#out ) {
            my $long = $$kc_long[$i];
            @$long[21..25] = ("", "", "", "", "");
            ${$$kc_long[$mid_pos]}[21] .= $$long[0];

            if ( ${$out[$i]}[6] == 0 ) {
                $$long[19] = "*";
                $mid_pos = $i+1;
                next;
            }
            if ( $i < $#out && ${$out[$i+1]}[3] eq "補助記号" ) {
                $mid_pos = $i+1;
            } elsif ( $i < $#out && ${$out[$i+1]}[3] eq "接頭辞" &&
                          defined $sp_prefix{${$out[$i+1]}[2]} ) {
                $mid_pos = $i+1;
            } elsif ( ${$out[$i]}[3] eq "補助記号" ) {
                $mid_pos = $i+1;
            } elsif ( ${$out[$i]}[7] eq "P" ) {
                if ( ${$out[$i]}[3] ne "接頭辞" ) {
                    $mid_pos = $i+1;
                }
            } elsif ( $$long[3] =~ /^接頭辞/ ) {
                if ( defined $sp_prefix{$$long[2]} ) {
                    $mid_pos = $i+1;
                }
            } elsif ( $i < $#out-1 && ${$out[$i+1]}[0] != ${$out[$i]}[6] ) {
                if ( ${$out[$i+2]}[0] == ${$out[$i]}[6] &&
                         ( (${$out[$i+2]}[3] eq "名詞" && ${$out[$i+1]}[3] eq "接頭辞") ||
                               (${$out[$i+2]}[3] eq "接尾辞" && ${$out[$i+1]}[3] eq "名詞")) ) {
                    # $mid_pos = $i+1;
                } else {
                    $mid_pos = $i+1;
                }
            }
            $$long[19] = $pos+${$out[$i]}[6] - 1;
        }
        for my $i ( 0 .. scalar(@$kc_long) - 1 ) {
            my $long = $$kc_long[$i];
            if ( $$long[21] ne "" ) {
                $$ref_mid++;
                $res .= join(" ",@$long[0..19]) . " " . $$ref_mid . " " . $$long[21];
            } else {
                $res .= join(" ",@$long[0..19]) . " " . $$ref_mid;
            }
            $res .= "\n";
        }
    }

    return $res;
}

# move last index to first
sub move_future_front {
    my ($class, $data) = @_;
    my $res = "";
    my $num_of_column = 12;
    foreach my $line ( split /\r?\n/, $data ) {
        my $items = [ split /[ \t]/, $line ];
        if ( scalar @$items == 1 ) {
            $res .= $line . "\n";
            next;
        }
        while ( scalar @$items < $num_of_column ) {
            push @$items, "";
        }
        $items = [ @$items[scalar(@$items) - 1, 0 .. scalar(@$items) - 2 ]];
        $res .= join(" ", @$items)."\n";
    }
    undef $data;
    return $res;
}

############################################################
# translate format
############################################################
# translate BCCWJ into KC
sub bccwj2kc_file {
    my ($class, $bccwj_file, $kc_file, $boundary) = @_;
    my $buff = read_from_file($bccwj_file);
    $buff = $class->bccwj2kc($buff, "", $boundary);
    write_to_file($kc_file, $buff);
    undef $buff;
}

sub bccwjlong2kc_file {
    my ($class, $bccwj_file, $kc_file, $boundary) = @_;
    my $buff = read_from_file($bccwj_file);
    $buff = $class->bccwj2kc($buff, "with_luw", $boundary);
    write_to_file($kc_file, $buff);
    undef $buff;
}

sub bccwj2kc {
    my ($class, $data, $type, $boundary) = @_;
    # my $cn = 17;
    my $cn = 27;
    if ( $boundary eq "word" || $type eq "with_luw" ) {
        # $cn = 24;
        # $cn = 25;
        $cn = 34;
    }
    my $res = "";
    foreach ( split(/\r?\n/, $data) ) {
        # chomp;
        my @suw = split(/\t/);
        $res .= "EOS\n" if $res ne "" && $suw[3] =~ /^B/;

        if( ($boundary eq "word" || $type eq "with_luw") && $suw[27] =~ /B/ ) {
            $res .= "*B\n";
        }
        $suw[6] = $suw[5] if $suw[6] eq "" || $suw[6] =~ /NULL/;
        $suw[7] = $suw[5] if $suw[7] eq "" || $suw[7] =~ /NULL/;

        for my $i ( 0 .. $cn ) {
            $suw[$i] = "*" if ($suw[$i] // "") eq "" || $suw[$i] =~ /NULL/;
        }

        $res .= "$suw[4] $suw[5] $suw[6] $suw[8] $suw[9] $suw[10] ";
        $res .= "$suw[16] $suw[17] $suw[18] $suw[19] $suw[22] $suw[23] $suw[21] ";

        if ( $type eq "with_luw" && $suw[27] =~ /B/ ) {
            $res .= "$suw[31] $suw[32] $suw[33] $suw[29] $suw[30] $suw[28]\n";
        } else {
            $res .= "* * * * * *\n";
        }
    }

    undef $data;

    return $res;
}

# translate lout into kclong (bccwj2mid*, plain2mid*)
sub lout2kc4mid_file {
    my ($class, $kc_lout_file, $kc_file) = @_;

    my $kc_lout_data = read_from_file($kc_lout_file);
    my $kc_buff = "";
    foreach my $line ( split(/\r?\n/, $kc_lout_data) ) {
        my @items = split(/[ \t]/, $line);
        if ( $items[0] =~ /^EOS/ ) {
            $kc_buff .= "EOS\n";
            next;
        }
        $kc_buff .= join(" ", @items[1..$#items-1])."\n";
    }
    write_to_file($kc_file, $kc_buff);

    undef $kc_lout_data;
    undef $kc_buff;
}



############################################################
# Merge files
############################################################
# merge bccwj and lout file
sub merge_bccwj_with_kc_lout_file {
    my ($class, $bccwj_file, $kc_lout_file, $boundary, $lout_file) = @_;
    my $bccwj_data = read_from_file($bccwj_file);
    my $kc_lout_data = read_from_file($kc_lout_file);
    my $lout_data = $class->merge_iof($bccwj_data, $kc_lout_data, $boundary);
    undef $bccwj_data;
    undef $kc_lout_data;

    return $lout_data unless $lout_file;

    write_to_file($lout_file, $lout_data);
    undef $lout_data;
}

sub merge_iof {
    my ($class, $bccwj_data, $lout_data, $boundary) = @_;
    my $res = "";
    my $cn1 = 16;
    # my $cn1 = 26;
    if ( $boundary eq "word" ) {
        # $cn1 = 23;
        $cn1 = 27;
        # $cn1 = 34;
    }
    my $cn2 = 19;
    $lout_data =~ s/^EOS.*?\n//mg;
    my @m = split /\r?\n/, $lout_data;
    undef $lout_data;

    my $long_pos = "";
    foreach ( split /\r?\n/, $bccwj_data ) {
        my @morph = split /\t/;
        if ($#morph+1 < $cn1) {
            print STDERR "Some columns are missing in bccwj_data!\n";
            print STDERR "  morph(".($#morph+1).") < sn1(".$cn1.")\n";
        }
        my $lw = shift @m;
        $lw = shift @m if $lw && $lw =~ /^EOS|^\*B/;
        my @ml = split /[ \t]/, $lw;
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
        $morph[$_] //= '' for (0..27);
        if ( $boundary eq "word" ) {
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
        $res .= join("\t", @morph) . "\n";
    }

    undef $bccwj_data;

    if ( $#m > -1 ) {
        print STDERR "Two files do not correspond to each other!\n";
    }
    return $res;
}

sub merge_bccwj_with_kc_bout_file {
    my ($class, $bccwj_file, $kc_bout_file, $bout_file) = @_;
    my $bccwj_data   = read_from_file($bccwj_file);
    my $kc_bout_data = read_from_file($kc_bout_file);
    my @m = split /\r?\n/, $kc_bout_data;
    undef $kc_bout_data;

    my $bout_data = "";
    foreach ( split /\r?\n/, $bccwj_data ) {
        my @item_list = split /\t/;
        my $lw = shift @m;
        $lw = shift @m if $lw && $lw =~ /^EOS|^\*B/;
        my @ml = split /[ \t]/, $lw;
        $item_list[$_] //= '' for (0..25);
        $item_list[26] = $ml[0];
        $bout_data .= join("\t", @item_list) . "\n";
    }
    undef $bccwj_data;

    return $bout_data unless $bout_file;

    write_to_file($bout_file, $bout_data);
    undef $bout_data;
}

sub merge_bccwj_with_kc_mout_file {
    my ($class, $bccwj_file, $kc_mout_file, $mout_file) = @_;
    my $bccwj_data   = read_from_file($bccwj_file);
    my $kc_mout_data = read_from_file($kc_mout_file);
    my @m = split /\r?\n/, $kc_mout_data;
    undef $kc_mout_data;

    my $mout_data = "";
    foreach ( split /\r?\n/, $bccwj_data ) {
        my @item_list = split /\t/;
        my $lw = shift @m;
        $lw = shift @m if $lw && $lw =~ /^EOS|^\*B/;
        my @ml = split /[ \t]/, $lw // "";
        $item_list[$_] //= '' for (0..33);
        # @item_list[34..36] = @ml[19..21];
        $item_list[$_ + 15] = $ml[$_] // '' for (19..21);
        $mout_data .= join("\t", @item_list) . "\n";
    }
    undef $bccwj_data;

    return $mout_data unless $mout_file;

    write_to_file($mout_file, $mout_data);
    undef $mout_data;
}

sub merge_mecab_with_kc_lout_file {
    my ($class, $mecab_file, $kc_lout_file, $lout_file) = @_;
    my $mecab_data   = read_from_file($mecab_file);
    my $kc_lout_data = read_from_file($kc_lout_file);
    my $kc_lout_data_list = [ split /\r?\n/, $kc_lout_data ];
    undef $kc_lout_data;

    my $lout_data = "";
    foreach my $mecab_line ( split /\r?\n/, $mecab_data ) {
        if ( $mecab_line =~ /^EOS|^\*B/ ) {
            $lout_data .= $mecab_line."\n";
            next;
        }
        my $mecab_item_list = [ split(/\t/, $mecab_line, -1) ];
        my $kc_lout_line = shift @$kc_lout_data_list;
        $kc_lout_line = shift @$kc_lout_data_list if $kc_lout_line =~ /^EOS/;
        my $kc_lout_item_list = [ split /[ \t]/, $kc_lout_line ];
        push(@$mecab_item_list, splice(@$kc_lout_item_list, 14, 6));
        $lout_data .= sprintf("%s\n", join("\t", @$mecab_item_list));
    }
    undef $mecab_data;
    undef $kc_lout_data_list;

    return $lout_data unless $lout_file;

    write_to_file($lout_file, $lout_data);
    undef $lout_data;
}

sub merge_mecab_with_kc_bout_file {
    my ($class, $mecab_file, $kc_bout_file, $bout_file) = @_;
    my $mecab_data   = read_from_file($mecab_file);
    my $kc_bout_data = read_from_file($kc_bout_file);
    my $kc_bout_data_list = [ split /\r?\n/, $kc_bout_data ];
    undef $kc_bout_data;

    my $bout_data = "";
    foreach my $mecab_line ( split /\r?\n/, $mecab_data ) {
        my $kc_bout_line = shift @$kc_bout_data_list;
        $bout_data .= "*B\n" if $kc_bout_line =~ /B/;
        $bout_data .= $mecab_line."\n" if $mecab_line !~ /^\*B/;
    }
    undef $mecab_data;
    undef $kc_bout_data_list;

    return $bout_data unless $bout_file;

    write_to_file($bout_file, $bout_data);
    undef $bout_data;
}

sub merge_mecab_with_kc_mout_file {
    my ($class, $mecab_file, $kc_mout_file, $mout_file) = @_;
    my $mecab_data   = read_from_file($mecab_file);
    my $kc_mout_data = read_from_file($kc_mout_file);
    my $kc_mout_data_list = [ split /\r?\n/, $kc_mout_data ];
    undef $kc_mout_data;

    my $mout_data = "";
    foreach my $mecab_line ( split /\r?\n/, $mecab_data ) {
        if ( $mecab_line =~ /^EOS|^\*B/ ) {
            $mout_data .= $mecab_line."\n";
            next;
        }
        my $mecab_item_list = [ split(/\t/, $mecab_line, -1) ];
        my $kc_mout_line = shift @$kc_mout_data_list;
        $kc_mout_line = shift @$kc_mout_data_list if $kc_mout_line =~ /^EOS/;
        my $kc_mout_item_list = [ split /[ \t]/, $kc_mout_line ];
        push(@$mecab_item_list, splice(@$kc_mout_item_list, 14, 9));
        $mout_data .= sprintf("%s\n", join("\t", @$mecab_item_list));
    }
    undef $mecab_data;
    undef $kc_mout_data_list;

    return $mout_data unless $mout_file;

    write_to_file($mout_file, $mout_data);
    undef $mout_data;
}


sub merge_kc_with_svmout {
    my ($class, $kc_file, $svmout_file, $luwmrph) = @_;

    my $res = "";
    my @long;
    my $kc_data     = read_from_file($kc_file);
    my $svmout_data = read_from_file($svmout_file);
    my $svmout_data_list = [ split /\r?\n/, $svmout_data ];
    undef $svmout_data;

    foreach my $kc_data_line ( split /\r?\n/, $kc_data ) {
    	next if $kc_data_line =~ /^\*B|^EOS/;
    	my @kc_item_list = split /[ \t]/, $kc_data_line;

    	my $svmout_line = shift @$svmout_data_list;
    	my $svmout_item_list = [ split /[ \t]/, $svmout_line ];
    	@$svmout_item_list[10..15] = ("*","*","*","*","*","*");

        if ( $svmout_item_list->[0] eq "B" || $svmout_item_list->[0] eq "Ba") {
            $res .= join(" ", @$_) . "\n" for @long;

            @long = ();
            if ( $luwmrph ne "without" ) {
                @$svmout_item_list[10..15] = @$svmout_item_list[4..6,2,3,1];
            } else {
                @$svmout_item_list[13..15] = @$svmout_item_list[2,3,1];
            }
        } else {
            my $first = $long[0];
            $first->[17] .= $svmout_item_list->[2];
            $first->[18] .= $svmout_item_list->[3];
            $first->[19] .= $svmout_item_list->[1];
            if ( $svmout_item_list->[0] eq "Ia" && $luwmrph ne "without") {
                @$first[14..16] = @$svmout_item_list[4..6];
            }
        }
        push @long, [@$svmout_item_list[0], @kc_item_list[0..12], @$svmout_item_list[10..15]];
    }

    $res .= join(" ", @$_) . "\n" for @long;

    undef $kc_data;
    undef $svmout_data_list;
    undef @long;

    return $res;
}

sub merge_kc_with_bout {
    my ($class, $kc_file, $bout_file) = @_;

    my $res = "";
    my $kc_data   = read_from_file($kc_file);
    my $bout_data = read_from_file($bout_file);
    my $bout_data_list = [ split /\r?\n/, $bout_data ];
    undef $bout_data;

    foreach my $kc_data_line ( split /\r?\n/, $kc_data ) {
    	next if $kc_data_line =~ /^\*B/;

        if ( $kc_data_line =~ /^EOS/ ) {
    	    $res .= "EOS\n";
    	    next;
    	}
    	my @kc_item_list = split /[ \t]/, $kc_data_line;
    	my $bout_line = shift @$bout_data_list;
    	my $bout_item_list = [ split /[ \t]/, $bout_line ];
    	$res .= $bout_item_list->[0] . " " . join(" ", @kc_item_list[0..12]) . "\n";
    }

    undef $kc_data;
    undef $bout_data_list;

    return $res;
}


1;
