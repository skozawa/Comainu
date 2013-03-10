# -*- mode: perl; coding: utf-8; -*-

#
# 訓練対象KCファイルから辞書を構築する
#

package CreateDictionary;

use strict;
use utf8;

my $DEFAULT_VALUES =
{
    "train-kc" => "",
};

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {%$DEFAULT_VALUES, @_};
    bless $self, $class;
    return $self;
}

# 辞書を構築
# 以下の辞書を構築
#
# 「名詞-普通名詞-一般」(長単位)を構成する「名詞-普通名詞-*」「動詞」(短単位)の辞書
# 「名詞-普通名詞-サ変可能」(長単位)を構成する「名詞-普通名詞-*」「動詞」(短単位)の辞書
# 「名詞-普通名詞-副詞可能」(長単位)を構成する「名詞-普通名詞-*」「動詞」(短単位)の辞書
# 「名詞-固有名詞」(長単位)を構成する「名詞-普通名詞-*」「接尾辞」(短単位)の辞書
# 複数の短単位から成る長単位「助詞」辞書
# 複数の短単位から成る長単位「助動詞」辞書
#
sub create_dictionary{
    my $self = shift;
    my ($train_kc,$dir,$NAME) = @_;

    #my %noun_ippan;
    #my %noun_sahen;
    #my %noun_hukusi;
    #my %noun_koyuu;
    my %postp;
    my %auxv;
    my $pre_sterm = "";

    my $buff = $self->read_from_file($train_kc);
    my $state = 0;
    my $long_term = "";
    my @short_terms;
    foreach my $line (split(/\r?\n/,$buff)){
	next if($line =~ /^\*B/);
	if($line eq 'EOS'){
	    if($state == 8 && $#short_terms >= 2){
		$postp{join("\n",@short_terms)} = $#short_terms;
	    }elsif($state == 9 && $#short_terms >= 2){
		$auxv{join("\n",@short_terms)} = $#short_terms;
	    }
	    @short_terms = ();
	    $state = 0;
	    next;
	}
	
	my @items = split(/ /,$line);
	
	## 長単位の先頭の短単位でない場合
	if($items[13] eq '*'){
	    #if($state == 1 && $items[3] =~ /^名詞-普通名詞|^動詞/){
		#$noun_ippan{$items[2]} = 1;
	    #}elsif($state == 2 && $items[3] =~ /^名詞-普通名詞|^動詞/){
		#$noun_sahen{$items[2]} = 1;
	    #}elsif($state == 3 && $items[3] =~ /^名詞-普通名詞|^動詞/){
		#$noun_hukusi{$items[2]} = 1;
	    #}elsif($state == 4 && $items[3] =~ /^名詞-普通名詞|^接尾辞/){
		#$noun_koyuu{$items[2]} = 1;
	    #}els
	    if($state == 8 || $state == 9){
		push @short_terms,join(" ",@items[0..5]);
	    }
	}
	## 長単位を構成する先頭の短単位の場合
	else{
	    ## 複数の短単位から成る場合は辞書に追加
	    if($state == 8 && $#short_terms >= 2){
		#push @short_terms, "$items[3]";
		push @short_terms, (split(/\-/, $items[3]))[0];
		$postp{join("\n",@short_terms)} = $#short_terms;
	    }elsif($state == 9 && $#short_terms >= 2){
		#push @short_terms, "$items[3]";
		push @short_terms, (split(/\-/, $items[3]))[0];
		$auxv{join("\n",@short_terms)} = $#short_terms;
	    }

	    #if($items[13] eq '名詞-普通名詞-一般'){
		#$state = 1;
		#$noun_ippan{$items[2]} = 1 if($items[3] =~ /^名詞-普通名詞|^動詞/);
	    #}elsif($items[13] eq '名詞-普通名詞-サ変可能'){
		#$state = 2;
		#$noun_sahen{$items[2]} = 1 if($items[3] =~ /^名詞-普通名詞|^動詞/);
	    #}elsif($items[13] eq '名詞-普通名詞-副詞可能'){
		#$state = 3;
		#$noun_hukusi{$items[2]} = 1 if($items[3] =~ /^名詞-普通名詞|^動詞/);
	    #}elsif($items[13] =~ /^名詞-固有名詞/){
		#$state = 4;
		#$noun_koyuu{$items[2]} = 1 if($items[3] =~ /^名詞-普通名詞|^接尾辞/);
	    #}els
	    if($items[13] =~ /^助詞/){
		$state = 8;
	    }elsif($items[13] =~ /^助動詞/){
		$state = 9;
	    }else{
		$state = 0;
	    }

	    @short_terms = ();
	    if($state == 8 || $state == 9){
		push @short_terms,$pre_sterm;
		push @short_terms,join(" ",@items[0..5]);
	    }
	}
	#$pre_sterm = $items[3];
	$pre_sterm = (split(/\-/, $items[3]))[0]." ".(split(/\-/, $items[4]))[0]." ".(split(/\-/, $items[5]))[0];
    }
    
    #$self->write_to_file($dir."/".$NAME.".Noun.ippan.dic",join("\n",keys %noun_ippan));
    #$self->write_to_file($dir."/".$NAME.".Noun.sahen.dic",join("\n",keys %noun_sahen));
    #$self->write_to_file($dir."/".$NAME.".Noun.hukusi.dic",join("\n",keys %noun_hukusi));
    #$self->write_to_file($dir."/".$NAME.".Noun.koyuu.dic",join("\n",keys %noun_koyuu));

    $self->write_to_file($dir."/".$NAME.".Postp.dic",join("\n\n",sort {$postp{$b} <=> $postp{$a}} keys %postp));
    $self->write_to_file($dir."/".$NAME.".AuxV.dic",join("\n\n",sort {$auxv{$b}<=>$auxv{$a}} keys %auxv));
}

############################################################
# Utilities
############################################################
sub read_from_file {
    my $self = shift;
    my ($file) = @_;
    my $data = "";
    open(my $fh, $file) or die "Cannot open '$file'";
    binmode($fh);
    while(my $line = <$fh>) {
	$data .= $line;
    }
    close($fh);
    $data = Encode::decode("utf-8", $data);
    return $data;
}

sub write_to_file {
    my $self = shift;
    my ($file, $data) = @_;
    $data = Encode::encode("utf-8", $data);
    open(my $fh, ">", $file) or die "Cannot open '$file'";
    binmode($fh);
    print $fh $data;
    close($fh);
}

sub copy_file {
    my $self = shift;
    my ($src_file, $dest_file) = @_;
    my $buff = $self->read_from_file($src_file);
    $self->write_to_file($dest_file, $buff);
}

1;
#################### END OF FILE ####################
