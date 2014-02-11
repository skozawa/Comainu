# -*- mode: perl; coding: utf-8 -*-

use strict;

package CommandWorker;

use utf8;
use Time::HiRes;
use threads;
use Thread::Queue;

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
    $self->{"_com_queue"} = Thread::Queue->new();
    $self->{"_th"} = threads->create(
        sub { $self->_execute_system(); }
    );
    $self->{"_th"}->detach();
    $self->{"_res"} = undef;
    return $self;
}

sub DESTROY {
    my $self = shift;
    eval {
        # $self->{"_com_queue"}->enqueue(undef);
        # $self->{"_th"} = undef;
        # $self->{"_com_queue"} = undef;
    };
}

sub _execute_system {
    my $self = shift;
    while (my $com = $self->{"_com_queue"}->dequeue()) {
        if ($self->{"debug"} > 0) {
            printf(STDERR "%s: com=%s\n", $self, $com);
        }
        if ($com ne "") {
            $self->{"_res"} = system($com);
        }
        $self->{"_com_queue"}->dequeue();
    }
}

sub system_nb {
    my ($self, $com) = @_;
    $self->{"_com_queue"}->enqueue($com);
    $self->{"_com_queue"}->enqueue("");
    if ($self->{"debug"} > 0) {
        printf(STDERR "%s: queue_num=%d\n", $self, $self->{"_com_queue"}->pending());
    }
    return;
}

sub system {
    my $self = shift;
    my ($com) = @_;
    $self->system_nb($com);
    print "timer=".$self->{"timer"}."\n";
    while ($self->is_running()) {
        &Time::HiRes::sleep($self->{"timer"});
    }
    return $self->{"_res"};
}

sub is_running {
    my $self = shift;
    return $self->{"_com_queue"}->pending() > 0 ? 1 : 0;
}

1;

#################### END OF FILE ####################
