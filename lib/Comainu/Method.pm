package Comainu::Method;

use strict;
use warnings;
use utf8;
use FindBin qw($Bin);

use Comainu::Util qw(get_dir_files check_file);

my $DEFAULT_VALUES = {
    "debug"                    => 0,
    "comainu-home"             => $Bin . "/..",
    "comainu-temp"             => $Bin . "/../tmp/temp",
    "comainu-bi-model-dir"     => "",
    "comainu-bi-model-default" => $Bin . "/../train/BI_model",
    "model-name"               => "train",
    "data_format"              => $Bin . "/../etc/data_format.conf",
    "mecab_rcfile"             => $Bin . "/../etc/dicrc",
    "perl"                     => "/usr/bin/perl",
    "java"                     => "/usr/bin/java",
    "yamcha-dir"               => "/usr/local/bin",
    "mecab-dir"                => "/usr/local/bin",
    "mecab-dic-dir"            => "/usr/local/lib/mecab/dic",
    "unidic-db"                => "/usr/local/unidic2/share/unidic.db",
    "svm-tool-dir"             => "/usr/local/bin",
    "crf-dir"                  => "/usr/local/bin",
    "mstparser-dir"            => "mstparser",
    "boundary"                 => "sentence",
    "luwmrph"                  => "with",
    "suwmodel"                 => "mecab",
    "luwmodel"                 => "CRF",
    "bnst_process"             => "none",
    "comp_file"                => $Bin . "/../etc/Comp.txt",
    "pos_label_file"           => $Bin . '/../etc/pos_label',
    "cType_label_file"         => $Bin . '/../etc/cType_label',
    "cForm_label_file"         => $Bin . '/../etc/cForm_label',
};

sub new {
    my ($class, %args) = @_;
    bless { %$DEFAULT_VALUES, %args }, $class;
}

sub args_num {
    my $self = shift;
    $self->{args_num};
}

sub comainu {
    my $self = shift;
    $self->{comainu};
}

sub check_args_num {
    my ($self, $num) = @_;

    return if $self->args_num == $num;
    $self->usage;
    exit 1;
}

sub before_analyze {
    my ($self, $args) = @_;
    $self->check_args_num($args->{args_num});
    mkdir $args->{dir} if $args->{dir} && !-d $args->{dir};
    $self->check_luwmodel($args->{luwmodel}) if $args->{luwmodel};
    foreach ( qw(bnstmodel muwmodel) ) {
        check_file($args->{$_}) if $args->{$_};
    }
}

sub check_luwmodel {
   my ($self, $luwmodel) = @_;

   if ( $self->{luwmodel} eq "SVM" || $self->{luwmodel} eq "CRF" ) {
       check_file($luwmodel);
   } else {
       printf(STDERR "ERROR: '%s' not found model name.\n",
              $self->{luwmodel});
       die;
   }
}


sub analyze_files {
    my $self = shift;
    my $test_file = shift;
    my @args = @_;

    my $ext = ref($self) =~ /Comainu::Method::Kc/ ? 'KC' : 'txt';
    foreach my $file ( @{get_dir_files($test_file, $ext)} ) {
        $self->analyze($file, @args);
    }
}

sub evaluate_files {
    my $self = shift;
    my $correct_file = shift;
    my $result_file = shift;
    my @args = @_;

    my $ext = ref($self) =~ /Comainu::Method::Kc/ ? 'KC' : 'txt';
    foreach my $file ( @{get_dir_files($result_file, $ext)} ) {
        $self->evaluate($correct_file, $file, @args);
    }
}

1;
