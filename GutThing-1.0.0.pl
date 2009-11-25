#!/usr/bin/perl

# $Id$

# GuiGuts text editor

#Copyright (C) 2008 V. L. Simpson <vlsimpson@gmail.com>

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

use Cwd;
use Encode;
use File::Basename;
use File::Temp qw/tempfile/;
use HTML::TokeParser;
use IPC::Open2;
use LWP::UserAgent;
use charnames();

use Tk;

# Custom Guigut modules
use LineNumberText;
use TextUnicode;

use constant OS_Win => $^O =~ /Win/;

# ignore any watchdog timer alarms. Subroutines that take a long time to
# complete can trip it
$SIG{ALRM} = 'IGNORE';
$SIG{INT} = sub { gt_exit() };


my %lglobal;

my $win_title = "GutThing"; 
my $mw = tkinit(-title => $win_title,);
$mw->minsize(440, 90);

our $geometry;
$mw->bind('<Configure>' => sub {
            $geometry = $mw->geometry;
            $lglobal{geometryupdate} = 1;
            }
);

# Set up Main window layout 
my $text_frame = $mw->Frame->pack( -anchor => 'nw',
                                    -expand => 'yes',
                                    -fill => 'both' ) ; # autosizing 

# The actual text widget
my $text_window = $text_frame->LineNumberText(
                                             -widget => 'TextUnicode',
                                             -exportselection => 'true', # 'sel' tag is associated with selections
                                             # FIXME: -background      => 'white',
                                             -relief          => 'sunken',
                                             # FIXME: -font      => $lglobal{font},
                                             -wrap      => 'none',
                                             # FIXME: -curlinebg => $activecolor,
                                            )->pack(
                                                    -side   => 'bottom',
                                                    -anchor => 'nw',
                                                    -expand => 'yes',
                                                    -fill   => 'both'
                                                   );
sub gt_exit { exit; }

$mw->protocol( 'WM_DELETE_WINDOW' => \&gt_exit );

our $nohighlights;
our $vislnnm;
$text_window->SetGUICallbacks(
    [    # routines to call every time the text is edited
    # FIXME: \&update_indicators,
    sub {
        return if $nohighlights;
        $text_window->HighlightAllPairsBracketingCursor;
    },
    sub {
        $text_window->hidelinenum unless $vislnnm;
    }
    ]
);

MainLoop;
