package Comainu::Feature;

use strict;
use warnings;
use utf8;

use Comainu::Util qw(read_from_file);

sub create_long_feature {
    my ($class, $kc_file, $boundary) = @_;

    my $kc_data = read_from_file($kc_file);

    my $buff = '';
    foreach my $line ( split /\r?\n/, $kc_data ) {
        $buff .= $class->_long_feature_from_line($line) . "\n";
    }
    undef $kc_data;

    # 解析時
    if ( $boundary ) {
        $buff =~ s/^EOS.*?\n//mg if $boundary ne 'sentence' && $boundary ne 'word';
        $buff =~ s/^\*B.*?\n//mg if $boundary eq "sentence";
    } else {
        # 学習時
        $buff =~ s/^EOS.*?\n|^\*B.*?\n//mg;
    }

    return $buff;
}

sub _long_feature_from_line {
    my ($class, $line) = @_;

    my @items = split /[ \t]/, $line;
    return $line unless $#items > 8;
    my @features = @items[0 .. 5, 10 .. 12];

    ## 品詞を分割して素性に追加
    my @hinsi = split(/\-/,$features[3]);
    for my $j ( 0 .. 3 ) {
        push @features, $hinsi[$j] // '*';
    }
    ## 活用型を分割して素性に追加
    my @katuyou1 = split(/\-/,$features[4]);
    for my $j ( 0 .. 2 ) {
        push @features, $katuyou1[$j] // '*';
    }
    ## 活用形を分割して素性に追加
    my @katuyou2 = split(/\-/,$features[5]);
    for my $j ( 0 .. 2 ) {
        push @features, $katuyou2[$j] // '*';
    }

    return join " ", @features;
}

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
            if ( $buff_list->[$prev] =~ /^EOS|^\*B/) {
                $mark = $B_label;
            } elsif ( !defined $buff_list->[$prev] ) {
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



1;
