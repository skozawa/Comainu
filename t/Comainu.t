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




# sub USAGE_kc2longout : Tests {};
# sub METHOD_kc2longout : Tests {};
# sub kc2longout_internal : Tests {};
# sub create_features : Tests {};
# sub chunk_luw : Tests {};
# sub merge_chunk_result : Tests {};
# sub post_process : Tests {};
# sub USAGE_kc2bnstout : Tests {};
# sub METHOD_kc2bnstout : Tests {};
# sub kc2bnstout_internal : Tests {};
# sub format_bnstdata : Tests {};
# sub chunk_bnst : Tests {};
# sub USAGE_kclong2midout : Tests {};
# sub METHOD_kclong2midout : Tests {};
# sub kclong2midout_internal : Tests {};
# sub create_mstin : Tests {};
# sub parse_muw : Tests {};
# sub merge_mst_result : Tests {};
# sub USAGE_bccwj2longout : Tests {};
# sub METHOD_bccwj2longout : Tests {};
# sub bccwj2longout_internal : Tests {};
# sub USAGE_bccwj2bnstout : Tests {};
# sub METHOD_bccwj2bnstout : Tests {};
# sub bccwj2bnstout_internal : Tests {};
# sub USAGE_bccwj2longbnstout : Tests {};
# sub METHOD_bccwj2longbnstout : Tests {};
# sub bccwj2longbnstout_internal : Tests {};
# sub USAGE_bccwj2midout : Tests {};
# sub METHOD_bccwj2midout : Tests {};
# sub bccwj2midout_internal : Tests {};
# sub USAGE_bccwj2midbnstout : Tests {};
# sub METHOD_bccwj2midbnstout : Tests {};
# sub bccwj2midbnstout_internal : Tests {};
# sub USAGE_bccwjlong2midout : Tests {};
# sub METHOD_bccwjlong2midout : Tests {};
# sub bccwjlong2midout_internal : Tests {};
# sub USAGE_plain2longout : Tests {};
# sub METHOD_plain2longout : Tests {};
# sub plain2longout_internal : Tests {};
# sub USAGE_plain2bnstout : Tests {};
# sub METHOD_plain2bnstout : Tests {};
# sub plain2bnstout_internal : Tests {};
# sub METHOD_plain2bnstout : Tests {};
# sub plain2bnstout_internal : Tests {};
# sub USAGE_plain2longbnstout : Tests {};
# sub METHOD_plain2longbnstout : Tests {};
# sub plain2longbnstout_internal : Tests {};
# sub USAGE_plain2midout : Tests {};
# sub METHOD_plain2midout : Tests {};
# sub plain2midout_internal : Tests {};
# sub USAGE_plain2midbnstout : Tests {};
# sub METHOD_plain2midbnstout : Tests {};
# sub plain2midbnstout_internal : Tests {};
# sub plain2mecab_file : Tests {};
# sub mecab2kc_file : Tests {};
# sub USAGE_kc2longmodel : Tests {};
# sub METHOD_kc2longmodel : Tests {};
# sub make_luw_traindata : Tests {};
# sub add_luw_label : Tests {};
# sub train_luwmodel_svm : Tests {};
# sub train_luwmodel_crf : Tests {};
# sub train_bi_model : Tests {};
# sub USAGE_kc2bnstmodel : Tests {};
# sub METHOD_kc2bnstmodel : Tests {};
# sub train_bnstmodel : Tests {};
# sub add_bnst_label : Tests {};
# sub USAGE_kclong2midmodel : Tests {};
# sub METHOD_kclong2midmodel : Tests {};
# sub create_mid_traindata : Tests {};
# sub train_midmodel : Tests {};
# sub USAGE_kc2longeval : Tests {};
# sub METHOD_kc2longeval : Tests {};
# sub kc2longeval_internal : Tests {};
# sub compare : Tests {};
# sub USAGE_kc2bnsteval : Tests {};
# sub METHOD_kc2bnsteval : Tests {};
# sub kc2bnsteval_internal : Tests {};
# sub compare_bnst : Tests {};
# sub USAGE_kclong2mideval : Tests {};
# sub METHOD_kclong2mideval : Tests {};
# sub kclong2mideval_internal : Tests {};
# sub compare_mid : Tests {};
# sub eval_long : Tests {};
# sub diff_perl : Tests {};
# sub create_long_lemma : Tests {};
# sub generate_long_lemma : Tests {};
# sub create_mstfeature : Tests {};
# sub create_middle : Tests {};
# sub add_pivot_to_kc2 : Tests {};
# sub delete_column_long : Tests {};
# sub move_future_front : Tests {};
# sub truncate_last_column : Tests {};
# sub pp_partial : Tests {};
# sub pp_partial_bnst_with_luw : Tests {};
# sub bccwj2kc_file : Tests {};
# sub bccwjlong2kc_file : Tests {};
# sub bccwj2kc : Tests {};
# sub kc2bnstsvmdata : Tests {};
# sub kc2mstin : Tests {};
# sub lout2kc4mid_file : Tests {};
# sub mecab2kc : Tests {};
# sub format_inputdata : Tests {};
# sub trans_dataformat : Tests {};
# sub short2long : Tests {};
# sub short2bnst : Tests {};
# sub short2middle : Tests {};

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

sub merge_kc_with_mstout : Test(1) {
    my $comainu = Comainu->new;
    my $buff = $comainu->merge_kc_with_mstout("t/sample/test.plain.KC", "t/sample/test.plain.mstout");
    my $gold_buff = $comainu->read_from_file("t/sample/test.plain.KC.mout");

    is $gold_buff, $buff;
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

sub create_template : Test(1) {
    my $template_buff = "";
    my $g = guard_write_to_file(\$template_buff);

    my $comainu = Comainu->new;
    $comainu->create_template("file", 6);

    my $expected_buff = <<FEATURE;
U1:%x[-2,0]
U2:%x[-1,0]
U3:%x[0,0]
U4:%x[1,0]
U5:%x[2,0]
U6:%x[-2,0]/%x[-1,0]
U7:%x[-1,0]/%x[0,0]
U8:%x[0,0]/%x[1,0]
U9:%x[1,0]/%x[2,0]
U10:%x[-2,0]/%x[-1,0]/%x[0,0]
U11:%x[-1,0]/%x[0,0]/%x[1,0]
U12:%x[0,0]/%x[1,0]/%x[2,0]
U13:%x[-2,2]
U14:%x[-1,2]
U15:%x[0,2]
U16:%x[1,2]
U17:%x[2,2]
U18:%x[-2,2]/%x[-1,2]
U19:%x[-1,2]/%x[0,2]
U20:%x[0,2]/%x[1,2]
U21:%x[1,2]/%x[2,2]
U22:%x[-2,2]/%x[-1,2]/%x[0,2]
U23:%x[-1,2]/%x[0,2]/%x[1,2]
U24:%x[0,2]/%x[1,2]/%x[2,2]
U25:%x[-2,3]
U26:%x[-1,3]
U27:%x[0,3]
U28:%x[1,3]
U29:%x[2,3]
U30:%x[-2,3]/%x[-1,3]
U31:%x[-1,3]/%x[0,3]
U32:%x[0,3]/%x[1,3]
U33:%x[1,3]/%x[2,3]
U34:%x[-2,3]/%x[-1,3]/%x[0,3]
U35:%x[-1,3]/%x[0,3]/%x[1,3]
U36:%x[0,3]/%x[1,3]/%x[2,3]
U37:%x[-2,4]
U38:%x[-1,4]
U39:%x[0,4]
U40:%x[1,4]
U41:%x[2,4]
U42:%x[-2,4]/%x[-1,4]
U43:%x[-1,4]/%x[0,4]
U44:%x[0,4]/%x[1,4]
U45:%x[1,4]/%x[2,4]
U46:%x[-2,4]/%x[-1,4]/%x[0,4]
U47:%x[-1,4]/%x[0,4]/%x[1,4]
U48:%x[0,4]/%x[1,4]/%x[2,4]
U49:%x[-2,5]
U50:%x[-1,5]
U51:%x[0,5]
U52:%x[1,5]
U53:%x[2,5]
U54:%x[-2,5]/%x[-1,5]
U55:%x[-1,5]/%x[0,5]
U56:%x[0,5]/%x[1,5]
U57:%x[1,5]/%x[2,5]
U58:%x[-2,5]/%x[-1,5]/%x[0,5]
U59:%x[-1,5]/%x[0,5]/%x[1,5]
U60:%x[0,5]/%x[1,5]/%x[2,5]
U61:%x[-2,6]
U62:%x[-1,6]
U63:%x[0,6]
U64:%x[1,6]
U65:%x[2,6]
U66:%x[-2,6]/%x[-1,6]
U67:%x[-1,6]/%x[0,6]
U68:%x[0,6]/%x[1,6]
U69:%x[1,6]/%x[2,6]
U70:%x[-2,6]/%x[-1,6]/%x[0,6]
U71:%x[-1,6]/%x[0,6]/%x[1,6]
U72:%x[0,6]/%x[1,6]/%x[2,6]

U73:%x[-2,2]/%x[-1,3]
U74:%x[-2,3]/%x[-1,2]
U75:%x[-1,2]/%x[0,3]
U76:%x[-1,3]/%x[0,2]
U77:%x[0,2]/%x[1,3]
U78:%x[0,3]/%x[1,2]
U79:%x[1,2]/%x[2,3]
U80:%x[1,3]/%x[2,2]

U81:%x[-2,2]/%x[-1,4]
U82:%x[-2,4]/%x[-1,2]
U83:%x[-1,2]/%x[0,4]
U84:%x[-1,4]/%x[0,2]
U85:%x[0,2]/%x[1,4]
U86:%x[0,4]/%x[1,2]
U87:%x[1,2]/%x[2,4]
U88:%x[1,4]/%x[2,2]

U89:%x[-2,2]/%x[-1,5]
U90:%x[-2,5]/%x[-1,2]
U91:%x[-1,2]/%x[0,5]
U92:%x[-1,5]/%x[0,2]
U93:%x[0,2]/%x[1,5]
U94:%x[0,5]/%x[1,2]
U95:%x[1,2]/%x[2,5]
U96:%x[1,5]/%x[2,2]

U97:%x[-2,2]/%x[-2,3]/%x[-1,3]
U98:%x[-2,3]/%x[-1,2]/%x[-1,3]
U99:%x[-1,2]/%x[-1,3]/%x[0,3]
U100:%x[-1,3]/%x[0,2]/%x[0,3]
U101:%x[0,2]/%x[0,3]/%x[1,3]
U102:%x[0,3]/%x[1,2]/%x[1,3]
U103:%x[1,2]/%x[1,3]/%x[2,3]
U104:%x[1,3]/%x[2,2]/%x[2,3]

U105:%x[-2,2]/%x[-2,4]/%x[-1,4]
U106:%x[-2,4]/%x[-1,2]/%x[-1,4]
U107:%x[-1,2]/%x[-1,4]/%x[0,4]
U108:%x[-1,4]/%x[0,2]/%x[0,4]
U109:%x[0,2]/%x[0,4]/%x[1,4]
U110:%x[0,4]/%x[1,2]/%x[1,4]
U111:%x[1,2]/%x[1,4]/%x[2,4]
U112:%x[1,4]/%x[2,2]/%x[2,4]

U113:%x[-2,2]/%x[-2,5]/%x[-1,5]
U114:%x[-2,5]/%x[-1,2]/%x[-1,5]
U115:%x[-1,2]/%x[-1,5]/%x[0,5]
U116:%x[-1,5]/%x[0,2]/%x[0,5]
U117:%x[0,2]/%x[0,5]/%x[1,5]
U118:%x[0,5]/%x[1,2]/%x[1,5]
U119:%x[1,2]/%x[1,5]/%x[2,5]
U120:%x[1,5]/%x[2,2]/%x[2,5]


B
FEATURE

    is $template_buff, $expected_buff;
};

# sub create_BI_template : Tests {};
# sub check_luwmodel : Tests {};
# sub create_yamcha_makefile : Tests {};
# sub get_yamcha_tool_dir : Tests {};

sub load_yamcha_training_conf : Test(1) {
    my $confdata = <<CONF;
# Template file of YamCha settings     #
# use YamCha  : DIRECTION, FEATURE     #
# use TinySVM : SVM_PARAM, MULTI_CLASS #

SVM_PARAM="-t 1 -d 3 -c 1 -m 514"
FEATURE=
DIRECTION="-B"
MULTI_CLASS=2

CONF

    my $file = create_tmp_file($confdata);
    my $comainu = Comainu->new;
    my $conf = $comainu->load_yamcha_training_conf($file);

    is_deeply $conf, {
        SVM_PARAM   => "-t 1 -d 3 -c 1 -m 514",
        FEATURE     => '',
        DIRECTION   => "-B",
        MULTI_CLASS => 2,
    };
};


# sub check_yamcha_training_makefile_template : Tests {};

# sub add_column : Tests {};
# sub poscreate : Tests {};
# sub pp_ctype : Tests {};
# sub check_args : Tests {};
# sub check_file : Tests {};
# sub read_from_file : Tests {};
# sub write_to_file : Tests {};

sub proc_stdin2stdout : Test(1) {
    my $comainu = Comainu->new;
    is $comainu->proc_stdin2stdout('cat', 'test'), 'test';
};

sub proc_stdin2file : Test(1) {
    my $outfile = create_tmp_file("");
    my $comainu = Comainu->new;
    $comainu->proc_stdin2file('cat', 'test', $outfile);

    open(IN, $outfile);
    my $out_data = "";
    while (<IN>) {
        chomp;
        $out_data .= $_ . "\n";
    }
    close(IN);

    is $out_data, "test\n";
};

sub proc_file2file : Test(1) {
    my $infile  = create_tmp_file("test");
    my $outfile = create_tmp_file("");

    my $comainu = Comainu->new;
    $comainu->proc_file2file('cat', $infile, $outfile);

    open(IN, $outfile);
    my $out_data = "";
    while (<IN>) {
        chomp;
        $out_data .= $_ . "\n";
    }
    close(IN);

    is $out_data, "test\n";
};




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
