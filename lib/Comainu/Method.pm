package Comainu::Method;

use strict;
use warnings;

use Comainu::Util qw(get_dir_files);

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
    my ($self, $num, $save_dir) = @_;
    $self->check_args_num($num);
    mkdir $save_dir unless -d $save_dir;
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
