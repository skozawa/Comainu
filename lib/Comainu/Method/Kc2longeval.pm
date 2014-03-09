package Comainu::Method::Kc2longeval;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename dirname);
use Config;

use Comainu::Util qw(read_from_file write_to_file);
use Comainu::Format;
use Comainu::Evaluate;

sub new {
    my ($class, %args) = @_;
    $class->SUPER::new( %args, args_num => 4 );
}

# Evalution for the model for analyzing long-unit-word
sub usage {
    my $self = shift;
    while ( <DATA> ) {
        print $_;
    }
}

sub run {
    my ($self, $correct_kc, $result_kc_lout, $save_dir) = @_;

    $self->before_analyze({ dir => $save_dir, args_num => scalar @_ });

    $self->evaluate_files($correct_kc, $result_kc_lout, $save_dir);

    return 0;
}

sub evaluate {
    my ($self, $correct_kc, $result_kc_lout, $save_dir) = @_;
    $self->compare($correct_kc, $result_kc_lout, $save_dir);
}

# Compare .KC file and .lout file
# Output the reuslt ".eval.long" file
sub compare {
    my ($self, $kc_file, $lout_file, $save_dir) = @_;
    print STDERR "# Compare\n";
    my $res = "";

    # KC file
    my $tmp1_file = $self->{"comainu-temp"} . "/" . basename($kc_file, ".KC").".long";
    # don't recreate if already exist
    if ( -s $tmp1_file ) {
        print STDERR "Use Cache \'$tmp1_file\'.\n";
    } else {
        unless ( -f $kc_file ) {
            print STDERR "ERROR: \'$1\' not Found.\n";
            return $res;
        }
        my $buff = read_from_file($kc_file);
        $buff = Comainu::Format->trans_dataformat($buff, {
            input_type       => 'input-kc',
            output_type      => 'kc',
            data_format_file => $self->{data_format},
        });
        $buff = $self->short2long($buff);
        write_to_file($tmp1_file, $buff);
        undef $buff;
    }

    unless ( -f $lout_file ) {
        print STDERR "ERROR: \'$2\' not Found.\n";
        return $res;
    }

    # lout file
    my $tmp2_file = $self->{"comainu-temp"} . "/" .
        basename($lout_file, ".lout") . ".svmout_create.long";
    my $buff = read_from_file($lout_file);
    $buff = $self->short2long($buff);
    write_to_file($tmp2_file, $buff);
    undef $buff;

    my $output_file = $save_dir . "/" .
        basename($lout_file, ".lout").".eval.long";

    $res = Comainu::Evaluate->eval_long($tmp1_file, $tmp2_file, 0, $self->{"longeval-level"});
    write_to_file($output_file, $res);
    print $res;

    return $res;
}

sub short2long {
    my ($self, $data) = @_;
    my $res = "";

    foreach ( split(/\r?\n/, $data) ) {
    	next if /^\*B/ || /^EOS/;

        my @elem = split(/[ \t]/);
        if ($elem[0] =~ /^[BI]/) { # remove B,Ba,I,Ia field *.lout
            shift(@elem);
        }
        $elem[16] = "*" if($elem[16] eq "");
        $elem[17] = "*" if($elem[17] eq "");
        if ($elem[13] ne "" && $elem[13] ne "*") {
            $res .= join(" ",@elem[18,16,17,13..15])."\n";
        }
    }
    undef $data;

    return $res;
}


1;


__DATA__
COMAINU-METHOD: kc2longeval
  Usage: ./script/comainu.pl kc2longeval <ref-kc> <kc-lout> <out-dir>
    This command makes a evaluation for <kc-lout> with <ref-kc>.
    The result is put into <out-dir>

  option
    --help                    show this message and exit

  ex.)
  $ perl ./script/comainu.pl kc2longeval sample/sample.KC out/sample.KC.lout out
    -> out/sample.eval.long

