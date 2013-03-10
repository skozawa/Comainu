# -*- mode: perl; coding: utf-8; -*-

package LCSDiff;

use strict;

my $DEFAULT_VALUES =
{
    "-D" => undef,
};

sub new {
    my $proto = shift;
    my $class = $proto or ref($proto);
    my $self = {%$DEFAULT_VALUES, @_};
    bless $self, $class;
    return $self;
}

sub diff {
    my $self = shift;
    my ($file1, $file2, $out_func) = @_;
    unless($out_func) {
        $out_func = sub { print STDOUT $_[0]; };
    }
    my $fh1 = \*STDIN;
    if ($file1 ne "-") {
        open($fh1, $file1) or die "Cannot open '$file1'";
    }
    my $str1 = join("", (<$fh1>));
    if ($file1 ne "-") {
        close($fh1);
    }
    my $fh2 = \*STDIN;
    if ($file2 ne "-") {
        open($fh2, $file2) or die "Cannot open '$file2'";
    }
    my $str2 = join("", (<$fh2>));
    if ($file2 ne "-") {
        close($fh2);
    }
    return $self->diff_str($str1, $str2, $out_func);
}

sub diff_str {
    my $self = shift;
    my ($str1, $str2, $out_func) = @_;
    unless($out_func) {
        $out_func = sub { print STDOUT $_[0]; };
    }
    my $seq1 = [split(/\r?\n/, $str1)];
    my $seq2 = [split(/\r?\n/, $str2)];
    return $self->diff_seq($seq1, $seq2, $out_func);
}

sub diff_seq {
    my $self = shift;
    my ($seq1, $seq2, $out_func) = @_;
    unless($out_func) {
        $out_func = sub { print STDOUT $_[0]; };
    }
    $self->calc_lcs($seq1, $seq2);
    if ($self->{"-D"}) {
        $self->out_merge($out_func);
    } else {
        $self->out_normal($out_func);
    }
    return $self;
}

sub calc_lcs {
    my $self = shift;
    my ($seq1, $seq2) = @_;
    my $seq1_len = scalar(@$seq1);
    my $seq2_len = scalar(@$seq2);

    my $matrix = [];
    for (my $i = 0; $i < $seq1_len + 1; ++$i) {
        $matrix->[$i] = [];
        for (my $j = 0; $j < $seq2_len + 1; ++$j) {
            $matrix->[$i][$j] = 0;
        }
    }
    for (my $i = $seq1_len - 1; $i >= 0; --$i) {
        for (my $j = $seq2_len - 1; $j >= 0; --$j) {
            if ($seq1->[$i] eq $seq2->[$j]) {
                $matrix->[$i][$j] = $matrix->[$i + 1][$j + 1] + 1;
            } else {
                my $max = $matrix->[$i][$j + 1];
                if ($max < $matrix->[$i + 1][$j]) {
                    $max = $matrix->[$i + 1][$j];
                }
                $matrix->[$i][$j] = $max;
            }
        }
    }
    $self->{"seq1"} = $seq1;
    $self->{"seq2"} = $seq2;
    $self->{"matrix"} = $matrix;
    return $self;
}

sub out_normal {
    my $self = shift;
    my ($out_func) = @_;
    unless($out_func) {
        $out_func = sub { print $_[0]; };
    }
    my $matrix = $self->{"matrix"};
    my $seq1 = $self->{"seq1"};
    my $seq2 = $self->{"seq2"};
    my $seq1_len = scalar(@$seq1);
    my $seq2_len = scalar(@$seq2);
    my $flag = 0;
    my $buff1 = "";
    my $buff2 = "";
    my $info = [0, 0];
    my ($i, $j) = (0, 0);
    while ($i < $seq1_len and $j < $seq2_len) {
        if ($seq1->[$i] eq $seq2->[$j]) {
            if ($flag != 0) {
                my $info_str = "";
                $info_str .= $info->[0];
                if ($info->[0] < $i) {
                    $info_str .= ",".$i;
                }
                if ($buff1 eq "" and $buff2 ne "") {
                    $info_str .= "a";
                } elsif ($buff1 ne "" and $buff2 eq "") {
                    $info_str .= "d";
                } else {
                    $info_str .= "c";
                }
                $info_str .= $info->[1];
                if ($info->[1] < $j) {
                    $info_str .= ",".$j;
                }
                $out_func->($info_str."\n");
                $out_func->($buff1);
                if ($buff2 ne "") {
                    if ($buff1 ne "") {
                        $out_func->("---\n");
                    }
                    $out_func->($buff2);
                }
                $flag = 0;
            }
            $buff1 = "";
            $buff2 = "";
            ++$i;
            ++$j;
        } elsif ($matrix->[$i][$j + 1] > $matrix->[$i + 1][$j]) {
            if ($flag != 2) {
                $info->[1] = $j + 1;
                $flag = 2;
            }
            $buff2 .= sprintf("> %s\n", $seq2->[$j]);
            ++$j;
        } else {
            if ($flag != 1) {
                $info->[0] = $i + 1;
                $flag = 1;
            }
            $buff1 .= sprintf("< %s\n", $seq1->[$i]);
            ++$i;
        }
    }
    $info->[1] = $j;
    while ($j < $seq2_len) {
        if ($flag != 2) {
            $info->[1] = $j + 1;
            $flag = 2;
        }
        $buff2 .= sprintf("> %s\n", $seq2->[$j]);
        ++$j;
    }
    $info->[0] = $i;
    while ($i < $seq1_len) {
        if ($flag != 1) {
            $info->[0] = $i + 1;
            $flag = 1;
        }
        $buff1 .= sprintf("< %s\n", $seq1->[$i]);
        ++$i;
    }
    if ($flag != 0) {
        my $info_str = "";
        $info_str .= $info->[0];
        if ($info->[0] < $i) {
            $info_str .= ",".$i;
        }
        if ($buff1 eq "" and $buff2 ne "") {
            $info_str .= "a";
        } elsif ($buff1 ne "" and $buff2 eq "") {
            $info_str .= "d";
        } else {
            $info_str .= "c";
        }
        $info_str .= $info->[1];
        if ($info->[1] < $j) {
            $info_str .= ",".$j;
        }
        $out_func->($info_str."\n");
        $out_func->($buff1);
        if ($buff2 ne "") {
            if ($buff1 ne "") {
                $out_func->("---\n");
            }
            $out_func->($buff2);
        }
        $flag = 0;
    }
    return $self;
}

sub out_merge {
    my $self = shift;
    my ($out_func) = @_;
    unless($out_func) {
        $out_func = sub { print STDOUT $_[0]; };
    }
    my ($org_str, $alt_str, $end_str);
    my $sep = $self->{"-D"};
    if (ref($sep) =~ /ARRAY/) {
        ($org_str, $alt_str, $end_str) = @$sep;
    } else {
        $org_str = sprintf("#ifndef %s", $sep);
        $alt_str = sprintf("#else /* %s */", $sep);
        $end_str = sprintf("#endif /* %s */", $sep);
    }
    my $matrix = $self->{"matrix"};
    my $seq1 = $self->{"seq1"};
    my $seq2 = $self->{"seq2"};
    my $seq1_len = scalar(@$seq1);
    my $seq2_len = scalar(@$seq2);
    my $flag = 0;
    my ($i, $j) = (0, 0);
    while ($i < $seq1_len and $j < $seq2_len) {
        if ($seq1->[$i] eq $seq2->[$j]) {
            if ($flag != 0) {
                $out_func->($end_str."\n");
                $flag = 0;
            }
            $out_func->($seq1->[$i]."\n");
            ++$i;
            ++$j;
        } elsif ($matrix->[$i][$j + 1] > $matrix->[$i + 1][$j]) {
            if ($flag != 2) {
                $out_func->($alt_str."\n");
                $flag = 2;
            }
            $out_func->($seq2->[$j]."\n");
            ++$j;
        } else {
            if ($flag != 1) {
                $out_func->($org_str."\n");
                $flag = 1;
            }
            $out_func->($seq1->[$i]."\n");
            ++$i;
        }
    }
    while ($j < $seq2_len) {
        if ($flag != 2) {
            $out_func->($alt_str."\n");
            $flag = 2;
        }
        $out_func->($seq2->[$j]."\n");
        ++$j;
    }
    while ($i < $seq1_len) {
        if ($flag != 1) {
            $out_func->($org_str."\n");
            $flag = 1;
        }
        $out_func->($seq1->[$i]."\n");
        ++$i;
    }
    if ($flag != 0) {
        $out_func->($end_str."\n");
        $flag = 0;
    }
    return $self;
}

1;
#################### END OF FILE ####################
