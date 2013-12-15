package Comainu::Method;

use strict;
use warnings;

use Comainu::Util qw(get_dir_files check_file);

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
    $self->comainu->check_luwmodel($args->{luwmodel}) if $args->{luwmodel};
    foreach ( qw(bnstmodel muwmodel) ) {
        check_file($args->{$_}) if $args->{$_};
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
