package Comainu::Evaluate;

use strict;
use warnings;
use utf8;

use File::Temp qw(tempfile);

# Evaluate the model comparing *.KC and *.out
sub eval_long {
    my ($class, $gld_file, $sys_file, $is_middle, $eval_level) = @_;

    my $tmp_file1 = $class->create_eval_temp_file($gld_file, $is_middle, $eval_level);
    my $tmp_file2 = $class->create_eval_temp_file($sys_file, $is_middle, $eval_level);

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

    my $rec  = $gld > 0 ? $agr / $gld * 100 : 0.0;
    my $prec = $sys > 0 ? $agr / $sys * 100 : 0.0;
    my $f    = $rec + $prec > 0 ? (2 * $rec * $prec / ($rec + $prec)) : 0.0;

    my $res = "";
    $res .= sprintf("Recall: %.2f%% ($agr/$gld) ", $rec);
    $res .= sprintf("Precision: %.2f%% ($agr/$sys) ", $prec);
    $res .= sprintf("F-measure: %.2f%%\n", $f);

    return $res;
}

sub create_eval_temp_file {
    my ($class, $file, $is_middle, $eval_level) = @_;

    my ($tmp_fh, $tmp_file) = tempfile;
    open(IN, $file) || die "Can't open $file: $!\n";
    while ( <IN> ) {
        next if /^\#/ || /^\*/;
        next if /^EOS/;
        chomp;

        my @morph = split /\s+/;
        my @pos;
        if ( $is_middle ) {
            print $tmp_fh "$morph[0]\n";
        } else {
            my @target = $eval_level eq "pos" ? @morph[0, 3..5] :
                $eval_level eq "boundary" ? ($morph[0]) : @morph[0..5];
            print $tmp_fh join(" ", @target), "\n";
        }
    }
    close(IN);
    $tmp_fh->close;

    return $tmp_file;
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
