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

    # my $noun_ippan = $self->load_dic1($dir,$NAME,".Noun.ippan.dic");
    # my $noun_sahen = $self->load_dic1($dir,$NAME,".Noun.sahen.dic");
    # my $noun_hukusi = $self->load_dic1($dir,$NAME,".Noun.hukusi.dic");
    # my $noun_koyuu = $self->load_dic1($dir,$NAME,".Noun.koyuu.dic");
    my $postp = $self->load_dic2($dir, $NAME, ".Postp.dic");
    my $auxv = $self->load_dic2($dir, $NAME, ".AuxV.dic");

    my $postp_state = 0;
    my $auxv_state = 0;

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

        ## 補助記号の場合、前後の品詞情報を素性として追加
        if ( $items[3] =~ /^補助記号/ ) {
            my $feature1 = "E";
            if ( $i > 0 ) {
                my @pre = split(/ /, $line_in_list->[$i-1]);
                if ( $pre[3] eq '名詞-普通名詞-一般' ) {
                    $feature1 = "A";
                } elsif ( $pre[3] eq '名詞-普通名詞-サ変可能' ) {
                    $feature1 = "B";
                } elsif ( $pre[3] eq '名詞-普通名詞-副詞可能' ) {
                    $feature1 = "C";
                } elsif ( $pre[3] eq '名詞-数詞' ) {
                    $feature1 = "D";
                }
            }
            my $feature2 = "E";
            if ( $i < $#{$line_in_list} ) {
                my @post = split(/ /, $line_in_list->[$i+1]);
                if ( $post[3] eq '名詞-普通名詞-一般' ) {
                    $feature2 = "A";
                } elsif ( $post[3] eq '名詞-普通名詞-サ変可能' ) {
                    $feature2 = "B";
                } elsif ( $post[3] eq '名詞-普通名詞-副詞可能' ) {
                    $feature2 = "C";
                } elsif ( $post[3] eq '名詞-数詞' ) {
                    $feature2 = "D";
                }
            }
            push @out_items, $feature1.$feature2;
        } else {
            push @out_items, '*';
        }

        ## 出現形がひらがなのみで構成されているか
        # if ( $items[0] =~ /^(?:\xE3\x81[\x81-\xBF]|\xE3\x82[\x80-\x93])+$/ ) {
        #     push @out_items, "1";
        # } else {
        #     push @out_items, "0";
        # }

        ## 名詞-普通名詞-一般を構成する短単位か(名詞or動詞)
        # if ( defined $$noun_ippan{$items[2]} ) {
        #     push @out_items, "1";
        # } else {
        #     push @out_items, "0";
        # }

        ## 名詞-普通名詞-サ変を構成する短単位か(名詞or動詞)
        # if ( defined $$noun_sahen{$items[2]} ) {
        #     push @out_items, "1";
        # } else {
        #     push @out_items, "0";
        # }

        ## 名詞-普通名詞-副詞可能を構成する短単位か(名詞or動詞)
        # if ( defined $$noun_hukusi{$items[2]} ) {
        #     push @out_items, "1";
        # } else {
        #     push @out_items, "0";
        # }

        ## 名詞-固有名詞を構成する短単位か(名詞-普通名詞or接尾辞)
        # if ( defined $$noun_koyuu{$items[2]} ) {
        #     push @out_items, "1";
        # } else {
        #     push @out_items, "0";
        # }

        ## 複数の短単位からなる助詞を構成する短単位であるか
        if ( $postp_state >= 1 ) {
            $postp_state--;
            push @out_items, "1";
        } else {
            foreach my $length ( sort {$b <=> $a} keys %$postp ) {
                next if $i+$length > $#{$line_in_list};
                my $term = "";
                for my $k ( 0 .. $length-1 ) {
                    my @items = split(/ /, $line_in_list->[$i + $k]);
                    $term .= join(" ", @items[0..5])."\n";
                }

                if ( defined $$postp{$length}->{$term} ) {
                    my @pre_pos = (split(/ /, $line_in_list->[$i-1]))[3..5];
                    my $pre_term = (split(/\-/, $pre_pos[0]))[0]." ".(split(/\-/, $pre_pos[1]))[0]." ".(split(/\-/, $pre_pos[2]))[0];
                    my $post_hinsi = (split(/ /, $line_in_list->[$i+$length]))[3];
                    my $post_hinsi1 = (split(/\-/, $post_hinsi))[0];
                    my $fix_pos = $pre_term."|".$post_hinsi1;
                    if ( defined $$postp{$length}->{$term}->{$fix_pos} ) {
                        $postp_state = $length;
                        last;
                    }
                }
            }
            if ( $postp_state >= 1 ) {
                 push @out_items, "1";
                $postp_state--;
            } else {
                 push @out_items, "0";
            }
        }

        ## 複数の短単位からなる助動詞を構成する短単位であるか
        if ( $auxv_state >= 1 ) {
            $auxv_state--;
             push @out_items, "1";
        } else {
            foreach my $length ( sort {$b <=> $a} keys %$auxv ) {
                next if $i+$length > $#{$line_in_list};
                my $term = "";
                for my $k ( 0 .. $length-1 ) {
                    my @items = split(/ /, $line_in_list->[$i + $k]);
                    $term .= join(" ", @items[0..5])."\n";
                }
                if ( defined $$auxv{$length}->{$term} ) {
                    my @pre_pos = (split(/ /, $line_in_list->[$i-1]))[3..5];
                    my $pre_term = (split(/\-/, $pre_pos[0]))[0]." ".(split(/\-/, $pre_pos[1]))[0]." ".(split(/\-/, $pre_pos[2]))[0];
                    my $post_hinsi = (split(/ /, $line_in_list->[$i+$length]))[3];
                    my $post_hinsi1 = (split(/\-/, $post_hinsi))[0];
                    my $fix_pos = $pre_term."|".$post_hinsi1;
                    if ( defined $$auxv{$length}->{$term}->{$fix_pos} ) {
                        $auxv_state = $length;
                        last;
                    }
                }
            }
            if ( $auxv_state >= 1 ) {
                push @out_items, "1";
                $auxv_state--;
            } else {
                push @out_items, "0";
            }
        }

        if ( $#items > 8 ) {
            push @out_items, @items[9..$#items];
        }

        $res .= join(" ", @out_items)."\n";
    }
    undef $line_in_list;

    return $res;
}

sub load_dic1 {
    my $self = shift;
    my ($dir,$NAME,$file) = @_;

    my %dic;
    open(my $fh, $dir."/".$NAME.$file) or die "Cannot open '$file'";
    binmode($fh);
    while ( my $line = <$fh> ) {
        $line = Encode::decode("utf-8", $line);
        chomp($line);
        $dic{$line} = 1;
    }
    close($fh);

    return \%dic;
}

sub load_dic2 {
    my $self = shift;
    my ($dir, $NAME, $file) = @_;

    my %dic;
    my @terms = ();
    open(my $fh, $dir."/".$NAME.$file) or die "Cannot open '$file'";
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
