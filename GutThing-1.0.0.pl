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

require 5.008;
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin . "/lib";
use Data::Dumper;

use Cwd;
use Encode;
use File::Basename;
use File::Temp qw/tempfile/;
use HTML::TokeParser;
use IPC::Open2;
use LWP::UserAgent;
use charnames();

use Tk;
use Tk::widgets qw/Balloon
    BrowseEntry
    Checkbutton
    Dialog
    DialogBox
    DropSite
    Font
    JPEG
    LabFrame
    Listbox
    PNG
    Pane
    Photo
    ProgressBar
    Radiobutton
    TextEdit/;

# Custom Guigut modules
use LineNumberText;
use TextUnicode;

my $VERSION = "1.0.0";
my $ggdir = "$FindBin::Bin"; # Get the GuiGuts directory.
my $window_title = "GutThing - " . $VERSION;


# ignore any watchdog timer alarms. Subroutines that take a long time to complete can trip it
$SIG{ALRM} = 'IGNORE';
$SIG{INT} = sub { myexit() }; # FIXME: Can this be \&myexit;?



my $mw = MainWindow->new;    # Set up main window
$mw->minsize( 440, 90 );
$mw->configure(-title => $window_title);

my $text_frame = $mw->Frame->pack( -anchor => 'nw',
    -expand => 'yes', 
    -fill => 'both' ) ;          # autosizing

my $textwindow = $text_frame->LineNumberText(
    -widget => 'TextUnicode',
    -exportselection => 'true',     # 'sel' tag is associated with selections
    -background      => 'white',
    -relief          => 'sunken',
#    -font      => $lglobal{font},
    -wrap      => 'none',
#    -curlinebg => $activecolor,
)->pack(
    -side   => 'bottom',
    -anchor => 'nw',
    -expand => 'yes',
    -fill   => 'both'
);

MainLoop;

## Functions and subroutines

sub myexit { }
sub confirmdiscard { }

