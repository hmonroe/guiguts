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

# Do not move from guiguts.pl; do command must be run in main
sub spellloadprojectdict {
	getprojectdic();
	do "$::lglobal{projectdictname}"
	  if $::lglobal{projectdictname};    
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
								-value       => '´|ª',
								-text        => 'Angle quotes ´ ª',
		  )->grid( -row => 2, -column => 2, -pady => 5 );

		my $gqusel =
		  $frame3->Radiobutton(
								-variable    => \$lglobal{brsel},
								-selectcolor => $lglobal{checkcolor},
								-value       => 'ª|´',
								-text        => 'German Angle quotes ª ´',
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
						    ( $lglobal{brbrackets}[0] =~ m{[\[\(\{<´]} )
						 && ( $lglobal{brbrackets}[1] =~ m{[\]\)\}>ª]} )
					   )
					   || (    ( $lglobal{brbrackets}[0] =~ m{[\[\(\{<ª]} )
							&& ( $lglobal{brbrackets}[1] =~ m{[\]\)\}>´]} ) )
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
									   -text    => 'WF≤',
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
	ok(deaccent('¿¡¬√ƒ≈‡·‚„‰Â«Á»… ÀËÈÍÎÃÕŒœÏÌÓÔ“”‘’÷ÿÚÛÙıˆ¯—ÒŸ⁄€‹˘˙˚¸›ˇ˝') eq 'AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiOOOOOOooooooNnUUUUuuuuYyy'
	,"deaccent('¿¡¬√ƒ≈‡·‚„‰Â«Á»… ÀËÈÍÎÃÕŒœÏÌÓÔ“”‘’÷ÿÚÛÙıˆ¯—ÒŸ⁄€‹˘˙˚¸›ˇ˝')");
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