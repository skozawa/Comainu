package Comainu::Evaluate;

use strict;
use warnings;
use utf8;

use File::Temp qw(tempfile);

# *.KC と *.out (システムの出力)を比較し、精度を求める
# segmentaion と POS information (発音を除くすべて)
sub eval_long {
    my ($class, $gld_file, $sys_file, $is_middle, $eval_level) = @_;

    my ($tmp1_fh, $tmp_file1) = tempfile;
    open(GLD, $gld_file) || die "Can't open $gld_file: $!\n";
    while ( <GLD> ) {
        next if /^\#/ || /^\*/;
        next if /^EOS/;
        chomp;

        my @morph = split /\s+/;
        my @pos;
        if ( $is_middle ) {
            print $tmp1_fh "$morph[0]\n";
        } else {
            my @target = $eval_level eq "pos" ? @morph[0, 3..5] :
                $eval_level eq "boundary" ? ($morph[0]) : @morph[0..5];
            print $tmp1_fh join(" ", @target), "\n";
        }
    }
    close(GLD);
    $tmp1_fh->close;

    my ($tmp2_fh, $tmp_file2) = tempfile;
    open(SYS, $sys_file) || die "Can't open $sys_file: $!\n";
    while ( <SYS> ) {
        next if /^\#/ || /^\*/;
        next if /^EOS/;
        chomp;

        my @morph = split /\s+/;
        my @pos;
        if ( $is_middle ) {
            print $tmp2_fh "$morph[0]\n";
        } else {
            my @target = $eval_level eq "pos" ? @morph[0, 3..5] :
                $eval_level eq "boundary" ? ($morph[0]) : @morph[0..5];
            print $tmp2_fh join(" ", @target), "\n";
        }
    }
    close(SYS);
    $tmp2_fh->close;

    my $dif = $sys_file . ".diff";
    $class->diff_perl($tmp_file1, $tmp_file2, $dif);

    my ($gld, $sys, $agr, $fg, $fs) = (0, 0, 0, 0, 0);
    open(DIF, $dif) || die "Can't open $dif: $!\n";
    while ( <DIF> ) {
        if (/^\;\_/) {
            $fg++;
            next;
        } elsif (/^\;\*/) {
            $fg = 0;
            $fs++;
            next;
        } elsif (/^\;\~/) {
            $fs = 0;
            next;
        } elsif (/^EOS/) {
            next;
        }

        if ($fg == 0 && $fs == 0) {
            $gld++;
            $sys++;
            $agr++;
        } elsif ($fg > 0) {
            $gld++;
        } elsif ($fs > 0) {
            $sys++;
        } else {
            print STDERR "ERROR!\n";
        }
    }
    close(DIF);

    my $rec = 0.0;
    if ($gld > 0) { $rec = $agr / $gld * 100; }
    my $prec = 0.0;
    if ($sys > 0) { $prec = $agr / $sys * 100; }
    my $f = 0.0;
    if (($rec + $prec) > 0) { $f = 2 * $rec * $prec / ($rec + $prec); }

    my $res = "";
    $res .= sprintf("Recall: %.2f%% ($agr/$gld) ", $rec);
    $res .= sprintf("Precision: %.2f%% ($agr/$sys) ", $prec);
    $res .= sprintf("F-measure: %.2f%%\n", $f);

    return $res;
}

sub diff_perl {
    my ($class, $tmp_file1, $tmp_file2, $dif) = @_;

    my ($tmp_fh, $tmp_file) = tempfile;
    system("diff -D".$;." \"$tmp_file1\" \"$tmp_file2\" > \"$tmp_file\"");

    open(DIF, ">", $dif) or die "Cannot open '$dif'";
    open(TMP, $tmp_file);

    my $flag;
    while ( <TMP> ) {
        chomp;
        if (/^\#ifn/ && /$;/) {
            $flag = 1;
            # print ";______\n";
            print DIF ";______\n";
        } elsif (/^\#if/ && /$;/) {
            $flag = 2;
            # print ";______\n";
            # print ";***\n";
            print DIF ";______\n";
            print DIF ";***\n";
        } elsif (/^\#else/ && /$;/) {
            $flag = 2;
            # print ";***\n";
            print DIF ";***\n";
        } elsif (/^\#end/ && $flag == 1 && /$;/) {
            $flag = 0;
            # print ";***\n";
            # print ";~~~~~~\n";
            print DIF ";***\n";
            print DIF ";~~~~~~\n";
        } elsif (/^\#end/ && $flag == 2 && /$;/) {
            $flag = 0;
            # print ";~~~~~~\n";
            print DIF ";~~~~~~\n";
        } else {
            # print "$_\n";
            print DIF "$_\n";
        }
    }
    close(TMP);
    close(DIF);
}


1;
