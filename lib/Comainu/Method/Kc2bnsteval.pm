package Comainu::Method::Kc2bnsteval;

use strict;
use warnings;
use utf8;
use parent 'Comainu::Method';
use File::Basename qw(basename dirname);
use Config;

use Comainu::Util qw(read_from_file write_to_file);

sub new {
    my ($class, %args) = @_;
    bless {
        args_num => 4,
        comainu  => delete $args{comainu},
        %args
    }, $class;
}

# 文節境界モデルの評価
sub usage {
    my $self = shift;
    printf("COMAINU-METHOD: kc2bnsteval\n");
    printf("  Usage: %s kc2bnsteval <ref-kc> <kc-lout> <out-dir>\n", $0);
    printf("    This command make a evaluation for <kc-lout> with <ref-kc>.\n");
    printf("    The result is put into <out-dir>.\n");
    printf("\n");
    printf("  ex.)\n");
    printf("  perl ./script/comainu.pl kc2bnsteval sample/sample.KC out/sample.KC.bout out\n");
    printf("    -> out/sample.eval.bnst\n");
    printf("\n");
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

    # 中間ファイル
    my $tmp1_file = $self->comainu->{"comainu-temp"} . "/" .
        basename($kc_file, ".KC") . ".bnst";

    if ( -s $tmp1_file ) {
        print STDERR "Use Cache \'$tmp1_file\'.\n";
    } else {
        unless ( -f $kc_file ) {
            print STDERR "ERROR: \'$1\' not Found.\n";
            return $res;
        }
        my $buff = read_from_file($kc_file);
        $buff = $self->comainu->short2bnst($buff);
        write_to_file($tmp1_file, $buff);
        undef $buff;
    }

    unless ( -f $bout_file ) {
        print STDERR "ERROR: \'$2\' not Found.\n";
        return $res;
    }

    # 中間ファイル
    my $tmp2_file = $self->comainu->{"comainu-temp"} . "/" .
        basename($bout_file, ".bout") . ".svmout_create.bnst";
    my $buff = read_from_file($bout_file);
    $buff = $self->comainu->short2bnst($buff);
    write_to_file($tmp2_file, $buff);
    undef $buff;

    my $output_file = $save_dir . "/" .
        basename($bout_file, ".bout") . ".eval.bnst";

    $res = $self->comainu->eval_long($tmp1_file, $tmp2_file, 1);
    write_to_file($output_file, $res);
    print $res;

    return $res;
}


1;
