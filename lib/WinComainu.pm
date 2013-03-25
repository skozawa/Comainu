# -*- mode: perl; coding: utf-8 -*-

use strict;

package WinComainu;
use vars qw($VERSION $DoDebug);
$VERSION = '0.53';
$DoDebug = 0;

use Tk qw (Ev);
# use AutoLoader;

use AppBase;
use base qw(AppBase);

Construct Tk::Widget 'WinComainu';

use utf8;
use FindBin qw($Bin);
use Config;
use Encode;
use Encode::JP; # to avoid segmentation fault on Linux
use FileHandle;
STDERR->autoflush(1);
use File::Spec;
use File::Basename;
use Time::HiRes;
use Tk;
use Tk::Panedwindow;
use Tk::ProgressBar;
use Tk::BrowseEntry;
use Tk::DropSite;
use Tk::Table;

use TextUndo_patch;
use CommandWorker;
use ComainuGetPath;
use RunCom;

my $DEFAULT_VALUES = {
    "debug"            => 0,
    "perl"             => "perl",
    "app-name"         => "WinComainu",
    "app-version"      => $VERSION,
    "title"            => "",
    "copyright"        => "",
    "icon-file"        => "$Bin/../img/wincomainu.ico",
    "gif-file"         => "$Bin/../img/wincomainu.gif",
    "conf-file"        => "$Bin/../wincomainu.conf",
    "conf-org-file"    => "$Bin/../wincomainu_org.conf",
    "conf-geometry"    => "600x400",
    "msg-file"         => "$Bin/../msg/ja.txt",
    "help-file"        => "$Bin/../Readme.txt",
    "default-dirname"  => "",
    "in-pathname"      => "",
    "in-dirname"       => "",
    "in-filename"      => "",
    "out-pathname"     => "",
    "out-dirname"      => "",
    "out-filename"     => "",
    "comainu-input"    => "plain",
    "comainu-output"   => "longbnst",
    "comainu-model"    => "SVM",
    "comainu-tagger"   => "mecab",
    "comainu-boundary" => "sentence",
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
            ["comainu-crf-train", "string", {"-list" => ["train.KC"]}],
            ["comainu-crf-model", "pathname"],
            ["comainu-svm-train", "string", {"-list" => ["train.KC"]}],
            ["comainu-svm-model", "pathname"],
            ["comainu-svm-bnst-model", "pathname"],
            ["comainu-svm-bip-model", "dirname"],
            ["comainu-mst-model", "pathname"],
            # ["comainu-boundary", "string"],
        ],
    },
    {
        "name" => "STR_TOOLS",
        "options" => [
            ["chasen-dir", "dirname"],
            ["mecab-dir", "dirname"],
            ["unidic-dir", "dirname"],
            ["unidic2-dir", "dirname"],
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
            # ["in-wrap", "string"],
            # ["in-readonly", "string"],
            # ["in-table-disp", "string"],
            # ["out-wrap", "string"],
            # ["out-readonly", "string"],
            # ["out-table-disp", "string"],
        ],
    },
];

sub ClassInit {
    my ($class,$mw) = @_;

    return $class->SUPER::ClassInit($mw);
}

sub InitObject {
    my ($self, $args) = @_;
    my $opts = {
        %$DEFAULT_VALUES,
        "configuration-view"=>$CONFIGURATION_VIEW
    };
    # $self->{"opts"} = $opts;
    %$self = (%$opts, %$self);
    my $parent = $self->parent();
    my $toplevel = $self->toplevel();
    if ($parent == $toplevel) {
        $toplevel->withdraw();
        $toplevel->geometry("800x600");
    }
    $self->SUPER::InitObject($args);

    # CommandWorker should be set up at first.
    my $com_worker = CommandWorker->new();
    $self->{"_com_worker"} = $com_worker;

    my $cgp = ComainuGetPath->new();
    my $app_conf = $self->get_app_conf();
    my $yamcha_dir = $app_conf->get("yamcha-dir");
    if ($yamcha_dir eq "") {
        $yamcha_dir = $cgp->get_yamcha_dir_auto();
        $app_conf->set("yamcha-dir", $yamcha_dir);
    }
    my $chasen_dir = $app_conf->get("chasen-dir");
    if ($chasen_dir eq "") {
        $chasen_dir = $cgp->get_chasen_dir_auto();
        $app_conf->set("chasen-dir", $chasen_dir);
    }
    my $mecab_dir = $app_conf->get("mecab-dir");
    if ($mecab_dir eq "") {
        $mecab_dir = $cgp->get_mecab_dir_auto();
        $app_conf->set("mecab-dir", $mecab_dir);
    }
    my $unidic_dir = $app_conf->get("unidic-dir");
    if ($unidic_dir eq "") {
        $unidic_dir = $cgp->get_unidic_dir_auto();
        $app_conf->set("unidic-dir", $unidic_dir);
    }
    my $unidic2_dir = $app_conf->get("unidic2-dir");
    if ($unidic2_dir eq "") {
        $unidic2_dir = $cgp->get_unidic2_dir_auto();
        $app_conf->set("unidic2-dir", $unidic2_dir);
    }
    my $unidic_db = $app_conf->get("unidic-db");
    if ($unidic_db eq "") {
        $unidic_db = $cgp->get_unidic_db_auto();
        $app_conf->set("unidic-db", $unidic_db);
    }

    my $dummy_text_undo = $self->TextUndo_patch(); # for rebinding
    # skip key binding on TextUndo_patch
    $self->bind("TextUndo_patch", "<Control-Key-o>", sub { return; });
    $self->bind("TextUndo_patch", "<Control-Key-s>", sub { return; });
    $self->bind("TextUndo_patch", "<Control-Key-q>", sub { return; });
    # rebind selectAll
    $self->bind("TextUndo_patch", "<Control-Key-a>", $self->bind("TextUndo_patch", "<Control-Key-slash>"));
    # rebind <<Undo>> and <<Redo>>
    $self->bind("TextUndo_patch", "<Control-Key-slash>", $self->bind("TextUndo_patch", "<<Undo>>"));
    $self->bind("TextUndo_patch", "<Control-Key-y>", $self->bind("TextUndo_patch", "<<Redo>>"));

    if ($parent == $toplevel) {
        $toplevel->update();
        $toplevel->deiconify();
    }
    return $self;
}

sub cmd_exit {
    my $self = shift;
    my $cancel = $self->SUPER::cmd_exit();
    if ($cancel == 0) {
        eval {
            if ($self->{"_com_worker"}) {
                $self->{"_com_worker"}->DESTROY();
                $self->{"_com_worker"} = undef;
            }
        };
        if ($@) {
            warn $@;
        }
    }
}

sub init {
    my $self = shift;
    $self->make_menubar();
    $self->make_toolbar();
    $self->make_mainframe();
}

sub make_menubar {
    my $self = shift;
    my $top = $self->toplevel();
    my $mb_fr = $self->{"menubar"};
    my $mb_bts = $mb_fr->{"bts"};
    my $mc;
    my $lbl_str = "";
    my $app_conf = $self->get_app_conf();
    my $curr_font_family = $app_conf->get("font-family");
    my $curr_font_size = $app_conf->get("font-size");
    my $curr_font_style = $app_conf->get("font-style");
    my $cand_families = [];
    if ($self->windowingsystem() eq "win32") {
        $cand_families = [$curr_font_family, "Meiryo UI", "MS UI Gothic"];
    } else {
        $cand_families = [$curr_font_family, "gothic", "fixed"];
    }
    my $def_families = [$self->fontFamilies];
    @$FONT_FAMILY_LIST = @$def_families;
    if ($self->{"debug"} > 0) {
        printf(STDERR "# FONT_FAMILIES=%s\n", Encode::encode("utf-8", join(", ", @$def_families)));
    }
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
    if (defined($font_family)) {
        if ($self->{"debug"} > 0) {
            printf(STDERR "USE_FONT_FAMILY=%s\n", Encode::encode("utf-8", $font_family));
        }
        $app_conf->set("font-family", $font_family);
        $curr_font_family = $font_family;
    }
    $self->optionAdd('*font' => [$curr_font_family, $curr_font_size, $curr_font_style]);

    # File
    $lbl_str = $self->{"msg"}{"MENU_STR_FILE"};
    my $mb = $mb_bts->Menubutton(-text=>$lbl_str, -underline=>1)->pack(-side=>"left");
    my $mc = $mb->Menu(-tearoff=>0);
    $mb->configure(-menu=>$mc);
    $lbl_str = $self->{"msg"}{"MENU_STR_NEW"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Ctrl+N",
        -command=>sub { $self->cmd_new(); }
    );
    $top->bind("<Control-Key-n>", sub { $self->cmd_new(); });
    $lbl_str = $self->{"msg"}{"MENU_STR_OPEN"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Ctrl+O",
        -command=>sub { $self->cmd_open(); }
    );
    $top->bind("<Control-Key-o>", sub { $self->cmd_open(); });
    $lbl_str = $self->{"msg"}{"MENU_STR_SAVE_AS"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Ctrl+S",
        -command=>sub { $self->cmd_save_as(); }
    );
    $top->bind("<Control-Key-s>", sub { $self->cmd_save_as(); });
    $lbl_str = $self->{"msg"}{"MENU_STR_CLOSE"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Ctrl+W",
        -command=>sub { $self->cmd_close(); }
    );
    $top->bind("<Control-Key-w>", sub { $self->cmd_close(); });
    $mc->separator();
    $lbl_str = $self->{"msg"}{"MENU_STR_EXIT"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Ctrl+Q",
        -command=>sub { $self->cmd_exit(); }
    );
    $top->bind("<Control-Key-q>", sub { $self->cmd_exit(); });

    # Edit
    $lbl_str = $self->{"msg"}{"MENU_STR_EDIT"};
    my $mb = $mb_bts->Menubutton(-text=>$lbl_str, -underline=>1)->pack(-side=>"left");
    my $mc = $mb->Menu(-tearoff=>0);
    $mb->configure(-menu=>$mc);
    $lbl_str = $self->{"msg"}{"MENU_STR_UNDO"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Ctrl+Z",
        -command=>sub { $self->eventGenerate("<Control-Key-z>"); }
    );
    $lbl_str = $self->{"msg"}{"MENU_STR_REDO"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Ctrl+Y",
        -command=>sub { $self->eventGenerate("<Control-Key-y>"); }
    );
    $mc->separator();
    $lbl_str = $self->{"msg"}{"MENU_STR_CUT"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Ctrl+X",
        -command=>sub { $self->eventGenerate("<Control-Key-x>"); }
    );
    $lbl_str = $self->{"msg"}{"MENU_STR_COPY"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Ctrl+C",
        -command=>sub { $self->eventGenerate("<Control-Key-c>"); }
    );
    $lbl_str = $self->{"msg"}{"MENU_STR_PASTE"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Ctrl+V",
        -command=>sub { $self->eventGenerate("<Control-Key-v>"); }
    );
    $mc->separator();
    $lbl_str = $self->{"msg"}{"MENU_STR_SELECT_ALL"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Ctrl+A",
        -command=>sub { $self->eventGenerate("<Control-Key-a>"); }
    );

    # Tool
    $lbl_str = $self->{"msg"}{"MENU_STR_TOOL"};
    my $mb = $mb_bts->Menubutton(-text=>$lbl_str, -underline=>1)->pack(-side=>"left");
    my $mc = $mb->Menu(-tearoff=>0);
    $mb->configure(-menu=>$mc);
    $lbl_str = $self->{"msg"}{"MENU_STR_COMAINU_INPUT"};
    $self->init_comainu_type("input-type");
    $self->make_comainu_type_cascade("input-type", $mc, -label=>$lbl_str);
    $lbl_str = $self->{"msg"}{"MENU_STR_COMAINU_OUTPUT"};
    $self->init_comainu_type("output-type");
    $self->make_comainu_type_cascade("output-type", $mc, -label=>$lbl_str);
    $lbl_str = $self->{"msg"}{"MENU_STR_COMAINU_MODEL"};
    $self->init_comainu_type("model-type");
    $self->make_comainu_type_cascade("model-type", $mc, -label=>$lbl_str);
    $lbl_str = $self->{"msg"}{"MENU_STR_COMAINU_TAGGER"};
    $self->init_comainu_type("tagger-type");
    $self->make_comainu_type_cascade("tagger-type", $mc, -label=>$lbl_str);
    $lbl_str = $self->{"msg"}{"MENU_STR_COMAINU_BOUNDARY"};
    $self->init_comainu_type("boundary-type");
    $self->make_comainu_type_cascade("boundary-type", $mc, -label=>$lbl_str);
    $lbl_str = $self->{"msg"}{"MENU_STR_ANALYSIS"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Alt+A",
        -command=>sub { $self->cmd_analysis(); }
    );
    $top->bind("<Alt-Key-a>", sub { $self->cmd_analysis(); });
    $lbl_str = $self->{"msg"}{"MENU_STR_BATCH_ANALYSIS"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Alt+B",
        -command=>sub { $self->cmd_batch_analysis(); }
    );
    $top->bind("<Alt-Key-b>", sub { $self->cmd_batch_analysis(); });
    $lbl_str = $self->{"msg"}{"MENU_STR_CLEAR_INPUT"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Alt+C",
        -command=>sub { $self->cmd_clear_input(); }
    );
    $top->bind("<Alt-Key-c>", sub { $self->cmd_clear_input(); });
    $lbl_str = $self->{"msg"}{"MENU_STR_CLEAR_CACHE"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Alt+D",
        -command=>sub { $self->cmd_clear_cache(); }
    );
    $top->bind("<Alt-Key-d>", sub { $self->cmd_clear_cache(); });
    $mc->separator();
    $lbl_str = $self->{"msg"}{"MENU_STR_CONFIGURATION"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"Alt+O",
        -command=>sub { $self->cmd_configuration(); }
    );
    $top->bind("<Alt-Key-o>", sub { $self->cmd_configuration(); });

    # Help
    $lbl_str = $self->{"msg"}{"MENU_STR_HELP"};
    my $mb = $mb_bts->Menubutton(-text=>$lbl_str, -underline=>1)->pack(-side=>"left");
    my $mc = $mb->Menu(-tearoff=>0);
    $mb->configure(-menu=>$mc);
    $lbl_str = $self->{"msg"}{"MENU_STR_HELP"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -accelerator=>"F1",
        -command=>sub { $self->cmd_show_help(); }
    );
    $top->bind("<F1>", sub { $self->cmd_show_help(); });
    $mc->separator();
    $lbl_str = $self->{"msg"}{"MENU_STR_ABOUT"};
    $mc->command(
        -label=>$lbl_str,
        -underline=>1,
        -command=>sub { $self->cmd_show_about(); }
    );

    return;
}

sub make_toolbar {
    my $self = shift;
    my $top = $self->toplevel();
    my $app_conf = $self->get_app_conf();
    my $tb_fr = $self->{"toolbar"};
    my $tb_bts = $tb_fr->{"bts"};
    my $f = $tb_bts->Frame();
    $f->pack(-side=>"top", -anchor=>"nw");
    my $lbl_str = $self->{"msg"}{"STR_COMAINU_INPUT"};
    my $be = $self->make_comainu_type_selector(
        "input-type",
        $f,
        -label=>$lbl_str,
        -width=>16
    );
    $be->pack(-side=>"left");
    my $lbl_str = $self->{"msg"}{"STR_COMAINU_OUTPUT"};
    my $be = $self->make_comainu_type_selector(
        "output-type",
        $f,
        -label=>$lbl_str,
        -width=>16
    );
    $be->pack(-side=>"left");
    my $lbl_str = $self->{"msg"}{"STR_COMAINU_MODEL"};
    my $be = $self->make_comainu_type_selector(
        "model-type",
        $f,
        -label=>$lbl_str,
        -width=>4
    );
    $be->pack(-side=>"left");
    my $lbl_str = $self->{"msg"}{"STR_COMAINU_TAGGER"};
    my $be = $self->make_comainu_type_selector(
        "tagger-type",
        $f,
        -label=>$lbl_str,
        -width=>8
    );
    $be->pack(-side=>"left");
    my $lbl_str = $self->{"msg"}{"STR_COMAINU_BOUNDARY"};
    my $be = $self->make_comainu_type_selector(
        "boundary-type",
        $f,
        -label=>$lbl_str,
        -width=>4
    );
    $be->pack(-side=>"left");

    my $f = $tb_bts->Frame();
    $f->pack(-side=>"top", -anchor=>"nw");
    my $lbl_str = $self->{"msg"}{"BT_STR_ANALYSIS"};
    my $b = $f->Button(
        -text=>$lbl_str,
        -command=>sub { $self->cmd_analysis(); }
    );
    $b->pack(-side=>"left", -anchor=>"w");
    $self->{"_analysis_button"} = $b;
    my $lbl_str = $self->{"msg"}{"BT_STR_BATCH_ANALYSIS"};
    my $b = $f->Button(
        -text=>$lbl_str,
        -command=>sub { $self->cmd_batch_analysis(); }
    );
    $b->pack(-side=>"left", -anchor=>"w");
    $self->{"_batch_analysis_button"} = $b;
    $lbl_str = $self->{"msg"}{"BT_STR_CLEAR_INPUT"};
    $b = $f->Button(
        -text=>$lbl_str,
        -command=>sub { $self->cmd_clear_input(); }
    );
    $b->pack(-side=>"left");
    $self->{"_clear_input_button"} = $b;
    $lbl_str = $self->{"msg"}{"BT_STR_CLEAR_CACHE"};
    $b = $f->Button(
        -text=>$lbl_str,
        -command=>sub { $self->cmd_clear_cache(); }
    );
    $b->pack(-side=>"left");
    $self->{"_clear_cache_button"} = $b;
}

sub make_mainframe {
    my $self = shift;
    my $top = $self->toplevel();
    my $app_conf = $self->get_app_conf();
    my $mf = $self->{"mainframe"};
    my ($f, $b, $e, $c);

    # Paned frame
    my $pw = $mf->Panedwindow(-orient=>"vertical");
    $pw->pack(-side=>"top", -fill=>"both", -expand=>"yes");

    # Input pane
    # my $f_in = $mf->Frame(-bg=>"#ffffff");
    # $f_in->pack(-side=>"top", -fill=>"both", -expand=>"yes");
    my $f_in = $pw->Frame(-bg=>"#ffffff");
    $pw->add($f_in, -minsize => 100, -height => 200);
    $f = $f_in->Frame();
    $f->pack(-side=>"top", -fill=>"x");
    my $lbl_str;
    $lbl_str = $self->{"msg"}{"STR_INPUT"};
    $f->Label(-text=>$lbl_str)->pack(-side=>"left", -fill=>"x", -anchor=>"w");
    $lbl_str = $self->{"msg"}{"BT_STR_OPEN"};
    $b = $f->Button(
        -text=>$lbl_str,
        -command=>sub { $self->cmd_open(); }
    );
    $b->pack(-side=>"left");
    $e = $f->Entry(
        -textvariable=>\$self->{"in-pathname"},
        -state=>"readonly"
    );
    $e->pack(-side=>"left", -fill=>"x", -expand=>"yes", -anchor=>"w");
    $c = $f->Checkbutton(
        -text=>$self->{"msg"}{"BT_STR_WRAP"},
        -onvalue=>"word",
        -offvalue=>"none",
        -variable=>$app_conf->get_ref("in-wrap"),
        -command=>sub {
            $self->{"in_text"}->configure(-wrap=>$app_conf->get("in-wrap"));
        }
    );
    $c->pack(-side=>"left");
    $c = $f->Checkbutton(
        -text=>$self->{"msg"}{"BT_STR_READONLY"},
        -onvalue=>"1",
        -offvalue=>"0",
        -variable=>$app_conf->get_ref("in-readonly"),
        -command=>sub {
            my $state = $app_conf->get("in-readonly") ? "disabled" : "normal";
            $self->{"in_text"}->configure(-state=>$state);
            $self->change_state_table($self->{"in_table"}, $state);
        }
    );
    $c->pack(-side=>"left");
    $c = $f->Checkbutton(
        -text=>$self->{"msg"}{"BT_STR_TABLE_DISP"},
        -onvalue=>"1",
        -offvalue=>"0",
        -variable=>$app_conf->get_ref("in-table-disp"),
        -command=>sub {
            my $in_text = $self->{"in_text"};
            my $in_table = $self->{"in_table"};
            my $table_disp = $app_conf->get("in-table-disp");
            my $readonly = $app_conf->get("in-readonly");
            $self->change_table_disp($in_text, $in_table,
                                     $table_disp, $readonly);
        }
    );
    $c->pack(-side=>"left");
    my $in_text = $f_in->Scrolled(
        "TextUndo_patch",
        -scrollbars=>"se",
        -height=>10,
        -bg=>"#ffffff",
        -wrap=>$app_conf->get("in-wrap")
    );
    my $in_table = $f_in->Table(
        -scrollbars=>"se",
        -rows => 1,
        -columns => 1,
        -fixedrows => 0,
        -fixedcolumns => 0,
        -height => 200,
        -takefocus => "yes",
        -bg => "#ffffff",
    );
    $f_in->DropSite(
        -droptypes=>$self->get_droptypes(),
        -dropcommand=>sub {
            my ($selection) = @_;
            my $w = $f_in;
            my $pathname = $self->get_selection($w, $selection);
            if ($pathname) {
                $pathname =~ s/\\/\//g;
                $pathname = $self->decode_pathname($pathname);
                $self->cmd_open($pathname);
            }
        }
    );
    my $state = $app_conf->get("in-readonly") ? "disabled" : "normal";
    $in_text->configure(-state=>$state);
    $in_text->bind("<Button>", sub { $in_text->focus(); });
    $in_text->bind("<Control-Key-f>", sub { $in_text->FindPopUp(); });
    $in_text->bind("<Control-Key-h>", sub { $in_text->FindAndReplacePopUp(); });
    $self->{"in_text"} = $in_text;
    $self->{"in_table"} = $in_table;

    $self->bind_wheel($in_table, $in_table);

    if($app_conf->get("in-table-disp")) {
        $in_table->pack(-side=>"top", -fill=>"both", -expand=>"yes");
    } else {
        $in_text->pack(-side=>"top", -fill=>"both", -expand=>"yes");
    }

    # Output pane
    # my $f_out = $mf->Frame();
    # $f_out->pack(-side=>"top", -fill=>"both", -expand=>"yes");
    my $f_out = $pw->Frame();
    $pw->add($f_out, -minsize => 100);
    $f = $f_out->Frame();
    $f->pack(-side=>"top", -fill=>"x");
    $lbl_str = $self->{"msg"}{"STR_OUTPUT"};
    $f->Label(-text=>$lbl_str)->pack(-side=>"left", -anchor=>"w");
    $lbl_str = $self->{"msg"}{"BT_STR_SAVE"};
    $b = $f->Button(
        -text=>$lbl_str,
        -command=>sub { $self->cmd_save_as(); }
    );
    $b->pack(-side=>"left");
    $e = $f->Entry(
        -textvariable=>\$self->{"out-pathname"},
        -state=>"readonly"
    );
    $e->pack(-side=>"left", -fill=>"x", -expand=>"yes", -anchor=>"w");
    $c = $f->Checkbutton(
        -text=>$self->{"msg"}{"BT_STR_WRAP"},
        -onvalue=>"word",
        -offvalue=>"none",
        -variable=>$app_conf->get_ref("out-wrap"),
        -command=>sub {
            $self->{"out_text"}->configure(-wrap=>$app_conf->get("out-wrap"));
        }
    );
    $c->pack(-side=>"left");
    $c = $f->Checkbutton(
        -text=>$self->{"msg"}{"BT_STR_READONLY"},
        -onvalue=>"1",
        -offvalue=>"0",
        -variable=>$app_conf->get_ref("out-readonly"),
        -command=>sub {
            my $state = $app_conf->get("out-readonly") ? "disabled" : "normal";
            $self->{"out_text"}->configure(-state=>$state);
            $self->change_state_table($self->{"out_table"}, $state);
        }
    );
    $c->pack(-side=>"left");
    $c = $f->Checkbutton(
        -text=>$self->{"msg"}{"BT_STR_TABLE_DISP"},
        -onvalue=>"1",
        -offvalue=>"0",
        -variable=>$app_conf->get_ref("out-table-disp"),
        -command=>sub {
            my $out_text = $self->{"out_text"};
            my $out_table = $self->{"out_table"};
            my $table_disp = $app_conf->get("out-table-disp");
            my $readonly = $app_conf->get("out-readonly");
            $self->change_table_disp($out_text, $out_table,
                                     $table_disp, $readonly);
        }
    );
    $c->pack(-side=>"left");
    my $out_text = $f_out->Scrolled(
        "TextUndo_patch",
        -scrollbars=>"se",
        -height=>10,
        -bg=>"#ffffff",
        -wrap=>$app_conf->get("out-wrap")
    );
    my $out_table = $f_out->Table(
        -scrollbars=>"se",
        -rows => 1,
        -columns => 1,
        -fixedrows => 0,
        -fixedcolumns => 0,
        -height => 200,
        -takefocus => "yes",
        -bg => "#ffffff",
    );
    my $state = $app_conf->get("out-readonly") ? "disabled" : "normal";
    $out_text->configure(-state=>$state);
    $out_text->bind("<Button>", sub { $out_text->focus(); });
    $out_text->bind("<Control-Key-f>", sub { $out_text->FindPopUp(); });
    $out_text->bind("<Control-Key-h>", sub { $out_text->FindAndReplacePopUp(); });
    $self->{"out_text"} = $out_text;
    $self->{"out_table"} = $out_table;

    $self->bind_wheel($out_table, $out_table);

    if ($app_conf->get("out-table-disp")) {
        $out_table->pack(-side=>"top", -fill=>"both", -expand=>"yes");
    } else {
        $out_text->pack(-side=>"top", -fill=>"both", -expand=>"yes");
    }
}

sub bind_wheel {
    my $self = shift;
    my ($w, $table) = @_;
    $w->bind("<Button>", sub { $w->focus(); });
    if($Config{"osname"} eq "MSWin32") {
        $w->bind(
            "<MouseWheel>",
            sub {
                my $delta = $Tk::event->D();
                # %D := -120|+120 on MS-Windows
                $table->yview("scroll", (-$delta/120) * 1, "units");
            }
        );
    } else {
        $w->bind(
            "<Button-4>",
            sub { $table->yview("scroll", -1, "units"); }
        );
        $w->bind(
            "<Button-5>",
            sub { $table->yview("scroll", +1, "units"); }
        );
    }
}

sub get_comainu_type_list {
    my $self = shift;
    my ($type) = @_;
    if ($type eq "input-type") {
        return ["plain", "bccwj", "bccwjlong", "kc", "kclong"];
    }
    if ($type eq "output-type") {
        my $input_type = $self->get_comainu_type_by_name("input-type", $self->{"_comainu_input_name"});
        if ($input_type =~ /^bccwjlong|kclong$/) {
            return ["mid"];
        }
        return ["bnst", "long_only_boundary", "long", "longbnst", "mid", "midbnst"];
    }
    if ($type eq "model-type") {
        return ["svm", "crf"];
    }
    if ($type eq "tagger-type") {
        return ["mecab", "chasen"];
    }
    if ($type eq "boundary-type") {
        return ["sentence", "word"];
    }
}

sub get_comainu_type_name_list {
    my $self = shift;
    my ($type) = @_;
    my $type_list = $self->get_comainu_type_list($type);
    my $type_name_list = [];
    foreach my $type (@$type_list) {
        my $type_name = $self->{"msg"}{"STR_".uc($type)};
        push(@$type_name_list, $type_name);
    }
    return $type_name_list;
}

sub get_comainu_type_by_name {
    my $self = shift;
    my ($type, $type_name) = @_;
    my $res_type;
    my $type_list = $self->get_comainu_type_list($type);
    my $type_name_list = $self->get_comainu_type_name_list($type);
    for (my $i = 0; $i < scalar(@$type_list); ++$i) {
        my $tmp_type = $type_list->[$i];
        my $tmp_type_name = $type_name_list->[$i];
        if ($tmp_type_name eq $type_name) {
            $res_type = $tmp_type;
            last;
        }
    }
    return $res_type;
}

sub init_comainu_type {
    my $self = shift;
    my ($type) = @_;
    if (!exists($self->{"_comainu_".$type."_name"}) or
            !exists($self->{"_comainu_".$type})) {
        my $app_conf = $self->get_app_conf();
        my $type_list = $self->get_comainu_type_list($type);
        my $type_name_list = $self->get_comainu_type_name_list($type);
        for (my $i = 0; $i < scalar(@$type_list); ++$i) {
            my $type_tmp = $type_list->[$i];
            my $type_name = $type_name_list->[$i];
            if ($app_conf->get("comainu-".$type) eq $type_tmp) {
                $self->{"_comainu_".$type."_name"} = $type_name;
            }
        }
        $self->{"_comainu_".$type."_name_list"} = $type_name_list;
    }
}

sub make_comainu_type_cascade {
    my $self = shift;
    my ($type, $mc, %opts) = @_;
    my $label = $opts{"-label"};
    my $m;                              # for closure of postcommand
    $m = $mc->Menu(
        -tearoff=>0,
        -postcommand=>sub {
            $m->delete(0, "end");
            foreach my $type_name (@{$self->get_comainu_type_name_list($type)}) {
                $m->radiobutton(
                    -label=>$type_name,
                    -variable=>\$self->{"_comainu_".$type."_name"},
                    -command=>sub {
                        my $type_tmp = $self->get_comainu_type_by_name(
                            $type,
                            $self->{"_comainu_type_name"}
                        );
                        my $app_conf = $self->get_app_conf();
                        $app_conf->set("comainu-".$type, $type_tmp);
                        $self->check_comainu_limitation($type);
                    }
                );
            }
        }
    );
    $mc->cascade(-underline=>1, -menu=>$m, %opts);
}

sub make_comainu_type_selector {
    my $self = shift;
    my ($type, $f, %opts) = @_;
    my $app_conf = $self->get_app_conf();
    my $type_list = $self->get_comainu_type_list($type);
    my $type_name_list = $self->get_comainu_type_name_list($type);
    $self->init_comainu_type($type);
    my $be = $f->BrowseEntry(
        -width=>"-1",
        -autolimitheight=>"yes",
        -autolistwidth=>"yes",
        -state=>"readonly",
        -variable=>\$self->{"_comainu_".$type."_name"},
        -listcmd=>sub {
            my ($be) = @_;
            my $curr_type_name_list = $self->get_comainu_type_name_list($type);
				 $be->delete(0, "end");
            map {$be->insert("end", $_);} @$curr_type_name_list;
        },
        -browse2cmd=>sub {
            my ($be, $index) = @_;
            $app_conf->set("comainu-".$type, $type_list->[$index]);
            # print $app_conf->get("comainu-".$type)."\n";
            $self->check_comainu_limitation($type);
        },
        %opts
    );
    $be->Subwidget("entry")->configure(
        -state=>"readonly",
        -readonlybackground=>"#ffffff",
    );
    my $select_type_by_key = sub {
        my ($d) = @_;
        my $e = $be->Subwidget("entry");
        for (my $i = 0; $i < scalar(@$type_name_list); ++$i) {
            my $type_name = $type_name_list->[$i];
            if ($type_name eq $e->get()) {
                my $index = $i + $d;
                if ($index < 0) {
                    $index += scalar(@$type_name_list);
                }
                if ($index >= scalar(@$type_name_list)) {
                    $index -= scalar(@$type_name_list);
                }
                my $next_type_name = $type_name_list->[$index];
                $self->{"_comainu_".$type."_name"} = $type_name_list->[$index];
                $e->selectionRange(0, "end");
                $app_conf->set("comainu-".$type, $type_list->[$index]);
                # print $app_conf->get("comainu-".$type)."\n";
                last;
            }
        }
    };
    $be->bind("<Key-Up>",   sub { $select_type_by_key->(-1); });
    $be->bind("<Key-Down>", sub { $select_type_by_key->(+1); });
    return $be;
}

sub check_comainu_limitation {
    my $self = shift;
    my ($type) = @_;
    if ($type eq "input-type") {
        my $input_type = $self->get_comainu_type_by_name("input-type", $self->{"_comainu_input_name"});
        if ($input_type =~ /^bccwjlong|kclong$/) {
            my $output_type_name = $self->{"_comainu_output_name"};
            my $output_type = $self->get_comainu_type_by_name("output-type", $output_type_name);
            my $output_type_name_list = $self->get_comainu_type_name_list("output-type");
            my $found = 0;
            foreach my $tmp_output_type_name (@$output_type_name_list) {
                if ($output_type_name eq $tmp_output_type_name) {
                    $found = 1;
                    last;
                }
            }
            if ($found == 0) {
                $output_type_name = $output_type_name_list->[0];
                $self->{"_comainu_output_name"} = $output_type_name;
                my $app_conf = $self->get_app_conf();
                $output_type = $self->get_comainu_type_by_name("output-type", $output_type_name);
                $app_conf->set("comainu-output", $output_type);
                # print $app_conf->get("comainu-output")."\n";
            }
        }
    }
}

sub cmd_open {
    my $self = shift;
    my ($in_file) = @_;
    my $app_conf = $self->get_app_conf();
    my $comainu_input_type = $app_conf->get("comainu-input-type");
    my $dirname = $app_conf->get("in-dirname");
    my $filename = $app_conf->get("in-filename");
    my $pathname;
    if (defined($in_file) and $in_file ne "") {
        if (-f $self->encode_pathname($in_file)) {
            $pathname = $in_file;
        } else {
            $dirname = $in_file;
            $filename = "";
        }
    }
    if (!defined($pathname)) {
        my $filetypes = [];
        if ($comainu_input_type =~ /kc/) {
            $filetypes = [['KC', ['*.KC']], ['Text', ['*.txt']]];
        } else {
            $filetypes = [['Text', ['*.txt']], ['KC', ['*.KC']]];
        }
        push(@$filetypes, ['All Files', ['*.*']]);
        $pathname = $self->getOpenFile(
            -filetypes=>$filetypes,
            -initialdir=>$dirname,
            -initialfile=>$filename,
            -parent=>$self->toplevel(),
        );
    }
    if($pathname) {
        $dirname = File::Basename::dirname($pathname);
        $filename = File::Basename::basename($pathname);
        $pathname = $dirname."/".$filename;
        $self->{"in-pathname"} = $pathname;
        $app_conf->set("in-dirname", $dirname);
        $app_conf->set("in-filename", $filename);
        my $pathname_enc = $self->encode_pathname($pathname);
        if (open(my $fh, $pathname_enc)) {
            my $data = join("", (<$fh>));
            close($fh);
            $data =~ s/\r\n/\n/sg;
            $data = Encode::decode("utf-8", $data);
            $self->cmd_clear_input();
            my $in_table_disp = $app_conf->get("in-table-disp");
            if ($in_table_disp) {
                $self->put_table($self->{"in_table"}, $data,
                                 $app_conf->get("in-readonly"));
            } else {
                $self->put_text($self->{"in_text"}, $data);
            }
            $self->{"in-pathname"} = $pathname;
        }
    }
    if (defined($in_file) and $in_file ne "") {
        return;
    }
    my $top = $self->toplevel();
    $top->raise();
    return Tk::break();
}

sub cmd_save_as {
    my $self = shift;
    my ($out_file) = @_;
    my $app_conf = $self->get_app_conf();
    my $comainu_output_type = $app_conf->get("comainu-output-type");
    my $dirname = $app_conf->get("out-dirname");
    my $filename = $app_conf->get("out-filename");
    my $in_filename = $app_conf->get("in-filename");
    my $pathname;
    my $out_data = $self->get_text($self->{"out_text"});
    if ($app_conf->get("out-table-disp")) {
        $out_data = $self->get_table($self->{"out_table"});
    }
    if (defined($out_file) and $out_file ne "") {
        $pathname = $out_file;
    } else {
        if ($out_data !~ /^\s*$/s or
                $self->messageBox(
                    -message=>$self->{"msg"}{"MSG_STR_NULL_OUTPUT"},
                    -icon=>"warning",
                    -type=>"yesno", -default=>"no"
                ) =~ /yes/i) {
            my $filetypes = [];
            if ($comainu_output_type eq "long") {
                $filename = $in_filename . ".lout";
                $filetypes = [['Long', ['*.lout']], ['Text', ['*.txt']]];
            } elsif ($comainu_output_type eq "bnst") {
                $filename = $in_filename . ".bout";
                $filetypes = [['BNST', ['*.bout']], ['Text', ['*.txt']]];
            } elsif ($comainu_output_type eq "longbnst") {
                $filename = $in_filename . ".lbout";
                $filetypes = [['LongBNST', ['*.lbout']], ['Text', ['*.txt']]];
            } elsif ($comainu_output_type eq "mid") {
                $filename = $in_filename . ".mout";
                $filetypes = [['Mid', ['*.mout']], ['Text', ['*.txt']]];
            } elsif ($comainu_output_type eq "midbnst") {
                $filename = $in_filename . ".mbout";
                $filetypes = [['MidBNST', ['*.mbout']], ['Text', ['*.txt']]];
            } else {
                $filename = $in_filename . ".lout";
                $filetypes = [['Long', ['*.lout']], ['Text', ['*.txt']]];
            }
            push(@$filetypes, ['All Files', ['*.*']]);
            $pathname = $self->getSaveFile(
                -filetypes=>$filetypes,
                -initialdir=>$dirname,
                -initialfile=>$filename,
                -parent=>$self->toplevel(),
            );
        }
    }
    if ($pathname) {
        $dirname = File::Basename::dirname($pathname);
        $filename = File::Basename::basename($pathname);
        $pathname = $dirname."/".$filename;
        $self->{"out-pathname"} = $pathname;
        $app_conf->set("out-dirname", $dirname);
        $app_conf->set("out-filename", $filename);
        my $pathname_enc = $self->encode_pathname($pathname);
        if (open(my $fh, ">", $pathname_enc)) {
            $out_data = Encode::encode("utf-8", $out_data);
            printf($fh "%s", $out_data);
            close($fh);
        }
    }
    if (defined($out_file) and $out_file ne "") {
        return;
    }
    my $top = $self->toplevel();
    $top->raise();
    return Tk::break();
}

sub cmd_analysis {
    my $self = shift;
    my ($cont_flag, $progress_func) = @_;
    my $app_conf = $self->get_app_conf();
    my $in_data = "";
    my $in_table_disp = $app_conf->get("in-table-disp");
    if ($in_table_disp) {
        $in_data = $self->get_table($self->{"in_table"});
    } else {
        $in_data = $self->get_text($self->{"in_text"});
    }
    if ($in_data !~ /^\s*$/s) {
        if ($in_table_disp) {
            $self->put_table($self->{"out_table"}, "",
                             $app_conf->get("out-readonly"));
        } else {
            $self->put_text($self->{"out_text"}, "");
        }
        $self->enable_analysis_buttons(0);
        my $res_data = $self->execute_analysis_data($in_data, $progress_func);
        my $out_table_disp = $app_conf->get("out-table-disp");
        if ($out_table_disp) {
            $self->put_table($self->{"out_table"}, $res_data,
                             $app_conf->get("out-readonly"));
        } else {
            $self->put_text($self->{"out_text"}, $res_data);
        }
        $self->enable_analysis_buttons(1);
    } elsif (!$cont_flag) {
        $self->messageBox(-message=>$self->{"msg"}{"MSG_STR_NULL_INPUT"},
                          -icon=>"warning", -type=>"ok");
    }
    if ($cont_flag) {
        return;
    }
    my $top = $self->toplevel();
    $top->raise();
    return Tk::break();
}

sub cmd_batch_analysis {
    my $self = shift;
    my $app_conf = $self->get_app_conf();
    my $in_dirname = $app_conf->get("in-dirname");
    my $out_dirname = $app_conf->get("out-dirname");
    my $progress = 0;
    my $total = 0;
    my $count = 0;
    my $run_flag = 0;

    my $title = "Batch analysis";
    my $top = $self->Toplevel(-title=>$title);
    $top->withdraw();
    $top->update();
    if (exists($self->{"img"})) {
        $top->iconimage($self->{"img"});
    }
    $top->grab();

    my $func_execute_batch_analysis = sub {
        my ($self, $in_dirname, $out_dirname, $run_flag_ref, $total_ref, $count_ref, $progress_ref) = @_;
        my $app_conf = $self->get_app_conf();
        my $comainu_input_type = $app_conf->get("comainu-input-type");
        my $comainu_output_type = $app_conf->get("comainu-output-type");
        $comainu_output_type =~ s/_only_boundary//;
        my $in_file_list = [];
        my $out_file_list = [];
        eval {
            my $in_dirname_enc = $self->encode_pathname($in_dirname);
            opendir(my $dh, $in_dirname_enc);
            foreach my $filename (readdir($dh)) {
                my $in_pathname = undef;
                $filename = $self->decode_pathname($filename);
                if ($filename =~ /^\./) {
                    next;
                }
                if ($comainu_input_type eq "kc") {
                    if ($filename =~ /\.KC$/) {
                        $in_pathname = $in_dirname."/".$filename;
                        push(@$in_file_list, $in_pathname);
                        $filename =~ s/\.KC$//;
                    }
                } else {
                    if ($filename =~ /\.txt$/) {
                        $in_pathname = $in_dirname."/".$filename;
                        push(@$in_file_list, $in_pathname);
                    }
                }
                if (defined($in_pathname)) {
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
                    push(@$out_file_list, $out_pathname);
                }
            }
            closedir($dh);
        };
        my $total = scalar(@$in_file_list);
        $$total_ref = $total;
        if ($$run_flag_ref == 0) {
            $$run_flag_ref = 1;
            if ($$count_ref == $$total_ref) {
                my $message = $self->{"msg"}{"MSG_FINISHED_BATCH"};
                my $res = $top->messageBox(-message=>$message,
                                           -icon=>"warning",
                                           -type=>"yesno", -default=>"no");
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
        if (!-d $out_dirname) {
            mkdir($out_dirname);
        }
        while ($$run_flag_ref == 1 and $$count_ref < $total) {
            my $in_file = $in_file_list->[$$count_ref];
            my $out_file = $out_file_list->[$$count_ref];
            ++$$count_ref;
            $$progress_ref = 100 * ($$count_ref - 1 + 0.01) / $total;
            my $next_progress = 100 * $$count_ref / $total;
            $self->update();
            my $progress_func = sub {
                my $delta = ($next_progress - $$progress_ref) / 2.0;
                if ($delta > 1) {
                    $delta = 1;
                }
                $$progress_ref += $delta;
                $self->update();
            };
            # $self->execute_analysis_file($in_file, $out_file);
            $self->execute_analysis_file_on_gui($in_file, $out_file, $top,
                                                $progress_func);
            $$progress_ref = 100 * $$count_ref / $total;
            $self->update();
        }
        $$run_flag_ref = 0;
    };
    my $func_reset = sub {
        $count = 0;
        $progress = 0;
        $run_flag = 1;
        $func_execute_batch_analysis->($self, $in_dirname, $out_dirname, \$run_flag, \$total, \$count, \$progress);
    };
    my $func_close = sub {
        my ($self, $in_dirname, $out_dirname, $top, $run_flag_ref) = @_;
        $$run_flag_ref = 0;
        $app_conf->set("in-dirname", $in_dirname);
        $app_conf->set("out-dirname", $out_dirname);
        $top->parent()->focus();
        $top->destroy();
    };

    my ($f, $l, $ei, $eo, $p, $e, $b);

    # for frame
    my $mf = $top->Frame();
    $mf->pack(-side=>"top", -fill=>"x", -expand=>"yes");
    $mf->gridColumnconfigure(0, -weight=>0);
    $mf->gridColumnconfigure(1, -weight=>1);
    my $row = 0;

    # for selector
    $f = $mf->Frame();
    $f->grid(-row=>$row, -column=>0, -columnspan=>2, -sticky=>"w");
    {
        my $col = 0;
        my $lbl_str = 0;
        my $be;
        $lbl_str = $self->{"msg"}{"STR_COMAINU_INPUT"};
        $be = $self->make_comainu_type_selector(
            "input-type",
            $f,
            -label=>$lbl_str,
            -width=>16
        );
        $be->grid(-row=>$row, -column=>$col++, -sticky=>"w");
        $lbl_str = $self->{"msg"}{"STR_COMAINU_OUTPUT"};
        $be = $self->make_comainu_type_selector(
            "output-type",
            $f,
            -label=>$lbl_str,
            -width=>16
        );
        $be->grid(-row=>$row, -column=>$col++, -sticky=>"w");
        $lbl_str = $self->{"msg"}{"STR_COMAINU_MODEL"};
        $be = $self->make_comainu_type_selector(
            "model-type",
            $f,
            -label=>$lbl_str,
            -width=>4
        );
        $be->grid(-row=>$row, -column=>$col++, -sticky=>"w");
        $lbl_str = $self->{"msg"}{"STR_COMAINU_TAGGER"};
        $be = $self->make_comainu_type_selector(
            "tagger-type",
            $f,
            -label=>$lbl_str,
            -width=>8
        );
        $be->grid(-row=>$row, -column=>$col++, -sticky=>"w");
        $lbl_str = $self->{"msg"}{"STR_COMAINU_BOUNDARY"};
        $be = $self->make_comainu_type_selector(
            "boundary-type",
            $f,
            -label=>$lbl_str,
            -width=>4
        );
        $be->grid(-row=>$row, -column=>$col++, -sticky=>"w");
    }
    ++$row;

    # for input
    $l = $mf->Label(-text=>$self->{"msg"}{"STR_INPUT_DIR"});
    $l->grid(-row=>$row, -column=>0, -sticky=>"e");
    $f = $mf->Frame();
    $f->grid(-row=>$row, -column=>1, -sticky=>"ew");
    $ei = $self->make_pathname_entry(
        $f,
        -textvariable=>\$in_dirname,
        -pathnametype=>"dirname"
    );
    ++$row;

    # for output
    $l = $mf->Label(-text=>$self->{"msg"}{"STR_OUTPUT_DIR"});
    $l->grid(-row=>$row, -column=>0, -sticky=>"e");
    $f = $mf->Frame();
    $f->grid(-row=>$row, -column=>1, -sticky=>"ew");
    $eo = $self->make_pathname_entry(
        $f,
        -textvariable=>\$out_dirname,
        -pathnametype=>"dirname"
    );
    ++$row;

    # for progress bar
    $f = $top->Frame();
    $f->pack(-side=>"top", -fill=>"x");
    $l = $f->Label(-text=>$self->{"msg"}{"STR_PROGRESS"});
    $l->pack(-side=>"left");
    $l = $f->Label(-textvariable=>\$count, -width=>5);
    $l->pack(-side=>"left");
    $l = $f->Label(-text=>"/");
    $l->pack(-side=>"left");
    $l = $f->Label(-textvariable=>\$total, -width=>5);
    $l->pack(-side=>"left");
    my $colors = [];
    my $color_list = [
        '#ff7f7f', '#ffff7f', '#7fff7f',
        '#7fffff', '#7f7fff', '#ff7fff'
    ];
    my $color_list_len = scalar(@$color_list);
    for(my $i = 0; $i < $color_list_len - 1; ++$i) {
        for (my $j = 0; $j < 100 / ($color_list_len - 1); ++$j) {
            my $start_color = $color_list->[$i];
            my $end_color = $color_list->[$i + 1];
            my $c = $self->calc_color($start_color, $end_color,
                                      $j, 100 / ($color_list_len - 1));
            my $k = $j + $i * 100 / $color_list_len;
            push(@$colors, $k, $c);
        }
    }
    $colors = [0=>'#00ff00'];
    $p = $f->ProgressBar(
        -troughcolor=>"#ffffff",
        -colors=>$colors,
        -padx=>2, -pady=>2,
        -gap=>1,
        -border=>2,
        -width=>15, -length=>500,
        -from=>0, -to=>100,
        -blocks=>100,
        -variable=>\$progress,
    );
    $p->pack(
        -side=>"left", -padx=>5, -pady=>5,
        -fill=>"x", -expand=>"yes"
    );

    # for buttons
    $f = $top->Frame();
    $f->pack(-side=>"top");
    $b = $f->Button(
        -text=>$self->{"msg"}{"BT_STR_RESET"},
        -command=>sub { $func_reset->(); }
    );
    $b->pack(-side=>"left");
    $b = $f->Button(
        -text=>$self->{"msg"}{"BT_STR_EXECUTE_STOP"},
        -command=>sub {
			$func_execute_batch_analysis->($self, $in_dirname, $out_dirname, \$run_flag, \$total, \$count, \$progress);
        }
    );
    $b->pack(-side=>"left");
    $b->focus();
    $b = $f->Button(
        -text=>$self->{"msg"}{"BT_STR_CLOSE"},
        -command=>sub {
			$func_close->($self, $in_dirname, $out_dirname, $top, \$run_flag);
        }
    );
    $b->pack(-side=>"left");

    $top->bind(
        "<Control-Key-r>",
        sub { $func_reset->(); }
    );
    $top->bind(
        "<Control-Key-e>",
        sub {
            $func_execute_batch_analysis->($self, $in_dirname, $out_dirname, \$run_flag, \$total, \$count, \$progress);
        }
    );
    $top->bind(
        "<Control-Key-w>",
        sub {
            $func_close->($self, $in_dirname, $out_dirname, $top, \$run_flag);
        }
    );
    $top->bind(
        "<Key-Escape>",
        sub {
            $func_close->($self, $in_dirname, $out_dirname, $top, \$run_flag);
        }
    );
    $top->protocol(
        "WM_DELETE_WINDOW",
        sub {
            $func_close->($self, $in_dirname, $out_dirname, $top, \$run_flag);
        }
    );

    $run_flag = 1;
    $func_execute_batch_analysis->($self, $in_dirname, $out_dirname, \$run_flag, \$total, \$count, \$progress);
    $top->resizable(1, 0);
    $top->update();
    $top->deiconify();
    $self->enable_analysis_buttons(0);
    $top->waitWindow($top);
    $self->enable_analysis_buttons(1);
    return Tk::break();
}

sub cmd_clear_input {
    my $self = shift;
    my $app_conf = $self->get_app_conf();
    my $in_table_disp = $app_conf->get("in-table-disp");
    if ($in_table_disp) {
        $self->put_table($self->{"in_table"}, "",
                         $app_conf->get("in-readonly"));
    } else {
        $self->put_text($self->{"in_text"}, "");
    }
    $self->{"in-pathname"} = "";
    my $out_table_disp = $app_conf->get("out-table-disp");
    if ($out_table_disp) {
        $self->put_table($self->{"out_table"}, "",
                         $app_conf->get("out-readonly"));
    } else {
        $self->put_text($self->{"out_text"}, "");
    }
    $self->{"out-pathname"} = "";
}

sub cmd_clear_cache {
    my $self = shift;
    my $app_conf = $self->get_app_conf();
    my $tmp_dir = $app_conf->get("tmp-dir");
    my $cache_dir = $tmp_dir;
    my $message = $cache_dir."\n".$self->{"msg"}{"MSG_CLEAR_CACHE"};
    my $res = $self->messageBox(
        -message=>$message,
        -icon=>"warning",
        -type=>"yesno", -default=>"no"
    );
    if ($res =~ /^yes/i) {
        if (-d $cache_dir) {
            $self->rm_fr($cache_dir);
        }
    }
}

sub rm_fr {
    my $self = shift;
    my ($dir) = @_;
    opendir(my $dh, $dir);
    foreach my $file (readdir($dh)) {
        if ($file =~ /^\./) {
            next;
        } elsif (-f $dir."/".$file) {
            unlink($dir."/".$file);
        } elsif (-d $dir."/".$file) {
            $self->rm_fr($dir."/".$file);
        }
    }
    closedir($dh);
    rmdir($dir);
}

sub put_text {
    my $self = shift;
    my ($text, $str) = @_;
    my $state = $text->cget(-state);
    $text->configure(-state=>"normal");
    $text->delete("1.0", "end");
    $text->insert("end", $str);
    $text->configure(-state=>$state);
    return;
}

sub get_text {
    my $self = shift;
    my ($text) = @_;
    my $str = $text->get("1.0", "end");
    $str =~ s/([^\n])\n$/$1/s;
    $str =~ s/^\n$//s;
    return $str;
}

sub put_table {
    my $self = shift;
    my ($table, $str, $readonly) = @_;
    my $sep = ($str =~ /\t/)?"\t":" ";
    $table->{"__sep"} = $sep;
    my $or = 1;
    my $oc = 1;
    # $or = 0; $oc = 0;
    my $state = $readonly ? "disabled" : "normal";
    $str =~ s/\n$//s;
    my $row_list = [split(/\n/, $str, -1)];
    my $rows = scalar(@$row_list);
    my $columns = 0;
    for (my $r = 0; $r < $rows; ++$r) {
        my $line = $row_list->[$r];
        my $column_list = [split(/$sep/, $line, -1)];
        if ($columns < scalar(@$column_list)) {
            $columns = scalar(@$column_list);
        }
        $row_list->[$r] = $column_list;
    }
    my $bg = $table->cget(-background);
    my $fg = $table->cget(-foreground);
    $table->configure(-rows => $rows + $or,
                      -columns => $columns + $oc);
    $table->configure(-fixedrows => $or,
                      -fixedcolumns => $oc);
    if ($or > 0) {
        for (my $c = 0; $c < $columns; ++$c) {
            my $cell = $table->get(0, $c + 1);
            if (!$cell) {
                $cell = $table->Entry();
                $cell->pack(-side => "left", -fill => "x", -expand => "yes");
                $cell->configure(
                    -width => -1,
                    -relief => "flat",
                    -foreground => $fg,
                    -disabledforeground => $fg,
                );
            }
            $cell->configure(-state => "normal");
            $cell->delete("0", "end");
            $cell->insert("end", $c + 1);
            $cell->configure(-state => "disabled");
            $self->bind_wheel($cell, $table);
            $table->put(0, $c + 1, $cell);
        }
    }
    for (my $r = 0; $r < $rows; ++$r) {
        for (my $c = 0; $c < $columns; ++$c) {
            if ($oc > 0) {
                my $cell = $table->get($r + 1, 0);
                if (!$cell) {
                    $cell = $table->Entry();
                    $cell->pack(-side => "left", -fill => "x", -expand => "yes");
                    $cell->configure(
                        -width => -1,
                        -relief => "flat",
                        -foreground => $fg,
                        -disabledforeground => $fg,
                    );
                }
                $cell->configure(-state => "normal");
                $cell->delete("0", "end");
                $cell->insert("end", $r + 1);
                $cell->configure(-state => "disabled");
                $self->bind_wheel($cell, $table);
                $table->put($r + 1, 0, $cell);
            }
            my $item = $row_list->[$r][$c];
            # my $w = length($item) * 2;
            my $w = length($item) + 4;
            if ($w > 20) {
                $w = 20;
            }
            my $cell = $table->get($r + $or, $c + $oc);
            if (!$cell) {
                $cell = $table->Entry();
                $cell->pack(-side => "left", -fill => "x", -expand => "yes");
                # print STDERR "CREATE: ".$cell."\n";
            } else {
                # print STDERR $cell."\n";
            }
            $cell->configure(
                -width => $w,
                -relief => "flat",
                -background => $bg,
                -foreground => $fg,
                -disabledbackground => $bg,
                -disabledforeground => $fg
            );
            $cell->configure(-state => "normal");
            $cell->delete("0", "end");
            $cell->insert("end", $item);
            my $relief = $state eq "disabled" ? "flat" : "sunken";
            $cell->configure(
                -state => $state,
                -relief => $relief
            );
            $self->bind_wheel($cell, $table);
            $table->put($r + $or, $c + $oc, $cell);
        }
    }
    return;
}

sub get_table {
    my $self = shift;
    my ($table) = @_;
    my $sep = $table->{"__sep"};
    my $or = 1;
    my $oc = 1;
    # $or = 0; $oc = 0;
    my $rows = $table->cget("rows") - $or;
    my $columns = $table->cget("columns") - $oc;
    my $row_list = [];
    for (my $r = 0; $r < $rows; ++$r) {
        my $column_list = [];
        for (my $c = 0; $c < $columns; ++$c) {
            my $cell = $table->get($r + $or, $c + $oc);
            my $item = $cell->get();
            # $item =~ s/([^\n])\n$/$1/s;
            # $item =~ s/^\n$//s;
            push(@$column_list, $item);
        }
        push(@$row_list, join($sep, @$column_list));
    }
    my $str = join("\n", @$row_list);
    if ($str ne "") {
        $str .= "\n";
    }
    return $str;
}

sub change_state_table {
    my $self = shift;
    my ($table, $state) = @_;
    my $or = 1;
    my $oc = 1;
    # $or = 0; $oc = 0;
    my $rows = $table->totalRows() - $or;
    my $columns = $table->totalColumns() - $oc;
    for (my $r = 0; $r < $rows; ++$r) {
        for (my $c = 0; $c < $columns; ++$c) {
            my $cell = $table->get($r + $or, $c + $oc);
            my $relief = $state eq "disabled" ? "flat" : "sunken";
            $cell->configure(-state => $state,
                             -relief => $relief);
        }
    }
}

sub change_table_disp {
    my $self = shift;
    my ($text, $table, $table_disp, $readonly) = @_;
    my $f = $table;
    my $p = $text;
    if ($table_disp) {
        $f = $text;
        $p = $table;
        my $str = $self->get_text($text);
        $table->clear();
        $self->put_table($table, $str, $readonly);
    } else {
        my $str = $self->get_table($table);
        $self->put_text($text, $str);
    }
    $f->packForget();
    $p->pack(-side=>"top", -fill=>"both", -expand=>"yes");
}

sub calc_color {
    my $self= shift;
    my ($start_color, $end_color, $i, $region) = @_;
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
    my $self = shift;
    my ($flag) = @_;
    if ($flag == 0) {
        $self->{"_analysis_button"}->configure(-state=>"disabled");
        $self->{"_batch_analysis_button"}->configure(-state=>"disabled");
        $self->{"_clear_input_button"}->configure(-state=>"disabled");
        $self->{"_clear_cache_button"}->configure(-state=>"disabled");
    } else {
        $self->{"_analysis_button"}->configure(-state=>"normal");
        $self->{"_batch_analysis_button"}->configure(-state=>"normal");
        $self->{"_clear_input_button"}->configure(-state=>"normal");
        $self->{"_clear_cache_button"}->configure(-state=>"normal");
    }
    $self->update();
    return;
}

sub execute_analysis_file_on_gui {
    my $self = shift;
    my ($in_file, $out_file, $top, $progress_func) = @_;
    $self->cmd_open($in_file);
    if(Tk::Exists($top)) { $top->raise(); }
    $self->update();
    $self->cmd_analysis(1, $progress_func);
    if(Tk::Exists($top)) { $top->raise(); }
    $self->update();
    $self->cmd_save_as($out_file);
    if(Tk::Exists($top)) { $top->raise(); }
    $self->update();
}

sub execute_analysis_file {
    my $self = shift;
    my ($in_file, $out_file) = @_;
    my $in_data = "";
    my $out_data = "";
    {
        open(my $in_fh, $in_file);
        $in_data = join("", (<$in_fh>));
        $in_data = Encode::decode("utf-8", $in_data);
        close($in_fh);
    }
    if ($in_data ne "") {
        $self->execute_analysis_data($in_data, $out_data);
        {
            open(my $out_fh, ">", $out_file);
            binmode($out_fh);
            $out_data = Encode::encode("utf-8", $out_data);
            printf($out_fh "%s", $out_data);
            close($out_fh);
        }
    }
    return;
}

sub execute_analysis_data {
    my $self = shift;
    my ($in_data, $progress_func) = @_;
    my $app_conf = $self->get_app_conf();
    my $chasen_dir = $app_conf->get("chasen-dir");
    my $mecab_dir = $app_conf->get("mecab-dir");
    my $unidic_dir = $app_conf->get("unidic-dir");
    my $unidic2_dir = $app_conf->get("unidic2-dir");
    my $unidic_db = $app_conf->get("unidic-db");
    my $yamcha_dir = $app_conf->get("yamcha-dir");
    my $crf_dir = $app_conf->get("crf-dir");
    my $java = $app_conf->get("java");
    my $mstparser_dir = $app_conf->get("mstparser-dir");
    my $comainu_home = $app_conf->get("comainu-home");
    my $comainu_crf_train = $app_conf->get("comainu-crf-train");
    my $comainu_crf_model = $app_conf->get("comainu-crf-model");
    my $comainu_svm_train = $app_conf->get("comainu-svm-train");
    my $comainu_svm_model = $app_conf->get("comainu-svm-model");
    my $comainu_svm_bnst_model = $app_conf->get("comainu-svm-bnst-model");
    my $comainu_svm_bip_model = $app_conf->get("comainu-svm-bip-model");
    my $comainu_mst_model = $app_conf->get("comainu-mst-model");
    my $comainu_input_type = $app_conf->get("comainu-input-type");
    my $comainu_output_type = $app_conf->get("comainu-output-type");
    my $comainu_long_model_type = $app_conf->get("comainu-model-type");
    my $comainu_tagger = $app_conf->get("comainu-tagger-type");
    my $comainu_boundary = $app_conf->get("comainu-boundary-type");
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
    my $comainu_train_kc = $comainu_crf_train;
    if ($comainu_long_model_type =~ /svm/) {
        $comainu_long_model = $comainu_svm_model;
        $comainu_train_kc = $comainu_svm_train;
    }
    if ($comainu_train_kc eq "") {
        $comainu_train_kc = $comainu_long_model;
        $comainu_train_kc =~ s/.model$//;
    }

    my $comainu_mid_model = $comainu_mst_model;
    my $comainu_bnst_model = $comainu_svm_bnst_model;

    if(!-d $tmp_dir) { mkdir($tmp_dir); }
    if(-f $out_file) { unlink($out_file); }
    eval {
        open(my $fh, ">", $comainu_test);
        binmode($fh);
        $in_data = Encode::encode("utf-8", $in_data);
        printf($fh "%s", $in_data);
        close($fh);
    };

    $yamcha_dir = File::Spec->rel2abs($yamcha_dir);
    $chasen_dir = File::Spec->rel2abs($chasen_dir);
    $mecab_dir = File::Spec->rel2abs($mecab_dir);
    $unidic_dir = File::Spec->rel2abs($unidic_dir);
    $unidic2_dir = File::Spec->rel2abs($unidic2_dir);
    $unidic_db = File::Spec->rel2abs($unidic_db);
    $comainu_home = File::Spec->rel2abs($comainu_home);
    $comainu_long_model = File::Spec->rel2abs($comainu_long_model);
    $comainu_train_kc = File::Spec->rel2abs($comainu_train_kc);
    $comainu_mid_model = File::Spec->rel2abs($comainu_mid_model);
    $tmp_dir = File::Spec->rel2abs($tmp_dir);
    $comainu_test = File::Spec->rel2abs($comainu_test);

    my $runcom = $Bin."/../bin/runcom.exe";
    if (! -f $runcom) {
        $runcom = $self->{"perl"};
    }
    $ENV{"PERL"} = $runcom;
    my $comainu_opts = {
        "debug" => $self->{"debug"},
        "comainu-home" => $comainu_home,
        "chasen-dir" => $chasen_dir,
        "mecab-dir" => $mecab_dir,
        "unidic-dir" => $unidic_dir,
        "unidic2-dir" => $unidic2_dir,
        "unidic-db" => $unidic_db,
        "yamcha-dir" => $yamcha_dir,
        "crf-dir" => $crf_dir,
        "java" => $java,
        "mstparser-dir" => $mstparser_dir,
        "comainu-output" => $tmp_dir,
        "comainu-temp" => $tmp_dir."/temp",
        "comainu-svm-bip-model" => $comainu_svm_bip_model,
        "boundary" => $comainu_boundary,
        "suwmodel" => $comainu_tagger,
        "luwmodel" => uc($comainu_long_model_type),
        "luwmrph" => $luwmrph,
    };
    my $comainu_opts_str = join(" ", map {"--".$_." \"".$comainu_opts->{$_}."\"";} keys %$comainu_opts);
    my $comainu_com = sprintf("\"%s\" \"%s/script/comainu.pl\" %s \"%s\" \"%s\" \"%s\" \"%s\" \"%s\"",
                              $runcom,
                              $comainu_home, $comainu_opts_str,
                              $comainu_method,
                              $comainu_train_kc,
                              $comainu_test, $comainu_long_model, $tmp_dir
                          );
    if($comainu_method =~ /(plain|bccwj|kc)2bnstout/) {
        # BunSetsu Analysis
        $comainu_com = sprintf("\"%s\" \"%s/script/comainu.pl\" %s \"%s\" \"%s\" \"%s\" \"%s\" \"%s\"",
			       $runcom,
                               $comainu_home, $comainu_opts_str,
                               $comainu_method,
                               $comainu_test, $comainu_bnst_model, $tmp_dir
                           );
    }
    if($comainu_method =~ /(plain|bccwj|kc)2longbnstout/) {
        # Long & BunSetsu Analysis
        $comainu_com = sprintf("\"%s\" \"%s/script/comainu.pl\" %s \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\"",
                               $runcom,
                               $comainu_home, $comainu_opts_str,
                               $comainu_method,
                               $comainu_train_kc, # just for name
                               $comainu_test, $comainu_long_model, $comainu_bnst_model, $tmp_dir
                           );
    }
    if($comainu_method =~ /(plain|bccwj|kc)2midout/) {
        # Mid Analysis
        $comainu_com = sprintf("\"%s\" \"%s/script/comainu.pl\" %s \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\"",
			       $runcom,
                               $comainu_home, $comainu_opts_str,
                               $comainu_method,
                               $comainu_train_kc, # just for name
                               $comainu_test, $comainu_long_model, $comainu_mid_model, $tmp_dir
                           );
    }
    if($comainu_method =~ /(plain|bccwj|kc)2midbnstout/) {
        # Long & Mid Analysis % BunSetsu
        $comainu_com = sprintf("\"%s\" \"%s/script/comainu.pl\" %s \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\"",
                               $runcom,
                               $comainu_home, $comainu_opts_str,
                               $comainu_method,
                               $comainu_train_kc, # just for name
                               $comainu_test, $comainu_long_model, $comainu_mid_model, $comainu_bnst_model, $tmp_dir
                           );
    }
    if($comainu_method =~ /(bccwjlong|kclong)2midout/) {
        # Long & Mid Analysis
        $comainu_com = sprintf("\"%s\" \"%s/script/comainu.pl\" %s \"%s\" \"%s\" \"%s\" \"%s\" \"%s\"",
                               $runcom,
                               $comainu_home, $comainu_opts_str,
                               $comainu_method,
                               $comainu_test, $comainu_mid_model, $tmp_dir
                           );
    }

    $comainu_com =~ s/\\/\//sg;
    while ($comainu_com =~ s/\/[^\/]+\/\.\.//sg) { ; }

    if ($Config{"osname"} eq "MSWin32") {
        $comainu_com =~ s/\//\\/sg;
    }

    if ($self->{"debug"} > 0) {
        printf(STDERR "# COMAINU_COM: %s\n", $comainu_com);
    }


    my $proc_end_flag = 0;
    my $com_worker = $self->{"_com_worker"};
    $com_worker->system_nb($comainu_com);
    while ($com_worker->is_running()) {
        if (ref($progress_func)) {
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

#################### END OF FILE ####################
