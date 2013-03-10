# -*- mode: perl; coding: utf-8 -*-

use strict;

package AppBase;
use vars qw($VERSION $DoDebug);
$VERSION = '1.000';
$DoDebug = 0;

use Config;
use Tk qw (Ev);
# use AutoLoader;

use Tk::Frame ();
use base qw(Tk::Frame);

Construct Tk::Widget 'AppBase';

use utf8;
use FindBin qw($Bin);
use File::Spec;
use File::Basename;
use Config;
use Tk;
use Tk::BrowseEntry;
use Tk::DropSite;

use AppConf;
use TabFrame;
use Text_patch;

my $DEFAULT_VALUES =
{
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

sub ClassInit
{
    my ($class,$mw) = @_;

    return $class->SUPER::ClassInit($mw);
}

sub InitObject
{
    my ($self, $args) = @_;
    my $parent = $self->parent();
    my $toplevel = $self->toplevel();
    if ($parent == $toplevel) {
        $toplevel->withdraw();
    }
    $self->update();
    my $args_opts = {};
    if (exists($args->{"opts"})) {
        $args_opts = $args->{"opts"};
        delete $args->{"opts"};
    }
    if (!exists($self->{"opts"})) {
        $self->{"opts"} = {};
    }
    my $opts = {%$DEFAULT_VALUES, %{$self->{"opts"}}, %$args_opts};
    $self->{"args"} = $args;
    $self->{"opts"} = $opts;
    my $app_conf = AppConf->new(
        "debug" => $opts->{"debug"},
        "conf-file" => $opts->{"conf-file"},
        "conf-org-file" => $opts->{"conf-org-file"},
    );
    $self->{"app-conf"} = $app_conf;
    $self->{"app-conf-init"} = $app_conf->clone();
    $self->pack(-fill=>"both", -expand=>1);
    # $self->{"opts"} = $opts;
    while (my ($key, $value) = each(%$opts)) {
        $self->{$key} = $value;
    }

    if ($app_conf->get("msg-file")) {
        $self->{"msg-file"} = $app_conf->get("msg-file");
    }

    # message catalogue
    if (exists($self->{"msg-file"})) {
        my $MSG = {};
        my $msg_file = $self->{"msg-file"};
        eval {
            open(my $fh, $msg_file) or die "Cannot open '$msg_file'";
            my $msg_str = join("", (<$fh>));
            close($fh);
            $msg_str = Encode::decode("utf-8", $msg_str);
            eval "$msg_str";
            $self->{"msg"} = $MSG;
        };
        if ($@) {
            print STDERR "Error: loading '$msg_file'\n";
            die $@;
        }
    }

    # title
    eval {
        my $title = $self->{"title"};
        $title =~ s/\[APP_NAME\]/$opts->{"app-name"}/g;
        $title =~ s/\[APP_VERSION\]/$opts->{"app-version"}/g;
        if ($parent == $toplevel) {
            $self->toplevel()->title($title);
        }
    };

    # icon
    if (exists($self->{"gif-file"}) and -f $self->{"gif-file"}) {
        $self->{"img"} = $self->Photo(-format=>"gif", -file=>$self->{"gif-file"});
        if ($parent == $toplevel) {
            $toplevel->iconimage($self->{"img"});
        }
    }

    # status bar
    my $st_fr = $self->Frame(-bd=>2, -height=>10, -relief=>"groove");
    $st_fr->pack(-side=>"bottom", -fill=>"x");
    $st_fr->{"lbl"} = $st_fr->Label(-text=>"status:");
    $st_fr->{"st"} = $st_fr->Entry(-bg=>"#cfcfcf", -relief=>"sunken");
    $st_fr->{"lbl"}->pack(-side=>"left");
    $st_fr->{"st"}->pack(-side=>"left", -fill=>"x", -expand=>"yes");
    $self->{"status"} = $st_fr->{"st"};
    $self->{"status"}->configure(-state=>"readonly");

    # menubar
    my $ws = $self->windowingsystem();
    if ($ws eq "win32") {
        # patch for Windows
        $self->bind("all",'<Alt-KeyPress>',['TraverseToMenu', Tk::Ev('K')]);
        $self->bind("all",'<F10>','FirstMenu');
    }
    my $mb_fr = $self->Frame(-bd=>2, -height=>10, -relief=>"groove");
    $mb_fr->{"oc"} = $mb_fr->Frame(-width=>10, -height=>8, -bg=>"#aacccc");
    $mb_fr->{"oc"}->bind("<Button-1>", sub { $self->toggle_menubar(); });
    $mb_fr->{"bts"} = $mb_fr->Frame(-relief=>"groove");
    $mb_fr->pack(-side=>"top", -fill=>"x");
    $mb_fr->{"oc"}->pack(-side=>"left", -fill=>"y");
    $self->{"menubar"} = $mb_fr;
    $self->{"menubar"}{"flag"} = 0;
    $self->toggle_menubar(undef);

    # toolbar
    my $tb_fr = $self->Frame(-bd=>2, -height=>10, -relief=>"groove");
    $tb_fr->{"oc"} = $tb_fr->Frame(-width=>40, -height=>8, -bg=>"#ccaacc");
    $tb_fr->{"oc"}->bind("<Button-1>", sub { $self->toggle_toolbar(); });
    $tb_fr->{"bts"} = $tb_fr->Frame(-relief=>"groove");
    $tb_fr->pack(-side=>"top", -fill=>"x");
    $tb_fr->{"oc"}->pack(-side=>"left", -fill=>"y");
    $self->{"toolbar"} = $tb_fr;
    $self->{"toolbar"}{"flag"} = 0;
    $self->toggle_toolbar(undef);

    # mainframe
    my $mf_fr = $self->Frame(-bd=>2, -height=>10, -relief=>"groove");
    $mf_fr->pack(-side=>"top", -fill=>"both", -expand=>"yes");
    $self->{"mainframe"} = $mf_fr;

    # Protocol
    if ($parent == $toplevel) {
        $toplevel->protocol("WM_DELETE_WINDOW", sub { $self->cmd_close(); });
    }

    $self->init();

    if ($parent == $toplevel) {
        $toplevel->update();
        $toplevel->deiconify();
    }
    return $self;
}

sub get_top_pathname {
    my $self = shift;
    my $top_pathname = "$Bin/..";
    $top_pathname =~ s/[^\/]+\/\.\.//g;
    $top_pathname =~ s/\/$//;
    return $top_pathname;
}

sub init {
    my $self = shift;
    print "Not implemented\n";
}

sub toggle_menubar {
    my $self = shift;
    my ($event) = @_;
    my $mb = $self->{"menubar"};
    if ($mb->{"flag"} == 1) {
        $mb->parent()->configure(-height=>10);
        $mb->{"oc"}->configure(-width=>40, -height=>8);
        $mb->{"bts"}->packForget();
        $mb->{"flag"} = 0;
    } else {
        $mb->{"oc"}->configure(-width=>8, -height=>40);
        $mb->{"bts"}->pack(-side=>"left", -padx=>5, -pady=>5, -fill=>"x", -expand=>"yes");
        $mb->{"flag"} = 1;
    }
    return
}

sub toggle_toolbar {
    my $self = shift;
    my ($event) = @_;
    my $tb = $self->{"toolbar"};
    if ($tb->{"flag"} == 1) {
        $tb->parent()->configure(-height=>10);
        $tb->{"oc"}->configure(-width=>40, -height=>8);
        $tb->{"bts"}->packForget();
        $tb->{"flag"} = 0;
    } else {
        $tb->{"oc"}->configure(-width=>8, -height=>40);
        $tb->{"bts"}->pack(-side=>"left", -padx=>5, -pady=>5, -fill=>"x", -expand=>"yes");
        $tb->{"flag"} = 1;
    }
    return
}

sub fullpath {
    my $self = shift;
    my ($pathname) = @_;
    $pathname = File::Spec->rel2abs($pathname);
    $pathname =~ s/\\/\//gs;
    while ($pathname =~ s/[^\/]+\.\.\///gs) { ; }
    return $pathname;
}

sub get_app_conf {
    my $self = shift;
    return $self->{"app-conf"};
}

sub cmd_exit {
    my $self = shift;
    my $cancel = 0;
    eval {
        my $app_conf = $self->get_app_conf();
        my $app_conf_init = $self->{"app-conf-init"};
        if (!$app_conf->equal($app_conf_init)) {
            my $app_conf_file = $self->fullpath($app_conf->get_filename());
            my $message = sprintf($self->{"msg"}{"MSG_STR_CONFIRM_TO_SAVE_APP_CONF"}, $app_conf_file);
            my $res = $self->messageBox(-message=>$message,
                                        -icon=>"question",
                                        -type=>"yesnocancel", -default=>"yes");
            if ($res =~ /yes/i) {
                $app_conf->save();
            } elsif ($res =~ /cancel/i) {
                $cancel = 1;
            }
        }
    };
    if ($cancel == 0) {
        $self->exit();
    }
    return $cancel;
}

sub cmd_close {
    my $self = shift;
    if (ref($self->toplevel()) =~ /MainWindow/) {
        $self->cmd_exit();
    } else {
        $self->toplevel()->destroy();
    }
}

sub cmd_new {
    my $self = shift;
    my $top = $self->Toplevel();
    my $new_app = ref($self)->new($top, "opts"=>$self->{"opts"});
    $new_app->raise();
    return Tk::break();
}

sub cmd_show_help {
    my $self = shift;
    if ($self->{"_help_window"} and Tk::Exists($self->{"_help_window"})) {
        $self->{"_help_window"}->{"text"}->focus();
        $self->{"_help_window"}->deiconify();
        return;
    }
    my $data = "";
    my $file = $self->{"help-file"};
    if ($file) {
        open(my $fh, $file) or die "Cannot open '$file'.";
        $data = join("", (<$fh>));
        close($fh);
        $data = Encode::decode("utf-8", $data);
        $data =~ s/\r\n/\n/sg;
    }
    my $title = $self->{"msg"}{"STR_HELP"};
    my $top = $self->Toplevel(-title=>$title);
    $top->withdraw();
    $top->update();
    if (exists($self->{"img"})) {
        $top->iconimage($self->{"img"});
    }
    my $text_f = $top->Frame()->pack(-side=>"top", -fill=>"both", -expand=>"yes");
    my $text = $text_f->Scrolled("Text_patch", -scrollbars=>"se", -bg=>"#ffffff");
    $text->pack(-side=>"top", -fill=>"both", -expand=>"yes");
    $top->{"text"} = $text;
    my $bt_f = $top->Frame()->pack(-side=>"bottom");
    my $bt = $bt_f->Button(-text=>$self->{"msg"}{"BT_STR_CLOSE"},
                           -command=>sub { $top->withdraw(); });
    $bt->pack(-side=>"left");
    $top->{"bt"} = $bt;
    $text->insert("1.0", $data);
    $text->SetCursor("1.0");
    $text->configure(-state=>"disabled");
    $text->bind("<Control-Key-f>", sub { $text->FindPopUp(); });
    # $text->bind("<Control-Key-h>", sub { $text->FindAndReplacePopUp(); });
    $text->bind("<Button>", sub { $text->focus(); });
    $top->bind("<Control-Key-w>", sub { $top->{"bt"}->invoke(); });
    $top->bind("<Key-Escape>", sub { $top->{"bt"}->invoke(); });
    $top->update();
    $top->deiconify();
    $self->{"_help_window"} = $top;
    $self->{"_help_window"}->{"text"}->focus();
    return;
}

sub cmd_show_about {
    my $self = shift;
    if ($self->{"_about_window"} and Tk::Exists($self->{"_about_window"})) {
        $self->{"_about_window"}->{"bt"}->focus();
        $self->{"_about_window"}->deiconify();
        return;
    }
    my ($sx, $sy, $ox, $oy) =
        ($self->toplevel()->geometry() =~ /(\d+)x(\d+)\+(\d+)\+(\d+)/);
    my $cx = int($sx / 2.0 + $ox - 100);
    my $cy = int($sy / 2.0 + $oy - 100);
    my $title = $self->{"msg"}{"STR_ABOUT"};
    my $top = $self->Toplevel(-title=>$title);
    $top->withdraw();
    $top->update();
    $top->geometry(sprintf("+%s+%s", $cx, $cy));
    my $f = $top->Frame();
    $f->pack(-side=>"top", -ipadx=>10, -ipady=>10, -padx=>10, -pady=>10);
    if (exists($self->{"img"})) {
        $top->iconimage($self->{"img"});
        my $lbl = $f->Label(-image=>$self->{"img"});
        $lbl->pack(-side=>"top");
    }
    my $str_about = $self->{"msg"}{"FMT_ABOUT"};
    foreach my $name ("app-name", "app-version", "copyright") {
        my ($key, $value);
        if (exists($self->{$name})) {
            $key = quotemeta("[".$name."]");
            $value = $self->{$name};
        }
        if ($key ne "") {
            $str_about =~ s/$key/$value/gs;
        }
    }
    foreach my $config_name (keys %Config) {
        my ($key, $value);
        my $name = "perl-".$config_name;
        if (exists($Config{$config_name})) {
            $key = quotemeta("[".$name."]");
            $value = $Config{$config_name};
        }
        if ($key ne "") {
            $str_about =~ s/$key/$value/gs;
        }
    }
    my $lbl = $f->Label(-text=>$str_about);
    $lbl->pack(-side=>"top");
    my $bt = $f->Button(-text=>$self->{"msg"}{"BT_STR_OK"},
                        -command=>sub { $top->destroy(); });
    $bt->pack(-side=>"bottom");
    $top->{"bt"} = $bt;
    $top->{"bt"}->focus();
    $self->{"_about_window"} = $top;
    $top->bind("<Key-Escape>", sub { $top->{"bt"}->invoke(); });
    $top->resizable(0, 0);
    $top->update();
    $top->deiconify();
    $top->grab();
    return;
}

sub cmd_configuration {
    my $self = shift;
    my $configuration_window = $self->popup_configuration_dialogue();
    return Tk::break();
}

sub decode_pathname {
    my $self = shift;
    my ($pathname) = @_;
    my $enc = $self->get_pathname_encoding();
    $pathname = Encode::decode($enc, $pathname);
    return $pathname;
}

sub encode_pathname {
    my $self = shift;
    my ($pathname) = @_;
    my $enc = $self->get_pathname_encoding();
    $pathname = Encode::encode($enc, $pathname);
    return $pathname;
}

sub get_pathname_encoding {
    my $self = shift;
    my $enc = $self->get_app_conf()->get("pathname-encoding");
    if ($enc =~ /^\s*$/ or $enc =~ /auto/) {
        if ($Config{"archname"} =~ /MSWin32/) {
            $enc = "cp932";             # for Japanese windows
            $enc = "shift_jis";         # for Japanese windows
        } else {
            $enc = "utf-8";
        }
    }
    return $enc;
}

sub set_configuration_view {
    my $self = shift;
    my ($configuration_view) = @_;
    $self->{"configuration_view"} = $configuration_view;
}

sub get_droptypes {
    my $self = shift;
    # return $Config{"osname"} eq "MSWin32" ? "Win32" : ["KDE", "XDND", "Sun"];
    return $Config{"osname"} eq "MSWin32" ? "Win32" : ["XDND", "Sun"];
}

sub get_selection {
    my $self = shift;
    my ($w, $selection) = @_;
    my $result = undef;
    if ($Config{"osname"} eq "MSWin32") {
        $result = $w->SelectionGet(-selection=>$selection, "STRING");
    } else {
        $result = $w->SelectionGet(-selection=>$selection, "FILE_NAME");
    }
    return $result;
}

sub make_pathname_entry {
    my $self = shift;
    my ($f, %args) = @_;
    my $local_opts = {
        -foreground=>"#000000",
        -background=>"#ffffff",
    };
    my $added_opts = {
        -pathnametype => "pathname",
        -filetypes => [],
        -invalidforeground=>"#000000",
        -invalidbackground=>"#ffff77",
        -dirnamevariable=>undef,
        -filetypes=>undef,
        -textvariable=>undef,           # for initialization
    };
    my $opts = {%$added_opts, %$local_opts, %args};
    my $pathnametype = $opts->{"-pathnametype"};
    my $textvariable = $opts->{"-textvariable"};
    my $dirnamevariable = $opts->{"-dirnamevariable"};
    my $filetypes = $opts->{"-filetypes"};
    my $entry_opts = {%$opts};
    foreach my $key (keys %$added_opts) {
        delete $entry_opts->{$key};
    }
    my $func_get_reference = sub {
        my ($self, $e, $pathnametype) = @_;
        my $e = $e->Subwidget("entry");
        my $pathname = $e->get();
        my $new_pathname = undef;
        if ($pathnametype =~ /dirname/) {
            my $dirname = $pathname;
            if ($dirname eq "") {
                $dirname = $self->{"default-dirname"};
            }
            my $dirname_enc = $self->encode_pathname($dirname);
            $dirname_enc = $e->chooseDirectory(-initialdir=>$dirname_enc);
            $dirname = $self->decode_pathname($dirname_enc);
            if (defined($dirname)) {
                $self->{"default-dirname"} = $dirname;
                $new_pathname = $dirname;
            }
        } elsif ($pathnametype =~ /filename/) {
            my $dirname = $self->{"defautl-dirname"};
            if (defined($dirnamevariable)) {
                $dirname = $$dirnamevariable;
            }
            my $filename = $pathname;
            $pathname = $e->getOpenFile(
                -filetypes=>$filetypes,
                -initialdir=>$dirname,
                -initialfile=>$filename,
            );
            if ($pathname) {
                $dirname = File::Basename::dirname($pathname);
                $filename = File::Basename::basename($pathname);
                if (defined($dirnamevariable)) {
                    $$dirnamevariable = $dirname;
                }
                $self->{"default-dirname"} = $dirname;
                $new_pathname = $filename;
            }
        } elsif ($pathnametype =~ /pathname/) {
            my $dirname = $pathname;
            my $filename = "";
            if ($pathname ne "" and $pathname !~ /\/$/) {
                $dirname = File::Basename::dirname($pathname);
                $filename = File::Basename::basename($pathname);
            }
            $new_pathname = $e->getOpenFile(
                -filetypes=>$filetypes,
                -initialdir=>$dirname,
                -initialfile=>$filename,
            );
        }
        if (defined($new_pathname)) {
            $e->delete("0", "end");
            $e->insert("end", $new_pathname);
            $e->icursor("end");
        }
    };
    my $e;
    $e = $f->BrowseEntry(
        %$entry_opts,
        -autolimitheight => "yes",
        -listcmd => sub {
            my ($e) = @_;
            my $ee = $e->Subwidget("entry");
            my $pathname = $ee->get();
            my $dirname = $pathname;
            if (-f $pathname) {
                $dirname = File::Basename::dirname($pathname);
            }
            if ($pathnametype =~ /filename/) {
                $dirname = $self->{"default-dirname"};
                if (defined($dirnamevariable)) {
                    $dirname = $$dirnamevariable;
                }
            }
            eval {
                $e->delete(0, "end");
                if ($dirname eq "") {
                    $dirname = ".";
                }
                $dirname =~ s/^[a-zA-Z]\:$/$&\//;
                my $dirname_enc = $self->encode_pathname($dirname);
                opendir(my $dh, $dirname_enc) or print STDERR "Cannot open '$dirname_enc'\n";
                foreach my $filename_enc (sort {$a cmp $b} readdir($dh)) {
                    if ($filename_enc eq ".") {
                        next;
                    }
                    my $new_pathname_enc = $dirname_enc;
                    if ($new_pathname_enc !~ /\/$/) {
                        $new_pathname_enc .= "/";
                    }
                    $new_pathname_enc .= $filename_enc;
                    if (($pathnametype =~ /dirname/ and
                             -d $new_pathname_enc) or
                                 $pathnametype =~ /pathname/) {
                        if ($new_pathname_enc !~ /^[a-zA-Z]\:/ and
                                $new_pathname_enc !~ /^\//) {
                            $new_pathname_enc = "./".$new_pathname_enc;
                        }
                        while ($new_pathname_enc =~ s/\/[^\/]+\/\.\.//) {
                            ;
                        }
                        while ($new_pathname_enc =~ s/^\.\///) {
                            ;
                        }
                    } elsif ($pathnametype =~ /filename/) {
                        $new_pathname_enc = $filename_enc;
                    } else {
                        next;
                    }
                    my $new_pathname = $self->decode_pathname($new_pathname_enc);
                    $e->insert("end", $new_pathname);
                }
                closedir($dh);
                $e->update();
            };
        },
        -browsecmd => sub {
            my ($e) = @_;
            my $ee = $e->Subwidget("entry");
            $ee->icursor("end");
        },
        -validate => "all",
        -validatecommand => sub {
            my ($new_value, $mod_chars, $cur_value, $mod_index, $action_type) = @_;
            my $new_value_enc = $self->encode_pathname($new_value);
            my $new_value2 = $new_value;
            if (defined($dirnamevariable)) {
                $new_value2 = $$dirnamevariable."/".$new_value;
            }
            my $new_value2_enc = $self->encode_pathname($new_value2);
            if (defined($e)) {
                my $foreground = $opts->{"-foreground"};
                my $background = $opts->{"-background"};
                if (($pathnametype =~ /dirname/ and
                         !-d $new_value_enc) or
                             ($pathnametype =~ /pathname/ and
                                  !-f $new_value_enc) or
                                      ($pathnametype =~ /filename/ and
                                           !-f $new_value2_enc)) {
                    $foreground = $opts->{"-invalidforeground"};
                    $background = $opts->{"-invalidbackground"};
                }
                $e->configure(-foreground=>$foreground);
                $e->configure(-background=>$background);
            }
            # always return true because of just checking
            return 1;
        });
    if (defined($textvariable)) {
        $e->configure(-textvariable=>$textvariable);
    }
    $e->pack(-side=>"left", -fill=>"x", -expand=>"yes");
    $e->bind("<Key-Return>", sub { $func_get_reference->($self, $e, $pathnametype); });
    $b = $f->Button(
        -text=>$self->{"msg"}{"BT_STR_REFERENCE"},
        -command=>sub { $func_get_reference->($self, $e, $pathnametype); }
    );
    $b->pack(-side=>"left");
    $f->DropSite(
        -droptypes => $self->get_droptypes(),
        -dropcommand => sub {
            my ($selection) = @_;
            my $w = $f;
            my $pathname = $self->get_selection($w, $selection);
            if ($pathname) {
                $pathname =~ s/\\/\//g;
                $pathname = $self->decode_pathname($pathname);
                my $pathname_enc = $self->encode_pathname($pathname);
                if ($pathnametype =~ /dirname/i and
                        -f $pathname_enc) {
                    $pathname = File::Basename::dirname($pathname);
                }
                $e->delete("0", "end");
                $e->insert("end", $pathname);
            }
        }
    );
    return $e;
}

sub make_list_entry {
    my $self = shift;
    my ($f, %args) = @_;
    my $local_opts = {
        -foreground => "#000000",
        -background => "#ffffff",
    };
    my $added_opts = {
        -invalidforeground => "#000000",
        -invalidbackground => "#ffff77",
        -textvariable => undef,         # for initialization
        -list => undef,                 # for initialization
    };
    my $opts = {%$added_opts, %$local_opts, %args};
    my $item_list = $opts->{"-list"};
    my $textvariable = $opts->{"-textvariable"};
    my $entry_opts = {%$opts};
    foreach my $key (keys %$added_opts) {
        delete $entry_opts->{$key};
    }
    my $init_list_flag = 0;
    my $e;
    $e = $f->BrowseEntry(
        %$entry_opts,
        -autolimitheight => "yes",
        -listcmd => sub {
            my ($e) = @_;
            my $ee = $e->Subwidget("entry");
            if ($init_list_flag == 0) {
                $e->delete("0", "end");
                foreach my $item (@$item_list) {
                    $e->insert("end", $item);
                }
                $init_list_flag = 1;
            }
        },
        -browsecmd => sub {
            my ($e) = @_;
            my $ee = $e->Subwidget("entry");
            $ee->icursor("end");
        },
        -validate => "all",
        -validatecommand => sub {
            my ($new_value, $mod_chars, $cur_value, $mod_index, $action_type) = @_;
            my $found_flag = 0;
            foreach my $item (@$item_list) {
                if ($new_value eq $item) {
                    $found_flag = 1;
                    last;
                }
            }
            my $foreground = $opts->{"-foreground"};
            my $background = $opts->{"-background"};
            if ($found_flag == 0) {
                $foreground = $opts->{"-invalidforeground"};
                $background = $opts->{"-invalidbackground"};
            }
            $e->configure(-foreground=>$foreground);
            $e->configure(-background=>$background);
            # always return true because of just checking
            return 1;
        }
    );
    if(defined($textvariable)) {
        $e->configure(-textvariable=>$textvariable);
    }
    $e->pack(-side=>"left", -fill=>"x", -expand=>"yes");
    return $e;
}

sub popup_configuration_dialogue {
    my $self = shift;
    my ($configuration_view) = @_;
    unless($configuration_view) {
        $configuration_view = $self->{"configuration-view"};
    }
    my $app_conf = $self->get_app_conf();
    my $app_conf_clone = $app_conf->clone();
    my $title = $self->{"msg"}{"STR_CONFIGURATION"};
    my $top = $self->Toplevel(-title=>$title);
    $top->withdraw();
    $top->update();
    if (exists($self->{"img"})) {
        $top->iconimage($self->{"img"});
    }
    my $conf_geometry = $self->{"conf-geometry"};
    $top->geometry($conf_geometry);

    my $tab_f = $top->TabFrame();
    $tab_f->pack(-side=>"top", -fill=>"both", -expand=>"yes");
    my $bt_f = $top->Frame();
    $bt_f->pack(-side=>"top");

    my $tab_item = {};
    foreach my $tab_view (@$configuration_view) {
        my $tab_name = $tab_view->{"name"};
        my $lbl_str = $tab_name;
        if (exists($self->{"msg"}{$tab_name})) {
            $lbl_str = $self->{"msg"}{$tab_name};
        }
        my $lbl_str = $self->{"msg"}{$tab_name};
        my $ft = $tab_f->add(-name=>$lbl_str);
        $ft->gridColumnconfigure(0, -weight=>0);
        $ft->gridColumnconfigure(1, -weight=>1);
        my $row = 0;
        foreach my $configuration_item (@{$tab_view->{"options"}}) {
            my ($conf_name, $conf_type, $conf_opts) = @$configuration_item;
            my $conf_value_ref = $app_conf_clone->get_ref($conf_name);
            my $lbl_str = $conf_name;
            if (exists($self->{"msg"}{$conf_name})) {
                $lbl_str = $self->{"msg"}{$conf_name};
            }
            my $l = $ft->Label(-text=>$lbl_str);
            $l->grid(-row=>$row, -column=>0, -sticky=>"w");
            my $f = $ft->Frame();
            $f->grid(-row=>$row, -column=>1, -sticky=>"ew");
            my $e;
            if ($conf_type =~ /pathname/i or
                    $conf_type =~ /dirname/i or
                        $conf_type =~ /filename/i) {
                my $filetypes = $conf_opts->{"filetypes"};
                my $dirnamevariable = undef;
                if ($conf_type =~ /filename/) {
                    my $tmp_conf_name = $conf_opts->{"dirnamevariable"};
                    if ($app_conf_clone->exists_item($tmp_conf_name)) {
                        $dirnamevariable = $app_conf_clone->get_ref($tmp_conf_name);
                    }
                }
                $e = $self->make_pathname_entry(
                    $f,
                    -pathnametype=>$conf_type,
                    -textvariable=>$conf_value_ref,
                    -dirnamevariable=>$dirnamevariable,
                    -filetypes=>$filetypes,
                );
            } elsif($conf_opts) {
                $e = $self->make_list_entry(
                    $f,
                    -textvariable=>$conf_value_ref,
                    %$conf_opts
                );
            } else {
                $e = $ft->Entry(-textvariable=>$conf_value_ref, -width=>80);
                $e->grid(-row=>$row, -column=>1, -sticky=>"ew");
            }
            ++$row;
        }
    }
    $tab_f->select_tab(0);

    # button frame
    my $b;
    $b = $bt_f->Button(
        -text => $self->{"msg"}{"BT_STR_OK"},
        -command => sub {
            foreach my $name (keys %{$app_conf_clone->{"conf-map"}}) {
                $app_conf->{"conf-map"}{$name} = $app_conf_clone->{"conf-map"}{$name};
            }
            $top->parent()->focus();
            $top->destroy();
        }
    );
    $b->pack(-side=>"left");
    $top->{"ok"} = $b;
    $b = $bt_f->Button(
        -text=>$self->{"msg"}{"BT_STR_CANCEL"},
        -command=>sub {
            $top->parent()->focus();
            $top->destroy();
        }
    );
    $b->pack(-side=>"left");
    $top->{"cancel"} = $b;

    $tab_f->bind_keys_toplevel();
    $top->bind("<Key-Escape>", sub { $top->{"cancel"}->invoke(); });

    $top->resizable(1, 1);
    $top->update();
    $top->deiconify();
    $top->update();
    $top->{"ok"}->focus();
    $top->grab();
}

1;

#################### END OF FILE ####################
