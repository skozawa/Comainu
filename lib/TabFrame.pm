# -*- mode: perl; coding: utf-8 -*-

use strict;

package TabFrame;
use vars qw($VERSION $DoDebug);
$VERSION = '1.000';
$DoDebug = 0;

use Tk qw (Ev);
# use AutoLoader;

use Tk::Frame ();
use base qw(Tk::Frame);

Construct Tk::Widget 'TabFrame';

my $DEFAULT_VALUES =
{
    -relief => "raised",
    -border => 2,
};

sub ClassInit {
    my ($class,$mw) = @_;

    return $class->SUPER::ClassInit($mw);
}

sub InitObject {
    my ($self, $args) = @_;
    %$args = (%$DEFAULT_VALUES, %$args);
    $self->{"_curr_index"} = -1;
    $self->{"_tab_list"} = [];
    my $bf = $self->Frame();
    $bf->pack(-side=>"top", -fill=>"x");
    $self->{"_button_frame"} = $bf;
    my $db = $bf->Button(
        -text=>"",
        -relief=>"sunken",
        -takefocus=>0,
    );
    $db->configure(-activebackground=>$db->cget(-bg));
    $db->pack(-side=>"left", -fill=>"x");
    $self->{"_dummy_button"} = $db;
    my $tf = $self->Frame(-bd=>2, -relief=>"flat");
    $tf->pack(-side=>"top", -fill=>"both", -expand=>"yes");
    $self->{"_tab_frame"} = $tf;
    return $self;
}

############################################################

sub bind_keys_toplevel {
    my $self = shift;
    my $top = $self->toplevel();
    $top->bind("<Control-Tab>", sub {
                   $self->next_tab(1);
                   return Tk::break();
               });
    $top->bind("<Shift-Control-Tab>", sub {
                   $self->next_tab(-1);
                   return Tk::break();
               });
}

sub get_index {
    my $self = shift;
    return $self->{"_curr_index"};
}

sub set_index {
    my $self = shift;
    my ($index) = @_;
    $self->{"_curr_index"} = $index;
}

sub get_length {
    my $self = shift;
    return scalar(@{$self->{"_tab_list"}});
}

sub add {
    my $self = shift;
    my $args = {@_};
    my $name = "";
    if (exists($args->{"-name"})) {
        $name = $args->{"-name"};
        delete $args->{"-name"};
    }
    my $db = $self->{"_dummy_button"};
    $db->packForget();
    my $index = scalar(@{$self->{"_tab_list"}});
    my $new_frame = $self->{"_tab_frame"}->Frame(%$args);
    my $new_button = $self->{"_button_frame"}->Button(
        -text=>$name,
        -command=>sub {
            $self->select_tab($index);
            return Tk::break();
        }
    );
    $new_button->pack(-side=>"left");
    push(@{$self->{"_tab_list"}}, [$name, $new_button, $new_frame]);
    $db->pack(-side=>"left", -fill=>"x", -expand=>"yes");
    $self->select_tab($index);
    return $new_frame;
}

sub get_tab {
    my $self = shift;
    my ($index) = @_;
    my $len = $self->get_length();
    if ($len == 0 or $index >= $len) {
        return;
    }
    return $self->{"_tab_list"}[$index];
}

sub select_tab {
    my $self = shift;
    my ($index) = @_;
    my $len = $self->get_length();
    for (my $i = 0; $i < $len; ++$i) {
        my ($name, $bt, $fr) = @{$self->{"_tab_list"}[$i]};
        if ($i == $index) {
            $bt->configure(-relief=>"flat");
            $bt->focus();
            $fr->pack(-fill=>"both");
        } else {
            $bt->configure(-relief=>"sunken");
            $fr->packForget();
        }
    }
    $self->set_index($index);
    return;
}

sub next_tab {
    my $self = shift;
    my ($delta) = @_;
    my $len = $self->get_length();
    if ($len == 0) {
        return;
    }
    my $index = $self->get_index() + $delta;
    while ($index < 0) {
        $index += $len;
    }
    while ($index >= $len) {
        $index -= $len;
    }
    $self->select_tab($index);
    return;
}

sub demo {
    my $mw = MainWindow->new();
    $mw->title("TabFrame demo");
    $mw->geometry("600x400");
    my $tab_frame = $mw->TabFrame();
    $tab_frame->pack(-side=>"top", -fill=>"both", -expand=>"yes");
    my $f;
    $f = $tab_frame->add(-name=>"Entry");
    $f->Entry()->pack();
    $f = $tab_frame->add(-name=>"Text");
    $f->Text()->pack();
    $f = $tab_frame->add(-name=>"Canvas");
    $f->Canvas()->pack();
    $f = $tab_frame->add(-name=>"TabFrame");
    my $t = $f->TabFrame();
    $t->pack();
    $t->add(-name=>"A")->Label(-text=>"A")->pack();
    $t->add(-name=>"B")->Label(-text=>"B")->pack();
    $t->add(-name=>"C")->Label(-text=>"C")->pack();

    $tab_frame->bind_keys_toplevel();
    $tab_frame->select_tab(0);
    Tk::MainLoop();
}

1;

#################### END OF FILE ####################
