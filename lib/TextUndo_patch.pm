# -*- mode: perl; coding: utf-8; -*-

package TextUndo_patch;

use vars qw($VERSION $DoDebug);
$VERSION = '1.000';
$DoDebug = 0;

use Tk qw (Ev);
# use AutoLoader;

use Tk::Text ();
use base qw(Tk::TextUndo);

Construct Tk::Widget 'TextUndo_patch';

sub ClassInit {
 my ($class,$mw) = @_;

 return $class->SUPER::ClassInit($mw);
}

############################################################

use utf8;

our $POPUP_MENU_MAP = {
    "en" => {
        "DIRECTION" => "Direction:",
        "forward" => "forward",
        "backward" => "backward",
        "MODE" => "Mode:",
        "exact" => "exact",
        "regexp" => "regexp",
        "CASE" => "Case:",
        "case" => "case",
        "nocase" => "nocase:",
        "FIND" => "Find",
        "FIND ALL" => "Find All",
        "REPLACE" => "Replace",
        "REPLACE ALL" => "Replace All",
        "CANCEL" => "Cancel",
    },
    "ja" => {
        "DIRECTION" => "方向:",
        "forward" => "前方",
        "backward" => "後方",
        "MODE" => "モード:",
        "exact" => "完全一致",
        "regexp" => "正規表現",
        "CASE" => "大文字／小文字の区別:",
        "case" => "区別する",
        "nocase" => "区別しない",
        "FIND" => "検索",
        "FIND ALL" => "すべて検索",
        "REPLACE" => "置換",
        "REPLACE ALL" => "すべて置換",
        "CANCEL" => "キャンセル",
    },
};

our $POPUP_MENU_LANG = "ja";

sub get_popup_menu_str {
    my ($name, $lang) = @_;
    unless($lang) { $lang = $POPUP_MENU_LANG; }
    return $POPUP_MENU_MAP->{$lang}{$name};
}

sub MenuLabels {
 return qw[~Edit ~Search ~View];
}

sub SearchMenuItems {
    my ($w) = @_;
    return [
        ['command'=>'~Find',          -command => [$w => 'FindPopUp']],
        ['command'=>'Find ~Next',     -command => [$w => 'FindSelectionNext']],
        ['command'=>'Find ~Previous', -command => [$w => 'FindSelectionPrevious']],
        ['command'=>'~Replace',       -command => [$w => 'FindAndReplacePopUp']]
    ];
}

sub EditMenuItems {
    my ($w) = @_;
    my @items = ();
    foreach my $op ($w->clipEvents) {
        push(@items,['command' => "~$op", -command => [ $w => "clipboard$op"]]);
    }
    push(@items,
         '-',
         ['command'=>'Select All', -command   => [$w => 'selectAll']],
         ['command'=>'Unselect All', -command => [$w => 'unselectAll']],
     );
    return \@items;
}

sub ViewMenuItems {
    my ($w) = @_;
    my $v;
    tie $v,'Tk::Configure',$w,'-wrap';
    return  [
        ['command'=>'Goto ~Line...', -command => [$w => 'GotoLineNumberPopUp']],
        ['command'=>'~Which Line?',  -command =>  [$w => 'WhatLineNumberPopUp']],
        # ['cascade'=> 'Wrap', -tearoff => 0, -menuitems => [
        # [radiobutton => 'Word', -variable => \$v, -value => 'word'],
        # [radiobutton => 'Character', -variable => \$v, -value => 'char'],
        # [radiobutton => 'None', -variable => \$v, -value => 'none'],
        # ]],
    ];
}

sub findandreplacepopup {
    my ($w,$find_only)=@_;

    my $pop = $w->Toplevel;
    $pop->transient($w->toplevel);
    if ($find_only) {
        $pop->title("Find");
    } else {
        $pop->title("Find and/or Replace");
    }
    my $frame =  $pop->Frame->pack(-anchor=>'nw');

    $frame->Label(
        -text=>get_popup_menu_str("DIRECTION")
    )->grid(
        -row=> 1,
        -column=>1,
        -padx=> 20,
        -sticky => 'nw'
    );
    my $direction = '-forward';
    $frame->Radiobutton(
        -variable => \$direction,
        -text => get_popup_menu_str('forward'),
        -value => '-forward'
    )->grid(
        -row=> 2,
        -column=>1,
        -padx=> 20,
        -sticky => 'nw'
    );
    $frame->Radiobutton(
        -variable => \$direction,
        -text => get_popup_menu_str('backward'),
        -value => '-backward'
    )->grid(
        -row=> 3,
        -column=>1,
        -padx=> 20,
        -sticky => 'nw'
    );

    $frame->Label(
        -text=>get_popup_menu_str("MODE")
    )->grid(
        -row=> 1,
        -column=>2,
        -padx=> 20,
        -sticky => 'nw'
    );
    my $mode = '-exact';
    $frame->Radiobutton(
        -variable => \$mode,
        -text => get_popup_menu_str('exact'),
        -value => '-exact'
    )->grid(
        -row=> 2,
        -column=>2,
        -padx=> 20,
        -sticky => 'nw'
    );
    $frame->Radiobutton(
        -variable => \$mode,
        -text => get_popup_menu_str('regexp'),
        -value => '-regexp'
    )->grid(
        -row=> 3,
        -column=>2,
        -padx=> 20,
        -sticky => 'nw'
    );

    $frame->Label(
        -text=>get_popup_menu_str("CASE")
    )->grid(
        -row=> 1,
        -column=>3,
        -padx=> 20,
        -sticky => 'nw'
    );
    my $case = '-case';
    $frame->Radiobutton(
        -variable => \$case,
        -text => get_popup_menu_str('case'),
        -value => '-case'
    )->grid(
        -row=> 2,
        -column=>3,
        -padx=> 20,
        -sticky => 'nw'
    );
    $frame->Radiobutton(
        -variable => \$case,
        -text => get_popup_menu_str('nocase'),
        -value => '-nocase'
    )->grid(
        -row=> 3,
        -column=>3,
        -padx=> 20,
        -sticky => 'nw'
    );

    ######################################################
    my $find_entry = $pop->Entry(-width=>25);
    $find_entry->focus;

    my $donext = sub {$w->FindNext ($direction,$mode,$case,$find_entry->get())};

    $find_entry->pack(-anchor=>'nw', '-expand' => 'yes' , -fill => 'x'); # autosizing

    ######  if any $w text is selected, put it in the find entry
    ######  could be more than one text block selected, get first selection
    my @ranges = $w->tagRanges('sel');
    if (@ranges) {
        my $first = shift(@ranges);
        my $last = shift(@ranges);

        # limit to one line
        my ($first_line, $first_col) = split(/\./,$first);
        my ($last_line, $last_col) = split(/\./,$last);
        unless($first_line == $last_line)
            {
                $last = $first. ' lineend';
            }

        $find_entry->insert('insert', $w->get($first , $last));
    } else {
        my $selected;
        eval {$selected=$w->SelectionGet(-selection => "PRIMARY"); };
        if ($@) {
        } elsif (defined($selected)) {
            $find_entry->insert('insert', $selected);
        }
    }

    $find_entry->icursor(0);

    my ($replace_entry,$button_replace,$button_replace_all);
    unless ($find_only)
        {
            $replace_entry = $pop->Entry(-width=>25);

            $replace_entry->pack(-anchor=>'nw', '-expand' => 'yes' , -fill => 'x');
        }

    my $button_find = $pop->Button(
        -text=>get_popup_menu_str('FIND'),
        -command => $donext,
        -default => 'active'
    )->pack(-side => 'left');

    my $button_find_all = $pop->Button(
        -text=>get_popup_menu_str('FIND ALL'),
        -command => sub {$w->FindAll($mode,$case,$find_entry->get());}
    )->pack(-side => 'left');

    unless ($find_only) {
        $button_replace = $pop->Button(
            -text=>get_popup_menu_str('REPLACE'),
            -default => 'normal',
            -command => sub {$w->ReplaceSelectionsWith($replace_entry->get());}
        )->pack(-side =>'left');
        $button_replace_all = $pop->Button(
            -text=>get_popup_menu_str('REPLACE ALL'),
            -command => sub {
                $w->FindAndReplaceAll(
                    $mode,
                    $case,
                    $find_entry->get(),
                    $replace_entry->get()
                );
            }
        )->pack(-side => 'left');
    }


    my $button_cancel = $pop->Button(
        -text=>get_popup_menu_str('CANCEL'),
        -command => sub {$pop->destroy()}
    )->pack(-side => 'left');

    $find_entry->bind("<Return>" => [$button_find, 'invoke']);
    $find_entry->bind("<Escape>" => [$button_cancel, 'invoke']);

    $find_entry->bind("<Return>" => [$button_find, 'invoke']);
    $find_entry->bind("<Escape>" => [$button_cancel, 'invoke']);

    $pop->resizable('yes','no');
    return $pop;
}

1;

#################### END OF FILE ####################
