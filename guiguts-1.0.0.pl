#!/usr/bin/perl

use warnings;
use strict;

use Tkx;

my $VERSION = "1.0.0";
my $win_title = "GuiGuts-" . $VERSION;

my ($mw, $tw);
   (my $progname = $0) =~ s,.*[\\/],,;
   my $IS_AQUA = Tkx::tk_windowingsystem() eq "aqua";
  
  Tkx::package_require("style");
  Tkx::style__use("as", -priority => 70);
  

$mw = Tkx::widget->new(".");
$mw->g_wm_title( $win_title ); 
$mw->configure(-menu => mk_menu($mw));


$tw = $mw->new_tk__text( -width => 80, -height => 24);
$tw->g_grid;
$tw->insert("1.0", "I don't work yet!");

Tkx::MainLoop();
exit;

  sub mk_menu {
      my $mw = shift;
      my $menu = $mw->new_menu;
  
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
          -label   => "Exit",
          -underline => 1,
          -command => [\&Tkx::destroy, $mw],
      ) unless $IS_AQUA;
  
      my $help = $menu->new_menu(
          -name => "help",
          -tearoff => 0,
      );
      $menu->add_cascade(
          -label => "Help",
          -underline => 0,
          -menu => $help,
      );
      $help->add_command(
          -label => "\u$progname Manual",
          -command => \&show_manual,
      );
  
      my $about_menu = $help;
      if ($IS_AQUA) {
          # On Mac OS we want about box to appear in the application
          # menu.  Anything added to a menu with the name "apple" will
          # appear in this menu.
          $about_menu = $menu->new_menu(
              -name => "apple",
          );
          $menu->add_cascade(
              -menu => $about_menu,
          );
      }
      $about_menu->add_command(
          -label => "About \u$progname",
          -command => \&about,
      );
  
      return $menu;
  }
  
  
  sub about {
      Tkx::tk___messageBox(
          -parent => $mw,
          -title => "About \u$progname",
          -type => "ok",
          -icon => "info",
          -message => "$progname v$VERSION\n" .
                      "Copyright 2005 ActiveState. " .
                      "All rights reserved.",
      );
  }

