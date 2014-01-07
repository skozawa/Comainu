# -*- mode: perl; coding: utf-8; -*-

# 素性を追加する

package AddFeature;

use strict;
use utf8;

my $DEFAULT_VALUES =
{
    "" => "",
};

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {%$DEFAULT_VALUES, @_};
    bless $self, $class;
    return $self;
}

sub add_feature {
    my ($self, $buff, $NAME, $dir) = @_;

    my $res = '';
    my $line_in_list = [ split(/\r?\n/, $buff) ];
    undef $buff;
    for my $i ( 0 .. $#{$line_in_list} ){
        my @items = split(/ /, $line_in_list->[$i]);
        if ( $#items < 8 ) {
            $res .= $line_in_list->[$i]."\n";
            next;
        }

        my @out_items = @items[0..8];

        ## 品詞を分割して素性に追加
        my @hinsi = split(/\-/,$items[3]);
        for my $j ( 0 .. 3 ) {
            push @out_items, $hinsi[$j] // '*';
        }
        ## 活用型を分割して素性に追加
        my @katuyou1 = split(/\-/,$items[4]);
        for my $j ( 0 .. 2 ) {
            push @out_items, $katuyou1[$j] // '*';
        }
        ## 活用形を分割して素性に追加
        my @katuyou2 = split(/\-/,$items[5]);
        for my $j ( 0 .. 2 ) {
            push @out_items, $katuyou2[$j] // '*';
        }

        if ( $#items > 8 ) {
            push @out_items, @items[9..$#items];
        }

        $res .= join(" ", @out_items)."\n";
    }
    undef $line_in_list;

    return $res;
}

sub load_dic {
    my ($self, $file) = @_;

    my %dic;
    my @terms = ();
    open(my $fh, $file) or die "Cannot open '$file'";
    binmode($fh);
    while ( my $line = <$fh> ) {
        $line = Encode::decode("utf-8", $line);
        $line =~ s/\r?\n//mg;
        if ( $line eq '' ) {
            if ( $#terms > 2 ) {
                $dic{scalar(@terms)-2}->{join("\n",@terms[1..$#terms-1])."\n"}->{$terms[0]."|".$terms[$#terms]} = 1;
            }
            @terms = ();
        } else {
            push @terms, $line;
        }
    }
    close($fh);

    return \%dic;
}

1;
#################### END OF FILE ####################
