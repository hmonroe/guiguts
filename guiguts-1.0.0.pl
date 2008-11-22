#!/usr/bin/perl
# $Id$

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

use warnings;
use strict;

use Tkx;

$Tkx::TRACE = 0;

our $VERSION = "1.0.0";

# Main window container
my ($mw, $tw);
$mw = Tkx::widget->new(".");
$mw->configure(-menu => mk_menu($mw));

# Our text widget
$tw = $mw->new_text(
    -width => 40, 
    -height => 10 );
$tw->g_pack;
$tw->g_focus;

$tw->insert("end", "If you can read this it worked");
$tw->insert("end", " but I don't do much at the moment.");

Tkx::MainLoop();
exit;

### Functions

## GUI building routines

# Main menu
# FIXME: Abstract this out to some kind of hash; e.g.,
# %menu = ( -label => $label, -underline => $underline, -menu => $menu )

sub mk_menu {
    my $mw = shift;
    my $menu = $mw->new_menu;

# File menu item    
    my $file = $menu->new_menu(
        -tearoff => 0,
    );
    $menu->add_cascade(
        -label => "File",
        -underline => 0,
        -menu => $file,
    );
    $file->add_command(
        -label => "New",
        -underline => 0,
        -accelerator => "Ctrl+N",
        -command => \&new,
    );
    $mw->g_bind("<Control-n>", \&new);
    $file->add_command(
        -label => "Open",
        -underline => 0,
        -accelerator => "Ctrl+O",
        -command => \&open_file,
    );
    $mw->g_bind("<Control-o>", \&open_file);
    $file->add_command(
        -label   => "Exit",
        -underline => 1,
        -command => [\&Tkx::destroy, $mw],
    );

    # Search menu item
    my $search = $menu->new_menu(
        -tearoff => 1,
    );
    $menu->add_cascade(
        -label => "Search",
        -underline => 0,
        -menu => $search,
    );
    $search->add_command(
        -label => "Search",
        -underline => 0,
        -accelerator => "Ctrl+s",
        -command => \&search_box,
    );

    # Help menu item
    my $help = $menu->new_menu(
        -name => "help",
        -tearoff => 0,
    );
    $menu->add_cascade(
        -label => "Help",
        -underline => 0,
        -menu => $help,
    );
    # FIXME:
#    $help->add_command(
#        -label => "\u$progname Manual",
#        -command => \&show_manual,
#    );
#
#    my $about_menu = $help;
#    $about_menu->add_command(
#        -label => "About # FIXME:\u$progname",
#        -command => \&about,
#    );

    return $menu;
}

# FIXME:
#sub about {
#    Tkx::tk___messageBox(
#        -parent => $mw,
#        -title => "About \u$progname",
#        -type => "ok",
#        -icon => "info",
#        -message => "$progname v$VERSION\nV. L. Simpson 2008.  All rights reserved.",
#    );
#}


