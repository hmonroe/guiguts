#!/usr/bin/perl

use warnings;
use strict;

use Tkx;

my ($mw, $tw);

$mw = Tkx::widget->new(".");
$tw = $mw->new_tk__text( -width => 80, -height => 24);
$tw->g_grid;

Tkx::MainLoop();

