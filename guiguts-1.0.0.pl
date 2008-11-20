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

use FindBin;
use lib "$FindBin::Bin/lib";
use Data::Dump;

use Tkx;
$Tkx::TRACE = 1;



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

$tw->insert("1.0", "If you can read this it worked.");

Tkx::MainLoop();
exit;

## Functions

# GUI building routines
sub mk_menu {
    my $mw = shift(@_);
    my $menu = $mw->new_menu;

    my $file = $menu->new_menu( -tearoff => 0,
    );
    $menu->add_cascade(
        -label => "File",
        -underline => 0,
        -menu => $file,
    );

    return $menu;
}


