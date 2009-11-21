#!/usr/bin/perl

# $Id$

# GuiGuts text editor

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

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin . "/lib";
#use Data::Dumper;
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
                   TextEdit
                  /;

# Custom Guigut modules
use LineNumberText;
use TextUnicode;

use constant OS_Win => $^O =~ /Win/;

# ignore any watchdog timer alarms. Subroutines that take a long time to complete can trip it
$SIG{ALRM} = 'IGNORE';
$SIG{INT} = sub { myexit() };

my $DEBUG; # FIXME: This and all references can go.
my $VERSION = "0.3.0";
my $currentver = $VERSION;
my $no_proofer_url = 'http://www.pgdp.net/phpBB2/privmsg.php?mode=post';
my $yes_proofer_url = 'http://www.pgdp.net/c/stats/members/mbr_list.php?uname=';

our $activecolor      = '#f2f818';
our $auto_page_marks  = 1;
our $autobackup       = 0;
our $autosave         = 0;
our $autosaveinterval = 5;
our $bkmkhl           = '0';
our $blocklmargin     = 5;
our $blockrmargin     = 72;
our $blockwrap;
our $bold_char = "=";
our $defaultindent = 0;
our $fontname      = 'Courier New';
our $fontsize      = 10;
our $fontweight    = '';
our $geometry2     = '';
our $geometry3     = '';
our $geometry;
our $globalaspellmode   = 'normal';
our $globalbrowserstart = 'start';
our $globalimagepath    = '';
our $globallastpath     = '';
our $globalspelldictopt = '';
our $globalspellpath    = '';
our $globalviewerpath   = '';
our $gutpath            = '';
our $highlightcolor     = '#a08dfc';
our $history_size       = 20;
our $italic_char = "_";
our $jeebiesmode        = 'p';
our $jeebiespath        = '';
our $lmargin            = 1;
our $markupthreshold    = 4;
our $nobell             = 0;
our $nohighlights       = 0;
our $notoolbar          = 0;
our $operationinterrupt;
our $pngspath         = '';
our $rmargin          = 72;
our $rwhyphenspace    = 0;
our $scannoslist      = '';
our $scannoslistpath  = '';
our $scannospath      = '';
our $scrollupdatespd  = 40;
our $searchendindex   = 'end';
our $searchstartindex = '1.0';
our $singleterm       = 1;
our $spellindexbkmrk  = '';
our $stayontop        = 0;
our $suspectindex;
our $tidycommand = '';
our $toolside    = 'bottom';
our $utffontname = 'Courier New';
our $utffontsize = 14;
our $vislnnm     = 0;

our %gc;
our %jeeb;
our %pagenumbers;
our %projectdict;
our %proofers;
our %reghints = ();
our %scannoslist;

our @bookmarks = ( 0, 0, 0, 0, 0, 0 );
our @gcopt = ( 0, 0, 0, 0, 0, 0, 1, 0, 1 );
our @mygcview;
our @operations;
our @pageindex;
our @recentfile;
our @replace_history;
our @search_history;
our @sopt = ( 1, 0, 0, 0 );
our @extops = (
    {   'label'   => 'W3C Markup Validation Service',
        'command' => 'start http://validator.w3.org/'
    },
    {   'label'   => 'W3C CSS Validation Service',
        'command' => 'start http://jigsaw.w3.org/css-validator/'
    },
    {   'label'   => 'NPL Dictionary Search',
        'command' => 'start http://www.puzzlers.org/wordlists/grepdict.php'
    },
    {   'label'   => 'Pass open file to default handler',
        'command' => 'start $d$f$e'
    },
    { 'label' => '', 'command' => '' },
    { 'label' => '', 'command' => '' },
    { 'label' => '', 'command' => '' },
    { 'label' => '', 'command' => '' },
    { 'label' => '', 'command' => '' },
    { 'label' => '', 'command' => '' },
);

#All local global variables contained in one hash.
my %lglobal;

# Check for some optional modules and load if present.
# FIXME: Pop up message box informing users they are missing out.

if ( eval { require Text::LevenshteinXS } ) {
    $lglobal{LevenshteinXS} = 1;
} else {
    print
    "Install the module Text::LevenshteinXS for much faster harmonics sorting.\n";
}

# load Tk::ToolBar if it is installed
if ( eval { require Tk::ToolBar; 1; } ) {
    $lglobal{ToolBar} = 1;
} else {
    $lglobal{ToolBar} = 0;
}

# load Image::Size if it is installed
if ( eval { require Image::Size; 1; } ) {
    $lglobal{ImageSize} = 1;
} else {
    $lglobal{ImageSize} = 0;
}

# Build the main window.

my $window_title = "GutThing-" . $VERSION;
my $mw = tkinit( -title => $window_title );

initialize();

$mw->minsize( 440, 90 );


# Detect geometry changes for tracking
$mw->bind(
    '<Configure>' => sub {
        $geometry = $mw->geometry;
        $lglobal{geometryupdate} = 1;
    }
);

my $icon = $mw->Photo(
    -format => 'gif',
    -data   => '
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
    '
);

# Initialize the fonts for the two windows
fontinit();

utffontinit();

$mw->geometry($geometry) if $geometry;

$mw->configure( -menu => my $menubar
        = $mw->Menu( -menuitems => menubar_menuitems() ) );

# Build the guts of our GUI.
my $text_frame
= $mw->Frame->pack( -anchor => 'nw', -expand => 'yes', -fill => 'both' ) ;

my $counter_frame = $text_frame->Frame->pack(
    -side   => 'bottom',
    -anchor => 'sw',
    -pady   => 2,
    -expand => 0
);
my $proofer_frame = $text_frame
->Frame;    # Frame to hold proofer names. Pack it when necessary.

# The actual text widget
my $text_window = $text_frame->LineNumberText(
    -widget => 'TextUnicode',
    -exportselection => 'true',     # 'sel' tag is associated with selections
    -background      => 'white',
    -relief          => 'sunken',
    -font      => $lglobal{font},
    -wrap      => 'none',
    -curlinebg => $activecolor,
)->pack(
    -side   => 'bottom',
    -anchor => 'nw',
    -expand => 'yes',
    -fill   => 'both'
);

$mw->protocol( 'WM_DELETE_WINDOW' => \&myexit );

$text_window->SetGUICallbacks(
    [    # routines to call every time the text is edited
    \&update_indicators,
    sub {
        return if $nohighlights;
        $text_window->HighlightAllPairsBracketingCursor;
    },
    sub {
        $text_window->hidelinenum unless $vislnnm;
    }
    ]
);


textbindings(); # Set up the key bindings for the text widget

buildstatusbar();    # Build the status bar

$mw->Icon( -image => $icon ) ;  # Load the icon ito the window bar. Needs to happen late in the process

$text_window->focus;

$lglobal{hasfocus} = $text_window;

toolbar_toggle();

$mw->geometry($geometry) if $geometry;

( $lglobal{global_filename} ) = @ARGV;
die "ERROR: too many files specified. \n" if ( @ARGV > 1 );

if (@ARGV) {
    $lglobal{global_filename} = shift @ARGV;
    if ( -e $lglobal{global_filename} ) {
        $mw->update
        ;    # it may be a big file, draw the window, and then load it
        openfile( $lglobal{global_filename} );
    }
} else {
    $lglobal{global_filename} = 'No File Loaded';
}

set_autosave() if $autosave;

$text_window->CallNextGUICallback;

$mw->repeat( 200, \&updatesel );
### End window build

### Subroutines

sub initialize {
# Initialize a whole bunch of global values that used to be discrete variables
# spread willy-nilly through the code. Refactored them into a global
# hash and gathered them together in a single subroutine.
    $lglobal{alignstring}      = '.';
    $lglobal{alpha_sort}       = 'f';
    $lglobal{asciijustify}     = 'center';
    $lglobal{asciiwidth}       = 64;
    $lglobal{codewarn}         = 1;
    $lglobal{cssblockmarkup}   = 0;
    $lglobal{delay}            = 50;
    $lglobal{ffchar}           = '';
    $lglobal{footstyle}        = 'end';
    $lglobal{ftnoteindexstart} = '1.0';
    $lglobal{groutp}           = 'l';
    $lglobal{htmlimgar}        = 1;          #html image aspect ratio
    $lglobal{ignore_case}      = 0;
    $lglobal{keep_latin1} = 1;
    $lglobal{lastmatchindex}   = '1.0';
    $lglobal{lastsearchterm}   = '';
    $lglobal{longordlabel}     = 0;
    $lglobal{proofbarvisible}  = 0;
    $lglobal{regaa}            = 0;
    $lglobal{seepagenums}      = 0;
    $lglobal{selectionsearch}  = 0;
    $lglobal{showblocksize}    = 1;
    $lglobal{stepmaxwidth}     = 70;
    $lglobal{suspects_only}    = 0;
    $lglobal{tblcoljustify}    = 'l';
    $lglobal{tblrwcol}         = 1;
    $lglobal{uoutp}            = 'h';
    $lglobal{utfrangesort}     = 0;
    $lglobal{visibleline}      = '';
    $lglobal{zoneindex}        = 0;
    @{ $lglobal{ascii} } = qw/+ - + | | | + - +/;
    @{ $lglobal{fixopt} } = ( 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 );

    if ( $0 =~ m/\/|\\/ ) {
        my $dir = $0;
        $dir =~ s/(\/|\\)[^\/\\]+$/$1/;
        chdir $dir if length $dir;
    }

    unless ( my $return = do 'setting.rc' ) {
        if ( -e 'setting.rc' ) {
            open my $file, "<setting.rc"
                or warn "Could not open setting file\n";
            my @file = <$file>;
            close $file;
            open $file, ">setting.err";
            print $file @file;
            close $file;
        }
    }

    %{ $lglobal{utfblocks} } = (
        'Alphabetic Presentation Forms' => [ 'FB00', 'FB4F' ],
        'Arabic Presentation Forms-A'   => [ 'FB50', 'FDCF' ]
        ,    #Really FDFF but there are illegal characters in fdc0-fdff
        'Arabic Presentation Forms-B' => [ 'FE70', 'FEFF' ],
        'Arabic'                      => [ '0600', '06FF' ],
        'Armenian'                    => [ '0530', '058F' ],
        'Arrows'                      => [ '2190', '21FF' ],
        'Bengali'                     => [ '0980', '09FF' ],
        'Block Elements'              => [ '2580', '259F' ],

        #'Bopomofo Extended' => ['31A0', '31BF'],
        #'Bopomofo' => ['3100', '312F'],
        'Box Drawing'      => [ '2500', '257F' ],
        'Braille Patterns' => [ '2800', '28FF' ],
        'Buhid'            => [ '1740', '175F' ],
        'Cherokee'         => [ '13A0', '13FF' ],

        #'CJK Compatibility Forms' => ['FE30', 'FE4F'],
        #'CJK Compatibility Ideographs' => ['F900', 'FAFF'],
        #'CJK Compatibility' => ['3300', '33FF'],
        #'CJK Radicals Supplement' => ['2E80', '2EFF'],
        #'CJK Symbols and Punctuation' => ['3000', '303F'],
        #'CJK Unified Ideographs Extension A' => ['3400', '4DBF'],
        #'CJK Unified Ideographs' => ['4E00', '9FFF'],
        'Combining Diacritical Marks for Symbols' => [ '20D0', '20FF' ],
        'Combining Diacritical Marks'             => [ '0300', '036F' ],
        'Combining Half Marks'                    => [ 'FE20', 'FE2F' ],
        'Control Pictures'                        => [ '2400', '243F' ],
        'Currency Symbols'                        => [ '20A0', '20CF' ],
        'Cyrillic Supplementary'                  => [ '0500', '052F' ],
        'Cyrillic'                                => [ '0400', '04FF' ],
        'Devanagari'                              => [ '0900', '097F' ],
        'Dingbats'                                => [ '2700', '27BF' ],
        'Enclosed Alphanumerics'                  => [ '2460', '24FF' ],

        #'Enclosed CJK Letters and Months' => ['3200', '32FF'],
        'Ethiopic'                      => [ '1200', '137F' ],
        'General Punctuation'           => [ '2000', '206F' ],
        'Geometric Shapes'              => [ '25A0', '25FF' ],
        'Georgian'                      => [ '10A0', '10FF' ],
        'Greek and Coptic'              => [ '0370', '03FF' ],
        'Greek Extended'                => [ '1F00', '1FFF' ],
        'Gujarati'                      => [ '0A80', '0AFF' ],
        'Gurmukhi'                      => [ '0A00', '0A7F' ],
        'Halfwidth and Fullwidth Forms' => [ 'FF00', 'FFEF' ],

        #'Hangul Compatibility Jamo' => ['3130', '318F'],
        #'Hangul Jamo' => ['1100', '11FF'],
        #'Hangul Syllables' => ['AC00', 'D7AF'],
        #'Hanunoo' => ['1720', '173F'],
        'Hebrew' => [ '0590', '05FF' ],

        #'High Private Use Surrogates' => ['DB80', 'DBFF'],
        #'High Surrogates' => ['D800', 'DB7F'],
        #'Hiragana' => ['3040', '309F'],
        #'Ideographic Description Characters' => ['2FF0', '2FFF'],
        #'Kanbun' => ['3190', '319F'],
        #'Kangxi Radicals' => ['2F00', '2FDF'],
        'Kannada' => [ '0C80', '0CFF' ],

        #'Katakana Phonetic Extensions' => ['31F0', '31FF'],
        #'Katakana' => ['30A0', '30FF'],
        #'Khmer Symbols' => ['19E0', '19FF'],
        #'Khmer' => ['1780', '17FF'],
        'Lao'                       => [ '0E80', '0EFF' ],
        'Latin Extended Additional' => [ '1E00', '1EFF' ],
        'Latin Extended-A'          => [ '0100', '017F' ],
        'Latin Extended-B'          => [ '0180', '024F' ],
        'Latin IPA Extensions'      => [ '0250', '02AF' ],
        'Letterlike Symbols'        => [ '2100', '214F' ],

        #'Limbu' => ['1900', '194F'],
        #'Low Surrogates' => ['DC00', 'DFFF'],
        'Malayalam'                            => [ '0D00', '0D7F' ],
        'Mathematical Operators'               => [ '2200', '22FF' ],
        'Miscellaneous Mathematical Symbols-A' => [ '27C0', '27EF' ],
        'Miscellaneous Mathematical Symbols-B' => [ '2980', '29FF' ],
        'Miscellaneous Symbols and Arrows'     => [ '2B00', '2BFF' ],
        'Miscellaneous Symbols'                => [ '2600', '26FF' ],
        'Miscellaneous Technical'              => [ '2300', '23FF' ],
        'Mongolian'                            => [ '1800', '18AF' ],
        'Myanmar'                              => [ '1000', '109F' ],
        'Number Forms'                         => [ '2150', '218F' ],
        'Ogham'                                => [ '1680', '169F' ],
        'Optical Character Recognition'        => [ '2440', '245F' ],
        'Oriya'                                => [ '0B00', '0B7F' ],
        'Phonetic Extensions'                  => [ '1D00', '1D7F' ],
        'Runic'                                => [ '16A0', '16FF' ],
        'Sinhala'                              => [ '0D80', '0DFF' ],
        'Small Form Variants'                  => [ 'FE50', 'FE6F' ],
        'Spacing Modifier Letters'             => [ '02B0', '02FF' ],
        'Superscripts and Subscripts'          => [ '2070', '209F' ],
        'Supplemental Arrows-A'                => [ '27F0', '27FF' ],
        'Supplemental Arrows-B'                => [ '2900', '297F' ],
        'Supplemental Mathematical Operators'  => [ '2A00', '2AFF' ],
        'Syriac'                               => [ '0700', '074F' ],
        'Tagalog'                              => [ '1700', '171F' ],

        #'Tagbanwa' => ['1760', '177F'],
        #'Tai Le' => ['1950', '197F'],
        'Tamil'  => [ '0B80', '0BFF' ],
        'Telugu' => [ '0C00', '0C7F' ],
        'Thaana' => [ '0780', '07BF' ],
        'Thai'   => [ '0E00', '0E7F' ],

        #'Tibetan' => ['0F00', '0FFF'],
        'Unified Canadian Aboriginal Syllabics' => [ '1400', '167F' ],

        #'Variation Selectors' => ['FE00', 'FE0F'],
        #'Yi Radicals' => ['A490', 'A4CF'],
        #'Yi Syllables' => ['A000', 'A48F'],
        #'Yijing Hexagram Symbols' => ['4DC0', '4DFF'],
    );

    %{ $lglobal{grkbeta1} } = (
        "\x{1F00}" => 'a)',
        "\x{1F01}" => 'a(',
        "\x{1F08}" => 'A)',
        "\x{1F09}" => 'A(',
        "\x{1FF8}" => 'O\\',
        "\x{1FF9}" => 'O/',
        "\x{1FFA}" => '�\\',
        "\x{1FFB}" => '�/',
        "\x{1FFC}" => '�|',
        "\x{1F10}" => 'e)',
        "\x{1F11}" => 'e(',
        "\x{1F18}" => 'E)',
        "\x{1F19}" => 'E(',
        "\x{1F20}" => '�)',
        "\x{1F21}" => '�(',
        "\x{1F28}" => '�)',
        "\x{1F29}" => '�(',
        "\x{1F30}" => 'i)',
        "\x{1F31}" => 'i(',
        "\x{1F38}" => 'I)',
        "\x{1F39}" => 'I(',
        "\x{1F40}" => 'o)',
        "\x{1F41}" => 'o(',
        "\x{1F48}" => 'O)',
        "\x{1F49}" => 'O(',
        "\x{1F50}" => 'y)',
        "\x{1F51}" => 'y(',
        "\x{1F59}" => 'Y(',
        "\x{1F60}" => '�)',
        "\x{1F61}" => '�(',
        "\x{1F68}" => '�)',
        "\x{1F69}" => '�(',
        "\x{1F70}" => 'a\\',
        "\x{1F71}" => 'a/',
        "\x{1F72}" => 'e\\',
        "\x{1F73}" => 'e/',
        "\x{1F74}" => '�\\',
        "\x{1F75}" => '�/',
        "\x{1F76}" => 'i\\',
        "\x{1F77}" => 'i/',
        "\x{1F78}" => 'o\\',
        "\x{1F79}" => 'o/',
        "\x{1F7A}" => 'y\\',
        "\x{1F7B}" => 'y/',
        "\x{1F7C}" => '�\\',
        "\x{1F7D}" => '�/',
        "\x{1FB0}" => 'a=',
        "\x{1FB1}" => 'a_',
        "\x{1FB3}" => 'a|',
        "\x{1FB6}" => 'a~',
        "\x{1FB8}" => 'A=',
        "\x{1FB9}" => 'A_',
        "\x{1FBA}" => 'A\\',
        "\x{1FBB}" => 'A/',
        "\x{1FBC}" => 'A|',
        "\x{1FC3}" => '�|',
        "\x{1FC6}" => '�~',
        "\x{1FC8}" => 'E\\',
        "\x{1FC9}" => 'E/',
        "\x{1FCA}" => '�\\',
        "\x{1FCB}" => '�/',
        "\x{1FCC}" => '�|',
        "\x{1FD0}" => 'i=',
        "\x{1FD1}" => 'i_',
        "\x{1FD6}" => 'i~',
        "\x{1FD8}" => 'I=',
        "\x{1FD9}" => 'I_',
        "\x{1FDA}" => 'I\\',
        "\x{1FDB}" => 'I/',
        "\x{1FE0}" => 'y=',
        "\x{1FE1}" => 'y_',
        "\x{1FE4}" => 'r)',
        "\x{1FE5}" => 'r(',
        "\x{1FE6}" => 'y~',
        "\x{1FE8}" => 'Y=',
        "\x{1FE9}" => 'Y_',
        "\x{1FEA}" => 'Y\\',
        "\x{1FEB}" => 'Y/',
        "\x{1FEC}" => 'R(',
        "\x{1FF6}" => '�~',
        "\x{1FF3}" => '�|',
        "\x{03AA}" => 'I+',
        "\x{03AB}" => 'Y+',
        "\x{03CA}" => 'i+',
        "\x{03CB}" => 'y+',
    );

    %{ $lglobal{grkbeta2} } = (
        "\x{1F02}" => 'a)\\',
        "\x{1F03}" => 'a(\\',
        "\x{1F04}" => 'a)/',
        "\x{1F05}" => 'a(/',
        "\x{1F06}" => 'a~)',
        "\x{1F07}" => 'a~(',
        "\x{1F0A}" => 'A)\\',
        "\x{1F0B}" => 'A(\\',
        "\x{1F0C}" => 'A)/',
        "\x{1F0D}" => 'A(/',
        "\x{1F0E}" => 'A~)',
        "\x{1F0F}" => 'A~(',
        "\x{1F12}" => 'e)\\',
        "\x{1F13}" => 'e(\\',
        "\x{1F14}" => 'e)/',
        "\x{1F15}" => 'e(/',
        "\x{1F1A}" => 'E)\\',
        "\x{1F1B}" => 'E(\\',
        "\x{1F1C}" => 'E)/',
        "\x{1F1D}" => 'E(/',
        "\x{1F22}" => '�)\\',
        "\x{1F23}" => '�(\\',
        "\x{1F24}" => '�)/',
        "\x{1F25}" => '�(/',
        "\x{1F26}" => '�~)',
        "\x{1F27}" => '�~(',
        "\x{1F2A}" => '�)\\',
        "\x{1F2B}" => '�(\\',
        "\x{1F2C}" => '�)/',
        "\x{1F2D}" => '�(/',
        "\x{1F2E}" => '�~)',
        "\x{1F2F}" => '�~(',
        "\x{1F32}" => 'i)\\',
        "\x{1F33}" => 'i(\\',
        "\x{1F34}" => 'i)/',
        "\x{1F35}" => 'i(/',
        "\x{1F36}" => 'i~)',
        "\x{1F37}" => 'i~(',
        "\x{1F3A}" => 'I)\\',
        "\x{1F3B}" => 'I(\\',
        "\x{1F3C}" => 'I)/',
        "\x{1F3D}" => 'I(/',
        "\x{1F3E}" => 'I~)',
        "\x{1F3F}" => 'I~(',
        "\x{1F42}" => 'o)\\',
        "\x{1F43}" => 'o(\\',
        "\x{1F44}" => 'o)/',
        "\x{1F45}" => 'o(/',
        "\x{1F4A}" => 'O)\\',
        "\x{1F4B}" => 'O(\\',
        "\x{1F4C}" => 'O)/',
        "\x{1F4D}" => 'O(/',
        "\x{1F52}" => 'y)\\',
        "\x{1F53}" => 'y(\\',
        "\x{1F54}" => 'y)/',
        "\x{1F55}" => 'y(/',
        "\x{1F56}" => 'y~)',
        "\x{1F57}" => 'y~(',
        "\x{1F5B}" => 'Y(\\',
        "\x{1F5D}" => 'Y(/',
        "\x{1F5F}" => 'Y~(',
        "\x{1F62}" => '�)\\',
        "\x{1F63}" => '�(\\',
        "\x{1F64}" => '�)/',
        "\x{1F65}" => '�(/',
        "\x{1F66}" => '�~)',
        "\x{1F67}" => '�~(',
        "\x{1F6A}" => '�)\\',
        "\x{1F6B}" => '�(\\',
        "\x{1F6C}" => '�)/',
        "\x{1F6D}" => '�(/',
        "\x{1F6E}" => '�~)',
        "\x{1F6F}" => '�~(',
        "\x{1F80}" => 'a)|',
        "\x{1F81}" => 'a(|',
        "\x{1F88}" => 'A)|',
        "\x{1F89}" => 'A(|',
        "\x{1F90}" => '�)|',
        "\x{1F91}" => '�(|',
        "\x{1F98}" => '�)|',
        "\x{1F99}" => '�(|',
        "\x{1FA0}" => '�)|',
        "\x{1FA1}" => '�(|',
        "\x{1FA8}" => '�)|',
        "\x{1FA9}" => '�(|',
        "\x{1FB2}" => 'a\|',
        "\x{1FB4}" => 'a/|',
        "\x{1FB7}" => 'a~|',
        "\x{1FC2}" => '�\|',
        "\x{1FC4}" => '�/|',
        "\x{1FC7}" => '�~|',
        "\x{1FD2}" => 'i\+',
        "\x{1FD3}" => 'i/+',
        "\x{1FD7}" => 'i~+',
        "\x{1FE2}" => 'y\+',
        "\x{1FE3}" => 'y/+',
        "\x{1FE7}" => 'y~+',
        "\x{1FF2}" => '�\|',
        "\x{1FF4}" => '�/|',
        "\x{1FF7}" => '�~|',
        "\x{0390}" => 'i/+',
        "\x{03B0}" => 'y/+',
    );

    %{ $lglobal{grkbeta3} } = (
        "\x{1F82}" => 'a)\|',
        "\x{1F83}" => 'a(\|',
        "\x{1F84}" => 'a)/|',
        "\x{1F85}" => 'a(/|',
        "\x{1F86}" => 'a~)|',
        "\x{1F87}" => 'a~(|',
        "\x{1F8A}" => 'A)\|',
        "\x{1F8B}" => 'A(\|',
        "\x{1F8C}" => 'A)/|',
        "\x{1F8D}" => 'A(/|',
        "\x{1F8E}" => 'A~)|',
        "\x{1F8F}" => 'A~(|',
        "\x{1F92}" => '�)\|',
        "\x{1F93}" => '�(\|',
        "\x{1F94}" => '�)/|',
        "\x{1F95}" => '�(/|',
        "\x{1F96}" => '�~)|',
        "\x{1F97}" => '�~(|',
        "\x{1F9A}" => '�)\|',
        "\x{1F9B}" => '�(\|',
        "\x{1F9C}" => '�)/|',
        "\x{1F9D}" => '�(/|',
        "\x{1F9E}" => '�~)|',
        "\x{1F9F}" => '�~(|',
        "\x{1FA2}" => '�)\|',
        "\x{1FA3}" => '�(\|',
        "\x{1FA4}" => '�)/|',
        "\x{1FA5}" => '�(/|',
        "\x{1FA6}" => '�~)|',
        "\x{1FA7}" => '�~(|',
        "\x{1FAA}" => '�)\|',
        "\x{1FAB}" => '�(\|',
        "\x{1FAC}" => '�)/|',
        "\x{1FAD}" => '�(/|',
        "\x{1FAE}" => '�~)|',
        "\x{1FAF}" => '�~(|',
    );

    $lglobal{checkcolor} = (OS_Win) ? 'white' : $activecolor;
    my $scroll_gif
        = 'R0lGODlhCAAQAIAAAAAAAP///yH5BAEAAAEALAAAAAAIABAAAAIUjAGmiMutopz0pPgwk7B6/3SZphQAOw==';
    $lglobal{scrollgif} = $mw->Photo(
        -data   => $scroll_gif,
        -format => 'gif',
    );
  }

sub fontinit {
    $lglobal{font} = "{$fontname} $fontsize $fontweight";
}

sub utffontinit {
    $lglobal{utffont} = "{$utffontname} $utffontsize";
}


# Routine to update the status bar when somthing has changed.
sub update_indicators {    
    my ( $last_line, $last_col ) = split( /\./, $text_window->index('end') );
    my ( $line, $column ) = split( /\./, $text_window->index('insert') );
    $lglobal{current_line_label}->configure(
        -text => "Ln: $line/" . ( $last_line - 1 ) . "  -  Col: $column" );
    my $mode             = $text_window->OverstrikeMode;
    my $overstrke_insert = ' I ';
    if ($mode) { $overstrke_insert = ' O ' }
    $lglobal{insert_overstrike_mode_label}
        ->configure( -text => " $overstrke_insert " );
    my $filename = $text_window->FileName;
    $filename = 'No File Loaded' unless ( defined($filename) );
    $lglobal{highlighlabel}->configure( -background => $highlightcolor )
        if ( $lglobal{scanno_hl} );
    $lglobal{highlighlabel}->configure( -background => 'gray' )
        unless ( $lglobal{scanno_hl} );
    $filename = os_normal($filename);
    my $edit_flag = '';
    my $ordinal   = ord( $text_window->get('insert') );
    my $hexi      = uc sprintf( "%04x", $ordinal );

    if ( $lglobal{longordlabel} ) {
        my $msg = charnames::viacode($ordinal) || '';
        my $msgln = length(" Dec $ordinal : Hex $hexi : $msg ");

        no warnings 'uninitialized';
        $lglobal{ordmaxlength} = $msgln
            if ( $msgln > $lglobal{ordmaxlength} );
        $lglobal{ordinallabel}->configure(
            -text    => " Dec $ordinal : Hex $hexi : $msg ",
            -width   => $lglobal{ordmaxlength},
            -justify => 'left'
        );

    } else {
        $lglobal{ordinallabel}->configure(
            -text  => " Dec $ordinal : Hex $hexi ",
            -width => 18
        );
    }
    if ( $text_window->numberChanges ) { $edit_flag = 'edited' }
    
# window label format: GG-version - [edited] - [file name]
    if ( $edit_flag) { $mw->configure( -title => $window_title . " - ". $edit_flag . " - " . $filename) } 
    else { $mw->configure( -title => $window_title . " - " . $filename) } 
#FIXME: need some logic behind this 
        
    $lglobal{global_filename} = $filename;
    $text_window->idletasks;
    my ( $mark, $pnum );
    my $markindex = $text_window->index('insert');
    if ( $filename ne 'No File Loaded' or defined $lglobal{prepfile} ) {
        $lglobal{page_num_label}->configure( -text => 'Img: XXX' )
            if defined $lglobal{page_num_label};
        $lglobal{page_label}->configure( -text => ("Lbl: None ") )
            if defined $lglobal{page_label};
        $mark = $text_window->markPrevious($markindex);
        while ($mark) {
            if ( $mark =~ /Pg(\S+)/ ) {
                $pnum = $1;
                unless ( defined( $lglobal{page_num_label} ) ) {
                    $lglobal{page_num_label} = $counter_frame->Label(
                        -text       => "Img: $pnum",
                        -width      => 8,
                        -background => 'gray',
                        -relief     => 'ridge',
                    )->grid( -row => 1, -column => 2, -sticky => 'nw' );
                    $lglobal{page_num_label}->bind(
                        '<1>',
                        sub {
                            $lglobal{page_num_label}
                                ->configure( -relief => 'sunken' );
                            gotopage();
                            update_indicators();
                        }
                    );
                    $lglobal{page_num_label}->bind(
                        '<3>',
                        sub {
                            $lglobal{page_num_label}
                                ->configure( -relief => 'sunken' );
                            viewpagenums();
                            update_indicators();
                        }
                    );
                    butbind( $lglobal{page_num_label} );
                    $lglobal{statushelp}->attach( $lglobal{page_num_label},
                        -balloonmsg => "Image/Page name for current page." );
                }
                unless ( defined( $lglobal{pagebutton} ) ) {
                    $lglobal{pagebutton} = $counter_frame->Label(
                        -text       => 'See Image',
                        -width      => 9,
                        -relief     => 'ridge',
                        -background => 'gray',
                    )->grid( -row => 1, -column => 3 );
                    $lglobal{pagebutton}->bind(
                        '<1>',
                        sub {
                            $lglobal{pagebutton}
                                ->configure( -relief => 'sunken' );
                            openpng();
                        }
                    );
                    $lglobal{pagebutton}
                        ->bind( '<3>', sub { setpngspath() } );
                    butbind( $lglobal{pagebutton} );
                    $lglobal{statushelp}->attach( $lglobal{pagebutton},
                        -balloonmsg =>
                            "Open Image corresponding to current page in an external viewer."
                    );
                }
                unless ( $lglobal{page_label} ) {
                    $lglobal{page_label} = $counter_frame->Label(
                        -text       => 'Lbl: None ',
                        -background => 'gray',
                        -relief     => 'ridge',
                    )->grid( -row => 1, -column => 4 );
                    butbind( $lglobal{page_label} );
                    $lglobal{page_label}->bind(
                        '<1>',
                        sub {
                            $lglobal{page_label}
                                ->configure( -relief => 'sunken' );
                            gotolabel();
                        }
                    );
                    $lglobal{page_label}->bind(
                        '<3>',
                        sub {
                            $lglobal{page_label}
                                ->configure( -relief => 'sunken' );
                            pageadjust();
                        }
                    );
                    $lglobal{statushelp}->attach( $lglobal{page_label},
                        -balloonmsg =>
                            "Page label assigned to current page." );
                }
                $lglobal{page_num_label}->configure( -text => "Img: $pnum" )
                    if defined $lglobal{page_num_label};
                my $label = $pagenumbers{"Pg$pnum"}{label};
                if ( defined $label && length $label ) {
                    $lglobal{page_label}
                        ->configure( -text => ("Lbl: $label ") );
                } else {
                    $lglobal{page_label}
                        ->configure( -text => ("Lbl: None ") );
                }
                last;
            } else {
                if ( $text_window->index('insert')
                    > ( $text_window->index($mark) + 400 ) )
                {
                    last;
                }
                $mark = $text_window->markPrevious($mark) if $mark;
                next;
            }
        }
        if ( ( scalar %proofers ) && ( defined( $lglobal{pagebutton} ) ) ) {
            unless ( defined( $lglobal{proofbutton} ) ) {
                $lglobal{proofbutton} = $counter_frame->Label(
                    -text       => 'See Proofers',
                    -width      => 11,
                    -relief     => 'ridge',
                    -background => 'gray',
                )->grid( -row => 1, -column => 5 );
                $lglobal{proofbutton}->bind(
                    '<1>',
                    sub {
                        $lglobal{proofbutton}
                            ->configure( -relief => 'sunken' );
                        showproofers();
                    }
                );
                $lglobal{proofbutton}->bind(
                    '<3>',
                    sub {
                        $lglobal{proofbutton}
                            ->configure( -relief => 'sunken' );
                        tglprfbar();
                    }
                );
                butbind( $lglobal{proofbutton} );
                $lglobal{statushelp}->attach( $lglobal{proofbutton},
                    -balloonmsg => "Proofers for the current page." );
            }
            {

                no warnings 'uninitialized';
                my ( $pg, undef ) = each %proofers;
                for my $round ( 1 .. 8 ) {
                    last unless defined $proofers{$pg}->[$round];
                    $lglobal{numrounds} = $round;
                    $lglobal{proofbar}[$round]->configure( -text =>
                            "  Round $round  $proofers{$pnum}->[$round]  " )
                        if $lglobal{proofbarvisible};
                }
            }
        }
    }
    $text_window->tagRemove( 'bkmk', '1.0', 'end' ) unless $bkmkhl;
    if ( $lglobal{geometryupdate} ) {
        saveset();
        $lglobal{geometryupdate} = 0;
    }
    # FIXME: Can this go? Maybe.
    if ( $autosave and $lglobal{autosaveinterval} ) {
        my $elapsed
            = $autosaveinterval * 60 - ( time - $lglobal{autosaveinterval} );
        printf "%d:%02d\n", int( $elapsed / 60 ), $elapsed % 60;
    }
  }

sub textbindings {

    # Set up a bunch of events and key bindings for the widget
    $text_window->tagConfigure( 'footnote', -background => 'cyan' );
    $text_window->tagConfigure( 'scannos',  -background => $highlightcolor );
    $text_window->tagConfigure( 'bkmk',     -background => 'green' );
    $text_window->tagConfigure( 'table',    -background => '#E7B696' );
    $text_window->tagRaise('sel');
    $text_window->tagConfigure( 'quotemark', -background => '#CCCCFF' );
    $text_window->tagConfigure( 'highlight', -background => 'orange' );
    $text_window->tagConfigure( 'linesel',   -background => '#8EFD94' );
    $text_window->tagConfigure(
        'pagenum',
        -background  => 'yellow',
        -relief      => 'raised',
        -borderwidth => 2
    );
    $text_window->tagBind( 'pagenum', '<ButtonRelease-1>', \&pnumadjust );
    $text_window->eventAdd( '<<hlquote>>' => '<Control-quoteright>' );
    $text_window->bind( '<<hlquote>>', sub { hilite('\'') } );
    $text_window->eventAdd( '<<hldquote>>' => '<Control-quotedbl>' );
    $text_window->bind( '<<hldquote>>', sub { hilite('"') } );
    $text_window->eventAdd( '<<hlrem>>' => '<Control-0>' );
    $text_window->bind(
        '<<hlrem>>',
        sub {
            $text_window->tagRemove( 'highlight', '1.0', 'end' );
            $text_window->tagRemove( 'quotemark', '1.0', 'end' );
        }
    );
    $text_window->bind( 'TextUnicode', '<Control-s>' => \&savefile );
    $text_window->bind( 'TextUnicode', '<Control-S>' => \&savefile );
    $text_window->bind( 'TextUnicode',
        '<Control-a>' => sub { $text_window->selectAll } );
    $text_window->bind( 'TextUnicode',
        '<Control-A>' => sub { $text_window->selectAll } );
    $text_window->eventAdd(
        '<<Copy>>' => '<Control-C>',
        '<Control-c>', '<F1>'
    );
    $text_window->bind( 'TextUnicode', '<<Copy>>' => \&copy );
    $text_window->eventAdd(
        '<<Cut>>' => '<Control-X>',
        '<Control-x>', '<F2>'
    );
    $text_window->bind( 'TextUnicode', '<<Cut>>' => sub { cut() } );

    $text_window->bind( 'TextUnicode', '<Control-V>' => sub { paste() } );
    $text_window->bind( 'TextUnicode', '<Control-v>' => sub { paste() } );
    $text_window->bind(
        'TextUnicode',
        '<F3>' => sub {
            $text_window->addGlobStart;
            $text_window->clipboardColumnPaste;
            $text_window->addGlobEnd;
        }
    );
    $text_window->bind(
        'TextUnicode',
        '<Control-quoteleft>' => sub {
            $text_window->addGlobStart;
            $text_window->clipboardColumnPaste;
            $text_window->addGlobEnd;
        }
    );

    $text_window->bind(
        'TextUnicode',
        '<Delete>' => sub {
            my @ranges      = $text_window->tagRanges('sel');
            my $range_total = @ranges;
            if ($range_total) {
                $text_window->addGlobStart;
                while (@ranges) {
                    my $end   = pop @ranges;
                    my $start = pop @ranges;
                    $text_window->delete( $start, $end );
                }
                $text_window->addGlobEnd;
                $mw->break;
            } else {
                $text_window->Delete;
            }
        }
    );
    $text_window->bind( 'TextUnicode', '<Control-l>' => sub { case ('lc'); } );
    $text_window->bind( 'TextUnicode', '<Control-u>' => sub { case ('uc'); } );
    $text_window->bind( 'TextUnicode',
        '<Control-t>' => sub { case ('tc'); $mw->break } );
    $text_window->bind(
        'TextUnicode',
        '<Control-Z>' => sub {
            $text_window->undo;
            $text_window->tagRemove( 'highlight', '1.0', 'end' );
        }
    );
    $text_window->bind(
        'TextUnicode',
        '<Control-z>' => sub {
            $text_window->undo;
            $text_window->tagRemove( 'highlight', '1.0', 'end' );
        }
    );
    $text_window->bind( 'TextUnicode',
        '<Control-Y>' => sub { $text_window->redo } );
    $text_window->bind( 'TextUnicode',
        '<Control-y>' => sub { $text_window->redo } );
    $text_window->bind( 'TextUnicode', '<Control-f>' => \&searchpopup );
    $text_window->bind( 'TextUnicode', '<Control-F>' => \&searchpopup );
    $text_window->bind( 'TextUnicode', '<Control-p>' => \&gotopage );
    $text_window->bind( 'TextUnicode', '<Control-P>' => \&gotopage );
    $text_window->bind(
        'TextUnicode',
        '<Control-w>' => sub {
            $text_window->addGlobStart;
            floodfill();
            $text_window->addGlobEnd;
        }
    );
    $text_window->bind(
        'TextUnicode',
        '<Control-W>' => sub {
            $text_window->addGlobStart;
            floodfill();
            $text_window->addGlobEnd;
        }
    );
    $text_window->bind( 'TextUnicode',
        '<Control-Shift-exclam>' => sub { setbookmark('1') } );
    $text_window->bind( 'TextUnicode',
        '<Control-Shift-at>' => sub { setbookmark('2') } );
    $text_window->bind( 'TextUnicode',
        '<Control-Shift-numbersign>' => sub { setbookmark('3') } );
    $text_window->bind( 'TextUnicode',
        '<Control-Shift-dollar>' => sub { setbookmark('4') } );
    $text_window->bind( 'TextUnicode',
        '<Control-Shift-percent>' => sub { setbookmark('5') } );
    $text_window->bind( 'TextUnicode',
        '<Control-KeyPress-1>' => sub { gotobookmark('1') } );
    $text_window->bind( 'TextUnicode',
        '<Control-KeyPress-2>' => sub { gotobookmark('2') } );
    $text_window->bind( 'TextUnicode',
        '<Control-KeyPress-3>' => sub { gotobookmark('3') } );
    $text_window->bind( 'TextUnicode',
        '<Control-KeyPress-4>' => sub { gotobookmark('4') } );
    $text_window->bind( 'TextUnicode',
        '<Control-KeyPress-5>' => sub { gotobookmark('5') } );
    $text_window->bind(
        'TextUnicode',
        '<Alt-Left>' => sub {
            $text_window->addGlobStart;
            indent('out');
            $text_window->addGlobEnd;
        }
    );
    $text_window->bind(
        'TextUnicode',
        '<Alt-Right>' => sub {
            $text_window->addGlobStart;
            indent('in');
            $text_window->addGlobEnd;
        }
    );
    $text_window->bind(
        'TextUnicode',
        '<Alt-Up>' => sub {
            $text_window->addGlobStart;
            indent('up');
            $text_window->addGlobEnd;
        }
    );
    $text_window->bind(
        'TextUnicode',
        '<Alt-Down>' => sub {
            $text_window->addGlobStart;
            indent('dn');
            $text_window->addGlobEnd;
        }
    );
    $text_window->bind( 'TextUnicode', '<F7>' => \&spellchecker );
    $text_window->bind(
        'TextUnicode',
        '<Control-Alt-d>' => sub {
            if ($DEBUG) {
                $DEBUG = 0;
                rebuildmenu();
            } else {
                $DEBUG = 1;
                rebuildmenu();
            }
            print "Debug ", $DEBUG ? "on\n" : "off\n";
        }
    );
    $text_window->bind(
        'TextUnicode',
        '<Control-Alt-s>' => sub {
            unless ( -e 'scratchpad.txt' ) {
                open my $fh, '>', 'scratchpad.txt'
                    or warn "Could not create file $!";
            }
            runner('start scratchpad.txt') if OS_Win;
        }
    );
    $text_window->bind( 'TextUnicode',
        '<Control-Alt-r>' => sub { regexref() } );
    $text_window->bind( 'TextUnicode', '<Shift-B1-Motion>', 'shiftB1_Motion' );
    $text_window->eventAdd(
        '<<FindNext>>' => '<Control-Key-G>',
        '<Control-Key-g>'
    );
    $text_window->bind( '<<ScrollDismiss>>', \&scrolldismiss );
    $text_window->bind( 'TextUnicode', '<ButtonRelease-2>',
        sub { popscroll() unless $Tk::mouseMoved } );
    $text_window->bind(
        '<<FindNext>>',
        sub {
            if ( $lglobal{search} ) {
                my $searchterm = $lglobal{searchentry}->get( '1.0', '1.end' );
                searchtext($searchterm);
            } else {
                searchpopup();
            }
        }
    );
    if (OS_Win) {
        $text_window->bind( 'TextUnicode',
            '<3>' =>
                sub { scrolldismiss(); $menubar->Popup( -popover => 'cursor' ) }
        );
    } else {
        $text_window->bind( 'TextUnicode', '<3>' => sub { scrolldismiss() } )
            ;    # Try to trap odd right click error under OSX and Linux
    }
    $text_window->bind( 'TextUnicode', '<Control-Alt-h>' => \&hilitepopup );
    $text_window->bind( 'TextUnicode',
        '<FocusIn>' => sub { $lglobal{hasfocus} = $text_window } );

    $lglobal{drag_img} = $mw->Photo(
        -format => 'gif',
        -data   => '
R0lGODlhDAAMALMAAISChNTSzPz+/AAAAOAAyukAwRIA4wAAd8oA0MEAe+MTYHcAANAGgnsAAGAA
AAAAACH5BAAAAAAALAAAAAAMAAwAAwQfMMg5BaDYXiw178AlcJ6VhYFXoSoosm7KvrR8zfXHRQA7
'
    );

    $lglobal{hist_img} = $mw->Photo(
        -format => 'gif',
        -data =>
            'R0lGODlhBwAEAIAAAAAAAP///yH5BAEAAAEALAAAAAAHAAQAAAIIhA+BGWoNWSgAOw=='
    );
    drag($text_window);
}

sub buildstatusbar {
    $lglobal{current_line_label} = $counter_frame->Label(
        -text       => 'Ln: 1 / 1  -  Col: 0',
        -width      => 26,
        -relief     => 'ridge',
        -background => 'gray',
    )->grid( -row => 1, -column => 0, -sticky => 'nw' );
    $lglobal{current_line_label}->bind(
        '<1>',
        sub {
            $lglobal{current_line_label}->configure( -relief => 'sunken' );
            gotoline();
            update_indicators();
        }
    );
    $lglobal{current_line_label}->bind(
        '<3>',
        sub {
            if   ($vislnnm) { $vislnnm = 0 }
            else            { $vislnnm = 1 }
            $text_window->showlinenum if $vislnnm;
            $text_window->hidelinenum unless $vislnnm;
            saveset();
        }
    );
    $lglobal{selectionlabel} = $counter_frame->Label(
        -text       => ' No Selection ',
        -relief     => 'ridge',
        -background => 'gray',
    )->grid( -row => 1, -column => 7, -sticky => 'nw' );
    $lglobal{selectionlabel}->bind(
        '<1>',
        sub {
            if ( $lglobal{showblocksize} ) {
                $lglobal{showblocksize} = 0;
            } else {
                $lglobal{showblocksize} = 1;
            }
        }
    );
    $lglobal{selectionlabel}->bind( '<Double-1>', sub { selection() } );
    $lglobal{selectionlabel}->bind(
        '<3>',
        sub {
            if ( $text_window->markExists('selstart') ) {
                $text_window->tagAdd( 'sel', 'selstart', 'selend' );
            }
        }
    );
    $lglobal{selectionlabel}->bind(
        '<Shift-3>',
        sub {
            $text_window->tagRemove( 'sel', '1.0', 'end' );
            if ( $text_window->markExists('selstart') ) {
                my ( $srow, $scol ) = split /\./,
                    $text_window->index('selstart');
                my ( $erow, $ecol ) = split /\./,
                    $text_window->index('selend');
                for ( $srow .. $erow ) {
                    $text_window->tagAdd( 'sel', "$_.$scol", "$_.$ecol" );
                }
            }
        }
    );

    $lglobal{highlighlabel} = $counter_frame->Label(
        -text       => 'H',
        -width      => 2,
        -relief     => 'ridge',
        -background => 'gray',
    )->grid( -row => 1, -column => 1 );

    $lglobal{highlighlabel}->bind(
        '<1>',
        sub {
            if ( $lglobal{scanno_hl} ) {
                $lglobal{scanno_hl}          = 0;
                $lglobal{highlighttempcolor} = 'gray';
            } else {
                scannosfile() unless $scannoslist;
                return        unless $scannoslist;
                $lglobal{scanno_hl}          = 1;
                $lglobal{highlighttempcolor} = $highlightcolor;
            }
            hilitetgl();
        }
    );
    $lglobal{highlighlabel}->bind( '<3>', sub { scannosfile() } );
    $lglobal{highlighlabel}->bind(
        '<Enter>',
        sub {
            $lglobal{highlighttempcolor}
                = $lglobal{highlighlabel}->cget( -background );
            $lglobal{highlighlabel}->configure( -background => $activecolor );
            $lglobal{highlighlabel}->configure( -relief     => 'raised' );
        }
    );
    $lglobal{highlighlabel}->bind(
        '<Leave>',
        sub {
            $lglobal{highlighlabel}
                ->configure( -background => $lglobal{highlighttempcolor} );
            $lglobal{highlighlabel}->configure( -relief => 'ridge' );
        }
    );
    $lglobal{highlighlabel}->bind( '<ButtonRelease-1>',
        sub { $lglobal{highlighlabel}->configure( -relief => 'raised' ) } );
    $lglobal{insert_overstrike_mode_label} = $counter_frame->Label(
        -text       => '',
        -relief     => 'ridge',
        -background => 'gray',
        -width      => 2,
    )->grid( -row => 1, -column => 6, -sticky => 'nw' );
    $lglobal{insert_overstrike_mode_label}->bind(
        '<1>',
        sub {
            $lglobal{insert_overstrike_mode_label}
                ->configure( -relief => 'sunken' );
            if ( $text_window->OverstrikeMode ) {
                $text_window->OverstrikeMode(0);
            } else {
                $text_window->OverstrikeMode(1);
            }
        }
    );
    $lglobal{ordinallabel} = $counter_frame->Label(
        -text       => '',
        -relief     => 'ridge',
        -background => 'gray',
        -anchor     => 'w',
    )->grid( -row => 1, -column => 8 );

    $lglobal{ordinallabel}->bind(
        '<1>',
        sub {
            $lglobal{ordinallabel}->configure( -relief => 'sunken' );
            $lglobal{longordlabel} = $lglobal{longordlabel} ? 0 : 1;
            update_indicators();
        }
    );
    butbind($_)
        for (
        $lglobal{insert_overstrike_mode_label},
        $lglobal{current_line_label},
        $lglobal{selectionlabel},
        $lglobal{ordinallabel}
        );
    $lglobal{statushelp} = $mw->Balloon( -initwait => 1000 );
    $lglobal{statushelp}->attach( $lglobal{current_line_label},
        -balloonmsg =>
            "Line number out of total lines\nand column number of cursor." );
    $lglobal{statushelp}->attach( $lglobal{insert_overstrike_mode_label},
        -balloonmsg => 'Typeover Mode. (Insert/Overstrike)' );
    $lglobal{statushelp}->attach( $lglobal{ordinallabel},
        -balloonmsg =>
            "Decimal & Hexadecimal ordinal of the\ncharacter to the right of the cursor."
    );
    $lglobal{statushelp}->attach( $lglobal{highlighlabel},
        -balloonmsg =>
            "Highlight words from list. Right click to select list" );
    $lglobal{statushelp}->attach( $lglobal{selectionlabel},
        -balloonmsg =>
            "Start and end points of selection -- Or, total lines.columns of selection"
    );
}

sub drag {
    my $scrolledwidget = shift;
    my $corner         = $scrolledwidget->Subwidget('corner');
    my $corner_label   = $corner->Label( -image => $lglobal{drag_img} )
        ->pack( -side => 'bottom', -anchor => 'se' );
    $corner_label->bind(
        '<Enter>',
        sub {
            if (OS_Win) {
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
            my $x
                = $scrolledwidget->toplevel->width 
                - $lglobal{x}
                + $scrolledwidget->toplevel->pointerx;
            my $y
                = $scrolledwidget->toplevel->height 
                - $lglobal{y}
                + $scrolledwidget->toplevel->pointery;
            ( $lglobal{x}, $lglobal{y} ) = (
                $scrolledwidget->toplevel->pointerx,
                $scrolledwidget->toplevel->pointery
            );
            $scrolledwidget->toplevel->geometry( $x . 'x' . $y );
        }
    );
}

sub butbind {    # Bindings to make label in status bar act like buttons
    my $widget = shift;
    $widget->bind(
        '<Enter>',
        sub {
            $widget->configure( -background => $activecolor );
            $widget->configure( -relief     => 'raised' );
        }
    );
    $widget->bind(
        '<Leave>',
        sub {
            $widget->configure( -background => 'gray' );
            $widget->configure( -relief     => 'ridge' );
        }
    );
    $widget->bind( '<ButtonRelease-1>',
        sub { $widget->configure( -relief => 'raised' ) } );
}

sub toolbar_toggle {    # Set up / remove the tool bar
    if ( $notoolbar && $lglobal{toptool} ) {
        $lglobal{toptool}->destroy;
        undef $lglobal{toptool};
    } elsif ( !$notoolbar && !$lglobal{toptool} ) {

      # if Tk::ToolBar isn't available, show a message and disable the toolbar
        if ( !$lglobal{ToolBar} ) {
            my $dbox = $mw->Dialog(
                -text =>
                    'Tk::ToolBar package not found, unable to create Toolbar. The toolbar will be disabled.',
                -title   => 'Unable to create Toolbar.',
                -buttons => ['OK']
            );
            $dbox->Show;

            # disable toolbar in settings
            $notoolbar = 1;
            saveset();
            return;
        }
        $lglobal{toptool}
            = $mw->ToolBar( -side => $toolside, -close => '30' );
        $lglobal{toolfont} = $mw->Font(
            -family => 'Times',
            -slant  => 'italic',
            -weight => 'bold',
            -size   => 9
        );
        $lglobal{toptool}->separator;
        $lglobal{toptool}->ToolButton(
            -image   => 'fileopen16',
            -command => [ \&fileopen ],
            -tip     => 'Open'
        );
        $lglobal{savetool} = $lglobal{toptool}->ToolButton(
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
                clearvars();
                update_indicators();
            },
            -tip => 'Discard Edits'
        );
        $lglobal{toptool}->separator;
        $lglobal{toptool}->ToolButton(
            -image   => 'actundo16',
            -command => sub { $text_window->undo },
            -tip     => 'Undo'
        );
        $lglobal{toptool}->ToolButton(
            -image   => 'actredo16',
            -command => sub { $text_window->redo },
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
            -command => [ \&wordcount ],
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
            -command => [ \&markpopup ],
            -tip     => 'HTML Fixup Popup'
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
            -tip     => 'Remove trailing spaces in selection'
        );
    }
    saveset();
}

sub os_normal {
    $_[0] =~ s|/|\\|g if OS_Win;
    return $_[0];
}

# Writes setting.rc file
sub saveset {
    my ( $index, $savethis );
    my $thispath = $0;
    $thispath =~ s/[^\\]*$//;
    my $savefile = $thispath . 'setting.rc';
    $geometry = $mw->geometry unless $geometry;
    if ( open my $save_handle, '>', $savefile ) {
        print $save_handle
            "# This file contains your saved settings for guiguts.
# It is automatically generated when you save your settings.
# If you delete it, all the settings will revert to defaults.
# You shouldn't ever have to edit this file manually.\n\n"
            ;

        print $save_handle '@gcopt = (';
        print $save_handle "$_," || '0,' for @gcopt;
        print $save_handle ");\n\n";

        for (
            qw/activecolor auto_page_marks autobackup autosave autosaveinterval blocklmargin blockrmargin
            defaultindent fontname fontsize fontweight geometry geometry2 geometry3 globalaspellmode
            highlightcolor history_size jeebiesmode lmargin nobell nohighlights notoolbar rmargin
            rwhyphenspace singleterm stayontop toolside utffontname utffontsize vislnnm italic_char bold_char/
            )
        {
            print $save_handle "\$$_", ' ' x ( 20 - length $_ ), "= '",
                eval '$' . $_, "';\n";
        }
        print $save_handle "\n";

        for (
            qw/globallastpath globalspellpath globalspelldictopt globalviewerpath globalbrowserstart
            gutpath jeebiespath scannospath tidycommand/
            )
        {
            print $save_handle "\$$_", ' ' x ( 20 - length $_ ), "= '",
                escape_problems( os_normal( eval '$' . $_ ) ), "';\n";
        }

        print $save_handle ("\n\@recentfile = (\n");
        for (@recentfile) {
            print $save_handle "\t'", escape_problems($_), "',\n";
        }
        print $save_handle (");\n\n");

        print $save_handle ("\@extops = (\n");
        for $index ( 0 .. $#extops ) {
            my $label   = escape_problems( $extops[$index]{label} );
            my $command = escape_problems( $extops[$index]{command} );
            print $save_handle
                "\t{'label' => '$label', 'command' => '$command'},\n";
        }
        print $save_handle ");\n\n";

        print $save_handle '@mygcview = (';
        for (@mygcview) { print $save_handle "$_," }
        print $save_handle (");\n\n");

        print $save_handle ("\@search_history = (\n");
        my @array = @search_history;
        for $index (@array) {
            $index =~ s/([^A-Za-z0-9 ])/'\x{'.(sprintf "%x", ord $1).'}'/eg;
            print $save_handle qq/\t"$index",\n/;
        }
        print $save_handle ");\n\n";

        print $save_handle ("\@replace_history = (\n");

        @array = @replace_history;
        for $index (@array) {
            $index =~ s/([^A-Za-z0-9 ])/'\x{'.(sprintf "%x", ord $1).'}'/eg;
            print $save_handle qq/\t"$index",\n/;
        }
        print $save_handle ");\n\n1;\n";
    }
}

sub escape_problems {
    $_[0] =~ s/\\+$/\\\\/g;
    $_[0] =~ s/(?!<\\)'/\\'/g;
    return $_[0];
}

sub updatesel {    # Update Last Selection readout in status bar
    my @ranges = $text_window->tagRanges('sel');
    my $msg;
    if (@ranges) {
        if ( $lglobal{showblocksize} && ( @ranges > 2 ) ) {
            my ( $srow, $scol ) = split /\./, $ranges[0];
            my ( $erow, $ecol ) = split /\./, $ranges[-1];
            $msg
            = ' R:'
            . abs( $erow - $srow + 1 ) . ' C:'
            . abs( $ecol - $scol ) . ' ';
        } else {
            $msg = " $ranges[0]--$ranges[-1] ";
            if ( $lglobal{selectionpop} ) {
                $lglobal{selsentry}->delete( '0', 'end' );
                $lglobal{selsentry}->insert( 'end', $ranges[0] );
                $lglobal{seleentry}->delete( '0', 'end' );
                $lglobal{seleentry}->insert( 'end', $ranges[-1] );
            }
        }
    } else {
        $msg = ' No Selection ';
    }
    my $msgln = length($msg);

    no warnings 'uninitialized';
    $lglobal{selmaxlength} = $msgln if ( $msgln > $lglobal{selmaxlength} );
    $lglobal{selectionlabel}
    ->configure( -text => $msg, -width => $lglobal{selmaxlength} );
    update_indicators();
    $text_window->_lineupdate;
}

# Menus
sub menubar_menuitems {
    [   map [ 'cascade', $_->[0],
            -menuitems => $_->[1],
            -tearoff   => $_->[2] ],
        [ 'File',            file_menuitems(),      0 ],
        [ 'Edit',            edit_menuitems(),      0 ],
        [ 'Search',          search_menuitems(),    1 ],
        [ 'Bookmarks',       bookmark_menuitems(),  0 ],
        [ 'Selection',       selection_menuitems(), 1 ],
        [ 'Fixup',           fixup_menuitems(),     1 ],
        [ 'Text Processing', text_menuitems(),      1 ],
        [ 'External',        external_menuitems(),  0 ],
        [ 'Unicode',         unicode_menuitems(),   0 ],
        [ 'Prefs',           prefs_menuitems(),     0 ],
        [ 'Help',            help_menuitems(),      0 ],
    ];
}

sub file_menuitems {
    [   [   'command', 'Open',
            -command     => \&file_open,
            -underline   => 0,
            -accelerator => 'Ctrl+o'
        ],
        '',
        [   'command', 'Save',
            -command     => \&file_save,
            -underline   => 0,
            -accelerator => 'Ctrl+s'
        ],
        [ 'command', 'Save As', -command => \&file_saveas, -underline => 5, ],
        [   'command', 'Include',
            -command   => \&file_include,
            -underline => 0,
        ],
        [ 'command', 'Close', -command => \&file_close, -underline => 0, ],
        '',
        [ 'command', 'Import Prep Text Files', -command => \&prep_import, ],
        [   'command', 'Export As Prep Text Files', -command => \&prep_export,
        ],
        '',
        [   'command', 'Guess Page Markers',
            -command   => \&guess_pagemarks,
            -underline => 0,
        ],
        [   'command', 'Set Page Markers',
            -command   => \&set_pagemarks,
            -underline => 9,
        ],
        '',
        [   'command', 'Exit',
            -command     => \&gg_exit,
            -underline   => 1,
            -accelerator => 'Ctrl+q'
        ],
    ];
}



sub file_save {
    my ($name);
    $text_window->SaveUTF($name);
}

sub file_saveas     { }
sub file_include    { }
sub file_close      { }
sub prep_import     { }
sub prep_export     { }
sub guess_pagemarks { }
sub set_pagemarks   { }
sub gg_exit         { exit; }

sub edit_menuitems {
    [   [ 'command', 'Undo', -command => \&gg_undo, ],
        [ 'command', 'Redo', -command => \&gg_redo, ],
        '',
        [ 'command', 'Cut', ],
        [ 'command', 'Copy', ],
        [ 'command', 'Paste', ],
        [ 'command', 'Column Paste', ],
        '',
        [ 'command', 'Select All', ],
        [ 'command', 'Unselect All', ],
    ];
}
sub gg_undo { $text_window->undo; }
sub gg_redo { $text_window->redo; }

sub search_menuitems {
    [   [ 'command', 'Search & Replace', ],
        [ 'command', 'Stealth Scannos', ],
        [ 'command', 'Spell Check', ],
        [ 'command', 'Goto Line', ],
        [ 'command', 'Goto Page' ],
        [ 'command', 'Which Line?', ],
        '',
        [ 'command', 'Find Proofer Comments', ],
        [ 'command', 'Find next /*..*/ block', ],
        [ 'command', 'Find previous /*..*/ block', ],
        [ 'command', 'Find next /#..#/ block', ],
        [ 'command', 'Find previous /#..#/ block', ],
        [ 'command', 'Find next /$..$/ block', ],
        [ 'command', 'Find previous /$..$/ block', ],
        [ 'command', 'Find next /p..p/ block', ],
        [ 'command', 'Find previous /p..p/ block', ],
        [ 'command', 'Find next indented block', ],
        [ 'command', 'Find previous indented block', ],
        '',
        [ 'command', 'Find Orphaned Brackets & Markup', ],
        '',
        [ 'command', 'Highlight double quotes in selection', ],
        [ 'command', 'Highlight single quotes in selection', ],
        [ 'command', 'Highlight arbitrary characters in selection', ],
        [ 'command', 'Remove Highlights', ],
    ];
}

sub bookmark_menuitems {
    [   [ 'command', 'Set Bookmark 1', ],
        [ 'command', 'Set Bookmark 2', ],
        [ 'command', 'Set Bookmark 3', ],
        [ 'command', 'Set Bookmark 4', ],
        [ 'command', 'Set Bookmark 5', ],
        '',
        [ 'command', 'Goto Bookmark 1', ],
        [ 'command', 'Goto Bookmark 2', ],
        [ 'command', 'Goto Bookmark 3', ],
        [ 'command', 'Goto Bookmark 4', ],
        [ 'command', 'Goto Bookmark 5', ],
    ];
}

sub selection_menuitems {
    [   [ 'command', 'lowercase Selection' ],
        [ 'command', 'Sentence case selection' ],
        [ 'command', 'Title Case Selection' ],
        [ 'command', 'UPPERCASE Selection' ],
        '',
        [ 'command', 'Surround Selectin With...' ],
        [ 'command', 'Flood Fill Selection With...' ],
        '',
        [ 'command', 'Indent Selection 1' ],
        [ 'command', 'Indent Selection -1' ],
        '',
        [ 'command', 'Rewrap Selection' ],
        [ 'command', 'Block Rewrap Selection' ],
        [ 'command', 'Interrupt Rewrap' ],
        '',
        [ 'command', 'ASCII Boxes' ],
        [ 'command', 'Align text on string' ],
        '',
        [ 'command', 'Convert to Named/Numeric Entities' ],
        [ 'command', 'Convert From Named/Numeric Entities' ],
        [ 'command', 'Convert Fractions' ],
    ];
}

sub fixup_menuitems {
    [   [ 'command', 'Run Word Frequency' ],
        [ 'command', 'Run ~Gutcheck' ],
        [ 'command', 'Gutcheck options' ],
        [ 'command', 'Run Jeebies' ],
        '',
        [ 'command', 'Remove End-of-line Spaces' ],
        [ 'command', 'Run Fixup' ],
        '',
        [ 'command', 'Fix Page Separators' ],
        [ 'command', 'Remove Blank Lines Before Page Separators' ],
        '',
        [ 'command', 'Footnote Fixup', ],
        [ 'command', 'HTML Fixup', ],
        [ 'command', 'Sidenote Fixup', ],
        [ 'command', 'Reformat Poetry Line Numbers', ],
        [ 'command', 'Convert Win CP 1252 Chars to Unicode', ],
        '',
        [ 'command', 'ASCII Table Special Effects', ],
        '',
        [ 'command', 'Clean Up Rewrap Markers', ],
        '',
        [ 'command', 'Find Greek', ],

        # FIXME: Doesn't work yet[ 'command', 'Convert Greek', ],
    ];
}

sub text_menuitems {
    [   [ 'command', 'Convert Italics' ],
        [ 'command', 'Convert Bold' ],
        [ 'command', 'Add Thought Break' ],
        [ 'command', 'Convert <tb>' ],
        [ 'command', 'Convert <sc>' ],
        [ 'command', 'Options' ],
    ];
}

sub external_menuitems {
    [ [ 'command', '' ], [ 'command', '' ], ];
}

sub unicode_menuitems {
    [ [ 'command', '' ], [ 'command', '' ], ];
}

sub prefs_menuitems {
    [   [ 'command',     'Set Rewrap Margins' ],
        [ 'command',     'Font' ],
        [ 'command',     'Browser Start Command' ],
        [ 'checkbutton', 'Leave Bookmarks Highlighted' ],
        [ 'checkbutton', 'Enable Quotes Highlighting' ],
        [ 'checkbutton', 'Keep Pop-ups On Top' ],
        [ 'checkbutton', 'Enable Bell' ],
        [ 'checkbutton', 'Auto Set Page Markers' ],
        [   'checkbutton',
            'Leave Space Afer End-of-Line Hyphens During Rewrap'
        ],
        [   'command',
            'Toggle Line Numbers',
            -command => \&toggle_line_numbers,
        ],
    ];
}
sub toggle_line_numbers { $text_window->togglelinenum; }

sub help_menuitems {
    [   [ 'command', 'Hot Keys' ],
        [ 'command', 'Function History' ],
        [ 'command', 'Greek Transliteration' ],
        [ 'command', 'Latin1 Chart' ],
        [ 'command', 'Regex Quick Reference' ],
        [ 'command', 'UTF Character Entry' ],
        [ 'command', 'UTF Character Search' ],
    ];
}

# "File Open Routines

if ( @ARGV == 1 ) { $text_window->Load( shift @ARGV ); }

sub confirmdiscard {
    if ( $text_window->numberChanges ) {
        my $ans = $mw->messageBox(
            -icon    => 'warning',
            -type    => 'YesNoCancel',
            -default => 'yes',
            -message =>
                'The text has been modified without being saved. Save edits?'
        );
        if ( $ans =~ /yes/i ) {
            savefile();
        } else {
            return $ans;
        }
    }
    return 'no';
}

sub confirmempty {
    my $answer = confirmdiscard();
    if ( $answer =~ /no/i ) {
        if ( $lglobal{page_num_label} ) {
            $lglobal{page_num_label}->destroy;
            undef $lglobal{page_num_label};
        }
        if ( $lglobal{pagebutton} ) {
            $lglobal{pagebutton}->destroy;
            undef $lglobal{pagebutton};
        }
        if ( $lglobal{proofbutton} ) {
            $lglobal{proofbutton}->destroy;
            undef $lglobal{proofbutton};
        }
        $text_window->EmptyDocument;
    }
    return $answer;
}

sub file_open {
    my ($name);

    return if ( confirmempty() =~ /cancel/i );
    my $types = [
        [ 'Text Files', [qw/.txt .text .ggp .htm .html .bk1 .bk2/] ],
        [ 'All Files',  ['*'] ],
    ];
    $name = $text_window->getOpenFile(
        -filetypes  => $types,
        -title      => 'Open File',
        -initialdir => $globallastpath,
    );
    if ( defined($name) and length($name) ) {
        open_file($name);
    }
}

sub open_file {
    my $name = shift;
    $text_window->Load($name);
}

MainLoop;