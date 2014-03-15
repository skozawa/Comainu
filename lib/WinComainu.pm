# -*- mode: perl; coding: utf-8 -*-
package WinComainu;

use strict;
use warnings;
use utf8;

use parent qw(AppBase);

use Config;
use Tkx;
use Tkx::Scrolled;
Tkx::package_require("Tktable");
use FindBin qw($Bin);
use File::Basename;
use File::Spec;
use Time::HiRes;
use Encode;

use CommandWorker;
use ComainuGetPath;
use RunCom;


my $DEFAULT_VALUES = {
    "debug"                 => 0,
    "perl"                  => "perl",
    "app-name"              => "WinComainu",
    "app-version"           => '0.70',
    "title"                 => "",
    "copyright"             => "",
    "icon-file"             => "$Bin/../img/wincomainu.ico",
    "gif-file"              => "$Bin/../img/wincomainu.gif",
    "conf-file"             => "$Bin/../wincomainu.conf",
    "conf-org-file"         => "$Bin/../wincomainu_org.conf",
    "conf-geometry"         => "600x400",
    "msg-file"              => "$Bin/../msg/ja.txt",
    "help-file"             => "$Bin/../README_GUI.txt",
    "default-dirname"       => "",
    "in-pathname"           => "",
    "in-dirname"            => "",
    "in-filename"           => "",
    "out-pathname"          => "",
    "out-dirname"           => "",
    "out-filename"          => "",
    "comainu-input-type"    => "plain",
    "comainu-output-type"   => "long",
    "comainu-model-type"    => "SVM",
    "comainu-tagger-type"   => "mecab",
    "comainu-boundary-type" => "sentence",
    "max-display-line-number"       => 1000,
};

my $FONT_FAMILY_LIST = [];
my $CONFIGURATION_VIEW = [
    {
        "name" => "STR_INPUT_OUTPUT",
        "options" => [
            ["in-dirname", "dirname"],
            ["in-filename", "filename", {
                "dirnamevariable" => "in-dirname",
                "filetypes" =>
                    [['KC or Text', ['*.KC', '*.txt']], ['All Files', ['*.*']]]
                }],
            ["out-dirname", "dirname"],
            ["out-filename", "filename", {
                "dirnamevariable" => "out-dirname",
                "filetypes" =>
                    [['Longout', ['*.lout']], ['Text', ['*.txt']], ['All Files', ['*.*']]]
                }],
            ["tmp-dir", "dirname"],
        ]
    },
    {
        "name" => "STR_COMAINU",
        "options" => [
            ["comainu-home", "dirname"],
            ["comainu-crf-model", "pathname"],
            ["comainu-svm-model", "pathname"],
            ["comainu-bnst-svm-model", "pathname"],
            ["comainu-bi-model-dir", "dirname"],
            ["comainu-mst-model", "pathname"],
        ],
    },
    {
        "name" => "STR_TOOLS",
        "options" => [
            ["mecab-dir", "dirname"],
            ["mecab-dic-dir", "dirname"],
            ["unidic-db", "pathname"],
            ["yamcha-dir", "dirname"],
            ["svm-tool-dir", "dirname"],
            ["crf-dir", "dirname"],
            ["java", "pathname"],
            ["mstparser-dir", "dirname"],
        ],
    },
    {
        "name" => "STR_OTHERS",
        "options" => [
            ["msg-file", "pathname"],
            ["pathname-encoding", "string"],
            ["font-family", "string", {"-list" => $FONT_FAMILY_LIST}],
            ["font-size", "string", {"-list" => ["6", "9", "10", "12", "14", "18"]}],
            ["font-style", "string", {"-list" => ["normal", "bold", "roman", "italic"]}],
            ["max-display-line-number", "string"],
        ],
    },
];


sub initialize {
    my ($self, $args) = @_;
    my $opts = {
        %$DEFAULT_VALUES,
        %$args,
        "configuration-view" => $CONFIGURATION_VIEW,
    };
    unless ( $self->_parent ) {
        $self->g_wm_withdraw;
        $self->g_wm_geometry("800x600");
    }
    $self->SUPER::initialize($opts);

    # CommandWorker should be set up at first.
    my $com_worker = CommandWorker->new();
    $self->_data->{_com_worker} = $com_worker;

    $self->_set_app_path;

    unless ( $self->_parent ) {
        $self->g_wm_deiconify;
    }

    $self->init;
}

sub _set_app_path {
    my ($self) = @_;

    my $cgp = ComainuGetPath->new();
    my $app_conf = $self->_data->{"app-conf"};
    my $yamcha_dir = $app_conf->get("yamcha-dir");
    if ($yamcha_dir eq "") {
        $yamcha_dir = $cgp->get_yamcha_dir_auto();
        $app_conf->set("yamcha-dir", $yamcha_dir);
    }
    my $mecab_dir = $app_conf->get("mecab-dir");
    if ($mecab_dir eq "") {
        $mecab_dir = $cgp->get_mecab_dir_auto();
        $app_conf->set("mecab-dir", $mecab_dir);
    }
    my $mecab_dic_dir = $app_conf->get("mecab-dic-dir");
    if ($mecab_dic_dir eq "") {
        $mecab_dic_dir = $cgp->get_mecab_dic_dir_auto();
        $app_conf->set("mecab-dic-dir", $mecab_dic_dir);
    }
    my $unidic_db = $app_conf->get("unidic-db");
    if ($unidic_db eq "") {
        $unidic_db = $cgp->get_unidic_db_auto();
        $app_conf->set("unidic-db", $unidic_db);
    }
}

sub init {
    my $self = shift;
    $self->make_menubar;
    $self->make_toolbar;
    $self->make_mainframe;
}

sub make_menubar {
    my $self = shift;

    my $top = $self->_parent || $self;
    my $menubar_frame = $self->_data->{menubar};
    my $menubar_buttons = $menubar_frame->_data->{bts};

    my $app_conf = $self->_data->{"app-conf"};
    my $curr_font_family = $app_conf->get("font-family");
    my $curr_font_size   = $app_conf->get("font-size");
    my $curr_font_style  = $app_conf->get("font-style");
    my $cand_families = Tkx::tk_windowingsystem() eq "win32" ?
        [$curr_font_family, "Meiryo UI", "MS UI Gothic"] :
        [$curr_font_family, "gothic", "fixed"];
    my $def_families = [Tkx::font_families()];
    @$FONT_FAMILY_LIST = @$def_families;
    if ($self->_data->{debug}) {
        printf(STDERR "# FONT_FAMILIES=%s\n", Encode::encode("utf-8", join(", ", @$def_families)));
    }

    # Font etc.
    my $font_family = undef;
    foreach my $cand_font_family (@$cand_families) {
        foreach my $def_font_family (@$def_families) {
            if (lc($cand_font_family) eq lc($def_font_family)) {
                $font_family = $def_font_family;
                last;
            }
        }
        last if $font_family;
    }
    if ( defined $font_family ) {
        if ($self->_data->{debug}) {
            printf(STDERR "USE_FONT_FAMILY=%s\n", Encode::encode("utf-8", $font_family));
        }
        $app_conf->set("font-family", $font_family);
        $curr_font_family = $font_family;
    }
    Tkx::option_add('*font' => [$curr_font_family, $curr_font_size, $curr_font_style]);

    # File Menu
    {
        my $menubutton = $menubar_buttons->new_menubutton(
            -text => $self->_data->{msg}{MENU_STR_FILE}, -underline => 1
        );
        $menubutton->g_pack(-side => "left");
        my $menu = $menubutton->new_menu(-tearoff => 0);
        $menubutton->configure(-menu => $menu);

        # XXX new
        $menu->add_command(
            -label       => $self->_data->{msg}{MENU_STR_NEW},
            -underline   => 1,
            -accelerator => "Ctrl+N",
            -command     => sub { $self->cmd_new; }
        );
        $top->g_bind("<Control-Key-n>", sub { $self->cmd_new; });

        # open
        $menu->add_command(
            -label       => $self->_data->{msg}{MENU_STR_OPEN},
            -underline   => 1,
            -accelerator => "Ctrl+O",
            -command     => sub { $self->cmd_open; }
        );
        $top->g_bind("<Control-Key-o>", sub { $self->cmd_open; });

        # save
        $menu->add_command(
            -label       => $self->_data->{msg}{MENU_STR_SAVE_AS},
            -underline   => 1,
            -accelerator => "Ctrl+S",
            -command     => sub { $self->cmd_save_as; }
        );
        $top->g_bind("<Control-Key-s>", sub { $self->cmd_save_as; });

        # close
        $menu->add_command(
            -label       => $self->_data->{msg}{MENU_STR_CLOSE},
            -underline   => 1,
            -accelerator => "Ctrl+W",
            -command     => sub { $self->cmd_close; }
        );
        $top->g_bind("<Control-Key-w>", sub { $self->cmd_close; });
        $menu->add_separator;

        # exit
        $menu->add_command(
            -label       => $self->_data->{msg}{MENU_STR_EXIT},
            -underline   => 1,
            -accelerator => "Ctrl+Q",
            -command     => sub { $self->cmd_exit; }
        );
        $top->g_bind("<Control-Key-q>", sub { $self->cmd_exit; });
    }

    {
        my $mb = $menubar_buttons->new_menubutton(
            -text => $self->_data->{msg}{MENU_STR_EDIT}, -underline => 1
        );
        $mb->g_pack(-side => "left");

        my $mc = $mb->new_menu(-tearoff => 0);
        $mb->configure(-menu => $mc);

        # undo
        $mc->add_command(
            -label       => $self->_data->{msg}{MENU_STR_UNDO},
            -underline   => 1,
            -accelerator => "Ctrl+Z",
            -command     => sub { $self->g_event_generate("<Control-Key-z>"); }
        );

        # redo
        $mc->add_command(
            -label       => $self->_data->{msg}{MENU_STR_REDO},
            -underline   => 1,
            -accelerator => "Ctrl+Y",
            -command     => sub { $self->g_event_generate("<Control-Key-y>"); }
        );
        $mc->add_separator;

        # cut
        $mc->add_command(
            -label       => $self->_data->{msg}{MENU_STR_CUT},
            -underline   => 1,
            -accelerator => "Ctrl+X",
            -command     => sub { $self->g_event_generate("<Control-Key-x>"); }
        );

        # copy
        $mc->add_command(
            -label       => $self->_data->{msg}{MENU_STR_COPY},
            -underline   => 1,
            -accelerator => "Ctrl+C",
            -command     => sub { $self->g_event_generate("<Control-Key-c>"); }
        );

        # paste
        $mc->add_command(
            -label       => $self->_data->{msg}{MENU_STR_PASTE},
            -underline   => 1,
            -accelerator => "Ctrl+V",
            -command     => sub { $self->g_event_generate("<Control-Key-v>"); }
        );
        $mc->add_separator;

        # select_all
        $mc->add_command(
            -label       => $self->_data->{msg}{MENU_STR_SELECT_ALL},
            -underline   => 1,
            -accelerator => "Ctrl+A",
            -command     => sub { $self->g_event_generate("<Control-Key-a>"); }
        );
    }

    # Tool
    {
        my $menubutton = $menubar_buttons->new_menubutton(
            -text => $self->_data->{msg}{MENU_STR_TOOL}, -underline => 1
        );
        $menubutton->g_pack(-side => "left");
        my $menu = $menubutton->new_menu(-tearoff => 0);
        $menubutton->configure(-menu => $menu);

        $self->init_comainu_type("input-type");
        $self->make_comainu_type_cascade(
            "input-type", $menu, -label => $self->_data->{msg}{MENU_STR_COMAINU_INPUT},
        );

        $self->init_comainu_type("output-type");
        $self->make_comainu_type_cascade(
            "output-type", $menu, -label => $self->_data->{msg}{MENU_STR_COMAINU_OUTPUT},
        );

        $self->init_comainu_type("model-type");
        $self->make_comainu_type_cascade(
            "model-type", $menu, -label => $self->_data->{msg}{MENU_STR_COMAINU_MODEL},
        );

        $self->init_comainu_type("tagger-type");
        $self->make_comainu_type_cascade(
            "tagger-type", $menu, -label => $self->_data->{msg}{MENU_STR_COMAINU_TAGGER},
        );

        $self->init_comainu_type("boundary-type");
        $self->make_comainu_type_cascade(
            "boundary-type", $menu, -label => $self->_data->{msg}{MENU_STR_COMAINU_BOUNDARY},
        );

        # analysis
        $menu->add_command(
            -label       => $self->_data->{msg}{MENU_STR_ANALYSIS},
            -underline   => 1,
            -accelerator => "Alt+A",
            -command     => sub { $self->cmd_analysis; }
        );
        $top->g_bind("<Alt-Key-a>", sub { $self->cmd_analysis; });

        # batch analysis
        $menu->add_command(
            -label       => $self->_data->{msg}{MENU_STR_BATCH_ANALYSIS},
            -underline   => 1,
            -accelerator => "Alt+B",
            -command     => sub { $self->cmd_batch_analysis; }
        );
        $top->g_bind("<Alt-Key-b>", sub { $self->cmd_batch_analysis; });

        # clear input
        $menu->add_command(
            -label       => $self->_data->{msg}{MENU_STR_CLEAR_INPUT},
            -underline   => 1,
            -accelerator => "Alt+C",
            -command     => sub { $self->cmd_clear_input; }
        );
        $top->g_bind("<Alt-Key-c>", sub { $self->cmd_clear_input; });

        # clear cache
        $menu->add_command(
            -label       => $self->_data->{msg}{MENU_STR_CLEAR_CACHE},
            -underline   => 1,
            -accelerator => "Alt+D",
            -command     => sub { $self->cmd_clear_cache; }
        );
        $top->g_bind("<Alt-Key-d>", sub { $self->cmd_clear_cache; });
        $menu->add_separator;

        # configuration
        $menu->add_command(
            -label       => $self->_data->{msg}{MENU_STR_CONFIGURATION},
            -underline   => 1,
            -accelerator => "Alt+O",
            -command     => sub { $self->cmd_configuration; }
        );
        $top->g_bind("<Alt-Key-o>", sub { $self->cmd_configuration; });
    }

    # Help
    {
        my $menubutton = $menubar_buttons->new_menubutton(
            -text => $self->_data->{msg}{MENU_STR_HELP}, -underline => 1
        );
        $menubutton->g_pack(-side => "left");
        my $menu = $menubutton->new_menu(-tearoff => 0);
        $menubutton->configure(-menu => $menu);
        $menu->add_command(
            -label       => $self->_data->{msg}{MENU_STR_HELP},
            -underline   => 1,
            -accelerator => "F1",
            -command     => sub { $self->cmd_show_help; }
        );
        $top->g_bind("<F1>", sub { $self->cmd_show_help; });
        $menu->add_separator;
        $menu->add_command(
            -label     => $self->_data->{msg}{MENU_STR_ABOUT},
            -underline => 1,
            -command   => sub { $self->cmd_show_about; }
        );
    }

    return;
}

sub make_toolbar {
    my $self = shift;

    my $top = $self->_parent || $self;
    my $app_conf = $self->_data->{"app-conf"};
    my $toolbar_frame = $self->_data->{toolbar};
    my $toolbar_buttons = $toolbar_frame->_data->{bts};

    my $combo_frame = $toolbar_buttons->new_frame;
    $combo_frame->g_pack(-side => "top", -anchor => "nw");
    # input
    {
        my $label = $combo_frame->new_label(-text => $self->_data->{msg}{STR_COMAINU_INPUT});
        $label->g_pack(-side => "left");
        my $combobox = $self->make_comainu_type_selector(
            "input-type", $combo_frame, -width => 16,
        );
        $combobox->g_pack(-side=>"left");
    }
    # output
    {
        my $label = $combo_frame->new_label(-text => $self->_data->{msg}{STR_COMAINU_OUTPUT});
        $label->g_pack(-side => "left");
        my $combobox = $self->make_comainu_type_selector(
            "output-type", $combo_frame, -width => 20,
        );
        $self->_data->{"_comainu_output-type_combobox"} = $combobox;
        $combobox->g_pack(-side => "left");
    }
    # model
    {
        my $label = $combo_frame->new_label(-text => $self->_data->{msg}{STR_COMAINU_MODEL});
        $label->g_pack(-side => "left");
        my $combobox = $self->make_comainu_type_selector(
            "model-type", $combo_frame, -width => 6,
        );
        $combobox->g_pack(-side => "left");
    }
    # tagger
    {
        my $label = $combo_frame->new_label(-text => $self->_data->{msg}{STR_COMAINU_TAGGER});
        $label->g_pack(-side => "left");
        my $combobox = $self->make_comainu_type_selector(
            "tagger-type", $combo_frame, -width => 8,
        );
        $combobox->g_pack(-side => "left");
    }
    # boundary
    {
        my $label = $combo_frame->new_label(-text => $self->_data->{msg}{STR_COMAINU_BOUNDARY});
        $label->g_pack(-side => "left");
        my $combobox = $self->make_comainu_type_selector(
            "boundary-type", $combo_frame, -width => 6,
        );
        $self->_data->{"_comainu_boundary-type_combobox"} = $combobox;
        $combobox->g_pack(-side => "left");
    }

    my $button_frame = $toolbar_buttons->new_frame;
    $button_frame->g_pack(-side => "top", -anchor => "nw");
    # analysis
    {
        my $button = $button_frame->new_button(
            -text    => $self->_data->{msg}{BT_STR_ANALYSIS},
            -command => sub { $self->cmd_analysis; }
        );
        $button->g_pack(-side => "left", -anchor => "w");
        $self->_data->{_analysis_button} = $button;
    }
    # batch analysis
    {
        my $button = $button_frame->new_button(
            -text    => $self->_data->{msg}{BT_STR_BATCH_ANALYSIS},
            -command => sub { $self->cmd_batch_analysis; }
        );
        $button->g_pack(-side => "left", -anchor => "w");
        $self->_data->{_batch_analysis_button} = $button;
    }
    # clear input
    {
        my $button = $button_frame->new_button(
            -text    => $self->_data->{msg}{BT_STR_CLEAR_INPUT},
            -command => sub { $self->cmd_clear_input; }
        );
        $button->g_pack(-side => "left");
        $self->_data->{_clear_input_button} = $button;
    }
    # clear cache
    {
        my $button = $button_frame->new_button(
            -text    => $self->_data->{msg}{BT_STR_CLEAR_CACHE},
            -command => sub { $self->cmd_clear_cache; }
        );
        $button->g_pack(-side => "left");
        $self->_data->{_clear_cache_button} = $button;
    }
}

sub make_mainframe {
    my $self = shift;
    my $top = $self->_parent || $self;
    my $app_conf = $self->_data->{"app-conf"};
    my $mf = $self->_data->{mainframe};

    # Paned frame
    my $paned_window = $mf->new_ttk__panedwindow(-orient => "vertical");
    $paned_window->g_pack(-side => "top", -fill => "both", -expand => "yes");

    # Input pane
    {
        my $input_frame = $paned_window->new_frame(-bg => "#ffffff");
        $paned_window->add($input_frame);
        my $frame = $input_frame->new_frame;
        $frame->g_pack(-side => "top", -fill => "x");

        # input
        my $label = $frame->new_label(-text => $self->_data->{msg}{STR_INPUT});
        $label->g_pack(-side => "left", -fill => "x", -anchor => "w");

        # open button
        my $open_button = $frame->new_button(
            -text    => $self->_data->{msg}{BT_STR_OPEN},
            -command => sub { $self->cmd_open; }
        );
        $open_button->g_pack(-side => "left");

        # file path
        my $entry = $frame->new_entry(
            -textvariable => \$self->_data->{"in-pathname"},
            -state        => "readonly"
        );
        $entry->g_pack(-side => "left", -fill => "x", -expand => "yes", -anchor => "w");

        # checkbox for wrap
        my $wrap_button = $frame->new_checkbutton(
            -text     => $self->_data->{msg}{BT_STR_WRAP},
            -onvalue  => "word",
            -offvalue => "none",
            -variable => $app_conf->get_ref("in-is-wrap"),
            -command  => sub {
                $self->_data->{in_text}->configure(-wrap => $app_conf->get("in-is-wrap"));
            }
        );
        $wrap_button->g_pack(-side => "left");

        # checkbox for readonly
        my $readonly_button = $frame->new_checkbutton(
            -text     => $self->_data->{msg}{BT_STR_READONLY},
            -onvalue  => "1",
            -offvalue => "0",
            -variable => $app_conf->get_ref("in-is-readonly"),
            -command  => sub {
                my $state = $app_conf->get("in-is-readonly") ? "disabled" : "normal";
                $self->_data->{in_text}->configure(-state => $state);
                $self->_data->{in_table}->configure(-state => $state);
            }
        );
        $readonly_button->g_pack(-side => "left");

        # checkbox for table display
        my $table_button = $frame->new_checkbutton(
            -text     => $self->_data->{msg}{BT_STR_TABLE_DISP},
            -onvalue  => "1",
            -offvalue => "0",
            -variable => $app_conf->get_ref("in-is-table-display"),
            -command  => sub {
                $self->change_table_display("in");
            }
        );
        $table_button->g_pack(-side => "left");

        # scrool for input pane
        my $in_text = $input_frame->new_tkx_Scrolled(
            "text",
            -scrollbars => "se",
            -height     => 10,
            -bg         => "#ffffff",
            -wrap       => $app_conf->get("in-is-wrap"),
        );
        my $in_table = $input_frame->new_tkx_Scrolled(
            "table",
            -scrollbars => "se",
            -rows      => 1,
            -cols      => 1,
            -height    => 200,
            -takefocus => "yes",
            -bg        => "#ffffff",
            -multiline => 0,
        );

        my $state = $app_conf->get("in-is-readonly") ? "disabled" : "normal";
        $in_text->configure(-state => $state);
        $in_text->g_bind("<Button>", sub { $in_text->g_focus; });
        $in_text->g_bind("<Control-Key-f>", sub { $in_text->FindPopUp; });
        $in_text->g_bind("<Control-Key-h>", sub { $in_text->FindAndReplacePopUp; });
        $in_table->configure(-state => $state);
        $self->_data->{in_text} = $in_text;
        $self->_data->{in_table} = $in_table;

        $self->bind_wheel($in_table, $in_table);

        if($app_conf->get("in-is-table-display")) {
            $in_table->g_pack(-side => "top", -fill => "both", -expand => "yes");
        } else {
            $in_text->g_pack(-side => "top", -fill => "both", -expand => "yes");
        }
    }

    # Output pane
    {
        my $output_frame = $paned_window->new_frame;
        $paned_window->add($output_frame);
        my $frame = $output_frame->new_frame;
        $frame->g_pack(-side => "top", -fill => "x");

        # output label
        my $label = $frame->new_label(-text => $self->_data->{msg}{STR_OUTPUT});
        $label->g_pack(-side => "left", -anchor => "w");

        # save button
        my $save_button = $frame->new_button(
            -text    => $self->_data->{msg}{BT_STR_SAVE},
            -command => sub { $self->cmd_save_as; }
        );
        $save_button->g_pack(-side => "left");

        # file path
        my $entry = $frame->new_entry(
            -textvariable => \$self->_data->{"out-pathname"},
            -state        => "readonly"
        );
        $entry->g_pack(-side => "left", -fill => "x", -expand => "yes", -anchor => "w");

        # checkbox for wrap
        my $wrap_button = $frame->new_checkbutton(
            -text     => $self->_data->{msg}{BT_STR_WRAP},
            -onvalue  => "word",
            -offvalue => "none",
            -variable => $app_conf->get_ref("out-is-wrap"),
            -command  =>sub {
                $self->_data->{out_text}->configure(-wrap => $app_conf->get("out-is-wrap"));
            }
        );
        $wrap_button->g_pack(-side => "left");

        # checkbox for readonly
        my $readonly_button = $frame->new_checkbutton(
            -text     => $self->_data->{msg}{BT_STR_READONLY},
            -onvalue  => "1",
            -offvalue => "0",
            -variable => $app_conf->get_ref("out-is-readonly"),
            -command  => sub {
                my $state = $app_conf->get("out-is-readonly") ? "disabled" : "normal";
                $self->_data->{out_text}->configure(-state => $state);
                $self->_data->{out_table}->configure(-state => $state);
            }
        );
        $readonly_button->g_pack(-side => "left");

        # checkbox for table display
        my $table_button = $frame->new_checkbutton(
            -text     => $self->_data->{msg}{BT_STR_TABLE_DISP},
            -onvalue  => "1",
            -offvalue => "0",
            -variable => $app_conf->get_ref("out-is-table-display"),
            -command  => sub {
                $self->change_table_display("out");
            }
        );
        $table_button->g_pack(-side => "left");

        # scrool for output frame
        my $out_text = $output_frame->new_tkx_Scrolled(
            "text",
            -scrollbars => "se",
            -height     => 10,
            -bg         => "#ffffff",
            -wrap       => $app_conf->get("out-is-wrap")
        );
        my $out_table = $output_frame->new_tkx_Scrolled(
            'table',
            -scrollbars => "se",
            -rows      => 1,
            -cols      => 1,
            -height    => 200,
            -takefocus => "yes",
            -bg        => "#ffffff",
            -multiline => 0,
        );

        my $state = $app_conf->get("out-is-readonly") ? "disabled" : "normal";
        $out_text->configure(-state => $state);
        $out_text->g_bind("<Button>", sub { $out_text->g_focus; });
        $out_text->g_bind("<Control-Key-f>", sub { $out_text->FindPopUp; });
        $out_text->g_bind("<Control-Key-h>", sub { $out_text->FindAndReplacePopUp; });
        $out_table->configure(-state => $state);
        $self->_data->{out_text} = $out_text;
        $self->_data->{out_table} = $out_table;

        $self->bind_wheel($out_table, $out_table);

        if ($app_conf->get("out-is-table-display")) {
            $out_table->g_pack(-side => "top", -fill => "both", -expand => "yes");
        } else {
            $out_text->g_pack(-side => "top", -fill => "both", -expand => "yes");
        }
    }
}


sub bind_wheel {
    my ($self, $w, $table) = @_;

    if($Config{"osname"} eq "MSWin32") {
        $w->g_bind(
            "<MouseWheel>",
            sub {
                my $delta = $Tk::event->D();
                # %D := -120|+120 on MS-Windows
                $table->yview("scroll", (-$delta/120) * 1, "units");
            }
        );
    } else {
        $w->g_bind(
            "<Button-4>",
            sub { $table->yview("scroll", -1, "units"); }
        );
        $w->g_bind(
            "<Button-5>",
            sub { $table->yview("scroll", +1, "units"); }
        );
    }
}


# list for select box
sub get_comainu_type_list {
    my ($self, $type) = @_;

    return ["plain", "bccwj", "bccwjlong", "kc", "kclong"] if $type eq "input-type";

    if ($type eq "output-type") {
        my $input_type = $self->get_comainu_type_by_name("input-type", $self->_data->{"_comainu_input-type_name"});
        return ["bnst", "long"] if $input_type eq "kc";
        return ["mid"] if $input_type eq "bccwjlong" || $input_type eq "kclong";
        return ["bnst", "long_only_boundary", "long", "longbnst", "mid", "midbnst"];
    }

    return ["svm", "crf"]       if $type eq "model-type";
    return ["mecab"]            if $type eq "tagger-type";

    if ( $type eq "boundary-type" ) {
        my $input_type = $self->get_comainu_type_by_name("input-type", $self->_data->{"_comainu_input-type_name"});
        my $output_type = $self->get_comainu_type_by_name("output-type", $self->_data->{"_comainu_output-type_name"});
        return ["sentence"] if $input_type eq "plain" || $input_type eq "bccwjlong" ||
            $input_type eq "kclong" || $output_type eq "bnst";
        return ["sentence", "word"];
    }
}

# label list for select box
sub get_comainu_type_name_list {
    my ($self, $type) = @_;

    my $type_list = $self->get_comainu_type_list($type);
    my $type_name_list = [];
    foreach my $type (@$type_list) {
        my $type_name = $self->_data->{msg}{"STR_".uc($type)};
        push @$type_name_list, $type_name;
    }
    return $type_name_list;
}

sub get_comainu_type_by_name {
    my ($self, $type, $type_name) = @_;

    my $type_list = $self->get_comainu_type_list($type);
    my $type_name_list = $self->get_comainu_type_name_list($type);
    my $res_type;
    for (my $i = 0; $i < scalar @$type_list; ++$i) {
        my $tmp_type = $type_list->[$i];
        my $tmp_type_name = $type_name_list->[$i];
        if ($tmp_type_name eq ($type_name // "")) {
            $res_type = $tmp_type;
            last;
        }
    }
    return $res_type // "";
}


sub init_comainu_type {
    my ($self, $type) = @_;

    if (!exists $self->_data->{"_comainu_".$type."_name"} ||
            !exists $self->_data->{"_comainu_".$type}) {
        my $app_conf = $self->_data->{"app-conf"};
        my $type_list = $self->get_comainu_type_list($type);
        my $type_name_list = $self->get_comainu_type_name_list($type);
        for (my $i = 0; $i < scalar @$type_list; ++$i) {
            my $type_tmp = $type_list->[$i];
            my $type_name = $type_name_list->[$i];
            if ($app_conf->get("comainu-".$type) eq $type_tmp) {
                $self->_data->{"_comainu_".$type."_name"} = $type_name;
            }
        }
        $self->_data->{"_comainu_".$type."_name_list"} = $type_name_list;
    }
}

sub make_comainu_type_cascade {
    my ($self, $type, $mc, %opts) = @_;

    my $label = $opts{"-label"};
    my $menu; # for closure of postcommand

    $menu = $mc->new_menu(
        -tearoff     => 0,
        -postcommand => sub {
            $menu->delete(0, "end");
            foreach my $type_name (@{$self->get_comainu_type_name_list($type)}) {
                $menu->add_radiobutton(
                    -label    => $type_name,
                    -variable => \$self->_data->{"_comainu_".$type."_name"},
                    -command  => sub {
                        my $type_tmp = $self->get_comainu_type_by_name(
                            $type,
                            $self->_data->{"_comainu_type_name"}
                        );
                        my $app_conf = $self->_data->{"app-conf"};
                        $app_conf->set("comainu-".$type, $type_tmp);
                        $self->check_comainu_limitation($type);
                    }
                );
            }
        }
    );
    $mc->add_cascade(-underline => 1, -menu => $menu, %opts);
}

sub make_comainu_type_selector {
    my ($self, $type, $frame, %opts) = @_;
    my $app_conf = $self->_data->{"app-conf"};
    my $type_list = $self->get_comainu_type_list($type);
    my $type_name_list = $self->get_comainu_type_name_list($type);

    $self->init_comainu_type($type);
    my $combobox = $frame->new_ttk__combobox(
        -textvariable => \$self->_data->{"_comainu_".$type."_name"},
        -values       => $type_name_list,
        %opts,
    );
    $combobox->g_bind("<<ComboboxSelected>>",   sub {
        $app_conf->set("comainu-".$type, $type_list->[$combobox->current]);
        $self->check_comainu_limitation($type);
    });

    return $combobox;
}

# limit output-type by intput-type
sub check_comainu_limitation {
    my ($self, $type) = @_;

    return unless $type eq "input-type" || $type eq "output-type";

    $self->limit_combobox("output-type");
    $self->limit_combobox("boundary-type");
}

sub limit_combobox {
    my ($self, $type) = @_;

    my $name = $self->_data->{"_comainu_" . $type . "_name"};
    my $current = $self->get_comainu_type_by_name($type, $name);
    my $list = $self->get_comainu_type_name_list($type);
    my $found = 0;
    foreach my $tmp_name ( @$list ) {
        if ( $name eq $tmp_name ) {
            $found = 1;
            last;
        }
    }
    unless ( $found ) {
        $name = $list->[0];
        $self->_data->{"_comainu_" . $type . "_name"} = $name;
        $current = $self->get_comainu_type_by_name($type, $name);
        $self->_data->{"app-conf"}->set("comainu-" . $type, $current);
    }
    $self->_data->{"_comainu_" . $type . "_name_list"} = $list;
    $self->_data->{"_comainu_" . $type . "_combobox"}->m_configure(
        -values => $list
    );
}


# open file menu
sub cmd_open {
    my ($self, $in_file) = @_;

    my $app_conf = $self->_data->{"app-conf"};
    my $comainu_input_type = $app_conf->get("comainu-input-type");
    my $dirname = $app_conf->get("in-dirname");
    my $filename = $app_conf->get("in-filename");

    my $pathname;
    if (defined $in_file && $in_file ne "") {
        if (-f $self->encode_pathname($in_file)) {
            $pathname = $in_file;
        } else {
            $dirname = $in_file;
            $filename = "";
        }
    }
    unless (defined $pathname) {
        my $filetypes = [];
        if ($comainu_input_type =~ /kc/) {
            $filetypes = [['KC', ['*.KC']], ['Text', ['*.txt']]];
        } else {
            $filetypes = [['Text', ['*.txt']], ['KC', ['*.KC']]];
        }
        push @$filetypes, ['All Files', ['*.*']];
        $pathname = Tkx::tk___getOpenFile(
            -filetypes   => $filetypes,
            -initialdir  => $dirname,
            -initialfile => $filename,
            -parent      => $self,
        );
    }
    if ( $pathname ) {
        $dirname  = File::Basename::dirname($pathname);
        $filename = File::Basename::basename($pathname);
        $pathname = $dirname . "/" . $filename;
        $self->_data->{"in-pathname"} = $pathname;
        $app_conf->set("in-dirname", $dirname);
        $app_conf->set("in-filename", $filename);

        my $pathname_enc = $self->encode_pathname($pathname);
        if (open(my $fh, $pathname_enc)) {
            my $data = join("", (<$fh>));
            close($fh);
            $data =~ s/\r\n/\n/sg;
            $data = decode_utf8 $data;
            $self->cmd_clear_input;
            if ( $app_conf->get("in-is-table-display") ) {
                $self->put_table("in", $data);
            } else {
                $self->put_text("in", $data);
            }
            $self->_data->{"in-pathname"} = $pathname;
        }
    }

    return if defined $in_file && $in_file ne "";

    # my $top = $self->toplevel();
    # $top->raise();
    # return Tk::break();
}

sub cmd_save_as {
    my ($self, $out_file) = @_;

    my $app_conf = $self->_data->{"app-conf"};
    my $comainu_output_type = $app_conf->get("comainu-output-type");
    my $dirname     = $app_conf->get("out-dirname");
    my $filename    = $app_conf->get("out-filename");
    my $in_filename = $app_conf->get("in-filename");

    my $pathname;
    my $out_data = $app_conf->get("out-is-table-display") ?
        $self->get_data_from_table('out') : $self->get_data_from_text('out');

    if (defined $out_file && $out_file ne "") {
        $pathname = $out_file;
    } else {
        if ($out_data !~ /^\s*$/s ||
                Tkx::tk___messageBox(
                    -message => $self->_data->{msg}{MSG_STR_NULL_OUTPUT},
                    -icon    => "warning",
                    -type    => "yesno",
                    -default => "no"
                ) =~ /yes/i) {

            my $filetypes = do {
                if ($comainu_output_type eq "long") {
                    $filename = $in_filename . ".lout";
                    [['Long', ['*.lout']], ['Text', ['*.txt']]];
                } elsif ($comainu_output_type eq "bnst") {
                    $filename = $in_filename . ".bout";
                    [['BNST', ['*.bout']], ['Text', ['*.txt']]];
                } elsif ($comainu_output_type eq "longbnst") {
                    $filename = $in_filename . ".lbout";
                    [['LongBNST', ['*.lbout']], ['Text', ['*.txt']]];
                } elsif ($comainu_output_type eq "mid") {
                    $filename = $in_filename . ".mout";
                    [['Mid', ['*.mout']], ['Text', ['*.txt']]];
                } elsif ($comainu_output_type eq "midbnst") {
                    $filename = $in_filename . ".mbout";
                    [['MidBNST', ['*.mbout']], ['Text', ['*.txt']]];
                } else {
                    $filename = $in_filename . ".lout";
                    [['Long', ['*.lout']], ['Text', ['*.txt']]];
                }
            };
            push @$filetypes, ['All Files', ['*.*']];
            $pathname = Tkx::tk___getSaveFile(
                -filetypes   =>$filetypes,
                -initialdir  =>$dirname,
                -initialfile =>$filename,
                -parent      => $self->_parent || $self,
            );
        }
    }
    if ($pathname) {
        $dirname  = File::Basename::dirname($pathname);
        $filename = File::Basename::basename($pathname);
        $pathname = $dirname . "/" . $filename;
        $self->_data->{"out-pathname"} = $pathname;
        $app_conf->set("out-dirname", $dirname);
        $app_conf->set("out-filename", $filename);

        my $pathname_enc = $self->encode_pathname($pathname);
        if (open(my $fh, ">", $pathname_enc)) {
            $out_data = Encode::encode("utf-8", $out_data);
            printf($fh "%s", $out_data);
            close($fh);
        }
    }

    return if ($out_file // "") ne "";

    # my $top = $self->toplevel();
    # $top->raise();
    # return Tk::break();
}

sub cmd_analysis {
    my ($self, $cont_flag, $progress_func) = @_;
    my $app_conf = $self->_data->{"app-conf"};

    my $in_is_table_display = $app_conf->get("in-is-table-display");
    my $in_data = $in_is_table_display ?
        $self->get_data_from_table('in') : $self->get_data_from_text('in');

    if ($in_data !~ /^\s*$/s) {
        if ($in_is_table_display) {
            $self->put_table("out", "");
        } else {
            $self->put_text("out", "");
        }
        $self->enable_analysis_buttons(0);

        my $res_data = $self->execute_analysis_data($in_data, $progress_func);

        if ( $app_conf->get("out-is-table-display") ) {
            $self->put_table("out", $res_data);
        } else {
            $self->put_text("out", $res_data);
        }
        $self->enable_analysis_buttons(1);
    } elsif (!$cont_flag) {
        Tkx::tk___messageBox(
            -message => $self->_data->{msg}{MSG_STR_NULL_INPUT},
            -icon    => "warning",
            -type    => "ok"
        );
    }
    return if $cont_flag;

    # my $top = $self->toplevel();
    # $top->raise();
    # return Tk::break();
}

sub cmd_batch_analysis {
    my $self = shift;
    my $app_conf = $self->_data->{"app-conf"};

    my $in_dirname  = $app_conf->get("in-dirname");
    my $out_dirname = $app_conf->get("out-dirname");
    my $progress = 0;
    my $total    = 0;
    my $count    = 0;
    my $run_flag = 0;

    my $title = "Batch analysis";
    my $top = $self->new_toplevel;
    $top->g_wm_title($title);
    $top->g_wm_withdraw;
    Tkx::update();
    $top->g_wm_iconphoto($self->_data->{img}) if exists $self->_data->{img};
    $top->g_grab;

    my $func_execute_batch_analysis = sub {
        my ($self, $in_dirname, $out_dirname, $run_flag_ref, $total_ref, $count_ref, $progress_ref) = @_;

        my $app_conf = $self->_data->{"app-conf"};
        my $comainu_input_type  = $app_conf->get("comainu-input-type");
        my $comainu_output_type = $app_conf->get("comainu-output-type");
        $comainu_output_type =~ s/_only_boundary//;

        my $in_file_list  = [];
        my $out_file_list = [];
        eval {
            my $in_dirname_enc = $self->encode_pathname($in_dirname);
            opendir(my $dh, $in_dirname_enc);
            foreach my $filename (readdir($dh)) {
                my $in_pathname = undef;
                $filename = $self->decode_pathname($filename);
                next if $filename =~ /^\./;

                if ($comainu_input_type eq "kc") {
                    if ($filename =~ /\.KC$/) {
                        $in_pathname = $in_dirname."/".$filename;
                        push @$in_file_list, $in_pathname;
                        $filename =~ s/\.KC$//;
                    }
                } else {
                    if ($filename =~ /\.txt$/) {
                        $in_pathname = $in_dirname."/".$filename;
                        push @$in_file_list, $in_pathname;
                    }
                }
                if (defined $in_pathname) {
                    if ($comainu_output_type eq "bnst") {
                        $filename .= ".bout";
                    } elsif ($comainu_output_type eq "long") {
                        $filename .= ".lout";
                    } elsif ($comainu_output_type eq "longbnst") {
                        $filename .= ".lbout";
                    } elsif ($comainu_output_type eq "mid") {
                        $filename .= ".mout";
                    } elsif ($comainu_output_type eq "midbnst") {
                        $filename .= ".mbout";
                    }
                    my $out_pathname = $out_dirname."/".$filename;
                    push @$out_file_list, $out_pathname;
                }
            }
            closedir($dh);
        };

        my $total = scalar @$in_file_list;
        $$total_ref = $total;
        if ($$run_flag_ref == 0) {
            $$run_flag_ref = 1;
            if ($$count_ref == $$total_ref) {
                my $res = Tkx::tk___messageBox(
                    -message => $self->_data->{msg}{MSG_FINISHED_BATCH},
                    -icon    => "warning",
                    -type    => "yesno",
                    -default => "no"
                );
                if ($res =~ /yes/i) {
                    $$count_ref = 0;
                } else {
                    $$run_flag_ref = 0;
                    return;
                }
            }
        } else {
            $$run_flag_ref = 0;
            return;
        }
        mkdir $out_dirname unless -d $out_dirname;

        while ($$run_flag_ref == 1 && $$count_ref < $total) {
            my $in_file  = $in_file_list->[$$count_ref];
            my $out_file = $out_file_list->[$$count_ref];
            ++$$count_ref;
            $$progress_ref = 100 * ($$count_ref - 1 + 0.01) / $total;
            my $next_progress = 100 * $$count_ref / $total;
            Tkx::update();
            my $progress_func = sub {
                my $delta = ($next_progress - $$progress_ref) / 2.0;
                $delta = 1 if $delta > 1;
                $$progress_ref += $delta;
                Tkx::update();
            };
            $self->execute_analysis_file_on_gui($in_file, $out_file, $top, $progress_func);
            $$progress_ref = 100 * $$count_ref / $total;
            Tkx::update();
        }
        $$run_flag_ref = 0;
    };
    my $func_reset = sub {
        $count = 0;
        $progress = 0;
        $run_flag = 1;
        $func_execute_batch_analysis->(
            $self, $in_dirname, $out_dirname,
            \$run_flag, \$total, \$count, \$progress
        );
    };
    my $func_close = sub {
        my ($self, $in_dirname, $out_dirname, $top, $run_flag_ref) = @_;
        $$run_flag_ref = 0;
        $app_conf->set("in-dirname", $in_dirname);
        $app_conf->set("out-dirname", $out_dirname);
        $top->_parent->g_focus if $top->_parent;
        $top->g_destroy;
    };

    # for frame
    my $main_frame = $top->new_frame;
    $main_frame->g_pack(-side => "top", -fill => "x", -expand => "yes");
    my $row = 0;

    {
        # for selector
        my $frame = $main_frame->new_frame;
        $frame->g_grid(-row => $row, -column => 0, -columnspan => 2, -sticky => "w");

        my $col = 0;
        # input
        {
            my $label = $frame->new_label(-text => $self->_data->{msg}{STR_COMAINU_INPUT});
            $label->g_grid(-row => $row, -column => $col++, -sticky => "w");
            my $combobox = $self->make_comainu_type_selector(
                "input-type", $frame, -width => 16
            );
            $combobox->g_grid(-row => $row, -column => $col++, -sticky => "w");
        }
        # output
        {
            my $label = $frame->new_label(-text => $self->_data->{msg}{STR_COMAINU_OUTPUT});
            $label->g_grid(-row => $row, -column => $col++, -sticky => "w");
            my $combobox = $self->make_comainu_type_selector(
                "output-type", $frame, -width => 16
            );
            $combobox->g_grid(-row => $row, -column => $col++, -sticky => "w");
        }
        # model
        {
            my $label = $frame->new_label(-text => $self->_data->{msg}{STR_COMAINU_MODEL});
            $label->g_grid(-row => $row, -column => $col++, -sticky => "w");
            my $combobox = $self->make_comainu_type_selector(
                "model-type", $frame, -width => 6,
            );
            $combobox->g_grid(-row => $row, -column => $col++, -sticky => "w");
        }
        # tagger
        {
            my $label = $frame->new_label(-text => $self->_data->{msg}{STR_COMAINU_TAGGER});
            $label->g_grid(-row => $row, -column => $col++, -sticky => "w");
            my $combobox = $self->make_comainu_type_selector(
                "tagger-type", $frame, -width => 8,
            );
            $combobox->g_grid(-row => $row, -column => $col++, -sticky => "w");
        }
        # boundary
        {
            my $label = $frame->new_label(-text => $self->_data->{msg}{STR_COMAINU_BOUNDARY});
            $label->g_grid(-row => $row, -column => $col++, -sticky => "w");
            my $combobox = $self->make_comainu_type_selector(
                "boundary-type", $frame, -width => 6,
            );
            $combobox->g_grid(-row => $row, -column => $col++, -sticky => "w");
        }
    }
    ++$row;

    # for input
    {
        my $label = $main_frame->new_label(-text => $self->_data->{msg}{STR_INPUT_DIR});
        $label->g_grid(-row => $row, -column => 0, -sticky => "e");
        my $frame = $main_frame->new_frame;
        $frame->g_grid(-row => $row, -column => 1, -sticky => "ew");
        my $entry = $self->make_pathname_entry(
            $frame,
            -textvariable => \$in_dirname,
            -pathnametype => "dirname"
        );
    }
    ++$row;

    # for output
    {
        my $label = $main_frame->new_label(-text => $self->_data->{msg}{STR_OUTPUT_DIR});
        $label->g_grid(-row => $row, -column => 0, -sticky => "e");
        my $frame = $main_frame->new_frame;
        $frame->g_grid(-row => $row, -column => 1, -sticky => "ew");
        my $entry = $self->make_pathname_entry(
            $frame,
            -textvariable => \$out_dirname,
            -pathnametype => "dirname"
        );
    }
    ++$row;

    # for progress bar
    {
        my $frame = $top->new_frame;
        $frame->g_pack(-side => "top", -fill => "x");
        my $progress_label = $frame->new_label(-text => $self->_data->{msg}{STR_PROGRESS});
        $progress_label->g_pack(-side => "left");
        my $count_label = $frame->new_label(-textvariable => \$count, -width => 5);
        $count_label->g_pack(-side => "left");
        my $slash_label = $frame->new_label(-text => "/");
        $slash_label->g_pack(-side => "left");
        my $total_label = $frame->new_label(-textvariable => \$total, -width => 5);
        $total_label->g_pack(-side => "left");

        my $colors = [];
        my $color_list = [
            '#ff7f7f', '#ffff7f', '#7fff7f',
            '#7fffff', '#7f7fff', '#ff7fff',
        ];
        my $color_list_len = scalar(@$color_list);
        for(my $i = 0; $i < $color_list_len - 1; ++$i) {
            for (my $j = 0; $j < 100 / ($color_list_len - 1); ++$j) {
                my $start_color = $color_list->[$i];
                my $end_color   = $color_list->[$i + 1];
                my $c = $self->calc_color(
                    $start_color, $end_color, $j, 100 / ($color_list_len - 1)
                );
                my $k = $j + $i * 100 / $color_list_len;
                push @$colors, $k, $c;
            }
        }
        $colors = [0 => '#00ff00'];

        $progress = 0.0;
        my $progress_bar = $frame->new_ttk__progressbar(
            -length => 500,
            -variable => \$progress,
        );
        $progress_bar->g_pack(
            -side => "left", -padx => 5, -pady => 5,
            -fill => "x", -expand => "yes",
        );
    }

    # for buttons
    {
        my $frame = $top->new_frame;
        $frame->g_pack(-side => "top");
        my $reset_button = $frame->new_button(
            -text    => $self->_data->{msg}{BT_STR_RESET},
            -command => sub { $func_reset->(); }
        );
        $reset_button->g_pack(-side => "left");
        my $execute_button = $frame->new_button(
            -text    => $self->_data->{msg}{BT_STR_EXECUTE_STOP},
            -command => sub {
                $func_execute_batch_analysis->(
                    $self, $in_dirname, $out_dirname,
                    \$run_flag, \$total, \$count, \$progress
                );
            }
        );
        $execute_button->g_pack(-side => "left");
        $execute_button->g_focus;
        my $close_button = $frame->new_button(
            -text    => $self->_data->{msg}{BT_STR_CLOSE},
            -command => sub {
                $func_close->($self, $in_dirname, $out_dirname, $top, \$run_flag);
            }
        );
        $close_button->g_pack(-side => "left");

        $top->g_bind("<Control-Key-r>", sub { $func_reset->(); });
        $top->g_bind("<Control-Key-e>", sub {
            $func_execute_batch_analysis->(
                $self, $in_dirname, $out_dirname,
                \$run_flag, \$total, \$count, \$progress
            );
        });
        $top->g_bind("<Control-Key-w>", sub {
            $func_close->($self, $in_dirname, $out_dirname, $top, \$run_flag);
        });
        $top->g_bind("<Key-Escape>", sub {
            $func_close->($self, $in_dirname, $out_dirname, $top, \$run_flag);
        });
        $top->g_wm_protocol("WM_DELETE_WINDOW", sub {
            $func_close->($self, $in_dirname, $out_dirname, $top, \$run_flag);
        });
    }

    $run_flag = 1;
    $func_execute_batch_analysis->(
        $self, $in_dirname, $out_dirname,
        \$run_flag, \$total, \$count, \$progress
    );
    $top->g_wm_resizable(1, 0);
    Tkx::update();
    $top->g_wm_deiconify;
    $self->enable_analysis_buttons(0);
    # $top->waitWindow($top);
    $self->enable_analysis_buttons(1);
    # return Tk::break();
}


sub cmd_clear_input {
    my $self = shift;

    my $app_conf = $self->_data->{"app-conf"};
    if ( $app_conf->get("in-is-table-display") ) {
        $self->put_table("in", "");
    } else {
        $self->put_text("in", "");
    }
    $self->_data->{"in-pathname"} = "";

    if ($app_conf->get("out-is-table-display")) {
        $self->put_table("out", "");
    } else {
        $self->put_text("text", "");
    }
    $self->_data->{"out-pathname"} = "";
}

sub cmd_clear_cache {
    my $self = shift;
    my $app_conf = $self->_data->{"app-conf"};
    my $tmp_dir = $app_conf->get("tmp-dir");
    my $message = $tmp_dir . "\n" . $self->_data->{msg}{MSG_CLEAR_CACHE};

    my $res = Tkx::tk___messageBox(
        -message => $message,
        -icon    => "warning",
        -type    => "yesno",
        -default => "no"
    );
    if ($res =~ /^yes/i) {
        $self->rm_fr($tmp_dir) if -d $tmp_dir;
    }
}

sub rm_fr {
    my ($self, $dir) = @_;

    opendir(my $dh, $dir);
    foreach my $file (readdir($dh)) {
        next if $file =~ /^\./;
        if (-f $dir . "/" . $file) {
            unlink $dir . "/" . $file;
        } elsif (-d $dir . "/" . $file) {
            $self->rm_fr($dir . "/" . $file);
        }
    }
    closedir($dh);
    rmdir($dir);
}


sub put_text {
    my ($self, $type, $data) = @_;

    my $text = $self->_data->{$type . "_text"};

    # limit display text
    $self->_data->{$type . "_data"} = $data;
    my @lines = split /\r?\n/, $data;
    my $max_line_number = $self->_data->{"app-conf"}->get("max-display-line-number");
    my $display_data = join "\n", (splice @lines, 0, $max_line_number);
    undef @lines;

    my $state = $text->cget(-state);
    $text->configure(-state => "normal");
    $text->delete("1.0", "end");
    $text->insert("end", $display_data);
    $text->configure(-state => $state);
    undef $display_data;
}

sub get_data_from_text {
    my ($self, $type) = @_;

    my $text = $self->_data->{$type . "_text"};

    my $data = $text->get("1.0", "end");
    $data =~ s/([^\n])\n$/$1/s;
    $data =~ s/^\n$//s;

    # merge text data
    my @lines = split /\r?\n/, $self->_data->{$type . "_data"} // '';
    my $max_line_number = $self->_data->{"app-conf"}->get("max-display-line-number");
    if ( scalar @lines > $max_line_number ) {
        splice @lines, 0, $max_line_number;
        $data .= "\n" . join "\n", @lines;
    }
    undef @lines;

    $self->_data->{$type . "_data"} = $data;
    return $data;
}

sub put_table {
    my ($self, $type, $data) = @_;

    my $table = $self->_data->{$type . "_table"};
    my $sep = ($data =~ /\t/) ? "\t" : " ";
    $table->_data->{__sep} = $sep;
    my $or = 0;
    my $oc = 0;
    my $has_row_number = 0;
    my $has_col_number = 0;

    # limit display data
    $data =~ s/\n$//s;
    $self->_data->{$type . "_data"} = $data;
    my @lines = split /\r?\n/, $data;
    my $max_line_number = $self->_data->{"app-conf"}->get("max-display-line-number");
    my $row_list = [splice @lines, 0, $max_line_number];
    undef @lines;

    my $row_count = scalar @$row_list;
    my $column_count = 0;
    for (my $r = 0; $r < $row_count; ++$r) {
        my $line = $row_list->[$r];
        my $column_list = [split(/$sep/, $line, -1)];
        $column_count = scalar @$column_list if $column_count < scalar @$column_list;
        $row_list->[$r] = $column_list;
    }

    my $bg = $table->cget(-background);
    my $fg = $table->cget(-foreground);
    $table->configure(
        -rows => $row_count + $or + $has_row_number,
        -cols => $column_count + $oc + $has_col_number,
        -roworigin => $or,
        -colorigin => $oc,
    );

    my $variables;
    if ($has_col_number) {
        for (my $c = 0; $c < $column_count; $c++) {
            my $index = sprintf('%d,%d', 0, $c + 1);
            my $cell = $table->get($index) || ($c + 1);
            $variables->{$index} = $cell;
        }
    }
    if ($has_row_number) {
        for (my $r = 0; $r <= $row_count; $r++) {
            my $index = sprintf('%d,%d', $r + 1, 0);
            my $cell = $table->get($index) || ($r + 1);
            $variables->{$index} = $cell;
        }
    }

    for (my $r = 0; $r < $row_count; $r++) {
        for (my $c = 0; $c < $column_count; $c++) {
            my $item = $row_list->[$r][$c] // '';
            my $w = length($item) + 4;
            $w = 20 if $w > 20;

            my $index = sprintf('%d,%d', $r + $or + $has_row_number, $c + $oc + $has_col_number);
            my $cell = $table->get($index) || $item;
            $variables->{$index} = $cell;
        }
    }
    $table->configure(-variable => $variables);
}

sub get_data_from_table {
    my ($self, $type) = @_;

    my $table = $self->_data->{$type . "_table"};
    my $sep = $table->_data->{__sep};
    my $or = 0;
    my $oc = 0;
    my $has_row_number = 0;
    my $has_col_number = 0;
    my $rows = $table->cget(-rows) - $or - $has_row_number;
    my $columns = $table->cget(-cols) - $oc - $has_col_number;

    my $row_list = [];
    for (my $r = 0; $r < $rows; $r++) {
        my $column_list = [];
        for (my $c = 0; $c < $columns; $c++) {
            my $cell = $table->get(($r + $or + $has_row_number) . ',' . ($c + $oc + $has_col_number));
            next if ! $cell && $sep eq ' ';
            push @$column_list, $cell;
        }
        push @$row_list, join($sep, @$column_list);
    }
    my $data = join("\n", @$row_list);

    # merge text data
    my @lines = split /\r?\n/, $self->_data->{$type . "_data"} // '';
    my $max_line_number = $self->_data->{"app-conf"}->get("max-display-line-number");
    if ( scalar @lines > $max_line_number ) {
        splice @lines, 0, $max_line_number;
        $data .= "\n" . join "\n", @lines;
    }
    undef @lines;

    $data .= "\n" if $data ne "";
    $self->_data->{$type . "_data"} = $data;
    return $data;
}

sub change_table_display {
    my ($self, $type) = @_;

    my $app_conf = $self->_data->{"app-conf"};
    my $is_table_display = $app_conf->get($type . "-is-table-display");
    my $text = $self->_data->{$type . "_text"};
    my $table = $self->_data->{$type . "_table"};

    if ( $is_table_display ) {
        my $data = $self->get_data_from_text($type);
        $table->clear('all');
        $self->put_table($type, $data);
        Tkx::pack('forget', $text);
        $table->g_pack(-side => "top", -fill => "both", -expand => "yes");
    } else {
        my $data = $self->get_data_from_table($type);
        $self->put_text($type, $data);
        Tkx::pack('forget', $table);
        $text->g_pack(-side => "top", -fill => "both", -expand => "yes");
    }
}


sub calc_color {
    my ($self, $start_color, $end_color, $i, $region) = @_;

    my ($rs, $gs, $bs) = ($start_color =~ /^\#(..)(..)(..)$/);
    my ($re, $ge, $be) = ($end_color =~ /^\#(..)(..)(..)$/);
    $rs = hex($rs);
    $gs = hex($gs);
    $bs = hex($bs);
    $re = hex($re);
    $ge = hex($ge);
    $be = hex($be);
    my $rc = $rs + ($re - $rs) * $i / $region;
    my $gc = $gs + ($ge - $gs) * $i / $region;
    my $bc = $bs + ($be - $bs) * $i / $region;
    my $c = sprintf("#%02x%02x%02x", $rc, $gc, $bc);

    return $c;
}

sub enable_analysis_buttons {
    my ($self, $flag) = @_;

    my $data = $self->_data;
    my @buttons = (
        "_analysis_button",
        "_batch_analysis_button",
        "_clear_input_button",
        "_clear_cache_button",
    );
    for (@buttons) {
        $data->{$_}->configure(-state => $flag ? "normal" : "disabled");
    }
    Tkx::update();
}

sub execute_analysis_file_on_gui {
    my ($self, $in_file, $out_file, $top, $progress_func) = @_;

    $self->cmd_open($in_file);
    $top->g_raise if $top;
    Tkx::update();
    $self->cmd_analysis(1, $progress_func);
    $top->g_raise if $top;
    Tkx::update();
    $self->cmd_save_as($out_file);
    $top->g_raise if $top;
    Tkx::update();
}

sub execute_analysis_data {
    my ($self, $in_data, $progress_func) = @_;
    my $app_conf = $self->_data->{"app-conf"};

    my $mecab_dir     = $app_conf->get("mecab-dir");
    my $mecab_dic_dir = $app_conf->get("mecab-dic-dir");
    my $unidic_db     = $app_conf->get("unidic-db");
    my $yamcha_dir    = $app_conf->get("yamcha-dir");
    my $crf_dir       = $app_conf->get("crf-dir");
    my $java          = $app_conf->get("java");
    my $mstparser_dir = $app_conf->get("mstparser-dir");

    my $comainu_home            = $app_conf->get("comainu-home");
    my $comainu_crf_model       = $app_conf->get("comainu-crf-model");
    my $comainu_svm_model       = $app_conf->get("comainu-svm-model");
    my $comainu_bnst_svm_model  = $app_conf->get("comainu-bnst-svm-model");
    my $comainu_bi_model_dir    = $app_conf->get("comainu-bi-model-dir");
    my $comainu_mst_model       = $app_conf->get("comainu-mst-model");
    my $comainu_input_type      = $app_conf->get("comainu-input-type");
    my $comainu_output_type     = $app_conf->get("comainu-output-type");
    my $comainu_long_model_type = $app_conf->get("comainu-model-type");
    my $comainu_tagger          = $app_conf->get("comainu-tagger-type");
    my $comainu_boundary        = $app_conf->get("comainu-boundary-type");

    my $tmp_dir = $app_conf->get("tmp-dir");

    my $luwmrph = "with";
    if ($comainu_output_type eq "long_only_boundary") {
        $comainu_output_type = "long";
        $luwmrph = "without";
    }

    # Comainu method
    my $comainu_method = sprintf("%s2%sout", $comainu_input_type, $comainu_output_type);

    my $comainu_test = $tmp_dir."/foo.txt";
    if ($comainu_input_type eq "kc") {
        $comainu_test = $tmp_dir."/foo.KC";
    }

    my $out_file = $tmp_dir."/".File::Basename::basename($comainu_test);
    if ($comainu_output_type eq "bnst") {
        $out_file .= ".bout";
    } elsif ($comainu_output_type eq "long") {
        $out_file .= ".lout";
    } elsif ($comainu_output_type eq "longbnst") {
        $out_file .= ".lbout";
    } elsif ($comainu_output_type eq "mid") {
        $out_file .= ".mout";
    } elsif ($comainu_output_type eq "midbnst") {
        $out_file .= ".mbout";
    }

    my $comainu_long_model = $comainu_crf_model;
    $comainu_long_model = $comainu_svm_model if $comainu_long_model_type =~ /svm/;
    my $comainu_mid_model = $comainu_mst_model;
    my $comainu_bnst_model = $comainu_bnst_svm_model;

    mkdir $tmp_dir unless -d $tmp_dir;
    unlink $out_file if -f $out_file;

    eval {
        open(my $fh, ">", $comainu_test);
        binmode($fh);
        $in_data = Encode::encode("utf-8", $in_data);
        printf($fh "%s", $in_data);
        close($fh);
    };

    $yamcha_dir         = File::Spec->rel2abs($yamcha_dir);
    $mecab_dir          = File::Spec->rel2abs($mecab_dir);
    $mecab_dic_dir      = File::Spec->rel2abs($mecab_dic_dir);
    $unidic_db          = File::Spec->rel2abs($unidic_db);
    $comainu_home       = File::Spec->rel2abs($comainu_home);
    $comainu_long_model = File::Spec->rel2abs($comainu_long_model);
    $comainu_mid_model  = File::Spec->rel2abs($comainu_mid_model);
    $tmp_dir            = File::Spec->rel2abs($tmp_dir);
    $comainu_test       = File::Spec->rel2abs($comainu_test);

    my $runcom = $Bin."/../bin/runcom.exe";
    $runcom = $self->_data->{perl} unless -f $runcom;

    $ENV{"PERL"} = $runcom;
    my $comainu_opts = {
        "debug"                => $self->_data->{debug},
        "comainu-home"         => $comainu_home,
        "mecab-dir"            => $mecab_dir,
        "mecab-dic-dir"        => $mecab_dic_dir,
        "unidic-db"            => $unidic_db,
        "yamcha-dir"           => $yamcha_dir,
        "crf-dir"              => $crf_dir,
        "java"                 => $java,
        "mstparser-dir"        => $mstparser_dir,
        "output-dir"           => $tmp_dir,
        "comainu-temp"         => $tmp_dir."/temp",
        "comainu-bi-model-dir" => $comainu_bi_model_dir,
        "boundary"             => $comainu_boundary,
        "luwmodel-type"        => uc($comainu_long_model_type),
        "luwmrph"              => $luwmrph,
    };

    my $comainu_opts_str = join(" ", map {"--".$_." \"".$comainu_opts->{$_}."\"";} keys %$comainu_opts);
    my $comainu_com = do {
        if($comainu_method =~ /(plain|bccwj|kc)2bnstout/) {
            # BunSetsu Analysis
            sprintf(
                "\"%s\" \"%s/script/comainu.pl\" %s \"%s\" --bnstmodel \"%s\" --input \"%s\" --output-dir \"%s\"",
                $runcom, $comainu_home, $comainu_opts_str, $comainu_method,
                $comainu_bnst_model, $comainu_test, $tmp_dir
            );
        } elsif($comainu_method =~ /(plain|bccwj|kc)2longbnstout/) {
            # Long & BunSetsu Analysis
            sprintf(
                "\"%s\" \"%s/script/comainu.pl\" %s \"%s\" --luwmodel \"%s\" --bnstmodel \"%s\" --input \"%s\" --output-dir \"%s\"",
                $runcom, $comainu_home, $comainu_opts_str, $comainu_method,
                $comainu_long_model, $comainu_bnst_model, $comainu_test, $tmp_dir
            );
        } elsif($comainu_method =~ /(plain|bccwj|kc)2midout/) {
            # Mid Analysis
            sprintf(
                "\"%s\" \"%s/script/comainu.pl\" %s \"%s\" --luwmodel \"%s\" --muwmodel \"%s\" --input \"%s\" --output-dir \"%s\"",
                $runcom, $comainu_home, $comainu_opts_str, $comainu_method,
                $comainu_long_model, $comainu_mid_model, $comainu_test, $tmp_dir
            );
        } elsif($comainu_method =~ /(plain|bccwj|kc)2midbnstout/) {
            # Long & Mid Analysis % BunSetsu
            sprintf(
                "\"%s\" \"%s/script/comainu.pl\" %s \"%s\" --luwmodel \"%s\" --muwmodel \"%s\" --bnstmodel \"%s\" --input \"%s\" --output-dir \"%s\"",
                $runcom, $comainu_home, $comainu_opts_str, $comainu_method,
                $comainu_long_model, $comainu_mid_model, $comainu_bnst_model,
                $comainu_test, $tmp_dir
            );
        } elsif($comainu_method =~ /(bccwjlong|kclong)2midout/) {
            # Mid Analysis
            sprintf(
                "\"%s\" \"%s/script/comainu.pl\" %s \"%s\" --muwmodel \"%s\" --input \"%s\" --output-dir \"%s\"",
                $runcom, $comainu_home, $comainu_opts_str, $comainu_method,
                $comainu_mid_model, $comainu_test, $tmp_dir
            );
        } else {
            sprintf(
                "\"%s\" \"%s/script/comainu.pl\" %s \"%s\" --luwmodel \"%s\" --input \"%s\" --output-dir \"%s\"",
                $runcom, $comainu_home, $comainu_opts_str, $comainu_method,
                $comainu_long_model, $comainu_test, $tmp_dir
            );
        }
    };

    $comainu_com =~ s/\\/\//sg;
    while ($comainu_com =~ s/\/[^\/]+\/\.\.//sg) { ; }

    $comainu_com =~ s/\//\\/sg if $Config{"osname"} eq "MSWin32";
    if ($self->_data->{debug} > 0) {
        printf(STDERR "# COMAINU_COM: %s\n", $comainu_com);
    }

    my $proc_end_flag = 0;
    my $com_worker = $self->_data->{_com_worker};
    $com_worker->system_nb($comainu_com);
    while ($com_worker->is_running()) {
        if (ref $progress_func) {
            $progress_func->();
        }
        &Time::HiRes::sleep(1.0);
    }
    my $out_data = "*** No result ***";
    eval {
        open(my $fh, $out_file);
        $out_data = join("", (<$fh>));
        close($fh);
    };
    $out_data = Encode::decode("utf-8", $out_data);
    return $out_data;
}


1;
__END__

