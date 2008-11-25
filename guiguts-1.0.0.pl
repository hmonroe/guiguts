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

$Tkx::TRACE = 1;

our $VERSION = "1.0.0";

my ($mw, $tw);

# Main window container
$mw = Tkx::widget->new(".");
$mw->configure(-menu => mk_menu($mw));
Tkx::wm_title($mw, "GutThing-$VERSION");

# Our text widget
my ($height, $width, $wrap) = (20, 80, "none");
$tw = $mw->new_text(
    -height => $height,
    -width => $width,
    -wrap => $wrap,
);

$tw->g_pack(
    -anchor => "center",
    -expand => 1, 
    -fill => "both",
);

$tw->g_focus;

$tw->insert("end", "If you can read this it worked");
$tw->insert("end", " but I don't do much at the moment.");
$tw->insert("end", " This is a long line that doesn't wrap.");
$tw->insert("end", " We don't wrap our lines in this editor for PPing.\n");
$tw->insert("end", "If you type here the line should scroll if you go longer than window width.\n");

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
    return $menu;
}

