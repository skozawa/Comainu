# -*- mode: perl; coding: utf-8 -*-

use strict;

package CommandWorker;

use utf8;
use Config;
use Time::HiRes;

my $DEFAULT_VALUES =
{
    "debug" => 0,
    "timer" => 0.2,
};

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {%$DEFAULT_VALUES, @_};
    bless $self, $class;
    $self->{"_res"} = undef;
    return $self;
}

sub DESTROY {
    my $self = shift;
}

sub system_nb {
    my $self = shift;
    my ($com) = @_;
    if ($self->{"debug"} > 0) {
        printf(STDERR "%s: queue_num=%d\n", $self, $self->{"_com_queue"}->pending());
    }
    $self->{"_res"} = system($com);
    return;
}

sub system {
    my $self = shift;
    my ($com) = @_;
    $self->system_nb($com);
    while ($self->is_running()) {
        &Time::HiRes::sleep($self->{"timer"});
    }
    return $self->{"_res"};
}

sub is_running {
    my $self = shift;
    return 0;
}

sub get_result {
    my $self = shift;
    return $self->{"_res"};
}

########################################
# load threaded version if possible
########################################
if($Config{"usethreads"}) {
    require CommandWorker_threaded;
}

1;

#################### END OF FILE ####################
