package Comainu::Method;

use strict;
use warnings;

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

1;
