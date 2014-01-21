package Comainu::Feature;

use strict;
use warnings;
use utf8;

use Comainu::Util qw(read_from_file);

sub create_longout_feature {
    my ($class, $kc_file, $boundary) = @_;

    my $kc_data = read_from_file($kc_file);

    my $buff = '';
    foreach my $line ( split /\r?\n/, $kc_data ) {
        $buff .= $class->_long_feature_from_line($line) . "\n";
    }
    undef $kc_data;

    $buff =~ s/^EOS.*?\n//mg if $boundary ne 'sentence' && $boundary ne 'word';
    $buff =~ s/^\*B.*?\n//mg if $boundary eq "sentence";

    return $buff;
}

# 行頭または行末のカラムとして追加する。
# pivot
#    Ba  長単位先頭     品詞一致
#    B   長単位先頭     品詞不一致
#    Ia  長単位先頭以外 品詞一致
#    I   長単位先頭以外 品詞不一致
sub create_longmodel_feature {
    my ($class, $kc_file, $flag) = @_;

    my $kc_data = read_from_file($kc_file);
    my $line_in_list = [ split /\r?\n/, $kc_data ];
    undef $kc_data;

    my $front = (defined $flag && $flag eq "0");
    my $curr_long_pos = "";

    my $buff = "";
    foreach my $i ( 0 .. $#{$line_in_list} ) {
        my $line = $line_in_list->[$i];
        next if $line =~ /^\*B/;

        if ( $line =~ /^EOS/ ) {
            $buff .= "\n";
            next;
        }

        my $pivot = "";
        my $items = [ split / /, $line ];
        my $short_pos = join " ", @$items[3..5];
        my $long_pos  = join " ", @$items[13..15];

        if ( $long_pos =~ /^\*/ ) {
            $pivot = "I";
        } else {
            $pivot = "B";
            $curr_long_pos = $long_pos;
        }

        if ( $short_pos eq $curr_long_pos ) {
            if ( $i < $#{$line_in_list} ) {
                my $next_items = [ split / /, $line_in_list->[$i+1] ];
                $pivot .= "a" if !$next_items->[13] || $next_items !~ /^\*/;
            } else {
                $pivot .= "a";
            }
        }

        my $feature = $class->_long_feature_from_line($line);
        $buff .= $front ? "$pivot $feature\n" : "$feature $pivot\n";
    }
    $buff .= "\n";

    return $buff;
}

sub _long_feature_from_line {
    my ($class, $line) = @_;

    my @items = split /[ \t]/, $line;
    return $line unless $#items > 8;
    my @features = @items[0 .. 5, 10 .. 12];

    ## 品詞を分割して素性に追加
    my @hinsi = split(/\-/,$features[3]);
    for my $j ( 0 .. 2 ) {
        push @features, $hinsi[$j+1] ? join("-", @hinsi[0..$j]) : '*';
    }
    ## 活用型を分割して素性に追加
    my @katuyou1 = split(/\-/,$features[4]);
    for my $j ( 0 .. 1 ) {
        push @features, $katuyou1[$j+1] ? join("-", @katuyou1[0..$j]) : '*';
    }
    ## 活用形を分割して素性に追加
    my @katuyou2 = split(/\-/,$features[5]);
    for my $j ( 0 .. 1 ) {
        push @features, $katuyou2[$j+1] ? join("-", @katuyou2[0..$j]) : '*';
    }

    return join " ", @features;
}

# 前処理（partial chunkingの入力フォーマットへの変換）
sub pp_partial {
    my ($class, $data, $args) = @_;
    my $res = "";
    my ($prev, $curr, $next) = (0, 1, 2);
    my $buff_list = [undef, undef];

    my $B_label  = $args->{is_bnst} ? "B" : "B Ba";
    my $BI_label = $args->{is_bnst} ? "B I" :
        $args->{boundary} ne "word" ? "B Ba I Ia" : "I Ia";

    foreach my $line ((split(/\r?\n/, $data), undef, undef)) {
        push @$buff_list, $line;
        if ( defined $buff_list->[$curr] && $buff_list->[$curr] !~ /^EOS|^\*B/ ) {
            my $mark = "";
            if ( !defined $buff_list->[$prev] ) {
                $mark = $B_label;
            } elsif ( $buff_list->[$prev] =~ /^EOS|^\*B/) {
                $mark = $B_label;
            } else {
                $mark = $BI_label;
            }
            $buff_list->[$curr] .= " " . $mark;
        }
        my $new_line = shift @$buff_list;
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


sub create_bnstout_feature {
    my ($class, $kc_file) = @_;

    my $kc_data = read_from_file($kc_file);

    my $buff = "";
    my $parenthetic = 0;
    foreach my $line ( split /\r?\n/, $kc_data ) {
        next if $line =~ /^\*B/;
        if ( $line eq "EOS" ) {
            $buff .= $line . "\n*B\n";
            $parenthetic = 0;
            next;
        }
        $buff .= $class->_bnst_feature_from_line($line, \$parenthetic) . "\n";
    }
    undef $kc_data;

    return $buff;
}

sub create_bnstmodel_feature {
    my ($class, $kc_file) = @_;

    my $kc_data = read_from_file($kc_file);

    my $buff = "";
    my ($prev, $curr, $next) = (0, 1, 2);
    my $buff_list = [undef, undef];
    my $parenthetic = 0;
    foreach my $line ( (split(/\r?\n/, $kc_data), undef, undef) ) {
        push @$buff_list, $line;
        if ( ! defined $buff_list->[$curr] || $buff_list->[$curr] =~ /^\*B/ ) {
            # no operation
        } elsif ( $buff_list->[$curr] =~ /^EOS/ ) {
            $buff .= "\n";
        } else {
            my $mark = !defined $buff_list->[$prev] ? 'B' :
                $buff_list->[$prev] =~ /^\*B/ ? "B" : "I";
            $buff .= $class->_bnst_feature_from_line($buff_list->[$curr], \$parenthetic) . ' ' . $mark . "\n";
        }

        shift @$buff_list;
    }
    undef $kc_data;
    undef $buff_list;

    $buff .= "\n";

    return $buff;
}

sub _bnst_feature_from_line {
    my ($class, $line, $parenthetic) = @_;

    my @items = split /[ \t]/, $line;
    my @pos   = split /\-/, $items[3] . "-*-*-*";
    my @cType = split /\-/, $items[4] . "-*-*";
    my @cForm = split /\-/, $items[5] . "-*-*";

    my $feature = join " ", @items[0..5], @pos[0..3], @cType[0..2], @cForm[0..2];

    if ( $items[3] eq '補助記号-括弧開' ) {
        $feature .= $$parenthetic ? ' I' : ' B';
        $$parenthetic++;
    } elsif ( $items[3] eq '補助記号-括弧閉' ) {
        $$parenthetic--;
        $feature .= ' I';
    } elsif ( $$parenthetic ) {
        $feature .= ' I';
    } else {
        $feature .= ' O';
    }

    return $feature;
}

# 前処理（partial chunkingの入力フォーマットへの変換）
sub pp_partial_bnst_with_luw {
    my ($class, $data, $svmout_file) = @_;
    my $res = "";
    my ($prev, $curr, $next) = (0, 1, 2);
    my $buff_list = [undef, undef];

    my $svmout_data = read_from_file($svmout_file);
    my $svmout_item_list = [ split(/\r?\n/, $svmout_data) ];
    undef $svmout_data;

    foreach my $line ( (split(/\r?\n/, $data), undef, undef) ) {
        push @$buff_list, $line;
        if ( defined $buff_list->[$curr] && $buff_list->[$curr] !~ /^EOS|^\*B/ ) {
            my $mark = "";
            my $lw = shift @$svmout_item_list;
            my @svmout = split(/[ \t]/,$lw);
            if ( $buff_list->[$prev] =~ /^EOS|^\*B/) {
                $mark = "B";
            } elsif ( !defined $buff_list->[$prev] ) {
                $mark = "B";
            } elsif ( $svmout[0] =~ /I/ ) {
                $mark = "I";
            } elsif ( $svmout[4] =~ /^動詞/ ) {
                $mark = "B";
            } elsif ( $svmout[4] =~ /^名詞|^形容詞|^副詞|^形状詞/ &&
                          ($svmout[21] == 1 || $svmout[22] == 1) ) {
                $mark = "B";
            } else {
                $mark = "B I";
            }
            $buff_list->[$curr] .= " ".$mark;
        }
        my $new_line = shift @$buff_list;
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line . "\n";
        }
    }
    while ( my $new_line = shift(@$buff_list) ) {
        if ( defined $new_line && $new_line !~ /^\*B/ ) {
            $res .= $new_line."\n";
        }
    }

    undef $data;
    undef $buff_list;
    undef $svmout_item_list;

    return $res;
}


sub create_mst_feature {
    my ($class, $kc_file) = @_;

    my $kc_data = read_from_file($kc_file);

    my $buff = "";
    my $short_terms = [];
    my $pos = 0;
    foreach my $line ( split /\r?\n/, $kc_data ) {
        next if $line =~ /^\*B/ || $line eq "";
        if ( $line =~ /^EOS/ ) {
            $buff .= $class->_mst_feature($short_terms, $pos);
            $short_terms = [];
            $pos = 0;
            next;
        }
        my @items = split(/[ \t]/, $line);
        if ( $items[13] ne "*" ) {
            $buff .= $class->_mst_feature($short_terms, $pos);
            $short_terms = [];
        }
        push @$short_terms, $line;
        $pos++;
    }
    undef $kc_data;
    undef $short_terms;

    return $buff;
}

# 中単位解析用の素性を生成
sub _mst_feature {
    my ($class, $short_terms, $pos) = @_;
    my $res = "";

    my $id = 1;
    if ( scalar(@$short_terms) > 1 ) {
        foreach my $line ( @$short_terms ) {
            my @items = split(/[ \t]/, $line);
            $items[19] //= '';
            my $depend = "_";
            if ( $items[19] =~ /Ｐ/ ) {
                $depend = "P";
            }
            if ( $items[19] ne "*" && $items[19] ne "" ) {
                $items[19] -= $pos - scalar(@$short_terms) - 1;
            } else {
                $items[19] = 0;
            }
            if ( scalar(@$short_terms) < $items[19] || $items[19] < 0 ) {
                print STDERR "error: $items[0]: $line\n";
                print STDERR $pos, " ", $items[19], " ", scalar(@$short_terms), "\n";
            }
            my @cpos = split(/\-/, $items[3]);
            my @features;

            foreach my $i ( 3 .. 5 ) {
                next if $items[$i] eq "*";
                my @pos = split(/\-/, $items[$i]);
                foreach my $j ( 0 .. $#pos ) {
                    next if ($i == 3 && ($j == 0 || $j == $#pos));
                    push @features, join("-",@pos[0..$j]);
                }
            }

            $res .= $id++ . "\t" . $items[0] . "\t" . $items[2] . "\t" . $cpos[0] . "\t" . $items[3] . "\t";
            if ( scalar @features > 0 ) {
                $res .= join("|",@features);
            } else {
                $res .= "_";
            }
            $res .= "\t" . $items[19] . "\t" . $depend . "\t_\n";
        }
        $res .= "\n";
    }

    return $res;
}


1;
