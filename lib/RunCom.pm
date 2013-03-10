# -*- mode: perl; coding: utf-8 -*-

package RunCom;
use strict;
use Encode;

my $DEFAULT_VALUES =
{
    "debug" => 0,
};

sub new {
    my $proto = shift;
    my $class = $proto or ref($proto);
    my $self = {%$DEFAULT_VALUES, @_};
    bless $self, $class;
    return $self;
}

sub exec_com {
    my $self = shift;
    if (scalar(@_) > 0) {
        my $perl_script = shift(@_);
        if (! -f $perl_script) {
            die "Cannot open '$perl_script'";
        }
        open(my $fh, $perl_script) or die "Cannot open '$perl_script'";
        my $script_str = join("", (<$fh>));
        close($fh);
        $script_str = Encode::decode("utf-8", $script_str);
        {
            package main;
            local $0 = $perl_script;
            local @ARGV = @_;
            eval($script_str);
            # do $0;
            if ($@) {
                die $@;
            }
        }
    }
}

1;

#################### END OF FILE ####################
