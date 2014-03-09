package Comainu::Method::Kclong2mideval;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename dirname);
use Config;

use Comainu::Util qw(read_from_file write_to_file);
use Comainu::Evaluate;

# Evalution for the middle-word-unit model
sub new {
    my ($class, %args) = @_;
    $class->SUPER::new( %args, args_num => 4 );
}

sub usage {
    my $self = shift;
    while ( <DATA> ) {
        print $_;
    }
}

sub run {
    my ($self, $correct_kc, $result_kc_mout, $save_dir) = @_;

    $self->before_analyze({ dir => $save_dir, args_num => scalar @_ });

    $self->evaluate_files($correct_kc, $result_kc_mout, $save_dir);

    return 0;
}

sub evaluate {
    my ($self, $correct_kc, $result_kc_mout, $save_dir) = @_;
    $self->compare($correct_kc, $result_kc_mout, $save_dir);
}

sub compare {
    my ($self, $kc_file, $mout_file, $save_dir) = @_;
    print STDERR "# Ccompare\n";
    my $res = "";

    # 中間ファイル
    my $tmp1_file = $self->{"comainu-temp"} . "/" .
        basename($kc_file, ".KC") . ".mid";

    if ( -s $tmp1_file ) {
        print STDERR "Use Cache \'$tmp1_file\'.\n";
    } else {
        unless ( -f $kc_file ) {
            print STDERR "ERROR: \'$1\' not Found.\n";
            return $res;
        }
        my $buff = read_from_file($kc_file);
        $buff = $self->short2middle($buff);
        write_to_file($tmp1_file, $buff);
        undef $buff;
    }

    unless ( -f $mout_file ) {
        print STDERR "ERROR: \'$2\' not Found.\n";
        return $res;
    }

    my $tmp2_file = $self->{"comainu-temp"} . "/" .
        basename($mout_file, ".mout") . ".svmout_create.mid";
    my $buff = read_from_file($mout_file);
    $buff = $self->short2middle($buff);
    write_to_file($tmp2_file, $buff);
    undef $buff;

    my $output_file = $save_dir . "/" .
        basename($mout_file, ".mout").".eval.mid";

    $res = Comainu::Evaluate->eval_long($tmp1_file, $tmp2_file, 1);
    write_to_file($output_file, $res);
    print $res;

    return $res;
}

sub short2middle {
    my ($self, $data) = @_;
    my $res = "";

    my @muws;
    my $muw_id = -1;
    foreach my $line ( split(/\r?\n/,$data) ) {
        my $mrph = [split(/[ \t]/, $line)];
        next if $$mrph[0] =~ /^\*B|^EOS/;

        $muw_id++ if $$mrph[21] && $$mrph[21] ne "" && $$mrph[21] ne "*";
        push @{$muws[$muw_id]},$mrph;
    }
    foreach my $muw (@muws) {
        if ( scalar(@$muw) > 0 ) {
            my $first = $$muw[0];
            $res .= $$first[21]."\n";
        }
    }

    undef $data;

    return $res;
}


1;


__DATA__
COMAINU-METHOD: kclong2mideval
  Usage: ./script/comainu.pl kclong2mideval <ref-kc> <kc-mout> <out-dir>
    This command makes a evaluation for <kc-mout> with <ref-kc>.
    The result is put into <out-dir>

  option
    --help                    show this message and exit

  ex.)
  $ perl ./script/comainu.pl kclong2mideval sample/sample_mid.KC out/sample_mid.KC.mout out
    -> out/sample.eval.mid

