package t::Comainu;
use strict;
use warnings;
use utf8;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

use Encode;
use File::Temp;

use Comainu;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu';
};


sub merge_bccwj_with_kc_lout_file : Test(1) {
    my $lout_buff = "";
    my $g = guard_write_to_file(\$lout_buff);

    my $comainu = Comainu->new;
    $comainu->merge_bccwj_with_kc_lout_file("t/sample/test.bccwj.txt", "t/sample/test.bccwj.KC.lout", "lout_file");

    my $gold_lout_buff = $comainu->read_from_file("t/sample/test.bccwj.lout");

    is $gold_lout_buff, $lout_buff;
};

# sub merge_iof : Tests {};

sub merge_bccwj_with_kc_bout_file : Test(1) {
    my $bout_buff = "";
    my $g = guard_write_to_file(\$bout_buff);

    my $comainu = Comainu->new;
    $comainu->merge_bccwj_with_kc_bout_file("t/sample/test.bccwj.txt", "t/sample/test.bccwj.KC.bout", "bout_file");

    my $gold_bout_buff = $comainu->read_from_file("t/sample/test.bccwj.bout");

    is $gold_bout_buff, $bout_buff;
};

sub merge_bccwj_with_kc_mout_file : Test(1) {
    my $mout_buff = "";
    my $g = guard_write_to_file(\$mout_buff);

    my $comainu = Comainu->new;
    $comainu->merge_bccwj_with_kc_mout_file("t/sample/test.bccwj.long.txt", "t/sample/test.bccwj.long.KC.mout", "mout_file");

    my $gold_mout_buff = $comainu->read_from_file("t/sample/test.bccwj.long.mout");

    is $gold_mout_buff, $mout_buff;
};

sub merge_mecab_with_kc_lout_file : Test(1) {
    my $lout_buff = "";
    my $g = guard_write_to_file(\$lout_buff);

    my $comainu = Comainu->new;
    $comainu->merge_mecab_with_kc_lout_file("t/sample/test.plain.mecab", "t/sample/test.plain.KC.lout", "lout_file");

    my $gold_lout_buff = $comainu->read_from_file("t/sample/test.plain.lout");

    is $gold_lout_buff, $lout_buff;
};

sub merge_mecab_with_kc_bout_file : Test(1) {
    my $bout_buff = "";
    my $g = guard_write_to_file(\$bout_buff);

    my $comainu = Comainu->new;
    $comainu->merge_mecab_with_kc_bout_file("t/sample/test.plain.mecab", "t/sample/test.plain.KC.bout", "bout_file");

    my $gold_bout_buff = $comainu->read_from_file("t/sample/test.plain.bout");

    is $gold_bout_buff, $bout_buff;
};

sub merge_mecab_with_kc_mout_file : Test(1) {
    my $mout_buff = "";
    my $g = guard_write_to_file(\$mout_buff);

    my $comainu = Comainu->new;
    $comainu->merge_mecab_with_kc_mout_file("t/sample/test.plain.mecab", "t/sample/test.plain.KC.mout", "mout_file");

    my $gold_mout_buff = $comainu->read_from_file("t/sample/test.plain.mout");

    is $gold_mout_buff, $mout_buff;
};

sub merge_kc_with_svmout : Test(1) {
    my $comainu = Comainu->new;
    my $buff = $comainu->merge_kc_with_svmout("t/sample/test.plain.KC", "t/sample/test.plain.svmout");
    my $gold_buff = $comainu->read_from_file("t/sample/test.plain.KC.svmout.lout");

    is $gold_buff, $buff;
};

sub merge_kc_with_bout : Test(1) {
    my $comainu = Comainu->new;
    my $buff = $comainu->merge_kc_with_bout("t/sample/test.KC", "t/sample/test.svmdata.bout");
    my $gold_buff = $comainu->read_from_file("t/sample/test.bout");

    is $gold_buff, $buff;
};

# sub add_column : Tests {};
# sub poscreate : Tests {};
# sub pp_ctype : Tests {};
# sub check_args : Tests {};


sub create_tmp_file {
    my $data = shift;

    my $fh   = File::Temp->new;
    my $file = $fh->filename;
    print $fh encode_utf8 $data;
    close $fh;

    return ($file, $fh);
}

sub guard_write_to_file {
    my $data = shift;

    mock_guard('Comainu', {
        write_to_file => sub {
            my ($self, $tmp_file, $buff) = @_;
            $$data = $buff;
        }
    });
}



__PACKAGE__->runtests;
