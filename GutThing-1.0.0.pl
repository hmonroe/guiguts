#!/usr/bin/perl

# $Id$

# GuiGuts text editor

#Copyright (C) 2008 V. L. Simpson <vlsimpson@users.sourceforge.net>

#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#as published by the Free Software Foundation; either version 2
#of the License, or (at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin . "/lib";
use Data::Dumper;



use Tk;
use Tk::widgets qw/TextUndo
    LineNumberText
    /;

use constant OS_Win => $^O =~ /Win/;

my $VERSION        = "1.0.0";
my $activecolor    = '#f2f818';
my $font           = 'Courier New';
my $globallastpath = '';

my %global;
$global{font} = "{$font}";

my $window_title = "GutThing - " . $VERSION;
my $mw = tkinit( -title => $window_title );
$mw->minsize( 440, 90 );

my $text_frame = $mw->Frame->pack(
    -anchor => 'nw',
    -expand => 'yes',
    -fill   => 'both'
);

my $text_window = $text_frame->LineNumberText(
    'TextUndo',
    -exportselection  => 'true',
    -relief           => 'sunken',
    -font             => $global{font},
    -wrap             => 'none',
    -curlinebg        => $activecolor,
    -curlinehighlight => 'linenum',
    -linenumalign     => 'center',
    )->pack(
    -side   => 'bottom',
    -anchor => 'nw',
    -expand => 'yes',
    -fill   => 'both'
    );
$mw->configure( -menu => my $menubar
        = $mw->Menu( -menuitems => menubar_menuitems() ) );

$text_window->focus;

### Subroutines

# Menus
sub menubar_menuitems {
    [   map [ 'cascade', $_->[0],
            -menuitems => $_->[1],
            -tearoff   => $_->[2] ],
        [ 'File',            file_menuitems(),      0 ],
        [ 'Edit',            edit_menuitems(),      0 ],
        [ 'Search',          search_menuitems(),    1 ],
        [ 'Bookmarks',       bookmark_menuitems(),  0 ],
        [ 'Selection',       selection_menuitems(), 1 ],
        [ 'Fixup',           fixup_menuitems(),     1 ],
        [ 'Text Processing', text_menuitems(),      1 ],
        [ 'External',        external_menuitems(),  0 ],
        [ 'Unicode',         unicode_menuitems(),   0 ],
        [ 'Prefs',           prefs_menuitems(),     0 ],
        [ 'Help',            help_menuitems(),      0 ],
    ];
}

sub file_menuitems {
    [   [   'command', 'Open',
            -command     => \&file_open,
            -underline   => 0,
            -accelerator => 'Ctrl+o'
        ],
        '',
        [   'command', 'Save',
            -command     => \&file_save,
            -underline   => 0,
            -accelerator => 'Ctrl+s'
        ],
        [ 'command', 'Save As', -command => \&file_saveas, -underline => 5, ],
        [   'command', 'Include',
            -command   => \&file_include,
            -underline => 0,
        ],
        [ 'command', 'Close', -command => \&file_close, -underline => 0, ],
        '',
        [ 'command', 'Import Prep Text Files', -command => \&prep_import, ],
        [   'command', 'Export As Prep Text Files', -command => \&prep_export,
        ],
        '',
        [   'command', 'Guess Page Markers',
            -command   => \&guess_pagemarks,
            -underline => 0,
        ],
        [   'command', 'Set Page Markers',
            -command   => \&set_pagemarks,
            -underline => 9,
        ],
        '',
        [   'command', 'Exit',
            -command     => \&gg_exit,
            -underline   => 1,
            -accelerator => 'Ctrl+q'
        ],
    ];
}



sub file_save {
    my ($name);
    $text_window->SaveUTF($name);
}

sub file_saveas     { }
sub file_include    { }
sub file_close      { }
sub prep_import     { }
sub prep_export     { }
sub guess_pagemarks { }
sub set_pagemarks   { }
sub gg_exit         { exit; }

sub edit_menuitems {
    [   [ 'command', 'Undo', -command => \&gg_undo, ],
        [ 'command', 'Redo', -command => \&gg_redo, ],
        '',
        [ 'command', 'Cut', ],
        [ 'command', 'Copy', ],
        [ 'command', 'Paste', ],
        [ 'command', 'Column Paste', ],
        '',
        [ 'command', 'Select All', ],
        [ 'command', 'Unselect All', ],
    ];
}
sub gg_undo { $text_window->undo; }
sub gg_redo { $text_window->redo; }

sub search_menuitems {
    [   [ 'command', 'Search & Replace', ],
        [ 'command', 'Stealth Scannos', ],
        [ 'command', 'Spell Check', ],
        [ 'command', 'Goto Line', ],
        [ 'command', 'Goto Page' ],
        [ 'command', 'Which Line?', ],
        '',
        [ 'command', 'Find Proofer Comments', ],
        [ 'command', 'Find next /*..*/ block', ],
        [ 'command', 'Find previous /*..*/ block', ],
        [ 'command', 'Find next /#..#/ block', ],
        [ 'command', 'Find previous /#..#/ block', ],
        [ 'command', 'Find next /$..$/ block', ],
        [ 'command', 'Find previous /$..$/ block', ],
        [ 'command', 'Find next /p..p/ block', ],
        [ 'command', 'Find previous /p..p/ block', ],
        [ 'command', 'Find next indented block', ],
        [ 'command', 'Find previous indented block', ],
        '',
        [ 'command', 'Find Orphaned Brackets & Markup', ],
        '',
        [ 'command', 'Highlight double quotes in selection', ],
        [ 'command', 'Highlight single quotes in selection', ],
        [ 'command', 'Highlight arbitrary characters in selection', ],
        [ 'command', 'Remove Highlights', ],
    ];
}

sub bookmark_menuitems {
    [   [ 'command', 'Set Bookmark 1', ],
        [ 'command', 'Set Bookmark 2', ],
        [ 'command', 'Set Bookmark 3', ],
        [ 'command', 'Set Bookmark 4', ],
        [ 'command', 'Set Bookmark 5', ],
        '',
        [ 'command', 'Goto Bookmark 1', ],
        [ 'command', 'Goto Bookmark 2', ],
        [ 'command', 'Goto Bookmark 3', ],
        [ 'command', 'Goto Bookmark 4', ],
        [ 'command', 'Goto Bookmark 5', ],
    ];
}

sub selection_menuitems {
    [   [ 'command', 'lowercase Selection' ],
        [ 'command', 'Sentence case selection' ],
        [ 'command', 'Title Case Selection' ],
        [ 'command', 'UPPERCASE Selection' ],
        '',
        [ 'command', 'Surround Selectin With...' ],
        [ 'command', 'Flood Fill Selection With...' ],
        '',
        [ 'command', 'Indent Selection 1' ],
        [ 'command', 'Indent Selection -1' ],
        '',
        [ 'command', 'Rewrap Selection' ],
        [ 'command', 'Block Rewrap Selection' ],
        [ 'command', 'Interrupt Rewrap' ],
        '',
        [ 'command', 'ASCII Boxes' ],
        [ 'command', 'Align text on string' ],
        '',
        [ 'command', 'Convert to Named/Numeric Entities' ],
        [ 'command', 'Convert From Named/Numeric Entities' ],
        [ 'command', 'Convert Fractions' ],
    ];
}

sub fixup_menuitems {
    [   [ 'command', 'Run Word Frequency' ],
        [ 'command', 'Run ~Gutcheck' ],
        [ 'command', 'Gutcheck options' ],
        [ 'command', 'Run Jeebies' ],
        '',
        [ 'command', 'Remove End-of-line Spaces' ],
        [ 'command', 'Run Fixup' ],
        '',
        [ 'command', 'Fix Page Separators' ],
        [ 'command', 'Remove Blank Lines Before Page Separators' ],
        '',
        [ 'command', 'Footnote Fixup', ],
        [ 'command', 'HTML Fixup', ],
        [ 'command', 'Sidenote Fixup', ],
        [ 'command', 'Reformat Poetry Line Numbers', ],
        [ 'command', 'Convert Win CP 1252 Chars to Unicode', ],
        '',
        [ 'command', 'ASCII Table Special Effects', ],
        '',
        [ 'command', 'Clean Up Rewrap Markers', ],
        '',
        [ 'command', 'Find Greek', ],

        # FIXME: Doesn't work yet[ 'command', 'Convert Greek', ],
    ];
}

sub text_menuitems {
    [   [ 'command', 'Convert Italics' ],
        [ 'command', 'Convert Bold' ],
        [ 'command', 'Add Thought Break' ],
        [ 'command', 'Convert <tb>' ],
        [ 'command', 'Convert <sc>' ],
        [ 'command', 'Options' ],
    ];
}

sub external_menuitems {
    [ [ 'command', '' ], [ 'command', '' ], ];
}

sub unicode_menuitems {
    [ [ 'command', '' ], [ 'command', '' ], ];
}

sub prefs_menuitems {
    [   [ 'command',     'Set Rewrap Margins' ],
        [ 'command',     'Font' ],
        [ 'command',     'Browser Start Command' ],
        [ 'checkbutton', 'Leave Bookmarks Highlighted' ],
        [ 'checkbutton', 'Enable Quotes Highlighting' ],
        [ 'checkbutton', 'Keep Pop-ups On Top' ],
        [ 'checkbutton', 'Enable Bell' ],
        [ 'checkbutton', 'Auto Set Page Markers' ],
        [   'checkbutton',
            'Leave Space Afer End-of-Line Hyphens During Rewrap'
        ],
        [   'command',
            'Toggle Line Numbers',
            -command => \&toggle_line_numbers,
        ],
    ];
}
sub toggle_line_numbers { $text_window->togglelinenum; }

sub help_menuitems {
    [   [ 'command', 'Hot Keys' ],
        [ 'command', 'Function History' ],
        [ 'command', 'Greek Transliteration' ],
        [ 'command', 'Latin1 Chart' ],
        [ 'command', 'Regex Quick Reference' ],
        [ 'command', 'UTF Character Entry' ],
        [ 'command', 'UTF Character Search' ],
    ];
}

# "File Open Routines

if ( @ARGV == 1 ) { $text_window->Load( shift @ARGV ); }

sub confirmdiscard {
    if ( $text_window->numberChanges ) {
        my $ans = $mw->messageBox(
            -icon    => 'warning',
            -type    => 'YesNoCancel',
            -default => 'yes',
            -message =>
                'The text has been modified without being saved. Save edits?'
        );
        if ( $ans =~ /yes/i ) {
            savefile();
        } else {
            return $ans;
        }
    }
    return 'no';
}

sub confirmempty {
    my $answer = confirmdiscard();
    if ( $answer =~ /no/i ) {
        if ( $global{page_num_label} ) {
            $global{page_num_label}->destroy;
            undef $global{page_num_label};
        }
        if ( $global{pagebutton} ) {
            $global{pagebutton}->destroy;
            undef $global{pagebutton};
        }
        if ( $global{proofbutton} ) {
            $global{proofbutton}->destroy;
            undef $global{proofbutton};
        }
        $text_window->EmptyDocument;
    }
    return $answer;
}

sub file_open {
    my ($name);

    return if ( confirmempty() =~ /cancel/i );
    my $types = [
        [ 'Text Files', [qw/.txt .text .ggp .htm .html .bk1 .bk2/] ],
        [ 'All Files',  ['*'] ],
    ];
    $name = $text_window->getOpenFile(
        -filetypes  => $types,
        -title      => 'Open File',
        -initialdir => $globallastpath,
    );
    if ( defined($name) and length($name) ) {
        open_file($name);
    }
}

sub open_file {
    my $name = shift;
    $text_window->Load($name);
}

MainLoop;
