#!/usr/bin/perl

# $Id$

# GuiGuts text editor

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
#use criticism 'gentle'; 

my $VERSION = '1.0.7';
# To debug use Devel::ptkdb perl -d:ptkdb guiguts.pl
our $debug = 0; # turn on to report debug messages. Do not commit with $debug on

use FindBin;
use lib $FindBin::Bin . "/lib";

#use Data::Dumper;
use Cwd;
use Encode;
use FileHandle;
use File::Basename;
use File::Spec::Functions qw(rel2abs);
use File::Spec::Functions qw(catfile);
use File::Spec::Functions qw(catdir);
use File::Copy;
use File::Compare;
use HTML::TokeParser;
use IPC::Open2;
use LWP::UserAgent;
use charnames();

use Tk;
use Tk::widgets qw{Balloon
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
  TextEdit
  ToolBar
};

my $APP_NAME = 'Guiguts';
our $window_title = $APP_NAME . '-' . $VERSION;

our $icondata = '
    R0lGODdhIAAgAPcAAAAAAAAAQAAAgAAA/wAgAAAgQAAggAAg/wBAAABAQABAgABA/wBgAABgQABg
    gABg/wCAAACAQACAgACA/wCgAACgQACggACg/wDAAADAQADAgADA/wD/AAD/QAD/gAD//yAAACAA
    QCAAgCAA/yAgACAgQCAggCAg/yBAACBAQCBAgCBA/yBgACBgQCBggCBg/yCAACCAQCCAgCCA/yCg
    ACCgQCCggCCg/yDAACDAQCDAgCDA/yD/ACD/QCD/gCD//0AAAEAAQEAAgEAA/0AgAEAgQEAggEAg
    /0BAAEBAQEBAgEBA/0BgAEBgQEBggEBg/0CAAECAQECAgECA/0CgAECgQECggECg/0DAAEDAQEDA
    gEDA/0D/AED/QED/gED//2AAAGAAQGAAgGAA/2AgAGAgQGAggGAg/2BAAGBAQGBAgGBA/2BgAGBg
    QGBggGBg/2CAAGCAQGCAgGCA/2CgAGCgQGCggGCg/2DAAGDAQGDAgGDA/2D/AGD/QGD/gGD//4AA
    AIAAQIAAgIAA/4AgAIAgQIAggIAg/4BAAIBAQIBAgIBA/4BgAIBgQIBggIBg/4CAAICAQICAgICA
    /4CgAICgQICggICg/4DAAIDAQIDAgIDA/4D/AID/QID/gID//6AAAKAAQKAAgKAA/6AgAKAgQKAg
    gKAg/6BAAKBAQKBAgKBA/6BgAKBgQKBggKBg/6CAAKCAQKCAgKCA/6CgAKCgQKCggKCg/6DAAKDA
    QKDAgKDA/6D/AKD/QKD/gKD//8AAAMAAQMAAgMAA/8AgAMAgQMAggMAg/8BAAMBAQMBAgMBA/8Bg
    AMBgQMBggMBg/8CAAMCAQMCAgMCA/8CgAMCgQMCggMCg/8DAAMDAQMDAgMDA/8D/AMD/QMD/gMD/
    //8AAP8AQP8AgP8A//8gAP8gQP8ggP8g//9AAP9AQP9AgP9A//9gAP9gQP9ggP9g//+AAP+AQP+A
    gP+A//+gAP+gQP+ggP+g///AAP/AQP/AgP/A////AP//QP//gP///yH5BAAAAAAALAAAAAAgACAA
    AAj/AP8JHEiwoMGDCBMqXMiwIUNJJCJKnDixDQlJD5PYErito8ePHictMYERYRtb225NWsmypctJ
    b04IaHMwyS2Vb5bo3Mmzp84TMpMUPHkrJ9CjSJMmNSAgAE2OSbZNQrpEqdKqR5sC2Cawzc2YJ56s
    VPnE6ptJl1RW1fqUxDeRJ85q60e3n62kcybNrSvJQAAAJASSkLpE7N66/bIdPYu4bqS/AAQT1ks3
    W5I2tRILOLFkUja6tS5/fgwg8r/BYyuXCGDCgJISmyfZAh1AQOskASBLXvm53+qrk1RvPuq39O5L
    dCOZKPymecw3s/u1We48p+7TUveOtaUtm/danumO19XW3Xsb49jDZ7vVuC77ftqit/+7G3TvynWj
    u2ncuxb99MkpEUkbJbgRXD+1vJeEG5EkUQJ0dOFmGmrJGXCCCXLRVYKCJnTIWGLXUdhPPs2ttNdj
    b1T2Rl7IRRiiSvJ5V1c2sJ1w3339xJIbem0oMckTmTVWS41A4Zhcbn89tU0AT1TVRiy11BLJasMd
    hVmUBNYGGVddmUCcAGBWuVSYFrJVUAlAMWVAh2y26WZrWgVmEGx+IWnnnXgCllAbSJbm55+A+vlU
    QttYFOihgLXBpUOMNuqoQQEBADs=
    ';

### Custom Guiguts modules
use Guiguts::ASCIITables;
use Guiguts::ErrorCheck;
use Guiguts::FileMenu;
use Guiguts::Footnotes;
use Guiguts::Greek;
use Guiguts::Greekgifs;
use Guiguts::HelpMenu;
use Guiguts::Highlight;
use Guiguts::HTMLConvert;
use Guiguts::LineNumberText;
use Guiguts::MenuStructure;
use Guiguts::MultiLingual;
use Guiguts::PageNumbers;
use Guiguts::PageSeparators;
use Guiguts::SearchReplaceMenu;
use Guiguts::SelectionMenu;
use Guiguts::StatusBar;
use Guiguts::TextProcessingMenu;
use Guiguts::TextUnicode;
use Guiguts::CharacterTools;
use Guiguts::Utilities;
use Guiguts::WordFrequency;

# Ignore any watchdog timer alarms. Subroutines that take a long time to
# complete can trip it
$SIG{ALRM} = 'IGNORE';
$SIG{INT} = sub { _exit() };

### Constants
my $no_proofer_url  = 'http://www.pgdp.net/phpBB2/privmsg.php?mode=post';
my $yes_proofer_url = 'http://www.pgdp.net/c/stats/members/mbr_list.php?uname=';

### Application Globals
our $OS_WIN          = $^O =~ m{Win};
our $OS_MAC   		= $^O =~ m{darwin}; 
our $activecolor      = '#24baec';    #'#f2f818';
our $alpha_sort       = 'f';
our $auto_page_marks  = 1;
our $auto_show_images = 0;
our $autobackup       = 0;
our $autosave         = 0;
our $autosaveinterval = 5;
our $bkgcolor         = '#ffffff';
our $bkmkhl           = 0;
our $blocklmargin     = 5;
our $blockrmargin     = 72;
our $poetrylmargin    = 4;
our $blockwrap;
our $booklang      = 'en';
our $bold_char     = "=";
our $defaultindent = 0;
our $failedsearch  = 0;
our $fontname      = 'Courier New';
our $fontsize      = 10;
our $fontweight    = q{};
our $geometry2     = q{};
our $geometry3     = q{};
our $geometry;
our $globalaspellmode   = 'normal';

our $globalbrowserstart = $ENV{BROWSER};
if ( ! $globalbrowserstart ) { $globalbrowserstart = 'xdg-open'; }
if ( $::OS_WIN ) { $globalbrowserstart = 'start'; }
if ( $OS_MAC ) { $globalbrowserstart = 'open'; }

our $globalfirefoxstart = 'firefox';
if( $OS_MAC ) { $globalbrowserstart = 'open -a firefox'; }

our $globalimagepath        = q{};
our $globallastpath         = q{};
our $globalspelldictopt     = q{};
our $globalspellpath        = q{};
our $globalviewerpath       = q{};
our $globalprojectdirectory = q{};
our @gsopt;
our $highlightcolor         = '#a08dfc';
our $history_size           = 20;
our $italic_char            = "_";
our $ignoreversions =
  "revision";    #ignore revisions by default but not major or minor versions
our $ignoreversionnumber = "";       #ignore a specific version
our $jeebiesmode         = 'p';
our $lastversioncheck    = time();
our $lmargin             = 1;
our $markupthreshold     = 4;
our $nobell              = 0;
our $nohighlights        = 0;
our $notoolbar           = 0;
our $intelligentWF       = 0;
our $operationinterrupt;
our $pngspath         = q{};
our $projectid        = q{};
our $regexpentry      = q();
our $rmargin          = 72;
our $rwhyphenspace    = 1;
our $scannos_highlighted=0;
our $scannoslist      = q{wordlist/en-common.txt};
our $scannoslistpath  = q{wordlist};
our $scannospath      = q{};
our $scannosearch     = 0;
our $scrollupdatespd  = 40;
our $searchendindex   = 'end';
our $searchstartindex = '1.0';
our $multiterm        = 0;
our $spellindexbkmrk  = q{};
our $stayontop        = 0;
our $suspectindex;
our $toolside            = 'bottom';
our $useppwizardmenus    = 0;
our $usemenutwo          = 0;
our $utffontname         = 'Courier New';
our $utffontsize         = 14;
our $verboseerrorchecks  = 0;
our $vislnnm             = 0;
our $w3cremote           = 0;
our $wfstayontop         = 0;

# These are set to the default Windows values in initialize()
our $gutcommand          = '';
our $jeebiescommand      = '';
our $tidycommand         = '';
our $validatecommand     = '';
our $validatecsscommand  = '';
our $gnutenbergdirectory = '';

our %gc;
our %jeeb;
our %pagenumbers;
our %projectdict;
our %proofers;
our %reghints = ();
our %scannoslist;
our %geometryhash;    #Geometry of windows in one hash.
$geometryhash{wfpop} = q{};

our @bookmarks = ( 0, 0, 0, 0, 0, 0 );
our @gcopt = ( 0, 0, 0, 0, 0, 0, 1, 0, 1 );
our @joinundolist;
our @joinredolist;
our @multidicts          = ();
our @mygcview;
our @operations;
our @pageindex;
our @recentfile;

@recentfile = ('README.txt');

our @replace_history;
our @search_history;
our @sopt = ( 0, 0, 0, 0, 0 );    # default is not whole word search
our @extops = ( 
        { 
         'label'   => 'Open current file in its default program', 
         'command' => "$globalbrowserstart \$d\$f\$e" 
        }, 
        { 
         'label'   => 'Open current file in Firefox', 
         'command' => "$globalfirefoxstart \$d\$f\$e" 
        }, 
        { 
         'label'   => "Websters 1913 (Specialist Online Dictionary)", 
         'command' => "$globalbrowserstart http://www.specialist-online-dictionary.com/websters/headword_search.cgi?query=\$t" 
        }, 
        { 
         'label'   => "Websters 1828 American Dictionary", 
         'command' => "$globalbrowserstart http://www.1828-dictionary.com/d/word/\$t" 
        }, 
        { 
         'label'   => 'Onelook.com (several dictionaries)', 
         'command' => "$globalbrowserstart http://www.onelook.com/?ls=a&w=\$t" 
        }, 
        { 
         'label'   => 'Shape Catcher (Unicode character finder)', 
         'command' => "$globalbrowserstart http://shapecatcher.com/" 
        }, 
        { 
         'label'   => 'W3C Markup Validation Service', 
         'command' => "$globalbrowserstart http://validator.w3.org/" 
        }, 
        { 
         'label'   => 'W3C CSS Validation Service', 
         'command' => "$globalbrowserstart http://jigsaw.w3.org/css-validator/#validate_by_upload" 
        }, 
        { 'label' => q{}, 'command' => q{} }, 
        { 'label' => q{}, 'command' => q{} }, 
        { 'label' => q{}, 'command' => q{} }, 
); 

#All local global variables contained in one hash. # now global
our %lglobal; # need to document each variable

# $lglobal{hl_index} 	line number being scanned for highlighting

if ( eval { require Text::LevenshteinXS } ) {
	$lglobal{LevenshteinXS} = 1;
}

#else {
#	print
#"Install the module Text::LevenshteinXS for much faster harmonics sorting.\n";
#}

# load Image::Size if it is installed
if ( eval { require Image::Size; 1; } ) {
	$lglobal{ImageSize} = 1;
} else {
	$lglobal{ImageSize} = 0;
}

# FIXME: Change $top to $mw.
our $top = tkinit( -title => $window_title, );

initialize();    # Initialize a bunch of vars that need it.

$top->minsize( 440, 90 );

# Detect geometry changes for tracking
$top->bind(
	'<Configure>' => sub {
		$geometry = $top->geometry;
		$lglobal{geometryupdate} = 1;
	}
);

our $icon = $top->Photo( -format => 'gif',
						-data   => $icondata );

fontinit();    # Initialize the fonts for the two windows

utffontinit();

# Set up Main window size
unless ($geometry) {
	my $height = $top->screenheight() - 90;
	my $width  = $top->screenwidth() - 20;
	$geometry = $width . "x" . $height . "+0+0";
	$geometry = $top->geometry($geometry);
}
$top->geometry($geometry) if $geometry;

# Set up Main window layout
my $text_frame = $top->Frame->pack(
									-anchor => 'nw',
									-expand => 'yes',
									-fill   => 'both'
);

our $counter_frame =
  $text_frame->Frame->pack(
							-side   => 'bottom',
							-anchor => 'sw',
							-pady   => 2,
							-expand => 0
  );

# Frame to hold proofer names. Pack it when necessary.
my $proofer_frame = $text_frame->Frame;

our $text_font = $top->fontCreate(
								   'courier',
								   -family => "Courier New",
								   -size   => 12,
								   -weight => 'normal',
);

# The actual text widget
our $textwindow = $text_frame->LineNumberText(
	-widget          => 'TextUnicode',
	-exportselection => 'true',        # 'sel' tag is associated with selections
	-background      => $bkgcolor,
	-relief          => 'sunken',
	-font            => $lglobal{font},
	-wrap            => 'none',
	-curlinebg       => $::activecolor,
  )->pack(
		   -side   => 'bottom',
		   -anchor => 'nw',
		   -expand => 'yes',
		   -fill   => 'both'
  );

$top->protocol( 'WM_DELETE_WINDOW' => \&_exit );

$top->configure( -menu => our $menubar = $top->Menu );

# routines to call every time the text is edited
$textwindow->SetGUICallbacks(
	[
	   \&update_indicators,
	   sub {
		   return unless $nohighlights;
		   $textwindow->HighlightAllPairsBracketingCursor;
	   },
	   sub {
		   $textwindow->hidelinenum unless $vislnnm;
		 }
	]
);

# Set up the custom menus
menubuild();

# Set up the key bindings for the text widget
textbindings();

buildstatusbar($textwindow,$top);

# Load the icon into the window bar. Needs to happen late in the process
$top->Icon( -image => $icon );

$lglobal{hasfocus} = $textwindow;

toolbar_toggle();

$top->geometry($geometry) if $geometry;

( $lglobal{global_filename} ) = @ARGV;

die "ERROR: too many files specified. \n" if ( @ARGV > 1 );

if (     ( $lglobal{global_filename} )
	 and ( $lglobal{global_filename} eq 'runtests' ) )
{
	$lglobal{runtests} = 1;
}
if (@ARGV) {
	$lglobal{global_filename} = shift @ARGV;

	if ( -e $lglobal{global_filename} ) {
		my $userfn = $lglobal{global_filename};
		$top->update;
		$lglobal{global_filename} = $userfn;
		openfile( $lglobal{global_filename} );
	}

} else {
	$lglobal{global_filename} = 'No File Loaded';
}

set_autosave() if $autosave;

$textwindow->CallNextGUICallback;

$top->repeat( 200, sub { _updatesel($textwindow) } );

# Do not move from guiguts.pl; do command must be run in ::main
sub loadscannos {
	$lglobal{scannosfilename} = '';
	%scannoslist = ();
	@{ $lglobal{scannosarray} } = ();
	$lglobal{scannosindex} = 0;
	my $types = [ [ 'Scannos', ['.rc'] ], [ 'All Files', ['*'] ], ];
	$scannospath = os_normal($scannospath);
	$lglobal{scannosfilename} =
	  $top->getOpenFile(
						 -filetypes  => $types,
						 -title      => 'Scannos list?',
						 -initialdir => $scannospath
	  );
	if ( $lglobal{scannosfilename} ) {
		my ( $name, $path, $extension ) =
		  fileparse( $lglobal{scannosfilename}, '\.[^\.]*$' );
		$scannospath = $path;
		unless ( my $return = do $lglobal{scannosfilename} )
		{    # load scannos list
			unless ( defined $return ) {
				if ($@) {
					$top->messageBox(
						-icon => 'error',
						-message =>
'Could not parse scannos file, file may be corrupted.',
						-title => 'Problem with file',
						-type  => 'Ok',
					);
				} else {
					$top->messageBox(
									 -icon    => 'error',
									 -message => 'Could not find scannos file.',
									 -title   => 'Problem with file',
									 -type    => 'Ok',
					);
				}
				$lglobal{doscannos} = 0;
				return 0;
			}
		}
		foreach ( sort ( keys %scannoslist ) ) {
			push @{ $lglobal{scannosarray} }, $_;
		}
		if ( $lglobal{scannosfilename} =~ /reg/i ) {
			searchoptset(qw/0 x x 1/);
		} else {
			searchoptset(qw/x x x 0/);
		}
		return 1;
	}
}


sub fontinit {
	$lglobal{font} = "{$fontname} $fontsize $fontweight";
}

sub scrolldismiss {
	return unless $lglobal{scroller};
	$textwindow->configure( -cursor => $lglobal{oldcursor} );
	$lglobal{scroller}->destroy;
	$lglobal{scroller} = '';
	$lglobal{scroll_id}->cancel if $lglobal{scroll_id};
	$lglobal{scroll_id}     = '';
	$lglobal{scrolltrigger} = 0;
}

sub b2scroll {
	my $scrolly = $top->pointery - $top->rooty - $lglobal{scroll_y} - 8;
	my $scrollx = $top->pointerx - $top->rootx - $lglobal{scroll_x} - 8;
	my $signy   = ( abs $scrolly > 5 ) ? ( $scrolly < 0 ? -1 : 1 ) : 0;
	my $signx   = ( abs $scrollx > 5 ) ? ( $scrollx < 0 ? -1 : 1 ) : 0;
	$textwindow->configure(
						  -cursor => $lglobal{scroll_cursors}{"$signy$signx"} );
	$scrolly = ( $scrolly**2 - 25 ) / 800;
	$scrollx = ( $scrollx**2 - 25 ) / 2000;
	$lglobal{scrolltriggery} += $scrolly;

	if ( $lglobal{scrolltriggery} > 1 ) {
		$textwindow->yview( 'scroll', ( $signy * $lglobal{scrolltriggery} ),
							'units' );
		$lglobal{scrolltriggery} = 0;
	}
	$lglobal{scrolltriggerx} += $scrollx;
	if ( $lglobal{scrolltriggerx} > 1 ) {
		$textwindow->xview( 'scroll', ( $signx * $lglobal{scrolltriggerx} ),
							'units' );
		$lglobal{scrolltriggerx} = 0;
	}
}

sub findmatchingclosebracket {
	my ($startIndex) = @_;
	my $indentLevel = 1;
	my $closeIndex;

	while ($indentLevel) {
		$closeIndex =
		  $textwindow->search( '-exact', '--', ']', "$startIndex" . '+1c',
							   'end' );
		my $openIndex =
		  $textwindow->search( '-exact', '--', '[', "$startIndex" . '+1c',
							   'end' );
		if ( !$closeIndex ) {

			# no matching ]
			return $startIndex;
		}
		if ( !$openIndex ) {

			# no [
			return $closeIndex;
		}
		if ( $textwindow->compare( $openIndex, '<', $closeIndex ) ) {
			$indentLevel++;
			$startIndex = $openIndex;
		} else {
			$indentLevel--;
			$startIndex = $closeIndex;
		}
	}
	return $closeIndex;
}

sub findgreek {
	my $startIndex = shift;
	$startIndex = $textwindow->index($startIndex);
	my $chars;
	my $greekIndex =
	  $textwindow->search( '-exact', '--', '[Greek:', "$startIndex", 'end' );
	if ($greekIndex) {
		my $closeIndex = findmatchingclosebracket($greekIndex);
		return ( $greekIndex, $closeIndex );
	} else {
		return ( $greekIndex, $greekIndex );
	}
}

# Puts Greek character into the Greek popup
sub putgreek {
	my ( $attrib, $hash ) = @_;
	my $letter;
	$letter = $$hash{$attrib}[0]       if ( $lglobal{groutp} eq 'l' );
	$letter = $$hash{$attrib}[1] . ' ' if ( $lglobal{groutp} eq 'n' );
	$letter = $$hash{$attrib}[2]       if ( $lglobal{groutp} eq 'h' );
	$letter = $$hash{$attrib}[3]       if ( $lglobal{groutp} eq 'u' );
	my $spot = $lglobal{grtext}->index('insert');
	if ( $lglobal{groutp} eq 'l' and $letter eq 'y' or $letter eq 'Y' ) {

		if ( $lglobal{grtext}->get('insert -1c') =~ /[AEIOUaeiou]/ ) {
			$letter = chr( ord($letter) - 4 );
		}
	}
	$lglobal{grtext}->insert( 'insert', $letter );
	$lglobal{grtext}->markSet( 'insert', $spot . '+' . length($letter) . 'c' );
	$lglobal{grtext}->focus;
	$lglobal{grtext}->see('insert');
}

sub movegreek {
	my $phrase = $lglobal{grtext}->get( '1.0', 'end' );
	$lglobal{grtext}->delete( '1.0', 'end' );
	chomp $phrase;
	$textwindow->insert( 'insert', $phrase );
}

sub placechar {
	my ( $widget, @xy, $letter );
	@xy     = $lglobal{grpop}->pointerxy;
	$widget = $lglobal{grpop}->containing(@xy);
	my $char = $widget->cget( -text );
	$char =~ s/\s//;
	if ( $char =~ /[AaEe��IiOoYy��Rr]/ ) {
		$lglobal{buildentry}->delete( '0', 'end' );
		$lglobal{buildentry}->insert( 'end', $char );
		$lglobal{buildentry}->focus;
	}
	if ( $char =~ /[\(\)\\\/\|~+=_]/ ) {
		$lglobal{buildentry}->insert( 'end', $char );
		$lglobal{buildentry}->focus;
	}
}

sub togreektr {
	my $phrase = shift;
	$phrase =~ s/s($|\W)/\x{03C2}$1/g;
	$phrase =~ s/th/\x{03B8}/g;
	$phrase =~ s/nch/\x{03B3}\x{03C7}/g;
	$phrase =~ s/ch/\x{03C7}/g;
	$phrase =~ s/ph/\x{03C6}/g;
	$phrase =~ s/CH/\x{03A7}/gi;
	$phrase =~ s/TH/\x{0398}/gi;
	$phrase =~ s/PH/\x{03A6}/gi;
	$phrase =~ s/ng/\x{03B3}\x{03B3}/g;
	$phrase =~ s/nk/\x{03B3}\x{03BA}/g;
	$phrase =~ s/nx/\x{03B3}\x{03BE}/g;
	$phrase =~ s/rh/\x{1FE5}/g;
	$phrase =~ s/ps/\x{03C8}/g;
	$phrase =~ s/ha/\x{1F01}/g;
	$phrase =~ s/he/\x{1F11}/g;
	$phrase =~ s/h�/\x{1F21}/g;
	$phrase =~ s/hi/\x{1F31}/g;
	$phrase =~ s/ho/\x{1F41}/g;
	$phrase =~ s/hy/\x{1F51}/g;
	$phrase =~ s/h�/\x{1F61}/g;
	$phrase =~ s/ou/\x{03BF}\x{03C5}/g;
	$phrase =~ s/PS/\x{03A8}/gi;
	$phrase =~ s/HA/\x{1F09}/gi;
	$phrase =~ s/HE/\x{1F19}/gi;
	$phrase =~ s/H�|H�/\x{1F29}/g;
	$phrase =~ s/HI/\x{1F39}/gi;
	$phrase =~ s/HO/\x{1F49}/gi;
	$phrase =~ s/HY/\x{1F59}/gi;
	$phrase =~ s/H�|H�/\x{1F69}/g;
	$phrase =~ s/A/\x{0391}/g;
	$phrase =~ s/a/\x{03B1}/g;
	$phrase =~ s/B/\x{0392}/g;
	$phrase =~ s/b/\x{03B2}/g;
	$phrase =~ s/G/\x{0393}/g;
	$phrase =~ s/g/\x{03B3}/g;
	$phrase =~ s/D/\x{0394}/g;
	$phrase =~ s/d/\x{03B4}/g;
	$phrase =~ s/E/\x{0395}/g;
	$phrase =~ s/e/\x{03B5}/g;
	$phrase =~ s/Z/\x{0396}/g;
	$phrase =~ s/z/\x{03B6}/g;
	$phrase =~ s/�/\x{0397}/g;
	$phrase =~ s/�/\x{03B7}/g;
	$phrase =~ s/I/\x{0399}/g;
	$phrase =~ s/i/\x{03B9}/g;
	$phrase =~ s/K/\x{039A}/g;
	$phrase =~ s/k/\x{03BA}/g;
	$phrase =~ s/L/\x{039B}/g;
	$phrase =~ s/l/\x{03BB}/g;
	$phrase =~ s/M/\x{039C}/g;
	$phrase =~ s/m/\x{03BC}/g;
	$phrase =~ s/N/\x{039D}/g;
	$phrase =~ s/n/\x{03BD}/g;
	$phrase =~ s/X/\x{039E}/g;
	$phrase =~ s/x/\x{03BE}/g;
	$phrase =~ s/O/\x{039F}/g;
	$phrase =~ s/o/\x{03BF}/g;
	$phrase =~ s/P/\x{03A0}/g;
	$phrase =~ s/p/\x{03C0}/g;
	$phrase =~ s/R/\x{03A1}/g;
	$phrase =~ s/r/\x{03C1}/g;
	$phrase =~ s/S/\x{03A3}/g;
	$phrase =~ s/s/\x{03C3}/g;
	$phrase =~ s/T/\x{03A4}/g;
	$phrase =~ s/t/\x{03C4}/g;
	$phrase =~ s/Y/\x{03A5}/g;
	$phrase =~ s/y/\x{03C5}/g;
	$phrase =~ s/U/\x{03A5}/g;
	$phrase =~ s/u/\x{03C5}/g;
	$phrase =~ s/�/\x{03A9}/g;
	$phrase =~ s/�/\x{03C9}/g;
	$phrase =~ s/\?/\x{037E}/g;
	$phrase =~ s/;/\x{0387}/g;
	return $phrase;
}

sub betagreek {
	my ( $direction, $phrase ) = @_;
	if ( $direction eq 'unicode' ) {
		$phrase =~ s/s(\s|\n|$)/\x{03C2}$1/g;
		$phrase =~ s/th/\x{03B8}/g;
		$phrase =~ s/ph/\x{03C6}/g;
		$phrase =~ s/TH/\x{0398}/gi;
		$phrase =~ s/PH/\x{03A6}/gi;
		$phrase =~ s/u\\\+/\x{1FE2}/g;
		$phrase =~ s/u\/\+/\x{1FE3}/g;
		$phrase =~ s/u~\+/\x{1FE7}/g;
		$phrase =~ s/u\/\+/\x{03B0}/g;
		$phrase =~ s/u\)\\/\x{1F52}/g;
		$phrase =~ s/u\(\\/\x{1F53}/g;
		$phrase =~ s/u\)\//\x{1F54}/g;
		$phrase =~ s/u\(\//\x{1F55}/g;
		$phrase =~ s/u~\)/\x{1F56}/g;
		$phrase =~ s/u~\(/\x{1F57}/g;
		$phrase =~ s/U\(\\/\x{1F5B}/g;
		$phrase =~ s/U\(\//\x{1F5D}/g;
		$phrase =~ s/U~\(/\x{1F5F}/g;
		$phrase =~ s/u\+/\x{03CB}/g;
		$phrase =~ s/U\+/\x{03AB}/g;
		$phrase =~ s/u=/\x{1FE0}/g;
		$phrase =~ s/u_/\x{1FE1}/g;
		$phrase =~ s/r\)/\x{1FE4}/g;
		$phrase =~ s/r\(/\x{1FE5}/g;
		$phrase =~ s/u~/\x{1FE6}/g;
		$phrase =~ s/U=/\x{1FE8}/g;
		$phrase =~ s/U_/\x{1FE9}/g;
		$phrase =~ s/U\\/\x{1FEA}/g;
		$phrase =~ s/U\//\x{1FEB}/g;
		$phrase =~ s/u\\/\x{1F7A}/g;
		$phrase =~ s/u\//\x{1F7B}/g;
		$phrase =~ s/u\)/\x{1F50}/g;
		$phrase =~ s/u\(/\x{1F51}/g;
		$phrase =~ s/U\(/\x{1F59}/g;
		$phrase =~ s/\?/\x{037E}/g;
		$phrase =~ s/;/\x{0387}/g;
		
		my %atebkrg = reverse %{ $lglobal{grkbeta3} };
		for ( keys %atebkrg ) {
			$phrase =~ s/\Q$_\E/$atebkrg{$_}/g;
		}
		%atebkrg = reverse %{ $lglobal{grkbeta2} };
		for ( keys %atebkrg ) {
			$phrase =~ s/\Q$_\E/$atebkrg{$_}/g;
		}
		%atebkrg = reverse %{ $lglobal{grkbeta1} };
		for ( keys %atebkrg ) {
			$phrase =~ s/\Q$_\E/$atebkrg{$_}/g;
		}
		return togreektr($phrase);
	} else {
		for ( keys %{ $lglobal{grkbeta1} } ) {
			$phrase =~ s/$_/$lglobal{grkbeta1}{$_}/g;
		}
		for ( keys %{ $lglobal{grkbeta2} } ) {
			$phrase =~ s/$_/$lglobal{grkbeta2}{$_}/g;
		}
		for ( keys %{ $lglobal{grkbeta3} } ) {
			$phrase =~ s/$_/$lglobal{grkbeta3}{$_}/g;
		}
		$phrase =~ s/\x{0386}/A\//g;
		$phrase =~ s/\x{0388}/E\//g;
		$phrase =~ s/\x{0389}/�\//g;
		$phrase =~ s/\x{038C}/O\//g;
		$phrase =~ s/\x{038E}/Y\//g;
		$phrase =~ s/\x{038F}/�\//g;
		$phrase =~ s/\x{03AC}/a\//g;
		$phrase =~ s/\x{03AD}/e\//g;
		$phrase =~ s/\x{03AE}/�\//g;
		$phrase =~ s/\x{03AF}/i\//g;
		$phrase =~ s/\x{03CC}/o\//g;
		$phrase =~ s/\x{03CE}/�\//g;
		$phrase =~ s/\x{03CD}/y\//g;
		$phrase =~ s/\x{037E}/?/g;
		$phrase =~ s/\x{0387}/;/g;
	return fromgreektr($phrase);
	}
}

sub betaascii {

	# Discards the accents
	my ($phrase) = @_;
	$phrase =~ s/[\)\/\\\|\~\+=_]//g;
	$phrase =~ s/r\(/rh/g;
	$phrase =~ s/([AEIOUY��])\(/H$1/g;
	$phrase =~ s/([aeiouy��]+)\(/h$1/g;
	return $phrase;
}

sub pageadjust {
	if ( defined $lglobal{padjpop} ) {
		$lglobal{padjpop}->deiconify;
		$lglobal{padjpop}->raise;
	} else {
		my @marks = $textwindow->markNames;
		my @pages = sort grep ( /^Pg\S+$/, @marks );
		my %pagetrack;

		$lglobal{padjpop} = $top->Toplevel;
		$lglobal{padjpop}->title('Configure Page Labels');
		$geometryhash{padjpop} = ('375x500') unless $geometryhash{padjpop};
		initialize_popup_with_deletebinding('padjpop');
		my $frame0 =
		  $lglobal{padjpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n', -pady => 4 );
		unless (@pages) {
			$frame0->Label(
							-text       => 'No Page Markers Found',
							-background => $bkgcolor,
			)->pack;
			return;
		}
		my $recalc = $frame0->Button(
			-text    => 'Recalculate',
			-width   => 15,
			-command => sub {
				my ( $index, $label );
				my $style = 'Arabic';
				for my $page (@pages) {
					my ($num) = $page =~ /Pg(\S+)/;
					if ( $pagetrack{$num}[4]->cget( -text ) eq 'Start @' ) {
						$index = $pagetrack{$num}[5]->get;
					}
					if ( $pagetrack{$num}[3]->cget( -text ) eq 'Arabic' ) {
						$style = 'Arabic';
					} elsif ( $pagetrack{$num}[3]->cget( -text ) eq 'Roman' ) {
						$style = 'Roman';
					}
					if ( $style eq 'Roman' ) {
						$label = lc( roman($index) );
						$label =~ s/\.//;
					} else {
						$label = $index;
						$label =~ s/^0+// if $label and length $label;
					}
					if ( $pagetrack{$num}[4]->cget( -text ) eq 'No Count' ) {
						$pagetrack{$num}[2]->configure( -text => '' );
					} else {
						$pagetrack{$num}[2]->configure( -text => "Pg $label" );
						$index++;
					}
				}
			},
		)->grid( -row => 1, -column => 1, -padx => 5, -pady => 4 );
		$frame0->Button(
			-text    => 'Use These Values',
			-width   => 15,
			-command => sub {
				%pagenumbers = ();
				for my $page (@pages) {
					my ($num) = $page =~ /Pg(\S+)/;
					$pagenumbers{$page}{label} =
					  $pagetrack{$num}[2]->cget( -text );
					$pagenumbers{$page}{style} =
					  $pagetrack{$num}[3]->cget( -text );
					$pagenumbers{$page}{action} =
					  $pagetrack{$num}[4]->cget( -text );
					$pagenumbers{$page}{base} = $pagetrack{$num}[5]->get;
				}
				$recalc->invoke;
				$lglobal{padjpopgoem} = $lglobal{padjpop}->geometry;
				$lglobal{padjpop}->destroy;
				undef $lglobal{padjpop};
			}
		)->grid( -row => 1, -column => 2, -padx => 5 );
		my $frame1 =
		  $lglobal{padjpop}->Scrolled(
									   'Pane',
									   -scrollbars => 'se',
									   -background => $bkgcolor,
		  )->pack(
				   -expand => 1,
				   -fill   => 'both',
				   -side   => 'top',
				   -anchor => 'n'
		  );
		drag($frame1);
		$top->update;
		my $updatetemp;
		$top->Busy( -recurse => 1 );
		my $row = 0;
		for my $page (@pages) {
			my ($num) = $page =~ /Pg(\S+)/;
			$updatetemp++;
			$lglobal{padjpop}->update if ( $updatetemp == 20 );

			$pagetrack{$num}[0] = $frame1->Button(
				-text    => "Image# $num",
				-width   => 12,
				-command => [
					sub {
						openpng($textwindow,$num);
					},
				],
			)->grid( -row => $row, -column => 0, -padx => 2 );

			$pagetrack{$num}[1] =
			  $frame1->Label(
							  -text       => "Label -->",
							  -background => $bkgcolor,
			  )->grid( -row => $row, -column => 1 );

			my $temp = $num;
			$temp =~ s/^0+//;
			$pagetrack{$num}[2] =
			  $frame1->Label(
							  -text       => "Pg $temp",
							  -background => 'yellow',
			  )->grid( -row => $row, -column => 2 );

			$pagetrack{$num}[3] = $frame1->Button(
				-text => ( $page eq $pages[0] ) ? 'Arabic' : '"',
				-width   => 8,
				-command => [
					sub {
						if ( $pagetrack{ $_[0] }[3]->cget( -text ) eq 'Arabic' )
						{
							$pagetrack{ $_[0] }[3]
							  ->configure( -text => 'Roman' );
						} elsif (
							  $pagetrack{ $_[0] }[3]->cget( -text ) eq 'Roman' )
						{
							$pagetrack{ $_[0] }[3]->configure( -text => '"' );
						} elsif ( $pagetrack{ $_[0] }[3]->cget( -text ) eq '"' )
						{
							$pagetrack{ $_[0] }[3]
							  ->configure( -text => 'Arabic' );
						} else {
							$pagetrack{ $_[0] }[3]->configure( -text => '"' );
						}
					},
					$num
				],
			)->grid( -row => $row, -column => 3, -padx => 2 );
			$pagetrack{$num}[4] = $frame1->Button(
				-text => ( $page eq $pages[0] ) ? 'Start @' : '+1',
				-width   => 8,
				-command => [
					sub {
						if (
							$pagetrack{ $_[0] }[4]->cget( -text ) eq 'Start @' )
						{
							$pagetrack{ $_[0] }[4]->configure( -text => '+1' );
						} elsif (
								 $pagetrack{ $_[0] }[4]->cget( -text ) eq '+1' )
						{
							$pagetrack{ $_[0] }[4]
							  ->configure( -text => 'No Count' );
						} elsif ( $pagetrack{ $_[0] }[4]->cget( -text ) eq
								  'No Count' )
						{
							$pagetrack{ $_[0] }[4]
							  ->configure( -text => 'Start @' );
						} else {
							$pagetrack{ $_[0] }[4]->configure( -text => '+1' );
						}
					},
					$num
				],
			)->grid( -row => $row, -column => 4, -padx => 2 );
			$pagetrack{$num}[5] = $frame1->Entry(
				-width    => 8,
				-validate => 'all',
				-vcmd     => sub {
					return 0 if ( $_[0] =~ /\D/ );
					return 1;
				}
			)->grid( -row => $row, -column => 5, -padx => 2 );
			if ( $page eq $pages[0] ) {
				$pagetrack{$num}[5]->insert( 'end', $num );
			}
			$row++;
		}
		$top->Unbusy( -recurse => 1 );
		if ( defined $pagenumbers{ $pages[0] }{action}
			 and length $pagenumbers{ $pages[0] }{action} )
		{
			for my $page (@pages) {
				my ($num) = $page =~ /Pg(\S+)/;
				$pagetrack{$num}[2]
				  ->configure( -text => $pagenumbers{$page}{label} );
				$pagetrack{$num}[3]->configure(
						  -text => ( $pagenumbers{$page}{style} or 'Arabic' ) );
				$pagetrack{$num}[4]->configure(
							 -text => ( $pagenumbers{$page}{action} or '+1' ) );
				$pagetrack{$num}[5]->delete( '0', 'end' );
				$pagetrack{$num}[5]->insert( 'end', $pagenumbers{$page}{base} );
			}
		}
		$frame1->yview( 'scroll', => 1, 'units' );
		$top->update;
		$frame1->yview( 'scroll', -1, 'units' );
	}

}

sub initialize_popup_with_deletebinding {
	my $popupname = shift;
	initialize_popup_without_deletebinding($popupname);
	$lglobal{$popupname}->protocol(
		'WM_DELETE_WINDOW' => sub {
			$lglobal{$popupname}->destroy;
			undef $lglobal{$popupname};
		}
	);
}

sub initialize_popup_without_deletebinding {
	my $popupname = shift;
	$lglobal{$popupname}->geometry( $geometryhash{$popupname} )
	  if $geometryhash{$popupname};
	$lglobal{"$popupname"}->bind(
		'<Configure>' => sub {
			$geometryhash{"$popupname"} = $lglobal{"$popupname"}->geometry;
			$lglobal{geometryupdate} = 1;
		}
	);
	$lglobal{$popupname}->Icon( -image => $icon );
	if ( ($stayontop) and ( not $popupname eq "wfpop" ) ) {
		$lglobal{$popupname}->transient($top);
	}
	if ( ($wfstayontop) and ( $popupname eq "wfpop" ) ) {
		$lglobal{$popupname}->transient($top);
	}
}


## Save setting.rc file
sub savesettings {
	#print time()."savesettings\n";
	my $message = <<EOM;
# This file contains your saved settings for guiguts.
# It is automatically generated when you save your settings.
# If you delete it, all the settings will revert to defaults.
# You shouldn't ever have to edit this file manually.\n\n
EOM
	my ( $index, $savethis );
	my $thispath = $0;
	$thispath =~ s/[^\\]*$//;
	my $savefile = $thispath . 'setting.rc';
	$geometry = $top->geometry;    # unless $geometry;
	if ( open my $save_handle, '>', $savefile ) {
		print $save_handle $message;
		print $save_handle '@gcopt = (';
		print $save_handle "$_," || '0,' for @gcopt;
		print $save_handle ");\n\n";
		# a variable's value is not saved unless it is nonzero

		for (
			qw/alpha_sort activecolor auto_page_marks auto_show_images autobackup autosave autosaveinterval bkgcolor
			blocklmargin blockrmargin bold_char defaultindent failedsearch fontname fontsize fontweight geometry
			geometry2 geometry3 geometrypnumpop globalaspellmode highlightcolor history_size ignoreversionnumber
			intelligentWF ignoreversions italic_char jeebiesmode lastversioncheck lmargin multiterm nobell nohighlights
			notoolbar poetrylmargin rmargin rwhyphenspace scannos_highlighted stayontop toolside utffontname utffontsize
			useppwizardmenus usemenutwo verboseerrorchecks vislnnm w3cremote wfstayontop/
		  )
		{
			if ( eval '$' . $_ ) {
				print $save_handle "\$$_", ' ' x ( 20 - length $_ ), "= '",
				  eval '$' . $_, "';\n";
			}
		}
		print $save_handle "\n";

		for (
			qw/globallastpath globalspellpath globalspelldictopt globalviewerpath globalbrowserstart
			gutcommand jeebiescommand scannospath tidycommand validatecommand validatecsscommand gnutenbergdirectory/
		  )
		{
			if ( eval '$' . $_ ) {
				print $save_handle "\$$_", ' ' x ( 20 - length $_ ), "= '",
				  escape_problems( os_normal( eval '$' . $_ ) ), "';\n";
			}
		}

		print $save_handle ("\n\@recentfile = (\n");
		for (@recentfile) {
			print $save_handle "\t'", escape_problems($_), "',\n";
		}
		print $save_handle (");\n\n");

		print $save_handle ("\@extops = (\n");
		for my $index ( 0 .. $#extops ) {
			my $label   = escape_problems( $extops[$index]{label} );
			my $command = escape_problems( $extops[$index]{command} );
			print $save_handle
			  "\t{'label' => '$label', 'command' => '$command'},\n";
		}
		print $save_handle ");\n\n";

		#print $save_handle ("\%geometryhash = (\n");
		for ( keys %geometryhash ) {
			print $save_handle "\$geometryhash{$_} = '$geometryhash{$_}';\n";
		}
		print $save_handle "\n";

		print $save_handle '@mygcview = (';
		for (@mygcview) { print $save_handle "$_," }
		print $save_handle (");\n\n");

		print $save_handle ("\@search_history = (\n");
		my @array = @search_history;
		for my $index (@array) {
			$index =~ s/([^A-Za-z0-9 ])/'\x{'.(sprintf "%x", ord $1).'}'/eg;
			print $save_handle qq/\t"$index",\n/;
		}
		print $save_handle ");\n\n";

		print $save_handle ("\@replace_history = (\n");

		@array = @replace_history;
		for my $index (@array) {
			$index =~ s/([^A-Za-z0-9 ])/'\x{'.(sprintf "%x", ord $1).'}'/eg;
			print $save_handle qq/\t"$index",\n/;
		}
		print $save_handle ");\n\n";

		print $save_handle ("\@multidicts = (\n");
		for my $index (@multidicts) {
			print $save_handle qq/\t"$index",\n/;
		}
		print $save_handle ");\n\n1;\n";
	}
}

sub readsettings {
	if ( -e 'setting.rc' ) {
		unless ( my $return = do 'setting.rc' ) {
			open my $file, "<", "setting.rc"
			  or warn "Could not open setting file\n";
			my @file = <$file>;
			close $file;
			my $settings = '';
			for (@file) {
				$settings .= $_;
			}
			unless ( my $return = eval($settings) ) {
				if ( -e 'setting.rc' ) {
					open my $file, "<", "setting.rc"
					  or warn "Could not open setting file\n";
					my @file = <$file>;
					close $file;
					open $file, ">", "setting.err";
					print $file @file;
					close $file;
					print length($file);
				}
			}
		}
	}
}

sub os_normal {
	$_[0] =~ s|/|\\|g if $::OS_WIN && $_[0];
	return $_[0];
}

sub escape_problems {
	if ( $_[0] ) {
		$_[0] =~ s/\\+$/\\\\/g;
		$_[0] =~ s/(?!<\\)'/\\'/g;
	}
	return $_[0];
}

sub utflabel_bind {
	my ( $widget, $block, $start, $end ) = @_;
	$widget->bind(
		'<Enter>',
		sub {
			$widget->configure( -background => $::activecolor );
		}
	);
	$widget->bind( '<Leave>',
				   sub { $widget->configure( -background => $bkgcolor ); } );
	$widget->bind(
		'<ButtonPress-1>',
		sub {
			utfpopup( $block, $start, $end );
		}
	);
}

sub utfchar_bind {
	my $widget = shift;
	$widget->bind(
		'<Enter>',
		sub {
			$widget->configure( -background => $::activecolor );
		}
	);
	$widget->bind( '<Leave>',
				   sub { $widget->configure( -background => $bkgcolor ) } );
	$widget->bind(
		'<ButtonPress-3>',
		sub {
			$widget->clipboardClear;
			$widget->clipboardAppend( $widget->cget('-text') );
			$widget->configure( -relief => 'sunken' );
		}
	);
	$widget->bind(
		'<ButtonRelease-3>',
		sub {
			$widget->configure( -relief => 'flat' );
		}
	);
	$widget->bind(
		'<ButtonPress-1>',
		sub {
			$widget->configure( -relief => 'sunken' );
			$textwindow->insert( 'insert', $widget->cget('-text') );
		}
	);
	$widget->bind(
		'<ButtonRelease-1>',
		sub {
			$widget->configure( -relief => 'flat' );
		}
	);
}

sub drag {
	my $scrolledwidget = shift;
	my $corner         = $scrolledwidget->Subwidget('corner');
	my $corner_label =
	  $corner->Label( -image => $lglobal{drag_img} )
	  ->pack( -side => 'bottom', -anchor => 'se' );
	$corner_label->bind(
		'<Enter>',
		sub {
			if ($::OS_WIN) {
				$corner->configure( -cursor => 'size_nw_se' );
			} else {
				$corner->configure( -cursor => 'sizing' );
			}
		}
	);
	$corner_label->bind( '<Leave>',
						 sub { $corner->configure( -cursor => 'arrow' ) } );
	$corner_label->bind(
		'<1>',
		sub {
			( $lglobal{x}, $lglobal{y} ) = (
											$scrolledwidget->toplevel->pointerx,
											$scrolledwidget->toplevel->pointery
			);
		}
	);
	$corner_label->bind(
		'<B1-Motion>',
		sub {
			my $x =
			  $scrolledwidget->toplevel->width -
			  $lglobal{x} +
			  $scrolledwidget->toplevel->pointerx;
			my $y =
			  $scrolledwidget->toplevel->height -
			  $lglobal{y} +
			  $scrolledwidget->toplevel->pointery;
			( $lglobal{x}, $lglobal{y} ) = (
											$scrolledwidget->toplevel->pointerx,
											$scrolledwidget->toplevel->pointery
			);
			$scrolledwidget->toplevel->geometry( $x . 'x' . $y );
		}
	);
}

sub jeebiesrun {
	my $listbox = shift;
	$listbox->delete( '0', 'end' );
	savefile() if ( $textwindow->numberChanges );
	my $title = os_normal( $lglobal{global_filename} );
	my $types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
	unless ($jeebiescommand) {
		$jeebiescommand =
		  $textwindow->getOpenFile( -filetypes => $types,
									-title => 'Where is the Jeebies executable?'
		  );
	}
	return unless $jeebiescommand;
	my $jeebiesoptions = "-$jeebiesmode" . 'e';
	$jeebiescommand = os_normal($jeebiescommand);
	%jeeb           = ();
	my $mark = 0;
	$top->Busy( -recurse => 1 );
	$listbox->insert( 'end',
				 '---------------- Please wait: Processing. ----------------' );
	$listbox->update;

	my $runner = runner::tofile('results.tmp');
	$runner->run($jeebiescommand, $jeebiesoptions, $title);
	if ( not $? ) {
		open my $fh, '<', 'results.tmp';
		while ( my $line = <$fh> ) {
			$line =~ s/\n//;
			$line =~ s/^\s+/  /;
			if ($line) {
				$jeeb{$line} = '';
				my ( $linenum, $colnum );
				$linenum = $1 if ( $line =~ /Line (\d+)/ );
				$colnum  = $1 if ( $line =~ /Line \d+ column (\d+)/ );
				$mark++ if $linenum;
				$textwindow->markSet( "j$mark", "$linenum.$colnum" )
				  if $linenum;
				$jeeb{$line} = "j$mark";
				$listbox->insert( 'end', $line );
			}
		}
		unlink 'results.tmp';
	} else {
		warn "Unable to run Jeebies. $!";
	}
	$listbox->delete('0');
	$listbox->insert( 2, "  --> $mark queries." );
	$top->Unbusy( -recurse => 1 );
}

sub jeebiesview {
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	my $line = $lglobal{jelistbox}->get('active');
	return unless $line;
	if ( $line =~ /Line/ ) {
		$textwindow->see('end');
		$textwindow->see( $jeeb{$line} );
		$textwindow->markSet( 'insert', $jeeb{$line} );
		update_indicators();
	}
	$textwindow->focus;
	$lglobal{jeepop}->raise;
	$geometryhash{jeepop} = $lglobal{jeepop}->geometry;
}

sub blocks_check {
	return 1 if eval { require q(unicore/Blocks.pl) };
	my $oops = $top->DialogBox(
		-buttons => [qw[Yes No]],
		-title   => 'Critical files missing.',
		-popover => $top,
		-command => sub {
			if ( $_[0] eq 'Yes' ) {
				system "perl update_unicore.pl";
			}
		}
	);
	my $message = <<END;
Your Perl installation is missing some files\nthat are critical for some Unicode operations.
Do you want to download/install them?\n(You need to have an active internet connection.)
If running under Linux or OSX, you will probably need to run the command\n\"sudo perl /[pathto]/guiguts/update_unicore.pl\
in a terminal window for the updates to be installed correctly.
END

	$oops->add( 'Label', -text => $message )->pack;
	$oops->Show;
	return 0;
}

## No Asterisks
sub noast {
	local $/ = ' ****';
	my $phrase = shift;
	chomp $phrase;
	return $phrase;
}

## Ultra fast natural sort - wants an array
sub natural_sort_alpha {
	my $i;
	s/(\d+(,\d+)*)/pack 'aNa*', 0, length $1, $1/eg, $_ .= ' ' . $i++
	  for ( my @x = map { lc deaccent $_} @_ );
	@_[ map { (split)[-1] } sort @x ];
}

## Fast length sort with secondary natural sort - wants an array
sub natural_sort_length {
	$_->[2] =~ s/(\d+(,\d+)*)/pack 'aNa*', 0, length $1, $1/eg
	  for ( my @x = map { [ length noast($_), $_, lc deaccent $_ ] } @_ );
	map { $_->[1] } sort { $b->[0] <=> $a->[0] or $a->[2] cmp $b->[2] } @x;
}

## Fast freqency sort with secondary natural sort - wants a hash reference
sub natural_sort_freq {
	$_->[2] =~ s/(\d+(,\d+)*)/pack 'aNa*', 0, length $1, $1/eg
	  for (
			my @x =
			map { [ $_[0]->{$_}, $_, lc deaccent $_ ] } keys %{ $_[0] }
	  );
	map { $_->[1] } sort { $b->[0] <=> $a->[0] or $a->[2] cmp $b->[2] } @x;
}


## Spell Check

#needed elsewhere - load projectdict
sub spellloadprojectdict {
	getprojectdic();
	do "$lglobal{projectdictname}"
	  if $lglobal{projectdictname};    
}

# Initialize spellchecker
sub spellcheckfirst {
	@{ $lglobal{misspelledlist} } = ();
	viewpagenums() if ( $lglobal{seepagenums} );
	spellloadprojectdict();
	$lglobal{lastmatchindex} = '1.0';

	# get list of misspelled words in selection (or file if nothing selected)
	spellget_misspellings();
	my $term = $lglobal{misspelledlist}[0];    # get first misspelled term
	$lglobal{misspelledentry}->delete( '0', 'end' );
	$lglobal{misspelledentry}->insert( 'end', $term )
	  ;    # put it in the appropriate text box
	$lglobal{suggestionlabel}->configure( -text => 'Suggestions:' );
	return unless $term;    # no misspellings found, bail
	$lglobal{matchlength} = '0';
	$lglobal{matchindex} =
	  $textwindow->search(
						   -forwards,
						   -count => \$lglobal{matchlength},
						   $term, $lglobal{spellindexstart}, 'end'
	  );                    # search for the misspelled word in the text
	$lglobal{lastmatchindex} =
	  spelladjust_index( $lglobal{matchindex}, $term )
	  ;                     # find the index of the end of the match
	spelladdtexttags();     # highlight the word in the text
	update_indicators();    # update the status bar
	aspellstart();          # initialize the guess function
	spellguesses($term);    # get the guesses for the misspelling
	spellshow_guesses();    # populate the listbox with guesses

	$lglobal{hyphen_words} = ();    # hyphenated list of words
	if ( scalar( $lglobal{seenwords} ) ) {
		$lglobal{misspelledlabel}->configure( -text =>
			   "Not in Dictionary:  -  $lglobal{seenwords}->{$term} in text." );

		# collect hyphenated words for faster, more accurate spell-check later
		foreach my $word ( keys %{ $lglobal{seenwords} } ) {
			if ( $lglobal{seenwords}->{$word} >= 1 && $word =~ /-/ ) {
				$lglobal{hyphen_words}->{$word} = $lglobal{seenwords}->{$word};
			}
		}
	}
	$lglobal{nextmiss} = 0;
}

sub getprojectdic {
	return unless $lglobal{global_filename};
	my $fname = $lglobal{global_filename};
	$fname = Win32::GetLongPathName($fname) if $::OS_WIN;
	return unless $fname;
	$lglobal{projectdictname} = $fname;
	$lglobal{projectdictname} =~ s/\.[^\.]*?$/\.dic/;
	if ( $lglobal{projectdictname} eq $fname ) {
		$lglobal{projectdictname} .= '.dic';
	}
}

sub spellchecknext {
	viewpagenums() if ( $lglobal{seepagenums} );
	$textwindow->tagRemove( 'highlight', '1.0', 'end' )
	  ;    # unhighlight any higlighted text
	spellclearvars();
	$lglobal{misspelledlabel}->configure( -text => 'Not in Dictionary:' );
	unless ($nobell) {
		$textwindow->bell
		  if (
			$lglobal{nextmiss} >= ( scalar( @{ $lglobal{misspelledlist} } ) ) );
	}
	$lglobal{suggestionlabel}->configure( -text => 'Suggestions:' );
	return
	  if $lglobal{nextmiss} >= ( scalar( @{ $lglobal{misspelledlist} } ) )
	;      # no more misspelled words, bail
	$lglobal{lastmatchindex} = $textwindow->index('spellindex');

#print $lglobal{misspelledlist}[$lglobal{nextmiss}]." | $lglobal{lastmatchindex}\n";
	if (    ( $lglobal{misspelledlist}[ $lglobal{nextmiss} ] =~ /^[\xC0-\xFF]/ )
		 || ( $lglobal{misspelledlist}[ $lglobal{nextmiss} ] =~ /[\xC0-\xFF]$/ )
	  )
	{      # crappy workaround for accented character bug
		$lglobal{matchindex} = (
							 $textwindow->search(
								 -forwards,
								 -count => \$lglobal{matchlength},
								 $lglobal{misspelledlist}[ $lglobal{nextmiss} ],
								 $lglobal{lastmatchindex}, 'end'
							 )
		);
	} else {
		$lglobal{matchindex} = (
						$textwindow->search(
							-forwards, -regexp,
							-count => \$lglobal{matchlength},
							'(?<!\p{Alpha})'
							  . $lglobal{misspelledlist}[ $lglobal{nextmiss} ]
							  . '(?!\p{Alnum})', $lglobal{lastmatchindex}, 'end'
						)
		);
	}
	unless ( $lglobal{matchindex} ) {
		$lglobal{matchindex} = (
							 $textwindow->search(
								 -forwards, -exact,
								 -count => \$lglobal{matchlength},
								 $lglobal{misspelledlist}[ $lglobal{nextmiss} ],
								 $lglobal{lastmatchindex}, 'end'
							 )
		);
	}
	$lglobal{spreplaceentry}->delete( '0', 'end' )
	  ;    # remove last replacement word
	$lglobal{misspelledentry}
	  ->insert( 'end', $lglobal{misspelledlist}[ $lglobal{nextmiss} ] )
	  ;    #put the misspelled word in the spellcheck text box
	spelladdtexttags()
	  if $lglobal{matchindex};    # highlight the word in the text
	$lglobal{lastmatchindex} =
	  spelladjust_index( $lglobal{matchindex},
						 $lglobal{misspelledlist}[ $lglobal{nextmiss} ] )
	  if $lglobal{matchindex};    #get the index of the end of the match
	spellguesses( $lglobal{misspelledlist}[ $lglobal{nextmiss} ] )
	  ;                           # get a list of guesses for the misspelling
	spellshow_guesses();          # and put them in the guess list
	update_indicators();          # update the status bar
	$lglobal{spellpopup}->configure( -title => 'Current Dictionary - '
						  . ( $globalspelldictopt || 'No dictionary!' )
						  . " | $#{$lglobal{misspelledlist}} words to check." );

	if ( scalar( $lglobal{seenwords} ) ) {
		my $spell_count_case = 0;
		my $hyphen_count     = 0;
		my $cur_word         = $lglobal{misspelledlist}[ $lglobal{nextmiss} ];
		my $proper_case      = lc($cur_word);
		$proper_case =~ s/(^\w)/\U$1\E/;
		$spell_count_case += ( $lglobal{seenwords}->{ uc($cur_word) } || 0 )
		  if $cur_word ne uc($cur_word)
		;    # Add the full-uppercase version to the count
		$spell_count_case += ( $lglobal{seenwords}->{ lc($cur_word) } || 0 )
		  if $cur_word ne lc($cur_word)
		;    # Add the full-lowercase version to the count
		$spell_count_case += ( $lglobal{seenwords}->{$proper_case} || 0 )
		  if $cur_word ne
			  $proper_case;    # Add the propercase version to the count

		foreach my $hyword ( keys %{ $lglobal{hyphen_words} } ) {
			next if $hyword !~ /$cur_word/;
			if (    $hyword =~ /^$cur_word-/
				 || $hyword =~ /-$cur_word$/
				 || $hyword =~ /-$cur_word-/ )
			{
				$hyphen_count += $lglobal{hyphen_words}->{$hyword};
			}
		}
		my $spell_count_non_poss = 0;
		$spell_count_non_poss = ( $lglobal{seenwords}->{$1} || 0 )
		  if $cur_word =~ /^(.*)'s$/i;
		$spell_count_non_poss =
		  ( $lglobal{seenwords}->{ $cur_word . '\'s' } || 0 )
		  if $cur_word !~ /^(.*)'s$/i;
		$spell_count_non_poss +=
		  ( $lglobal{seenwords}->{ $cur_word . '\'S' } || 0 )
		  if $cur_word !~ /^(.*)'s$/i;
		$lglobal{misspelledlabel}->configure(
			   -text => 'Not in Dictionary:  -  '
				 . (
				   $lglobal{seenwords}
					 ->{ $lglobal{misspelledlist}[ $lglobal{nextmiss} ] } || '0'
				 )
				 . (
					 $spell_count_case + $spell_count_non_poss > 0
					 ? ", $spell_count_case, $spell_count_non_poss"
					 : ''
				 )
				 . ( $hyphen_count > 0 ? ", $hyphen_count hyphens" : '' )
				 . ' in text.'
		);
	}
	return 1;
}

sub spellgettextselection {
	return
	  $textwindow->get( $lglobal{matchindex},
						"$lglobal{matchindex}+$lglobal{matchlength}c" )
	  ;    # get the
	       # misspelled word
	       # as it appears in
	       # the text (may be
	       # checking case
	       # insensitive)
}

sub spellreplace {
	viewpagenums() if ( $lglobal{seepagenums} );
	my $replacement =
	  $lglobal{spreplaceentry}->get;    # get the word for the replacement box
	$textwindow->bell unless ( $replacement || $nobell );
	my $misspelled = $lglobal{misspelledentry}->get;
	return unless $replacement;
	$textwindow->replacewith( $lglobal{matchindex},
							  "$lglobal{matchindex}+$lglobal{matchlength}c",
							  $replacement );
	$lglobal{lastmatchindex} =
	  spelladjust_index( ( $textwindow->index( $lglobal{matchindex} ) ),
						 $replacement )
	  ;    #adjust the index to the end of the replaced word
	print OUT '$$ra ' . "$misspelled, $replacement\n";
	shift @{ $lglobal{misspelledlist} };
	spellchecknext();    # and check the next word
}

# replace all instances of a word with another, pretty straightforward
sub spellreplaceall {
	$top->Busy;
	viewpagenums() if ( $lglobal{seepagenums} );
	my $lastindex   = '1.0';
	my $misspelled  = $lglobal{misspelledentry}->get;
	my $replacement = $lglobal{spreplaceentry}->get;
	my $repmatchindex;
	$textwindow->FindAndReplaceAll( '-exact',    '-nocase',
									$misspelled, $replacement );
	$top->Unbusy;
	spellignoreall();
}

# replace the replacement word with one from the guess list
sub spellmisspelled_replace {
	viewpagenums() if ( $lglobal{seepagenums} );
	$lglobal{spreplaceentry}->delete( 0, 'end' );
	my $term = $lglobal{replacementlist}->get('active');
	$lglobal{spreplaceentry}->insert( 'end', $term );
}

# tell aspell to add a word to the personal dictionary
sub spelladdword {
	my $term = $lglobal{misspelledentry}->get;
	$textwindow->bell unless ( $term || $nobell );
	return unless $term;
	print OUT "*$term\n";
	print OUT "#\n";
}

# add a word to the project dictionary
sub spellmyaddword {
	my $term = shift;
	$textwindow->bell unless ( $term || $nobell );
	return unless $term;
	getprojectdic();
	$projectdict{$term} = '';
	open( my $dic, ">", "$lglobal{projectdictname}" );
	print $dic "\%projectdict = (\n";
	for my $term ( sort { $a cmp $b } keys %projectdict ) {
		$term =~ s/'/\\'/g;
		print $dic "'$term' => '',\n";
	}
	print $dic ");";
	close $dic;

	#print "$lglobal{projectdictname}";
}

sub spellclearvars {
	$lglobal{misspelledentry}->delete( '0', 'end' );
	$lglobal{replacementlist}->delete( 0,   'end' );
	$lglobal{spreplaceentry}->delete( '0', 'end' );
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
}

# start aspell in interactive mode, repipe stdin and stdout to file handles
sub aspellstart {
	aspellstop();
	my @cmd =
	  ( $globalspellpath, '-a', '-S', '--sug-mode', $globalaspellmode );
	push @cmd, '-d', $globalspelldictopt if $globalspelldictopt;
	$lglobal{spellpid} = open2( \*IN, \*OUT, @cmd );
	my $line = <IN>;
}

sub get_spellchecker_version {

	# the spellchecker version is not used anywhere
	return $lglobal{spellversion} if $lglobal{spellversion};
	my $aspell_version;
	my $runner = runner::tofile('aspell.tmp');
	$runner->run($globalspellpath, 'help');
	open my $aspell, '<', 'aspell.tmp';
	while (<$aspell>) {
		$aspell_version = $1 if m/^Aspell ([\d\.]+)/;
	}
	close $aspell;
	unlink 'aspell.tmp';
	return $lglobal{spellversion} = $aspell_version;
}

sub aspellstop {
	if ( $lglobal{spellpid} ) {
		close IN;
		close OUT;
		kill 9, $lglobal{spellpid}
		  if $::OS_WIN
		;    # Brute force kill the aspell process... seems to be necessary
		     # under windows
		waitpid( $lglobal{spellpid}, 0 );
		$lglobal{spellpid} = 0;
	}
}

sub spellguesses {    #feed aspell a word to get a list of guess
	my $word = shift;     # word to get guesses for
	$textwindow->Busy;    # let the user know something is happening
	@{ $lglobal{guesslist} } = ();    # clear the guesslist
	utf8::encode($word);

	print OUT $word, "\n";            # send the word to the stdout file handle
	my $list = <IN>;                  # and read the results
	$list =~
	  s/.*\: //;    # remove incidental stuff (word, index, number of guesses)
	$list =~ s/\#.*0/\*none\*/;    # oops, no guesses, put a notice in.
	chomp $list;                   # remove newline
	chop $list
	  if substr( $list, length($list) - 1, 1 ) eq
		  "\r";    # if chomp didn't take care of both \r and \n in Windows...
	@{ $lglobal{guesslist} } =
	  ( split /, /, $list );    # split the words into an array
	$list = <IN>;               # throw away extra newline
	$textwindow->Unbusy;        # done processing
}

# load the guesses into the guess list box
sub spellshow_guesses {
	$lglobal{replacementlist}->delete( 0, 'end' );
	$lglobal{replacementlist}->insert( 0, @{ $lglobal{guesslist} } );
	$lglobal{replacementlist}->activate(0);
	$lglobal{spreplaceentry}->delete( '0', 'end' );
	$lglobal{spreplaceentry}->insert( 'end', $lglobal{guesslist}[0] );
	$lglobal{replacementlist}->yview( 'scroll', 1, 'units' );
	$lglobal{replacementlist}->update;
	$lglobal{replacementlist}->yview( 'scroll', -1, 'units' );
	$lglobal{suggestionlabel}
	  ->configure( -text => @{ $lglobal{guesslist} } . ' Suggestions:' );
}

# only spell check selected text or whole file if nothing selected
sub spellcheckrange {
	viewpagenums() if ( $lglobal{seepagenums} );
	my @ranges = $textwindow->tagRanges('sel');
	$operationinterrupt = 0;
	if (@ranges) {
		$lglobal{spellindexstart} = $ranges[0];
		$lglobal{spellindexend}   = $ranges[-1];
	} else {
		$lglobal{spellindexstart} = '1.0';
		$lglobal{spellindexend}   = $textwindow->index('end');
	}
}

sub spellget_misspellings {    # get list of misspelled words
	spellcheckrange();         # get chunk of text to process
	return if ( $lglobal{spellindexstart} eq $lglobal{spellindexend} );
	$top->Busy( -recurse => 1 );    # let user know something is going on
	my $section =
	  $textwindow->get( $lglobal{spellindexstart}, $lglobal{spellindexend} )
	  ;                             # get selection
	$section =~ s/^-----File:.*//g;

	getmisspelledwords($section);

	wordfrequencybuildwordlist($textwindow);

	#wordfrequencygetmisspelled();

	if ( $#{ $lglobal{misspelledlist} } > 0 ) {
		$lglobal{spellpopup}->configure( -title => 'Current Dictionary - '
						  . ( $globalspelldictopt || '<default>' )
						  . " | $#{$lglobal{misspelledlist}} words to check." );
	} else {
		$lglobal{spellpopup}->configure( -title => 'Current Dictionary - '
								   . ( $globalspelldictopt || 'No dictionary!' )
								   . ' | No Misspelled Words Found.' );
	}
	$top->Unbusy( -recurse => 0 );    # done processing
	unlink 'checkfil.txt';
}

sub getmisspelledwords {
	if ($debug) {print "sub getmisspelledwords\n";}
    $lglobal{misspelledlist}=();	
	my $section = shift;
	my ( $word, @templist );

	open my $save, '>:bytes', 'checkfil.txt';
	utf8::encode($section);
	print $save $section;
	close $save;
	my @spellopt = ("list", "--encoding=utf-8");
	push @spellopt, "-d", $globalspelldictopt if $globalspelldictopt;

	my $runner = runner::withfiles('checkfil.txt', 'temp.txt');
	$runner->run($globalspellpath, @spellopt);

	if ($debug) {
		print "\$globalspellpath ", $globalspellpath, "\n";
		print "\@spellopt\n";
		for my $element (@spellopt) {
		print "$element\n";
		};
		print "checkfil.txt retained\n";
	} else {
	unlink 'checkfil.txt';
	};

	open my $infile,'<', 'temp.txt';
	my ( $ln, $tmp );
	while ( $ln = <$infile> ) {
		$ln =~ s/\r\n/\n/;
		chomp $ln;
		utf8::decode($ln);
		push( @templist, $ln );
	}
	close $infile;
	
	if ($debug) {
		print "temp.txt retained\n";
	} else {
	unlink 'temp.txt';
	}

	foreach my $word (@templist) {
		next if ( exists( $projectdict{$word} ) );
		push @{ $lglobal{misspelledlist} },
		  $word;    # filter out project dictionary word list.
	}
}

# remove ignored words from checklist
sub spellignoreall {
	my $next;
	my $word = $lglobal{misspelledentry}->get;    # get word you want to ignore
	$textwindow->bell unless ( $word || $nobell );
	return unless $word;
	my @ignorelist =
	  @{ $lglobal{misspelledlist} };              # copy the misspellings array
	@{ $lglobal{misspelledlist} } = ();           # then clear it
	foreach my $next (@ignorelist)
	{    # then put all of the words you are NOT ignoring back into the
		    # misspellings list
		push @{ $lglobal{misspelledlist} }, $next
		  if ( $next ne $word )
		  ;    # inefficient but easy, and the overhead isn't THAT bad...
	}
	spellmyaddword($word);
}

sub spelladjust_index {    # get the index of the match start (row column)
	my ( $idx, $match ) = @_;
	my ( $mr, $mc ) = split /\./, $idx;
	$mc += 1;
	$textwindow->markSet( 'spellindex', "$mr.$mc" );
	return "$mr.$mc";      # and return the index of the end of the match
}

# add highlighting to selected word
sub spelladdtexttags {
	$textwindow->markSet( 'insert', $lglobal{matchindex} );
	$textwindow->tagAdd( 'highlight', $lglobal{matchindex},
						 "$lglobal{matchindex}+$lglobal{matchlength} chars" );
	$textwindow->yview('end');
	$textwindow->see( $lglobal{matchindex} );
}

sub spelladdgoodwords {
	my $ans = $top->messageBox(
		-icon    => 'warning',
		-type    => 'YesNo',
		-default => 'yes',
		-message =>
'Warning: Before adding good_words.txt first check whether they do not contain misspellings, multiple spellings, etc. Continue?'
	);
	if ( $ans =~ /no/i ) {
		return;
	}
	chdir $globallastpath;
	open( DAT, "good_words.txt" ) || die("Could not open good_words.txt!");
	my @raw_data = <DAT>;
	close(DAT);
	my $word = q{};
	foreach my $word (@raw_data) {
		spellmyaddword( substr( $word, 0, -1 ) );
	}
}

## End Spellcheck

### File Menu
### Do not move from guiguts.pl
sub openfile {    # and open it
	my $name = shift;
	return if ( $name eq '*empty*' );
	return if ( confirmempty() =~ /cancel/i );
	unless ( -e $name ) {
		my $dbox = $top->Dialog(
				  -text => 'Could not find file. Has it been moved or deleted?',
				  -bitmap  => 'error',
				  -title   => 'Could not find File.',
				  -buttons => ['Ok']
		);
		$dbox->Show;
		return;
	}
	clearvars($textwindow);
	if ( $lglobal{img_num_label} ) {
		$lglobal{img_num_label}->destroy;
		undef $lglobal{img_num_label};
	}
	if ( $lglobal{page_label} ) {
		$lglobal{page_label}->destroy;
		undef $lglobal{page_label};
	}
	if ( $lglobal{pagebutton} ) {
		$lglobal{pagebutton}->destroy;
		undef $lglobal{pagebutton};
	}
	if ( $lglobal{previmagebutton} ) {
		$lglobal{previmagebutton}->destroy;
		undef $lglobal{previmagebutton};
	}
	if ( $lglobal{proofbutton} ) {
		$lglobal{proofbutton}->destroy;
		undef $lglobal{proofbutton};
	}
	my ( $fname, $extension, $filevar );
	$textwindow->Load($name);
	( $fname, $globallastpath, $extension ) = fileparse($name);
	$textwindow->markSet( 'insert', '1.0' );
	$globallastpath           = os_normal($globallastpath);
	$name                     = os_normal($name);
	$lglobal{global_filename} = $name;
	my $binname = "$lglobal{global_filename}.bin";

	unless ( -e $binname ) {    #for backward compatibility
		$binname = $lglobal{global_filename};
		$binname =~ s/\.[^\.]*$/\.bin/;
		if ( $binname eq $lglobal{global_filename} ) { $binname .= '.bin' }
	}
	if ( -e $binname ) {
		my $markindex;
		do $binname;
		foreach my $mark ( keys %pagenumbers ) {
			$markindex = $pagenumbers{$mark}{offset};
			if ( $markindex eq '' ) {
				delete $pagenumbers{$mark};
				next;
			}
			$textwindow->markSet( $mark, $markindex );
			$textwindow->markGravity( $mark, 'left' );
		}
		for ( 1 .. 5 ) {
			if ( $bookmarks[$_] ) {
				$textwindow->markSet( 'insert', $bookmarks[$_] );
				$textwindow->markSet( "bkmk$_", $bookmarks[$_] );
				setbookmark($_);
			}
		}
		$bookmarks[0] ||= '1.0';
		$textwindow->markSet( 'insert',    $bookmarks[0] );
		$textwindow->markSet( 'spellbkmk', $spellindexbkmrk )
		  if $spellindexbkmrk;
		$textwindow->see( $bookmarks[0] );
		$textwindow->focus;
	}
	getprojectid() unless $projectid;
	_recentupdate($name);
	update_indicators();
	file_mark_pages() if $auto_page_marks;
	push @operations, ( localtime() . " - Open $lglobal{global_filename}" );
	oppopupdate() if $lglobal{oppop};
	savesettings();
	set_autosave() if $autosave;
}

### Edit Menu
sub cut {
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	return unless $range_total;
	if ( $range_total == 2 ) {
		$textwindow->clipboardCut;
	} else {
		$textwindow->addGlobStart;    # NOTE: Add to undo ring.
		$textwindow->clipboardColumnCut;
		$textwindow->addGlobEnd;      # NOTE: Add to undo ring.
	}
}

sub textcopy {
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	return unless $range_total;
	$textwindow->clipboardClear;
	if ( $range_total == 2 ) {
		$textwindow->clipboardCopy;
	} else {
		$textwindow->clipboardColumnCopy;
	}
}

# Special paste routine that will respond differently
# for overstrike/insert modes
sub paste {
	if ( $textwindow->OverstrikeMode ) {
		my @ranges = $textwindow->tagRanges('sel');
		if (@ranges) {
			my $end   = pop @ranges;
			my $start = pop @ranges;
			$textwindow->delete( $start, $end );
		}
		my $text    = $textwindow->clipboardGet;
		my $lineend = $textwindow->get( 'insert', 'insert lineend' );
		my $length  = length $text;
		$length = length $lineend if ( length $lineend < length $text );
		$textwindow->delete( 'insert', 'insert +' . ($length) . 'c' );
		$textwindow->insert( 'insert', $text );
	} else {
		$textwindow->clipboardPaste;
	}
}

### Search
sub searchpopup {
	viewpagenums() if ( $lglobal{seepagenums} );
	push @operations, ( localtime() . ' - Search & Replace' )
	  unless $lglobal{doscannos};
	push @operations, ( localtime() . ' - Stealth Scannos' )
	  if $lglobal{doscannos};
	oppopupdate() if $lglobal{oppop};
	my $aacheck;
	my $searchterm = '';
	my @ranges     = $textwindow->tagRanges('sel');
	$searchterm = $textwindow->get( $ranges[0], $ranges[1] ) if @ranges;

	if ( defined( $lglobal{searchpop} ) ) {
		$lglobal{searchpop}->deiconify;
		$lglobal{searchpop}->raise;
		$lglobal{searchpop}->focus;
		$lglobal{searchentry}->focus;
	} else {
		$lglobal{searchpop} = $top->Toplevel;
		$lglobal{searchpop}->title('Search & Replace');
		$lglobal{searchpop}->minsize( 460, 127 );
		my $sf1 =
		  $lglobal{searchpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my $searchlabel =
		  $sf1->Label( -text => 'Search Text', )
		  ->pack( -side => 'left', -anchor => 'n', -padx => 80 );
		$lglobal{searchnumlabel} =
		  $sf1->Label(
					   -text  => '',
					   -width => 20,
		  )->pack( -side => 'right', -anchor => 'e', -padx => 1 );
		my $sf11 =
		  $lglobal{searchpop}->Frame->pack(
											-side   => 'top',
											-anchor => 'w',
											-padx   => 3,
											-expand => 'y',
											-fill   => 'x'
		  );

		$sf11->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$textwindow->undo;
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			},
			-text  => 'Undo',
			-width => 6
		)->pack( -side => 'right', -anchor => 'w' );
		$lglobal{searchbutton} = $sf11->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				add_search_history(
								   $lglobal{searchentry}->get( '1.0', '1.end' ),
								   \@search_history, $history_size );
				searchtext($textwindow,$top,'');
			},
			-text  => 'Search',
			-width => 6
		  )->pack(
				   -side   => 'right',
				   -pady   => 1,
				   -padx   => 2,
				   -anchor => 'w'
		  );

		$lglobal{searchentry} =
		  $sf11->Text(
					   -background => $bkgcolor,
					   -width      => 60,
					   -height     => 1,
		  )->pack(
				   -side   => 'right',
				   -anchor => 'w',
				   -expand => 'y',
				   -fill   => 'x'
		  );

		$sf11->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				search_history( $lglobal{searchentry}, \@search_history );
			},
			-image  => $lglobal{hist_img},
			-width  => 9,
			-height => 15,
		)->pack( -side => 'right', -anchor => 'w' );

		$lglobal{regrepeat} = $lglobal{searchentry}->repeat( 500, \&reg_check );

		my $sf2 =
		  $lglobal{searchpop}->Frame->pack( -side => 'top', -anchor => 'w' );
		$lglobal{searchop1} =
		  $sf2->Checkbutton(
							 -variable    => \$sopt[1],
							 -selectcolor => $lglobal{checkcolor},
							 -text        => 'Case Insensitive'
		  )->pack( -side => 'left', -anchor => 'n', -pady => 1 );
		$lglobal{searchop0} =
		  $sf2->Checkbutton(
							 -variable => \$sopt[0],
							 -command  => [ \&searchoptset, 'x', 'x', 'x', 0 ],
							 -selectcolor => $lglobal{checkcolor},
							 -text        => 'Whole Word'
		  )->pack( -side => 'left', -anchor => 'n', -pady => 1 );
		$lglobal{searchop3} =
		  $sf2->Checkbutton(
							 -variable => \$sopt[3],
							 -command  => [ \&searchoptset, 0, 'x', 'x', 'x' ],
							 -selectcolor => $lglobal{checkcolor},
							 -text        => 'Regex'
		  )->pack( -side => 'left', -anchor => 'n', -pady => 1 );
		$lglobal{searchop2} =
		  $sf2->Checkbutton(
							 -variable    => \$sopt[2],
							 -selectcolor => $lglobal{checkcolor},
							 -text        => 'Reverse'
		  )->pack( -side => 'left', -anchor => 'n', -pady => 1 );
		$lglobal{searchop4} =
		  $sf2->Checkbutton(
							 -variable    => \$sopt[4],
							 -selectcolor => $lglobal{checkcolor},
							 -text        => 'Start at Beginning'
		  )->pack( -side => 'left', -anchor => 'n', -pady => 1 );

		$lglobal{searchop5} =
		  $sf2->Checkbutton(
							 -variable    => \$auto_show_images,
							 -selectcolor => $lglobal{checkcolor},
							 -text        => 'Show Images'
		  )->pack( -side => 'left', -anchor => 'n', -pady => 1 );

		my ( $sf13, $sf14, $sf5 );
		my $sf10 =
		  $lglobal{searchpop}->Frame->pack(
											-side   => 'top',
											-anchor => 'n',
											-expand => '1',
											-fill   => 'x'
		  );
		my $replacelabel =
		  $sf10->Label( -text => "Replacement Text\t\t", )
		  ->grid( -row => 1, -column => 1 );

		$sf10->Label( -text => 'Terms - ' )->grid( -row => 1, -column => 2 );
		$sf10->Radiobutton(
			-text     => 'single',
			-variable => \$multiterm,
			-value    => 0,
			-command  => sub {
				for ( $sf13, $sf14 ) {
					$_->packForget;
				}
			},
		)->grid( -row => 1, -column => 3 );
		$sf10->Radiobutton(
			-text     => 'multi',
			-variable => \$multiterm,
			-value    => 1,
			-command  => sub {
				for ( $sf13, $sf14 ) {
					print "$multiterm:single\n";
					if ( defined $sf5 ) {
						$_->pack(
								  -before => $sf5,
								  -side   => 'top',
								  -anchor => 'w',
								  -padx   => 3,
								  -expand => 'y',
								  -fill   => 'x'
						);
					} else {
						$_->pack(
								  -side   => 'top',
								  -anchor => 'w',
								  -padx   => 3,
								  -expand => 'y',
								  -fill   => 'x'
						);
					}
				}
			},
		)->grid( -row => 1, -column => 4 );
		my $sf12 =
		  $lglobal{searchpop}->Frame->pack(
											-side   => 'top',
											-anchor => 'w',
											-padx   => 3,
											-expand => 'y',
											-fill   => 'x'
		  );

		$sf12->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				my $temp = $lglobal{replaceentry}->get( '1.0', '1.end' );
				replaceall( $lglobal{replaceentry}->get( '1.0', '1.end' ) );
			},
			-text  => 'Rpl All',
			-width => 5
		  )->pack(
				   -side   => 'right',
				   -pady   => 1,
				   -padx   => 2,
				   -anchor => 'nw'
		  );

		$sf12->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replace( $lglobal{replaceentry}->get( '1.0', '1.end' ) );
				add_search_history(
								   $lglobal{searchentry}->get( '1.0', '1.end' ),
								   \@search_history, $history_size );
				searchtext($textwindow,$top,'');
			},
			-text  => 'R & S',
			-width => 5
		  )->pack(
				   -side   => 'right',
				   -pady   => 1,
				   -padx   => 2,
				   -anchor => 'nw'
		  );
		$sf12->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replace( $lglobal{replaceentry}->get( '1.0', '1.end' ) );
				add_search_history(
								  $lglobal{replaceentry}->get( '1.0', '1.end' ),
								  \@replace_history, $history_size );
			},
			-text  => 'Replace',
			-width => 6
		  )->pack(
				   -side   => 'right',
				   -pady   => 1,
				   -padx   => 2,
				   -anchor => 'nw'
		  );

		$lglobal{replaceentry} =
		  $sf12->Text(
					   -background => $bkgcolor,
					   -width      => 60,
					   -height     => 1,
		  )->pack(
				   -side   => 'right',
				   -anchor => 'w',
				   -padx   => 1,
				   -expand => 'y',
				   -fill   => 'x'
		  );
		$sf12->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				search_history( $lglobal{replaceentry}, \@replace_history );
			},
			-image  => $lglobal{hist_img},
			-width  => 9,
			-height => 15,
		)->pack( -side => 'right', -anchor => 'w' );
		$sf13 = $lglobal{searchpop}->Frame;

		$sf13->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replaceall( $lglobal{replaceentry1}->get( '1.0', '1.end' ) );
			},
			-text  => 'Rpl All',
			-width => 5
		  )->pack(
				   -side   => 'right',
				   -pady   => 1,
				   -padx   => 2,
				   -anchor => 'nw'
		  );

		$sf13->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replace( $lglobal{replaceentry1}->get( '1.0', '1.end' ) );
				searchtext($textwindow,$top,'');
			},
			-text  => 'R & S',
			-width => 5
		  )->pack(
				   -side   => 'right',
				   -pady   => 1,
				   -padx   => 2,
				   -anchor => 'nw'
		  );
		$sf13->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replace( $lglobal{replaceentry1}->get( '1.0', '1.end' ) );
				add_search_history(
								 $lglobal{replaceentry1}->get( '1.0', '1.end' ),
								 \@replace_history );
			},
			-text  => 'Replace',
			-width => 6
		  )->pack(
				   -side   => 'right',
				   -pady   => 1,
				   -padx   => 2,
				   -anchor => 'nw'
		  );

		$lglobal{replaceentry1} =
		  $sf13->Text(
					   -background => $bkgcolor,
					   -width      => 60,
					   -height     => 1,
		  )->pack(
				   -side   => 'right',
				   -anchor => 'w',
				   -padx   => 1,
				   -expand => 'y',
				   -fill   => 'x'
		  );
		$sf13->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				search_history( $lglobal{replaceentry1}, \@replace_history );
			},
			-image  => $lglobal{hist_img},
			-width  => 9,
			-height => 15,
		)->pack( -side => 'right', -anchor => 'w' );
		$sf14 = $lglobal{searchpop}->Frame;

		$sf14->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replaceall( $lglobal{replaceentry2}->get( '1.0', '1.end' ) );
			},
			-text  => 'Rpl All',
			-width => 5
		  )->pack(
				   -side   => 'right',
				   -pady   => 1,
				   -padx   => 2,
				   -anchor => 'nw'
		  );

		$sf14->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replace( $lglobal{replaceentry2}->get( '1.0', '1.end' ) );
				searchtext($textwindow,$top,'');
			},
			-text  => 'R & S',
			-width => 5
		  )->pack(
				   -side   => 'right',
				   -pady   => 1,
				   -padx   => 2,
				   -anchor => 'nw'
		  );
		$sf14->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replace( $lglobal{replaceentry2}->get( '1.0', '1.end' ) );
				add_search_history(
								 $lglobal{replaceentry2}->get( '1.0', '1.end' ),
								 \@replace_history );
			},
			-text  => 'Replace',
			-width => 6
		  )->pack(
				   -side   => 'right',
				   -pady   => 1,
				   -padx   => 2,
				   -anchor => 'nw'
		  );

		$lglobal{replaceentry2} =
		  $sf14->Text(
					   -background => $bkgcolor,
					   -width      => 60,
					   -height     => 1,
		  )->pack(
				   -side   => 'right',
				   -anchor => 'w',
				   -padx   => 1,
				   -expand => 'y',
				   -fill   => 'x'
		  );
		$sf14->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				search_history( $lglobal{replaceentry2}, \@replace_history );
			},
			-image  => $lglobal{hist_img},
			-width  => 9,
			-height => 15,
		)->pack( -side => 'right', -anchor => 'w' );

		if ($multiterm) {
			for ( $sf13, $sf14 ) {
				$_->pack(
						  -side   => 'top',
						  -anchor => 'w',
						  -padx   => 3,
						  -expand => 'y',
						  -fill   => 'x'
				);
			}
		}
		if ( $lglobal{doscannos} ) {
			$sf5 =
			  $lglobal{searchpop}
			  ->Frame->pack( -side => 'top', -anchor => 'n' );
			my $nextbutton = $sf5->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					$lglobal{scannosindex}++
					  unless ( $lglobal{scannosindex} >=
							   scalar( @{ $lglobal{scannosarray} } ) );
					getnextscanno();
				},
				-text  => 'Next Stealtho',
				-width => 15
			  )->pack(
					   -side   => 'left',
					   -pady   => 5,
					   -padx   => 2,
					   -anchor => 'w'
			  );
			my $nextoccurrencebutton = $sf5->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					searchtext($textwindow,$top,'');
				},
				-text  => 'Next Occurrence',
				-width => 15
			  )->pack(
					   -side   => 'left',
					   -pady   => 5,
					   -padx   => 2,
					   -anchor => 'w'
			  );
			my $lastbutton = $sf5->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					$aacheck->deselect;
					$lglobal{scannosindex}--
					  unless ( $lglobal{scannosindex} == 0 );
					getnextscanno();
				},
				-text  => 'Prev Stealtho',
				-width => 15
			  )->pack(
					   -side   => 'left',
					   -pady   => 5,
					   -padx   => 2,
					   -anchor => 'w'
			  );
			my $switchbutton =
			  $sf5->Button(
							-activebackground => $::activecolor,
							-command          => sub { swapterms() },
							-text             => 'Swap Terms',
							-width            => 15
			  )->pack(
					   -side   => 'left',
					   -pady   => 5,
					   -padx   => 2,
					   -anchor => 'w'
			  );
			my $hintbutton =
			  $sf5->Button(
							-activebackground => $::activecolor,
							-command          => sub { reghint() },
							-text             => 'Hint',
							-width            => 5
			  )->pack(
					   -side   => 'left',
					   -pady   => 5,
					   -padx   => 2,
					   -anchor => 'w'
			  );
			my $editbutton =
			  $sf5->Button(
							-activebackground => $::activecolor,
							-command          => sub { regedit() },
							-text             => 'Edit',
							-width            => 5
			  )->pack(
					   -side   => 'left',
					   -pady   => 5,
					   -padx   => 2,
					   -anchor => 'w'
			  );
			my $sf6 =
			  $lglobal{searchpop}
			  ->Frame->pack( -side => 'top', -anchor => 'n' );
			$lglobal{regtracker} = $sf6->Label( -width => 15 )->pack(
																-side => 'left',
																-pady => 5,
																-padx => 2,
																-anchor => 'w'
			);
			$aacheck =
			  $sf6->Checkbutton(
								 -text     => 'Auto Advance',
								 -variable => \$lglobal{regaa},
			  )->pack(
					   -side   => 'left',
					   -pady   => 5,
					   -padx   => 2,
					   -anchor => 'w'
			  );
		}
		$lglobal{searchpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$lglobal{regrepeat}->cancel;
				undef $lglobal{regrepeat};
				$lglobal{searchpop}->destroy;
				undef $lglobal{searchpop};
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
				undef $lglobal{hintpop} if $lglobal{hintpop};
				$scannosearch = 0;    #no longer in a scanno search
			}
		);
		$lglobal{searchpop}->Icon( -image => $icon );
		$lglobal{searchentry}->focus;
		$lglobal{searchpop}->resizable( 'yes', 'no' );
		$lglobal{searchpop}->transient($top) if $stayontop;
		$lglobal{searchpop}->Tk::bind(
			'<Return>' => sub {
				$lglobal{searchentry}->see('1.0');
				$lglobal{searchentry}->delete('1.end');
				$lglobal{searchentry}->delete( '2.0', 'end' );
				$lglobal{replaceentry}->see('1.0');
				$lglobal{replaceentry}->delete('1.end');
				$lglobal{replaceentry}->delete( '2.0', 'end' );
				searchtext($textwindow,$top);
				$top->raise;
			}
		);
		$lglobal{searchpop}->Tk::bind(
			'<Control-f>' => sub {
				$lglobal{searchentry}->see('1.0');
				$lglobal{searchentry}->delete( '2.0', 'end' );
				$lglobal{replaceentry}->see('1.0');
				$lglobal{replaceentry}->delete( '2.0', 'end' );
				searchtext($textwindow,$top);
				$top->raise;
			}
		);
		$lglobal{searchpop}->Tk::bind(
			'<Control-F>' => sub {
				$lglobal{searchentry}->see('1.0');
				$lglobal{searchentry}->delete( '2.0', 'end' );
				$lglobal{replaceentry}->see('1.0');
				$lglobal{replaceentry}->delete( '2.0', 'end' );
				searchtext($textwindow,$top);
				$top->raise;
			}
		);
		$lglobal{searchpop}->eventAdd( '<<FindNexte>>' => '<Control-Key-G>',
									   '<Control-Key-g>' );

		$lglobal{searchentry}->bind(
			'<<FindNexte>>',
			sub {
				$lglobal{searchentry}->delete('insert -1c')
				  if ( $lglobal{searchentry}->get('insert -1c') eq "\cG" );
				searchtext($textwindow,$top, $lglobal{searchentry}->get( '1.0', '1.end' ) );
				$textwindow->focus;
			}
		);

		$lglobal{searchentry}->{_MENU_}   = ();
		$lglobal{replaceentry}->{_MENU_}  = ();
		$lglobal{replaceentry1}->{_MENU_} = ();
		$lglobal{replaceentry2}->{_MENU_} = ();

		$lglobal{searchentry}->bind(
			'<FocusIn>',
			sub {
				$lglobal{hasfocus} = $lglobal{searchentry};
			}
		);
		$lglobal{replaceentry}->bind(
			'<FocusIn>',
			sub {
				$lglobal{hasfocus} = $lglobal{replaceentry};
			}
		);
		$lglobal{replaceentry1}->bind(
			'<FocusIn>',
			sub {
				$lglobal{hasfocus} = $lglobal{replaceentry1};
			}
		);
		$lglobal{replaceentry2}->bind(
			'<FocusIn>',
			sub {
				$lglobal{hasfocus} = $lglobal{replaceentry2};
			}
		);

		$lglobal{searchpop}->Tk::bind(
			'<Control-Return>' => sub {
				$lglobal{searchentry}->see('1.0');
				$lglobal{searchentry}->delete('1.end');
				$lglobal{searchentry}->delete( '2.0', 'end' );
				$lglobal{replaceentry}->see('1.0');
				$lglobal{replaceentry}->delete('1.end');
				$lglobal{replaceentry}->delete( '2.0', 'end' );
				replace( $lglobal{replaceentry}->get( '1.0', '1.end' ) );
				searchtext($textwindow,$top);
				$top->raise;
			}
		);
		$lglobal{searchpop}->Tk::bind(
			'<Shift-Return>' => sub {
				$lglobal{searchentry}->see('1.0');
				$lglobal{searchentry}->delete('1.end');
				$lglobal{searchentry}->delete( '2.0', 'end' );
				$lglobal{replaceentry}->see('1.0');
				$lglobal{replaceentry}->delete('1.end');
				$lglobal{replaceentry}->delete( '2.0', 'end' );
				replace( $lglobal{replaceentry}->get( '1.0', '1.end' ) );
				$top->raise;
			}
		);
		$lglobal{searchpop}->Tk::bind(
			'<Control-Shift-Return>' => sub {
				$lglobal{searchentry}->see('1.0');
				$lglobal{searchentry}->delete('1.end');
				$lglobal{searchentry}->delete( '2.0', 'end' );
				$lglobal{replaceentry}->see('1.0');
				$lglobal{replaceentry}->delete('1.end');
				$lglobal{replaceentry}->delete( '2.0', 'end' );
				replaceall( $lglobal{replaceentry}->get( '1.0', '1.end' ) );
				$top->raise;
			}
		);
	}
	if ( length $searchterm ) {
		$lglobal{searchentry}->delete( '1.0', 'end' );
		$lglobal{searchentry}->insert( 'end', $searchterm );
		$lglobal{searchentry}->tagAdd( 'sel', '1.0', 'end -1c' );
		searchtext($textwindow,$top,'');
	}
}

sub stealthscanno {
	$lglobal{doscannos} = 1;
	$lglobal{searchpop}->destroy if defined $lglobal{searchpop};
	undef $lglobal{searchpop};
	searchoptset(qw/1 x x 0 1/)
	  ;    # force search to begin at start of doc, whole word
	if ( loadscannos() ) {
		savesettings();
		searchpopup();
		getnextscanno();
		searchtext($textwindow,$top);
	}
	$lglobal{doscannos} = 0;
}

sub spellchecker {    # Set up spell check window
	push @operations, ( localtime() . ' - Spellcheck' );
	viewpagenums() if ( $lglobal{seepagenums} );
	oppopupdate()  if $lglobal{oppop};
	if ( defined( $lglobal{spellpopup} ) ) {    # If window already exists
		$lglobal{spellpopup}->deiconify;        # pop it up off the task bar
		$lglobal{spellpopup}->raise;            # put it on top
		$lglobal{spellpopup}->focus;            # and give it focus
		spelloptions()
		  unless $globalspellpath;    # Whoops, don't know where to find Aspell
		spellclearvars();
		spellcheckfirst();            # Start checking the spelling
	} else {                          # window doesn't exist so set it up
		$lglobal{spellpopup} = $top->Toplevel;
		$lglobal{spellpopup}
		  ->title(    'Current Dictionary - ' . $globalspelldictopt
				   || 'No dictionary!' );
		$lglobal{spellpopup}->Icon( -image => $icon );
		my $spf1 =
		  $lglobal{spellpopup}
		  ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
		$lglobal{misspelledlabel} =
		  $spf1->Label( -text => 'Not in Dictionary:', )
		  ->pack( -side => 'top', -anchor => 'n', -pady => 5 );
		$lglobal{misspelledentry} =
		  $spf1->Entry(
						-background => $bkgcolor,
						-width      => 42,
						-font       => $lglobal{font},
		  )->pack( -side => 'top', -anchor => 'n', -pady => 1 );
		my $replacelabel =
		  $spf1->Label( -text => 'Replacement Text:', )
		  ->pack( -side => 'top', -anchor => 'n', -padx => 6 );
		$lglobal{spreplaceentry} =
		  $spf1->Entry(
						-background => $bkgcolor,
						-width      => 42,
						-font       => $lglobal{font},
		  )->pack( -side => 'top', -anchor => 'n', -padx => 1 );
		$lglobal{suggestionlabel} =
		  $spf1->Label( -text => 'Suggestions:', )
		  ->pack( -side => 'top', -anchor => 'n', -pady => 5 );
		$lglobal{replacementlist} =
		  $spf1->ScrlListbox(
							  -background => $bkgcolor,
							  -scrollbars => 'osoe',
							  -font       => $lglobal{font},
							  -width      => 40,
							  -height     => 4,
		  )->pack( -side => 'top', -anchor => 'n', -padx => 6, -pady => 6 );
		my $spf2 =
		  $lglobal{spellpopup}
		  ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
		my $changebutton =
		  $spf2->Button(
						 -activebackground => $::activecolor,
						 -command          => sub { spellreplace() },
						 -text             => 'Change',
						 -width            => 14
		  )->pack(
				   -side   => 'left',
				   -pady   => 2,
				   -padx   => 3,
				   -anchor => 'nw'
		  );
		my $ignorebutton = $spf2->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				shift @{ $lglobal{misspelledlist} };
				spellchecknext();
			},
			-text  => 'Skip <Ctrl+s>',
			-width => 14
		  )->pack(
				   -side   => 'left',
				   -pady   => 2,
				   -padx   => 3,
				   -anchor => 'nw'
		  );
		my $spelloptionsbutton =
		  $spf2->Button(
						 -activebackground => $::activecolor,
						 -command          => sub { spelloptions() },
						 -text             => 'Options',
						 -width            => 14
		  )->pack(
				   -side   => 'left',
				   -pady   => 2,
				   -padx   => 3,
				   -anchor => 'nw'
		  );
		$spf2->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$spellindexbkmrk =
				  $textwindow->index( $lglobal{lastmatchindex} . '-1c' )
				  || '1.0';
				$textwindow->markSet( 'spellbkmk', $spellindexbkmrk );
				savesettings();
			},
			-text  => 'Set Bookmark',
			-width => 14,
		  )->pack(
				   -side   => 'left',
				   -pady   => 2,
				   -padx   => 3,
				   -anchor => 'nw'
		  );
		my $spf3 =
		  $lglobal{spellpopup}
		  ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
		my $replaceallbutton =
		  $spf3->Button(
						-activebackground => $::activecolor,
						-command => sub { spellreplaceall(); spellchecknext() },
						-text    => 'Change All',
						-width   => 14,
		  )->pack(
				   -side   => 'left',
				   -pady   => 2,
				   -padx   => 3,
				   -anchor => 'nw'
		  );
		my $ignoreallbutton =
		  $spf3->Button(
						 -activebackground => $::activecolor,
						 -command => sub { spellignoreall(); spellchecknext() },
						 -text    => 'Skip All <Ctrl+i>',
						 -width   => 14
		  )->pack(
				   -side   => 'left',
				   -pady   => 2,
				   -padx   => 3,
				   -anchor => 'nw'
		  );
		my $closebutton = $spf3->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				@{ $lglobal{misspelledlist} } = ();
				$lglobal{spellpopup}->destroy;
				undef $lglobal{spellpopup}; # completly remove spellcheck window
				print OUT "\cC\n"
				  if $lglobal{spellpid};    # send a quit signal to aspell
				aspellstop();               # and remove the process
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			},
			-text  => 'Close',
			-width => 14
		  )->pack(
				   -side   => 'left',
				   -pady   => 2,
				   -padx   => 3,
				   -anchor => 'nw'
		  );
		$spf3->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				return unless $spellindexbkmrk;
				$textwindow->tagRemove( 'sel',       '1.0', 'end' );
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
				$textwindow->tagAdd( 'sel', 'spellbkmk', 'end' );

				#print $textwindow->index('spellbkmk')."\n";
				spellcheckfirst();
			},
			-text  => 'Resume @ Bkmrk',
			-width => 14
		  )->pack(
				   -side   => 'left',
				   -pady   => 2,
				   -padx   => 3,
				   -anchor => 'nw'
		  );
		my $spf4 =
		  $lglobal{spellpopup}
		  ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
		my $dictmybutton = $spf4->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				spelladdgoodwords();
			},
			-text  => 'Add Goodwords To Proj. Dic.',
			-width => 22,
		  )->pack(
				   -side   => 'left',
				   -pady   => 2,
				   -padx   => 3,
				   -anchor => 'nw'
		  );
		my $showimagebutton;
		$showimagebutton = $spf4->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$auto_show_images = 1 - $auto_show_images;
				if ($auto_show_images) {
					$showimagebutton->configure( -text => 'No Images' );
				} else {
					$showimagebutton->configure( -text => 'Show Images' );
				}
			},
			-text  => 'Show Images',
			-width => 22,
		  )->pack(
				   -side   => 'left',
				   -pady   => 2,
				   -padx   => 3,
				   -anchor => 'nw'
		  );
		my $spf5 =
		  $lglobal{spellpopup}
		  ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
		my $dictaddbutton = $spf5->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				spelladdword();
				spellignoreall();
				spellchecknext();
			},
			-text  => 'Add To Aspell Dic. <Ctrl+a>',
			-width => 22,
		  )->pack(
				   -side   => 'left',
				   -pady   => 2,
				   -padx   => 3,
				   -anchor => 'nw'
		  );
		my $dictmyaddbutton = $spf5->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				spellmyaddword( $lglobal{misspelledentry}->get );
				spellignoreall();
				spellchecknext();
			},
			-text  => 'Add To Project Dic. <Ctrl+p>',
			-width => 22,
		  )->pack(
				   -side   => 'left',
				   -pady   => 2,
				   -padx   => 3,
				   -anchor => 'nw'
		  );
		$lglobal{spellpopup}->protocol(
			'WM_DELETE_WINDOW' => sub {
				@{ $lglobal{misspelledlist} } = ();
				$lglobal{spellpopup}->destroy;
				undef $lglobal{spellpopup}; # completly remove spellcheck window
				print OUT "\cC\n"
				  if $lglobal{spellpid};    # send quit signal to aspell
				aspellstop();               # and remove the process
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			}
		);
		$lglobal{spellpopup}->bind(
			'<Control-a>',
			sub {
				$lglobal{spellpopup}->focus;
				spelladdword();
				spellignoreall();
				spellchecknext();
			}
		);
		$lglobal{spellpopup}->bind(
			'<Control-p>',
			sub {
				$lglobal{spellpopup}->focus;
				spellmyaddword( $lglobal{misspelledentry}->get );
				spellignoreall();
				spellchecknext();
			}
		);
		$lglobal{spellpopup}->bind(
			'<Control-s>',
			sub {
				$lglobal{spellpopup}->focus;
				shift @{ $lglobal{misspelledlist} };
				spellchecknext();
			}
		);
		$lglobal{spellpopup}->bind(
			'<Control-i>',
			sub {
				$lglobal{spellpopup}->focus;
				spellignoreall();
				spellchecknext();
			}
		);
		$lglobal{spellpopup}->bind(
			'<Return>',
			sub {
				$lglobal{spellpopup}->focus;
				spellreplace();
			}
		);
		$lglobal{spellpopup}->transient($top) if $stayontop;
		$lglobal{replacementlist}
		  ->bind( '<Double-Button-1>', \&spellmisspelled_replace );
		$lglobal{replacementlist}->bind( '<Triple-Button-1>',
							sub { spellmisspelled_replace(); spellreplace() } );
		BindMouseWheel( $lglobal{replacementlist} );
		spelloptions()
		  unless $globalspellpath;    # Check to see if we know where Aspell is
		spellcheckfirst();            # Start the spellcheck
	}
}

# Pop up a window which will allow jumping directly to a specified line
sub gotoline {
	unless ( defined( $lglobal{gotolinepop} ) ) {
		$lglobal{gotolinepop} = $top->DialogBox(
			-buttons => [qw[Ok Cancel]],
			-title   => 'Go To Line Number',
			-popover => $top,
			-command => sub {

				no warnings 'uninitialized';
				if ( $_[0] eq 'Ok' ) {
					$lglobal{line_number} =~ s/[\D.]//g;
					my ( $last_line, $junk ) =
					  split( /\./, $textwindow->index('end') );
					( $lglobal{line_number}, $junk ) =
					  split( /\./, $textwindow->index('insert') )
					  unless $lglobal{line_number};
					$lglobal{line_number} =~ s/^\s+|\s+$//g;
					if ( $lglobal{line_number} > $last_line ) {
						$lglobal{line_number} = $last_line;
					}
					$textwindow->markSet( 'insert', "$lglobal{line_number}.0" );
					$textwindow->see('insert');
					update_indicators();
					$lglobal{gotolinepop}->destroy;
					undef $lglobal{gotolinepop};
				} else {
					$lglobal{gotolinepop}->destroy;
					undef $lglobal{gotolinepop};
				}
			}
		);
		$lglobal{gotolinepop}->Icon( -image => $icon );
		$lglobal{gotolinepop}->resizable( 'no', 'no' );
		my $frame = $lglobal{gotolinepop}->Frame->pack( -fill => 'x' );
		$frame->Label( -text => 'Enter Line number: ' )
		  ->pack( -side => 'left' );
		my $entry = $frame->Entry(
								   -background   => $bkgcolor,
								   -width        => 25,
								   -textvariable => \$lglobal{line_number},
		)->pack( -side => 'left', -fill => 'x' );
		$lglobal{gotolinepop}->Advertise( entry => $entry );
		$lglobal{gotolinepop}->Popup;
		$lglobal{gotolinepop}->Subwidget('entry')->focus;
		$lglobal{gotolinepop}->Subwidget('entry')->selectionRange( 0, 'end' );
		$lglobal{gotolinepop}->Wait;
	}
}

# Pop up a window which will allow jumping directly to a specified page
sub gotopage {
	unless ( defined( $lglobal{gotopagpop} ) ) {
		return unless %pagenumbers;
		for ( keys(%pagenumbers) ) {
			$lglobal{pagedigits} = ( length($_) - 2 );
			last;
		}
		$lglobal{gotopagpop} = $top->DialogBox(
			-buttons => [qw[Ok Cancel]],
			-title   => 'Goto Page Number',
			-popover => $top,
			-command => sub {
				if ( $_[0] eq 'Ok' ) {
					unless ( $lglobal{lastpage} ) {
						$lglobal{gotopagpop}->bell;
						$lglobal{gotopagpop}->destroy;
						undef $lglobal{gotopagpop};
						return;
					}
					if ( $lglobal{pagedigits} == 3 ) {
						$lglobal{lastpage} =
						  sprintf( "%03s", $lglobal{lastpage} );
					} elsif ( $lglobal{pagedigits} == 4 ) {
						$lglobal{lastpage} =
						  sprintf( "%04s", $lglobal{lastpage} );
					}
					unless ( exists $pagenumbers{ 'Pg' . $lglobal{lastpage} }
						  && defined $pagenumbers{ 'Pg' . $lglobal{lastpage} } )
					{
						delete $pagenumbers{ 'Pg' . $lglobal{lastpage} };
						$lglobal{gotopagpop}->bell;
						$lglobal{gotopagpop}->destroy;
						undef $lglobal{gotopagpop};
						return;
					}
					my $index = $textwindow->index( 'Pg' . $lglobal{lastpage} );
					$textwindow->markSet( 'insert', "$index +1l linestart" );
					$textwindow->see('insert');
					$textwindow->focus;
					update_indicators();
					$lglobal{gotopagpop}->destroy;
					undef $lglobal{gotopagpop};
				} else {
					$lglobal{gotopagpop}->destroy;
					undef $lglobal{gotopagpop};
				}
			}
		);
		$lglobal{gotopagpop}->resizable( 'no', 'no' );
		$lglobal{gotopagpop}->Icon( -image => $icon );
		my $frame = $lglobal{gotopagpop}->Frame->pack( -fill => 'x' );
		$frame->Label( -text => 'Enter image number: ' )
		  ->pack( -side => 'left' );
		my $entry = $frame->Entry(
								   -background   => $bkgcolor,
								   -width        => 25,
								   -textvariable => \$lglobal{lastpage}
		)->pack( -side => 'left', -fill => 'x' );
		$lglobal{gotopagpop}->Advertise( entry => $entry );
		$lglobal{gotopagpop}->Popup;
		$lglobal{gotopagpop}->Subwidget('entry')->focus;
		$lglobal{gotopagpop}->Subwidget('entry')->selectionRange( 0, 'end' );
		$lglobal{gotopagpop}->Wait;
	}
}

sub find_proofer_comment {
	my $pattern = '[**';
	my $comment = $textwindow->search( $pattern, "insert" );
	if ($comment) {
		my $index = $textwindow->index("$comment +1c");
		$textwindow->SetCursor($index);
	}
}

sub find_asterisks {
	if ( defined( $lglobal{searchpop} ) ) {
		$lglobal{searchpop}->destroy;
		undef $lglobal{searchpop};
	}
	searchpopup();
	searchoptset(qw/0 x x 1/);
	$lglobal{searchentry}->delete( '1.0', 'end' );
	$lglobal{searchentry}->insert( 'end', "(?<!/)\\*(?!/)" );
}

sub find_transliterations {
	searchpopup();
	searchoptset(qw/0 x x 1/);
	$lglobal{searchentry}->delete( '1.0', 'end' );
	$lglobal{searchentry}->insert( 'end', "\\[[^FIS\\d]" );
}

sub nextblock {
	my ( $mark, $direction ) = @_;
	unless ($searchstartindex) { $searchstartindex = '1.0' }

#use Text::Balanced qw (			extract_delimited			extract_bracketed			extract_quotelike			extract_codeblock			extract_variable			extract_tagged			extract_multiple			gen_delimited_pat			gen_extract_tagged		       );
#print extract_bracketed( "((I)(like(pie))!)", '()' );
#return;
	if ( $mark eq 'default' ) {
		if ( $direction eq 'forward' ) {
			$searchstartindex =
			  $textwindow->search( '-exact', '--', '/*', $searchstartindex,
								   'end' )
			  if $searchstartindex;
		} elsif ( $direction eq 'reverse' ) {
			$searchstartindex =
			  $textwindow->search( '-backwards', '-exact', '--', '/*',
								   $searchstartindex, '1.0' )
			  if $searchstartindex;
		}
	} elsif ( $mark eq 'indent' ) {
		if ( $direction eq 'forward' ) {
			$searchstartindex =
			  $textwindow->search( '-regexp', '--', '^\S', $searchstartindex,
								   'end' )
			  if $searchstartindex;
			$searchstartindex =
			  $textwindow->search( '-regexp', '--', '^\s', $searchstartindex,
								   'end' )
			  if $searchstartindex;
		} elsif ( $direction eq 'reverse' ) {
			$searchstartindex =
			  $textwindow->search( '-backwards', '-regexp', '--', '^\S',
								   $searchstartindex, '1.0' )
			  if $searchstartindex;
			$searchstartindex =
			  $textwindow->search( '-backwards', '-regexp', '--', '^\s',
								   $searchstartindex, '1.0' )
			  if $searchstartindex;
		}
	} elsif ( $mark eq 'stet' ) {
		if ( $direction eq 'forward' ) {
			$searchstartindex =
			  $textwindow->search( '-exact', '--', '/$', $searchstartindex,
								   'end' )
			  if $searchstartindex;
		} elsif ( $direction eq 'reverse' ) {
			$searchstartindex =
			  $textwindow->search( '-backwards', '-exact', '--', '/$',
								   $searchstartindex, '1.0' )
			  if $searchstartindex;
		}
	} elsif ( $mark eq 'block' ) {
		if ( $direction eq 'forward' ) {
			$searchstartindex =
			  $textwindow->search( '-exact', '--', '/#', $searchstartindex,
								   'end' )
			  if $searchstartindex;
		} elsif ( $direction eq 'reverse' ) {
			$searchstartindex =
			  $textwindow->search( '-backwards', '-exact', '--', '/#',
								   $searchstartindex, '1.0' )
			  if $searchstartindex;
		}
	} elsif ( $mark eq 'poetry' ) {
		if ( $direction eq 'forward' ) {
			$searchstartindex =
			  $textwindow->search( '-regexp', '--', '\/[pP]', $searchstartindex,
								   'end' )
			  if $searchstartindex;
		} elsif ( $direction eq 'reverse' ) {
			$searchstartindex =
			  $textwindow->search( '-backwards', '-regexp', '--', '\/[pP]',
								   $searchstartindex, '1.0' )
			  if $searchstartindex;
		}
	}
	$textwindow->markSet( 'insert', $searchstartindex )
	  if $searchstartindex;
	$textwindow->see($searchstartindex) if $searchstartindex;
	$textwindow->update;
	$textwindow->focus;
	if ( $direction eq 'forward' ) {
		$searchstartindex += 1;
	} elsif ( $direction eq 'reverse' ) {
		$searchstartindex -= 1;
	}
	if ( $searchstartindex = int($searchstartindex) ) {
		$searchstartindex .= '.0';
	}
	update_indicators();
}

sub orphanedbrackets {
	my $psel;
	if ( defined( $lglobal{brkpop} ) ) {
		$lglobal{brkpop}->deiconify;
		$lglobal{brkpop}->raise;
		$lglobal{brkpop}->focus;
	} else {
		$lglobal{brkpop} = $top->Toplevel;
		$lglobal{brkpop}->title('Find orphan brackets');
		initialize_popup_without_deletebinding('brkpop');

		$lglobal{brkpop}->Label( -text => 'Bracket or Markup Style' )->pack;
		my $frame = $lglobal{brkpop}->Frame->pack;
		$psel = $frame->Radiobutton(
									 -variable    => \$lglobal{brsel},
									 -selectcolor => $lglobal{checkcolor},
									 -value       => '[\(\)]',
									 -text        => '(  )',
		)->grid( -row => 1, -column => 1 );
		my $ssel =
		  $frame->Radiobutton(
							   -variable    => \$lglobal{brsel},
							   -selectcolor => $lglobal{checkcolor},
							   -value       => '[\[\]]',
							   -text        => '[  ]',
		  )->grid( -row => 1, -column => 2 );
		my $csel =
		  $frame->Radiobutton(
							   -variable    => \$lglobal{brsel},
							   -selectcolor => $lglobal{checkcolor},
							   -value       => '[\{\}]',
							   -text        => '{  }',
		  )->grid( -row => 1, -column => 3, -pady => 5 );
		my $asel =
		  $frame->Radiobutton(
							   -variable    => \$lglobal{brsel},
							   -selectcolor => $lglobal{checkcolor},
							   -value       => '[<>]',
							   -text        => '<  >',
		  )->grid( -row => 1, -column => 4, -pady => 5 );
		my $frame1 = $lglobal{brkpop}->Frame->pack;
		my $dsel =
		  $frame1->Radiobutton(
								-variable    => \$lglobal{brsel},
								-selectcolor => $lglobal{checkcolor},
								-value       => '\/\*|\*\/',
								-text        => '/* */',
		  )->grid( -row => 1, -column => 1, -pady => 5 );
		my $nsel =
		  $frame1->Radiobutton(
								-variable    => \$lglobal{brsel},
								-selectcolor => $lglobal{checkcolor},
								-value       => '\/#|#\/',
								-text        => '/# #/',
		  )->grid( -row => 1, -column => 2, -pady => 5 );
		my $stsel =
		  $frame1->Radiobutton(
								-variable    => \$lglobal{brsel},
								-selectcolor => $lglobal{checkcolor},
								-value       => '\/\$|\$\/',
								-text        => '/$ $/',
		  )->grid( -row => 1, -column => 3, -pady => 5 );
		my $frame3 = $lglobal{brkpop}->Frame->pack;
		my $parasel =
		  $frame3->Radiobutton(
								-variable    => \$lglobal{brsel},
								-selectcolor => $lglobal{checkcolor},
								-value       => '^\/[Pp]|[Pp]\/',
								-text        => '/p p/',
		  )->grid( -row => 2, -column => 1, -pady => 5 );
		my $qusel =
		  $frame3->Radiobutton(
								-variable    => \$lglobal{brsel},
								-selectcolor => $lglobal{checkcolor},
								-value       => '�|�',
								-text        => 'Angle quotes � �',
		  )->grid( -row => 2, -column => 2, -pady => 5 );

		my $gqusel =
		  $frame3->Radiobutton(
								-variable    => \$lglobal{brsel},
								-selectcolor => $lglobal{checkcolor},
								-value       => '�|�',
								-text        => 'German Angle quotes � �',
		  )->grid( -row => 3, -column => 2 );

		#		my $allqsel =
		#		  $frame3->Radiobutton(
		#								-variable    => \$lglobal{brsel},
		#								-selectcolor => $lglobal{checkcolor},
		#								-value       => 'all',
		#								-text        => 'All brackets ( )',
		#		  )->grid( -row => 3, -column => 2 );

		my $frame2 = $lglobal{brkpop}->Frame->pack;
		my $brsearchbt =
		  $frame2->Button(
						   -activebackground => $::activecolor,
						   -text             => 'Search',
						   -command          => \&brsearch,
						   -width            => 10,
		  )->grid( -row => 1, -column => 2, -pady => 5 );
		my $brnextbt = $frame2->Button(
			-activebackground => $::activecolor,
			-text             => 'Next',
			-command          => sub {
				shift @{ $lglobal{brbrackets} }
				  if @{ $lglobal{brbrackets} };
				shift @{ $lglobal{brindices} }
				  if @{ $lglobal{brindices} };
				$textwindow->bell
				  unless ( $lglobal{brbrackets}[1] || $nobell );
				return unless $lglobal{brbrackets}[1];
				brnext();
			},
			-width => 10,
		)->grid( -row => 2, -column => 2, -pady => 5 );
	}
	$lglobal{brkpop}->protocol(
		'WM_DELETE_WINDOW' => sub {
			$lglobal{brkpop}->destroy;
			undef $lglobal{brkpop};
			$textwindow->tagRemove( 'highlight', '1.0', 'end' );
		}
	);
	$lglobal{brkpop}->transient($top) if $stayontop;
	if ($psel) { $psel->select; }

	sub brsearch {
		viewpagenums() if ( $lglobal{seepagenums} );
		@{ $lglobal{brbrackets} } = ();
		@{ $lglobal{brindices} }  = ();
		$lglobal{brindex} = '1.0';
		my $brcount = 0;
		my $brlength;
		while ( $lglobal{brindex} ) {
			$lglobal{brindex} =
			  $textwindow->search(
								 '-regexp',
								 '-count' => \$brlength,
								 '--', $lglobal{brsel}, $lglobal{brindex}, 'end'
			  );
			last unless $lglobal{brindex};
			$lglobal{brbrackets}[$brcount] =
			  $textwindow->get( $lglobal{brindex},
								$lglobal{brindex} . '+' . $brlength . 'c' );
			$lglobal{brindices}[$brcount] = $lglobal{brindex};
			$brcount++;
			$lglobal{brindex} .= '+1c';
		}
		brnext() if @{ $lglobal{brbrackets} };
	}

	sub brnext {
		viewpagenums() if ( $lglobal{seepagenums} );
		$textwindow->tagRemove( 'highlight', '1.0', 'end' );
		while (1) {
			last
			  unless (
					   (
						    ( $lglobal{brbrackets}[0] =~ m{[\[\(\{<�]} )
						 && ( $lglobal{brbrackets}[1] =~ m{[\]\)\}>�]} )
					   )
					   || (    ( $lglobal{brbrackets}[0] =~ m{[\[\(\{<�]} )
							&& ( $lglobal{brbrackets}[1] =~ m{[\]\)\}>�]} ) )
					   || (    ( $lglobal{brbrackets}[0] =~ m{^\x7f*/\*} )
							&& ( $lglobal{brbrackets}[1] =~ m{^\x7f*\*/} ) )
					   || (    ( $lglobal{brbrackets}[0] =~ m{^\x7f*/\$} )
							&& ( $lglobal{brbrackets}[1] =~ m{^\x7f*\$/} ) )
					   || (    ( $lglobal{brbrackets}[0] =~ m{^\x7f*/[p]}i )
							&& ( $lglobal{brbrackets}[1] =~ m{^\x7f*[p]/}i ) )
					   || (    ( $lglobal{brbrackets}[0] =~ m{^\x7f*/#} )
							&& ( $lglobal{brbrackets}[1] =~ m{^\x7f*#/} ) )
			  );
			shift @{ $lglobal{brbrackets} };
			shift @{ $lglobal{brbrackets} };
			shift @{ $lglobal{brindices} };
			shift @{ $lglobal{brindices} };
			$lglobal{brbrackets}[0] = $lglobal{brbrackets}[0] || '';
			$lglobal{brbrackets}[1] = $lglobal{brbrackets}[1] || '';
			last unless @{ $lglobal{brbrackets} };
		}
		if ( ( $lglobal{brbrackets}[2] ) && ( $lglobal{brbrackets}[3] ) ) {
			if (    ( $lglobal{brbrackets}[0] eq $lglobal{brbrackets}[1] )
				 && ( $lglobal{brbrackets}[2] eq $lglobal{brbrackets}[3] ) )
			{
				shift @{ $lglobal{brbrackets} };
				shift @{ $lglobal{brbrackets} };
				shift @{ $lglobal{brindices} };
				shift @{ $lglobal{brindices} };
				shift @{ $lglobal{brbrackets} };
				shift @{ $lglobal{brbrackets} };
				shift @{ $lglobal{brindices} };
				shift @{ $lglobal{brindices} };
				brnext();
			}
		}
		if ( @{ $lglobal{brbrackets} } ) {
			$textwindow->markSet( 'insert', $lglobal{brindices}[0] )
			  if $lglobal{brindices}[0];
			$textwindow->see( $lglobal{brindices}[0] )
			  if $lglobal{brindices}[0];
			$textwindow->tagAdd(
								 'highlight',
								 $lglobal{brindices}[0],
								 $lglobal{brindices}[0] . '+'
								   . ( length( $lglobal{brbrackets}[0] ) ) . 'c'
			) if $lglobal{brindices}[0];
			$textwindow->tagAdd(
								 'highlight',
								 $lglobal{brindices}[1],
								 $lglobal{brindices}[1] . '+'
								   . ( length( $lglobal{brbrackets}[1] ) ) . 'c'
			) if $lglobal{brindices}[1];
			$textwindow->focus;
		}
	}
}

sub orphanedmarkup {
	searchpopup();
	searchoptset(qw/0 x x 1/);
	$lglobal{searchentry}->delete( '1.0', 'end' );

	#	$lglobal{searchentry}->insert( 'end', "\\<(\\w+)>\\n?[^<]+<(?!/\\1>)" );
	$lglobal{searchentry}->insert( 'end',
				 "<(?!tb)(\\w+)>(\\n|[^<])+<(?!/\\1>)|<(?!/?(tb|sc|[bfgi])>)" );
}

sub hilite {
	my $mark = shift;
	$lglobal{hilitemode} = 'exact' unless $lglobal{hilitemode};
	$mark = quotemeta($mark)
	  if $lglobal{hilitemode} eq 'exact';    # FIXME: uninitialized 'hilitemode'
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	my ( $index, $lastindex );
	if ( $range_total == 0 ) {
		return;
	} else {
		my $end            = pop(@ranges);
		my $start          = pop(@ranges);
		my $thisblockstart = $start;
		$lastindex = $start;
		my $thisblockend = $end;
		$textwindow->tagRemove( 'quotemark', '1.0', 'end' );
		my $length;
		while ($lastindex) {
			$index =
			  $textwindow->search(
								   '-regexp',
								   -count => \$length,
								   '--', $mark, $lastindex, $thisblockend
			  );
			$textwindow->tagAdd( 'quotemark', $index,
								 $index . ' +' . $length . 'c' )
			  if $index;
			if   ($index) { $lastindex = "$index+1c" }
			else          { $lastindex = '' }
		}
	}
}
# Popup for highlighting arbitrary characters in selection
sub hilitepopup {
	viewpagenums() if ( $lglobal{seepagenums} );
	if ( defined( $lglobal{hilitepop} ) ) {
		$lglobal{hilitepop}->deiconify;
		$lglobal{hilitepop}->raise;
		$lglobal{hilitepop}->focus;
	} else {
		$lglobal{hilitepop} = $top->Toplevel;
		$lglobal{hilitepop}->title('Character Highlight');
		initialize_popup_with_deletebinding('hilitepop');
		$lglobal{hilitemode} = 'exact';
		my $f =
		  $lglobal{hilitepop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f->Label( -text => 'Highlight Character(s) or Regex', )
		  ->pack( -side => 'top', -pady => 2, -padx => 2, -anchor => 'n' );
		my $entry = $f->Entry(
							   -width      => 40,
							   -background => $bkgcolor,
							   -font       => $lglobal{font},
							   -relief     => 'sunken',
		  )->pack(
				   -expand => 1,
				   -fill   => 'x',
				   -padx   => 3,
				   -pady   => 3,
				   -anchor => 'n'
		  );
		my $f2 =
		  $lglobal{hilitepop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f2->Radiobutton(
						  -variable    => \$lglobal{hilitemode},
						  -selectcolor => $lglobal{checkcolor},
						  -value       => 'exact',
						  -text        => 'Exact',
		)->grid( -row => 0, -column => 1 );
		$f2->Radiobutton(
						  -variable    => \$lglobal{hilitemode},
						  -selectcolor => $lglobal{checkcolor},
						  -value       => 'regex',
						  -text        => 'Regex',
		)->grid( -row => 0, -column => 2 );
		my $f3 =
		  $lglobal{hilitepop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f3->Button(
			-activebackground => $::activecolor,
			-command          => sub {

				if ( $textwindow->markExists('selstart') ) {
					$textwindow->tagAdd( 'sel', 'selstart', 'selend' );
				}
			},
			-text  => 'Previous Selection',
			-width => 16,
		)->grid( -row => 1, -column => 1, -padx => 2, -pady => 2 );

		$f3->Button(
				 -activebackground => $::activecolor,
				 -command => sub { $textwindow->tagAdd( 'sel', '1.0', 'end' ) },
				 -text    => 'Select Whole File',
				 -width   => 16,
		)->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
		$f3->Button(
					 -activebackground => $::activecolor,
					 -command          => sub { hilite( $entry->get ) },
					 -text             => 'Apply Highlights',
					 -width            => 16,
		)->grid( -row => 2, -column => 1, -padx => 2, -pady => 2 );
		$f3->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$textwindow->tagRemove( 'quotemark', '1.0', 'end' );
			},
			-text  => 'Remove Highlight',
			-width => 16,
		)->grid( -row => 2, -column => 2, -padx => 2, -pady => 2 );

	}
}

### Bookmarks

sub setbookmark {
	my $index    = '';
	my $indexb   = '';
	my $bookmark = shift;
	if ( $bookmarks[$bookmark] ) {
		$indexb = $textwindow->index("bkmk$bookmark");
	}
	$index = $textwindow->index('insert');
	if ( $bookmarks[$bookmark] ) {
		$textwindow->tagRemove( 'bkmk', $indexb, "$indexb+1c" );
	}
	if ( $index ne $indexb ) {
		$textwindow->markSet( "bkmk$bookmark", $index );
	}
	$bookmarks[$bookmark] = $index;
	$textwindow->tagAdd( 'bkmk', $index, "$index+1c" );
}

sub gotobookmark {
	my $bookmark = shift;
	$textwindow->bell unless ( $bookmarks[$bookmark] || $nobell );
	$textwindow->see("bkmk$bookmark") if $bookmarks[$bookmark];
	$textwindow->markSet( 'insert', "bkmk$bookmark" )
	  if $bookmarks[$bookmark];
	update_indicators();
	$textwindow->tagAdd( 'bkmk', "bkmk$bookmark", "bkmk$bookmark+1c" )
	  if $bookmarks[$bookmark];
}

### Selection

sub blockrewrap {
	$blockwrap = 1;
	selectrewrap( $textwindow, $lglobal{seepagenums}, $scannos_highlighted,
				  $rwhyphenspace );
	$blockwrap = 0;
}

sub asciipopup {
	viewpagenums() if ( $lglobal{seepagenums} );
	if ( defined( $lglobal{asciipop} ) ) {
		$lglobal{asciipop}->deiconify;
		$lglobal{asciipop}->raise;
		$lglobal{asciipop}->focus;
	} else {
		$lglobal{asciipop} = $top->Toplevel;
		initialize_popup_with_deletebinding('asciipop');
		$lglobal{asciipop}->title('ASCII Boxes');
		my $f =
		  $lglobal{asciipop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f->Label( -text => 'ASCII Drawing Characters', )
		  ->pack( -side => 'top', -pady => 2, -padx => 2, -anchor => 'n' );
		my $f5 =
		  $lglobal{asciipop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my ( $row, $col );
		for ( 0 .. 8 ) {
			next if $_ == 4;
			$row = int $_ / 3;
			$col = $_ % 3;
			$f5->Entry(
						-width        => 1,
						-background   => $bkgcolor,
						-font         => $lglobal{font},
						-relief       => 'sunken',
						-textvariable => \${ $lglobal{ascii} }[$_],
			  )->grid(
					   -row    => $row,
					   -column => $col,
					   -padx   => 3,
					   -pady   => 3
			  );
		}

		my $f0 =
		  $lglobal{asciipop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my $wlabel = $f0->Label(
								 -width => 16,
								 -text  => 'ASCII Box Width',
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'n' );
		my $wmentry = $f0->Entry(
								  -width        => 6,
								  -background   => $bkgcolor,
								  -relief       => 'sunken',
								  -textvariable => \$lglobal{asciiwidth},
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'n' );
		my $f1 =
		  $lglobal{asciipop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my $leftjust =
		  $f1->Radiobutton(
							-text        => 'left justified',
							-selectcolor => $lglobal{checkcolor},
							-variable    => \$lglobal{asciijustify},
							-value       => 'left',
		  )->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
		my $centerjust =
		  $f1->Radiobutton(
							-text        => 'centered',
							-selectcolor => $lglobal{checkcolor},
							-variable    => \$lglobal{asciijustify},
							-value       => 'center',
		  )->grid( -row => 2, -column => 2, -padx => 1, -pady => 2 );
		my $rightjust =
		  $f1->Radiobutton(
							-selectcolor => $lglobal{checkcolor},
							-text        => 'right justified',
							-variable    => \$lglobal{asciijustify},
							-value       => 'right',
		  )->grid( -row => 2, -column => 3, -padx => 1, -pady => 2 );
		my $asciiw =
		  $f1->Checkbutton(
							-variable    => \$lglobal{asciiwrap},
							-selectcolor => $lglobal{checkcolor},
							-text        => 'Don\'t Rewrap'
		  )->grid( -row => 3, -column => 2, -padx => 1, -pady => 2 );
		my $gobut = $f1->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				asciibox(
						  $textwindow,          $lglobal{asciiwrap},
						  $lglobal{asciiwidth}, $lglobal{ascii},
						  $lglobal{asciijustify}
				);
			},
			-text  => 'Draw Box',
			-width => 16
		)->grid( -row => 4, -column => 2, -padx => 1, -pady => 2 );

		#$lglobal{asciipop}->resizable( 'no', 'no' );

		#$lglobal{asciipop}->deiconify;
		$lglobal{asciipop}->raise;
		$lglobal{asciipop}->focus;
	}
}

sub alignpopup {
	if ( defined( $lglobal{alignpop} ) ) {
		$lglobal{alignpop}->deiconify;
		$lglobal{alignpop}->raise;
		$lglobal{alignpop}->focus;
	} else {
		$lglobal{alignpop} = $top->Toplevel;
		initialize_popup_with_deletebinding('alignpop');
		$lglobal{alignpop}->title('Align text');
		my $f =
		  $lglobal{alignpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f->Label( -text => 'String to align on (first occurence)', )
		  ->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
		my $f1 =
		  $lglobal{alignpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f1->Entry(
					-width        => 8,
					-background   => $bkgcolor,
					-font         => $lglobal{font},
					-relief       => 'sunken',
					-textvariable => \$lglobal{alignstring},
		)->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
		my $gobut = $f1->Button(
			-activebackground => $::activecolor,
			-command          => [
				sub {
					aligntext( $textwindow, $lglobal{alignstring} );
				  }
			],
			-text  => 'Align selected text',
			-width => 16
		)->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
	}
}

### Fixup

## Gutcheck
sub gutcheck {
	no warnings;
	push @operations, ( localtime() . ' - Gutcheck' );
	viewpagenums() if ( $lglobal{seepagenums} );
	oppopupdate()  if $lglobal{oppop};
	my ( $name, $path, $extension, @path );
	$textwindow->focus;
	update_indicators();
	my $title = $top->cget('title');
	return if ( $title =~ /No File Loaded/ );
	#$top->Busy( -recurse => 1 );

	# FIXME: wide character in print warning next line with unicode
	# Figure out how to determine encoding. See scratchpad.pl
	# open my $gc, ">:encoding(UTF-8)", "gutchk.tmp");
	if ( open my $gc, ">:bytes", 'gutchk.tmp' ) {
		my $count = 0;
		my $index = '1.0';
		my ($lines) = $textwindow->index('end - 1c') =~ /^(\d+)\./;
		while ( $textwindow->compare( $index, '<', 'end' ) ) {
			my $end = $textwindow->index("$index  lineend +1c");
			print $gc $textwindow->get( $index, $end );
			$index = $end;
		}
		close $gc;
	} else {
		warn "Could not open temp file for writing. $!";
		my $dialog = $top->Dialog(
				-text => 'Could not write to the '
				  . cwd()
				  . ' directory. Check for write permission or space problems.',
				-bitmap  => 'question',
				-title   => 'Gutcheck problem',
				-buttons => [qw/OK/],
		);
		$dialog->Show;
		return;
	}
	$title =~
	  s/$window_title - //; #FIXME: sub this out; this and next in the tidy code
	$title =~ s/edited - //;
	$title = os_normal($title);
	( $name, $path, $extension ) = fileparse( $title, '\.[^\.]*$' );
	my $types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
	unless ($gutcommand) {
		$gutcommand =
		  $textwindow->getOpenFile(-filetypes => $types,
								   -title => 'Where is the Gutcheck executable?'
		  );
	}
	return unless $gutcommand;
	my $gutcheckoptions = '-ey'
	  ;    # e - echo queried line. y - puts errors to stdout instead of stderr.
	if ( $gcopt[0] ) { $gutcheckoptions .= 't' }
	;      # Check common typos
	if ( $gcopt[1] ) { $gutcheckoptions .= 'x' }
	;      # "Trust no one" Paranoid mode. Queries everything
	if ( $gcopt[2] ) { $gutcheckoptions .= 'p' }
	;      # Require closure of quotes on every paragraph
	if ( $gcopt[3] ) { $gutcheckoptions .= 's' }
	;      # Force checking for matched pairs of single quotes
	if ( $gcopt[4] ) { $gutcheckoptions .= 'm' }
	;      # Ignore markup in < >
	if ( $gcopt[5] ) { $gutcheckoptions .= 'l' }
	;      # Line end checking - defaults on
	if ( $gcopt[6] ) { $gutcheckoptions .= 'v' }
	;      # Verbose - list EVERYTHING!
	if ( $gcopt[7] ) { $gutcheckoptions .= 'u' }
	;      # Use file of User-defined Typos
	if ( $gcopt[8] ) { $gutcheckoptions .= 'd' }
	;      # Ignore DP style page separators
	$gutcommand = os_normal($gutcommand);
	savesettings();

	if ( $lglobal{gcpop} ) {
		$lglobal{gclistbox}->delete( '0', 'end' );
	}
	my $runner = runner::tofile('gutrslts.tmp');
	$runner->run( $gutcommand, $gutcheckoptions, 'gutchk.tmp' );

	#$top->Unbusy;
	unlink 'gutchk.tmp';
	gcheckpop_up();
}

sub gutopts {
	$lglobal{gcdialog} =
	  $top->DialogBox( -title => 'Gutcheck Options', -buttons => ['OK'] );
	initialize_popup_without_deletebinding('gcdialog');
	my $gcopt6 = $lglobal{gcdialog}->add(
							   'Checkbutton',
							   -variable    => \$gcopt[6],
							   -selectcolor => $lglobal{checkcolor},
							   -text => '-v Enable verbose mode (Recommended).',
	)->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt0 = $lglobal{gcdialog}->add(
								  'Checkbutton',
								  -variable    => \$gcopt[0],
								  -selectcolor => $lglobal{checkcolor},
								  -text => '-t Disable check for common typos.',
	)->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt1 = $lglobal{gcdialog}->add(
										  'Checkbutton',
										  -variable    => \$gcopt[1],
										  -selectcolor => $lglobal{checkcolor},
										  -text => '-x Disable paranoid mode.',
	)->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt2 = $lglobal{gcdialog}->add(
							 'Checkbutton',
							 -variable    => \$gcopt[2],
							 -selectcolor => $lglobal{checkcolor},
							 -text => '-p Report ALL unbalanced double quotes.',
	)->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt3 = $lglobal{gcdialog}->add(
							 'Checkbutton',
							 -variable    => \$gcopt[3],
							 -selectcolor => $lglobal{checkcolor},
							 -text => '-s Report ALL unbalanced single quotes.',
	)->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt4 = $lglobal{gcdialog}->add(
										  'Checkbutton',
										  -variable    => \$gcopt[4],
										  -selectcolor => $lglobal{checkcolor},
										  -text => '-m Interpret HTML markup.',
	)->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt5 = $lglobal{gcdialog}->add(
								  'Checkbutton',
								  -variable    => \$gcopt[5],
								  -selectcolor => $lglobal{checkcolor},
								  -text => '-l Do not report non DOS newlines.',
	)->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt7 = $lglobal{gcdialog}->add(
								   'Checkbutton',
								   -variable    => \$gcopt[7],
								   -selectcolor => $lglobal{checkcolor},
								   -text => '-u Flag words from the .typ file.',
	)->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt8 = $lglobal{gcdialog}->add(
								 'Checkbutton',
								 -variable    => \$gcopt[8],
								 -selectcolor => $lglobal{checkcolor},
								 -text => '-d Ignore DP style page separators.',
	)->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	$lglobal{gcdialog}->Show;
	savesettings();
}

sub jeebiespop_up {
	my @jlines;
	viewpagenums() if ( $lglobal{seepagenums} );
	if ( $lglobal{jeepop} ) {
		$lglobal{jeepop}->deiconify;
	} else {
		$lglobal{jeepop} = $top->Toplevel;
		$lglobal{jeepop}->title('Jeebies');
		initialize_popup_with_deletebinding('jeepop');
		$lglobal{jeepop}->transient($top) if $stayontop;
		my $ptopframe = $lglobal{jeepop}->Frame->pack;
		$ptopframe->Label( -text => 'Search mode:', )
		  ->pack( -side => 'left', -padx => 2 );
		my %rbutton = ( 'Paranoid', 'p', 'Normal', '', 'Tolerant', 't' );
		for ( keys %rbutton ) {
			$ptopframe->Radiobutton(
									 -text     => $_,
									 -variable => \$jeebiesmode,
									 -value    => $rbutton{$_},
									 -command  => \&saveset,
			)->pack( -side => 'left', -padx => 2 );
		}
		$ptopframe->Button(
						  -activebackground => $::activecolor,
						  -command => sub { jeebiesrun( $lglobal{jelistbox} ) },
						  -text    => 'Re-run Jeebies',
						  -width   => 16
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 2,
				   -anchor => 'n'
		  );
		my $pframe =
		  $lglobal{jeepop}->Frame->pack( -fill => 'both', -expand => 'both', );
		$lglobal{jelistbox} =
		  $pframe->Scrolled(
							 'Listbox',
							 -scrollbars  => 'se',
							 -background  => $bkgcolor,
							 -font        => $lglobal{font},
							 -selectmode  => 'single',
							 -activestyle => 'none',
		  )->pack(
				   -anchor => 'nw',
				   -fill   => 'both',
				   -expand => 'both',
				   -padx   => 2,
				   -pady   => 2
		  );
		drag( $lglobal{jelistbox} );
		BindMouseWheel( $lglobal{jelistbox} );
		$lglobal{jelistbox}
		  ->eventAdd( '<<jview>>' => '<Button-1>', '<Return>' );
		$lglobal{jelistbox}->bind( '<<jview>>', sub { jeebiesview() } );
		$lglobal{jelistbox}->eventAdd( '<<jremove>>' => '<ButtonRelease-2>',
									   '<ButtonRelease-3>' );
		$lglobal{jelistbox}->bind(
			'<<jremove>>',
			sub {
				$lglobal{jelistbox}->activate(
										 $lglobal{jelistbox}->index(
											 '@'
											   . (
												 $lglobal{jelistbox}->pointerx -
												   $lglobal{jelistbox}->rootx
											   )
											   . ','
											   . (
												 $lglobal{jelistbox}->pointery -
												   $lglobal{jelistbox}->rooty
											   )
										 )
				);
				undef $gc{ $lglobal{jelistbox}->get('active') };
				$lglobal{jelistbox}->delete('active');
				jeebiesview();
				$lglobal{jelistbox}->selectionClear( '0', 'end' );
				$lglobal{jelistbox}->selectionSet('active');
				$lglobal{jelistbox}->after( $lglobal{delay} );
			}
		);
		jeebiesrun( $lglobal{jelistbox} );
	}
}

## End of Line Cleanup
sub endofline {
	push @operations, ( localtime() . ' - End-of-line Spaces' );
	viewpagenums() if ( $lglobal{seepagenums} );
	oppopupdate()  if $lglobal{oppop};
	my $start  = '1.0';
	my $end    = $textwindow->index('end');
	my @ranges = $textwindow->tagRanges('sel');
	if (@ranges) {
		$start = $ranges[0];
		$end   = $ranges[-1];
	}
	$operationinterrupt = 0;
	$textwindow->FindAndReplaceAll( '-regex', '-nocase', '\s+$', '' );
	update_indicators();
}

sub epubmaker {
	my $format = shift;
	if ( $lglobal{global_filename} =~ /(\w+.(rst|htm|html))$/ ) {

		print "\nBeginning epubmaker\n";
		print "Files will appear in the directory $globallastpath.\n";
		print
"Running in background with no messages that processing is complete.\n";
		my $rstfilename = $1;
		my $pwd         = getcwd();
		chdir $globallastpath;
		my $epubmakerpath = catfile( $lglobal{guigutsdirectory},
									 'python27', 'scripts',
									 'epubmaker-script.py' );
		my $pythonpath =
		  catfile( $lglobal{guigutsdirectory}, 'python27', 'python.exe' );

		if ( defined $format and (($format eq 'html') or ($format eq 'epub')) ) {
			runner($pythonpath, $epubmakerpath, "--make", $format, $rstfilename);
		} else {
			runner($pythonpath, $epubmakerpath, $rstfilename);
		}
		chdir $pwd;
	} else {
		print "Not an .rst file\n";
	}
}

sub gnutenberg {
	my $format = shift;

	print "\nBeginning Gnutenberg Press\n";
	print "Warning: This requires installing perl including LibXML, and \n";
	print "guiguts must be installed in c:\\guiguts on Windows systems.\n";
	my $pwd = getcwd();
	chdir $globallastpath;
	unless ( -d 'output' ) {
		mkdir 'output' or die;
	}
	my $gnutenbergoutput = catfile( $globallastpath, 'output' );
	chdir $gnutenbergdirectory;
	runner(
"perl", "transform.pl", "-f", $format, $lglobal{global_filename}, "$gnutenbergoutput" );
	chdir $pwd;
}

## Sidenote Fixup
sub sidenotes {
	push @operations, ( localtime() . ' - Sidenote Fixup' );
	viewpagenums() if ( $lglobal{seepagenums} );
	oppopupdate()  if $lglobal{oppop};
	$textwindow->markSet( 'sidenote', '1.0' );
	my ( $bracketndx, $nextbracketndx, $bracketstartndx, $bracketendndx,
		 $paragraphp, $paragraphn, $sidenote, $sdnoteindexstart );

	while (1) {
		$sdnoteindexstart = $textwindow->index('sidenote');
		$bracketstartndx =
		  $textwindow->search( '-regexp', '--', '\[sidenote', $sdnoteindexstart,
							   'end' );
		if ($bracketstartndx) {
			$textwindow->replacewith(
									  "$bracketstartndx+1c",
									  "$bracketstartndx+2c",
									  'S'
			);
			$textwindow->markSet( 'sidenote', "$bracketstartndx+1c" );
			next;
		}
		$textwindow->markSet( 'sidenote', '1.0' );
		last;
	}
	while (1) {
		$sdnoteindexstart = $textwindow->index('sidenote');
		$bracketstartndx =
		  $textwindow->search( '-regexp', '--', '\[Sidenote', $sdnoteindexstart,
							   'end' );
		last unless $bracketstartndx;
		$bracketndx = "$bracketstartndx+1c";
		while (1) {
			$bracketendndx =
			  $textwindow->search( '--', ']', $bracketndx, 'end' );
			$bracketendndx = $textwindow->index("$bracketstartndx+9c")
			  unless $bracketendndx;
			$bracketendndx = $textwindow->index("$bracketendndx+1c")
			  if $bracketendndx;
			$nextbracketndx =
			  $textwindow->search( '--', '[', $bracketndx, 'end' );
			if (
				 ($nextbracketndx)
				 && (
					  $textwindow->compare( $nextbracketndx, '<', $bracketendndx
					  )
				 )
			  )
			{
				$bracketndx = $bracketendndx;
				next;
			}
			last;
		}
		$textwindow->markSet( 'sidenote', $bracketendndx );
		$paragraphp =
		  $textwindow->search( '-backwards', '-regexp', '--', '^$',
							   $bracketstartndx, '1.0' );
		$paragraphn =
		  $textwindow->search( '-regexp', '--', '^$', $bracketstartndx, 'end' );
		$sidenote = $textwindow->get( $bracketstartndx, $bracketendndx );
		if ( $textwindow->get( "$bracketstartndx-2c", $bracketstartndx ) ne
			 "\n\n" )
		{
			if (
				 (
				   $textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq
				   ' '
				 )
				 || ( $textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq
					  "\n" )
			  )
			{
				$textwindow->delete( $bracketendndx, "" );
			}
			$textwindow->delete( $bracketstartndx, $bracketendndx );
			$textwindow->see($bracketstartndx);
			$textwindow->insert( "$paragraphp+1l", $sidenote . "\n\n" );
		} elsif (
				 $textwindow->compare( "$bracketendndx+1c", '<', $paragraphn ) )
		{
			if (
				 (
				   $textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq
				   ' '
				 )
				 || ( $textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq
					  "\n" )
			  )
			{
				$textwindow->delete( $bracketendndx, "$bracketendndx+1c" );
			}
			$textwindow->see($bracketstartndx);
			$textwindow->insert( $bracketendndx, "\n\n" );
		}
		$sdnoteindexstart = "$bracketstartndx+10c";
	}
	my $error =
	  $textwindow->search(
						   '-regexp',                   '--',
						   '(?<=[^\[])[Ss]idenote[: ]', '1.0',
						   'end'
	  );
	unless ($nobell) { $textwindow->bell if $error }
	$textwindow->see($error) if $error;
	$textwindow->markSet( 'insert', $error ) if $error;
}

# FIXME: vls -- Adapt this to handle abitrary text at eol, separated by
# >2 spaces. Suggestion from jabber room

# Find and format poetry line numbers. They need to be to the right, at
# least 2 space from the text.

## Reformat Poetry ~LINE Numbers
sub poetrynumbers {
	$searchstartindex = '1.0';
	viewpagenums() if ( $lglobal{seepagenums} );
	my ( $linenum, $line, $spacer, $row, $col );
	while (1) {
		$searchstartindex =
		  $textwindow->search( '-regexp', '--', '(?<=\S)\s\s+\d+$',
							   $searchstartindex, 'end' );
		last unless $searchstartindex;
		$textwindow->see($searchstartindex);
		$textwindow->update;
		update_indicators();
		( $row, $col ) = split /\./, $searchstartindex;
		$line = $textwindow->get( "$row.0", "$row.end" );
		$line =~ s/(?<=\S)\s\s+(\d+)$//;
		$linenum = $1;
		$spacer  = $rmargin - length($line) - length($linenum);
		$spacer -= 2;
		$line = '  ' . ( ' ' x $spacer ) . $linenum;
		$textwindow->delete( $searchstartindex, "$searchstartindex lineend" );
		$textwindow->insert( $searchstartindex, $line );
		$searchstartindex = ++$row . '.0';
	}
}

## Convert Windows CP 1252
sub cp1252toUni {
	my %cp = (
			   "\x{80}" => "\x{20AC}",
			   "\x{82}" => "\x{201A}",
			   "\x{83}" => "\x{0192}",
			   "\x{84}" => "\x{201E}",
			   "\x{85}" => "\x{2026}",
			   "\x{86}" => "\x{2020}",
			   "\x{87}" => "\x{2021}",
			   "\x{88}" => "\x{02C6}",
			   "\x{89}" => "\x{2030}",
			   "\x{8A}" => "\x{0160}",
			   "\x{8B}" => "\x{2039}",
			   "\x{8C}" => "\x{0152}",
			   "\x{8E}" => "\x{017D}",
			   "\x{91}" => "\x{2018}",
			   "\x{92}" => "\x{2019}",
			   "\x{93}" => "\x{201C}",
			   "\x{94}" => "\x{201D}",
			   "\x{95}" => "\x{2022}",
			   "\x{96}" => "\x{2013}",
			   "\x{97}" => "\x{2014}",
			   "\x{98}" => "\x{02DC}",
			   "\x{99}" => "\x{2122}",
			   "\x{9A}" => "\x{0161}",
			   "\x{9B}" => "\x{203A}",
			   "\x{9C}" => "\x{0153}",
			   "\x{9E}" => "\x{017E}",
			   "\x{9F}" => "\x{0178}"
	);
	for my $term ( keys %cp ) {
		my $thisblockstart;
		while ( $thisblockstart =
				$textwindow->search( '-exact', '--', $term, '1.0', 'end' ) )
		{

			# Use replacewith() to ensure change is tracked and saved
			$textwindow->replacewith( $thisblockstart, "$thisblockstart+1c",
									  $cp{$term} );
		}
	}
	update_indicators();
}


## Clean Up Rewrap
sub cleanup {
	$top->Busy( -recurse => 1 );
	$searchstartindex = '1.0';
	viewpagenums() if ( $lglobal{seepagenums} );
	while (1) {
		$searchstartindex =
		  $textwindow->search( '-regexp', '--',
							   '^\/[\*\$#pPfFLlXx]|^[Pp\*\$#fFLlXx]\/',
							   $searchstartindex, 'end' );
		last unless $searchstartindex;
		$textwindow->delete( "$searchstartindex -1c",
							 "$searchstartindex lineend" );
	}
	$top->Unbusy( -recurse => 1 );
}

## Find Greek
sub findandextractgreek {
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	my ( $greekIndex, $closeIndex ) = findgreek('insert');
	if ($closeIndex) {
		$textwindow->markSet( 'insert', $greekIndex );
		$textwindow->tagAdd( 'highlight', $greekIndex, $greekIndex . "+7c" );
		$textwindow->see('insert');
		$textwindow->tagAdd( 'highlight', $greekIndex, $greekIndex . "+1c" );
		if ( !defined( $lglobal{grpop} ) ) {
			greekpopup();
		}
		$textwindow->markSet( 'insert', $greekIndex . '+8c' );
		my $text = $textwindow->get( $greekIndex . '+8c', $closeIndex );
		$textwindow->delete( $greekIndex . '+8c', $closeIndex );
		$lglobal{grtext}->delete( '1.0', 'end' );
		$lglobal{grtext}->insert( '1.0', $text );
	}
}

### Text Processing

sub get_page_number {
	my $pnum;
	my $markindex = $textwindow->index('insert');
	my $mark      = $textwindow->markPrevious($markindex);
	while ($mark) {
		if ( $mark =~ /Pg(\S+)/ ) {
			$pnum = $1;
			last;
		} else {
			$mark = $textwindow->markPrevious($mark) if $mark;
		}
	}
	unless ($pnum) {
		$mark = $textwindow->markNext($markindex);
		while ($mark) {
			if ( $mark =~ /Pg(\S+)/ ) {
				$pnum = $1;
				last;
			} else {

				#print "$mark:1\n";
				#print $textwindow->markNext($mark).":2\n";
				if (    ( not defined $textwindow->markNext($mark) )
					 || ( $mark eq $textwindow->markNext($mark) ) )
				{
					last;
				}
				$mark = $textwindow->markNext($mark);
				last unless $mark;
			}
		}
	}
	$pnum = '' unless $pnum;
	return $pnum;
}

### External
sub externalpopup {    # Set up the external commands menu
	my $menutempvar;
	if ( $lglobal{xtpop} ) {
		$lglobal{xtpop}->deiconify;
	} else {
		$lglobal{xtpop} = $top->Toplevel( -title => 'External programs', );
		initialize_popup_with_deletebinding('xtpop');
		my $f0 = $lglobal{xtpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f0->Label( -text =>
"You can set up external programs to be called from within guiguts here. Each line of entry boxes represent\n"
			. "a menu entry. The left box is the label that will show up under the menu. The right box is the calling parameters.\n"
			. "Format the calling parameters as they would be when entered into the \"Run\" entry under the Start button\n"
			. "(for Windows). You can call a file directly: (\"C:\\Program Files\\Accessories\\wordpad.exe\") or indirectly for\n"
			. "registered apps (start or rundll). If you call a program that has a space in the path, you must enclose the program\n"
			. "name in double quotes.\n\n"
			. "There are a few exposed internal variables you can use to build commands with.\nUse one of these variable to "
			. "substitute in the corresponding value.\n\n"
			. "\$d = the directory path of the currently open file.\n"
			. "\$f = the current open file name, without a path or extension.\n"
			. "\$e = the extension of the currently open file.\n"
			. '(So, to pass the currently open file, use $d$f$e.)' . "\n\n"
			. "\$i = the directory with full path that the png files are in.\n"
			. "\$p = the number of the page that the cursor is currently in.\n"
		)->pack;
		my $f1 = $lglobal{xtpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		for my $menutempvar ( 0 .. 9 ) {
			$f1->Entry(
						-width        => 50,
						-background   => $bkgcolor,
						-relief       => 'sunken',
						-textvariable => \$extops[$menutempvar]{label},
			  )->grid(
					   -row    => "$menutempvar" + 1,
					   -column => 1,
					   -padx   => 2,
					   -pady   => 4
			  );
			$f1->Entry(
						-width        => 80,
						-background   => $bkgcolor,
						-relief       => 'sunken',
						-textvariable => \$extops[$menutempvar]{command},
			  )->grid(
					   -row    => "$menutempvar" + 1,
					   -column => 2,
					   -padx   => 2,
					   -pady   => 4
			  );
		}
		my $f2 = $lglobal{xtpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my $gobut = $f2->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				savesettings();
				menurebuild();
				$lglobal{xtpop}->destroy;
				undef $lglobal{xtpop};
			},
			-text  => 'OK',
			-width => 8
		)->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
	}
}

sub xtops {    # run an external program through the external commands menu
	my $index = shift;
	return unless $extops[$index]{command};
	runner( cmdinterp( $extops[$index]{command} ) );
}

### Prefs

sub setmargins {
	my $getmargins = $top->DialogBox( -title   => 'Set margins for rewrap',
									  -buttons => ['OK'], );
	my $lmframe =
	  $getmargins->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $lmlabel = $lmframe->Label(
								   -width => 25,
								   -text  => 'Rewrap Left Margin',
	)->pack( -side => 'left' );
	my $lmentry = $lmframe->Entry(
								   -width        => 6,
								   -background   => $bkgcolor,
								   -relief       => 'sunken',
								   -textvariable => \$lmargin,
	)->pack( -side => 'left' );
	my $rmframe =
	  $getmargins->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $rmlabel = $rmframe->Label(
								   -width => 25,
								   -text  => 'Rewrap Right Margin',
	)->pack( -side => 'left' );
	my $rmentry = $rmframe->Entry(
								   -width        => 6,
								   -background   => $bkgcolor,
								   -relief       => 'sunken',
								   -textvariable => \$rmargin,
	)->pack( -side => 'left' );
	my $blmframe =
	  $getmargins->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $blmlabel = $blmframe->Label(
									 -width => 25,
									 -text  => 'Block Rewrap Left Margin',
	)->pack( -side => 'left' );
	my $blmentry = $blmframe->Entry(
									 -width        => 6,
									 -background   => $bkgcolor,
									 -relief       => 'sunken',
									 -textvariable => \$blocklmargin,
	)->pack( -side => 'left' );
	my $brmframe =
	  $getmargins->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $brmlabel = $brmframe->Label(
									 -width => 25,
									 -text  => 'Block Rewrap Right Margin',
	)->pack( -side => 'left' );
	my $brmentry = $brmframe->Entry(
									 -width        => 6,
									 -background   => $bkgcolor,
									 -relief       => 'sunken',
									 -textvariable => \$blockrmargin,
	)->pack( -side => 'left' );

	#
	my $plmframe =
	  $getmargins->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $plmlabel = $plmframe->Label(
									 -width => 25,
									 -text  => 'Poetry Rewrap Left Margin',
	)->pack( -side => 'left' );
	my $plmentry = $plmframe->Entry(
									 -width        => 6,
									 -background   => $bkgcolor,
									 -relief       => 'sunken',
									 -textvariable => \$poetrylmargin,
	)->pack( -side => 'left' );

	#
	my $didntframe =
	  $getmargins->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $didntlabel =
	  $didntframe->Label(
						  -width => 25,
						  -text  => 'Default Indent for /*  */ Blocks',
	  )->pack( -side => 'left' );
	my $didntmentry =
	  $didntframe->Entry(
						  -width        => 6,
						  -background   => $bkgcolor,
						  -relief       => 'sunken',
						  -textvariable => \$defaultindent,
	  )->pack( -side => 'left' );
	$getmargins->Icon( -image => $icon );
	$getmargins->Show;

	if (    ( $blockrmargin eq '' )
		 || ( $blocklmargin eq '' )
		 || ( $rmargin      eq '' )
		 || ( $lmargin      eq '' ) )
	{
		$top->messageBox(
						  -icon    => 'error',
						  -message => 'The margins must be a positive integer.',
						  -title   => 'Incorrect margin ',
						  -type    => 'OK',
		);
		setmargins();
	}
	if (    ( $blockrmargin =~ /[\D\.]/ )
		 || ( $blocklmargin =~ /[\D\.]/ )
		 || ( $rmargin      =~ /[\D\.]/ )
		 || ( $lmargin      =~ /[\D\.]/ ) )
	{
		$top->messageBox(
						  -icon    => 'error',
						  -message => 'The margins must be a positive integer.',
						  -title   => 'Incorrect margin ',
						  -type    => 'OK',
		);
		setmargins();
	}
	if ( ( $blockrmargin < $blocklmargin ) || ( $rmargin < $lmargin ) ) {
		$top->messageBox(
			  -icon    => 'error',
			  -message => 'The left margins must come before the right margin.',
			  -title   => 'Incorrect margin ',
			  -type    => 'OK',
		);
		setmargins();
	}
	savesettings();
}

# FIXME: Adapt to work with fontCreate thingy
sub fontsize {
	my $sizelabel;
	if ( defined( $lglobal{fspop} ) ) {
		$lglobal{fspop}->deiconify;
		$lglobal{fspop}->raise;
		$lglobal{fspop}->focus;
	} else {
		$lglobal{fspop} = $top->Toplevel;
		$lglobal{fspop}->title('Font');
		initialize_popup_with_deletebinding('fspop');
		my $tframe = $lglobal{fspop}->Frame->pack;
		my $fontlist = $tframe->BrowseEntry(
			-label     => 'Font',
			-browsecmd => sub {
				fontinit();
				$textwindow->configure( -font => $lglobal{font} );
			},
			-variable => \$fontname
		)->grid( -row => 1, -column => 1, -pady => 5 );
		$fontlist->insert( 'end', sort( $textwindow->fontFamilies ) );
		my $mframe = $lglobal{fspop}->Frame->pack;
		my $smallerbutton = $mframe->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$fontsize++;
				fontinit();
				$textwindow->configure( -font => $lglobal{font} );
				$sizelabel->configure( -text => $fontsize );
			},
			-text  => 'Bigger',
			-width => 10
		)->grid( -row => 1, -column => 1, -pady => 5 );
		$sizelabel =
		  $mframe->Label( -text => $fontsize )
		  ->grid( -row => 1, -column => 2, -pady => 5 );
		my $biggerbutton = $mframe->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$fontsize--;
				fontinit();
				$textwindow->configure( -font => $lglobal{font} );
				$sizelabel->configure( -text => $fontsize );
			},
			-text  => 'Smaller',
			-width => 10
		)->grid( -row => 1, -column => 3, -pady => 5 );
		my $weightbox = $mframe->Checkbutton(
			-variable    => \$fontweight,
			-onvalue     => 'bold',
			-offvalue    => '',
			-selectcolor => $::activecolor,
			-command     => sub {
				fontinit();
				$textwindow->configure( -font => $lglobal{font} );
			},
			-text => 'Bold'
		)->grid( -row => 2, -column => 2, -pady => 5 );
		my $button_ok = $mframe->Button(
			-activebackground => $::activecolor,
			-text             => 'OK',
			-command          => sub {
				$lglobal{fspop}->destroy;
				undef $lglobal{fspop};
				savesettings();
			}
		)->grid( -row => 3, -column => 2, -pady => 5 );
		$lglobal{fspop}->resizable( 'no', 'no' );
		$lglobal{fspop}->raise;
		$lglobal{fspop}->focus;
	}
}

## Set up command to start a browser, varies by OS and browser
sub setbrowser {
	my $browsepop = $top->Toplevel;
	$browsepop->title('Browser Start Command?');
	$browsepop->Label( -text =>
"Enter the complete path to the executable.\n(Under Windows, you can use 'start' to use the default handler.\n"
		. "Under OSX, 'open' will start the default browser.)" )
	  ->grid( -row => 0, -column => 1, -columnspan => 2 );
	my $browserentry =
	  $browsepop->Entry(
						 -width        => 60,
						 -background   => $bkgcolor,
						 -textvariable => $globalbrowserstart,
	  )->grid( -row => 1, -column => 1, -columnspan => 2, -pady => 3 );
	my $button_ok = $browsepop->Button(
		-activebackground => $::activecolor,
		-text             => 'OK',
		-width            => 6,
		-command          => sub {
			$globalbrowserstart = $browserentry->get;
			savesettings();
			$browsepop->destroy;
			undef $browsepop;
		}
	)->grid( -row => 2, -column => 1, -pady => 8 );
	my $button_cancel = $browsepop->Button(
		-activebackground => $::activecolor,
		-text             => 'Cancel',
		-width            => 6,
		-command          => sub {
			$browsepop->destroy;
			undef $browsepop;
		}
	)->grid( -row => 2, -column => 2, -pady => 8 );
	$browsepop->protocol(
		 'WM_DELETE_WINDOW' => sub { $browsepop->destroy; undef $browsepop; } );
	$browsepop->Icon( -image => $icon );
}

sub setpngspath {
	my $pagenum = shift;

	#print $pagenum.'';
	my $path =
	  $textwindow->chooseDirectory( -title => 'Choose the PNGs file directory.',
									-initialdir => "$globallastpath" . "pngs",
	  );
	return unless defined $path and -e $path;
	$path .= '/';
	$path     = os_normal($path);
	$pngspath = $path;
	_bin_save($textwindow,$top);
	openpng($textwindow,$pagenum) if defined $pagenum;
}

sub toolbar_toggle {    # Set up / remove the tool bar
	if ( $notoolbar && $lglobal{toptool} ) {
		$lglobal{toptool}->destroy;
		undef $lglobal{toptool};
	} elsif ( !$notoolbar && !$lglobal{toptool} ) {
		$lglobal{toptool} = $top->ToolBar( -side => $toolside, -close => '30' );
		$lglobal{toolfont} = $top->Font(
			-family => 'Times',

			# -slant  => 'italic',
			-weight => 'bold',
			-size   => 9
		);
		$lglobal{toptool}->separator;
		$lglobal{toptool}->ToolButton(
									   -image   => 'fileopen16',
									   -command => sub {file_open($textwindow);} ,
									   -tip     => 'Open'
		);
		$lglobal{savetool} =
		  $lglobal{toptool}->ToolButton(
										 -image   => 'filesave16',
										 -command => [ \&savefile ],
										 -tip     => 'Save',
		  );
		$lglobal{savetool}->bind( '<3>', sub { set_autosave() } );
		$lglobal{savetool}->bind(
			'<Shift-3>',
			sub {
				$autosave = !$autosave;
				toggle_autosave();
			}
		);
		$lglobal{toptool}->ToolButton(
			-image   => 'edittrash16',
			-command => sub {
				return if ( confirmempty() =~ /cancel/i );
				clearvars($textwindow);
				update_indicators();
			},
			-tip => 'Discard Edits'
		);
		$lglobal{toptool}->separator;
		$lglobal{toptool}->ToolButton(
									   -image   => 'actundo16',
									   -command => sub { $textwindow->undo },
									   -tip     => 'Undo'
		);
		$lglobal{toptool}->ToolButton(
									   -image   => 'actredo16',
									   -command => sub { $textwindow->redo },
									   -tip     => 'Redo'
		);
		$lglobal{toptool}->separator;
		$lglobal{toptool}->ToolButton(
									   -image   => 'filefind16',
									   -command => [ \&searchpopup ],
									   -tip     => 'Search'
		);
		$lglobal{toptool}->ToolButton(
									   -image   => 'actcheck16',
									   -command => [ \&spellchecker ],
									   -tip     => 'Spell Check'
		);
		$lglobal{toptool}->ToolButton(
									   -text    => '"arid"',
									   -command => [ \&stealthscanno ],
									   -tip     => 'Scannos'
		);
		$lglobal{toptool}->separator;
		$lglobal{toptool}->ToolButton(
									   -text    => 'WF�',
									   -font    => $lglobal{toolfont},
									   -command => [ sub{wordfrequency($textwindow,$top)} ],
									   -tip     => 'Word Frequency'
		);
		$lglobal{toptool}->ToolButton(
									   -text    => 'GC',
									   -font    => $lglobal{toolfont},
									   -command => [ \&gutcheck ],
									   -tip     => 'Gutcheck'
		);
		$lglobal{toptool}->separator;
		$lglobal{toptool}->ToolButton(
									   -text    => 'Ltn-1',
									   -font    => $lglobal{toolfont},
									   -command => [ \&latinpopup ],
									   -tip     => 'Latin - 1 Popup'
		);
		$lglobal{toptool}->ToolButton(
									   -text    => 'Grk',
									   -font    => $lglobal{toolfont},
									   -command => [ \&greekpopup ],
									   -tip     => 'Greek Transliteration Popup'
		);
		$lglobal{toptool}->ToolButton(
									   -text    => 'UCS',
									   -font    => $lglobal{toolfont},
									   -command => [ \&uchar ],
									   -tip     => 'Unicode Character Search'
		);
		$lglobal{toptool}->separator;
		$lglobal{toptool}->ToolButton(
									   -text    => 'HTML',
									   -font    => $lglobal{toolfont},
									   -command => sub{htmlpopup($textwindow,$top)},
									   -tip     => 'HTML Fixup'
		);
		$lglobal{toptool}->separator;
		$lglobal{toptool}->ToolButton(
									   -text    => 'Tfx',
									   -font    => $lglobal{toolfont},
									   -command => [ \&tablefx ],
									   -tip     => 'ASCII Table Formatting'
		);
		$lglobal{toptool}->separator;
		$lglobal{toptool}->ToolButton(
								   -text    => 'Eol',
								   -font    => $lglobal{toolfont},
								   -command => [ \&endofline ],
								   -tip => 'Remove trailing spaces in selection'
		);
	}
	savesettings();
}

sub setcolor {    # Color picking routine
	my $initial = shift;
	return (
			 $top->chooseColor(
								-initialcolor => $initial,
								-title        => 'Choose color'
			 )
	);
}

sub spelloptions {
	if ($globalspellpath) {
		aspellstart() unless $lglobal{spellpid};
	}
	my $dicts;
	my $dictlist;
	my $spellop = $top->DialogBox( -title   => 'Spellcheck Options',
								   -buttons => ['Close'] );
	my $spellpathlabel =
	  $spellop->add( 'Label', -text => 'Aspell executable file?' )->pack;
	my $spellpathentry =
	  $spellop->add( 'Entry', -width => 60, -background => $bkgcolor )->pack;
	my $spellpathbrowse = $spellop->add(
		'Button',
		-text    => 'Browse',
		-width   => 12,
		-command => sub {
			my $name = $spellop->getOpenFile( -title => 'Aspell executable?' );
			if ($name) {
				$globalspellpath = $name;
				$globalspellpath = os_normal($globalspellpath);
				$spellpathentry->delete( 0, 'end' );
				$spellpathentry->insert( 'end', $globalspellpath );
				savesettings();

				my $runner = runner::tofile('aspell.tmp');
				$runner->run($globalspellpath, 'dump', 'dicts');
				warn "Unable to access dictionaries.\n" if $?;

				open my $infile, '<', 'aspell.tmp';
				while ( $dicts = <$infile> ) {
					chomp $dicts;
					next if ( $dicts =~ m/-/ );
					$dictlist->insert( 'end', $dicts );
				}
				close $infile;
				unlink 'aspell.tmp'
			}
		}
	)->pack( -pady => 4 );
	$spellpathentry->insert( 'end', $globalspellpath );

	my $spellencodinglabel =
	  $spellop->add( 'Label', -text => 'Set encoding: default = iso8859-1' )
	  ->pack;

	my $spellencodingentry =
	  $spellop->add(
					 'Entry',
					 -width        => 30,
					 -textvariable => \$lglobal{spellencoding},
	  )->pack;

	my $dictlabel = $spellop->add( 'Label', -text => 'Dictionary files' )->pack;
	$dictlist = $spellop->add(
							   'ScrlListbox',
							   -scrollbars => 'oe',
							   -selectmode => 'browse',
							   -background => $bkgcolor,
							   -height     => 10,
							   -width      => 40,
	)->pack( -pady => 4 );
	my $spelldiclabel =
	  $spellop->add( 'Label', -text => 'Current Dictionary (ies)' )->pack;
	my $spelldictxt = $spellop->add(
									 'ROText',
									 -width      => 40,
									 -height     => 1,
									 -background => $bkgcolor
	)->pack;
	$spelldictxt->delete( '1.0', 'end' );
	$spelldictxt->insert( '1.0', $globalspelldictopt );

	#$dictlist->insert( 'end', "No dictionary!" );

	if ($globalspellpath) {
		my $runner = runner::tofile('aspell.tmp');
		$runner->run($globalspellpath, 'dump', 'dicts');
		warn "Unable to access dictionaries.\n" if $?;

		open my $infile,'<', 'aspell.tmp';
		while ( $dicts = <$infile> ) {
			chomp $dicts;
			next if ( $dicts =~ m/-/ );
			$dictlist->insert( 'end', $dicts );
		}
		close $infile;
		unlink 'aspell.tmp';
	}
	$dictlist->eventAdd( '<<dictsel>>' => '<Double-Button-1>' );
	$dictlist->bind(
		'<<dictsel>>',
		sub {
			my $selection = $dictlist->get('active');
			$spelldictxt->delete( '1.0', 'end' );
			$spelldictxt->insert( '1.0', $selection );
			$selection = '' if $selection eq "No dictionary!";
			$globalspelldictopt = $selection;
			savesettings();
			aspellstart();
			$top->Busy( -recurse => 1 );

			if ( defined( $lglobal{spellpopup} ) ) {
				spellclearvars();
				spellcheckfirst();
			}
			$top->Unbusy( -recurse => 1 );
		}
	);
	my $spopframe = $spellop->Frame->pack;
	$spopframe->Radiobutton(
							 -selectcolor => $lglobal{checkcolor},
							 -text        => 'Ultra Fast',
							 -variable    => \$globalaspellmode,
							 -value       => 'ultra'
	)->grid( -row => 0, -sticky => 'w' );
	$spopframe->Radiobutton(
							 -selectcolor => $lglobal{checkcolor},
							 -text        => 'Fast',
							 -variable    => \$globalaspellmode,
							 -value       => 'fast'
	)->grid( -row => 1, -sticky => 'w' );
	$spopframe->Radiobutton(
							 -selectcolor => $lglobal{checkcolor},
							 -text        => 'Normal',
							 -variable    => \$globalaspellmode,
							 -value       => 'normal'
	)->grid( -row => 2, -sticky => 'w' );
	$spopframe->Radiobutton(
							 -selectcolor => $lglobal{checkcolor},
							 -text        => 'Bad Spellers',
							 -variable    => \$globalaspellmode,
							 -value       => 'bad-spellers'
	)->grid( -row => 3, -sticky => 'w' );
	$spellop->Show;
}

sub toggle_autosave {
	if ($autosave) {
		set_autosave();
	} else {
		$lglobal{autosaveid}->cancel;
		undef $lglobal{autosaveid};
		$lglobal{saveflashid}->cancel;
		undef $lglobal{saveflashid};
		$lglobal{saveflashingid}->cancel if $lglobal{saveflashingid};
		undef $lglobal{saveflashingid};
		$lglobal{savetool}->configure(
									   -background       => 'SystemButtonFace',
									   -activebackground => 'SystemButtonFace'
		) unless $notoolbar;
	}
}

# Pop up a window where you can adjust the auto save interval
sub saveinterval {
	if ( $lglobal{intervalpop} ) {
		$lglobal{intervalpop}->deiconify;
		$lglobal{intervalpop}->raise;
	} else {
		$lglobal{intervalpop} = $top->Toplevel;
		$lglobal{intervalpop}->title('Autosave Interval');
		initialize_popup_with_deletebinding('intervalpop');
		$lglobal{intervalpop}->resizable( 'no', 'no' );
		my $frame =
		  $lglobal{intervalpop}
		  ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		$frame->Label( -text => 'Minutes between Autosave' )
		  ->pack( -side => 'left' );
		my $entry = $frame->Entry(
			-background   => $bkgcolor,
			-width        => 5,
			-textvariable => \$autosaveinterval,
			-validate     => 'key',
			-vcmd         => sub {
				return 1 unless $_[0];
				return 0 if ( $_[0] =~ /\D/ );
				return 0 if ( $_[0] < 1 );
				return 0 if ( $_[0] > 999 );
				return 1;
			},
		)->pack( -side => 'left', -fill => 'x' );
		my $frame1 =
		  $lglobal{intervalpop}
		  ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		$frame1->Label( -text => '1-999 minutes' )->pack( -side => 'left' );
		my $button = $frame1->Button(
			-text    => 'OK',
			-command => sub {
				$autosaveinterval = 5 unless $autosaveinterval;
				$lglobal{intervalpop}->destroy;
				undef $lglobal{scrlspdpop};
			},
		)->pack( -side => 'left' );
		$lglobal{intervalpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$autosaveinterval = 5 unless $autosaveinterval;
				$lglobal{intervalpop}->destroy;
				undef $lglobal{intervalpop};
			}
		);
		$entry->selectionRange( 0, 'end' );
	}
}

sub set_autosave {
	$lglobal{autosaveid}->cancel     if $lglobal{autosaveid};
	$lglobal{saveflashid}->cancel    if $lglobal{saveflashid};
	$lglobal{saveflashingid}->cancel if $lglobal{saveflashingid};
	$lglobal{autosaveid} = $top->repeat(
		( $autosaveinterval * 60000 ),
		sub {
			savefile()
			  if $textwindow->numberChanges
				  and $lglobal{global_filename} !~ /No File Loaded/;
		}
	);
	$lglobal{saveflashid} = $top->after(
		( $autosaveinterval * 60000 - 10000 ),
		sub {
			_flash_save($textwindow)
			  if $lglobal{global_filename} !~ /No File Loaded/;
		}
	);
	$lglobal{savetool}
	  ->configure( -background => 'green', -activebackground => 'green' )
	  unless $notoolbar;
	$lglobal{autosaveinterval} = time;
}

sub highlight_scannos {    # Enable / disable word highlighting in the text
	if ( $scannos_highlighted ) {
		$lglobal{hl_index} = 1;
		highlightscannos();
		$lglobal{scannos_highlightedid} = $top->repeat( 400, \&highlightscannos );
	} else {
		$lglobal{scannos_highlightedid}->cancel if $lglobal{scannos_highlightedid};
		undef $lglobal{scannos_highlightedid};
		$textwindow->tagRemove( 'scannos', '1.0', 'end' );
	}
	update_indicators();
	savesettings();
}

sub searchsize {  # Pop up a window where you can adjust the search history size
	if ( $lglobal{hssizepop} ) {
		$lglobal{hssizepop}->deiconify;
		$lglobal{hssizepop}->raise;
	} else {
		$lglobal{hssizepop} = $top->Toplevel;
		$lglobal{hssizepop}->title('History Size');
		initialize_popup_with_deletebinding('hssizepop');
		$lglobal{hssizepop}->resizable( 'no', 'no' );
		my $frame =
		  $lglobal{hssizepop}
		  ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		$frame->Label( -text => 'History Size: # of terms to save - ' )
		  ->pack( -side => 'left' );
		my $entry = $frame->Entry(
			-background   => $bkgcolor,
			-width        => 5,
			-textvariable => \$history_size,
			-validate     => 'key',
			-vcmd         => sub {
				return 1 unless $_[0];
				return 0 if ( $_[0] =~ /\D/ );
				return 0 if ( $_[0] < 1 );
				return 0 if ( $_[0] > 200 );
				return 1;
			},
		)->pack( -side => 'left', -fill => 'x' );
		my $frame2 =
		  $lglobal{hssizepop}
		  ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		$frame2->Button(
			-text    => 'Ok',
			-width   => 10,
			-command => sub {
				savesettings();
				$lglobal{hssizepop}->destroy;
				undef $lglobal{hssizepop};
			}
		)->pack;
		$lglobal{hssizepop}->raise;
		$lglobal{hssizepop}->focus;
	}
}

### Help
# FIXME: generalize about, version, etc. into one function.
sub showversion {
	my ($top) = @_;
	my $os = $^O;
	$os =~ s/^([^\[]+)\[.+/$1/;
	my $perl = sprintf( "Perl v%vd", $^V );
	my $winver;
	if ($::OS_WIN) {
		$winver = qx{ver};
		$winver =~ s{\n}{}smg;
	} else {
		$winver = "";
	}    # stops "uninitialised value" message on non windows systems
	my $message = <<"END";
Currently Running :
$APP_NAME, Version : $VERSION
Platform : $os
$winver
$perl
perl/Tk Version : $Tk::VERSION
Tk patchLevel : $Tk::patchLevel
Tk libraries : $Tk::library
END

	my $dialog = $top->Dialog(
							   -title   => 'Versions',
							   -popover => $top,
							   -justify => 'center',
							   -text    => $message,
	);
	$dialog->Show;
}

# Check what is the most recent version online
sub checkonlineversion {

	#working("Checking for update online (timeout 20 seconds)");
	my $ua = LWP::UserAgent->new(
								  env_proxy  => 1,
								  keep_alive => 1,
								  timeout    => 20,
	);
	my $response = $ua->get('http://sourceforge.net/projects/guiguts/');

	#working();
	unless ( $response->content ) {
		return;
	}
	if ( $response->content =~ /(\d+)\.(\d+)\.(\d+)\.zip/i ) {
		return "$1.$2.$3";
	}
}

# Check to see if this is the most recent version
sub checkforupdates {
	my $monthlycheck = shift;
	if ( ( $monthlycheck eq "monthly" ) and ( $ignoreversions eq "major" ) ) {
		return;
	}
	my $onlineversion;

	$onlineversion = checkonlineversion();
	if ($onlineversion) {
		if ( $monthlycheck eq "monthly" ) {
			if (    ( $onlineversion eq "$VERSION" )
				 or ( $onlineversion eq $ignoreversionnumber ) )
			{
				return;
			}
			my ( $onlinemajorversion, $onlineminorversion, $onlinerevision ) =
			  split( /\./, $onlineversion );
			my ( $currentmajorversion, $currentminorversion, $currentrevision )
			  = split( /\./, $VERSION );
			if (     ( $onlinemajorversion == $currentmajorversion )
				 and ( $ignoreversions eq "minor" ) )
			{
				return;
			}
			if (     ( $onlineminorversion == $currentminorversion )
				 and ( $ignoreversions eq "revisions" ) )
			{
				return;
			}
		}

		my ( $dbox, $answer );
		my $versionpopmessage;
		my $versionbox = $top->Toplevel;
		$versionbox->Icon( -image => $icon );
		$versionbox->title('Check for updates');
		$versionbox->focusForce;
		my $dialog_frame =
		  $versionbox->Frame()->pack( -side => "top", -pady => 10 );
		$dialog_frame->Label( -text =>
"The latest version available online is $onlineversion, and your version is $VERSION."
		)->pack( -side => "top" );
		my $button_frame = $dialog_frame->Frame()->pack( -side => "top" );
		$button_frame->Button(
			-text    => 'Update',
			-command => sub {
				runner(
$globalbrowserstart, "http://sourceforge.net/projects/guiguts/" );
				$versionbox->destroy;
				undef $versionbox;
			}
		)->pack( -side => 'left', -pady => 8, -padx => 5 );
		$button_frame->Button(
			-text    => 'Ignore This Version',
			-command => sub {

				#print $ignoreversionnumber;
				$ignoreversionnumber = $onlineversion;
				savesettings();
				$versionbox->destroy;
				undef $versionbox;
			}
		)->pack( -side => 'left', -pady => 8, -padx => 5 );
		$button_frame->Button(
			-text    => 'Remind Me',
			-command => sub {
				$versionbox->destroy;
				undef $versionbox;
				return;
			}
		)->pack( -side => 'left', -pady => 8, -padx => 5 );
		$dialog_frame->Label( -text => $versionpopmessage )
		  ->pack( -side => "top" );

		my $radio_frame =
		  $versionbox->Frame()->pack( -side => "top", -pady => 10 );
		$radio_frame->Radiobutton(
								   -text     => "Do Not Check Again",
								   -value    => "major",
								   -variable => \$ignoreversions
		)->pack( -side => "left" );
		$radio_frame->Radiobutton(
								   -text     => "Ignore Minor Versions",
								   -value    => "minor",
								   -variable => \$ignoreversions
		)->pack( -side => "left" );
		$radio_frame->Radiobutton(
								   -text     => "Ignore Revisions",
								   -value    => "revisions",
								   -variable => \$ignoreversions
		)->pack( -side => "left" );
		$radio_frame->Radiobutton(
								   -text     => "Check for Revisions",
								   -value    => "none",
								   -variable => \$ignoreversions
		)->pack( -side => "left" );

	} else {
		$top->messageBox(
					   -icon    => 'error',
					   -message => 'Could not determine latest version online.',
					   -title   => 'Checking for Updates',
					   -type    => 'Ok',
		);
		return;

	}
}

# On a monthly basis, check to see if this is the most recent version
sub checkforupdatesmonthly {
	if (     ( $ignoreversions ne "major" )
		 and ( time() - $lastversioncheck > 2592000 ) )
	{
		$lastversioncheck = time();

		my $updateanswer = $top->Dialog(
			-title => 'Check for Updates',
			-font  => $lglobal{font},

			-text           => 'Would you like to check for updates?',
			-buttons        => [ 'Ok', 'Later', 'Don\'t Ask' ],
			-default_button => 'Ok'
		)->Show();
		if ( $updateanswer eq 'Ok' ) {
			checkforupdates("monthly");
			return;
		}
		if ( $updateanswer eq 'Later' ) {
			return;
		}
		if ( $updateanswer eq 'Do Not Ask Again' ) {
			$ignoreversions = "major";
			return;
		}
	}
}

sub hotkeyshelp {
	if ( defined( $lglobal{hotpop} ) ) {
		$lglobal{hotpop}->deiconify;
		$lglobal{hotpop}->raise;
		$lglobal{hotpop}->focus;
	} else {
		$lglobal{hotpop} = $top->Toplevel;
		$lglobal{hotpop}->title('Hot key combinations');
		initialize_popup_with_deletebinding('hotpop');

		my $frame =
		  $lglobal{hotpop}->Frame->pack(
										 -anchor => 'nw',
										 -expand => 'yes',
										 -fill   => 'both'
		  );
		my $rotextbox =
		  $frame->Scrolled(
							'ROText',
							-scrollbars => 'se',
							-background => $bkgcolor,
							-font       => '{Helvetica} 10',
							-width      => 80,
							-height     => 25,
							-wrap       => 'none',
		  )->pack( -anchor => 'nw', -expand => 'yes', -fill => 'both' );
		drag($rotextbox);
		$rotextbox->focus;
		$rotextbox->insert( 'end', <<'EOF' );

MAIN WINDOW

<ctrl>+x -- cut or column cut
<ctrl>+c -- copy or column copy
<ctrl>+v -- paste
<ctrl>+` -- column paste
<ctrl>+a -- select all

F1 -- column copy
F2 -- column cut
F3 -- column paste

F7 -- spell check selection (or document, if no selection made)

<ctrl>+z -- undo
<ctrl>+y -- redo

<ctrl>+/ -- select all
<ctrl>+\ -- unselect all
<Esc> -- unselect all

<ctrl>+u -- Convert case of selection to upper case
<ctrl>+l -- Convert case of selection to lower case
<ctrl>+t -- Convert case of selection to title case

<ctrl>+i -- insert a tab character before cursor (Tab)
<ctrl>+j -- insert a newline character before cursor (Enter)
<ctrl>+o -- insert a newline character after cursor

<ctrl>+d -- delete character after cursor (Delete)
<ctrl>+h -- delete character to the left of the cursor (Backspace)
<ctrl>+k -- delete from cursor to end of line

<ctrl>+e -- move cursor to end of current line. (End)
<ctrl>+b -- move cursor left one character (left arrow)
<ctrl>+p -- move cursor up one line (up arrow)
<ctrl>+n -- move cursor down one line (down arrow)

<ctrl>Home -- move cursor to the start of the text
<ctrl>End -- move cursor to end of the text
<ctrl>+right arrow -- move to the start of the next word
<ctrl>+left arrow -- move to the start of the previous word
<ctrl>+up arrow -- move to the start of the current paragraph
<ctrl>+down arrow -- move to the start of the next paragraph
<ctrl>+PgUp -- scroll left one screen
<ctrl>+PgDn -- scroll right one screen

<shift>+Home -- adjust selection to beginning of current line
<shift>+End -- adjust selection to end of current line
<shift>+up arrow -- adjust selection up one line
<shift>+down arrow -- adjust selection down one line
<shift>+left arrow -- adjust selection left one character
<shift>+right arrow -- adjust selection right one character

<shift><ctrl>Home -- adjust selection to the start of the text
<shift><ctrl>End -- adjust selection to end of the text
<shift><ctrl>+left arrow -- adjust selection to the start of the previous word
<shift><ctrl>+right arrow -- adjust selection to the start of the next word
<shift><ctrl>+up arrow -- adjust selection to the start of the current paragraph
<shift><ctrl>+down arrow -- adjust selection to the start of the next paragraph

<ctrl>+' -- highlight all apostrophes in selection.
<ctrl>+\" -- highlight all double quotes in selection.
<ctrl>+0 -- remove all highlights.

<Insert> -- Toggle insert / overstrike mode

Double click left mouse button -- select word
Triple click left mouse button -- select line

<shift> click left mouse button -- adjust selection to click point
<shift> Double click left mouse button -- adjust selection to include word clicked on
<shift> Triple click left mouse button -- adjust selection to include line clicked on

Single click right mouse button -- pop up shortcut to menu bar

BOOKMARKS

<ctrl>+<shift>+1 -- set bookmark 1
<ctrl>+<shift>+2 -- set bookmark 1
<ctrl>+<shift>+3 -- set bookmark 3
<ctrl>+<shift>+4 -- set bookmark 4
<ctrl>+<shift>+5 -- set bookmark 5

<ctrl>+1 -- go to bookmark 1
<ctrl>+2 -- go to bookmark 2
<ctrl>+3 -- go to bookmark 3
<ctrl>+4 -- go to bookmark 4
<ctrl>+5 -- go to bookmark 5

MENUS

<alt>+f -- file menu
<alt>+e -- edit menu
<alt>+b -- bookmarks
<alt>+s -- search menu
<alt>+g -- gutcheck menu
<alt>+x -- fixup menu
<alt>+w -- word frequency menu


SEARCH POPUP

<Enter> -- Search
<shift><Enter> -- Replace
<ctrl><Enter> -- Replace & Search
<ctrl><shift><Enter> -- Replace All

PAGE SEPARATOR POPUP

'j' -- Join Lines - join lines, remove all blank lines, spaces, asterisks and hyphens.
'k' -- Join, Keep Hyphen - join lines, remove all blank lines, spaces and asterisks, keep hyphen.
'l' -- Blank Line - leave one blank line. Close up any other whitespace. (Paragraph Break)
't' -- New Section - leave two blank lines. Close up any other whitespace. (Section Break)
'h' -- New Chapter - leave four blank lines. Close up any other whitespace. (Chapter Break)
'r' -- Refresh - search for, highlight and re-center the next page separator.
'u' -- Undo - undo the last edit. (Note: in Full Automatic mode,\n\tthis just single steps back through the undo buffer)
'd' -- Delete - delete the page separator. Make no other edits.
'v' -- View the current page in the image viewer.
'a' -- Toggle Full Automatic mode.
's' -- Toggle Semi Automatic mode.
'?' -- View hotkey help popup.
EOF
		my $button_ok = $frame->Button(
			-activebackground => $::activecolor,
			-text             => 'OK',
			-command          => sub {
				$lglobal{hotpop}->destroy;
				undef $lglobal{hotpop};
			}
		)->pack( -pady => 8 );
	}
}

sub greekpopup {
	my $buildlabel;
	my %attributes;
	if ( defined( $lglobal{grpop} ) ) {
		$lglobal{grpop}->deiconify;
		$lglobal{grpop}->raise;
		$lglobal{grpop}->focus;
	} else {
		my @greek = (
					  [ 'a',  'calpha',   'lalpha',   'chalpha',   'halpha' ],
					  [ 'b',  'cbeta',    'lbeta',    '',          '' ],
					  [ 'g',  'cgamma',   'lgamma',   'ng',        '' ],
					  [ 'd',  'cdelta',   'ldelta',   '',          '' ],
					  [ 'e',  'cepsilon', 'lepsilon', 'chepsilon', 'hepsilon' ],
					  [ 'z',  'czeta',    'lzeta',    '',          '' ],
					  [ '�', 'ceta',     'leta',     'cheta',     'heta' ],
					  [ 'th', 'ctheta',   'ltheta',   '',          '' ],
					  [ 'i',  'ciota',    'liota',    'chiota',    'hiota' ],
					  [ 'k',  'ckappa',   'lkappa',   'nk',        '' ],
					  [ 'l',  'clambda',  'llambda',  '',          '' ],
					  [ 'm',  'cmu',      'lmu',      '',          '' ],
					  [ 'n',  'cnu',      'lnu',      '',          '' ],
					  [ 'x',  'cxi',      'lxi',      'nx',        '' ],
					  [ 'o',  'comicron', 'lomicron', 'chomicron', 'homicron' ],
					  [ 'p',  'cpi',      'lpi',      '',          '' ],
					  [ 'r',  'crho',     'lrho',     'hrho',      '' ],
					  [ 's',  'csigma',   'lsigma',   'lsigmae',   '' ],
					  [ 't',  'ctau',     'ltau',     '',          '' ],
					  [
						 '(yu)', 'cupsilon', 'lupsilon', 'chupsilon',
						 'hupsilon'
					  ],
					  [ 'ph',  'cphi',     'lphi',     '',        '' ],
					  [ 'ch',  'cchi',     'lchi',     'nch',     '' ],
					  [ 'ps',  'cpsi',     'lpsi',     '',        '' ],
					  [ '�',  'comega',   'lomega',   'chomega', 'homega' ],
					  [ 'st',  'cstigma',  'lstigma',  '',        '' ],
					  [ '6',   'cdigamma', 'ldigamma', '',        '' ],
					  [ '90',  'ckoppa',   'lkoppa',   '',        '' ],
					  [ '900', 'csampi',   'lsampi',   '',        '' ]
		);
		%attributes = (
			'calpha'  => [ 'A',  'Alpha', '&#913;',  "\x{0391}" ],
			'lalpha'  => [ 'a',  'alpha', '&#945;',  "\x{03B1}" ],
			'chalpha' => [ 'Ha', 'Alpha', '&#7945;', "\x{1F09}" ],
			'halpha'  => [ 'ha', 'alpha', '&#7937;', "\x{1F01}" ],
			'cbeta'   => [ 'B',  'Beta',  '&#914;',  "\x{0392}" ],
			'lbeta'   => [ 'b',  'beta',  '&#946;',  "\x{03B2}" ],
			'cgamma'  => [ 'G',  'Gamma', '&#915;',  "\x{0393}" ],
			'lgamma'  => [ 'g',  'gamma', '&#947;',  "\x{03B3}" ],
			'ng' => [ 'ng', 'gamma gamma', '&#947;&#947;', "\x{03B3}\x{03B3}" ],
			'cdelta'    => [ 'D',   'Delta',   '&#916;',  "\x{0394}" ],
			'ldelta'    => [ 'd',   'delta',   '&#948;',  "\x{03B4}" ],
			'cepsilon'  => [ 'E',   'Epsilon', '&#917;',  "\x{0395}" ],
			'lepsilon'  => [ 'e',   'epsilon', '&#949;',  "\x{03B5}" ],
			'chepsilon' => [ 'He',  'Epsilon', '&#7961;', "\x{1F19}" ],
			'hepsilon'  => [ 'he',  'epsilon', '&#7953;', "\x{1F11}" ],
			'czeta'     => [ 'Z',   'Zeta',    '&#918;',  "\x{0396}" ],
			'lzeta'     => [ 'z',   'zeta',    '&#950;',  "\x{03B6}" ],
			'ceta'      => [ '�',  'Eta',     '&#919;',  "\x{0397}" ],
			'leta'      => [ '�',  'eta',     '&#951;',  "\x{03B7}" ],
			'cheta'     => [ 'H�', 'Eta',     '&#7977;', "\x{1F29}" ],
			'heta'      => [ 'h�', 'eta',     '&#7969;', "\x{1F21}" ],
			'ctheta'    => [ 'Th',  'Theta',   '&#920;',  "\x{0398}" ],
			'ltheta'    => [ 'th',  'theta',   '&#952;',  "\x{03B8}" ],
			'ciota'     => [ 'I',   'Iota',    '&#921;',  "\x{0399}" ],
			'liota'     => [ 'i',   'iota',    '&#953;',  "\x{03B9}" ],
			'chiota'    => [ 'Hi',  'Iota',    '&#7993;', "\x{1F39}" ],
			'hiota'     => [ 'hi',  'iota',    '&#7985;', "\x{1F31}" ],
			'ckappa'    => [ 'K',   'Kappa',   '&#922;',  "\x{039A}" ],
			'lkappa'    => [ 'k',   'kappa',   '&#954;',  "\x{03BA}" ],
			'nk' => [ 'nk', 'gamma kappa', '&#947;&#954;', "\x{03B3}\x{03BA}" ],
			'clambda' => [ 'L', 'Lambda', '&#923;', "\x{039B}" ],
			'llambda' => [ 'l', 'lambda', '&#955;', "\x{03BB}" ],
			'cmu'     => [ 'M', 'Mu',     '&#924;', "\x{039C}" ],
			'lmu'     => [ 'm', 'mu',     '&#956;', "\x{03BC}" ],
			'cnu'     => [ 'N', 'Nu',     '&#925;', "\x{039D}" ],
			'lnu'     => [ 'n', 'nu',     '&#957;', "\x{03BD}" ],
			'cxi'     => [ 'X', 'Xi',     '&#926;', "\x{039E}" ],
			'lxi'     => [ 'x', 'xi',     '&#958;', "\x{03BE}" ],
			'nx' => [ 'nx', 'gamma xi', '&#947;&#958;', "\x{03B3}\x{03BE}" ],
			'comicron'  => [ 'O',  'Omicron', '&#927;',  "\x{039F}" ],
			'lomicron'  => [ 'o',  'omicron', '&#959;',  "\x{03BF}" ],
			'chomicron' => [ 'Ho', 'Omicron', '&#8009;', "\x{1F49}" ],
			'homicron'  => [ 'ho', 'omicron', '&#8001;', "\x{1F41}" ],
			'cpi'       => [ 'P',  'Pi',      '&#928;',  "\x{03A0}" ],
			'lpi'       => [ 'p',  'pi',      '&#960;',  "\x{03C0}" ],
			'crho'      => [ 'R',  'Rho',     '&#929;',  "\x{03A1}" ],
			'lrho'      => [ 'r',  'rho',     '&#961;',  "\x{03C1}" ],
			'hrho'      => [ 'rh', 'rho',     '&#8165;', "\x{1FE5}" ],
			'csigma'    => [ 'S',  'Sigma',   '&#931;',  "\x{03A3}" ],
			'lsigma'    => [ 's',  'sigma',   '&#963;',  "\x{03C3}" ],
			'lsigmae'   => [ 's',  'sigma',   '&#962;',  "\x{03C2}" ],
			'ctau'      => [ 'T',  'Tau',     '&#932;',  "\x{03A4}" ],
			'ltau'      => [ 't',  'tau',     '&#964;',  "\x{03C4}" ],
			'cupsilon'  => [ 'Y',  'Upsilon', '&#933;',  "\x{03A5}" ],
			'lupsilon'  => [ 'y',  'upsilon', '&#965;',  "\x{03C5}" ],
			'chupsilon' => [ 'Hy', 'Upsilon', '&#8025;', "\x{1F59}" ],
			'hupsilon'  => [ 'hy', 'upsilon', '&#8017;', "\x{1F51}" ],
			'cphi'      => [ 'Ph', 'Phi',     '&#934;',  "\x{03A6}" ],
			'lphi'      => [ 'ph', 'phi',     '&#966;',  "\x{03C6}" ],
			'cchi'      => [ 'Ch', 'Chi',     '&#935;',  "\x{03A7}" ],
			'lchi'      => [ 'ch', 'chi',     '&#967;',  "\x{03C7}" ],
			'nch' => [ 'nch', 'gamma chi', '&#947;&#967;', "\x{03B3}\x{03C7}" ],
			'cpsi'     => [ 'Ps',  'Psi',     '&#936;',  "\x{03A8}" ],
			'lpsi'     => [ 'ps',  'psi',     '&#968;',  "\x{03C8}" ],
			'comega'   => [ '�',  'Omega',   '&#937;',  "\x{03A9}" ],
			'lomega'   => [ '�',  'omega',   '&#969;',  "\x{03C9}" ],
			'chomega'  => [ 'H�', 'Omega',   '&#8041;', "\x{1F69}" ],
			'homega'   => [ 'h�', 'omega',   '&#8033;', "\x{1F61}" ],
			'cstigma'  => [ 'St',  'Stigma',  '&#986;',  "\x{03DA}" ],
			'lstigma'  => [ 'st',  'stigma',  '&#987;',  "\x{03DB}" ],
			'cdigamma' => [ '6',   'Digamma', '&#988;',  "\x{03DC}" ],
			'ldigamma' => [ '6',   'digamma', '&#989;',  "\x{03DD}" ],
			'ckoppa'   => [ '9',   'Koppa',   '&#990;',  "\x{03DE}" ],
			'lkoppa'   => [ '9',   'koppa',   '&#991;',  "\x{03DF}" ],
			'csampi'   => [ '9',   'Sampi',   '&#992;',  "\x{03E0}" ],
			'lsampi'   => [ '9',   'sampi',   '&#993;',  "\x{03E1}" ],
			'oulig' => [ 'ou', 'oulig', '&#959;&#965;', "\x{03BF}\x{03C5}" ]
		);
		my $grfont = '{Times} 14';

		for my $image ( keys %attributes ) {
			$lglobal{images}->{$image} =
			  $top->Photo( -format => 'gif',
						   -data   => $Guiguts::Greekgifs::grkgifs{$image}, );
		}
		$lglobal{grpop} = $top->Toplevel;
		initialize_popup_without_deletebinding('grpop');
		$lglobal{grpop}->title('Greek Transliteration');
		my $tframe =
		  $lglobal{grpop}
		  ->Frame->pack( -expand => 'no', -fill => 'none', -anchor => 'n' );
		my $glatin =
		  $tframe->Radiobutton(
								-variable    => \$lglobal{groutp},
								-selectcolor => $lglobal{checkcolor},
								-value       => 'l',
								-text        => 'Latin-1',
		  )->grid( -row => 1, -column => 1 );
		$tframe->Radiobutton(
							  -variable    => \$lglobal{groutp},
							  -selectcolor => $lglobal{checkcolor},
							  -value       => 'n',
							  -text        => 'Greek Name',
		)->grid( -row => 1, -column => 2 );
		$tframe->Radiobutton(
							  -variable    => \$lglobal{groutp},
							  -selectcolor => $lglobal{checkcolor},
							  -value       => 'h',
							  -text        => 'HTML code',
		)->grid( -row => 1, -column => 3 );

		if ( $Tk::version ge 8.4 ) {
			$tframe->Radiobutton(
								  -variable    => \$lglobal{groutp},
								  -selectcolor => $lglobal{checkcolor},
								  -value       => 'u',
								  -text        => 'UTF-8',
			)->grid( -row => 1, -column => 4 );
		}
		$tframe->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				my $spot = $lglobal{grtext}->index('insert');
				$lglobal{grtext}->insert( 'insert', ' ' );
				$lglobal{grtext}->markSet( 'insert', "$spot+1c" );
				$lglobal{grtext}->focus;
				$lglobal{grtext}->see('insert');
			},
			-text => 'Space',
		)->grid( -row => 1, -column => 5 );
		$tframe->Button(
						 -activebackground => $::activecolor,
						 -command          => \&movegreek,
						 -text             => 'Transfer',
		)->grid( -row => 1, -column => 6 );
		$tframe->Button(
						-activebackground => $::activecolor,
						-command => sub { movegreek(); findandextractgreek(); },
						-text    => 'Transfer and get next',
		)->grid( -row => 1, -column => 7 );
		if ( $Tk::version ge 8.4 ) {
			my $tframe2 =
			  $lglobal{grpop}->Frame->pack(
											-expand => 'no',
											-fill   => 'none',
											-anchor => 'n',
											-pady   => 3
			  );
			$tframe2->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					my @ranges      = $lglobal{grtext}->tagRanges('sel');
					my $range_total = @ranges;
					if ( $range_total == 0 ) {
						push @ranges, ( '1.0', 'end' );
					}
					my $textindex = 0;
					my $end       = pop(@ranges);
					my $start     = pop(@ranges);
					my $selection = $lglobal{grtext}->get( $start, $end );
					$lglobal{grtext}->delete( $start, $end );
					$lglobal{grtext}->insert( $start, togreektr($selection) );
					if ( $lglobal{grtext}->get( 'end -1c', 'end' ) =~ /^$/ ) {
						$lglobal{grtext}->delete( 'end -1c', 'end' );
					}
				},
				-text => 'ASCII->Greek',
			)->grid( -row => 1, -column => 1, -padx => 2 );
			$tframe2->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					my @ranges      = $lglobal{grtext}->tagRanges('sel');
					my $range_total = @ranges;
					if ( $range_total == 0 ) {
						push @ranges, ( '1.0', 'end' );
					}
					my $textindex = 0;
					my $end       = pop(@ranges);
					my $start     = pop(@ranges);
					my $selection = $lglobal{grtext}->get( $start, $end );
					$lglobal{grtext}->delete( $start, $end );
					$lglobal{grtext}->insert( $start, fromgreektr($selection) );
					if ( $lglobal{grtext}->get( 'end -1c', 'end' ) =~ /^$/ ) {
						$lglobal{grtext}->delete( 'end -1c', 'end' );
					}
				},
				-text => 'Greek->ASCII',
			)->grid( -row => 1, -column => 2, -padx => 2 );
			$tframe2->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					my @ranges      = $lglobal{grtext}->tagRanges('sel');
					my $range_total = @ranges;
					if ( $range_total == 0 ) {
						push @ranges, ( '1.0', 'end' );
					}
					my $textindex = 0;
					my $end       = pop(@ranges);
					my $start     = pop(@ranges);
					my $selection = $lglobal{grtext}->get( $start, $end );
					$lglobal{grtext}->delete( $start, $end );
					$lglobal{grtext}
					  ->insert( $start, betagreek( 'unicode', $selection ) );
					if ( $lglobal{grtext}->get( 'end -1c', 'end' ) =~ /^$/ ) {
						$lglobal{grtext}->delete( 'end -1c', 'end' );
					}
				},
				-text => 'Beta code->Unicode',
			)->grid( -row => 1, -column => 3, -padx => 2 );
			$tframe2->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					my @ranges      = $lglobal{grtext}->tagRanges('sel');
					my $range_total = @ranges;
					if ( $range_total == 0 ) {
						push @ranges, ( '1.0', 'end' );
					}
					my $textindex = 0;
					my $end       = pop(@ranges);
					my $start     = pop(@ranges);
					my $selection = $lglobal{grtext}->get( $start, $end );
					$lglobal{grtext}->delete( $start, $end );
					$lglobal{grtext}
					  ->insert( $start, betagreek( 'beta', $selection ) );
					if ( $lglobal{grtext}->get( 'end -1c', 'end' ) =~ /^$/ ) {
						$lglobal{grtext}->delete( 'end -1c', 'end' );
					}
				},
				-text => 'Unicode->Beta code',
			)->grid( -row => 1, -column => 4, -padx => 2 );
		}
		my $frame =
		  $lglobal{grpop}->Frame( -background => $bkgcolor )
		  ->pack( -expand => 'no', -fill => 'none', -anchor => 'n' );
		my $index = 0;
		for my $column (@greek) {
			my $row = 1;
			$index++;
			$frame->Label(
						   -text       => ${$column}[0],
						   -font       => $grfont,
						   -background => $bkgcolor,
			)->grid( -row => $row, -column => $index, -padx => 2 );
			$row++;
			$lglobal{buttons}->{ ${$column}[1] } =
			  $frame->Button(
				   -activebackground => $::activecolor,
				   -image            => $lglobal{images}->{ ${$column}[1] },
				   -relief           => 'flat',
				   -borderwidth      => 0,
				   -command =>
					 [ sub { putgreek( $_[0], \%attributes ) }, ${$column}[1] ],
				   -highlightthickness => 0,
			  )->grid( -row => $row, -column => $index, -padx => 2 );
			$row++;
			$lglobal{buttons}->{ ${$column}[2] } =
			  $frame->Button(
				   -activebackground => $::activecolor,
				   -image            => $lglobal{images}->{ ${$column}[2] },
				   -relief           => 'flat',
				   -borderwidth      => 0,
				   -command =>
					 [ sub { putgreek( $_[0], \%attributes ) }, ${$column}[2] ],
				   -highlightthickness => 0,
			  )->grid( -row => $row, -column => $index, -padx => 2 );
			$row++;
			next unless ( ${$column}[3] );
			$lglobal{buttons}->{ ${$column}[3] } =
			  $frame->Button(
				   -activebackground => $::activecolor,
				   -image            => $lglobal{images}->{ ${$column}[3] },
				   -relief           => 'flat',
				   -borderwidth      => 0,
				   -command =>
					 [ sub { putgreek( $_[0], \%attributes ) }, ${$column}[3] ],
				   -highlightthickness => 0,
			  )->grid( -row => $row, -column => $index, -padx => 2 );
			$row++;
			next unless ( ${$column}[4] );
			$lglobal{buttons}->{ ${$column}[4] } =
			  $frame->Button(
				   -activebackground => $::activecolor,
				   -image            => $lglobal{images}->{ ${$column}[4] },
				   -relief           => 'flat',
				   -borderwidth      => 0,
				   -command =>
					 [ sub { putgreek( $_[0], \%attributes ) }, ${$column}[4] ],
				   -highlightthickness => 0,
			  )->grid( -row => $row, -column => $index, -padx => 2 );
		}
		$frame->Label(
					   -text       => 'ou',
					   -font       => $grfont,
					   -background => $bkgcolor,
		)->grid( -row => 4, -column => 16, -padx => 2 );
		$lglobal{buttons}->{'oulig'} =
		  $frame->Button(
						  -activebackground => $::activecolor,
						  -image            => $lglobal{images}->{'oulig'},
						  -relief           => 'flat',
						  -borderwidth      => 0,
						  -command => sub { putgreek( 'oulig', \%attributes ) },
						  -highlightthickness => 0,
		  )->grid( -row => 5, -column => 16 );
		my $bframe =
		  $lglobal{grpop}->Frame->pack(
										-expand => 'yes',
										-fill   => 'both',
										-anchor => 'n'
		  );
		$lglobal{grtext} =
		  $bframe->Scrolled(
							 'TextEdit',
							 -height     => 8,
							 -width      => 50,
							 -wrap       => 'word',
							 -background => $bkgcolor,
							 -font       => $lglobal{utffont},
							 -wrap       => 'none',
							 -setgrid    => 'true',
							 -scrollbars => 'se',
		  )->pack(
				   -expand => 'yes',
				   -fill   => 'both',
				   -anchor => 'nw',
				   -pady   => 5
		  );
		$lglobal{grtext}->bind(
			'<FocusIn>',
			sub {
				$lglobal{hasfocus} = $lglobal{grtext};
			}
		);
		drag( $lglobal{grtext} );
		if ( $Tk::version ge 8.4 ) {
			my $bframe2 =
			  $lglobal{grpop}->Frame( -relief => 'ridge' )
			  ->pack( -expand => 'n', -anchor => 's' );
			$bframe2->Label(
							 -text => 'Character Builder',
							 -font => $lglobal{utffont},
			)->pack( -side => 'left', -padx => 2 );
			$buildlabel =
			  $bframe2->Label(
							   -text       => '',
							   -width      => 5,
							   -font       => $lglobal{utffont},
							   -background => $bkgcolor,
							   -relief     => 'ridge'
			  )->pack( -side => 'left', -padx => 2 );
			$lglobal{buildentry} = $bframe2->Entry(
				-width      => 5,
				-font       => $lglobal{utffont},
				-background => $bkgcolor,
				-relief     => 'ridge',
				-validate   => 'all',
				-vcmd       => sub {
					my %hash = (
								 %{ $lglobal{grkbeta1} },
								 %{ $lglobal{grkbeta2} },
								 %{ $lglobal{grkbeta3} }
					);
					%hash         = reverse %hash;
					$hash{'a'}    = "\x{3B1}";
					$hash{'A'}    = "\x{391}";
					$hash{'e'}    = "\x{3B5}";
					$hash{'E'}    = "\x{395}";
					$hash{"�"}   = "\x{397}";
					$hash{"�"}   = "\x{3B7}";
					$hash{'I'}    = "\x{399}";
					$hash{'i'}    = "\x{3B9}";
					$hash{'O'}    = "\x{39F}";
					$hash{'o'}    = "\x{3BF}";
					$hash{'Y'}    = "\x{3A5}";
					$hash{'y'}    = "\x{3C5}";
					$hash{'U'}    = "\x{3A5}";
					$hash{'u'}    = "\x{3C5}";
					$hash{"�"}   = "\x{3A9}";
					$hash{"�"}   = "\x{3C9}";
					$hash{'R'}    = "\x{3A1}";
					$hash{'r'}    = "\x{3C1}";
					$hash{'B'}    = "\x{392}";
					$hash{'b'}    = "\x{3B2}";
					$hash{'G'}    = "\x{393}";
					$hash{'g'}    = "\x{3B3}";
					$hash{'D'}    = "\x{394}";
					$hash{'d'}    = "\x{3B4}";
					$hash{'Z'}    = "\x{396}";
					$hash{'z'}    = "\x{3B6}";
					$hash{'K'}    = "\x{39A}";
					$hash{'k'}    = "\x{3BA}";
					$hash{'L'}    = "\x{39B}";
					$hash{'l'}    = "\x{3BB}";
					$hash{'M'}    = "\x{39C}";
					$hash{'m'}    = "\x{3BC}";
					$hash{'N'}    = "\x{39D}";
					$hash{'n'}    = "\x{3BD}";
					$hash{'X'}    = "\x{39E}";
					$hash{'x'}    = "\x{3BE}";
					$hash{'P'}    = "\x{3A0}";
					$hash{'p'}    = "\x{3C0}";
					$hash{'R'}    = "\x{3A1}";
					$hash{'r'}    = "\x{3C1}";
					$hash{'S'}    = "\x{3A3}";
					$hash{'s'}    = "\x{3C3}";
					$hash{'s '}   = "\x{3C2}";
					$hash{'T'}    = "\x{3A4}";
					$hash{'t'}    = "\x{3C4}";
					$hash{'th'}   = "\x{03B8}";
					$hash{'ng'}   = "\x{03B3}\x{03B3}";
					$hash{'nk'}   = "\x{03B3}\x{03BA}";
					$hash{'nx'}   = "\x{03B3}\x{03BE}";
					$hash{'rh'}   = "\x{1FE5}";
					$hash{'ph'}   = "\x{03C6}";
					$hash{'nch'}  = "\x{03B3}\x{03C7}";
					$hash{'nc'}   = "";
					$hash{'c'}    = "";
					$hash{'C'}    = "";
					$hash{'ch'}   = "\x{03C7}";
					$hash{'ps'}   = "\x{03C8}";
					$hash{'CH'}   = "\x{03A7}";
					$hash{'TH'}   = "\x{0398}";
					$hash{'PH'}   = "\x{03A6}";
					$hash{'PS'}   = "\x{03A8}";
					$hash{'Ch'}   = "\x{03A7}";
					$hash{'Th'}   = "\x{0398}";
					$hash{'Ph'}   = "\x{03A6}";
					$hash{'Ps'}   = "\x{03A8}";
					$hash{'e^'}   = "\x{397}";
					$hash{'E^'}   = "\x{3B7}";
					$hash{'O^'}   = "\x{3A9}";
					$hash{'o^'}   = "\x{3C9}";
					$hash{'H'}    = "\x{397}";
					$hash{'h'}    = "\x{3B7}";
					$hash{'W'}    = "\x{3A9}";
					$hash{'w'}    = "\x{3C9}";
					$hash{' '}    = ' ';
					$hash{'u\+'}  = "\x{1FE2}";
					$hash{'u/+'}  = "\x{1FE3}";
					$hash{'u~+'}  = "\x{1FE7}";
					$hash{'u/+'}  = "\x{03B0}";
					$hash{'u)\\'} = "\x{1F52}";
					$hash{'u(\\'} = "\x{1F53}";
					$hash{'u)/'}  = "\x{1F54}";
					$hash{'u(/'}  = "\x{1F55}";
					$hash{'u~)'}  = "\x{1F56}";
					$hash{'u~('}  = "\x{1F57}";
					$hash{'U(\\'} = "\x{1F5B}";
					$hash{'U(/'}  = "\x{1F5D}";
					$hash{'U~('}  = "\x{1F5F}";
					$hash{'u+'}   = "\x{03CB}";
					$hash{'U+'}   = "\x{03AB}";
					$hash{'u='}   = "\x{1FE0}";
					$hash{'u_'}   = "\x{1FE1}";
					$hash{'r)'}   = "\x{1FE4}";
					$hash{'r('}   = "\x{1FE5}";
					$hash{'u~'}   = "\x{1FE6}";
					$hash{'U='}   = "\x{1FE8}";
					$hash{'U_'}   = "\x{1FE9}";
					$hash{'U\\'}  = "\x{1FEA}";
					$hash{'U/'}   = "\x{1FEB}";
					$hash{'u\\'}  = "\x{1F7A}";
					$hash{'u/'}   = "\x{1F7B}";
					$hash{'u)'}   = "\x{1F50}";
					$hash{'u('}   = "\x{1F51}";
					$hash{'U('}   = "\x{1F59}";

					if ( ( $_[0] eq '' ) or ( exists $hash{ $_[0] } ) ) {
						$buildlabel->configure( -text => $hash{ $_[0] } );
						return 1;
					}
				}
			)->pack( -side => 'left', -padx => 2 );
			$lglobal{buildentry}->bind(
				'<FocusIn>',
				sub {
					$lglobal{hasfocus} = $lglobal{buildentry};
				}
			);
			$lglobal{buildentry}->bind(
				$lglobal{buildentry},
				'<Return>',
				sub {
					my $index = $lglobal{grtext}->index('insert');
					$index = 'end' unless $index;
					my $char = $buildlabel->cget( -text );
					$char = "\n" unless $char;
					$lglobal{grtext}->insert( $index, $char );
					$lglobal{grtext}->markSet( 'insert', "$index+1c" );
					$lglobal{buildentry}->delete( '0', 'end' );
					$lglobal{buildentry}->focus;
				}
			);
			$lglobal{buildentry}->bind(
				$lglobal{buildentry},
				'<asciicircum>',
				sub {
					my $string = $lglobal{buildentry}->get;
					if ( $string =~ /(O\^|o\^|E\^|e\^)/ ) {
						$string =~ tr/OoEe/����/;
						$string =~ s/\^//;
					}
					$lglobal{buildentry}->delete( '0', 'end' );
					$lglobal{buildentry}->insert( 'end', $string );
				}
			);
			$lglobal{buildentry}
			  ->eventAdd( '<<alias>>' => '<h>', '<H>', '<w>', '<W>' );
			$lglobal{buildentry}->bind(
				$lglobal{buildentry},
				'<<alias>>',
				sub {
					my $string = $lglobal{buildentry}->get;
					if ( $string =~ /(^h$|^H$|^w$|^W$)/ ) {
						$string =~ tr/WwHh/����/;
						$lglobal{buildentry}->delete( '0', 'end' );
						$lglobal{buildentry}->insert( 'end', $string );
					}
				}
			);
			$lglobal{buildentry}->bind(
				$lglobal{buildentry},
				'<BackSpace>',
				sub {
					if ( $lglobal{buildentry}->get ) {
						$lglobal{buildentry}->delete('insert');
					} else {
						$lglobal{grtext}->delete( 'insert -1c', 'insert' );
					}
				}
			);
			for (qw!( ) / \ | ~ + = _!) {
				$bframe2->Button(
								  -activebackground => $::activecolor,
								  -text             => $_,
								  -font             => $lglobal{utffont},
								  -borderwidth      => 0,
								  -command          => \&placechar,
				)->pack( -side => 'left', -padx => 1 );
			}
		}

		$lglobal{grpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
				movegreek();
				for my $image ( keys %attributes ) {
					my $pic = $lglobal{buttons}->{$image}->cget( -image );
					$pic->delete;
					$lglobal{buttons}->{$image}->destroy;
				}
				%attributes = ();
				$lglobal{grpop}->destroy;
				undef $lglobal{grpop};
			}
		);
		$glatin->select;
		$lglobal{grtext}->SetGUICallbacks( [] );
	}
}

sub regexref {
	if ( defined( $lglobal{regexrefpop} ) ) {
		$lglobal{regexrefpop}->deiconify;
		$lglobal{regexrefpop}->raise;
		$lglobal{regexrefpop}->focus;
	} else {
		$lglobal{regexrefpop} = $top->Toplevel;
		$lglobal{regexrefpop}->title('Regex Quick Reference');
		initialize_popup_with_deletebinding('regexrefpop');
		my $button_ok = $lglobal{regexrefpop}->Button(
			-activebackground => $::activecolor,
			-text             => 'Close',
			-command          => sub {
				$lglobal{regexrefpop}->destroy;
				undef $lglobal{regexrefpop};
			}
		)->pack( -pady => 6 );
		my $regtext =
		  $lglobal{regexrefpop}->Scrolled(
										   'ROText',
										   -scrollbars => 'se',
										   -background => $bkgcolor,
										   -font       => $lglobal{font},
		  )->pack( -anchor => 'n', -expand => 'y', -fill => 'both' );
		drag($regtext);
		if ( -e 'regref.txt' ) {
			if ( open my $ref, '<', 'regref.txt' ) {
				while (<$ref>) {
					$_ =~ s/\cM\cJ|\cM|\cJ/\n/g;

					#$_ = eol_convert($_);
					$regtext->insert( 'end', $_ );
				}
			} else {
				$regtext->insert( 'end',
						  'Could not open Regex Reference file - regref.txt.' );
			}
		} else {
			$regtext->insert( 'end',
						  'Could not find Regex Reference file - regref.txt.' );
		}
	}
}

# Pop up window to allow entering Unicode characters by ordinal number
sub utford {
	my $ord;
	my $base = 'dec';
	if ( $lglobal{ordpop} ) {
		$lglobal{ordpop}->deiconify;
		$lglobal{ordpop}->raise;
	} else {
		$lglobal{ordpop} = $top->Toplevel;
		$lglobal{ordpop}->title('Ordinal to Char');
		initialize_popup_with_deletebinding('ordpop');

		$lglobal{ordpop}->resizable( 'yes', 'no' );
		my $frame =
		  $lglobal{ordpop}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		my $frame2 =
		  $lglobal{ordpop}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		$frame->Label( -text => 'Ordinal of char.' )
		  ->grid( -row => 1, -column => 1 );
		my $charlbl = $frame2->Label( -text => '', -width => 50 )->pack;
		my ( $inentry, $outentry );
		$frame->Radiobutton(
							 -variable => \$base,
							 -value    => 'hex',
							 -text     => 'Hex',
							 -command  => sub { $inentry->validate }
		)->grid( -row => 0, -column => 1 );
		$frame->Radiobutton(
							 -variable => \$base,
							 -value    => 'dec',
							 -text     => 'Decimal',
							 -command  => sub { $inentry->validate }
		)->grid( -row => 0, -column => 2 );
		$inentry = $frame->Entry(
			-background   => $bkgcolor,
			-width        => 6,
			-font         => '{sanserif} 14',
			-textvariable => \$ord,
			-validate     => 'key',
			-vcmd         => sub {

				if ( $_[0] eq '' ) {
					$outentry->delete( '1.0', 'end' );
					return 1;
				}
				my ( $name, $char );
				if ( $base eq 'hex' ) {
					return 0 unless ( $_[0] =~ /^[a-fA-F\d]{0,4}$/ );
					$char = chr( hex( $_[0] ) );
					$name = charnames::viacode( hex( $_[0] ) );
				} elsif ( $base eq 'dec' ) {
					return 0
					  unless (    ( $_[0] =~ /^\d{0,5}$/ )
							   && ( $_[0] < 65519 ) );
					$char = chr( $_[0] );
					$name = charnames::viacode( $_[0] );
				}
				$outentry->delete( '1.0', 'end' );
				$outentry->insert( 'end', $char );
				$charlbl->configure( -text => $name );
				return 1;
			},
		)->grid( -row => 1, -column => 2 );
		$outentry = $frame->ROText(
									-background => $bkgcolor,
									-relief     => 'sunken',
									-font       => '{sanserif} 14',
									-width      => 6,
									-height     => 1,
		)->grid( -row => 2, -column => 2 );
		my $frame1 =
		  $lglobal{ordpop}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		my $button = $frame1->Button(
			-text    => 'OK',
			-width   => 8,
			-command => sub {
				$lglobal{hasfocus}
				  ->insert( 'insert', $outentry->get( '1.0', 'end -1c' ) );
			},
		)->grid( -row => 1, -column => 1 );
		$frame1->Button(
			-text    => 'Close',
			-width   => 8,
			-command => sub {
				$lglobal{ordpop}->destroy;
				undef $lglobal{ordpop};
			},
		)->grid( -row => 1, -column => 2 );
	}
}

sub uchar {
	if ( defined $lglobal{ucharpop} ) {
		$lglobal{ucharpop}->deiconify;
		$lglobal{ucharpop}->raise;
	} else {
		return unless blocks_check();
		require q(unicore/Blocks.pl);
		require q(unicore/Name.pl);
		my $stopit = 0;
		my %blocks;
		for ( split /\n/, do 'unicore/Blocks.pl' ) {
			my @array = split /\t/, $_;
			$blocks{ $array[2] } = [ @array[ 0, 1 ] ];
		}
		$lglobal{ucharpop} = $top->Toplevel;
		$lglobal{ucharpop}->title('Unicode Character Search');
		initialize_popup_with_deletebinding('ucharpop');

		$lglobal{ucharpop}->geometry('550x450');
		my $cframe = $lglobal{ucharpop}->Frame->pack;
		my $frame0 =
		  $lglobal{ucharpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n', -pady => 4 );
		my $sizelabel;
		my ( @textchars, @textlabels );
		my $pane =
		  $lglobal{ucharpop}->Scrolled(
										'Pane',
										-background => $bkgcolor,
										-scrollbars => 'se',
										-sticky     => 'wne',
		  )->pack( -expand => 'y', -fill => 'both', -anchor => 'nw' );
		drag($pane);
		BindMouseWheel($pane);
		my $fontlist = $cframe->BrowseEntry(
			-label     => 'Font',
			-browsecmd => sub {
				utffontinit();
				for (@textchars) {
					$_->configure( -font => $lglobal{utffont} );
				}
			},
			-variable => \$utffontname,
		)->grid( -row => 1, -column => 1, -padx => 8, -pady => 2 );
		$fontlist->insert( 'end', sort( $textwindow->fontFamilies ) );
		my $bigger = $cframe->Button(
			-activebackground => $::activecolor,
			-text             => 'Bigger',
			-command          => sub {
				$utffontsize++;
				utffontinit();
				for (@textchars) {
					$_->configure( -font => $lglobal{utffont} );
				}
				$sizelabel->configure( -text => $utffontsize );
			},
		)->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
		$sizelabel =
		  $cframe->Label( -text => $utffontsize )
		  ->grid( -row => 1, -column => 3, -padx => 2, -pady => 2 );
		my $smaller = $cframe->Button(
			-activebackground => $::activecolor,
			-text             => 'Smaller',
			-command          => sub {
				$utffontsize--;
				utffontinit();
				for (@textchars) {
					$_->configure( -font => $lglobal{utffont} );
				}
				$sizelabel->configure( -text => $utffontsize );
			},
		)->grid( -row => 1, -column => 4, -padx => 2, -pady => 2 );

		$frame0->Label( -text => 'Search Characteristics ', )
		  ->grid( -row => 1, -column => 1 );
		my $characteristics =
		  $frame0->Entry(
						  -width      => 40,
						  -background => $bkgcolor
		  )->grid( -row => 1, -column => 2 );
		my $doit = $frame0->Button(
			-text    => 'Search',
			-command => sub {
				for ( @textchars, @textlabels ) {
					$_->destroy;
				}
				$stopit = 0;
				my $row = 0;
				@textlabels = @textchars = ();
				my @chars = split /\s+/, uc( $characteristics->get );
				my @lines = split /\n/,  do 'unicore/Name.pl';
				while (@lines) {
					my @items = split /\t+/, shift @lines;
					my ( $ord, $name ) = ( $items[0], $items[-1] );
					last if ( hex $ord > 65535 );
					if ($stopit) { $stopit = 0; last; }
					my $count = 0;
					for my $char (@chars) {
						$count++;
						last unless $name =~ /\b$char\b/;
						if ( @chars == $count ) {
							my $block = '';
							for ( keys %blocks ) {
								if (    hex( $blocks{$_}[0] ) <= hex($ord)
									 && hex( $blocks{$_}[1] ) >= hex($ord) )
								{
									$block = $_;
									last;
								}
							}
							$textchars[$row] =
							  $pane->Label(
											-text       => chr( hex $ord ),
											-font       => $lglobal{utffont},
											-background => $bkgcolor,
							  )->grid(
									   -row    => $row,
									   -column => 0,
									   -sticky => 'w'
							  );
							utfchar_bind( $textchars[$row] );

							$textlabels[$row] =
							  $pane->Label(
								   -text => "$name  -  Ordinal $ord  -  $block",
								   -background => $bkgcolor,
							  )->grid(
									   -row    => $row,
									   -column => 1,
									   -sticky => 'w'
							  );
							utflabel_bind($textlabels[$row],  $block,
										  $blocks{$block}[0], $blocks{$block}[1]
							);
							$row++;
						}
					}
				}
			},
		)->grid( -row => 1, -column => 3 );
		$frame0->Button(
						 -text    => 'Stop',
						 -command => sub { $stopit = 1; },
		)->grid( -row => 1, -column => 4 );
		$characteristics->bind( '<Return>' => sub { $doit->invoke } );
	}
}

sub addpagelinks {
	my $selection = shift;
	$selection =~ s/(\d{1,3})-(\d{1,3})/<a href="#Page_$1">$1-$2<\/a>/g;
	$selection =~ s/(\d{1,3})([,;\.])/<a href="#Page_$1">$1<\/a>$2/g;
	$selection =~ s/\s(\d{1,3})\s/ <a href="#Page_$1">$1<\/a> /g;
	$selection =~ s/(\d{1,3})$/<a href="#Page_$1">$1<\/a>/;
	return $selection;
}

sub text_convert_smallcaps {
	searchpopup();
	searchoptset(qw/0 x x 1/);
	$lglobal{searchentry}->delete( '1.0', 'end' );
	$lglobal{searchentry}->insert( 'end', "<sc>(\\n?[^<]+)</sc>" );
	$lglobal{replaceentry}->delete( '1.0', 'end' );
	$lglobal{replaceentry}->insert( 'end', "\\U\$1\\E" );
}

sub text_remove_smallcaps_markup {
	searchpopup();
	searchoptset(qw/0 x x 1/);
	$lglobal{searchentry}->delete( '1.0', 'end' );
	$lglobal{searchentry}->insert( 'end', "<sc>(\\n?[^<]+)</sc>" );
	$lglobal{replaceentry}->delete( '1.0', 'end' );
	$lglobal{replaceentry}->insert( 'end', "\$1" );
}

# Popup for choosing replacement characters, etc.
sub runtests {

	# From the command line run "guiguts.pl runtests"
	use Test::More;    #tests => 34;
	ok( 1 == 1, "Dummy test 1==1" );

	#if ( -e "setting.rc" ) { rename( "setting.rc", "setting.old" ); }
	ok( roman(22) eq 'XXII.', "roman(22)==XXII" );
	ok( arabic('XXII.') eq '22', "arabic(XXII.) eq '22'" );
	ok(not (arabic('XXII.') eq '23'), "not arabic(XXII.) eq '23'" );
	my $ln;
	my @book   = ();
	my $inbody = 0;
	$lglobal{pageanch} = 1;
	$lglobal{pagecmt}  = 0;

	ok( 1 == do { 1 }, "do block" );
	ok( -e "tests/errorcheck.html", "tests/errorcheck.html exists" );
	ok( 1 == do { openfile("tests/errorcheck.html"); 1 }, "openfile on tests/errorcheck.html" );
	errorcheckpop_up($textwindow,$top,'Check All');
	open my $logfile, ">","tests/errors.err" || die "output file error\n";
	print $logfile $main::lglobal{errorchecklistbox}->get( '1.0', 'end' ); 
	close $logfile;
	ok(
		compare( "tests/errors.err", 'tests/errorcheckbaseline.txt' ) ==
		  0,
		"Check All was successful"
	);
	print "begin diff\n";
	system "diff tests/errorcheckbaseline.txt tests/errors.err";
	print "end diff\n";
	unlink 'tests/errors.err';
	ok( 1 == do { openfile("readme.txt"); 1 }, "openfile on readme.txt" );
	ok( "readme.txt" eq $textwindow->FileName, "File is named readme.txt" );
	ok( 1 == do { file_close($textwindow); 1 }, "close readme.txt" );

	# Test of rewrapping
	ok( -e "tests/testfile.txt", "tests/testfile.txt exists" );
	ok( 1 == do { openfile("tests/testfile.txt"); 1 },
		"openfile on tests/testfile.txt" );
	ok( 1 == do { $textwindow->selectAll; 1 }, "Select All" );
	ok(
		1 == do {
			selectrewrap( $textwindow, $lglobal{seepagenums},
						  $scannos_highlighted, $rwhyphenspace );
			1;
		},
		"Rewrap Selection"
	);
	ok( 1 == do { $textwindow->SaveUTF('tests/testfilewrapped.txt'); 1 },
		"File saved as tests/testfilewrapped" );
	ok( -e 'tests/testfilewrapped.txt', "tests/testfilewrapped.txt was saved" );

	ok( -e "tests/testfilebaseline.txt", "tests/testfilebaseline.txt exists" );
	ok(
		compare( "tests/testfilebaseline.txt", 'tests/testfilewrapped.txt' ) ==
		  0,
		"Rewrap was successful"
	);
	print "begin diff\n";
	system "diff tests/testfilebaseline.txt tests/testfilewrapped.txt";
	print "end diff\n";
	unlink 'tests/testfilewrapped.txt';
	ok( not( -e "tests/testfilewrapped.txt" ),
		"Deletion confirmed of tests/testfilewrapped.txt" );
	unlink 'setting.rc';
	if ( -e "setting.old" ) { rename( "setting.old", "setting.rc" ); }

	# Test 1 of HTML generation
	ok( 1 == do { openfile("tests/testhtml1.txt"); 1 },
		"openfile on tests/testhtml1.txt" );
	ok( 1 == do { htmlautoconvert($textwindow,$top); 1 }, "openfile on tests/testhtml1.txt" );
	ok( 1 == do { $textwindow->SaveUTF('tests/testhtml1.html'); 1 },
		"test of file save as tests/testfilewrapped" );
	ok( -e 'tests/testhtml1.html', "tests/testhtml1.html was saved" );

	ok( -e "tests/testhtml1baseline.html",
		"tests/testhtml1baseline.html exists" );
	open my $infile,  "<","tests/testhtml1.html"       || die "no source file\n";
	open $logfile, ">","tests/testhtml1temp.html" || die "output file error\n";
	while ( $ln = <$infile> ) {
		if ($inbody) { print $logfile $ln; }
		if ( $ln =~ /<\/head>/ ) {
			$inbody = 1;
		}
	}
	close $infile;
	close $logfile;
	ok(
		compare( "tests/testhtml1baseline.html", 'tests/testhtml1temp.html' ) ==
		  0,
		"Autogenerate HTML successful"
	);
	print "begin diff\n";
	system "diff tests/testhtml1baseline.html tests/testhtml1temp.html";
	print "end diff\n";

	unlink 'tests/testhtml1.html';
	unlink 'tests/testhtml1temp.html';
	unlink 'tests/testhtml1-htmlbak.txt';
	unlink 'tests/testhtml1-htmlbak.txt.bin';
	ok( not( -e "tests/testhtml1temp.html" ),
		"Deletion confirmed of tests/testhtml1temp.html" );
	ok( not( -e "tests/testhtml1.html" ),
		"Deletion confirmed of tests/testhtml1.html" );

	# Test 2 of HTML generation
	ok( 1 == do { openfile("tests/testhtml2.txt"); 1 },
		"openfile on tests/testhtml2.txt" );
	ok( 1 == do { htmlautoconvert($textwindow,$top); 1 }, "openfile on tests/testhtml2.txt" );
	ok( 1 == do { $textwindow->SaveUTF('tests/testhtml2.html'); 1 },
		"test of file save as tests/testfilewrapped" );
	ok( -e 'tests/testhtml2.html', "tests/testhtml2.html was saved" );

	ok( -e "tests/testhtml2baseline.html",
		"tests/testhtml2baseline.html exists" );
	open $infile,"<","tests/testhtml2.html"       || die "no source file\n";
	open $logfile, ">", "tests/testhtml2temp.html" || die "output file error\n";
	@book   = ();
	$inbody = 0;
	while ( $ln = <$infile> ) {
		if ($inbody) { print $logfile $ln; }
		if ( $ln =~ /<\/head>/ ) {
			$inbody = 1;
		}
	}
	close $infile;
	close $logfile;
	ok(
		compare( "tests/testhtml2baseline.html", 'tests/testhtml2temp.html' ) ==
		  0,
		"Autogenerate HTML successful"
	);
	print "begin diff\n";
	system "diff tests/testhtml2baseline.html tests/testhtml2temp.html";
	print "end diff\n";

	unlink 'tests/testhtml2.html';
	unlink 'tests/testhtml2temp.html';
	unlink 'tests/testhtml2-htmlbak.txt';
	unlink 'tests/testhtml2-htmlbak.txt.bin';
	ok( not( -e "tests/testhtml2temp.html" ),
		"Deletion confirmed of tests/testhtml2temp.html" );
	ok( not( -e "tests/testhtml2.html" ),
		"Deletion confirmed of tests/testhtml2.html" );

	#	fnview();
	#htmlimage();
##errorcheckpop_up($textwindow,$top,'test');
	#gcheckpop_up();
	#harmonicspop();
	#pnumadjust();
	#searchpopup();
	#asciipopup();
	#alignpopup();
	#wordfrequency();
	#jeebiespop_up();
	#separatorpopup();
	#footnotepop();
	#externalpopup();
	#utfpopup();
	#about_pop_up();
	#opspop_up();
	#greekpopup();
	ok( $debug == 0, "Do not release with \$debug = 1" );
	ok(deaccent('�������������������������������������������������������') eq 'AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiOOOOOOooooooNnUUUUuuuuYyy'
	,"deaccent('�������������������������������������������������������')");
	ok((entity('\xff') eq '&yuml;'), "entity('\\xff') eq '&yuml;'");
	ok( $debug == 0, "Do not release with \$debug = 1" );
	ok( 1 == 1, "This is the last test" );
	done_testing();
	exit;
}

# Ready to enter main loop
checkforupdatesmonthly();
		unless ( -e 'header.txt' ) {
			&main::copy( 'headerdefault.txt', 'header.txt' );
		}
if ( $lglobal{runtests} ) {
	runtests();
} else {
	print
"If you have any problems, please report any error messages that appear here.\n";
	MainLoop;
}