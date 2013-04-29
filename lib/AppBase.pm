# -*- mode: perl; coding: utf-8 -*-
package AppBase;
use strict;
use warnings;
use utf8;
use base qw(Tkx::widget);

use Tkx;
use Tkx::Scrolled;
use FindBin qw($Bin);
use File::Spec;
use Encode;
use Config;

use AppConf;
use Text_patch;

my $DEFAULT_VALUES = {
    "debug" => 0,
    "app-name" => "",
    "app-version" => "",
    "title" => "untitled",
    "copyright" => "",
    "icon-file" => "$Bin/../img/icon.ico",
    "gif-file" => "$Bin/../img/icon.gif",
    "conf-file" => "$Bin/../conf.conf",
    "conf-org-file" => "$Bin/../conf_org.conf",
    "conf-geometry" => "600x400",
    "msg-file" => "$Bin/../msg/en.txt",
    "help-file" => "$Bin/../Readme.txt",
};

sub initialize {
    my ($self, $args) = @_;

    unless ( $self->_parent ) {
        $self->g_wm_withdraw;
    }
    my $opts = {%$DEFAULT_VALUES, %{$args // {}}};
    my $app_conf = AppConf->new(
        debug           => $opts->{debug},
        "conf-file"     => $opts->{"conf-file"},
        "conf-org-file" => $opts->{"conf-org-file"},
    );
    $self->_data->{"app-conf"} = $app_conf;
    $self->_data->{"app-conf-init"} = $app_conf->clone;
    # XXX
    # $self->g_pack( -fill => "both", -expand => 1 );

    while ( my ($key, $val) = each %$opts ) {
        $self->_data->{$key} = $val;
    }

    $self->_data->{"msg-file"} = $app_conf->get("msg-file") if $app_conf->get("msg-file");

    # message catelogue
    if ( $self->_data->{"msg-file"} ) {
        my $MSG = {};
        my $msg_file = $self->_data->{"msg-file"};
        eval {
            open(my $fh, $msg_file) or die "Cannot open '$msg_file'";
            my $msg_str = join("", (<$fh>));
            close($fh);
            $msg_str = Encode::decode("utf-8", $msg_str);
            eval "$msg_str";
            $self->_data->{msg} = $MSG;
        };
        if ($@) {
            print STDERR "Error: loading '$msg_file'\n";
            die $@;
        }
    }

    # title
    my $title = $self->_data->{title} // '';
    $title =~ s/\[APP_NAME\]/$opts->{"app-name"}/g;
    $title =~ s/\[APP_VERSION\]/$opts->{"app-version"}/g;
    $self->g_wm_title($title) unless $self->_parent;

    # icon
    if ( $self->_data->{"gif-file"} && -f $self->_data->{"gif-file"}) {
        # $self->_data->{img} = $self->Photo( -format => "gif", -file => $self->_data->{"gif-file"});
        $self->_data->{img} = Tkx::image(
            "create", "photo",
            -format => "gif",
            -file => $self->_data->{"gif-file"}
        );
        $self->g_wm_iconphoto($self->_data->{img}) unless $self->_parent;
    }

    # status bar
    my $status_frame = $self->new_frame(
        -bd => 2, -height => 10, -relief => "groove",
    );
    $status_frame->g_pack( -side => "bottom", -fill => "x" );
    $status_frame->_data->{lbl} = $status_frame->new_label(-text => "status:");
    $status_frame->_data->{st}  = $status_frame->new_entry(-bg => "#cfcfcf", -relief => "sunken");
    $status_frame->_data->{lbl}->g_pack(-side => "left");
    $status_frame->_data->{st}->g_pack(
        -side => "left", -fill => "x", -expand => "yes",
    );
    $self->_data->{status} = $status_frame->_data->{st};
    $self->_data->{status}->configure(-state => "readonly");

    # menubar
    my $ws = Tkx::tk_windowingsystem();
    if ($ws eq "win32") {
        # patch for Windows
        $self->g_bind('<Alt-KeyPress>', ['TraverseToMenu', Tkx::Ev('K')]);
        $self->g_bind('<F10>', 'FirstMenu');
    }
    my $menubar_frame = $self->new_frame(
        -bd => 2, -height => 10, -relief => "groove"
    );
    $menubar_frame->_data->{oc} = $menubar_frame->new_frame(
        -width => 10, -height => 8, -bg => "#aacccc"
    );
    $menubar_frame->_data->{oc}->g_bind(
        "<Button-1>", sub { $self->toggle_menubar; }
    );
    $menubar_frame->_data->{bts} = $menubar_frame->new_frame(-relief => "groove");
    $menubar_frame->g_pack(-side => "top", -fill => "x");
    $menubar_frame->_data->{oc}->g_pack(-side => "left", -fill => "y");
    $self->_data->{menubar} = $menubar_frame;
    $self->_data->{menubar}->_data->{flag} = 0;
    $self->toggle_menubar;

    # toolbar
    my $toolbar_frame = $self->new_frame(
        -bd => 2, -height => 10, -relief => "groove"
    );
    $toolbar_frame->_data->{oc} = $toolbar_frame->new_frame(
        -width => 40, -height => 8, -bg => "#ccaacc"
    );
    $toolbar_frame->_data->{oc}->g_bind(
        "<Button-1>", sub { $self->toggle_toolbar; }
    );
    $toolbar_frame->_data->{bts} = $toolbar_frame->new_frame(-relief => "groove");
    $toolbar_frame->g_pack(-side => "top", -fill => "x");
    $toolbar_frame->_data->{oc}->g_pack(-side => "left", -fill => "y");
    $self->_data->{toolbar} = $toolbar_frame;
    $self->_data->{toolbar}->_data->{flag} = 0;
    $self->toggle_toolbar;

    # mainframe
    my $mainframe = $self->new_frame(
        -bd => 2, -height => 10, -relief => "groove"
    );
    $mainframe->g_pack(
        -side => "top", -fill => "both", -expand => "yes"
    );
    $self->_data->{mainframe} = $mainframe;

    # Protocol
    $self->g_wm_protocol(
        "WM_DELETE_WINDOW", sub { $self->cmd_close; }
    ) unless $self->_parent;

    unless ( $self->_parent ) {
        # $self->update;
        $self->g_wm_deiconify;
    }

    return $self;
}

sub toggle_menubar {
    my ($self, $event) = @_;

    my $manubar = $self->_data->{menubar};
    if ($manubar->_data->{flag} == 1) {
        $manubar->_parent->configure(-height => 10);
        $manubar->_data->{oc}->configure(-width => 40, -height => 8);
        $manubar->_data->{bts}->g_packForget;
        $manubar->_data->{flag} = 0;
    } else {
        $manubar->_data->{oc}->configure(-width => 8, -height => 40);
        # XXX
        $manubar->_data->{bts}->g_pack(
            -side => "left", -padx => 5, -pady => 5, -fill => "x", -expand => "yes"
        );
        $manubar->_data->{flag} = 1;
    }
}

sub toggle_toolbar {
    my ($self, $event) = @_;

    my $toolbar = $self->_data->{toolbar};
    if ($toolbar->_data->{flag} == 1) {
        $toolbar->_parent->configure(-height=>10);
        $toolbar->_data->{oc}->configure(-width => 40, -height => 8);
        $toolbar->_data->{bts}->g_packForget;
        $toolbar->_data->{flag} = 0;
    } else {
        $toolbar->_data->{oc}->configure(-width => 8, -height => 40);
        # XXX
        $toolbar->_data->{bts}->g_pack(
            -side => "left", -padx => 5, -pady => 5, -fill => "x", -expand => "yes");
        $toolbar->_data->{flag} = 1;
    }
}


sub fullpath {
    my ($self, $pathname) = @_;
    $pathname = File::Spec->rel2abs($pathname);
    $pathname =~ s/\\/\//gs;
    $pathname =~ s/[^\/]+\.\.\///gs;
    return $pathname;
}

sub decode_pathname {
    my ($self, $pathname) = @_;
    my $enc = $self->get_pathname_encoding;
    $pathname = Encode::decode($enc, $pathname);
    return $pathname;
}

sub encode_pathname {
    my ($self, $pathname) = @_;
    my $enc = $self->get_pathname_encoding;
    $pathname = Encode::encode($enc, $pathname);
    return $pathname;
}

sub get_pathname_encoding {
    my $self = shift;
    my $enc = $self->_data->{"app-conf"}->get("pathname-encoding");
    if ($enc =~ /^\s*$/ or $enc =~ /auto/) {
        if ($Config{"archname"} =~ /MSWin32/) {
            $enc = "cp932";      # for Japanese windows
            $enc = "shift_jis";  # for Japanese windows
        } else {
            $enc = "utf-8";
        }
    }
    return $enc;
}


sub cmd_close {
    my $self = shift;
    unless ( $self->_parent ) {
        $self->cmd_exit;
    } else {
        $self->g_destroy;
    }
}

sub cmd_exit {
    my $self = shift;
    my $cancel = 0;
    eval {
        my $app_conf = $self->_data->{"app-conf"};
        my $app_conf_init = $self->_data->{"app-conf-init"};
        if (!$app_conf->equal($app_conf_init)) {
            my $app_conf_file = $self->fullpath($app_conf->get_filename);
            my $message = sprintf($self->_data->{msg}{MSG_STR_CONFIRM_TO_SAVE_APP_CONF}, $app_conf_file);
            my $res = Tkx::tk___messageBox(
                -message => $message,
                -icon    => "question",
                -type    => "yesnocancel",
                -default => "yes"
            );
            if ($res =~ /yes/i) {
                $app_conf->save;
            } elsif ($res =~ /cancel/i) {
                $cancel = 1;
            }
        }
    };
    if ($cancel == 0) {
        $self->g_destroy;
    }
    return $cancel;
}

sub cmd_new {
    my $self = shift;
    my $top = $self->new_toplevel;
    my $new_app = ref($self)->new($top);
    $new_app->initialize($self->_data);
    $new_app->g_raise;
    # return Tkx::Tk__break();
}

sub cmd_show_help {
    my $self = shift;

    # if ($self->_data->{_help_window} && Tkx::tk__Exists($self->{"_help_window"})) {
    if ($self->_data->{_help_window}) {
        # $self->_data->{_help_window}->{text}->focus();
        $self->_data->{_help_window}->g_wm_deiconify;
        return;
    }

    my $data = "";
    if (my $file = $self->_data->{"help-file"}) {
        open(my $fh, $file) or die "Cannot open '$file'.";
        $data = join("", (<$fh>));
        close($fh);
        $data = Encode::decode("utf-8", $data);
        $data =~ s/\r\n/\n/sg;
    }

    my $top = $self->new_toplevel;
    $top->g_wm_title($self->_data->{msg}{STR_HELP});
    $top->g_wm_withdraw;
    # $top->update();
    $self->g_wm_iconphoto($self->_data->{img}) if exists $self->_data->{img};

    my $text_frame = $top->new_frame;
    $text_frame->g_pack(
        -side => "top", -fill => "both", -expand => "yes"
    );
    my $text = $text_frame->new_tkx_Scrolled(
        "text", -scrollbars => "se", -bg => "#ffffff"
    );
    $text->g_pack(-side => "top", -fill => "both", -expand => "yes");
    $top->_data->{text} = $text;

    my $bt_frame = $top->new_frame;
    $bt_frame->g_pack(-side => "bottom");
    my $bt = $bt_frame->new_button(
        -text    => $self->_data->{msg}{BT_STR_CLOSE},
        -command => sub { $top->g_wm_withdraw; }
    );
    $bt->g_pack(-side => "left");
    $top->_data->{bt} = $bt;

    $text->insert("1.0", $data);
    # $text->SetCursor("1.0");
    $text->configure(-state=>"disabled");
    $text->g_bind("<Control-Key-f>", sub { $text->FindPopUp; });
    $text->g_bind("<Button>", sub { $text->g_focus; });
    $top->g_bind("<Control-Key-w>", sub { $top->_data->{bt}->invoke; });
    $top->g_bind("<Key-Escape>", sub { $top->_data->{bt}->invoke; });
    # $top->update();
    $top->g_wm_deiconify;
    $self->_data->{_help_window} = $top;
    # $self->_data->{_help_window}->_data->{text}->focus();
}

sub cmd_show_about {
    my $self = shift;

    # if ($self->_data->{_about_window} && Tkx::tk__Exists($self->_data->{_about_window})) {
    # if ($self->_data->{_about_window}) {
    #     # $self->_data->{_about_window}->_data->{"bt"}->g_wm_focus;
    #     $self->_data->{_about_window}->g_wm_deiconify;
    #     return;
    # }

    my ($sx, $sy, $ox, $oy) =
        ($self->g_wm_geometry() =~ /(\d+)x(\d+)\+(\d+)\+(\d+)/);
    my $cx = int($sx / 2.0 + $ox - 100);
    my $cy = int($sy / 2.0 + $oy - 100);
    my $title = $self->_data->{msg}{STR_ABOUT};
    my $top = $self->new_toplevel;
    $top->g_wm_title($title);
    $top->g_wm_withdraw;
    # $top->update();
    $top->g_wm_geometry(sprintf("+%s+%s", $cx, $cy));

    my $frame = $top->new_frame;
    $frame->g_pack(
        -side => "top", -ipadx => 10, -ipady => 10, -padx => 10, -pady => 10
    );
    if (exists $self->_data->{img}) {
        $top->g_wm_iconphoto($self->_data->{img});
        my $lbl = $frame->new_label(-image => $self->_data->{img});
        $lbl->g_pack(-side => "top");
    }

    my $str_about = $self->_data->{msg}{FMT_ABOUT};
    foreach my $name ("app-name", "app-version", "copyright") {
        my ($key, $value);
        if (exists $self->_data->{$name}) {
            $key = quotemeta("[".$name."]");
            $value = $self->_data->{$name};
        }
        $str_about =~ s/$key/$value/gs if $key ne "";
    }
    foreach my $config_name (keys %Config) {
        my ($key, $value);
        my $name = "perl-".$config_name;
        if (exists $Config{$config_name}) {
            $key = quotemeta("[".$name."]");
            $value = $Config{$config_name};
        }
        $str_about =~ s/$key/$value/gs if $key ne "";
    }

    my $lbl = $frame->new_label(-text => $str_about);
    $lbl->g_pack(-side => "top");
    my $bt = $frame->new_button(
        -text    => $self->_data->{msg}{BT_STR_OK},
        -command => sub { $top->g_destroy }
    );
    $bt->g_pack(-side => "bottom");

    $top->_data->{bt} = $bt;
    # $top->_data->{bt}->focus;
    $self->_data->{_about_window} = $top;
    $top->g_bind("<Key-Escape>", sub { $top->_data->{bt}->invoke; });
    $top->g_wm_resizable(0, 0);
    # $top->update();
    $top->g_wm_deiconify;
    $top->g_grab;
}

sub cmd_configuration {
    my $self = shift;
    my $configuration_window = $self->popup_configuration_dialogue;
    # return Tk::break();
}

sub popup_configuration_dialogue {
    my ($self, $configuration_view) = @_;
    $configuration_view ||= $self->_data->{"configuration-view"};

    my $app_conf = $self->_data->{"app-conf"};
    my $app_conf_clone = $app_conf->clone();

    my $top = $self->new_toplevel;
    $top->g_wm_title($self->_data->{msg}{STR_CONFIGURATION});
    $top->g_wm_withdraw;
    # $top->update();
    $top->g_wm_iconphoto($self->_data->{img}) if $self->_data->{img};
    $top->g_wm_geometry($self->_data->{"conf_geometry"});

    my $tab_f = $top->new_ttk__notebook;
    $tab_f->g_pack(-side => "top", -fill => "both", -expand => "yes");
    my $bt_f = $top->new_frame;
    $bt_f->g_pack(-side => "top");

    my $tab_item = {};
    foreach my $tab_view (@$configuration_view) {
        my $tab_name = $tab_view->{name};
        my $lbl_str = $self->_data->{msg}{$tab_name} || $tab_name;
        my $ft = $tab_f->new_frame;
        $tab_f->add($ft, -text => $lbl_str);

        my $row = 0;
        foreach my $configuration_item (@{$tab_view->{options}}) {
            my ($conf_name, $conf_type, $conf_opts) = @$configuration_item;
            my $conf_value_ref = $app_conf_clone->get_ref($conf_name);
            my $lbl_str = $self->_data->{msg}{$conf_name} || $conf_name;
            my $l = $ft->new_label(-text => $lbl_str);
            $l->g_grid(-row => $row, -column => 0, -sticky => "w");
            my $f = $ft->new_frame;
            $f->g_grid(-row => $row, -column => 1, -sticky => "ew");

            my $e = do {
                if ($conf_type =~ /pathname/i || $conf_type =~ /dirname/i ||
                        $conf_type =~ /filename/i) {
                    my $filetypes = $conf_opts->{filetypes};
                    my $dirnamevariable = do {
                        if ($conf_type =~ /filename/) {
                            my $tmp_conf_name = $conf_opts->{"dirnamevariable"};
                            if ($app_conf_clone->exists_item($tmp_conf_name)) {
                                $app_conf_clone->get_ref($tmp_conf_name);
                            }
                        }
                    };
                    $self->make_pathname_entry(
                        $f,
                        -pathnametype    => $conf_type,
                        -textvariable    => $conf_value_ref,
                        -dirnamevariable => $dirnamevariable,
                        -filetypes       => $filetypes,
                    );
                } elsif ($conf_opts) {
                    $self->make_list_entry(
                        $f,
                        -textvariable => $conf_value_ref,
                        %$conf_opts
                    );
                } else {
                    my $e = $ft->new_entry(-textvariable => $conf_value_ref, -width => 80);
                    $e->g_grid(-row => $row, -column => 1, -sticky => "ew");
                    $e;
                }
            };
            ++$row;
        }
    }

    # button frame
    my $b_ok = $bt_f->new_button(
        -text    => $self->_data->{msg}{BT_STR_OK},
        -command => sub {
            foreach my $name (keys %{$app_conf_clone->{"conf-map"}}) {
                $app_conf->{"conf-map"}{$name} = $app_conf_clone->{"conf-map"}{$name};
            }
            $top->_parent->g_focus;
            $top->g_destroy;
        }
    );
    $b_ok->g_pack(-side => "left");
    $top->_data->{ok} = $b_ok;
    my $b_cancel = $bt_f->new_button(
        -text    => $self->_data->{msg}{BT_STR_CANCEL},
        -command => sub {
            $top->_parent->g_focus;
            $top->g_destroy;
        }
    );
    $b_cancel->g_pack(-side => "left");
    $top->_data->{cancel} = $b_cancel;

    $top->g_bind("<Key-Escape>", sub { $top->_data->{cancel}->invoke; });

    $top->g_wm_resizable(1, 1);
    # $top->update();
    $top->g_wm_deiconify;
    # $top->update();
    # $top->_data->{ok}->focus();
    $top->g_grab;
}


sub make_pathname_entry {
    my ($self, $f, %args) = @_;
    my $local_opts = {
        -foreground => "#000000",
        -background => "#ffffff",
    };
    my $added_opts = {
        -pathnametype      =>  "pathname",
        -filetypes         =>  [],
        -invalidforeground => "#000000",
        -invalidbackground => "#ffff77",
        -dirnamevariable   => undef,
        -filetypes         => undef,
        -textvariable      => undef,  # for initialization
    };
    my $opts = {%$added_opts, %$local_opts, %args};
    my $pathnametype    = $opts->{"-pathnametype"};
    my $textvariable    = $opts->{"-textvariable"};
    my $dirnamevariable = $opts->{"-dirnamevariable"};
    my $filetypes       = $opts->{"-filetypes"};
    my $entry_opts      = {%$opts};
    delete $entry_opts->{$_} for keys %$added_opts;

    my $func_get_reference = sub {
        my ($self, $e, $pathnametype) = @_;
        my $pathname = $e->get;
        my $new_pathname = undef;
        if ($pathnametype =~ /dirname/) {
            my $dirname_enc = $self->encode_pathname(
                $pathname eq "" ? $self->_data->{"default-dirname"} : $pathname
            );
            $dirname_enc = Tkx::tk___chooseDirectory(-initialdir => $dirname_enc);
            my $dirname = $self->decode_pathname($dirname_enc);
            if (defined $dirname) {
                $self->_data->{"default-dirname"} = $dirname;
                $new_pathname = $dirname;
            }
        } elsif ($pathnametype =~ /filename/) {
            my $dirname = $self->_data->{"defautl-dirname"};
            $dirname = $$dirnamevariable if defined $dirnamevariable;
            my $filename = $pathname;
            $pathname = $e->getOpenFile(
                -filetypes   => $filetypes,
                -initialdir  => $dirname,
                -initialfile => $filename,
            );
            if ($pathname) {
                $dirname  = File::Basename::dirname($pathname);
                $filename = File::Basename::basename($pathname);
                $$dirnamevariable = $dirname if defined $dirnamevariable;
                $self->_data->{"default-dirname"} = $dirname;
                $new_pathname = $filename;
            }
        } elsif ($pathnametype =~ /pathname/) {
            my $dirname  = $pathname;
            my $filename = "";
            if ($pathname ne "" and $pathname !~ /\/$/) {
                $dirname  = File::Basename::dirname($pathname);
                $filename = File::Basename::basename($pathname);
            }
            $new_pathname = $e->getOpenFile(
                -filetypes   => $filetypes,
                -initialdir  => $dirname,
                -initialfile => $filename,
            );
        }
        if (defined $new_pathname) {
            $e->delete("0", "end");
            $e->insert("end", $new_pathname);
            $e->icursor("end");
        }
    };

    my $e = $f->new_ttk__combobox(
        -textvariable => $textvariable,
        -width => 60, # TODO
        %$entry_opts,
    );
    $e->g_bind("<Key-Return>", sub { $func_get_reference->($self, $e, $pathnametype); });
    $e->g_pack(-side => "left", -fill => "x", -expand => "yes");
    my $b = $f->new_button(
        -text    => $self->_data->{msg}{BT_STR_REFERENCE},
        -command => sub { $func_get_reference->($self, $e, $pathnametype); }
    );
    $b->g_pack(-side => "left");

    return $e;
}

sub make_list_entry {
    my ($self, $f, %args) = @_;
    my $local_opts = {
        -foreground => "#000000",
        -background => "#ffffff",
    };
    my $added_opts = {
        -invalidforeground => "#000000",
        -invalidbackground => "#ffff77",
        -textvariable      => undef,     # for initialization
        -list              => undef,     # for initialization
    };
    my $opts = {%$added_opts, %$local_opts, %args};
    my $item_list    = $opts->{"-list"};
    my $textvariable = $opts->{"-textvariable"};
    my $entry_opts   = {%$opts};
    delete $entry_opts->{$_} for keys %$added_opts;

    my $init_list_flag = 0;
    my $e;
    $e = $f->new_ttk__combobox(
        -textvariable => $textvariable,
        -values       => $item_list,
        %$entry_opts,
    );
    $e->g_pack(-side => "left", -fill => "x", -expand => "yes");
    return $e;
}


1;
__END__
