# -*- mode: perl; coding: utf-8 -*-

use strict;

package AppConf;

use utf8;
use Encode;
use FindBin qw($Bin);
use Config;

use AppConf;

my $DEFAULT_VALUES =
{
    "debug" => 0,
    "encoding" => "utf-8",
    "conf-file" => "$Bin/../app.conf",
    "conf-org-file" => "$Bin/../app_org.conf",
    "conf-map" => undef,
    "adjust-winpath" => 1,
};

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {%$DEFAULT_VALUES, @_};
    bless $self, $class;
    if (-f $self->{"conf-org-file"}) {
        $self->load($self->{"conf-org-file"});
    }
    if (-f $self->{"conf-file"}) {
        $self->load($self->{"conf-file"});
    }
    return $self;
}

sub get_filename {
    $_[0]->{"conf-file"};
}

sub load {
    my $self = shift;
    my ($conf_file) = @_;
    unless($conf_file) {
        $conf_file = $self->{"conf-file"};
    }
    unless ($self->{"conf-map"}) {
        $self->{"conf-map"} = {};
    }
    my $conf_map = $self->{"conf-map"};
    open(my $fh, $conf_file) or die "Cannot open conf '$conf_file'";
    my $buff = join("", (<$fh>));
    close($fh);
    $buff = Encode::decode($self->{"encoding"}, $buff);
    my $added_map = eval "$buff";
    if (!ref($added_map)) {
        $added_map = {};
    }
    $conf_map = {%$conf_map, %$added_map};
    if ($self->{"adjust-winpath"} > 0) {
        $self->adjust_winpath_map($conf_map);
    }
    $self->{"conf-map"} = $conf_map;
    return $conf_map;
}

sub save {
    my $self = shift;
    my ($conf_file) = @_;
    unless($conf_file) {
        $conf_file = $self->{"conf-file"};
    }
    open(my $fh, ">", $conf_file) or die "Cannot open conf '$conf_file'";
    $self->show($fh);
    close($fh);
    if ($self->{"debug"} > 0) {
        printf(STDERR "# Saved conf: %s\n", $conf_file);
    }
}

sub show {
    my $self = shift;
    my ($fh, $encoding) = @_;
    $fh = \*STDOUT unless $fh;
    $encoding = $self->{"encoding"} unless $encoding;
    my $conf_map = $self->{"conf-map"};
    printf($fh "# -*- mode: perl; coding: %s; -*-\n", $encoding);
    printf($fh "\{\n");
    foreach my $key (sort {$a cmp $b} keys %$conf_map) {
        my $value = $conf_map->{$key};
        $key = Encode::encode($encoding, $key);
        $value = Encode::encode($self->{"encoding"}, $value);
        printf($fh "    \"%s\" => \"%s\",\n", $key, $value);
    }
    printf($fh "\};\n");
    printf($fh "#################### END OF FILE ####################\n");
}

sub exists_item {
    return exists($_[0]->{"conf-map"}{$_[1]});
}

sub get_ref {
    \$_[0]->{"conf-map"}{$_[1]};
}

sub get {
    $_[0]->{"conf-map"}{$_[1]};
}

sub set {
    $_[0]->{"conf-map"}{$_[1]} = $_[2];
}

sub clone {
    my $self = shift;
    my $app_conf_clone = {%$self};
    $app_conf_clone->{"conf-map"} = {%{$self->{"conf-map"}}};
    bless $app_conf_clone, ref($self);
    return $app_conf_clone;
}

sub equal {
    my $self = shift;
    my ($that) = @_;
    my $self_map = $self->{"conf-map"};
    my $that_map = $that->{"conf-map"};
    my $flag = 1;
    foreach my $name (keys %$that_map) {
        if (!exists($self_map->{$name}) or
                $self_map->{$name} ne $that_map->{$name}) {
            $flag = 0;
            last;
        }
    }
    return $flag;
}

sub adjust_winpath_map {
    my $self = shift;
    my ($conf_map) = @_;
    if ($Config{"osname"} =~ /MSWin32|cygwin|msys/i) {
        while (my ($key, $value) = each %$conf_map) {
            $value = $self->adjust_winpath($value);
            $conf_map->{$key} = $value;
        }
    }
}

# adjust MS-Windows path
sub adjust_winpath {
    my $self = shift;
    my ($path) = @_;
    if ($path !~ /^\//) {
        return $path;
    }
    my $path_tmp = $path;
    open(STDERR2, ">&STDERR");
    close(STDERR);
    eval {
        if ($path_tmp =~ /^\/([a-zA-Z])\//) {
            # change drive letter "/c/" to "c:/"for msys
            $path_tmp =~ s/^\/([a-zA-Z])\//$1:\//;
        }
        # change drive letter "/" to "c:/cygwin/" for cygwin
        $path_tmp = qx(cygpath -am "$path_tmp");
        if (!$?) {
            # success of cygpath
            $path_tmp =~ s/\n.*//;
            $path = $path_tmp;
        } else {
            # failure of cygpath
            if ($path =~ /^\/([a-zA-Z])\//) {
                # change drive letter "/c/" to "c:/" for msys
                $path =~ s/^\/([a-zA-Z])\//$1:\//;
            } else {
                # in configuration by cygwin
                if ($path =~ /^\/cygdrive\/([a-zA-Z])\//) {
                    # change drive letter "/cygdrive/c/" to "c:/" for msys
                    $path =~ s/^\/cygdrive\/([a-zA-Z])\//$1:\//;
                } else {
                    # add drive letter "/c" for msys
                    $path = "c:/cygwin".$path;
                }
            }
        }
    };
    open(STDERR, ">&STDERR2");
    return $path;
}

1;

#################### END OF FILE ####################
