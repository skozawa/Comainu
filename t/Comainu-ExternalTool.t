package t::Comainu::ExternalTool;
use strict;
use warnings;
use utf8;

use lib 'lib', 't/lib';
use Test::Comainu;

use parent 'Test::Class';
use Test::More;
use Test::Mock::Guard;

sub _use_ok : Test(startup => 1) {
    use_ok 'Comainu::ExternalTool';
}

sub create_crf_template : Test(1) {
    my $template_buff = "";
    my $g = guard_write_to_file('Comainu::ExternalTool', \$template_buff);

    my $external_tool = Comainu::ExternalTool->new;
    $external_tool->create_crf_template("file", 6);

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

# sub create_crf_BI_template : Tests {};
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
    my $external_tool = Comainu::ExternalTool->new;
    my $conf = $external_tool->load_yamcha_training_conf($file);

    is_deeply $conf, {
        SVM_PARAM   => "-t 1 -d 3 -c 1 -m 514",
        FEATURE     => '',
        DIRECTION   => "-B",
        MULTI_CLASS => 2,
    };
};

# sub check_yamcha_training_makefile_template : Tests {};

__PACKAGE__->runtests;
