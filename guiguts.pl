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

our $VERSION = '1.0.7';
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

our $APP_NAME = 'Guiguts';
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
use Guiguts::SpellCheck;
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

# Do not move from guiguts.pl; do command must be run in main
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

# Do not move from guiguts.pl; do command must be run in main
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

### File Menu
# Do not move from guiguts.pl; do command must be run in main
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
									   -text    => 'WF²',
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
	unlink 'null' if ( -e 'null' );

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
	ok(deaccent('ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÑñÙÚÛÜùúûüİÿı') eq 'AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiOOOOOOooooooNnUUUUuuuuYyy'
	,"deaccent('ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÑñÙÚÛÜùúûüİÿı')");
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