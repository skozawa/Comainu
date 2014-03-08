package Comainu::Method::Kc2bnsteval;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename dirname);
use Config;

use Comainu::Util qw(read_from_file write_to_file);
use Comainu::Evaluate;

sub new {
    my ($class, %args) = @_;
    $class->SUPER::new( %args, args_num => 4 );
}

# Evalution for the model for analyzing bunsetsu boudnary
sub usage {
    my $self = shift;
    while ( <DATA> ) {
        print $_;
    }
}

sub run {
    my ($self, $correct_kc, $result_kc_bout, $save_dir) = @_;

    $self->before_analyze({ dir => $save_dir, args_num => scalar @_ });

    $self->evaluate_files($correct_kc, $result_kc_bout, $save_dir);

    return 0;
}

sub evaluate {
    my ($self, $correct_kc, $result_kc_bout, $save_dir) = @_;
    $self->compare($correct_kc, $result_kc_bout, $save_dir);
}

sub compare {
    my ($self, $kc_file, $bout_file, $save_dir) = @_;
    print STDERR "_compare\n";
    my $res = "";

    my $tmp1_file = $self->{"comainu-temp"} . "/" . basename($kc_file, ".KC") . ".bnst";

    if ( -s $tmp1_file ) {
        print STDERR "Use Cache \'$tmp1_file\'.\n";
    } else {
        unless ( -f $kc_file ) {
            print STDERR "ERROR: \'$1\' not Found.\n";
            return $res;
        }
        my $buff = read_from_file($kc_file);
        $buff = $self->short2bnst($buff);
        write_to_file($tmp1_file, $buff);
        undef $buff;
    }

    unless ( -f $bout_file ) {
        print STDERR "ERROR: \'$2\' not Found.\n";
        return $res;
    }

    my $tmp2_file = $self->{"comainu-temp"} . "/" . basename($bout_file, ".bout") . ".svmout_create.bnst";
    my $buff = read_from_file($bout_file);
    $buff = $self->short2bnst($buff);
    write_to_file($tmp2_file, $buff);
    undef $buff;

    my $output_file = $save_dir . "/" . basename($bout_file, ".bout") . ".eval.bnst";

    $res = Comainu::Evaluate->eval_long($tmp1_file, $tmp2_file, 1);
    write_to_file($output_file, $res);
    print $res;

    return $res;
}

sub short2bnst {
    my ($self, $data) = @_;
    my $res = "";

    my $BOB = "B";
    foreach ( split(/\r?\n/, $data) ) {
        my @morph = split(/[ \t]/);
        if ( $morph[0] =~ /^\*B|^EOS/ ) {
            $BOB = "B";
            next;
        } elsif ( $morph[0] eq "B" || $morph[0] eq "I" ) {
            $BOB = shift(@morph);
        }
        if ( $BOB eq "B" ) {
            $BOB = "I";
            $res .= "\n" if $res ne "";
        }
        $res .= $morph[0];
    }

    undef $data;

    return $res;
}


1;


__DATA__
COMAINU-METHOD: kc2bnsteval
  Usage: ./script/comainu.pl kc2bnsteval <ref-kc> <kc-bout> <out-dir>
    This command makes a evaluation for <kc-bout> with <ref-kc>.
    The result is put into <out-dir>

  option
    --help                    show this message and exit

  ex.)
  $ perl ./script/comainu.pl kc2bnsteval sample/sample.KC out/sample.KC.bout out
    -> out/sample.eval.bnst

