package Comainu::SUWAnalysis;

use strict;
use warnings;
use utf8;
use Config;

use Comainu::Util qw(read_from_file write_to_file proc_stdin2stdout proc_file2file);

use constant {
    KC_MECAB_TABLE_FOR_UNIDIC => {
        # KC => MECAB
        "0" => "0",
        "1" => "0",
        "2" => "2",
        "3" => "3",
        "4" => "1",
        "5" => "4",
        "6" => "5",
        "7" => "6",
        "8" => "*",
        "9" => "*",
        "10" => "*",
    },
    KC_MECAB_TABLE_FOR_CHAMAME => {
        # KC => MECAB
        "0" => "1",
        "1" => "3",
        "2" => "4",
        "3" => "5",
        "4" => "6",
        "5" => "7",
        #"6" => "10",
        #"7" => "11",
        #"8" => "12",
        #"9" => "13",
        "6" => "9",
        "7" => "10",
        "8" => "11",
        "9" => "12",
        "10" => "*",
        "11" => "*",
        #"12" => "9",
        "12" => "8",
    },
    UNIDIC_MECAB_TYPE => "chamame",
};


sub new {
    my ($class, %args) = @_;
    bless { %args }, $class;
}

sub plain2kc_file {
    my ($self, $test_file, $mecab_file, $kc_file) = @_;

    $self->plain2mecab_file($test_file, $mecab_file);
    $self->mecab2kc_file($mecab_file, $kc_file);
}

# 形態素解析
sub plain2mecab_file {
    my ($self, $test_file, $mecab_file) = @_;

    my $mecab_dic_dir = $self->{"mecab-dic-dir"};
    my $mecab_dir = $self->{"mecab-dir"};
    my $mecabdic = $mecab_dic_dir . '/unidic';
    $mecabdic = $mecab_dic_dir . "/unidic-mecab" unless -d $mecabdic;
    my $com = sprintf("\"%s/mecab\" -O%s -d\"%s\" -r\"%s\"",
                      $mecab_dir, UNIDIC_MECAB_TYPE, $mecabdic, $self->{mecab_rcfile});
    $com =~ s/\//\\/g if $Config{osname} eq "MSWin32";

    print STDERR "# COM: ".$com."\n";
    my $in_buff = read_from_file($test_file);
    my $out_buffs = [];
    $in_buff =~ s/\r?\n$//s;
    foreach my $line (split(/\r?\n/, $in_buff)) {
        $line .= "\n";
        my $out = proc_stdin2stdout($com, $line, $self->{"comainu-temp"});
        $out =~ s/\x0d\x0a/\x0a/sg;
        $out .= "EOS" if $out !~ /EOS\s*$/s;
        push @$out_buffs, $out;
    }
    my $out_buff = join "\n", @$out_buffs;
    undef $out_buffs;
    undef $in_buff;

    write_to_file($mecab_file, $out_buff);
    undef $out_buff;
}

# extcorput.plを利用して付加情報を付与
sub mecab2kc_file {
    my ($self, $mecab_file, $kc_file) = @_;
    my $mecab_ext_file = $mecab_file."_ext";
    my $ext_def_file   = $self->{"comainu-temp"}."/mecab_ext.def";

    # unidic dbがない場合の対処
    unless ( -f $self->{"unidic-db"} ) {
        printf STDERR "***********************************************\n";
        printf STDERR "***** WARN: NO UNIDIC DB                  *****\n";
        printf STDERR "***** Maybe long-word lemma is incorrect  *****\n";
        printf STDERR "***********************************************\n";
        my $buff = read_from_file($mecab_file);
        $buff = $self->mecab2kc($buff);
        write_to_file($kc_file, $buff);
        undef $buff;
        return;
    }

    my $def_buff = "";
    $def_buff .= "dbfile:".$self->{"unidic-db"}."\n";
    $def_buff .= "table:lex\n";
    $def_buff .= "input:sLabel,orth,pron,lForm,lemma,pos,cType?,cForm?\n";
    $def_buff .= "output:sLabel,orth,pron,lForm,lemma,pos,cType?,cForm?,goshu,form,formBase,formOrthBase,formOrth\n";
    $def_buff .= "key:lForm,lemma,pos,cType,cForm,orth,pron\n";
    write_to_file($ext_def_file, $def_buff);
    undef $def_buff;

    my $com = sprintf("\"%s\" \"%s/script/extcorpus.pl\" -C \"%s\"",
                      $self->{perl}, $self->{"comainu-home"}, $ext_def_file);
    proc_file2file($com, $mecab_file, $mecab_ext_file);

    my $buff = read_from_file($mecab_ext_file);
    $buff = $self->mecab2kc($buff);
    write_to_file($kc_file, $buff);

    unlink $mecab_ext_file if !$self->{debug} && -f $mecab_ext_file;

    undef $buff;
}

sub mecab2kc {
    my ($self, $buff) = @_;
    my $table = KC_MECAB_TABLE_FOR_CHAMAME;
    my $res_str = "";
    my $first_flag = 0;
    my $item_name_list = [keys %$table];
    $buff =~ s/\r?\n$//;

    foreach my $line ( split(/\r?\n/, $buff) ) {
        if ( $line =~ /^EOS/ ) {
            $first_flag = 1;
            next;
        }
        my $item_list = [ split(/\t/, $line) ];
        $item_list->[2] = $item_list->[1] if $item_list->[2] eq "";
        $item_list->[3] = $item_list->[1] if $item_list->[3] eq "";
        $item_list->[5] = "*"             if $item_list->[5] eq "";
        $item_list->[6] = "*"             if ($item_list->[6] // "") eq "";
        $item_list->[7] = "*"             if ($item_list->[7] // "") eq "";

        my $value_list = [ map {
            $table->{$_} eq "*" ? "*" : $item_list->[$table->{$_}] // "";
        } sort {$a <=> $b} keys %$table ];
        $value_list = [ @$value_list, "*", "*", "*", "*", "*", "*", "*", "*" ];
        if ( $first_flag == 1 ) {
            $first_flag = 0;
            $res_str .= "EOS\n";
        }
        $res_str .= sprintf("%s\n", join(" ", @$value_list));
    }
    $res_str .= "EOS\n";

    undef $buff;
    undef $item_name_list;

    return $res_str;
}


1;
