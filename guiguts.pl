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
use ToolBar;

use constant OS_Win => $^O =~ /Win/;

# ignore any watchdog timer alarms. Subroutines that take a long time to
# complete can trip it
$SIG{ALRM} = 'IGNORE';
$SIG{INT} = sub { myexit() };

my $DEBUG      = 0;          # FIXME: this can go.
my $VERSION    = "0.2.8";
my $currentver = $VERSION;
my $no_proofer_url = 'http://www.pgdp.net/phpBB2/privmsg.php?mode=post';
my $yes_proofer_url
    = 'http://www.pgdp.net/c/stats/members/mbr_list.php?uname=';

our $activecolor      = '#f2f818';
our $auto_page_marks  = 1;
our $autobackup       = 0;
our $autosave         = 0;
our $autosaveinterval = 5;
our $bkmkhl           = '0';
our $blocklmargin     = 5;
our $blockrmargin     = 72;
our $blockwrap;
our $bold_char     = "=";
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
our $italic_char        = "_";
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
our $tidycommand  = '';
our $toolside     = 'bottom';
our $utffontname  = 'Courier New';
our $utffontsize  = 14;
our $vislnnm      = 0;
our $window_title = "Guiguts-" . $currentver;

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

# FIXME: Build a popup message about these.
if ( eval { require Text::LevenshteinXS } ) {
    $lglobal{LevenshteinXS} = 1;
}
else {
    print
        "Install the module Text::LevenshteinXS for much faster harmonics sorting.\n";
}

# load Image::Size if it is installed
if ( eval { require Image::Size; 1; } ) {
    $lglobal{ImageSize} = 1;
}
else {
    $lglobal{ImageSize} = 0;
}

my $top = tkinit( -title => $window_title, );

initialize();    # Initialize a bunch of vars that need it.

$top->minsize( 440, 90 );

# Detect geometry changes for tracking
$top->bind(
    '<Configure>' => sub {
        $geometry = $top->geometry;
        $lglobal{geometryupdate} = 1;
    }
);

my $icon = $top->Photo(
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

fontinit();    # Initialize the fonts for the two windows

utffontinit();

$top->geometry($geometry) if $geometry;

# Set up Main window layout
my $text_frame = $top->Frame->pack(
    -anchor => 'nw',
    -expand => 'yes',
    -fill   => 'both'
);

my $counter_frame = $text_frame->Frame->pack(
    -side   => 'bottom',
    -anchor => 'sw',
    -pady   => 2,
    -expand => 0
);

# Frame to hold proofer names. Pack it when necessary.
my $proofer_frame = $text_frame->Frame;

# The actual text widget
my $textwindow = $text_frame->LineNumberText(
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

# Enable Drag & Drop. You can drag a text file into the open window and it
# will auto load. Kind of gimicky, but fun to play with.
$top->DropSite(
    -dropcommand => \&handleDND,
    -droptypes =>
        ( OS_Win or ( $^O eq 'cygwin' and $Tk::platform eq 'MSWin32' ) )
    ? ['Win32']
    : [qw/XDND Sun/]
);

$top->protocol( 'WM_DELETE_WINDOW' => \&myexit );

my $menu = $top->Menu( -type => 'menubar' );

$top->configure( -menu => $menu );

# routines to call every time the text is edited
$textwindow->SetGUICallbacks(
    [   \&update_indicators,
        sub {
            return if $nohighlights;
            $textwindow->HighlightAllPairsBracketingCursor;
        },
        sub {
            $textwindow->hidelinenum unless $vislnnm;
            }
    ]
);

# Set up the custom menus
buildmenu();

# Set up the key bindings for the text widget
textbindings();

buildstatusbar();

# Load the icon into the window bar. Needs to happen late in the process
$top->Icon( -image => $icon );

$textwindow->focus;

$lglobal{hasfocus} = $textwindow;

toolbar_toggle();

$top->geometry($geometry) if $geometry;

( $lglobal{global_filename} ) = @ARGV;
die "ERROR: too many files specified. \n" if ( @ARGV > 1 );

if (@ARGV) {
    $lglobal{global_filename} = shift @ARGV;
    if ( -e $lglobal{global_filename} ) {
        $top->update
            ;    # it may be a big file, draw the window, and then load it
        openfile( $lglobal{global_filename} );
    }
}
else {
    $lglobal{global_filename} = 'No File Loaded';
}

set_autosave() if $autosave;

$textwindow->CallNextGUICallback;

$top->repeat( 200, \&updatesel );

## Global Exit
sub myexit {
    if ( confirmdiscard() =~ /no/i ) {
        aspellstop() if $lglobal{spellpid};
        exit;
    }
}

## Update Last Selection readout in status bar
sub updatesel {
    my @ranges = $textwindow->tagRanges('sel');
    my $msg;
    if (@ranges) {
        if ( $lglobal{showblocksize} && ( @ranges > 2 ) ) {
            my ( $srow, $scol ) = split /\./, $ranges[0];
            my ( $erow, $ecol ) = split /\./, $ranges[-1];
            $msg
                = ' R:'
                . abs( $erow - $srow + 1 ) . ' C:'
                . abs( $ecol - $scol ) . ' ';
        }
        else {
            $msg = " $ranges[0]--$ranges[-1] ";
            if ( $lglobal{selectionpop} ) {
                $lglobal{selsentry}->delete( '0', 'end' );
                $lglobal{selsentry}->insert( 'end', $ranges[0] );
                $lglobal{seleentry}->delete( '0', 'end' );
                $lglobal{seleentry}->insert( 'end', $ranges[-1] );
            }
        }
    }
    else {
        $msg = ' No Selection ';
    }
    my $msgln = length($msg);

    no warnings 'uninitialized';
    $lglobal{selmaxlength} = $msgln if ( $msgln > $lglobal{selmaxlength} );
    $lglobal{selectionlabel}
        ->configure( -text => $msg, -width => $lglobal{selmaxlength} );
    update_indicators();
    $textwindow->_lineupdate;
}

sub flash_save {
    $lglobal{saveflashingid} = $top->repeat(
        500,
        sub {
            if ( $lglobal{savetool}->cget('-background') eq 'yellow' ) {
                $lglobal{savetool}->configure(
                    -background       => 'green',
                    -activebackground => 'green'
                ) unless $notoolbar;
            }
            else {
                $lglobal{savetool}->configure(
                    -background       => 'yellow',
                    -activebackground => 'yellow'
                ) if $textwindow->numberChanges and !$notoolbar;
            }
        }
    );
}

## save the .bin file associated with the text file
sub binsave {
    push @operations, ( localtime() . ' - File Saved' );
    oppopupdate() if $lglobal{oppop};
    my $mark = '1.0';
    while ( $textwindow->markPrevious($mark) ) {
        $mark = $textwindow->markPrevious($mark);
    }
    my $markindex;
    while ($mark) {
        if ( $mark =~ /Pg(\S+)/ ) {
            $markindex                  = $textwindow->index($mark);
            $pagenumbers{$mark}{offset} = $markindex;
            $mark                       = $textwindow->markNext($mark);
        }
        else {
            $mark = $textwindow->markNext($mark) if $mark;
            next;
        }
    }
    return if ( $lglobal{global_filename} =~ /No File Loaded/ );
    my $binname = "$lglobal{global_filename}.bin";
    if ( $textwindow->markExists('spellbkmk') ) {
        $spellindexbkmrk = $textwindow->index('spellbkmk');
    }
    else {
        $spellindexbkmrk = '';
    }
    my $bak = "$binname.bak";
    if ( -e $bak ) {
        my $perms = ( stat($bak) )[2] & 07777;
        unless ( $perms & 0300 ) {
            $perms = $perms | 0300;
            chmod $perms, $bak or warn "Can not back up .bin file: $!\n";
        }
        unlink $bak;
    }
    if ( -e $binname ) {
        my $perms = ( stat($binname) )[2] & 07777;
        unless ( $perms & 0300 ) {
            $perms = $perms | 0300;
            chmod $perms, $binname
                or warn "Can not save .bin file: $!\n" and return;
        }
        rename $binname, $bak or warn "Can not back up .bin file: $!\n";
    }
    if ( open my $bin, '>', $binname ) {
        print $bin "\%pagenumbers = (\n";
        for my $page ( sort { $a cmp $b } keys %pagenumbers ) {

            no warnings 'uninitialized';
            print $bin " '$page' => {";
            print $bin "'offset' => '$pagenumbers{$page}{offset}', ";
            print $bin "'label' => '$pagenumbers{$page}{label}', ";
            print $bin "'style' => '$pagenumbers{$page}{style}', ";
            print $bin "'action' => '$pagenumbers{$page}{action}', ";
            print $bin "'base' => '$pagenumbers{$page}{base}'},\n";
        }
        print $bin ");\n\n";

        print $bin '$bookmarks[0] = \''
            . $textwindow->index('insert') . "';\n";
        for ( 1 .. 5 ) {
            print $bin '$bookmarks[' 
                . $_ 
                . '] = \''
                . $textwindow->index( 'bkmk' . $_ ) . "';\n"
                if $bookmarks[$_];
        }
        if ($pngspath) {
            print $bin
                "\n\$pngspath = '@{[escape_problems($pngspath)]}';\n\n";
        }
        my ( $page, $prfr );
        delete $proofers{''};
        foreach $page ( sort keys %proofers ) {

            no warnings 'uninitialized';
            for my $round ( 1 .. $lglobal{numrounds} ) {
                if ( defined $proofers{$page}->[$round] ) {
                    print $bin '$proofers{\'' 
                        . $page . '\'}[' 
                        . $round
                        . '] = \''
                        . $proofers{$page}->[$round] . '\';' . "\n";
                }
            }
        }
        print $bin "\n\n";
        print $bin "\@operations = (\n";
        for $mark (@operations) {
            $mark = escape_problems($mark);
            print $bin "'$mark',\n";
        }
        print $bin ");\n\n";
        print $bin "\$spellindexbkmrk = '$spellindexbkmrk';\n\n";
        print $bin
            "\$scannoslistpath = '@{[escape_problems(os_normal($scannoslistpath))]}';\n\n";
        print $bin '1;';
        close $bin;
    }
    else {
        $top->BackTrace("Cannot open $binname:$!");
    }
}

## Track recently open files for the menu
sub recentupdate {
    my $name = shift;

    # remove $name or any *empty* values from the list
    @recentfile = grep( !/(?: \Q$name\E | \Q*empty*\E )/x, @recentfile );

    # place $name at the top
    unshift @recentfile, $name;

    # limit the list to 10 entries
    pop @recentfile while ( $#recentfile > 10 );
    rebuildmenu();
}

## Bindings to make label in status bar act like buttons
sub butbind {
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

# Pop up window allowing tracking and auto reselection of last selection
sub selection {
    my ( $start, $end );
    if ( $lglobal{selectionpop} ) {
        $lglobal{selectionpop}->deiconify;
        $lglobal{selectionpop}->raise;
    }
    else {
        $lglobal{selectionpop} = $top->Toplevel;
        $lglobal{selectionpop}->title('Select Line.Col');
        $lglobal{selectionpop}->resizable( 'no', 'no' );
        my $frame = $lglobal{selectionpop}
            ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        $frame->Label( -text => 'Start Line.Col' )
            ->grid( -row => 1, -column => 1 );
        $lglobal{selsentry} = $frame->Entry(
            -background   => 'white',
            -width        => 15,
            -textvariable => \$start,
            -validate     => 'focusout',
            -vcmd         => sub {
                return 0 unless ( $_[0] =~ /^\d+\.\d+$/ );
                return 1;
            },
        )->grid( -row => 1, -column => 2 );
        $frame->Label( -text => 'End Line.Col' )
            ->grid( -row => 2, -column => 1 );
        $lglobal{seleentry} = $frame->Entry(
            -background   => 'white',
            -width        => 15,
            -textvariable => \$end,
            -validate     => 'focusout',
            -vcmd         => sub {
                return 0 unless ( $_[0] =~ /^\d+\.\d+$/ );
                return 1;
            },
        )->grid( -row => 2, -column => 2 );
        my $frame1 = $lglobal{selectionpop}
            ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        my $button = $frame1->Button(
            -text    => 'OK',
            -width   => 8,
            -command => sub {
                return
                    unless ( ( $start =~ /^\d+\.\d+$/ )
                    && ( $end =~ /^\d+\.\d+$/ ) );
                $textwindow->tagRemove( 'sel', '1.0', 'end' );
                $textwindow->tagAdd( 'sel', $start, $end );
                $textwindow->markSet( 'selstart', $start );
                $textwindow->markSet( 'selend',   $end );
                $textwindow->focus;
            },
        )->grid( -row => 1, -column => 1 );
        $frame1->Button(
            -text    => 'Close',
            -width   => 8,
            -command => sub {
                $lglobal{selectionpop}->destroy;
                undef $lglobal{selectionpop};
                undef $lglobal{selsentry};
                undef $lglobal{seleentry};
            },
        )->grid( -row => 1, -column => 2 );
        $lglobal{selectionpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{selectionpop}->destroy;
                undef $lglobal{selectionpop};
                undef $lglobal{selsentry};
                undef $lglobal{seleentry};
            }
        );
        $lglobal{selectionpop}->Icon( -image => $icon );
    }
    my @ranges = $textwindow->tagRanges('sel');
    if (@ranges) {
        $lglobal{selsentry}->delete( '0', 'end' );
        $lglobal{selsentry}->insert( 'end', $ranges[0] );
        $lglobal{seleentry}->delete( '0', 'end' );
        $lglobal{seleentry}->insert( 'end', $ranges[-1] );
    }
    elsif ( $textwindow->markExists('selstart') ) {
        $lglobal{selsentry}->delete( '0', 'end' );
        $lglobal{selsentry}->insert( 'end', $textwindow->index('selstart') );
        $lglobal{seleentry}->delete( '0', 'end' );
        $lglobal{seleentry}->insert( 'end', $textwindow->index('selend') );
    }
    $lglobal{selsentry}->selectionRange( 0, 'end' );
}

# Command parsing for External command routine
sub cmdinterp {
    my $command = shift;
    my ( $fname, $pagenum, $number, $pname );
    if ( $command =~ m/\$f|\$d|\$e/ ) {
        return ' ' if ( $lglobal{global_filename} =~ m/No File Loaded/ );
        $fname = $lglobal{global_filename};
        $fname = dos_path( $lglobal{global_filename} ) if OS_Win;
        my ( $f, $d, $e ) = fileparse( $fname, qr{\.[^\.]*$} );
        $command =~ s/\$f/$f/ if $f;
        $command =~ s/\$d/$d/ if $d;
        $command =~ s/\$e/$e/ if $e;
    }
    if ( $command =~ m/\$p/ ) {
        return unless $lglobal{page_num_label};
        $number = $lglobal{page_num_label}->cget( -text );
        $number =~ s/.+?(\d+).*/$1/;
        $pagenum = $number;
        return ' ' unless $pagenum;
        $command =~ s/\$p/$number/;
    }
    if ( $command =~ m/\$i/ ) {
        return ' ' unless $pngspath;
        $pname = $pngspath;
        $pname = dos_path($pngspath) if OS_Win;
        $command =~ s/\$i/$pngspath/;
    }
    return $command;
}

## Routine to spawn another perl process and use it to execute an
# external program
# FIXME: Can we get rid of spawn.pl
sub runner {
    my $args;
    $args = join ' ', @_;
    unless ( -e 'spawn.pl' ) {
        open my $spawn, '>', 'spawn.pl';
        print $spawn 'exec @ARGV;';
    }
    if (OS_Win) {
        $args = '"' . $args . '"';
    }
    else {
        $args .= ' &';
    }
    system "perl spawn.pl $args";
}

# Menus are not easily modifiable in place. Easier to just destroy and
## rebuild every time it is modified
sub rebuildmenu {
    for ( 0 .. 10 ) {
        $menu->delete('last');
    }
    buildmenu();
}

## Clear persistant variables before loading another file
sub clearvars {
    my @marks = $textwindow->markNames;
    for (@marks) {
        unless ( $_ =~ /insert|current/ ) {
            $textwindow->markUnset($_);
        }
    }
    %reghints = ();
    %{ $lglobal{seenm} } = ();
    $lglobal{seen}        = ();
    $lglobal{fnarray}     = ();
    %proofers             = ();
    %pagenumbers          = ();
    @operations           = ();
    @bookmarks            = ();
    $pngspath             = '';
    $lglobal{seepagenums} = 0;
    @{ $lglobal{fnarray} } = ();
    undef $lglobal{prepfile};
}

## Make toolbar visible if invisible and vice versa
sub tglprfbar {
    if ( $lglobal{proofbarvisible} ) {
        for ( @{ $lglobal{proofbar} } ) {
            $_->gridForget if defined $_;
        }
        $proofer_frame->packForget;
        my @geom = split /[x+]/, $top->geometry;
        $geom[1] -= $counter_frame->height;
        $top->geometry("$geom[0]x$geom[1]+$geom[2]+$geom[3]");
        $lglobal{proofbarvisible} = 0;
    }
    else {
        my $pnum = $lglobal{page_num_label}->cget( -text );
        $pnum =~ s/\D+//g;
        $proofer_frame->pack(
            -before => $counter_frame,
            -side   => 'bottom',
            -anchor => 'sw',
            -expand => 0
        );
        my @geom = split /[x+]/, $top->geometry;
        $geom[1] += $counter_frame->height;
        $top->geometry("$geom[0]x$geom[1]+$geom[2]+$geom[3]");
        {

            no warnings 'uninitialized';
            my ( $pg, undef ) = each %proofers;
            for my $round ( 1 .. 8 ) {
                last unless defined $proofers{$pg}->[$round];
                $lglobal{numrounds} = $round;
                $lglobal{proofbar}[$round] = $proofer_frame->Label(
                    -text       => '',
                    -relief     => 'ridge',
                    -background => 'gray',
                )->grid( -row => 1, -column => $round, -sticky => 'nw' );
                butbind( $lglobal{proofbar}[$round] );
                $lglobal{proofbar}[$round]->bind(
                    '<1>' => sub {
                        $lglobal{proofbar}[$round]
                            ->configure( -relief => 'sunken' );
                        my $proofer
                            = $lglobal{proofbar}[$round]->cget( -text );
                        $proofer =~ s/\s+Round \d\s+|\s+$//g;
                        $proofer =~ s/\s/%20/g;
                        prfrmessage($proofer);
                    }
                );
            }
        }
        $lglobal{proofbarvisible} = 1;
    }
}

# Routine to handle image viewer file requests
sub openpng {
    my ( $pagenum, $number );
    $number = $lglobal{page_num_label}->cget( -text )
        if defined $lglobal{page_num_label};
    $number =~ s/.+? (\S+)/$1/ if defined $lglobal{page_num_label};
    $pagenum = $number || '001';
    viewerpath() unless $globalviewerpath;
    my $dosfile;
    unless ($pngspath) {
        if (OS_Win) {
            $pngspath = "${globallastpath}pngs\\";
        }
        else {
            $pngspath = "${globallastpath}pngs/";
        }
        setpngspath() unless ( -e "$pngspath$pagenum.png" );
    }
    if ($pngspath) {
        if ($globalviewerpath) {
            my $dospath;
            $dospath = $globalviewerpath;
            $dosfile = "$pngspath$pagenum.png";
            unless ( -e $dosfile ) {
                $dosfile = "$pngspath$pagenum.jpg";
                unless ( -e $dosfile ) {
                    my $response = $top->messageBox(
                        -icon => 'error',
                        -message =>
                            "File $pngspath$pagenum.(png|jpg) not found.\nDo you need to change the path?",
                        -title => 'Problem with file',
                        -type  => 'YesNo',
                    );
                    setpngspath() if $response =~ /yes/i;
                    return;
                }
            }
            if (OS_Win) {
                $dospath = dos_path($dospath);
                $dosfile = dos_path($dosfile);
            }
            runner( $dospath, $dosfile );
        }
    }
    else {
        setpngspath();
    }
}

# Routine to find highlight word list
sub scannosfile {
    $scannoslistpath = os_normal($scannoslistpath);
    $scannoslist     = $top->getOpenFile(
        -title      => 'Word file?',
        -initialdir => $scannoslistpath
    );
    if ($scannoslist) {
        my ( $name, $path, $extension )
            = fileparse( $scannoslist, '\.[^\.]*$' );
        $scannoslistpath = $path;
        hilitetgl() if ( $lglobal{scanno_hl} );
        %{ $lglobal{wordlist} } = ();
        hilitetgl();
    }
}

##routine to automatically highlight words in the text
sub highlightscannos {
    return 0 unless $lglobal{scanno_hl};
    unless ( %{ $lglobal{wordlist} } ) {
        scannosfile() unless ( defined $scannoslist && -e $scannoslist );
        return 0 unless $scannoslist;
        if ( open my $fh, '<', $scannoslist ) {
            while (<$fh>) {
                utf8::decode($_);
                $_ =~ s/^\x{FFEF}?// if ( $. < 2 );
                s/\cM\cJ|\cM|\cJ//g;
                next unless length $_;
                my @words = split /[\s \xA0]+/, $_;
                for my $word (@words) {
                    next unless length $word;
                    $word =~ s/^\p{Punct}*|\p{Punct}*$//g;
                    $lglobal{wordlist}->{$word} = '';
                }
            }
        }
        else {
            warn "Cannot open $scannoslist: $!";
            return 0;
        }
    }
    my ( $fileend, undef ) = split /\./, $textwindow->index('end');
    if ( $lglobal{hl_index} < $fileend ) {
        for ( 0 .. 99 ) {
            my $textline = $textwindow->get( "$lglobal{hl_index}.0",
                "$lglobal{hl_index}.end" );
            while ( $textline
                =~ s/ [^\p{Alnum} ]|[^\p{Alnum} ] |[^\p{Alnum} ][^\p{Alnum} ]/  /
                )
            {
            }
            $textline =~ s/^'|[,']+$/"/;
            $textline =~ s/--/  /g;
            my @words = split( /[^'\p{Alnum},-]+/, $textline );
            for my $word (@words) {
                if ( defined $lglobal{wordlist}->{$word} ) {
                    my $indx = 0;
                    my $index;
                    while (1) {
                        $index = index( $textline, $word, $indx );
                        last if ( $index < 0 );
                        $indx = $index + length($word);
                        if ( $index > 0 ) {
                            next
                                if (
                                $textwindow->get(
                                    "$lglobal{hl_index}.@{[$index-1]}")
                                =~ /\p{Alnum}/
                                );
                        }
                        next
                            if (
                            $textwindow->get(
                                "$lglobal{hl_index}.@{[$index + length $word]}"
                            ) =~ /\p{Alnum}/
                            );
                        $textwindow->tagAdd(
                            'scannos',
                            "$lglobal{hl_index}.$index",
                            "$lglobal{hl_index}.$index +@{[length $word]}c"
                        );
                    }
                }
            }
            $lglobal{hl_index}++;
            last if ( $lglobal{hl_index} > $fileend );
        }
    }
    my $idx1 = $textwindow->index('@0,0'); # First visible line in text widget

    $lglobal{visibleline} = $idx1;
    $textwindow->tagRemove(
        'scannos',
        $idx1,
        $textwindow->index(
            '@' . $textwindow->width . ',' . $textwindow->height
        )
    );
    my ( $dummy, $ypix ) = $textwindow->dlineinfo($idx1);
    my $theight = $textwindow->height;
    my $oldy = my $lastline = -99;
    while (1) {
        my $idx = $textwindow->index( '@0,' . "$ypix" );
        ( my $realline ) = split( /\./, $idx );
        my ( $x, $y, $wi, $he ) = $textwindow->dlineinfo($idx);
        my $textline = $textwindow->get( "$realline.0", "$realline.end" );
        while ( $textline
            =~ s/ [^\p{Alnum} ]|[^\p{Alnum} ] |[^\p{Alnum} ][^\p{Alnum} ]/  /
            )
        {
        }
        $textline =~ s/^'|[,']+$/"/;
        $textline =~ s/--/  /g;
        my @words = split( /[^'\p{Alnum},-]/, $textline );

        for my $word (@words) {
            if ( defined $lglobal{wordlist}->{$word} ) {
                my $indx = 0;
                my $index;
                while (1) {
                    $index = index( $textline, $word, $indx );
                    last if ( $index < 0 );
                    $indx = $index + length($word);
                    if ( $index > 0 ) {
                        next
                            if ( $textwindow->get("$realline.@{[$index - 1]}")
                            =~ /\p{Alnum}/ );
                    }
                    next
                        if (
                        $textwindow->get(
                            "$realline.@{[$index + length $word]}")
                        =~ /\p{Alnum}/
                        );
                    $textwindow->tagAdd(
                        'scannos',
                        "$realline.$index",
                        "$realline.$index +@{[length $word]}c"
                    );
                }
            }
        }
        last unless defined $he;
        last if ( $oldy == $y );    #line is the same as the last one
        $oldy = $y;
        $ypix += $he;
        last
            if $ypix
                >= ( $theight - 1 );   #we have reached the end of the display
        last if ( $y == $ypix );
    }
}

## The main menu building code.
sub buildmenu {
    $menu->Cascade(
        -label     => '~File',
        -tearoff   => 0,
        -menuitems => [
            [ Button => '~Open', -command => [ \&fileopen ] ],
            [ 'separator', '' ],
            map ( [ Button   => "$recentfile[$_]",
                    -command => [ \&openfile, $recentfile[$_] ],
                ],
                ( 0 .. scalar(@recentfile) - 1 ) ),
            [ 'separator', '' ],
            [   Button       => '~Save',
                -command     => \&savefile,
                -accelerator => 'Ctrl+s'
            ],
            [   Button   => 'Save ~As',
                -command => sub {         # FIXME: Move to sub saveas
                    my ($name);
                    $name = $textwindow->getSaveFile(
                        -title      => 'Save As',
                        -initialdir => $globallastpath
                    );
                    if ( defined($name) and length($name) ) {
                        my $binname = $name;
                        $binname =~ s/\.[^\.]*?$/\.bin/;
                        if ( $binname eq $name ) { $binname .= '.bin' }
                        if ( -e $binname ) {
                            my $warning = $top->Dialog(
                                -text =>
                                    "WARNING! A file already exists that will use the same .bin filename.\n"
                                    . "It is highly recommended that a different file name is chosen to avoid\n"
                                    . "corrupting the .bin files.\n\n Are you sure you want to continue?",
                                -title          => 'Bin File Collision!',
                                -bitmap         => 'warning',
                                -buttons        => [qw/Continue Cancel/],
                                -default_button => qw/Cancel/,
                            );
                            my $answer = $warning->Show;
                            return unless ( $answer eq 'Continue' );
                        }
                        $textwindow->SaveUTF($name);
                        my ( $fname, $extension, $filevar );
                        ( $fname, $globallastpath, $extension )
                            = fileparse($name);
                        $globallastpath = os_normal($globallastpath);
                        $name           = os_normal($name);
                        $textwindow->FileName($name);
                        $lglobal{global_filename} = $name;
                        binsave();
                        recentupdate($name);
                    }
                    else {
                        return;
                    }
                    update_indicators();
                    }
            ],
            [   Button   => '~Include',
                -command => sub {         # FIXME: file_include
                    my ($name);
                    my $types = [
                        [   'Text Files',
                            [ '.txt', '.text', '.ggp', 'htm', 'html' ]
                        ],
                        [ 'All Files', ['*'] ],
                    ];
                    return if $lglobal{global_filename} =~ /No File Loaded/;
                    $name = $textwindow->getOpenFile(
                        -filetypes  => $types,
                        -title      => 'File Include',
                        -initialdir => $globallastpath
                    );
                    $textwindow->IncludeFile($name)
                        if defined($name)
                            and length($name);
                    update_indicators();
                    }
            ],
            [   Button   => '~Close',
                -command => sub {       # FIXME: sub file_close
                    return if ( confirmempty() =~ /cancel/i );
                    clearvars();
                    update_indicators();
                    }
            ],
            [ 'separator', '' ],
            [   Button   => 'Import Prep Text Files',
                -command => sub { prep_import() }       # FIXME: \&prep_import
            ],
            [   Button   => 'Export As Prep Text Files',
                -command => sub { prep_export() }
            ],
            [ 'separator', '' ],
            [ Button => '~Guess Page Markers', -command => \&guesswindow ],
            [ Button => 'Set Page ~Markers',   -command => \&markpages ],
            [ 'separator', '' ],
            [ Button => 'E~xit', -command => \&myexit ],
        ]
    );

    $menu->Cascade(
        -label     => '~Edit',
        -tearoff   => 1,
        -menuitems => [
            [   Button       => 'Undo',
                -command     => sub { $textwindow->undo },
                -accelerator => 'Ctrl+z'
            ],
            [   Button       => 'Redo',
                -command     => sub { $textwindow->redo },
                -accelerator => 'Ctrl+y'
            ],
            [ 'separator', '' ],
            [   Button       => 'Cut',
                -command     => sub { cut() },
                -accelerator => 'Ctrl+x'
            ],
            [   Button       => 'Copy',
                -command     => sub { copy() },
                -accelerator => 'Ctrl+c'
            ],
            [   Button       => 'Paste',
                -command     => sub { paste() },
                -accelerator => 'Ctrl+v'
            ],
            [   Button   => 'Col Paste',
                -command => sub {          # FIXME: sub edit_column_paste
                    $textwindow->addGlobStart;
                    $textwindow->clipboardColumnPaste;
                    $textwindow->addGlobEnd;
                },
                -accelerator => 'Ctrl+`'
            ],
            [ 'separator', '' ],
            [   Button   => 'Select All',
                -command => sub {
                    $textwindow->selectAll;
                },
                -accelerator => 'Ctrl+/'
            ],
            [   Button   => 'Unselect All',
                -command => sub {
                    $textwindow->unselectAll;
                },
                -accelerator => 'Ctrl+\\'
            ],
        ]
    );

    $menu->Cascade(
        -label     => 'Sea~rch',
        -tearoff   => 1,
        -menuitems => [
            [ Button => 'Search & ~Replace', -command => \&searchpopup ],
            [ Button => '~Stealth Scannos',  -command => \&stealthscanno ],
            [ Button => 'Spell ~Check',      -command => \&spellchecker ],
            [   Button   => 'Goto ~Line...',
                -command => sub { gotoline(); update_indicators(); }
            ],
            [   Button   => 'Goto ~Page...',
                -command => sub { gotopage(); update_indicators(); }
            ],
            [   Button   => '~Which Line?',
                -command => sub { $textwindow->WhatLineNumberPopUp }
            ],

            [ 'separator', '' ],

            [   Button   => "Find Proofer Comments",
                -command => \&find_proofer_comment
            ],
            [   Button   => 'Find next /*..*/ block',
                -command => [ \&nextblock, 'default', 'forward' ]
            ],
            [   Button   => 'Find previous /*..*/ block',
                -command => [ \&nextblock, 'default', 'reverse' ]
            ],
            [   Button   => 'Find next /#..#/ block',
                -command => [ \&nextblock, 'block', 'forward' ]
            ],
            [   Button   => 'Find previous /#..#/ block',
                -command => [ \&nextblock, 'block', 'reverse' ]
            ],
            [   Button   => 'Find next /$..$/ block',
                -command => [ \&nextblock, 'stet', 'forward' ]
            ],
            [   Button   => 'Find previous /$..$/ block',
                -command => [ \&nextblock, 'stet', 'reverse' ]
            ],
            [   Button   => 'Find next /p..p/ block',
                -command => [ \&nextblock, 'poetry', 'forward' ]
            ],
            [   Button   => 'Find previous /p..p/ block',
                -command => [ \&nextblock, 'poetry', 'reverse' ]
            ],
            [   Button   => 'Find next indented block',
                -command => [ \&nextblock, 'indent', 'forward' ]
            ],
            [   Button   => 'Find previous indented block',
                -command => [ \&nextblock, 'indent', 'reverse' ]
            ],
            ,
            [ 'separator', '' ],
            [   Button   => 'Find ~Orphaned Brackets & Markup',
                -command => \&brackets
            ],
            [ 'separator', '' ],
            [   Button       => 'Highlight double quotes in selection',
                -command     => [ \&hilite, '"' ],
                -accelerator => 'Ctrl+Shift+"'
            ],
            [   Button       => 'Highlight single quotes in selection',
                -command     => [ \&hilite, '\'' ],
                -accelerator => 'Ctrl+\''
            ],
            [   Button       => 'Highlight arbitrary characters in selection',
                -command     => \&hilitepopup,
                -accelerator => 'Ctrl+Alt+h'
            ],
            [   Button   => 'Remove Highlights',
                -command => sub {               # FIXME: sub search_rm_hilites
                    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                    $textwindow->tagRemove( 'quotemark', '1.0', 'end' );
                },
                -accelerator => 'Ctrl+0'
            ],
        ]
    );

    $menu->Cascade(
        qw/-label ~Bookmarks -tearoff 1 -menuitems/ => [
            map ( [ Button       => "Set Bookmark $_",
                    -command     => [ \&setbookmark, $_ ],
                    -accelerator => "Ctrl+Shift+$_"
                ],
                ( 1 .. 5 ) ),
            [ 'separator', '' ],
            map ( [ Button       => "Go To Bookmark $_",
                    -command     => [ \&gotobookmark, $_ ],
                    -accelerator => "Ctrl+$_"
                ],
                ( 1 .. 5 ) ),
        ],
    );

    $menu->Cascade(
        -label     => '~Selection',
        -tearoff   => 1,
        -menuitems => [
            [   Button   => '~lowercase Selection',
                -command => sub { case ('lc'); }
            ],
            [   Button   => '~Sentence case Selection',
                -command => sub { case ('sc'); }
            ],
            [   Button   => '~Title Case Selection',
                -command => sub { case ('tc'); }
            ],
            [   Button   => '~UPPERCASE Selection',
                -command => sub { case ('uc'); }
            ],
            [ 'separator', '' ],
            [   Button   => 'Surround Selection With....',
                -command => \&surround
            ],
            [   Button   => 'Flood Fill Selection With....',
                -command => sub {
                    $textwindow->addGlobStart;
                    flood();
                    $textwindow->addGlobEnd;
                    }
            ],
            [ 'separator', '' ],
            [   Button   => 'Indent Selection 1',
                -command => sub {
                    $textwindow->addGlobStart;
                    indent('in');
                    $textwindow->addGlobEnd;
                    }
            ],
            [   Button   => 'Indent Selection -1',
                -command => sub {
                    $textwindow->addGlobStart;
                    indent('out');
                    $textwindow->addGlobEnd;
                    }
            ],
            [ 'separator', '' ],
            [   Button   => '~Rewrap Selection',
                -command => sub {
                    $textwindow->addGlobStart;
                    selectrewrap();
                    $textwindow->addGlobEnd;
                    }
            ],
            [   Button   => '~Block Rewrap Selection',
                -command => sub {
                    $textwindow->addGlobStart;
                    blockrewrap();
                    $textwindow->addGlobEnd;
                    }
            ],
            [   Button   => 'Interrupt Rewrap',
                -command => sub { $operationinterrupt = 1 }
            ],
            [ 'separator', '' ],
            [ Button => 'ASCII ~Boxes',          -command => \&asciipopup ],
            [ Button => '~Align text on string', -command => \&alignpopup ],
            [ 'separator', '' ],
            [   Button   => 'Convert To Named/Numeric Entities',
                -command => sub {
                    $textwindow->addGlobStart;
                    tonamed();
                    $textwindow->addGlobEnd;
                    }
            ],
            [   Button   => 'Convert From Named/Numeric Entities',
                -command => sub {
                    $textwindow->addGlobStart;
                    fromnamed();
                    $textwindow->addGlobEnd;
                    }
            ],
            [   Button   => 'Convert Fractions',
                -command => sub {
                    my @ranges = $textwindow->tagRanges('sel');
                    $textwindow->addGlobStart;
                    if (@ranges) {
                        while (@ranges) {
                            my $end   = pop @ranges;
                            my $start = pop @ranges;
                            fracconv( $start, $end );
                        }
                    }
                    else {
                        fracconv( '1.0', 'end' );
                    }
                    $textwindow->addGlobEnd;
                    }
            ],
        ]
    );

    $menu->Cascade(
        -label     => 'Fi~xup',
        -tearoff   => 1,
        -menuitems => [
            [   Button   => 'Run ~Word Frequency Routine',
                -command => \&wordcount
            ],
            [ 'separator', '' ],
            [ Button => 'Run ~Gutcheck',    -command => \&gutcheck ],
            [ Button => 'Gutcheck options', -command => \&gutopts ],
            [ Button => 'Run ~Jeebies',     -command => \&jeebiespop_up ],
            [ 'separator', '' ],
            [   Button   => 'Remove End-of-line Spaces',
                -command => sub {
                    $textwindow->addGlobStart;
                    endofline();
                    $textwindow->addGlobEnd;
                    }
            ],
            [ Button => 'Run Fi~xup', -command => \&fixpopup ],
            [ 'separator', '' ],
            [   Button   => 'Fix ~Page Separators',
                -command => \&separatorpopup
            ],
            [   Button   => 'Remove Blank Lines Before Page Separators',
                -command => sub {
                    $textwindow->addGlobStart;
                    delblanklines();
                    $textwindow->addGlobEnd;
                    }
            ],
            [ 'separator', '' ],
            [ Button => '~Footnote Fixup', -command => \&footnotepop ],
            [ Button => '~HTML Fixup',     -command => \&markpopup ],
            [ Button => '~Sidenote Fixup', -command => \&sidenotes ],
            [   Button   => 'Reformat Poetry ~Line Numbers',
                -command => \&poetrynumbers
            ],
            [   Button   => 'Convert Windows CP 1252 characters to Unicode',
                -command => \&cp1252toUni
            ],
            [ 'separator', '' ],
            [   Button   => 'ASCII Table Special Effects',
                -command => \&tablefx
            ],
            [ 'separator', '' ],
            [   Button   => 'Clean Up Rewrap ~Markers',
                -command => sub {
                    $textwindow->addGlobStart;
                    cleanup();
                    $textwindow->addGlobEnd;
                    }
            ],
            [ 'separator', '' ],
            [   Button   => 'Find Greek',
                -command => \&findandextractgreek
            ],

           # FIXME: [   Button   => 'Convert Greek [STUB - does nothing yet]',
           #    -command => \&convertgreek
           # ],
        ]
    );

    $menu->Cascade(
        -label     => 'Text Processing',
        -tearoff   => 1,
        -menuitems => [
            [   Button   => "Convert Italics",
                -command => \&text_convert_italic
            ],
            [ Button => "Convert Bold", -command => \&text_convert_bold ],

         #[ Button => "Convert Smallcaps", -command => \&text_convert_smcap ],
            [   Button   => '~Add a Thought Break',
                -command => sub {
                    $textwindow->addGlobStart;
                    thoughtbreak();
                    $textwindow->addGlobEnd;
                    }
            ],
            [   Button   => 'Convert <tb> to asterisk break',
                -command => sub {
                    $textwindow->addGlobStart;
                    text_convert_tb();
                    $textwindow->addGlobEnd;
                    }
            ],

            [ Button => "Options", -command => \&text_convert_options ],
        ]
    );
    $menu->Cascade(
        qw/-label Externa~l -tearoff 1 -menuitems/ => [
            [   Button   => 'Setup External Operations',
                -command => \&externalpopup
            ],
            [ 'separator', '' ],
            map ( [ Button   => "~$_ $extops[$_]{label}",
                    -command => [ \&xtops, $_ ]
                ],
                ( 0 .. 9 ) ),
        ],
    );

    if ( $Tk::version ge 8.4 ) {
        my %utfsorthash;
        for ( keys %{ $lglobal{utfblocks} } ) {
            $utfsorthash{ $lglobal{utfblocks}{$_}->[0] } = $_;
        }
        if ( $lglobal{utfrangesort} ) {
            $menu->Cascade(
                qw/-label ~Unicode -tearoff 0 -menuitems/ => [
                    [   Radiobutton => 'Sort by Name',
                        -variable   => \$lglobal{utfrangesort},
                        -command    => \&rebuildmenu,
                        -value      => 0,
                    ],
                    map ( [ Button   => "$utfsorthash{$_}",
                            -command => [
                                \&utfpopup,
                                $utfsorthash{$_},
                                $lglobal{utfblocks}{ $utfsorthash{$_} }[0],
                                $lglobal{utfblocks}{ $utfsorthash{$_} }[1]
                            ],
                            -accelerator =>
                                $lglobal{utfblocks}{ $utfsorthash{$_} }[0]
                                . ' - '
                                . $lglobal{utfblocks}{ $utfsorthash{$_} }[1]
                        ],
                        ( sort ( keys %utfsorthash ) ) ),
                ],
            );
        }
        else {
            $menu->Cascade(
                qw/-label ~Unicode -tearoff 0 -menuitems/ => [
                    [   Radiobutton => 'Sort by Range',
                        -variable   => \$lglobal{utfrangesort},
                        -command    => \&rebuildmenu,
                        -value      => 1,
                    ],
                    map ( [ Button   => "$_",
                            -command => [
                                \&utfpopup,
                                $_,
                                $lglobal{utfblocks}{$_}[0],
                                $lglobal{utfblocks}{$_}[1]
                            ],
                            -accelerator => $lglobal{utfblocks}{$_}[0] . ' - '
                                . $lglobal{utfblocks}{$_}[1]
                        ],
                        ( sort ( keys %{ $lglobal{utfblocks} } ) ) ),
                ],
            );
        }
    }

    $menu->Cascade(
        -label     => '~Prefs',
        -tearoff   => 1,
        -menuitems => [
            [ Button => 'Set Rewrap ~margins',   -command => \&setmargins ],
            [ Button => '~Font',                 -command => \&fontsize ],
            [ Button => 'Browser Start Command', -command => \&setbrowser ],
            [   Cascade  => 'Set File ~Paths',
                -tearoff => 0,
                -menuitems =>
                    [ # FIXME: sub this and generalize for all occurences in menu code.
                    [   Button   => 'Locate Gutcheck Executable',
                        -command => sub {
                            my $types;
                            if (OS_Win) {
                                $types = [
                                    [ 'Executable', [ '.exe', ] ],
                                    [ 'All Files',  ['*'] ],
                                ];
                            }
                            else {
                                $types = [ [ 'All Files', ['*'] ] ];
                            }
                            $lglobal{pathtemp} = $textwindow->getOpenFile(
                                -filetypes => $types,
                                -title => 'Where is the Gutcheck executable?',
                                -initialdir => dirname($gutpath)
                            );
                            $gutpath = $lglobal{pathtemp}
                                if $lglobal{pathtemp};
                            return unless $gutpath;
                            $gutpath = os_normal($gutpath);
                            saveset();
                            }
                    ],
                    [   Button   => 'Locate Jeebies Executable',
                        -command => sub {
                            my $types;
                            if (OS_Win) {
                                $types = [
                                    [ 'Executable', [ '.exe', ] ],
                                    [ 'All Files',  ['*'] ],
                                ];
                            }
                            else {
                                $types = [ [ 'All Files', ['*'] ] ];
                            }
                            $lglobal{pathtemp} = $textwindow->getOpenFile(
                                -filetypes => $types,
                                -title => 'Where is the Jeebies executable?',
                                -initialdir => dirname($jeebiespath)
                            );
                            $jeebiespath = $lglobal{pathtemp}
                                if $lglobal{pathtemp};
                            return unless $jeebiespath;
                            $jeebiespath = os_normal($jeebiespath);
                            saveset();
                            }
                    ],
                    [   Button   => 'Locate Aspell Executable',
                        -command => sub {
                            my $types;
                            if (OS_Win) {
                                $types = [
                                    [ 'Executable', [ '.exe', ] ],
                                    [ 'All Files',  ['*'] ],
                                ];
                            }
                            else {
                                $types = [ [ 'All Files', ['*'] ] ];
                            }
                            $lglobal{pathtemp} = $textwindow->getOpenFile(
                                -filetypes => $types,
                                -title => 'Where is the Aspell executable?',
                                -initialdir => dirname($globalspellpath)
                            );
                            $globalspellpath = $lglobal{pathtemp}
                                if $lglobal{pathtemp};
                            return unless $globalspellpath;
                            $globalspellpath = os_normal($globalspellpath);
                            saveset();
                            }
                    ],
                    [   Button   => 'Locate Tidy Executable',
                        -command => sub {
                            my $types;
                            if (OS_Win) {
                                $types = [
                                    [ 'Executable', [ '.exe', ] ],
                                    [ 'All Files',  ['*'] ],
                                ];
                            }
                            else {
                                $types = [ [ 'All Files', ['*'] ] ];
                            }
                            $tidycommand = $textwindow->getOpenFile(
                                -filetypes => $types,
                                -title     => 'Where is the Tidy executable?'
                            );
                            return unless $tidycommand;
                            $tidycommand = os_normal($tidycommand);
                            saveset();
                            }
                    ],
                    [   Button   => 'Locate Image Viewer Executable',
                        -command => \&viewerpath
                    ],
                    [   Button   => 'Set Images Directory',
                        -command => \&setpngspath
                    ],
                    ]
            ],
            [   Checkbutton => 'Leave Bookmarks Highlighted',
                -variable   => \$bkmkhl,
                -onvalue    => 1,
                -offvalue   => 0
            ],
            [   Checkbutton => 'Enable Quotes Highlighting',
                -variable   => \$nohighlights,
                -onvalue    => 0,
                -offvalue   => 1
            ],
            [   Checkbutton => 'Keep Pop-ups On Top',
                -variable   => \$stayontop,
                -onvalue    => 1,
                -offvalue   => 0
            ],
            [   Checkbutton => 'Enable Bell',
                -variable   => \$nobell,
                -onvalue    => 0,
                -offvalue   => 1
            ],
            [   Checkbutton => 'Auto Set Page Markers On File Open',
                -variable   => \$auto_page_marks,
                -onvalue    => 1,
                -offvalue   => 0
            ],
            [   Checkbutton =>
                    'Leave Space After End-Of-Line Hyphens During Rewrap',
                -variable => \$rwhyphenspace,
                -onvalue  => 1,
                -offvalue => 0
            ],
            [   Cascade    => 'Toolbar Prefs',
                -tearoff   => 1,
                -menuitems => [
                    [   Checkbutton => 'Enable Toolbar',
                        -variable   => \$notoolbar,
                        -command    => [ \&toolbar_toggle ],
                        -onvalue    => 0,
                        -offvalue   => 1
                    ],
                    [   Radiobutton => 'Toolbar on Top',
                        -variable   => \$toolside,
                        -command    => sub {
                            $lglobal{toptool}->destroy if $lglobal{toptool};
                            undef $lglobal{toptool};
                            toolbar_toggle();
                        },
                        -value => 'top'
                    ],
                    [   Radiobutton => 'Toolbar on Bottom',
                        -variable   => \$toolside,
                        -command    => sub {
                            $lglobal{toptool}->destroy if $lglobal{toptool};
                            undef $lglobal{toptool};
                            toolbar_toggle();
                        },
                        -value => 'bottom'
                    ],
                    [   Radiobutton => 'Toolbar on Left',
                        -variable   => \$toolside,
                        -command    => sub {
                            $lglobal{toptool}->destroy if $lglobal{toptool};
                            undef $lglobal{toptool};
                            toolbar_toggle();
                        },
                        -value => 'left'
                    ],
                    [   Radiobutton => 'Toolbar on Right',
                        -variable   => \$toolside,
                        -command    => sub {
                            $lglobal{toptool}->destroy if $lglobal{toptool};
                            undef $lglobal{toptool};
                            toolbar_toggle();
                        },
                        -value => 'right'
                    ],
                ]
            ],
            [   Button   => 'Set Button Highlight Color',
                -command => sub {
                    my $thiscolor = setcolor($activecolor);
                    $activecolor = $thiscolor if $thiscolor;
                    OS_Win
                        ? $lglobal{checkcolor}
                        = 'white'
                        : $lglobal{checkcolor} = $activecolor;
                    }
            ],
            [   Button   => 'Spellcheck Dictionary Select',
                -command => sub { spelloptions() }
            ],
            [   Checkbutton => 'Enable Auto Save',
                -variable   => \$autosave,
                -command    => sub {
                    toggle_autosave();
                    saveset();
                    }
            ],
            [   Button   => 'Auto Save Interval',
                -command => sub {
                    saveinterval();
                    saveset();
                    set_autosave() if $autosave;
                    }
            ],
            [   Checkbutton => 'Enable Auto Backups',
                -variable   => \$autobackup,
                -onvalue    => 1,
                -offvalue   => 0
            ],
            [   Checkbutton => 'Enable Scanno Highlighting',
                -variable   => \$lglobal{scanno_hl},
                -onvalue    => 1,
                -offvalue   => 0,
                -command    => \&hilitetgl
            ],
            [   Button   => 'Set Scanno Highlight Color',
                -command => sub {
                    my $thiscolor = setcolor($highlightcolor);
                    $highlightcolor = $thiscolor if $thiscolor;
                    $textwindow->tagConfigure( 'scannos',
                        -background => $highlightcolor );
                    saveset();
                    }
            ],
            [   Button   => 'Search History Size',
                -command => sub {
                    searchsize();
                    saveset();
                    }
            ],
        ]
    );
    $menu->Cascade(
        -label     => '~Help',
        -tearoff   => 1,
        -menuitems => [
            [ Button => '~About',    -command => \&about_pop_up ],
            [ Button => '~Versions', -command => [ \&showversion, $top ] ],
            [   Button   => '~Manual',
                -command => sub {        # FIXME: sub this out.
                    runner("$globalbrowserstart guiguts.html")
                        if ( -e 'guiguts.html' );
                    }
            ],

            # FIXME: Disable update check until it works
            #[ Button => 'Check For ~Updates',     -command => \&checkver ],
            [ Button => '~Hot keys',              -command => \&hotkeyshelp ],
            [ Button => '~Function History',      -command => \&opspop_up ],
            [ Button => '~Greek Transliteration', -command => \&greekpopup ],
            [ Button => '~Latin 1 Chart',         -command => \&latinpopup ],
            [ Button => '~Regex Quick Reference', -command => \&regexref ],
            [ Button => '~UTF Character entry',   -command => \&utford ],
            [ Button => '~UTF Character Search',  -command => \&uchar ],
        ]
    );
}

## Toggle visible page markers
sub viewpagenums {
    if ( $lglobal{seepagenums} ) {
        $lglobal{seepagenums} = 0;
        my @marks = $textwindow->markNames;
        for ( sort @marks ) {
            if ( $_ =~ /Pg(\S+)/ ) {
                my $pagenum = " Pg$1 ";
                $textwindow->ntdelete( $_, "$_ +@{[length $pagenum]}c" );
            }
        }
        $textwindow->tagRemove( 'pagenum', '1.0', 'end' );
        if ( $lglobal{pnumpop} ) {
            $lglobal{pnpopgoem} = $lglobal{pnumpop}->geometry;
            $lglobal{pnumpop}->destroy;
            undef $lglobal{pnumpop};
        }
    }
    else {
        $lglobal{seepagenums} = 1;
        my @marks = $textwindow->markNames;
        for ( sort @marks ) {
            if ( $_ =~ /Pg(\S+)/ ) {
                my $pagenum = " Pg$1 ";
                $textwindow->ntinsert( $_, $pagenum );
                $textwindow->tagAdd( 'pagenum', $_,
                    "$_ +@{[length $pagenum]}c" );
            }
        }
        pnumadjust();
    }
}

## Pop up a window which will allow jumping directly to a specified page
sub gotolabel {
    unless ( defined( $lglobal{gotolabpop} ) ) {
        return unless %pagenumbers;
        for ( keys(%pagenumbers) ) {
            $lglobal{pagedigits} = ( length($_) - 2 );
            last;
        }
        $lglobal{gotolabpop} = $top->DialogBox(
            -buttons => [qw[Ok Cancel]],
            -title   => 'Goto Page Label',
            -popover => $top,
            -command => sub {
                if ( $_[0] eq 'Ok' ) {
                    my $mark;
                    for ( keys %pagenumbers ) {
                        if (   $pagenumbers{$_}{label}
                            && $pagenumbers{$_}{label} eq
                            $lglobal{lastlabel} )
                        {
                            $mark = $_;
                            last;
                        }
                    }
                    unless ($mark) {
                        $lglobal{gotolabpop}->bell;
                        $lglobal{gotolabpop}->destroy;
                        undef $lglobal{gotolabpop};
                        return;
                    }
                    my $index = $textwindow->index($mark);
                    $textwindow->markSet( 'insert', "$index +1l linestart" );
                    $textwindow->see('insert');
                    $textwindow->focus;
                    update_indicators();
                    $lglobal{gotolabpop}->destroy;
                    undef $lglobal{gotolabpop};
                }
                else {
                    $lglobal{gotolabpop}->destroy;
                    undef $lglobal{gotolabpop};
                }
            }
        );
        $lglobal{gotolabpop}->resizable( 'no', 'no' );
        my $frame = $lglobal{gotolabpop}->Frame->pack( -fill => 'x' );
        $frame->Label( -text => 'Enter Label: ' )->pack( -side => 'left' );
        $lglobal{lastlabel} = 'Pg ' unless $lglobal{lastlabel};
        my $entry = $frame->Entry(
            -background   => 'white',
            -width        => 25,
            -textvariable => \$lglobal{lastlabel}
        )->pack( -side => 'left', -fill => 'x' );
        $lglobal{gotolabpop}->Advertise( entry => $entry );
        $lglobal{gotolabpop}->Popup;
        $lglobal{gotolabpop}->Subwidget('entry')->focus;
        $lglobal{gotolabpop}->Subwidget('entry')->selectionRange( 0, 'end' );
        $lglobal{gotolabpop}->Wait;
    }
}

## Update the Operations history
sub oppopupdate {
    $lglobal{oplistbox}->delete( '0', 'end' );
    $lglobal{oplistbox}->insert( 'end', @operations );
}

## Footnote Operations
# Pop up a window showing all the footnote addresses with potential
# problems highlighted
sub fnview {
    my ( %fnotes, %anchors, $ftext );
    viewpagenums() if ( $lglobal{seepagenums} );
    if ( defined( $lglobal{footviewpop} ) ) {
        $lglobal{footviewpop}->deiconify;
        $lglobal{footviewpop}->raise;
        $lglobal{footviewpop}->focus;
    }
    else {
        $lglobal{footviewpop} = $top->Toplevel( -background => 'white' );
        $lglobal{footviewpop}->title('Footnotes');
        my $frame1 = $lglobal{footviewpop}->Frame( -background => 'white' )
            ->pack( -side => 'top', -anchor => 'n' );
        $frame1->Label(
            -text =>
                "Duplicate anchors.\nmore than one fn\npointing to same anchor",
            -background => 'yellow',
        )->grid( -row => 1, -column => 1 );
        $frame1->Label(
            -text =>
                "No anchor found.\npossibly missing anchor,\nmissing colon, incorrect #",
            -background => 'pink',
        )->grid( -row => 1, -column => 2 );
        $frame1->Label(
            -text => "Out of sequence.\nfn's not in same\norder as anchors",
            -background => 'cyan',
        )->grid( -row => 1, -column => 3 );
        $frame1->Label(
            -text =>
                "Very long.\nfn missing its' end bracket?\n(may just be a long fn.)",
            -background => 'tan',
        )->grid( -row => 1, -column => 4 );

        my $frame2 = $lglobal{footviewpop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'both',
            -expand => 'both'
        );
        $ftext = $frame2->Scrolled(
            'ROText',
            -scrollbars => 'se',
            -background => 'white',
            -font       => $lglobal{font},
            )->pack(
            -anchor => 'nw',
            -fill   => 'both',
            -expand => 'both',
            -padx   => 2,
            -pady   => 2
            );
        drag($ftext);
        $ftext->tagConfigure( 'seq',    background => 'cyan' );
        $ftext->tagConfigure( 'dup',    background => 'yellow' );
        $ftext->tagConfigure( 'noanch', background => 'pink' );
        $ftext->tagConfigure( 'long',   background => 'tan' );
        $lglobal{footviewpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{footviewpop}->destroy;
                undef $lglobal{footviewpop};
            }
        );
        $lglobal{footviewpop}->Icon( -image => $icon );
        for my $findex ( 1 .. $lglobal{fntotal} ) {
            $ftext->insert( 'end',
                      'footnote #' 
                    . $findex
                    . '  line.column - '
                    . $lglobal{fnarray}->[$findex][0]
                    . ",\tanchor line.column - "
                    . $lglobal{fnarray}->[$findex][2]
                    . "\n" );
            if ( $lglobal{fnarray}->[$findex][0] eq
                $lglobal{fnarray}->[$findex][2] )
            {
                $ftext->tagAdd( 'noanch', 'end -2l', 'end -1l' );
                $ftext->update;
            }
            if (( $findex > 1 )
                && ($textwindow->compare(
                        $lglobal{fnarray}->[$findex][0], '<',
                        $lglobal{fnarray}->[ $findex - 1 ][0]
                    )
                    || $textwindow->compare(
                        $lglobal{fnarray}->[$findex][2], '<',
                        $lglobal{fnarray}->[ $findex - 1 ][2]
                    )
                )
                )
            {
                $ftext->tagAdd( 'seq', 'end -2l', 'end -1l' );
                $ftext->update;
            }
            if ( exists $fnotes{ $lglobal{fnarray}->[$findex][2] } ) {
                $ftext->tagAdd( 'dup', 'end -2l', 'end -1l' );
                $ftext->update;
            }
            if (  $lglobal{fnarray}->[$findex][1]
                - $lglobal{fnarray}->[$findex][0] > 40 )
            {
                $ftext->tagAdd( 'long', 'end -2l', 'end -1l' );
                $ftext->update;
            }
            $fnotes{ $lglobal{fnarray}->[$findex][2] } = $findex;
        }
        BindMouseWheel($ftext);
    }
}

# Clean up footnotes in ASCII version of text. Note: destructive. Use only
# at end of editing.
sub footnotetidy {
    my ( $begin, $end, $colon );
    $lglobal{fnsecondpass} = 0;
    footnotefixup();
    return unless $lglobal{fntotal} > 1;
    $lglobal{fnindex} = 1;
    while (1) {
        $begin = $textwindow->index( 'fns' . $lglobal{fnindex} );
        $textwindow->delete( "$begin+1c", "$begin+10c" );
        $colon = $textwindow->search( '--', ':', $begin,
            $textwindow->index( 'fne' . $lglobal{fnindex} ) );
        $textwindow->delete($colon) if $colon;
        $textwindow->insert( $colon, ']' ) if $colon;
        $end = $textwindow->index( 'fne' . $lglobal{fnindex} );
        $textwindow->delete("$end-1c");
        $textwindow->tagAdd( 'sel', 'fns' . $lglobal{fnindex}, "$end+1c" );
        selectrewrap();
        $lglobal{fnindex}++;
        last if $lglobal{fnindex} > $lglobal{fntotal};
    }
}

sub footnotemove {
    my ( $lz, %footnotes, $zone, $index, $r, $c, $marker );
    $lglobal{fnsecondpass} = 0;
    footnotefixup();
    autoendlz();
    getlz();
    $lglobal{fnindex} = 1;
    foreach $lz ( @{ $lglobal{fnlzs} } ) {
        if ( $lglobal{fnarray}->[ $lglobal{fnindex} ][0] ) {
            while (
                $textwindow->compare(
                    $lglobal{fnarray}->[ $lglobal{fnindex} ][0],
                    '<=', $lz
                )
                )
            {
                $footnotes{$lz} .= "\n\n"
                    . $textwindow->get( "fns$lglobal{fnindex}",
                    "fne$lglobal{fnindex}" );
                $lglobal{fnindex}++;
                last if $lglobal{fnindex} > $lglobal{fntotal};
            }
        }
    }
    $lglobal{fnindex} = $lglobal{fntotal};
    while ( $lglobal{fnindex} ) {
        $textwindow->delete("fne$lglobal{fnindex} +1c")
            if ( $textwindow->get("fne$lglobal{fnindex} +1c") eq "\n" );
        $textwindow->delete("fns$lglobal{fnindex} -1c")
            if ( $textwindow->get("fns$lglobal{fnindex} -1c") eq "\n" );
        $textwindow->delete( "fns$lglobal{fnindex}", "fne$lglobal{fnindex}" );
        $lglobal{fnindex}--;
    }
    $zone = 0;
    foreach $lz ( @{ $lglobal{fnlzs} } ) {
        $textwindow->insert( $textwindow->index("LZ$zone +10c"),
            $footnotes{$lz} )
            if $footnotes{$lz};
        $footnotes{$lz} = '';
        $zone++;
    }
    $zone = 1;
    while ( $lglobal{fnarray}->[$zone][4] ) {
        my $fna = $textwindow->index("fna$zone");
        my $fnb = $textwindow->index("fnb$zone");
        if ( $textwindow->get( "$fna -1c", $fna ) eq ' ' ) {
            $textwindow->delete( "$fna -1c", $fna );
            $fna = $textwindow->index("fna$zone -1c");
            $fnb = $textwindow->index("fnb$zone -1c");
            $textwindow->markSet( "fna$zone", $fna );
            $textwindow->markSet( "fnb$zone", $fnb );
        }
        ( $r, $c ) = split /\./, $fna;
        while ( $c eq '0' ) {
            $marker = $textwindow->get( $fna, $fnb );
            $textwindow->delete( $fna, $fnb );
            $r--;
            $textwindow->insert( "$r.end", $marker );
            ( $r, $c ) = split /\./, ( $textwindow->index("$r.end") );
        }
        $zone++;
    }
    @{ $lglobal{fnlzs} }   = ();
    @{ $lglobal{fnarray} } = ();
    $index            = '1.0';
    $lglobal{fnindex} = 0;
    $lglobal{fntotal} = 0;
    while (1) {
        $index = $textwindow->search( '-regex', '--', 'FOOTNOTES:', $index,
            'end' );
        last unless ($index);
        unless ( $textwindow->get("$index +2l") =~ /^\[/ ) {
            $textwindow->delete( $index, "$index+12c" );
        }
        $index .= '+4l';
    }
    $textwindow->markSet( 'insert', '1.0' );
    $textwindow->see('1.0');
}

sub getlz {
    my $index = '1.0';
    my $zone  = 0;
    $lglobal{fnlzs} = ();
    my @marks = grep( /^LZ/, $textwindow->markNames );
    for my $mark (@marks) {
        $textwindow->markUnset($mark);
    }
    while (1) {
        $index = $textwindow->search( '-regex', '--', '^FOOTNOTES:$', $index,
            'end' );
        last unless $index;
        push @{ $lglobal{fnlzs} }, $index;
        $textwindow->markSet( "LZ$zone", $index );
        $index = $textwindow->index("$index +10c");
        $zone++;
    }
}

sub autochaptlz {
    $lglobal{zoneindex} = 0;
    $lglobal{fnlzs}     = ();
    my $char;
    while (1) {
        $char = $textwindow->get('end-2c');
        last if ( $char =~ /\S/ );
        $textwindow->delete('end-2c');
        $textwindow->update;
    }
    $textwindow->insert( 'end', "\n\n" );
    my $index = '200.0';
    while (1) {
        $index = $textwindow->search( '-regex', '--', '^$', $index, 'end' );
        last unless ($index);
        last if ( $index < '100.0' );
        if ( ( $textwindow->index("$index+1l") ) eq
               ( $textwindow->index("$index+1c") )
            && ( $textwindow->index("$index+2l") ) eq
            ( $textwindow->index("$index+2c") )
            && ( $textwindow->index("$index+3l") ) eq
            ( $textwindow->index("$index+3c") ) )
        {
            $textwindow->markSet( 'insert', "$index+1l" );
            setlz();
            $index .= '+4l';
        }
        else {
            $index .= '+1l';
            next;
        }
    }
    $textwindow->see('1.0');
}

sub autoendlz {
    $textwindow->markSet( 'insert', 'end -1c' );
    setlz();
}

sub setlz {
    $textwindow->insert( 'insert', "FOOTNOTES:\n\n" );
    $lglobal{fnmvbutton}->configure( '-state' => 'normal' )
        if ( ( $lglobal{fnsecondpass} ) && ( $lglobal{footstyle} eq 'end' ) );
}

sub setanchor {
    my ( $index, $insert );
    $insert = $textwindow->index('insert');
    if ( $lglobal{fnarray}->[ $lglobal{fnindex} ][0] ne
        $lglobal{fnarray}->[ $lglobal{fnindex} ][2] )
    {
        $textwindow->delete(
            $lglobal{fnarray}->[ $lglobal{fnindex} ][2],
            $lglobal{fnarray}->[ $lglobal{fnindex} ][3]
        ) if $lglobal{fnarray}->[ $lglobal{fnindex} ][3];
    }
    else {
        $lglobal{fnarray}->[ $lglobal{fnindex} ][2] = $insert;
    }
    footnoteadjust();
    if ( $lglobal{footstyle} eq 'inline' ) {
        $index = $textwindow->search( ':', "fns$lglobal{fnindex}",
            "fne$lglobal{fnindex}" );
        $textwindow->delete( "fns$lglobal{fnindex}+9c", $index ) if $index;
        footnoteadjust();
        my $fn = $textwindow->get(
            $textwindow->index( 'fns' . $lglobal{fnindex} ),
            $textwindow->index( 'fne' . $lglobal{fnindex} )
        );
        $textwindow->insert( $textwindow->index("fna$lglobal{fnindex}"), $fn )
            if $textwindow->compare(
            $textwindow->index("fna$lglobal{fnindex}"),
            '>', $textwindow->index("fns$lglobal{fnindex}") );
        $textwindow->delete(
            $textwindow->index("fns$lglobal{fnindex}"),
            $textwindow->index("fne$lglobal{fnindex}")
        );
        $textwindow->insert( $textwindow->index("fna$lglobal{fnindex}"), $fn )
            if $textwindow->compare(
            $textwindow->index("fna$lglobal{fnindex}"),
            '<=', $textwindow->index("fns$lglobal{fnindex}") );
        $lglobal{fnarray}->[ $lglobal{fnindex} ][0]
            = $textwindow->index( 'fns' . $lglobal{fnindex} );
        $lglobal{fnarray}->[ $lglobal{fnindex} ][4] = '';
        $lglobal{fnarray}->[ $lglobal{fnindex} ][3] = '';
        $lglobal{fnarray}->[ $lglobal{fnindex} ][6] = '';
        footnoteadjust();
    }
    else {
        $lglobal{fnarray}->[ $lglobal{fnindex} ][2] = $insert;
        if ($textwindow->compare(
                $lglobal{fnarray}->[ $lglobal{fnindex} ][2],
                '>',
                $lglobal{fnarray}->[ $lglobal{fnindex} ][0]
            )
            )
        {
            $lglobal{fnarray}->[ $lglobal{fnindex} ][2]
                = $lglobal{fnarray}->[ $lglobal{fnindex} ][0];
        }
        $textwindow->insert(
            $lglobal{fnarray}->[ $lglobal{fnindex} ][2],
            '[' . $lglobal{fnarray}->[ $lglobal{fnindex} ][4] . ']'
        );
        $textwindow->update;
        $lglobal{fnarray}->[ $lglobal{fnindex} ][3]
            = $textwindow->index(
            $lglobal{fnarray}->[ $lglobal{fnindex} ][2] . '+'
                . (
                length( $lglobal{fnarray}->[ $lglobal{fnindex} ][4] ) + 2 )
                . 'c' );
        $textwindow->markSet( "fna$lglobal{fnindex}",
            $lglobal{fnarray}->[ $lglobal{fnindex} ][2] );
        $textwindow->markSet( "fnb$lglobal{fnindex}",
            $lglobal{fnarray}->[ $lglobal{fnindex} ][3] );
        footnoteadjust();
        footnoteshow();
    }
}

# @{$lglobal{fnarray}} is an array of arrays
#
# $lglobal{fnarray}->[$lglobal{fnindex}][0] = starting index of footnote.
# $lglobal{fnarray}->[$lglobal{fnindex}][1] = ending index of footnote.
# $lglobal{fnarray}->[$lglobal{fnindex}][2] = index of footnote anchor.
# $lglobal{fnarray}->[$lglobal{fnindex}][3] = index of footnote anchor end.
# $lglobal{fnarray}->[$lglobal{fnindex}][4] = anchor label.
# $lglobal{fnarray}->[$lglobal{fnindex}][5] = anchor type n a r (numeric, alphabet, roman)
# $lglobal{fnarray}->[$lglobal{fnindex}][6] = type index

sub footnotefixup {
    viewpagenums() if ( $lglobal{seepagenums} );
    my ( $start, $end, $anchor, $pointer );
    $start            = 1;
    $lglobal{fncount} = '1';
    $lglobal{fnalpha} = '1';
    $lglobal{fnroman} = '1';
    $lglobal{fnindexbrowse}->delete( '0', 'end' ) if $lglobal{footpop};
    $lglobal{footnotenumber}->configure( -text => $lglobal{fncount} )
        if $lglobal{footpop};
    $lglobal{footnoteletter}->configure( -text => alpha( $lglobal{fnalpha} ) )
        if $lglobal{footpop};
    $lglobal{footnoteroman}->configure( -text => roman( $lglobal{fnroman} ) )
        if $lglobal{footpop};
    $lglobal{ftnoteindexstart} = '1.0';
    $textwindow->markSet( 'fnindex', $lglobal{ftnoteindexstart} );
    $lglobal{fntotal} = 0;
    $textwindow->tagRemove( 'footnote',  '1.0', 'end' );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );

    while (1) {
        $lglobal{ftnoteindexstart}
            = $textwindow->search( '-exact', '--', '[ Footnote', '1.0',
            'end' );
        last unless $lglobal{ftnoteindexstart};
        $textwindow->delete(
            "$lglobal{ftnoteindexstart}+1c",
            "$lglobal{ftnoteindexstart}+2c"
        );
    }
    while (1) {
        $lglobal{ftnoteindexstart}
            = $textwindow->search( '-exact', '--', '{Footnote', '1.0',
            'end' );
        last unless $lglobal{ftnoteindexstart};
        $textwindow->delete( $lglobal{ftnoteindexstart},
            "$lglobal{ftnoteindexstart}+1c" );
        $textwindow->insert( $lglobal{ftnoteindexstart}, '[' );
    }
    while (1) {
        $lglobal{ftnoteindexstart}
            = $textwindow->search( '-exact', '--', '[Fotonote', '1.0',
            'end' );
        last unless $lglobal{ftnoteindexstart};
        $textwindow->delete(
            "$lglobal{ftnoteindexstart}+1c",
            "$lglobal{ftnoteindexstart}+9c"
        );
        $textwindow->insert( "$lglobal{ftnoteindexstart}+1c", 'Footnote' );
    }
    while (1) {
        $lglobal{ftnoteindexstart}
            = $textwindow->search( '-exact', '--', '[Footnoto', '1.0',
            'end' );
        last unless $lglobal{ftnoteindexstart};
        $textwindow->delete(
            "$lglobal{ftnoteindexstart}+1c",
            "$lglobal{ftnoteindexstart}+9c"
        );
        $textwindow->insert( "$lglobal{ftnoteindexstart}+1c", 'Footnote' );
    }
    while (1) {
        $lglobal{ftnoteindexstart}
            = $textwindow->search( '-exact', '--', '[footnote', '1.0',
            'end' );
        last unless $lglobal{ftnoteindexstart};
        $textwindow->delete(
            "$lglobal{ftnoteindexstart}+1c",
            "$lglobal{ftnoteindexstart}+2c"
        );
        $textwindow->insert( "$lglobal{ftnoteindexstart}+1c", 'F' );
    }
    $lglobal{ftnoteindexstart} = '1.0';
    while (1) {
        ( $start, $end ) = footnotefind();
        last unless $start;
        $lglobal{fntotal}++;
        $lglobal{fnindex} = $lglobal{fntotal};
        ( $start, $end ) = (
            $textwindow->index("fns$lglobal{fnindex}"),
            $textwindow->index("fne$lglobal{fnindex}")
        ) if $lglobal{fnsecondpass};
        $pointer = '';
        $anchor  = '';
        $textwindow->yview('end');
        $textwindow->see($start) if $start;
        $textwindow->tagAdd( 'footnote', $start, $end );
        $textwindow->markSet( 'insert', $start );
        $lglobal{fnindexbrowse}->insert( 'end', $lglobal{fnindex} )
            if $lglobal{footpop};
        $lglobal{footnotetotal}
            ->configure( -text => "# $lglobal{fnindex}/$lglobal{fntotal}" )
            if $lglobal{footpop};
        $pointer = $textwindow->get( $start,
            ( $textwindow->search( '--', ':', $start, "$start lineend" ) ) );
        $pointer =~ s/\[Footnote\s*//i;
        $pointer =~ s/\s*:$//;

        if ( length($pointer) > 20 ) {
            $pointer = '';
            $textwindow->insert( "$start+9c", ':' );
        }
        if ( $lglobal{fnsearchlimit} ) {
            $anchor
                = $textwindow->search( '-backwards', '--', "[$pointer]",
                $start, '1.0' )
                if $pointer;
        }
        else {
            $anchor
                = $textwindow->search( '-backwards', '--', "[$pointer]",
                $start, "$start-80l" )
                if $pointer;
        }
        $textwindow->tagAdd( 'highlight', $anchor,
            $anchor . '+' . ( length($pointer) + 2 ) . 'c' )
            if $anchor;
        $lglobal{fnarray}->[ $lglobal{fnindex} ][0] = $start if $start;
        $lglobal{fnarray}->[ $lglobal{fnindex} ][1] = $end   if $end;
        $lglobal{fnarray}->[ $lglobal{fnindex} ][2] = $start
            unless ( $pointer && $anchor );
        $lglobal{fnarray}->[ $lglobal{fnindex} ][2] = $anchor if $anchor;
        $lglobal{fnarray}->[ $lglobal{fnindex} ][3] = $start
            unless ( $pointer && $anchor );
        $lglobal{fnarray}->[ $lglobal{fnindex} ][3]
            = $textwindow->index(
                  $lglobal{fnarray}->[ $lglobal{fnindex} ][2] . '+'
                . ( length($pointer) + 2 )
                . 'c' )
            if $anchor;
        $lglobal{fnarray}->[ $lglobal{fnindex} ][4] = $pointer if $pointer;

        if ($pointer) {
            $lglobal{fnarray}->[ $lglobal{fnindex} ][5] = 'n';
            if ( $pointer =~ /\p{IsAlpha}+/ ) {
                $lglobal{fnarray}->[ $lglobal{fnindex} ][5] = 'a';
                $lglobal{fnarray}->[ $lglobal{fnindex} ][4] = uc($pointer);
            }
            if ( $pointer =~ /[ivxlcdm]+\./i ) {
                $lglobal{fnarray}->[ $lglobal{fnindex} ][5] = 'r';
                $lglobal{fnarray}->[ $lglobal{fnindex} ][4] = uc($pointer);
            }
        }
        else {
            $lglobal{fnarray}->[ $lglobal{fnindex} ][5] = '';
        }
        $textwindow->markSet( "fns$lglobal{fnindex}", $start );
        $textwindow->markSet( "fne$lglobal{fnindex}", $end );
        $textwindow->markSet( "fna$lglobal{fnindex}",
            $lglobal{fnarray}->[ $lglobal{fnindex} ][2] );
        $textwindow->markSet( "fnb$lglobal{fnindex}",
            $lglobal{fnarray}->[ $lglobal{fnindex} ][3] );
        update_indicators();
        $textwindow->focus;
        $lglobal{footpop}->raise if $lglobal{footpop};

        if ( $lglobal{fnsecondpass} ) {
            if ( $lglobal{footstyle} eq 'end' ) {
                $lglobal{fnsearchlimit} = 1;
                fninsertmarkers('n')
                    if (
                       ( $lglobal{fnarray}->[ $lglobal{fnindex} ][5] eq 'n' )
                    || ( $lglobal{fnarray}->[ $lglobal{fnindex} ][5] eq '' )
                    || ( $lglobal{fntypen} ) );
                fninsertmarkers('a')
                    if (
                       ( $lglobal{fnarray}->[ $lglobal{fnindex} ][5] eq 'a' )
                    || ( $lglobal{fntypea} ) );
                fninsertmarkers('r')
                    if (
                       ( $lglobal{fnarray}->[ $lglobal{fnindex} ][5] eq 'r' )
                    || ( $lglobal{fntyper} ) );
                $lglobal{fnmvbutton}->configure( '-state' => 'normal' )
                    if ( defined $lglobal{fnlzs} and @{ $lglobal{fnlzs} } );
            }
            else {
                $textwindow->markSet( 'insert', 'fna' . $lglobal{fnindex} );
                $lglobal{fnarray}->[ $lglobal{fnindex} ][4] = '';
                setanchor();
            }
        }
    }
    $lglobal{fnindex}      = 1;
    $lglobal{fnsecondpass} = 1;
    $lglobal{fnfpbutton}->configure( '-state' => 'normal' )
        if $lglobal{footpop};
    footnoteshow();
}

sub footnoteshow {
    if ( $lglobal{fnindex} < 1 ) {
        $lglobal{fnindex} = 1;
        return;
    }
    if ( $lglobal{fnindex} > $lglobal{fntotal} ) {
        $lglobal{fnindex} = $lglobal{fntotal};
        return;
    }
    $textwindow->tagRemove( 'footnote',  '1.0', 'end' );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    footnoteadjust();
    my $start     = $textwindow->index("fns$lglobal{fnindex}");
    my $end       = $textwindow->index("fne$lglobal{fnindex}");
    my $anchor    = $textwindow->index("fna$lglobal{fnindex}");
    my $anchorend = $textwindow->index("fnb$lglobal{fnindex}");
    my $line      = $textwindow->index('end -1l');
    $textwindow->yview('end');

    if ( $lglobal{fncenter} ) {
        $textwindow->see($start) if $start;
    }
    else {
        my $widget = $textwindow->{rtext};
        my ( $lx, $ly, $lw, $lh ) = $widget->dlineinfo($line);
        my $bottom = int(
            (         $widget->height 
                    - 2 * $widget->cget( -bd )
                    - 2 * $widget->cget( -highlightthickness )
            ) / $lh / 2
        ) - 1;
        $textwindow->see("$end-${bottom}l") if $start;
    }
    $textwindow->tagAdd( 'footnote', $start, $end ) if $start;
    $textwindow->markSet( 'insert', $start ) if $start;
    $textwindow->tagAdd( 'highlight', $anchor, $anchorend )
        if ( ( $anchor ne $start ) && $anchorend );
    $lglobal{footnotetotal}
        ->configure( -text => "# $lglobal{fnindex}/$lglobal{fntotal}" )
        if $lglobal{footpop};
    update_indicators();
}

sub fninsertmarkers {
    my $style  = shift;
    my $offset = $textwindow->search(
        '--', ':',
        $lglobal{fnarray}->[ $lglobal{fnindex} ][0],
        $lglobal{fnarray}->[ $lglobal{fnindex} ][1]
    );
    if ( $lglobal{footstyle} eq 'end' ) {
        $textwindow->delete(
            $lglobal{fnarray}->[ $lglobal{fnindex} ][0] . '+9c', $offset )
            if $offset;
        if ( $lglobal{fnarray}->[ $lglobal{fnindex} ][3] ne
            $lglobal{fnarray}->[ $lglobal{fnindex} ][2] )
        {
            $textwindow->delete(
                $lglobal{fnarray}->[ $lglobal{fnindex} ][2],
                $lglobal{fnarray}->[ $lglobal{fnindex} ][3]
            );
        }
        $lglobal{fnarray}->[ $lglobal{fnindex} ][6] = $lglobal{fncount}
            if $style eq 'n';
        $lglobal{fnarray}->[ $lglobal{fnindex} ][6] = $lglobal{fnalpha}
            if $style eq 'a';
        $lglobal{fnarray}->[ $lglobal{fnindex} ][6] = $lglobal{fnroman}
            if $style eq 'r';
        $lglobal{fnarray}->[ $lglobal{fnindex} ][5] = $style;
        $lglobal{fnarray}->[ $lglobal{fnindex} ][4] = $lglobal{fncount}
            if $style eq 'n';
        $lglobal{fnarray}->[ $lglobal{fnindex} ][4]
            = alpha( $lglobal{fnalpha} )
            if $style eq 'a';
        $lglobal{fnarray}->[ $lglobal{fnindex} ][4]
            = roman( $lglobal{fnroman} )
            if $style eq 'r';
        $lglobal{fncount}++ if $style eq 'n';
        $lglobal{fnalpha}++ if $style eq 'a';
        $lglobal{fnroman}++ if $style eq 'r';
        footnoteadjust();
        $textwindow->insert(
            $lglobal{fnarray}->[ $lglobal{fnindex} ][0] . '+9c',
            ' ' . $lglobal{fnarray}->[ $lglobal{fnindex} ][4]
        );
        $textwindow->insert(
            $lglobal{fnarray}->[ $lglobal{fnindex} ][2],
            '[' . $lglobal{fnarray}->[ $lglobal{fnindex} ][4] . ']'
        );
        $lglobal{fnarray}->[ $lglobal{fnindex} ][3]
            = $textwindow->index(
            $lglobal{fnarray}->[ $lglobal{fnindex} ][2] . ' +'
                . (
                length( $lglobal{fnarray}->[ $lglobal{fnindex} ][4] ) + 2 )
                . 'c' );
        $textwindow->markSet( "fna$lglobal{fnindex}",
            $lglobal{fnarray}->[ $lglobal{fnindex} ][2] );
        $textwindow->markSet( "fnb$lglobal{fnindex}",
            $lglobal{fnarray}->[ $lglobal{fnindex} ][3] );
        footnoteadjust();
        $lglobal{footnotenumber}->configure( -text => $lglobal{fncount} );
    }
}

sub fnjoin {
    $textwindow->tagRemove( 'footnote',  '1.0', 'end' );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    my $start = $textwindow->search(
        '--', ':',
        $lglobal{fnarray}->[ $lglobal{fnindex} ][0],
        $lglobal{fnarray}->[ $lglobal{fnindex} ][1]
    );
    my $end = $lglobal{fnarray}->[ $lglobal{fnindex} ][1] . '-1c';
    $textwindow->delete( $lglobal{fnarray}->[ $lglobal{fnindex} - 1 ][1] )
        if (
        $textwindow->get( $lglobal{fnarray}->[ $lglobal{fnindex} - 1 ][1] ) eq
        '*' );
    $textwindow->insert(
        $lglobal{fnarray}->[ $lglobal{fnindex} - 1 ][1] . '-1c',
        "\n" . $textwindow->get( "$start+2c", $end )
    );
    footnoteadjust();
    $textwindow->delete( "fns$lglobal{fnindex}",    "fne$lglobal{fnindex}" );
    $textwindow->delete( "fna$lglobal{fnindex}",    "fnb$lglobal{fnindex}" );
    $textwindow->delete( "fns$lglobal{fnindex}-1c", "fns$lglobal{fnindex}" )
        if ( $textwindow->get("fns$lglobal{fnindex}-1c") eq '*' );
    $lglobal{fnarray}->[ $lglobal{fnindex} ][0] = '';
    $lglobal{fnarray}->[ $lglobal{fnindex} ][1] = '';
    footnoteadjust();
    $lglobal{fncount}-- if $lglobal{fnarray}->[ $lglobal{fnindex} ][5] eq 'n';
    $lglobal{fnalpha}-- if $lglobal{fnarray}->[ $lglobal{fnindex} ][5] eq 'a';
    $lglobal{fnroman}-- if $lglobal{fnarray}->[ $lglobal{fnindex} ][5] eq 'r';
    $lglobal{fnindex}--;
    footnoteshow();
}

sub footnoteadjust {
    my $end      = $lglobal{fnarray}->[ $lglobal{fnindex} ][1];
    my $start    = $lglobal{fnarray}->[ $lglobal{fnindex} ][0];
    my $tempsave = $lglobal{ftnoteindexstart};
    my $label;
    unless ( $start and $lglobal{fnindex} ) {
        $tempsave = $lglobal{fnindex};
        $lglobal{fnarray}->[ $lglobal{fnindex} ] = ();
        my $type = $lglobal{fnarray}->[ $lglobal{fnindex} ][5];
        $lglobal{fncount}-- if $type and $type eq 'n';
        $lglobal{fnalpha}-- if $type and $type eq 'a';
        $lglobal{fnroman}-- if $type and $type eq 'r';
        while ( $lglobal{fnarray}->[ $lglobal{fnindex} + 1 ][0] ) {
            $lglobal{fnarray}->[ $lglobal{fnindex} ][0]
                = $textwindow->index( 'fns' . ( $lglobal{fnindex} + 1 ) );
            $textwindow->markSet( "fns$lglobal{fnindex}",
                $lglobal{fnarray}->[ $lglobal{fnindex} ][0] );
            $lglobal{fnarray}->[ $lglobal{fnindex} ][1]
                = $textwindow->index( 'fne' . ( $lglobal{fnindex} + 1 ) );
            $textwindow->markSet( "fne$lglobal{fnindex}",
                $lglobal{fnarray}->[ $lglobal{fnindex} ][1] );
            $lglobal{fnarray}->[ $lglobal{fnindex} ][2]
                = $textwindow->index( 'fna' . ( $lglobal{fnindex} + 1 ) );
            $textwindow->markSet( "fna$lglobal{fnindex}",
                $lglobal{fnarray}->[ $lglobal{fnindex} ][2] );
            $lglobal{fnarray}->[ $lglobal{fnindex} ][3] = '';
            $lglobal{fnarray}->[ $lglobal{fnindex} ][3]
                = $textwindow->index( 'fnb' . ( $lglobal{fnindex} + 1 ) )
                if $lglobal{fnarray}->[ $lglobal{fnindex} + 1 ][3];
            $textwindow->markSet( "fnb$lglobal{fnindex}",
                $lglobal{fnarray}->[ $lglobal{fnindex} ][3] )
                if $lglobal{fnarray}->[ $lglobal{fnindex} + 1 ][3];
            $lglobal{fnarray}->[ $lglobal{fnindex} ][4]
                = $lglobal{fnarray}->[ $lglobal{fnindex} + 1 ][4];
            $lglobal{fnarray}->[ $lglobal{fnindex} ][5]
                = $lglobal{fnarray}->[ $lglobal{fnindex} + 1 ][5];
            $lglobal{fnarray}->[ $lglobal{fnindex} ][6]
                = $lglobal{fnarray}->[ $lglobal{fnindex} + 1 ][6];
            $lglobal{fnindex}++;
        }
        $lglobal{footnotenumber}->configure( -text => $lglobal{fncount} );
        $lglobal{footnoteletter}
            ->configure( -text => alpha( $lglobal{fnalpha} ) );
        $lglobal{footnoteroman}
            ->configure( -text => roman( $lglobal{fnroman} ) );
        $lglobal{fnarray}->[ $lglobal{fnindex} ] = ();
        $lglobal{fnindex} = $tempsave;
        $lglobal{fntotal}--;
        $lglobal{footnotetotal}
            ->configure( -text => "# $lglobal{fnindex}/$lglobal{fntotal}" );
        return;
    }
    $textwindow->tagRemove( 'footnote', $start, $end );
    if ( $lglobal{fnindex} > 1 ) {
        $lglobal{ftnoteindexstart}
            = $lglobal{fnarray}->[ $lglobal{fnindex} - 1 ][1];
        $textwindow->markSet( 'fnindex', $lglobal{ftnoteindexstart} );
    }
    else {
        $lglobal{ftnoteindexstart} = '1.0';
        $textwindow->markSet( 'fnindex', $lglobal{ftnoteindexstart} );
    }

    #print "\n$start|$end|$lglobal{fnindex}, $lglobal{ftnoteindexstart}\n";
    ( $start, $end ) = footnotefind();
    $textwindow->markSet( "fns$lglobal{fnindex}", $start );
    $textwindow->markSet( "fne$lglobal{fnindex}", $end );
    $lglobal{ftnoteindexstart} = $tempsave;
    $textwindow->markSet( 'fnindex', $lglobal{ftnoteindexstart} );
    $textwindow->tagAdd( 'footnote', $start, $end );
    $textwindow->markSet( 'insert', $start );
    $lglobal{footnotenumber}->configure( -text => $lglobal{fncount} )
        if $lglobal{footpop};
    $lglobal{footnoteletter}->configure( -text => alpha( $lglobal{fnalpha} ) )
        if $lglobal{footpop};
    $lglobal{footnoteroman}->configure( -text => roman( $lglobal{fnroman} ) )
        if $lglobal{footpop};

    if ( $end eq "$start+10c" ) {
        $textwindow->bell unless $nobell;
        return;
    }
    $lglobal{fnarray}->[ $lglobal{fnindex} ][0] = $start if $start;
    $lglobal{fnarray}->[ $lglobal{fnindex} ][1] = $end   if $end;
    $textwindow->focus;
    $lglobal{footpop}->raise if $lglobal{footpop};
    return ( $start, $end );
}

sub footnotefind {
    my ( $bracketndx, $nextbracketndx, $bracketstartndx, $bracketendndx );
    $lglobal{ftnoteindexstart} = $textwindow->index('fnindex');
    $bracketstartndx
        = $textwindow->search( '-regexp', '--', '\[[Ff][Oo][Oo][Tt]',
        $lglobal{ftnoteindexstart}, 'end' );
    return ( 0, 0 ) unless $bracketstartndx;
    $bracketndx = "$bracketstartndx+1c";
    while (1) {
        $bracketendndx = $textwindow->search( '--', ']', $bracketndx, 'end' );
        $bracketendndx = $textwindow->index("$bracketstartndx+9c")
            unless $bracketendndx;
        $bracketendndx = $textwindow->index("$bracketendndx+1c")
            if $bracketendndx;
        $nextbracketndx
            = $textwindow->search( '--', '[', $bracketndx, 'end' );
        if ( ($nextbracketndx)
            && ($textwindow->compare( $nextbracketndx, '<', $bracketendndx ) )
            )
        {
            $bracketndx = $bracketendndx;
            next;
        }
        last;
    }
    $lglobal{ftnoteindexstart} = "$bracketstartndx+10c";
    $textwindow->markSet( 'fnindex', $lglobal{ftnoteindexstart} );
    return ( $bracketstartndx, $bracketendndx );
}

sub alpha {
    my $label = shift;
    $label--;
    my ( $single, $double, $triple );
    $single = $label % 26;
    $double = ( int( $label / 26 ) % 26 );
    $triple = ( $label - $single - ( $double * 26 ) % 26 );
    $single = chr( 65 + $single );
    $double = chr( 65 + $double - 1 );
    $triple = chr( 65 + $triple - 1 );
    $double = '' if ( $label < 26 );
    $triple = '' if ( $label < 676 );
    return ( $triple . $double . $single );
}

# Roman numeral conversion taken directly from the Roman.pm module Copyright
# (c) 1995 OZAWA Sakuro. Done to avoid users having to install downloadable
# modules.
sub roman {
    my %roman_digit = qw(1 IV 10 XL 100 CD 1000 MMMMMM);
    my @figure      = reverse sort keys %roman_digit;
    grep( $roman_digit{$_} = [ split( //, $roman_digit{$_}, 2 ) ], @figure );
    my $arg = shift;
    return undef
        unless defined $arg;
    0 < $arg and $arg < 4000 or return undef;
    my ( $x, $roman );
    foreach (@figure) {
        my ( $digit, $i, $v ) = ( int( $arg / $_ ), @{ $roman_digit{$_} } );
        if ( 1 <= $digit and $digit <= 3 ) {
            $roman .= $i x $digit;
        }
        elsif ( $digit == 4 ) {
            $roman .= "$i$v";
        }
        elsif ( $digit == 5 ) { $roman .= $v; }
        elsif ( 6 <= $digit
            and $digit <= 8 )
        {
            $roman .= $v . $i x ( $digit - 5 );
        }
        elsif ( $digit == 9 ) { $roman .= "$i$x"; }
        $arg -= $digit * $_;
        $x = $i;
    }
    return "$roman.";
}

sub arabic {
    my $arg = shift;
    return $arg
        unless $arg =~ /^(?: M{0,3})
                (?: D?C{0,3} | C[DM])
                (?: L?X{0,3} | X[LC])
                (?: V?I{0,3} | I[VX])\.?$/ix;
    $arg =~ s/\.$//;
    my %roman2arabic = qw(I 1 V 5 X 10 L 50 C 100 D 500 M 1000);
    my $last_digit   = 1000;
    my $arabic;
    foreach ( split( //, uc $arg ) ) {
        $arabic -= 2 * $last_digit if $last_digit < $roman2arabic{$_};
        $arabic += ( $last_digit = $roman2arabic{$_} );
    }
    return $arabic;
}

sub add_search_history {
    my ( $widget, $history_array_ref ) = @_;
    my @temparray = @$history_array_ref;
    @$history_array_ref = ();
    my $term = $widget->get( '1.0', '1.end' );
    push @$history_array_ref, $term;
    for (@temparray) {
        next if $_ eq $term;
        push @$history_array_ref, $_;
        last if @$history_array_ref >= $history_size;
    }
}

sub search_history {
    my ( $widget, $history_array_ref ) = @_;
    my $menu = $widget->Menu( -title => 'History', -tearoff => 0 );
    $menu->command(
        -label   => 'Clear History',
        -command => sub { @$history_array_ref = (); saveset(); },
    );
    $menu->separator;
    for my $item (@$history_array_ref) {
        $menu->command(
            -label   => $item,
            -command => [ sub { load_hist_term( $widget, $_[0] ) }, $item ],
        );
    }
    my $x = $widget->rootx;
    my $y = $widget->rooty + $widget->height;
    $menu->post( $x, $y );
}

sub load_hist_term {
    my ( $widget, $term ) = @_;
    $widget->delete( '1.0', 'end' );
    $widget->insert( 'end', $term );
}

sub reg_check {
    $lglobal{searchentry}->tagConfigure( 'reg', -foreground => 'black' );
    $lglobal{searchentry}->tagRemove( 'reg', '1.0', 'end' );
    return unless $sopt[3];
    $lglobal{searchentry}->tagAdd( 'reg', '1.0', 'end' );
    my $term = $lglobal{searchentry}->get( '1.0', 'end' );
    return if ( $term eq '^' or $term eq '$' );
    return if isvalid($term);
    $lglobal{searchentry}->tagConfigure( 'reg', -foreground => 'red' );
    return;
}

sub regedit {
    my $editor = $top->DialogBox(
        -title   => 'Regex editor',
        -buttons => [ 'Save', 'Cancel' ]
    );
    my $regsearchlabel
        = $editor->add( 'Label', -text => 'Search Term' )->pack;
    $lglobal{regsearch} = $editor->add(
        'Text',
        -background => 'white',
        -width      => 40,
        -height     => 1,
    )->pack;
    my $regreplacelabel
        = $editor->add( 'Label', -text => 'Replacement Term' )->pack;
    $lglobal{regsearch} = $editor->add(
        'Text',
        -background => 'white',
        -width      => 40,
        -height     => 1,
    )->pack;
    my $reghintlabel = $editor->add( 'Label', -text => 'Hint Text' )->pack;
    $lglobal{reghinted} = $editor->add(
        'Text',
        -background => 'white',
        -width      => 40,
        -height     => 8,
        -wrap       => 'word',
    )->pack;
    my $buttonframe = $editor->add('Frame')->pack;
    $buttonframe->Button(
        -activebackground => $activecolor,
        -text             => '<--',
        -command          => sub {
            $lglobal{scannosindex}-- if $lglobal{scannosindex};
            regload();
        },
    )->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
    $buttonframe->Button(
        -activebackground => $activecolor,
        -text             => '-->',
        -command          => sub {
            $lglobal{scannosindex}++
                if $lglobal{scannosarray}[ $lglobal{scannosindex} ];
            regload();
        },
    )->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
    $buttonframe->Button(
        -activebackground => $activecolor,
        -text             => 'Add',
        -command          => \&regadd,
    )->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
    $buttonframe->Button(
        -activebackground => $activecolor,
        -text             => 'Del',
        -command          => \&regdel,
    )->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
    $lglobal{regsearch}
        ->insert( 'end', ( $lglobal{searchentry}->get( '1.0', '1.end' ) ) )
        if $lglobal{searchentry}->get( '1.0', '1.end' );
    $lglobal{regsearch}
        ->insert( 'end', ( $lglobal{replaceentry}->get( '1.0', '1.end' ) ) )
        if $lglobal{replaceentry}->get( '1.0', '1.end' );
    $lglobal{reghinted}->insert( 'end',
        ( $reghints{ $lglobal{searchentry}->get( '1.0', '1.end' ) } ) )
        if $reghints{ $lglobal{searchentry}->get( '1.0', '1.end' ) };
    my $button = $editor->Show;
    if ( $button =~ /save/i ) {
        open REG, ">$lglobal{scannosfilename}";
        print REG "\%scannoslist = (\n";
        foreach my $word ( sort ( keys %scannoslist ) ) {
            my $srch = $word;
            $srch =~ s/'/\\'/;
            my $repl = $scannoslist{$word};
            $repl =~ s/'/\\'/;
            print REG "'$srch' => '$repl',\n";
        }
        print REG ");\n\n";
        print
            REG # FIXME: here doc or just stuff in a text file and suck that out.
            '# For a hint, use the regex expression EXACTLY as it appears in the %scannoslist hash'
            . "\n";
        print REG
            '# but replace the replacement term (heh) with the hint text. Note: if a single quote'
            . "\n";
        print REG
            '# appears anywhere in the hint text, you\'ll need to escape it with a backslash. I.E. isn\\\'t'
            . "\n";
        print REG
            '# I could have made this more compact by converting the scannoslist hash into a two dimensional'
            . "\n";
        print REG '# hash, but would have sacrificed backward compatibility.'
            . "\n\n";
        print REG '%reghints = (' . "\n";

        foreach my $word ( sort ( keys %reghints ) ) {
            my $srch = $word;
            $srch =~ s/'/\\'/;
            my $repl = $reghints{$word};
            $repl =~ s/([\\'])/\\$1/;
            print REG "'$srch' => '$repl'\n";
        }
        print REG ");\n\n";
        close REG;
    }
}

sub regload {
    my $word = '';
    $word = $lglobal{scannosarray}[ $lglobal{scannosindex} ];
    $lglobal{regsearch}->delete( '1.0', 'end' );
    $lglobal{regsearch}->delete( '1.0', 'end' );
    $lglobal{reghinted}->delete( '1.0', 'end' );
    $lglobal{regsearch}->insert( 'end', $word ) if defined $word;
    $lglobal{regsearch}->insert( 'end', $scannoslist{$word} )
        if defined $word;
    $lglobal{reghinted}->insert( 'end', $reghints{$word} ) if defined $word;
}

sub regadd {
    my $st = $lglobal{regsearch}->get( '1.0', '1.end' );
    unless ( isvalid($st) ) {
        badreg();
        return;
    }
    my $rt = $lglobal{regsearch}->get( '1.0', '1.end' );
    my $rh = $lglobal{reghinted}->get( '1.0', 'end' );
    $rh =~ s/(?!<\\)'/\\'/;
    $rh =~ s/\n/ /;
    $rh =~ s/  / /;
    $rh =~ s/\s+$//;
    $reghints{$st} = $rh;

    unless ( defined $scannoslist{$st} ) {
        $scannoslist{$st} = $rt;
        $lglobal{scannosindex} = 0;
        @{ $lglobal{scannosarray} } = ();
        foreach ( sort ( keys %scannoslist ) ) {
            push @{ $lglobal{scannosarray} }, $_;
        }
        foreach ( @{ $lglobal{scannosarray} } ) {
            $lglobal{scannosindex}++ unless ( $_ eq $st );
            next unless ( $_ eq $st );
            last;
        }
    }
    else {
        $scannoslist{$st} = $rt;
    }
    regload();
}

sub regdel {
    my $word = '';
    my $st = $lglobal{regsearch}->get( '1.0', '1.end' );
    delete $reghints{$st};
    delete $scannoslist{$st};
    $lglobal{scannosindex}--;
    @{ $lglobal{scannosarray} } = ();
    foreach $word ( sort ( keys %scannoslist ) ) {
        push @{ $lglobal{scannosarray} }, $word;
    }
    regload();
}

sub reghint {
    my $message = 'No hints for this entry.';
    my $reg = $lglobal{searchentry}->get( '1.0', '1.end' );
    if ( $reghints{$reg} ) { $message = $reghints{$reg} }
    if ( defined( $lglobal{hintpop} ) ) {
        $lglobal{hintpop}->deiconify;
        $lglobal{hintpop}->raise;
        $lglobal{hintpop}->focus;
        $lglobal{hintmessage}->delete( '1.0', 'end' );
        $lglobal{hintmessage}->insert( 'end', $message );
    }
    else {
        $lglobal{hintpop} = $lglobal{search}->Toplevel;
        $lglobal{hintpop}->title('Search Term Hint');
        my $frame = $lglobal{hintpop}->Frame->pack(
            -anchor => 'nw',
            -expand => 'yes',
            -fill   => 'both'
        );
        $lglobal{hintmessage} = $frame->ROText(
            -width      => 40,
            -height     => 6,
            -background => 'white',
            -wrap       => 'word',
            )->pack(
            -anchor => 'nw',
            -expand => 'yes',
            -fill   => 'both',
            -padx   => 4,
            -pady   => 4
            );
        $lglobal{hintmessage}->insert( 'end', $message );
    }
    $lglobal{hintpop}->protocol( 'WM_DELETE_WINDOW' =>
            sub { $lglobal{hintpop}->destroy; undef $lglobal{hintpop} } );
    $lglobal{hintpop}->Icon( -image => $icon );
}

sub loadscannos {
    $lglobal{scannosfilename} = '';
    %scannoslist = ();
    @{ $lglobal{scannosarray} } = ();
    $lglobal{scannosindex} = 0;
    my $types = [ [ 'Scannos', ['.rc'] ], [ 'All Files', ['*'] ], ];
    $scannospath = os_normal($scannospath);
    $lglobal{scannosfilename} = $top->getOpenFile(
        -filetypes  => $types,
        -title      => 'Scannos list?',
        -initialdir => $scannospath
    );
    if ( $lglobal{scannosfilename} ) {
        my ( $name, $path, $extension )
            = fileparse( $lglobal{scannosfilename}, '\.[^\.]*$' );
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
                }
                else {
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
        }
        else {
            searchoptset(qw/x x x 0/);
        }
        return 1;
    }
}

sub getnextscanno {
    findascanno();
    unless ( searchtext() ) {
        if ( $lglobal{regaa} ) {
            while (1) {
                last
                    if ( $lglobal{scannosindex}++
                    >= $#{ $lglobal{scannosarray} } );
                findascanno();
                last if searchtext();
            }
        }
    }
}

sub findascanno {
    $searchendindex = '1.0';
    my $word = '';
    $word = $lglobal{scannosarray}[ $lglobal{scannosindex} ];
    $lglobal{searchentry}->delete( '1.0', 'end' );
    $lglobal{replaceentry}->delete( '1.0', 'end' );
    $textwindow->bell unless ( $word || $nobell || $lglobal{regaa} );
    $lglobal{searchbutton}->flash unless ( $word || $lglobal{regaa} );
    $lglobal{regtracker}
        ->configure( -text => ( $lglobal{scannosindex} + 1 ) . '/'
            . scalar( @{ $lglobal{scannosarray} } ) );
    $lglobal{hintmessage}->delete( '1.0', 'end' )
        if ( defined( $lglobal{hintpop} ) );
    return 0 unless $word;
    $lglobal{searchentry}->insert( 'end', $word );
    $lglobal{replaceentry}->insert( 'end', ( $scannoslist{$word} ) );
    $sopt[2]
        ? $textwindow->markSet( 'insert', 'end' )
        : $textwindow->markSet( 'insert', '1.0' );
    reghint() if ( defined( $lglobal{hintpop} ) );
    $textwindow->update;
    return 1;
}

sub swapterms {
    my $tempholder = $lglobal{replaceentry}->get( '1.0', '1.end' );
    $lglobal{replaceentry}->delete( '1.0', 'end' );
    $lglobal{replaceentry}
        ->insert( 'end', $lglobal{searchentry}->get( '1.0', '1.end' ) );
    $lglobal{searchentry}->delete( '1.0', 'end' );
    $lglobal{searchentry}->insert( 'end', $tempholder );
    searchtext();
}

sub isvalid {
    my $term = shift;
    return eval { '' =~ m/$term/; 1 } || 0;
}

sub badreg {
    my $warning = $top->Dialog(
        -text =>
            "Invalid Regex search term.\nDo you have mismatched\nbrackets or parenthesis?",
        -title   => 'Invalid Regex',
        -bitmap  => 'warning',
        -buttons => ['Ok'],
    );
    $warning->Show;
}

sub clearmarks {
    @{ $lglobal{nlmatches} } = ();
    my ( $mark, $mindex );
    $mark = $textwindow->markNext($searchendindex);
    while ($mark) {
        if ( $mark =~ /nls\d+q(\d+)/ ) {
            $mindex = $textwindow->index($mark);
            $textwindow->markUnset($mark);
            $mark = $mindex;
        }
        $mark = $textwindow->markNext($mark) if $mark;
    }
}

sub searchtext {
    viewpagenums() if ( $lglobal{seepagenums} );

# $sopt[0] --> 0 = pattern search                       1 = whole word search
# $sopt[1] --> 0 = case insensitive                     1 = case sensitive search
# $sopt[2] --> 0 = search forwards                      1 = search backwards
# $sopt[3] --> 0 = normal search term           1 = regex search term - 3 and 0 are mutually exclusive
# $sopt[4] --> 0 = search from last index       1 = Start from beginning
    $lglobal{lastsearchterm} = 'stupid variable needs to be initialized'
        unless length( $lglobal{lastsearchterm} );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' ) if $searchstartindex;
    my ( $start, $end );
    my $foundone    = 1;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    $searchstartindex = $textwindow->index('insert') unless $searchstartindex;

    if ( $range_total == 0 && $lglobal{selectionsearch} ) {
        $start = $textwindow->index('insert');
        $end   = $lglobal{selectionsearch};
    }
    elsif ( $range_total == 0 && !$lglobal{selectionsearch} ) {
        $start = $textwindow->index('insert');
        $end   = 'end';
        $end   = '1.0' if ( $sopt[2] );
    }
    else {
        $end                      = pop(@ranges);
        $start                    = pop(@ranges);
        $lglobal{selectionsearch} = $end;
    }
    if ( $sopt[4] ) {
        if ( $sopt[2] ) {
            $start = 'end';
            $end   = '1.0';
        }
        else {
            $start = '1.0';
            $end   = 'end';
        }
        $lglobal{searchop4}->deselect if ( defined $lglobal{search} );
    }
    my $searchterm = shift;
    $searchterm = '' unless defined $searchterm;
    if ($start) {
        $sopt[2]
            ? ( $searchstartindex = $start )
            : ( $searchendindex = "$start+1c" );
    }
    {

       # Turn off warnings temporarily since $searchterm is undefined on first
       # search
        no warnings;
        unless ( length($searchterm) ) {
            $searchterm = $lglobal{searchentry}->get( '1.0', '1.end' );
        }
    }
    return ('') unless length($searchterm);
    if ( $sopt[3] ) {
        unless ( isvalid($searchterm) ) {
            badreg();
            return;
        }
    }
    unless ( $searchterm eq $lglobal{lastsearchterm} ) {
        ( $range_total == 0 )
            ? ( $searchendindex = '1.0' )
            : ( $searchendindex = $start );
        if ( $sopt[2] ) {
            ( $range_total == 0 )
                ? ( $searchstartindex = 'end' )
                : ( $searchstartindex = $end );
        }
        $lglobal{lastsearchterm} = $searchterm
            unless ( ( $searchterm =~ m/\\n/ ) && ( $sopt[3] ) );
        clearmarks() if ( ( $searchterm =~ m/\\n/ ) && ( $sopt[3] ) );
    }
    $textwindow->tagRemove( 'sel', '1.0', 'end' );
    my $length = '0';
    my ($tempindex);
    if ( ( $searchterm =~ m/\\n/ ) && ( $sopt[3] ) ) {
        unless ( $searchterm eq $lglobal{lastsearchterm} ) {
            {
                $top->Busy;
                my $wholefile = $textwindow->get( '1.0', $end );
                while ( $wholefile =~ m/$searchterm/smg ) {
                    push @{ $lglobal{nlmatches} },
                        [ $-[0], ( $+[0] - $-[0] ) ];
                }
                $top->Unbusy;
            }
            my $matchidx = 0;
            my $lineidx  = 1;
            my $matchacc = 0;
            foreach my $match ( @{ $lglobal{nlmatches} } ) {
                while (1) {
                    my $linelen
                        = length(
                        $textwindow->get( "$lineidx.0", "$lineidx.end" ) )
                        + 1;
                    last if ( ( $matchacc + $linelen ) > $match->[0] );
                    $matchacc += $linelen;
                    $lineidx++;
                }
                $matchidx++;
                my $offset = $match->[0] - $matchacc;
                $textwindow->markSet( "nls${matchidx}q" . $match->[1],
                    "$lineidx.$offset" );
            }
            $lglobal{lastsearchterm} = $searchterm;
        }
        my $mark;
        if ( $sopt[2] ) {
            $mark = getmark($searchstartindex);
        }
        else {
            $mark = getmark($searchendindex);
        }
        while ($mark) {
            if ( $mark =~ /nls\d+q(\d+)/ ) {
                $length           = $1;
                $searchstartindex = $textwindow->index($mark);
                last;
            }
            else {
                $mark = getmark($mark) if $mark;
                next;
            }
        }

        #print "$searchstartindex\n";
        $searchstartindex = 0 unless $mark;
        $lglobal{lastsearchterm} = 'reset' unless $mark;
    }
    else {
        my $exactsearch = $searchterm;
        $exactsearch =~ s/([\{\}\[\]\(\)\^\$\.\|\*\+\?\\])/\\$1/g
            ;    # escape metacharacters for whole word matching
        $searchterm = '(?<!\p{Alnum})' . $exactsearch . '(?!\p{Alnum})'
            if $sopt[0];
        my ( $direction, $searchstart, $mode );
        if   ( $sopt[2] ) { $searchstart = $searchstartindex }
        else              { $searchstart = $searchendindex }
        if   ( $sopt[2] ) { $direction = '-backwards' }
        else              { $direction = '-forwards' }
        if   ( $sopt[0] or $sopt[3] ) { $mode = '-regexp' }
        else                          { $mode = '-exact' }

        if ( $sopt[1] ) {
            $searchstartindex = $textwindow->search(
                $mode, $direction, '-nocase',
                '-count' => \$length,
                '--', $searchterm, $searchstart, $end
            );
        }
        else {
            $searchstartindex = $textwindow->search(
                $mode, $direction,
                '-count' => \$length,
                '--', $searchterm, $searchstart, $end
            );
        }
    }
    if ($searchstartindex) {
        $tempindex = $searchstartindex;
        my ( $row, $col ) = split /\./, $tempindex;
        $col += $length;
        $searchendindex = "$row.$col" if $length;
        $searchendindex = $textwindow->index("$searchstartindex +${length}c")
            if ( $searchterm =~ m/\\n/ );
        $searchendindex = $textwindow->index("$searchstartindex +1c")
            unless $length;
        $textwindow->markSet( 'insert', $searchstartindex )
            if $searchstartindex;    # position the cursor at the index
        $textwindow->tagAdd( 'highlight', $searchstartindex, $searchendindex )
            if $searchstartindex;    # highlight the text
        $textwindow->yviewMoveto(1);
        $textwindow->see($searchstartindex)
            if ( $searchendindex && $sopt[2] )
            ;    # scroll text box, if necessary, to make found text visible
        $textwindow->see($searchendindex) if ( $searchendindex && !$sopt[2] );
        $searchendindex = $searchstartindex unless $length;
    }
    unless ($searchstartindex) {
        $foundone = 0;
        unless ( $lglobal{selectionsearch} ) { $start = '1.0'; $end = 'end' }
        if ( $sopt[2] ) {
            $searchstartindex = $end;
            $textwindow->markSet( 'insert', $searchstartindex );
            $textwindow->see($searchendindex);
        }
        else {
            $searchendindex = $start;
            $textwindow->markSet( 'insert', $start );
            $textwindow->see($start);
        }
        $lglobal{selectionsearch} = 0;
        unless ( $lglobal{regaa} ) {
            $textwindow->bell unless $nobell;
            $lglobal{searchbutton}->flash if defined $lglobal{search};
            $lglobal{searchbutton}->flash if defined $lglobal{search};
        }
    }
    updatesearchlabels();
    update_indicators();
    return $foundone;    # return index of where found text started
}

sub getmark {
    my $start = shift;
    if ( $sopt[2] ) {    # search reverse
        return $textwindow->markPrevious($start);
    }
    else {               # search forward
        return $textwindow->markNext($start);
    }
}

sub updatesearchlabels {
    if ( $lglobal{seen} && $lglobal{search} ) {
        my $replaceterm = $lglobal{replaceentry}->get( '1.0', '1.end' );
        my $searchterm1 = $lglobal{searchentry}->get( '1.0', '1.end' );
        if ( ( $lglobal{seen}->{$searchterm1} ) && ( $sopt[0] ) ) {
            $lglobal{searchnumlabel}->configure(
                -text => "Found $lglobal{seen}->{$searchterm1} times." );
        }
        elsif ( ( $searchterm1 eq '' ) || ( !$sopt[0] ) ) {
            $lglobal{searchnumlabel}->configure( -text => '' );
        }
        else {
            $lglobal{searchnumlabel}->configure( -text => 'Not Found.' );
        }
    }
}

sub replace {
    viewpagenums() if ( $lglobal{seepagenums} );
    my $replaceterm = shift;
    $replaceterm = '' unless length $replaceterm;
    return unless $searchstartindex;
    my $searchterm = $lglobal{searchentry}->get( '1.0', '1.end' );
    $replaceterm = replaceeval( $searchterm, $replaceterm ) if ( $sopt[3] );
    if ($searchstartindex) {
        $textwindow->replacewith( $searchstartindex, $searchendindex,
            $replaceterm );
    }
    return 1;
}

sub replaceeval {
    my ( $searchterm, $replaceterm ) = @_;
    my @replarray = ();
    my ( $replaceseg, $seg1, $seg2, $replbuild );
    my ( $m1, $m2, $m3, $m4, $m5, $m6, $m7, $m8 );
    my $found = $textwindow->get( $searchstartindex, $searchendindex );
    $searchterm =~ s/\Q(?<=\E.*?\)//;
    $searchterm =~ s/\Q(?=\E.*?\)//;
    $found      =~ m/$searchterm/m;
    $m1 = $1;
    $m2 = $2;
    $m3 = $3;
    $m4 = $4;
    $m5 = $5;
    $m6 = $6;
    $m7 = $7;
    $m8 = $8;
    $replaceterm =~ s/(?<!\\)\$1/$m1/g if defined $m1;
    $replaceterm =~ s/(?<!\\)\$2/$m2/g if defined $m2;
    $replaceterm =~ s/(?<!\\)\$3/$m3/g if defined $m3;
    $replaceterm =~ s/(?<!\\)\$4/$m4/g if defined $m4;
    $replaceterm =~ s/(?<!\\)\$5/$m5/g if defined $m5;
    $replaceterm =~ s/(?<!\\)\$6/$m6/g if defined $m6;
    $replaceterm =~ s/(?<!\\)\$7/$m7/g if defined $m7;
    $replaceterm =~ s/(?<!\\)\$8/$m8/g if defined $m8;
    $replaceterm =~ s/\\\$/\$/g;

    if ( $replaceterm =~ /\\C/ ) {
        if ( $lglobal{codewarn} ) {
            my $dialog = $top->Dialog(
                -text =>
                    "WARNING!! The replacement term will execute arbitrary perl code. "
                    . "If you do not want to, or are not sure of what you are doing, cancel the operation.\n\n"
                    . "It is unlikely that there is a problem. However, it is possible (and not terribly difficult) "
                    . "to construct an expression that would delete files, execute arbitrary malicious code, "
                    . "reformat hard drives, etc.\n\n"
                    . "Do you want to proceed?",
                -bitmap  => 'warning',
                -title   => 'WARNING! Code in term.',
                -buttons => [ 'OK', 'Warnings Off', 'Cancel' ],
            );
            my $answer = $dialog->Show;
            $lglobal{codewarn} = 0 if ( $answer eq 'Warnings Off' );
            return $replaceterm
                unless ( ( $answer eq 'OK' )
                || ( $answer eq 'Warnings Off' ) );
        }
        $replbuild = '';
        if ( $replaceterm =~ s/^\\C// ) {
            if ( $replaceterm =~ s/\\C// ) {
                @replarray = split /\\C/, $replaceterm;
            }
            else {
                push @replarray, $replaceterm;
            }
        }
        else {
            @replarray = split /\\C/, $replaceterm;
            $replbuild = shift @replarray;
        }
        while ( $replaceseg = shift @replarray ) {
            $seg1 = $seg2 = '';
            ( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
            $replbuild .= eval $seg1;
            $replbuild .= $seg2 if $seg2;
        }
        $replaceterm = $replbuild;
        $replbuild   = '';
    }
    if ( $replaceterm =~ /\\L/ ) {
        if ( $replaceterm =~ s/^\\L// ) {
            if ( $replaceterm =~ s/\\L// ) {
                @replarray = split /\\L/, $replaceterm;
            }
            else {
                push @replarray, $replaceterm;
            }
        }
        else {
            @replarray = split /\\L/, $replaceterm;
            $replbuild = shift @replarray;
        }
        while ( $replaceseg = shift @replarray ) {
            $seg1 = $seg2 = '';
            ( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
            $replbuild .= lc($seg1);
            $replbuild .= $seg2 if $seg2;
        }
        $replaceterm = $replbuild;
        $replbuild   = '';
    }
    if ( $replaceterm =~ /\\U/ ) {
        if ( $replaceterm =~ s/^\\U// ) {
            if ( $replaceterm =~ s/\\U// ) {
                @replarray = split /\\U/, $replaceterm;
            }
            else {
                push @replarray, $replaceterm;
            }
        }
        else {
            @replarray = split /\\U/, $replaceterm;
            $replbuild = shift @replarray;
        }
        while ( $replaceseg = shift @replarray ) {
            $seg1 = $seg2 = '';
            ( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
            $replbuild .= uc($seg1);
            $replbuild .= $seg2 if $seg2;
        }
        $replaceterm = $replbuild;
        $replbuild   = '';
    }
    if ( $replaceterm =~ /\\T/ ) {
        if ( $replaceterm =~ s/^\\T// ) {
            if ( $replaceterm =~ s/\\T// ) {
                @replarray = split /\\T/, $replaceterm;
            }
            else {
                push @replarray, $replaceterm;
            }
        }
        else {
            @replarray = split /\\T/, $replaceterm;
            $replbuild = shift @replarray;
        }
        while ( $replaceseg = shift @replarray ) {
            $seg1 = $seg2 = '';
            ( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
            $seg1 = lc($seg1);
            $seg1 =~ s/(^\W*\w)/\U$1\E/;
            $seg1 =~ s/([\s\n]+\W*\w)/\U$1\E/g;
            $replbuild .= $seg1;
            $replbuild .= $seg2 if $seg2;
        }
        $replaceterm = $replbuild;
        $replbuild   = '';
    }
    $replaceterm =~ s/\\n/\n/g;
    $replaceterm =~ s/\\t/\t/g;
    if ( $replaceterm =~ /\\GA/ ) {
        if ( $replaceterm =~ s/^\\GA// ) {
            if ( $replaceterm =~ s/\\GA// ) {
                @replarray = split /\\GA/, $replaceterm;
            }
            else {
                push @replarray, $replaceterm;
            }
        }
        else {
            @replarray = split /\\GA/, $replaceterm;
            $replbuild = shift @replarray;
        }
        while ( $replaceseg = shift @replarray ) {
            $seg1 = $seg2 = '';
            ( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
            $replbuild .= betaascii($seg1);
            $replbuild .= $seg2 if $seg2;
        }
        $replaceterm = $replbuild;
        $replbuild   = '';
    }
    if ( $replaceterm =~ /\\GB/ ) {
        if ( $replaceterm =~ s/^\\GB// ) {
            if ( $replaceterm =~ s/\\GB// ) {
                @replarray = split /\\GB/, $replaceterm;
            }
            else {
                push @replarray, $replaceterm;
            }
        }
        else {
            @replarray = split /\\GB/, $replaceterm;
            $replbuild = shift @replarray;
        }
        while ( $replaceseg = shift @replarray ) {
            $seg1 = $seg2 = '';
            ( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
            $replbuild .= betagreek( 'beta', $seg1 );
            $replbuild .= $seg2 if $seg2;
        }
        $replaceterm = $replbuild;
        $replbuild   = '';
    }
    if ( $replaceterm =~ /\\G/ ) {
        if ( $replaceterm =~ s/^\\G// ) {
            if ( $replaceterm =~ s/\\G// ) {
                @replarray = split /\\G/, $replaceterm;
            }
            else {
                push @replarray, $replaceterm;
            }
        }
        else {
            @replarray = split /\\G/, $replaceterm;
            $replbuild = shift @replarray;
        }
        while ( $replaceseg = shift @replarray ) {
            $seg1 = $seg2 = '';
            ( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
            $replbuild .= betagreek( 'unicode', $seg1 );
            $replbuild .= $seg2 if $seg2;
        }
        $replaceterm = $replbuild;
        $replbuild   = '';
    }
    if ( $replaceterm =~ /\\A/ ) {
        if ( $replaceterm =~ s/^\\A// ) {
            if ( $replaceterm =~ s/\\A// ) {
                @replarray = split /\\A/, $replaceterm;
            }
            else {
                push @replarray, $replaceterm;
            }
        }
        else {
            @replarray = split /\\A/, $replaceterm;
            $replbuild = shift @replarray;
        }
        while ( $replaceseg = shift @replarray ) {
            $seg1 = $seg2 = '';
            ( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
            my $linkname;
            $linkname = makeanchor( deaccent($seg1) );
            $seg1     = "<a name=\"$linkname\" id=\"$linkname\"></a>";
            $replbuild .= $seg1;
            $replbuild .= $seg2 if $seg2;
        }
        $replaceterm = $replbuild;
    }
    return $replaceterm;
}

sub opstop {
    if ( defined( $lglobal{stoppop} ) ) {
        $lglobal{stoppop}->deiconify;
        $lglobal{stoppop}->raise;
        $lglobal{stoppop}->focus;
    }
    else {
        $lglobal{stoppop} = $top->Toplevel;
        $lglobal{stoppop}->title('Interrupt');
        my $frame      = $lglobal{stoppop}->Frame->pack;
        my $stopbutton = $frame->Button(
            -activebackground => $activecolor,
            -command          => sub { $operationinterrupt = 1 },
            -text             => 'Interrupt Operation',
            -width            => 16
        )->grid( -row => 1, -column => 1, -padx => 10, -pady => 10 );
        $lglobal{stoppop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{stoppop}->destroy; undef $lglobal{stoppop} } );
        $lglobal{stoppop}->Icon( -image => $icon );
    }
}

sub replaceall {
    my $replacement = shift;
    $replacement = '' unless $replacement;
    my @ranges = $textwindow->tagRanges('sel');
    if (@ranges) {
        $lglobal{lastsearchterm}
            = $lglobal{replaceentry}->get( '1.0', '1.end' );
        $searchstartindex = pop @ranges;
        $searchendindex   = pop @ranges;
    }
    else {
        $lglobal{lastsearchterm} = '';
    }
    $textwindow->focus;
    opstop();
    while ( searchtext() )
    {    # keep calling search() and replace() until you return undef
        last unless replace($replacement);
        last if $operationinterrupt;
        $textwindow->update;
    }
    $operationinterrupt = 0;
    $lglobal{stoppop}->destroy;
    undef $lglobal{stoppop};
}

sub orphans {
    viewpagenums() if ( $lglobal{seepagenums} );
    my $br = shift;
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    my ( $thisindex, $open, $close, $crow, $ccol, $orow, $ocol, @op );
    $open = '<' . $br . '>';
    $open = '<' . $br . '>|<' . $br . ' [^>]*>'
        if ( ( $br eq 'p' ) || ( $br eq 'span' ) );
    $close = '<\/' . $br . '>';
    my $end = $textwindow->index('end');
    $thisindex = '1.0';
    my ( $lengtho, $lengthc );
    my $opindex = $textwindow->search(
        '-regexp',
        '-count' => \$lengtho,
        '--', $open, $thisindex, 'end'
    );
    push @op, $opindex;
    my $clindex = $textwindow->search(
        '-regexp',
        '-count' => \$lengthc,
        '--', $close, $thisindex, 'end'
    );
    return unless ( $clindex || $opindex );
    push @op, ( $clindex || $end );

    while ($opindex) {
        $opindex = $textwindow->search(
            '-regexp',
            '-count' => \$lengtho,
            '--', $open, $op[0] . '+1c', 'end'
        );
        if ($opindex) {
            push @op, $opindex;
        }
        else {
            push @op, $textwindow->index('end');
        }
        my $begin = $op[1];
        $begin = 'end' unless $begin;
        $clindex = $textwindow->search(
            '-regexp',
            '-count' => \$lengthc,
            '--', $close, "$begin+1c", 'end'
        );
        if ($clindex) {
            push @op, $clindex;
        }
        else {
            push @op, $textwindow->index('end');
        }
        if ( $textwindow->compare( $op[1], '==', $op[3] ) ) {
            $textwindow->markSet( 'insert', $op[0] ) if $op[0];
            $textwindow->see( $op[0] ) if $op[0];
            $textwindow->tagAdd( 'highlight', $op[0],
                $op[0] . '+' . length($open) . 'c' );
            return 1;
        }
        if (   ( $textwindow->compare( $op[0], '<', $op[1] ) )
            && ( $textwindow->compare( $op[1], '<', $op[2] ) )
            && ( $textwindow->compare( $op[2], '<', $op[3] ) )
            && ( $op[2] ne $end )
            && ( $op[3] ne $end ) )
        {
            $textwindow->update;
            $textwindow->focus;
            shift @op;
            shift @op;
            next;
        }
        elsif (( $textwindow->compare( $op[0], '<', $op[1] ) )
            && ( $textwindow->compare( $op[1], '>', $op[2] ) ) )
        {
            $textwindow->markSet( 'insert', $op[2] ) if $op[2];
            $textwindow->see( $op[2] ) if $op[2];
            $textwindow->tagAdd( 'highlight', $op[2],
                $op[2] . ' +' . $lengtho . 'c' );
            $textwindow->tagAdd( 'highlight', $op[0],
                $op[0] . ' +' . $lengtho . 'c' );
            $textwindow->update;
            $textwindow->focus;
            return 1;
        }
        elsif (( $textwindow->compare( $op[0], '<', $op[1] ) )
            && ( $textwindow->compare( $op[2], '>', $op[3] ) ) )
        {
            $textwindow->markSet( 'insert', $op[3] ) if $op[3];
            $textwindow->see( $op[3] ) if $op[3];
            $textwindow->tagAdd( 'highlight', $op[3],
                $op[3] . '+' . $lengthc . 'c' );
            $textwindow->tagAdd( 'highlight', $op[1],
                $op[1] . '+' . $lengthc . 'c' );
            $textwindow->update;
            $textwindow->focus;
            return 1;
        }
        elsif (( $textwindow->compare( $op[0], '>', $op[1] ) )
            && ( $op[0] ne $end ) )
        {
            $textwindow->markSet( 'insert', $op[1] ) if $op[1];
            $textwindow->see( $op[1] ) if $op[1];
            $textwindow->tagAdd( 'highlight', $op[1],
                $op[1] . '+' . $lengthc . 'c' );
            $textwindow->tagAdd( 'highlight', $op[3],
                $op[3] . '+' . $lengtho . 'c' );
            $textwindow->update;
            $textwindow->focus;
            return 1;
        }
        else {
            if (   ( $op[3] eq $end )
                && ( $textwindow->compare( $op[2], '>', $op[0] ) ) )
            {
                $textwindow->markSet( 'insert', $op[2] ) if $op[2];
                $textwindow->see( $op[2] ) if $op[2];
                $textwindow->tagAdd( 'highlight', $op[2],
                    $op[2] . '+' . $lengthc . 'c' );
            }
            if (   ( $op[2] eq $end )
                && ( $textwindow->compare( $op[3], '>', $op[1] ) ) )
            {
                $textwindow->markSet( 'insert', $op[3] ) if $op[3];
                $textwindow->see( $op[3] ) if $op[3];
                $textwindow->tagAdd( 'highlight', $op[3],
                    $op[3] . '+' . $lengthc . 'c' );
            }
            if ( ( $op[1] eq $end ) && ( $op[2] eq $end ) ) {
                $textwindow->markSet( 'insert', $op[0] ) if $op[0];
                $textwindow->see( $op[0] ) if $op[0];
                $textwindow->tagAdd( 'highlight', $op[0],
                    $op[0] . '+' . $lengthc . 'c' );
            }
            update_indicators();
            return 0;
        }
    }
    return 0;
}

sub wrapper {
    my @words       = ();
    my $word        = '';
    my $line        = '';
    my $leftmargin  = shift;
    my $firstmargin = shift;
    my $rightmargin = shift;
    my $paragraph   = shift;
    $leftmargin--  if $leftmargin;
    $firstmargin-- if $firstmargin;
    $rightmargin++;
    $paragraph =~ s/-\n/-/g unless $rwhyphenspace;
    $paragraph =~ s/\n/ /g;
    return ("\n") unless ($paragraph);
    @words     = split /\s+/, $paragraph;
    $paragraph = '';
    $line      = ' ' x $firstmargin;

    while (@words) {
        $word = shift @words;
        next unless defined $word and length $word;
        if ( $word =~ /\/#/ ) {
            $firstmargin = $leftmargin = $blocklmargin;
            if ( $word =~ /^\x7f*\/#\x8A(\d+)/ )
            {    #check for block rewrapping with parameter markup
                if ( length $1 ) {
                    $leftmargin  = $1;
                    $firstmargin = $leftmargin;
                }
            }
            if ( $word =~ /^\x7f*\/#\x8A(\d+)?(\.)(\d+)/ ) {
                if ( length $3 ) { $firstmargin = $3 }
            }
            if ( $word =~ /^\x7f*\/#\x8A(\d+)?(\.)?(\d+)?,(\d+)/ ) {
                if ($4) { $rightmargin = $4 }
            }
            $line =~ s/\s$//;
            if ( $line =~ /\S/ ) {
                $paragraph .= $line . "\n" . $word . "\n";
            }
            else {
                $paragraph .= $word . "\n";
            }
            $line = ' ' x $firstmargin;
            next;
        }
        if ( $word =~ /#\// ) {
            $paragraph .= $line . "\n" if $line;
            $paragraph .= $word . "\n";
            $leftmargin = $lmargin - 1;
            $line       = '';
            next;
        }
        my $thisline = $line . $word;
        $thisline =~ s/<\/?[^>]+?>//g;    #ignore HTML markup when rewrapping
        if ( length($thisline) < $rightmargin ) {
            $line .= $word . ' ';
        }
        else {
            if ( $line =~ /\S/ ) {
                $line =~ s/\s$//;
                $paragraph .= $line . "\n";
                $line = ' ' x $leftmargin;
                $line .= $word . ' ';
            }
            else {
                $paragraph .= $line . $word . "\n";
                $line = ' ' x $leftmargin;
            }
        }
        unless ( scalar(@words) ) {
            $line =~ s/\s$//;
            $paragraph .= "$line\n";
            last;
        }
    }
    if ( $paragraph =~ /-[#\*]\// )
    {    # Trap bug when there is a hyphen at the end of a block
        $paragraph =~ s/\n(\S+)-([#\*]\/)/ $1-\n$2/;
    }
    return ($paragraph);
}

sub asciibox {
    my $marker      = shift(@_);
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    }
    else {
        my ( $linenum, $line, $sr, $sc, $er, $ec, $lspaces, $rspaces );
        my $end   = pop(@ranges);
        my $start = pop(@ranges);
        $textwindow->markSet( 'asciistart', $start );
        $textwindow->markSet( 'asciiend',   $end );
        my $saveleft  = $lmargin;
        my $saveright = $rmargin;
        $textwindow->addGlobStart;
        $lmargin = 0;
        $rmargin = ( $lglobal{asciiwidth} - 4 );
        &selectrewrap unless $lglobal{asciiwrap};
        $lmargin = $saveleft;
        $rmargin = $saveright;
        $textwindow->insert( 'asciistart',
                  ${ $lglobal{ascii} }[0]
                . ( ${ $lglobal{ascii} }[1] x ( $lglobal{asciiwidth} - 2 ) )
                . ${ $lglobal{ascii} }[2]
                . "\n" );
        $textwindow->insert( 'asciiend',
                  "\n"
                . ${ $lglobal{ascii} }[6]
                . ( ${ $lglobal{ascii} }[7] x ( $lglobal{asciiwidth} - 2 ) )
                . ${ $lglobal{ascii} }[8]
                . "\n" );
        $start = $textwindow->index('asciistart');
        $end   = $textwindow->index('asciiend');
        ( $sr, $sc ) = split /\./, $start;
        ( $er, $ec ) = split /\./, $end;

        for $linenum ( $sr .. $er - 2 ) {
            $line = $textwindow->get( "$linenum.0", "$linenum.end" );
            $line =~ s/^\s*//;
            $line =~ s/\s*$//;
            if ( $lglobal{asciijustify} eq 'left' ) {
                $lspaces = 1;
                $rspaces = ( $lglobal{asciiwidth} - 3 ) - length($line);
            }
            elsif ( $lglobal{asciijustify} eq 'center' ) {
                $lspaces = ( $lglobal{asciiwidth} - 2 ) - length($line);
                if ( $lspaces % 2 ) {
                    $rspaces = ( $lspaces / 2 ) + .5;
                    $lspaces = $rspaces - 1;
                }
                else {
                    $rspaces = $lspaces / 2;
                    $lspaces = $rspaces;
                }
            }
            elsif ( $lglobal{asciijustify} eq 'right' ) {
                $rspaces = 1;
                $lspaces = ( $lglobal{asciiwidth} - 3 ) - length($line);
            }
            $line
                = ${ $lglobal{ascii} }[3]
                . ( ' ' x $lspaces )
                . $line
                . ( ' ' x $rspaces )
                . ${ $lglobal{ascii} }[5];
            $textwindow->delete( "$linenum.0", "$linenum.end" );
            $textwindow->insert( "$linenum.0", $line );
        }
        $textwindow->addGlobEnd;
    }
}

sub aligntext {
    my $marker      = shift(@_);
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    }
    else {
        my $textindex = 0;
        my ( $linenum, $line, $sr, $sc, $er, $ec, $r, $c, @indexpos );
        my $end   = pop(@ranges);
        my $start = pop(@ranges);
        $textwindow->addGlobStart;
        ( $sr, $sc ) = split /\./, $start;
        ( $er, $ec ) = split /\./, $end;
        for $linenum ( $sr .. $er - 1 ) {
            $indexpos[$linenum]
                = $textwindow->search( '--', $lglobal{alignstring},
                "$linenum.0 -1c",
                "$linenum.end" );
            if ( $indexpos[$linenum] ) {
                ( $r, $c ) = split /\./, $indexpos[$linenum];
            }
            else {
                $c = -1;
            }
            if ( $c > $textindex ) { $textindex = $c }
            $indexpos[$linenum] = $c;
        }
        for $linenum ( $sr .. $er ) {
            if ( $indexpos[$linenum] > (-1) ) {
                $textwindow->insert( "$linenum.0",
                    ( ' ' x ( $textindex - $indexpos[$linenum] ) ) );
            }
        }
        $textwindow->addGlobEnd;
    }
}

sub floodfill {
    my @ranges = $textwindow->tagRanges('sel');
    return unless @ranges;
    $lglobal{ffchar} = ' ' unless length $lglobal{ffchar};
    $textwindow->addGlobStart;
    while (@ranges) {
        my $end       = pop(@ranges);
        my $start     = pop(@ranges);
        my $selection = $textwindow->get( $start, $end );
        my $temp      = substr(
            $lglobal{ffchar} x (
                ( ( length $selection ) / ( length $lglobal{ffchar} ) ) + 1
            ),
            0,
            ( length $selection )
        );
        chomp $selection;
        my @temparray = split( /\n/, $selection );
        my $replacement;
        for (@temparray) {
            $replacement .= substr( $temp, 0, ( length $_ ), '' );
            $replacement .= "\n";
        }
        chomp $replacement;
        $textwindow->replacewith( $start, $end, $replacement );
    }
    $textwindow->addGlobEnd;

}

sub surroundit {
    my ( $pre, $post ) = @_;
    $pre  =~ s/\\n/\n/;
    $post =~ s/\\n/\n/;
    my @ranges = $textwindow->tagRanges('sel');
    unless (@ranges) {
        push @ranges, $textwindow->index('insert');
        push @ranges, $textwindow->index('insert');
    }
    $textwindow->addGlobStart;
    while (@ranges) {
        my $end   = pop(@ranges);
        my $start = pop(@ranges);
        $textwindow->replacewith( $start, $end,
            $pre . $textwindow->get( $start, $end ) . $post );
    }
    $textwindow->addGlobEnd;
}

sub poetryhtml {
    viewpagenums() if ( $lglobal{seepagenums} );
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    }
    else {
        my $end   = pop(@ranges);
        my $start = pop(@ranges);
        my ( $lsr, $lsc, $ler, $lec, $step, $ital );
        ( $lsr, $lsc ) = split /\./, $start;
        ( $ler, $lec ) = split /\./, $end;
        $step = $lsr;
        my $selection = $textwindow->get( "$lsr.0", "$lsr.end" );
        $selection =~ s/&nbsp;/ /g;
        $selection =~ s/^(\s+)//;
        my $indent = length($1) if $1;
        my $class = '';
        $class = ( " class=\"i" . ( $indent - 4 ) . '"' ) if ( $indent - 4 );

        if ( length $selection ) {
            $selection = "<span$class>" . $selection . '<br /></span>';
        }
        else {
            $selection = '';
        }
        $textwindow->delete( "$lsr.0", "$lsr.end" );
        $textwindow->insert( "$lsr.0", $selection );
        $step++;
        while ( $step <= $ler ) {
            $selection = $textwindow->get( "$step.0", "$step.end" );
            if ( $selection =~ /^$/ ) {
                $textwindow->insert( "$step.0",
                    '</div><div class="stanza">' );
                while (1) {
                    $step++;
                    $selection = $textwindow->get( "$step.0", "$step.end" );
                    last if ( $step ge $ler );
                    next if ( $selection =~ /^$/ );
                    last;
                }
            }
            $selection =~ s/&nbsp;/ /g;
            $selection =~ s/^(\s+)//;
            $indent = length($1) if $1;
            $textwindow->delete( "$step.0", "$step.$indent" ) if $indent;
            $indent -= 4;
            $indent = 0 if ( $indent < 0 );
            $selection =~ s/^(\s*)//;
            $selection =~ /(<i>)/g;
            my $op = $-[-1];
            $selection =~ s/^(\s*)//;
            $selection =~ /(<\/i>)/g;
            my $cl = $-[-1];

            if ( !$cl && $ital ) {
                $textwindow->ntinsert( "$step.0 lineend", '</i>' );
            }
            if ( !$op && $ital ) {
                $textwindow->ntinsert( "$step.0", '<i>' );
            }
            if ( $op && ( $cl < $op ) && !$ital ) {
                $textwindow->ntinsert( "$step.end", '</i>' );
                $ital = 1;
            }
            if ( $op && $cl && ( $cl < $op ) && $ital ) {
                $textwindow->ntinsert( "$step.0", '<i>' );
                $ital = 0;
            }
            if ( ( $op < $cl ) && $ital ) {
                $textwindow->ntinsert( "$step.0", '<i>' );
                $ital = 0;
            }
            if ($indent) {
                $textwindow->insert( "$step.0", "<span class=\"i$indent\">" );
            }
            else {
                $textwindow->insert( "$step.0", '<span>' );
            }
            $textwindow->insert( "$step.end", '<br /></span>' );
            $step++;
        }
        $selection = "\n</div></div>";
        $textwindow->insert( "$ler.end", $selection );
        $textwindow->insert( "$lsr.0",
            "<div class=\"poem\"><div class=\"stanza\">\n" );
    }
}

sub autotable {
    viewpagenums() if ( $lglobal{seepagenums} );
    my $format = shift;
    my @cformat;
    if ($format) {
        @cformat = split( //, $format );
    }
    my @ranges = $textwindow->tagRanges('sel');
    unless (@ranges) {
        push @ranges, $textwindow->index('insert');
        push @ranges, $textwindow->index('insert');
    }
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    }
    else {
        my $table = 1;
        my $end   = pop(@ranges);
        my $start = pop(@ranges);
        my ( @tbl, @trows, @tlines, @twords );
        my $row = 0;
        my $selection = $textwindow->get( $start, $end );
        $selection =~ s/<br.*?>//g;
        $selection =~ s/<\/?p>//g;
        $selection =~ s/\n[\s|]+\n/\n\n/g;
        $selection =~ s/^\n+//;
        $selection =~ s/\n\n+/\x{8A}/g if $lglobal{tbl_multiline};
        @trows = split( /\x{8A}/, $selection ) if $lglobal{tbl_multiline};
        $selection =~ s/\n[\s|]*\n/\n/g unless $lglobal{tbl_multiline};
        @trows = split( /\n/, $selection ) unless $lglobal{tbl_multiline};

        for my $trow (@trows) {
            @tlines = split( /\n/, $trow );
            for my $tline (@tlines) {
                if ( $selection =~ /\|/ ) {
                    @twords = split( /\|/, $tline );
                }
                else {
                    @twords = split( /\s\s+/, $tline );
                }
                for ( 0 .. $#twords ) {
                    $tbl[$row][$_] .= "$twords[$_] ";
                }
            }
            $row++;
        }
        $selection = '';
        for my $row ( 0 .. $#tbl ) {
            $selection .= '<tr>';
            for ( $tbl[$row] ) {
                my $cellcnt = 0;
                my $cellalign;
                while (@$_) {
                    if ( $cformat[$cellcnt] ) {
                        if ( $cformat[$cellcnt] eq '>' ) {
                            $cellalign = ' align="right"';
                        }
                        elsif ( $cformat[$cellcnt] eq '|' ) {
                            $cellalign = ' align="center"';
                        }
                        else {
                            $cellalign = ' align="left"';
                        }
                    }
                    else {
                        $cellalign = $lglobal{tablecellalign};
                    }
                    ++$cellcnt;
                    $selection .= '<td' . $cellalign . '>';
                    $selection .= shift @$_;
                    $selection .= '</td>';
                }
            }
            $selection .= "</tr>\n";
        }
        $selection .= '</table></div>';
        $selection =~ s/<td[^>]+><\/td>//g;
        $selection =~ s/ +<\//<\//g;
        $selection =~ s/d> +/d>/g;
        $selection =~ s/ +/ /g;
        $textwindow->delete( $start, $end );
        $textwindow->insert( $start, $selection );
        $textwindow->insert( $start,
                  "\n<div class=\"center\">\n"
                . '<table border="0" cellpadding="4" cellspacing="0" summary="">'
                . "\n" )
            if $table;
        $table = 1;
    }
}

sub autolist {
    viewpagenums() if ( $lglobal{seepagenums} );
    my @ranges = $textwindow->tagRanges('sel');
    unless (@ranges) {
        push @ranges, $textwindow->index('insert');
        push @ranges, $textwindow->index('insert');
    }
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    }
    else {
        $textwindow->addGlobStart;
        my $end       = pop(@ranges);
        my $start     = pop(@ranges);
        my $paragraph = 0;
        if ( $lglobal{list_multiline} ) {
            my $selection = $textwindow->get( $start, $end );
            $selection =~ s/\n +/\n/g;
            $selection =~ s/\n\n+/\x{8A}/g;
            my @lrows = split( /\x{8A}/, $selection );
            for (@lrows) {
                $_ = '<li>' . $_ . "</li>\n\n";
            }
            $selection = "<$lglobal{liststyle}>\n";
            for my $lrow (@lrows) {
                $selection .= $lrow;
            }
            $selection =~ s/\n$//;
            $selection .= '</' . $lglobal{liststyle} . ">\n";
            $selection =~ s/ </</g;
            $textwindow->delete( $start, $end );
            $textwindow->insert( $start, $selection );
        }
        else {
            my ( $lsr, $lsc ) = split /\./, $start;
            my ( $ler, $lec ) = split /\./, $end;
            my $step = $lsr;
            $step++
                while ( $textwindow->get( "$step.0", "$step.end" ) eq '' );
            while ( $step <= $ler ) {
                my $selection = $textwindow->get( "$step.0", "$step.end" );
                unless ($selection) { $step++; next }
                if ( $selection =~ s/<br.*?>//g ) {
                    $selection = '<li>' . $selection . '</li>';
                }
                if ( $selection =~ s/<p>/<li>/g )     { $paragraph = 1 }
                if ( $selection =~ s/<\/p>/<\/li>/g ) { $paragraph = 0 }
                $textwindow->delete( "$step.0", "$step.end" );
                unless ($paragraph) {
                    unless ( $selection =~ /<li>/ ) {
                        $selection = '<li>' . $selection . '</li>';
                    }
                }
                $selection =~ s/<li><\/li>//;
                $textwindow->insert( "$step.0", $selection );
                $step++;
            }
            $textwindow->insert( "$ler.end", "</$lglobal{liststyle}>\n" );
            $textwindow->insert( $start,     "<$lglobal{liststyle}>" );
        }
        $textwindow->addGlobEnd;
    }
}

sub markup {
    viewpagenums() if ( $lglobal{seepagenums} );
    saveset();
    my $mark   = shift;
    my $mark1  = shift if @_;
    my @ranges = $textwindow->tagRanges('sel');
    unless (@ranges) {
        push @ranges, $textwindow->index('insert');
        push @ranges, $textwindow->index('insert');
    }
    my $range_total = @ranges;
    my $done        = '';
    my $open        = 0;
    my $close       = 0;
    my @intanchors;
    if ( $range_total == 0 ) {
        return;
    }
    else {
        my $end            = pop(@ranges);
        my $start          = pop(@ranges);
        my $thisblockstart = $start;
        my $thisblockend   = $end;
        my $selection;
        if ( $mark eq 'del' ) {
            my ( $lsr, $lsc, $ler, $lec, $step, $edited );
            ( $lsr, $lsc ) = split /\./, $thisblockstart;
            ( $ler, $lec ) = split /\./, $thisblockend;
            $step = $lsr;
            while ( $step <= $ler ) {
                $selection = $textwindow->get( "$step.0", "$step.end" );
                $edited++ if ( $selection =~ s/<\/td>/  /g );
                $edited++ if ( $selection =~ s/<\/?body>//g );
                $edited++ if ( $selection =~ s/<br.*?>//g );
                $edited++ if ( $selection =~ s/<\/?div[^>]*?>//g );
                $edited++
                    if ( $selection
                    =~ s/<span.*?margin-left: (\d+\.?\d?)em.*?>/' ' x ($1 *2)/e
                    );
                $edited++ if ( $selection =~ s/<\/?span[^>]*?>//g );
                $edited++ if ( $selection =~ s/<\/?[hscalupt].*?>//g );
                $edited++ if ( $selection =~ s/&nbsp;/ /g );
                $edited++ if ( $selection =~ s/<\/?blockquote>//g );
                $edited++ if ( $selection =~ s/\s+$// );
                $textwindow->delete( "$step.0", "$step.end" ) if $edited;
                $textwindow->insert( "$step.0", $selection ) if $edited;
                $step++;
                unless ( $step % 25 ) { $textwindow->update }
            }
            $textwindow->tagAdd( 'sel', $start, $end );
        }
        elsif ( $mark eq 'br' ) {
            my ( $lsr, $lsc, $ler, $lec, $step );
            ( $lsr, $lsc ) = split /\./, $thisblockstart;
            ( $ler, $lec ) = split /\./, $thisblockend;
            if ( $lsr eq $ler ) {
                $textwindow->insert( 'insert', '<br />' );
            }
            else {
                $step = $lsr;
                while ( $step <= $ler ) {
                    $selection = $textwindow->get( "$step.0", "$step.end" );
                    $selection =~ s/<br.*?>//g;
                    $textwindow->insert( "$step.end", '<br />' );
                    $step++;
                }
            }
        }
        elsif ( $mark eq 'hr' ) {
            $textwindow->insert( 'insert', '<hr style="width: 95%;" />' );
        }
        elsif ( $mark eq '&nbsp;' ) {
            my ( $lsr, $lsc, $ler, $lec, $step );
            ( $lsr, $lsc ) = split /\./, $thisblockstart;
            ( $ler, $lec ) = split /\./, $thisblockend;
            if ( $lsr eq $ler ) {
                $textwindow->insert( 'insert', '&nbsp;' );
            }
            else {
                $step = $lsr;
                while ( $step <= $ler ) {
                    $selection = $textwindow->get( "$step.0", "$step.end" );
                    if ( $selection =~ /\s\s/ ) {
                        $selection =~ s/^\s/&nbsp;/;
                        $selection =~ s/  /&nbsp; /g;
                        $selection =~ s/&nbsp; /&nbsp;&nbsp;/g;
                        $textwindow->delete( "$step.0", "$step.end" );
                        $textwindow->insert( "$step.0", $selection );
                    }
                    $step++;
                }
            }
        }
        elsif ( $mark eq 'img' ) {
            htmlimage( $thisblockstart, $thisblockend );
        }
        elsif ( $mark eq 'elink' ) {
            my ( $name, $tempname );
            $name = '';
            if ( $lglobal{elinkpop} ) {
                $lglobal{elinkpop}->raise;
            }
            else {
                $lglobal{elinkpop} = $top->Toplevel;
                $lglobal{elinkpop}->title('Link Name');
                my $linkf1 = $lglobal{elinkpop}
                    ->Frame->pack( -side => 'top', -anchor => 'n' );
                my $linklabel = $linkf1->Label( -text => 'Link name' )->pack;
                $lglobal{linkentry}
                    = $linkf1->Entry( -width => 60, -background => 'white' )
                    ->pack;
                my $linkf2 = $lglobal{elinkpop}
                    ->Frame->pack( -side => 'top', -anchor => 'n' );
                my $extbrowse = $linkf2->Button(
                    -activebackground => $activecolor,
                    -text             => 'Browse',
                    -width            => 16,
                    -command          => sub {
                        $name = $lglobal{elinkpop}
                            ->getOpenFile( -title => 'File Name?' );
                        if ($name) {
                            $lglobal{linkentry}->delete( 0, 'end' );
                            $lglobal{linkentry}->insert( 'end', $name );
                        }
                    }
                )->pack( -side => 'left', -pady => 4 );
                my $linkf3 = $lglobal{elinkpop}
                    ->Frame->pack( -side => 'top', -anchor => 'n' );
                my $okbut = $linkf3->Button(
                    -activebackground => $activecolor,
                    -text             => 'Ok',
                    -width            => 16,
                    -command          => sub {
                        $name = $lglobal{linkentry}->get;
                        if ($name) {
                            $name =~ s/[\/\\]/;/g;
                            $tempname = $globallastpath;
                            $tempname =~ s/[\/\\]/;/g;
                            $name     =~ s/$tempname//;
                            $name     =~ s/;/\//g;
                            $done = '</a>';
                            $textwindow->insert( $thisblockend, $done );
                            $done = '<a href="' . $name . "\">";
                            $textwindow->insert( $thisblockstart, $done );
                        }
                        $lglobal{elinkpop}->destroy;
                        undef $lglobal{elinkpop};
                    }
                )->pack( -pady => 4 );
                $lglobal{elinkpop}->protocol(
                    'WM_DELETE_WINDOW' => sub {
                        $lglobal{elinkpop}->destroy;
                        undef $lglobal{elinkpop};
                    }
                );
                $lglobal{elinkpop}->Icon( -image => $icon );
                $lglobal{elinkpop}->transient( $lglobal{markpop} );
                $lglobal{linkentry}->focus;
            }
            $done = '';
        }
        elsif ( $mark eq 'ilink' ) {
            my ( $anchorname, $anchorstartindex, $anchorendindex, $length,
                $srow, $scol, $string, $link, $match, $match2 );
            $length     = 0;
            @intanchors = ();
            my %inthash = ();
            $anchorstartindex = $anchorendindex = '1.0';
            while (
                $anchorstartindex = $textwindow->search(
                    '-regexp', '--', '<a (name|id)=[\'"].+?[\'"]',
                    $anchorendindex, 'end'
                )
                )
            {
                $anchorendindex = $textwindow->search( '-regexp', '--', '>',
                    $anchorstartindex, 'end' );
                $string
                    = $textwindow->get( $anchorstartindex, $anchorendindex );
                $string =~ s/\n/ /g;
                $string =~ s/= /=/g;
                $string =~ m/=["'](.+?)['"]/;
                $match = $1;
                push @intanchors, '#' . $match;
                $match2 = $match;

                if ( exists $inthash{ '#' . ( lc($match) ) } ) {
                    $textwindow->tagAdd( 'highlight', $anchorstartindex,
                        $anchorendindex );
                    $textwindow->see($anchorstartindex);
                    $textwindow->bell unless $nobell;
                    $top->messageBox(
                        -icon => 'error',
                        -message =>
                            "More than one instance of the anchor $match2 in text.",
                        -title => 'Duplicate anchor names.',
                        -type  => 'Ok',
                    );
                    return;
                }
                else {
                    $inthash{ '#' . ( lc($match) ) } = '#' . $match2;
                }
            }
            my ( $name, $tempname );
            $name = '';
            if ( $lglobal{linkpop} ) {
                $lglobal{linkpop}->deiconify;
            }
            else {
                my $linklistbox;
                $selection
                    = $textwindow->get( $thisblockstart, $thisblockend );
                return unless length($selection);
                $lglobal{linkpop} = $top->Toplevel;
                $lglobal{linkpop}->title('Internal Links');
                $lglobal{linkpop}->geometry($geometry2) if $geometry2;
                $lglobal{linkpop}->transient($top)      if $stayontop;
                $lglobal{fnlinks} = 1;
                my $tframe = $lglobal{linkpop}->Frame->pack;
                $tframe->Checkbutton(
                    -variable    => \$lglobal{ilinksrt},
                    -selectcolor => $lglobal{checkcolor},
                    -text        => 'Sort Alphabetically',
                    -command     => sub {
                        $linklistbox->delete( '0', 'end' );
                        linkpopulate( $linklistbox, \@intanchors );
                    },
                    )->pack(
                    -side   => 'left',
                    -pady   => 2,
                    -padx   => 2,
                    -anchor => 'n'
                    );
                $tframe->Checkbutton(
                    -variable    => \$lglobal{fnlinks},
                    -selectcolor => $lglobal{checkcolor},
                    -text        => 'Hide Footnote Links',
                    -command     => sub {
                        $linklistbox->delete( '0', 'end' );
                        linkpopulate( $linklistbox, \@intanchors );
                    },
                    )->pack(
                    -side   => 'left',
                    -pady   => 2,
                    -padx   => 2,
                    -anchor => 'n'
                    );
                $tframe->Checkbutton(
                    -variable    => \$lglobal{pglinks},
                    -selectcolor => $lglobal{checkcolor},
                    -text        => 'Hide Page Links',
                    -command     => sub {
                        $linklistbox->delete( '0', 'end' );
                        linkpopulate( $linklistbox, \@intanchors );
                    },
                    )->pack(
                    -side   => 'left',
                    -pady   => 2,
                    -padx   => 2,
                    -anchor => 'n'
                    );
                my $pframe = $lglobal{linkpop}
                    ->Frame->pack( -fill => 'both', -expand => 'both' );
                $linklistbox = $pframe->Scrolled(
                    'Listbox',
                    -scrollbars  => 'se',
                    -background  => 'white',
                    -selectmode  => 'single',
                    -activestyle => 'none',
                    )->pack(
                    -side   => 'top',
                    -anchor => 'nw',
                    -fill   => 'both',
                    -expand => 'both',
                    -padx   => 2,
                    -pady   => 2
                    );
                drag($linklistbox);
                $lglobal{linkpop}->protocol(
                    'WM_DELETE_WINDOW' => sub {
                        $lglobal{linkpop}->destroy;
                        undef $lglobal{linkpop};
                    }
                );
                $lglobal{linkpop}->Icon( -image => $icon );
                BindMouseWheel($linklistbox);
                $linklistbox->eventAdd( '<<trans>>' => '<Double-Button-1>' );
                $linklistbox->bind(
                    '<<trans>>',
                    sub {
                        $name      = $linklistbox->get('active');
                        $geometry2 = $lglobal{linkpop}->geometry;
                        $done      = '</a>';
                        $textwindow->insert( $thisblockend, $done );
                        $done = "<a href=\"" . $name . "\">";
                        $textwindow->insert( $thisblockstart, $done );
                        $lglobal{linkpop}->destroy;
                        undef $lglobal{linkpop};
                    }
                );
                my $tempvar   = lc( makeanchor( deaccent($selection) ) );
                my $flag      = 0;
                my @entrarray = split( /_/, $tempvar );
                $entrarray[1] = '@' unless $entrarray[1];
                $entrarray[2] = '@' unless $entrarray[2];
                for ( sort (@intanchors) ) {
                    last unless $tempvar;
                    next
                        if (
                        ( ( $_ =~ /#Footnote/ ) || ( $_ =~ /#FNanchor/ ) )
                        && $lglobal{fnlinks} );
                    next if ( ( $_ =~ /#Page_\d+/ ) && $lglobal{pglinks} );
                    next unless ( lc($_) eq '#' . $tempvar );
                    $linklistbox->insert( 'end', $_ );
                    $flag++;
                }
                $linklistbox->insert( 'end', '  ' );

                #print"$selection2\n";
                if ( $entrarray[1] && ( $entrarray[1] ne '@' ) ) {
                    $entrarray[0] = '@'
                        if ( $entrarray[0] =~ /^to$|^a$|^the$|^and$/ );
                    $entrarray[1] = '@'
                        if ( $entrarray[1] =~ /^to$|^a$|^the$|^and$/ );
                    $entrarray[2] = '@'
                        if ( $entrarray[2] =~ /^to$|^a$|^the$|^and$/ );
                }
                for ( sort (@intanchors) ) {
                    next
                        if (
                        ( ( $_ =~ /#Footnote/ ) || ( $_ =~ /#FNanchor/ ) )
                        && $lglobal{fnlinks} );
                    next if ( ( $_ =~ /#Page_\d+/ ) && $lglobal{pglinks} );
                    next
                        unless (
                        lc($_)
                        =~ /\Q$entrarray[0]\E|\Q$entrarray[1]\E|\Q$entrarray[2]\E/
                        );
                    $linklistbox->insert( 'end', $_ );
                    $flag++;
                }
                $linklistbox->insert( 'end', "  " );
                $flag = 0;
                linkpopulate( $linklistbox, \@intanchors );
                $linklistbox->focus;
            }
        }
        elsif ( $mark eq 'anchor' ) {
            my $linkname;
            $selection = $textwindow->get( $thisblockstart, $thisblockend )
                || '';
            $linkname = makeanchor( deaccent($selection) );
            $done
                = "<a name=\""
                . $linkname
                . "\" id=\""
                . $linkname
                . "\"></a>";
            $textwindow->insert( $thisblockstart, $done );
        }
        elsif ( $mark =~ /h\d/ ) {
            $selection = $textwindow->get( $thisblockstart, $thisblockend );
            if ( $selection =~ s/<\/?p>//g ) {
                $textwindow->delete( $thisblockstart, $thisblockend );
                $textwindow->tagRemove( 'sel', '1.0', 'end' );
                $textwindow->markSet( 'blkend', $thisblockstart );
                $textwindow->insert( $thisblockstart,
                    "<$mark>$selection<\/$mark>" );
                $textwindow->tagAdd( 'sel', $thisblockstart,
                    $textwindow->index('blkend') );
            }
            else {
                $textwindow->insert( $thisblockend,   "<\/$mark>" );
                $textwindow->insert( $thisblockstart, "<$mark>" );
            }
        }
        elsif ( ( $mark =~ /div/ ) || ( $mark =~ /span/ ) ) {
            $done = "<\/" . $mark . ">";
            $textwindow->insert( $thisblockend, $done );
            $mark .= $mark1;
            $done = '<' . $mark . '>';
            $textwindow->insert( $thisblockstart, $done );
        }
        else {
            $done = "<\/" . $mark . '>';
            $textwindow->insert( $thisblockend, $done );
            $done = '<' . $mark . '>';
            $textwindow->insert( $thisblockstart, $done );
        }
    }
    if ( $open != $close ) {
        $top->messageBox(
            -icon => 'error',
            -message =>
                "Mismatching open and close markup removed.\nYou may have orphaned markup.",
            -title => 'Mismatching markup.',
            -type  => 'Ok',
        );
    }
    $textwindow->focus;
}

sub linkpopulate {
    my $linklistbox = shift;
    my $anchorsref  = shift;
    if ( $lglobal{ilinksrt} ) {
        for ( natural_sort_alpha( @{$anchorsref} ) ) {
            next
                if ( ( ( $_ =~ /#Footnote/ ) || ( $_ =~ /#FNanchor/ ) )
                && $lglobal{fnlinks} );
            next if ( ( $_ =~ /#Page_\d+/ ) && $lglobal{pglinks} );
            $linklistbox->insert( 'end', $_ );
        }
    }
    else {
        foreach ( @{$anchorsref} ) {
            next
                if ( ( ( $_ =~ /#Footnote/ ) || ( $_ =~ /#FNanchor/ ) )
                && $lglobal{fnlinks} );
            next if ( ( $_ =~ /#Page_\d+/ ) && $lglobal{pglinks} );
            $linklistbox->insert( 'end', $_ );
        }
    }
    $linklistbox->yviewScroll( 1, 'units' );
    $linklistbox->update;
    $linklistbox->yviewScroll( -1, 'units' );
}

sub htmlimage {
    my ( $thisblockstart, $thisblockend ) = @_;
    $thisblockstart = 'insert'        unless $thisblockstart;
    $thisblockend   = $thisblockstart unless $thisblockend;
    $textwindow->markSet( 'thisblockstart', $thisblockstart );
    $textwindow->markSet( 'thisblockend',   $thisblockend );
    my $selection;
    $selection = $textwindow->get( $thisblockstart, $thisblockend ) if @_;
    $selection = '' unless $selection;
    my $preservep = '';
    $preservep = '<p>' if $selection !~ /<\/p>$/;
    $selection =~ s/<\/?[bidhscalup].*?>//g;
    $selection =~ s/^\[Illustration:?\s*(\.*)/$1/;
    $selection =~ s/(\.*)\]$/$1/;
    my ( $fname, $extension );
    my $xpad = 0;
    $globalimagepath = $globallastpath unless $globalimagepath;
    my ($alignment);
    $lglobal{htmlorig}  = $top->Photo;
    $lglobal{htmlthumb} = $top->Photo;

    if ( defined( $lglobal{htmlimpop} ) ) {
        $lglobal{htmlimpop}->deiconify;
        $lglobal{htmlimpop}->raise;
        $lglobal{htmlimpop}->focus;
    }
    else {
        $lglobal{htmlimpop} = $top->Toplevel;
        $lglobal{htmlimpop}->title('Image');
        $lglobal{htmlimpop}->geometry( $lglobal{htmlgeom} )
            if $lglobal{htmlgeom};
        my $f1 = $lglobal{htmlimpop}->LabFrame( -label => 'File Name' )
            ->pack( -side => 'top', -anchor => 'n', -padx => 2 );
        $lglobal{imgname}
            = $f1->Entry( -width => 45, )->pack( -side => 'left' );
        my $f3 = $lglobal{htmlimpop}->LabFrame( -label => 'Alt text' )
            ->pack( -side => 'top', -anchor => 'n' );
        $lglobal{alttext}
            = $f3->Entry( -width => 45, )->pack( -side => 'left' );
        my $f4 = $lglobal{htmlimpop}->LabFrame( -label => 'Title text' )
            ->pack( -side => 'top', -anchor => 'n' );
        $lglobal{titltext}
            = $f4->Entry( -width => 45, )->pack( -side => 'left' );
        my $f5 = $lglobal{htmlimpop}->LabFrame( -label => 'Geometry' )
            ->pack( -side => 'top', -anchor => 'n' );
        my $f51 = $f5->Frame->pack( -side => 'top', -anchor => 'n' );
        $f51->Label( -text => 'Width' )->pack( -side => 'left' );
        $lglobal{widthent} = $f51->Entry(
            -width    => 10,
            -validate => 'all',
            -vcmd     => sub {
                return 1 if ( !$lglobal{ImageSize} );
                return 1 unless $lglobal{htmlimgar};
                return 1 unless ( $_[0] && $_[2] );
                return 0 unless ( defined $_[1] && $_[1] =~ /\d/ );
                my ( $sizex, $sizey )
                    = Image::Size::imgsize( $lglobal{imgname}->get );
                $lglobal{heightent}->delete( 0, 'end' );
                $lglobal{heightent}
                    ->insert( 'end', ( int( $sizey * ( $_[0] / $sizex ) ) ) );
                return 1;
            }
        )->pack( -side => 'left' );
        $f51->Label( -text => 'Height' )->pack( -side => 'left' );
        $lglobal{heightent} = $f51->Entry(
            -width    => 10,
            -validate => 'all',
            -vcmd     => sub {
                return 1 if ( !$lglobal{ImageSize} );
                return 1 unless $lglobal{htmlimgar};
                return 1 unless ( $_[0] && $_[2] );
                return 0 unless ( defined $_[1] && $_[1] =~ /\d/ );
                my ( $sizex, $sizey )
                    = Image::Size::imgsize( $lglobal{imgname}->get );
                $lglobal{widthent}->delete( 0, 'end' );
                $lglobal{widthent}
                    ->insert( 'end', ( int( $sizex * ( $_[0] / $sizey ) ) ) );
                return 1;
            }
        )->pack( -side => 'left' );
        my $ar = $f51->Checkbutton(
            -text     => 'Maintain AR',
            -variable => \$lglobal{htmlimgar},
            -onvalue  => 1,
            -offvalue => 0
        )->pack( -side => 'left' );
        $ar->select;
        my $f52 = $f5->Frame->pack( -side => 'top', -anchor => 'n' );
        $lglobal{htmlimggeom}
            = $f52->Label( -text => '' )->pack( -side => 'left' );
        my $f2 = $lglobal{htmlimpop}->LabFrame( -label => 'Alignment' )
            ->pack( -side => 'top', -anchor => 'n' );
        $f2->Radiobutton(
            -variable    => \$alignment,
            -text        => 'Left',
            -selectcolor => $lglobal{checkcolor},
            -value       => 'left',
        )->grid( -row => 1, -column => 1 );
        my $censel = $f2->Radiobutton(
            -variable    => \$alignment,
            -text        => 'Center',
            -selectcolor => $lglobal{checkcolor},
            -value       => 'center',
        )->grid( -row => 1, -column => 2 );
        $f2->Radiobutton(
            -variable    => \$alignment,
            -text        => 'Right',
            -selectcolor => $lglobal{checkcolor},
            -value       => 'right',
        )->grid( -row => 1, -column => 3 );
        $censel->select;
        my $f8 = $lglobal{htmlimpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f8->Button(
            -text    => 'Ok',
            -width   => 10,
            -command => sub {
                my $name = $lglobal{imgname}->get;
                if ($name) {
                    my $sizexy
                        = 'width="'
                        . $lglobal{widthent}->get
                        . '" height="'
                        . $lglobal{heightent}->get . '"';
                    my $width = $lglobal{widthent}->get;
                    return unless $name;
                    ( $fname, $globalimagepath, $extension )
                        = fileparse($name);
                    $globalimagepath = os_normal($globalimagepath);
                    $name =~ s/[\/\\]/\;/g;
                    my $tempname = $globallastpath;
                    $tempname =~ s/[\/\\]/\;/g;
                    $name     =~ s/$tempname//;
                    $name     =~ s/;/\//g;
                    $alignment = 'center' unless $alignment;
                    $selection = $lglobal{alttext}->get;
                    $selection ||= '';
                    $selection =~ s/"/&quot;/g;
                    $selection =~ s/'/&#39;/g;
                    my $alt = $selection;
                    $selection = "<span class=\"caption\">$selection</span>\n"
                        if $selection;
                    $preservep = '' unless $selection;
                    my $title = $lglobal{titltext}->get || '';
                    $title =~ s/"/&quot;/g;
                    $title =~ s/'/&#39;/g;
                    $textwindow->addGlobStart;

                    if ( $alignment eq 'center' ) {
                        $textwindow->delete( 'thisblockstart',
                            'thisblockend' );
                        $textwindow->insert( 'thisblockstart',
                                  "<div class=\"figcenter\" style=\"width: "
                                . $width
                                . "px;\">\n<img src=\"$name\" $sizexy alt=\"$alt\" title=\"$title\" />\n$selection</div>$preservep"
                        );
                    }
                    elsif ( $alignment eq 'left' ) {
                        $textwindow->delete( 'thisblockstart',
                            'thisblockend' );
                        $textwindow->insert( 'thisblockstart',
                                  "<div class=\"figleft\" style=\"width: " 
                                . $width
                                . "px;\">\n<img src=\"$name\" $sizexy alt=\"$alt\" title=\"$title\" />\n$selection</div>$preservep"
                        );
                    }
                    elsif ( $alignment eq 'right' ) {
                        $textwindow->delete( 'thisblockstart',
                            'thisblockend' );
                        $textwindow->insert( 'thisblockstart',
                                  "<div class=\"figright\" style=\"width: " 
                                . $width
                                . "px;\">\n<img src=\"$name\" $sizexy alt=\"$alt\" title=\"$title\" />\n$selection</div>$preservep"
                        );
                    }
                    $textwindow->addGlobEnd;
                    $lglobal{htmlgeom} = $lglobal{htmlimpop}->geometry;
                    $lglobal{htmlthumb}->delete  if $lglobal{htmlthumb};
                    $lglobal{htmlthumb}->destroy if $lglobal{htmlthumb};
                    $lglobal{htmlorig}->delete   if $lglobal{htmlorig};
                    $lglobal{htmlorig}->destroy  if $lglobal{htmlorig};
                    for (
                        $lglobal{alttext},  $lglobal{titltext},
                        $lglobal{widthent}, $lglobal{heightent},
                        $lglobal{imagelbl}, $lglobal{imgname}
                        )
                    {
                        $_->destroy;
                    }
                    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                    $lglobal{htmlimpop}->destroy if $lglobal{htmlimpop};
                    undef $lglobal{htmlimpop} if $lglobal{htmlimpop};
                }
            }
        )->pack;
        my $f = $lglobal{htmlimpop}->Frame->pack;
        $lglobal{imagelbl} = $f->Label(
            -text       => 'Thumbnail',
            -justify    => 'center',
            -background => 'white',
        )->grid( -row => 1, -column => 1 );
        $lglobal{imagelbl}->bind( $lglobal{imagelbl}, '<1>', \&tnbrowse );
        $lglobal{htmlimpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{htmlthumb}->delete  if $lglobal{htmlthumb};
                $lglobal{htmlthumb}->destroy if $lglobal{htmlthumb};
                $lglobal{htmlorig}->delete   if $lglobal{htmlorig};
                $lglobal{htmlorig}->destroy  if $lglobal{htmlorig};
                for (
                    $lglobal{alttext},  $lglobal{titltext},
                    $lglobal{widthent}, $lglobal{heightent},
                    $lglobal{imagelbl}, $lglobal{imgname}
                    )
                {
                    $_->destroy;
                }
                $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                $lglobal{htmlimpop}->destroy;
                undef $lglobal{htmlimpop};
            }
        );
        $lglobal{htmlimpop}->transient($top);
        $lglobal{htmlimpop}->Icon( -image => $icon );
    }
    $lglobal{alttext}->delete( 0, 'end' ) if $lglobal{alttext};
    $lglobal{titltext}->delete( 0, 'end' ) if $lglobal{titltext};
    $lglobal{alttext}->insert( 'end', $selection );
    tnbrowse();
}

sub tnbrowse {
    my $types = [
        [ 'Image Files', [ '.gif', '.jpg', '.png' ] ],
        [ 'All Files', ['*'] ],
    ];
    my $name = $lglobal{htmlimpop}->getOpenFile(
        -filetypes  => $types,
        -title      => 'File Load',
        -initialdir => $globalimagepath
    );
    return unless ($name);
    my $xythumb = 200;

    if ( $lglobal{ImageSize} ) {
        my ( $sizex, $sizey ) = Image::Size::imgsize($name);
        $lglobal{widthent}->delete( 0, 'end' );
        $lglobal{heightent}->delete( 0, 'end' );
        $lglobal{widthent}->insert( 'end', $sizex );
        $lglobal{heightent}->insert( 'end', $sizey );
        $lglobal{htmlimggeom}->configure(
            -text => "Actual image size: $sizex x $sizey pixels" );
    }
    else {
        $lglobal{htmlimggeom}
            ->configure( -text => "Actual image size: unknown" );
    }
    $lglobal{htmlorig}->blank;
    $lglobal{htmlthumb}->blank;
    $lglobal{imgname}->delete( '0', 'end' );
    $lglobal{imgname}->insert( 'end', $name );
    my ( $fn, $ext );
    ( $fn, $globalimagepath, $ext ) = fileparse( $name, '(?<=\.)[^\.]*$' );
    $globalimagepath = os_normal($globalimagepath);
    $ext =~ s/jpg/jpeg/;

    if ( lc($ext) eq 'gif' ) {
        $lglobal{htmlorig}->read( $name, -shrink );
    }
    else {
        $lglobal{htmlorig}->read( $name, -format => $ext, -shrink );
    }
    my $sw = int( ( $lglobal{htmlorig}->width ) / $xythumb );
    my $sh = int( ( $lglobal{htmlorig}->height ) / $xythumb );
    if ( $sh > $sw ) {
        $sw = $sh;
    }
    if ( $sw < 2 ) { $sw += 1 }
    $lglobal{htmlthumb}
        ->copy( $lglobal{htmlorig}, -subsample => ($sw), -shrink );
    $lglobal{imagelbl}->configure(
        -image   => $lglobal{htmlthumb},
        -text    => 'Thumbnail',
        -justify => 'center',
    );
}

sub linkcheck {
    if ( defined( $lglobal{lcpop} ) ) {
        $lglobal{lcpop}->deiconify;
        $lglobal{lcpop}->raise;
        $lglobal{lcpop}->focus;
    }
    else {

        $lglobal{lcpop} = $top->Toplevel;
        $lglobal{lcpop}->title('Link Check');
        my $frame = $lglobal{lcpop}->Frame->pack->pack(
            -anchor => 'nw',
            -expand => 'yes',
            -fill   => 'both'
        );
        $lglobal{linkchkbox} = $frame->Scrolled(
            'Listbox',
            -scrollbars  => 'se',
            -background  => 'white',
            -font        => '{Courier} 10',
            -height      => 40,
            -width       => 60,
            -activestyle => 'none',
        )->pack( -anchor => 'nw', -expand => 'yes', -fill => 'both' );
        drag( $lglobal{linkchkbox} );
        $lglobal{lcpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{lcpop}->destroy; undef $lglobal{lcpop} } );
        $lglobal{lcpop}->Icon( -image => $icon );
    }
    BindMouseWheel( $lglobal{linkchkbox} );
    $lglobal{linkchkbox}->eventAdd(
        '<<search>>' => '<ButtonRelease-2>',
        '<ButtonRelease-3>'
    );
    $lglobal{linkchkbox}->bind(
        '<<search>>',
        sub {
            $lglobal{linkchkbox}->activate(
                $lglobal{linkchkbox}->index(
                    '@'
                        . (
                              $lglobal{linkchkbox}->pointerx
                            - $lglobal{linkchkbox}->rootx
                        )
                        . ','
                        . (
                              $lglobal{linkchkbox}->pointery
                            - $lglobal{linkchkbox}->rooty
                        )
                )
            );
            $lglobal{linkchkbox}->selectionClear( 0, 'end' );
            $lglobal{linkchkbox}
                ->selectionSet( $lglobal{linkchkbox}->index('active') );
            my $sword = $lglobal{linkchkbox}->get('active');
            return unless ( defined $sword and length $sword );
            searchpopup();
            searchoptset(qw/0 x x 0/);
            $lglobal{searchentry}->delete( '1.0', 'end' );
            $lglobal{searchentry}->insert( 'end', $sword );
            updatesearchlabels();
        }
    );
    $lglobal{linkchkbox}->eventAdd( '<<find>>' => '<Double-Button-1>' );
    $lglobal{linkchkbox}->bind(
        '<<find>>',
        sub {
            my $sword = $lglobal{linkchkbox}->get('active');
            return unless ( defined $sword and length $sword );
            return unless $lglobal{linkchkbox}->index('active');
            return unless ( $lglobal{linkchkbox}->curselection );
            my @savesets = @sopt;
            searchoptset(qw/0 x x 0/);
            searchtext($sword);
            searchoptset(@savesets);
            $top->raise;
        }
    );
    $lglobal{linkchkbox}->delete( '0', 'end' );
    $lglobal{linkchkbox}->update;
    my ( %anchor,  %id,  %link,   %image,  %badlink, $length, $upper );
    my ( $anchors, $ids, $ilinks, $elinks, $images,  $count,  $css )
        = ( 0, 0, 0, 0, 0, 0, 0 );
    my @warning = ();
    my $fname   = $lglobal{global_filename};
    if ( $fname =~ /(No File Loaded)/ ) {
        $lglobal{linkchkbox}
            ->insert( 'end', "You need to save your file first." );
        return;
    }
    $fname = dos_path( $lglobal{global_filename} ) if OS_Win;
    my ( $f, $d, $e ) = fileparse( $fname, qr{\.[^\.]*$} );
    my %imagefiles;
    my @ifiles   = ();
    my $imagedir = '';
    push @warning, '';
    my ( $fh, $filename );

    if ( $textwindow->numberChanges ) {
        ( $fh, $filename ) = tempfile();
        my ($lines) = $textwindow->index('end - 1 chars') =~ /^(\d+)\./;
        my $index = '1.0';
        while ( $textwindow->compare( $index, '<', 'end' ) ) {
            my $end = $textwindow->index("$index lineend +1c");
            my $line = $textwindow->get( $index, $end );
            print $fh $line;
            $index = $end;
        }
        $fname = $filename;
        close $fh;
    }
    my $parser = HTML::TokeParser->new($fname);
    while ( my $token = $parser->get_token ) {
        if ( $token->[0] eq 'S' and $token->[1] eq 'style' ) {
            $token = $parser->get_token;
            if ( $token->[0] eq 'T' and $token->[2] ) {
                my @urls = $token->[1] =~ m/\burl\(['"](.+?)['"]\)/gs;
                for my $img (@urls) {
                    if ($img) {
                        if ( !$imagedir ) {
                            $imagedir = $img;
                            $imagedir =~ s/\/.*?$/\//;
                            @ifiles = glob( $d . $imagedir . '*.*' );
                            for (@ifiles) { $_ =~ s/\Q$d\E// }
                            for (@ifiles) { $imagefiles{$_} = '' }
                        }
                        $image{$img}++;
                        $upper++ if ( $img ne lc($img) );
                        delete $imagefiles{$img}
                            if ( ( defined $imagefiles{$img} )
                            || ( defined $link{$img} ) );
                        push @warning,
                            "WARNING! $img contains uppercase characters!"
                            if ( $img ne lc($img) );
                        push @warning, "CRITICAL! Image file: $img not found!"
                            unless ( -e $d . $img );
                        $css++;
                    }
                }
            }
        }
        next unless $token->[0] eq 'S';
        my $url    = $token->[2]{href} || '';
        my $anchor = $token->[2]{name} || '';
        my $img    = $token->[2]{src}  || '';
        my $id     = $token->[2]{id}   || '';
        if ($anchor) {
            $anchor{ '#' . $anchor } = $anchor;
            $anchors++;
        }
        elsif ($id) {
            $id{ '#' . $id } = $id;
            $ids++;
        }
        if ( $url =~ m/^(#?)(.+)$/ ) {
            $link{ $1 . $2 } = $2;
            $ilinks++ if $1;
            $elinks++ unless $1;
        }
        if ($img) {
            if ( !$imagedir ) {
                $imagedir = $img;
                $imagedir =~ s/\/.*?$/\//;
                @ifiles = glob( $d . $imagedir . '*.*' );
                for (@ifiles) { $_ =~ s/\Q$d\E// }
                for (@ifiles) { $imagefiles{$_} = '' }
            }
            $image{$img}++;
            $upper++ if ( $img ne lc($img) );
            delete $imagefiles{$img}
                if ( ( defined $imagefiles{$img} )
                || ( defined $link{$img} ) );
            push @warning, "WARNING! $img contains uppercase characters!"
                if ( $img ne lc($img) );
            push @warning, "CRITICAL! Image file: $img not found!"
                unless ( -e $d . $img );
            $images++;
        }
    }
    for ( keys %link ) {
        $badlink{$_} = $_ if ( $_ =~ m/\\|\%5C|\s|\%20/ );
        delete $imagefiles{$_} if ( defined $imagefiles{$_} );
    }
    $lglobal{linkchkbox}->insert( 'end', "$anchors named anchors" );
    $lglobal{linkchkbox}
        ->insert( 'end', "$ids unnamed anchors (tag with id attribute)" );
    $lglobal{linkchkbox}->insert( 'end', "$ilinks internal links" );
    $lglobal{linkchkbox}->insert( 'end', "$images image links" );
    $lglobal{linkchkbox}->insert( 'end', "$css CSS style image links" );
    $lglobal{linkchkbox}->insert( 'end', "$elinks external links", '', '' );
    $lglobal{linkchkbox}
        ->insert( 'end', 'INTERNAL LINKS WITHOUT ANCHORS. - (CRITICAL)', '' );

    for ( natural_sort_alpha( keys %link ) ) {
        unless ( ( defined $anchor{$_} )
            || ( defined $id{$_} )
            || ( $link{$_} eq $_ ) )
        {
            $lglobal{linkchkbox}->insert( 'end', "#$link{$_}" );
            $count++;
        }
    }
    $lglobal{linkchkbox}
        ->insert( '5', "$count internal links without anchors" );
    $lglobal{linkchkbox}
        ->insert( 'end', '', 'EXTERNAL LINKS. - (CRITICAL)', '' );
    my $externflag;
    for ( natural_sort_alpha( keys %link ) ) {
        if ( $link{$_} eq $_ ) {
            if ( $_ =~ /:\/\// ) {
                $lglobal{linkchkbox}->insert( 'end', "$link{$_}" );
            }
            else {
                my $temp = $_;
                $temp =~ s/^([^#]+).*/$1/;
                unless ( -e $d . $temp ) {
                    $lglobal{linkchkbox}
                        ->insert( 'end', "local file(s) not found!" )
                        unless $externflag;
                    $lglobal{linkchkbox}->insert( 'end', "$link{$_}" );
                    $externflag++;
                }
            }
        }
    }
    $lglobal{linkchkbox}
        ->insert( 'end', '', 'LINKS WITH BAD CHARACTERS. - (CRITICAL)', '' );
    for ( natural_sort_alpha( keys %badlink ) ) {
        $lglobal{linkchkbox}->insert( 'end', "$badlink{$_}" );
    }
    $lglobal{linkchkbox}->insert( 'end', '',
        'IMAGE LINKS/FILES WITH PROBLEMS. - (CRITICAL)' );
    $lglobal{linkchkbox}->insert( 'end', @warning ) if @warning;
    $lglobal{linkchkbox}->insert( 'end', '' );
    if ( keys %imagefiles ) {
        for ( natural_sort_alpha( keys %imagefiles ) ) {
            $lglobal{linkchkbox}
                ->insert( 'end', 'WARNING! File ' . $_ . ' not used!' )
                if ( $_ =~ /\.(png|jpg|gif|bmp)/ );
        }
        $lglobal{linkchkbox}->insert( 'end', '' );
    }
    $lglobal{linkchkbox}
        ->insert( 'end', '', 'ANCHORS WITHOUT LINKS. - (INFORMATIONAL)', '' );
    for ( natural_sort_alpha( keys %anchor ) ) {
        unless ( exists $link{$_} ) {
            $lglobal{linkchkbox}->insert( 'end', "$anchor{$_}" );
            $count++;
        }
    }
    $lglobal{linkchkbox}->insert( '6', "$count  anchors without links" );
    unlink $filename if $filename;
}

sub htmlimages {
    my $length;
    my $start
        = $textwindow->search( '-regexp', '--', '(<p>)?\[Illustration', '1.0',
        'end' );
    return unless $start;
    $textwindow->see($start);
    my $end = $textwindow->search(
        '-regexp',
        '-count' => \$length,
        '--', '\](<\/p>)?', $start, 'end'
    );
    $end = $textwindow->index( $end . ' +' . $length . 'c' );
    return unless $end;
    $textwindow->tagAdd( 'highlight', $start, $end );
    $textwindow->markSet( 'insert', $start );
    update_indicators();
    htmlimage( $start, $end );
}

sub deaccent {
    my $phrase = shift;
    return $phrase unless ( $phrase =~ y/\xC0-\xFF// );
    $phrase
        =~ tr/¿¡¬√ƒ≈‡·‚„‰Â«Á»… ÀËÈÍÎÃÕŒœÏÌÓÔ“”‘’÷ÿÚÛÙıˆ¯—ÒŸ⁄€‹˘˙˚¸›ˇ˝/AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiOOOOOOooooooNnUUUUuuuuYyy/;
    my %trans = qw(∆ AE Ê ae ﬁ TH ˛ th – TH  th ﬂ ss);
    $phrase =~ s/([∆Êﬁ˛–ﬂ])/$trans{$1}/g;
    return $phrase;
}

sub makeanchor {
    my $linkname = shift;
    return unless $linkname;
    $linkname =~ s/-/\x00/g;
    $linkname =~ s/&amp;|&mdash;/\xFF/;
    $linkname =~ s/<sup>.*?<\/sup>//g;
    $linkname =~ s/<\/?[^>]+>//g;
    $linkname =~ s/\p{Punct}//g;
    $linkname =~ s/\x00/-/g;
    $linkname =~ s/\s+/_/g;
    while ( $linkname =~ m/([\x{100}-\x{ffef}])/ ) {
        my $char     = "$1";
        my $ord      = ord($char);
        my $phrase   = charnames::viacode($ord);
        my $case     = 'lc';
        my $notlatin = 1;
        $phrase = '-X-' unless ( $phrase =~ /(LETTER|DIGIT|LIGATURE)/ );
        $case     = 'uc' if $phrase =~ /CAPITAL|^-X-$/;
        $notlatin = 0    if $phrase =~ /LATIN/;
        $phrase =~ s/.+(LETTER|DIGIT|LIGATURE) //;
        $phrase =~ s/ WITH.+//;
        $phrase = lc($phrase) if $case eq 'lc';
        $phrase =~ s/ /_/g;
        $phrase = "-$phrase-" if $notlatin;
        $linkname =~ s/$char/$phrase/g;
    }
    $linkname =~ s/--+/-/g;
    $linkname =~ s/[\x90-\xff\x20\x22]/_/g;
    $linkname =~ s/__+/_/g;
    $linkname =~ s/^[_-]+|[_-]+$//g;
    return $linkname;
}

# FIXME: Split this into separate functions, eventually into HTMLconvert.pm
sub htmlautoconvert {
    viewpagenums() if ( $lglobal{seepagenums} );
    my $aname = '';
    my $author;
    my $blkquot = 0;
    my $cflag   = 0;
    my $front;
    my $headertext;
    my $inblock    = 0;
    my $incontents = '1.0';
    my $indent     = 0;
    my $intitle    = 0;
    my $ital       = 0;
    my $listmark   = 0;
    my $pgoffset   = 0;
    my $poetry     = 0;
    my $selection  = '';
    my $skip       = 0;
    my $thisblank  = '';
    my $thisblockend;
    my $thisblockstart = '1.0';
    my $thisend        = '';
    my $title;
    my ( $blkopen, $blkclose );
    my ( $ler, $lec, $step );    #FIXME: WTF is ler and lec supposed to mean?
    my @contents = ("<p>\n");
    my @last5 = [ 1, 1, 1, 1, 1 ];

    if ( $lglobal{cssblockmarkup} ) {
        $blkopen  = '<div class="blockquot"><p>';
        $blkclose = '</p></div>';
    }
    else {
        $blkopen  = '<blockquote><p>';
        $blkclose = '</p></blockquote>';
    }
    return if ( $lglobal{global_filename} =~ /No File Loaded/ );

    htmlbackup();

    html_convert_codepage();

    #    html_parse_header( $selection, $headertext, $title, $author);
    working('Parsing Header');

    $selection = $textwindow->get( '1.0', '1.end' );
    if ( $selection =~ /DOCTYPE/ ) {
        $step = 1;
        while (1) {
            $selection = $textwindow->get( "$step.0", "$step.end" );
            $headertext .= ( $selection . "\n" );
            $textwindow->ntdelete( "$step.0", "$step.end" );
            last if ( $selection =~ /^\<body/ );
            $step++;
            last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
        }
        $textwindow->ntdelete( '1.0', "$step.0 +1c" );
    }
    else {
        open my $infile, '<', 'header.txt'
            or warn "Could not open header file. $!\n";
        while (<$infile>) {
            $_ =~ s/\cM\cJ|\cM|\cJ/\n/g;

            # FIXME: $_ = eol_convert($_);
            $headertext .= $_;
        }
        close $infile;
    }

    $step = 0;
    while (1) {
        $step++;
        last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
        $selection = $textwindow->get( "$step.0", "$step.end" );
        next if ( $selection =~ /^\[Illustr/i );    # Skip Illustrations
        next if ( $selection =~ /^\/[\$f]/i );      # Skip /$|/F tags
        next unless length($selection);
        $title = $selection;
        $title =~ s/[,.]$//;
        $title = lc($title);
        $title =~ s/(^\W*\w)/\U$1\E/;
        $title =~ s/([\s\n]+\W*\w)/\U$1\E/g;
        last if $title;
    }
    if ($title) {
        $headertext =~ s/TITLE/$title/ if $title;
        $textwindow->ntinsert( "$step.0",   '<h1>' );
        $textwindow->ntinsert( "$step.end", '</h1>' );
    }
    while (1) {
        $step++;
        last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
        $selection = $textwindow->get( "$step.0", "$step.end" );
        if ( ( $selection =~ /^by/i ) and ( $step < 100 ) ) {
            last if ( $selection =~ /[\/[Ff]/ );
            if ( $selection =~ /^by$/i ) {
                $selection = '<h3>' . $selection . '</h3>';
                $textwindow->ntdelete( "$step.0", "$step.end" );
                $textwindow->ntinsert( "$step.0", $selection );
                do {
                    $step++;
                    $selection = $textwindow->get( "$step.0", "$step.end" );
                } until ( $selection ne "" );
                $author = $selection;
                $author =~ s/,$//;
            }
            else {
                $author = $selection;
                $author =~ s/\s$//i;
            }
        }
        $selection = '<h2>' . $selection . '</h2>' if $author;
        $textwindow->ntdelete( "$step.0", "$step.end" );
        $textwindow->ntinsert( "$step.0", $selection );
        last if $author || ( $step > 100 );
    }
    if ($author) {
        $author =~ s/^by //i;
        $author = ucfirst( lc($author) );
        $author     =~ s/(\W)(\w)/$1\U$2\E/g;
        $headertext =~ s/AUTHOR/$author/;
    }

    html_convert_ampersands();

    html_convert_emdashes();

    # Footnotes
    $lglobal{fnsecondpass}  = 0;
    $lglobal{fnsearchlimit} = 1;
    working('Converting Footnotes');
    footnotefixup();
    getlz();
    $textwindow->tagRemove( 'footnote',  '1.0', 'end' );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    $textwindow->see('1.0');
    $textwindow->update;
    $step = 0;

    while (1) {
        $step++;
        last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
        last unless $lglobal{fnarray}->[$step][0];
        next unless $lglobal{fnarray}->[$step][3];
        $textwindow->ntdelete( 'fne' . "$step" . '-1c', 'fne' . "$step" );
        $textwindow->ntinsert( 'fne' . "$step", '</p></div>' );
        $textwindow->ntinsert(
            (   'fns' . "$step" . '+'
                    . ( length( $lglobal{fnarray}->[$step][4] ) + 11 ) . "c"
            ),
            ']</span></a>'
        );
        $textwindow->ntdelete(
            'fns' . "$step" . '+'
                . ( length( $lglobal{fnarray}->[$step][4] ) + 10 ) . 'c',
            "fns" . "$step" . '+'
                . ( length( $lglobal{fnarray}->[$step][4] ) + 11 ) . 'c'
        );
        $textwindow->ntinsert(
            'fns' . "$step" . '+10c',
            "<div class=\"footnote\"><p><a name=\"Footnote_"
                . $lglobal{fnarray}->[$step][4] . '_'
                . $step
                . "\" id=\"Footnote_"
                . $lglobal{fnarray}->[$step][4] . '_'
                . $step
                . "\"></a><a href=\"#FNanchor_"
                . $lglobal{fnarray}->[$step][4] . '_'
                . $step
                . "\"><span class=\"label\">["
        );
        $textwindow->ntdelete( 'fns' . "$step", 'fns' . "$step" . '+10c' );
        $textwindow->ntinsert( 'fnb' . "$step", '</a>' )
            if ( $lglobal{fnarray}->[$step][3] );
        $textwindow->ntinsert(
            'fna' . "$step",
            "<a name=\"FNanchor_"
                . $lglobal{fnarray}->[$step][4] . '_'
                . $step
                . "\" id=\"FNanchor_"
                . $lglobal{fnarray}->[$step][4] . '_'
                . $step
                . "\"></a><a href=\"#Footnote_"
                . $lglobal{fnarray}->[$step][4] . '_'
                . $step
                . "\" class=\"fnanchor\">"
        ) if ( $lglobal{fnarray}->[$step][3] );

        while (
            $thisblank = $textwindow->search(
                '-regexp', '--', '^$',
                'fns' . "$step",
                "fne" . "$step"
            )
            )
        {
            $textwindow->ntinsert( $thisblank, '</p><p>' );
        }
    }

    working('Converting Body');
    @last5        = [ '1', '1', '1', '1', '1', '1' ];
    $step         = 1;
    $thisblockend = $textwindow->index('end');
    ( $ler, $lec ) = split /\./, $thisblockend;
    while ( $step <= $ler ) {
        unless ( $step % 500 ) {
            $textwindow->see("$step.0");
            $textwindow->update;
        }
        $selection = $textwindow->get( "$step.0", "$step.end" );
        $incontents = "$step.end"
            if ( ( $step < 100 )
            && ( $selection =~ /contents/i )
            && ( $incontents eq '1.0' ) );

        # Subscripts
        html_convert_subscripts( $selection, $step );

        # Superscripts
        html_convert_superscripts( $selection, $step );

        # Thought break conversion
        html_convert_tb( $selection, $step );

   #    if ($selection =~ s/\s{7}(\*\s{7}){4}\*/<hr style="width: 45%;" \/>/ )
   #        {
   #            $textwindow->ntdelete( "$step.0", "$step.end" );
   #            $textwindow->ntinsert( "$step.0", $selection );
   #            next;
   #        }
   #        if ( $selection =~ s/<tb>/<hr style="width: 45%;" \/>/ ) {
   #            $textwindow->ntdelete( "$step.0", "$step.end" );
   #            $textwindow->ntinsert( "$step.0", $selection );
   #            next;
   #        }
   #
   # /x|/X gets <pre>
        if ( $selection =~ m"^/x"i ) {
            $skip = 1;
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $textwindow->insert( "$step.0", '<pre>' );
            if ( ( $last5[2] ) && ( !$last5[3] ) ) {
                $textwindow->ntinsert( ( $step - 2 ) . ".end", '</p>' )
                    unless (
                    $textwindow->get( ( $step - 2 ) . '.0',
                        ( $step - 2 ) . '.end' ) =~ /<\/p>/
                    );
            }
            $step++;
            next;
        }

        # and end tag gets </pre>
        if ( $selection =~ m"^x/"i ) {
            $skip = 0;
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $textwindow->ntinsert( "$step.0", '</pre>' );
            $step++;
            $step++;
            next;
        }
        if ($skip) {
            $step++;
            next;
        }
        if ( $selection =~ m"^/f"i ) {
            $front = 1;
            $textwindow->ntdelete( "$step.0", "$step.end +1c" );
            if ( ( $last5[2] ) && ( !$last5[3] ) ) {
                $textwindow->ntinsert( ( $step - 2 ) . ".end", '</p>' )
                    unless (
                    $textwindow->get( ( $step - 2 ) . '.0',
                        ( $step - 2 ) . '.end' ) =~ /<\/p>/
                    );
            }
            next;
        }
        if ($front) {
            if ( $selection =~ m"^f/"i ) {
                $front = 0;
                $textwindow->ntdelete( "$step.0", "$step.end +1c" );
                $step++;
                next;
            }
            if ( $selection =~ /^<h/ ) {
                push @last5, $selection;
                shift @last5 while ( scalar(@last5) > 4 );
                $step++;
                next;
            }
            $textwindow->ntinsert( "$step.0", '<p class="center">' )
                if ( length($selection)
                && ( !$last5[3] )
                && ( $selection !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) );
            $textwindow->ntinsert( ( $step - 1 ) . '.end', '</p>' )
                if ( !( length($selection) )
                && ( $last5[3] )
                && ( $last5[3] !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }
        if ( $lglobal{poetrynumbers} && ( $selection =~ s/\s\s(\d+)$// ) ) {
            $selection .= '<span class="linenum">' . $1 . '</span>';
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $textwindow->ntinsert( "$step.0", $selection );
        }
        if ($poetry) {
            if ( $selection =~ /^\x7f*[pP]\/<?/ ) {
                $poetry    = 0;
                $selection = '</div></div>';
                $textwindow->ntdelete( "$step.0", "$step.0 +2c" );
                $textwindow->ntinsert( "$step.0", $selection );
                push @last5, $selection;
                shift @last5 while ( scalar(@last5) > 4 );
                $ital = 0;
                $step++;
                next;
            }
            if ( $selection =~ /^$/ ) {
                $textwindow->ntinsert( "$step.0",
                    '</div><div class="stanza">' );
                while (1) {
                    $step++;
                    $selection = $textwindow->get( "$step.0", "$step.end" );
                    last if ( $step ge $ler );
                    next if ( $selection =~ /^$/ );
                    last;
                }
                next;
            }
            if ( $selection
                =~ s/\s{2,}(\d+)\s*$/<span class="linenum">$1<\/span>/ )
            {
                $textwindow->ntdelete( "$step.0", "$step.end" );
                $textwindow->ntinsert( "$step.0", $selection );
            }
            my $indent = 0;
            $indent = length($1) if $selection =~ s/^(\s+)//;
            $textwindow->ntdelete( "$step.0", "$step.$indent" ) if $indent;
            $indent -= 4;
            $indent = 0 if ( $indent < 0 );
            my ( $op, $cl ) = ( 0, 0 );
            while ( ( my $temp = index $selection, '<i>', $op ) > 0 ) {
                $op = $temp + 3;
            }
            while ( ( my $temp = index $selection, '</i>', $cl ) > 0 ) {
                $cl = $temp + 4;
            }
            if ( !$cl && $ital ) {
                $textwindow->ntinsert( "$step.end", '</i>' );
            }
            if ( !$op && $ital ) {
                $textwindow->ntinsert( "$step.0", '<i>' );
            }
            if ( $op && $cl && ( $cl < $op ) && $ital ) {
                $textwindow->ntinsert( "$step.0",   '<i>' );
                $textwindow->ntinsert( "$step.end", '</i>' );
            }
            if ( $op && ( $cl < $op ) && !$ital ) {
                $textwindow->ntinsert( "$step.end", '</i>' );
                $ital = 1;
            }
            if ( $cl && ( $op < $cl ) && $ital ) {
                if ($op) {
                    $textwindow->ntinsert( "$step.0", '<i>' );
                }
                $ital = 0;
            }
            $lglobal{classhash}->{$indent}
                = '    .poem span.i' 
                . $indent
                . '     {display: block; margin-left: '
                . $indent
                . 'em; padding-left: 3em; text-indent: -3em;}' . "\n"
                if ( $indent and ( $indent != 2 ) and ( $indent != 4 ) );
            $textwindow->ntinsert( "$step.0",   "<span class=\"i$indent\">" );
            $textwindow->ntinsert( "$step.end", '<br /></span>' );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }
        if ( $selection =~ /^\x7f*\/[pP]$/ ) {
            $poetry = 1;
            if ( ( $last5[2] ) && ( !$last5[3] ) ) {
                $textwindow->ntinsert( ( $step - 2 ) . ".end", '</p>' )
                    unless (
                    $textwindow->get( ( $step - 2 ) . '.0',
                        ( $step - 2 ) . '.end' ) =~ /<\/p>/
                    );
            }
            $textwindow->ntdelete( $step . '.end -2c', $step . '.end' );
            $selection = '<div class="poem"><div class="stanza">';
            $textwindow->ntinsert( $step . '.end', $selection );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }
        if ( $selection =~ /^\x7f*\/\#/ ) {
            $blkquot = 1;
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            $selection = $textwindow->get( "$step.0", "$step.end" );
            $selection =~ s/^\s+//;
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $textwindow->ntinsert( "$step.0", $blkopen . $selection );

            if ( ( $last5[1] ) && ( !$last5[2] ) ) {
                $textwindow->ntinsert( ( $step - 3 ) . ".end", '</p>' )
                    unless (
                    $textwindow->get( ( $step - 3 ) . '.0',
                        ( $step - 2 ) . '.end' )
                    =~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/
                    );
            }
            $textwindow->ntinsert( ($step) . ".end", '</p>' )
                unless (
                length $textwindow->get(
                    ( $step + 1 ) . '.0',
                    ( $step + 1 ) . '.end'
                )
                );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }
        if ( $selection =~ /^\x7f*\/[Ll]/ ) {
            $listmark = 1;
            if ( ( $last5[2] ) && ( !$last5[3] ) ) {
                $textwindow->ntinsert( ( $step - 2 ) . ".end", '</p>' )
                    unless (
                    $textwindow->get( ( $step - 2 ) . '.0',
                        ( $step - 2 ) . '.end' ) =~ /<\/p>/
                    );
            }
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $step++;
            $selection = $textwindow->get( "$step.0", "$step.end" );
            $selection = '<ul><li>' . $selection . '</li>';
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $textwindow->ntinsert( "$step.0", $selection );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }
        if ( $selection =~ /^\x7f*\#\// ) {
            $blkquot = 0;
            $textwindow->ntinsert( ( $step - 1 ) . '.end', $blkclose );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }
        if ( $selection =~ /^\x7f*[Ll]\// ) {
            $listmark = 0;
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $textwindow->ntinsert( "$step.end", '</ul>' );
            push @last5, '</ul>';
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }
        if ($listmark) {
            if ( $selection eq '' ) { $step++; next; }
            $textwindow->ntdelete( "$step.0", "$step.end" );
            my ( $op, $cl ) = ( 0, 0 );
            while ( ( my $temp = index $selection, '<i>', $op ) > 0 ) {
                $op = $temp + 3;
            }
            while ( ( my $temp = index $selection, '</i>', $cl ) > 0 ) {
                $cl = $temp + 4;
            }
            if ( !$cl && $ital ) {
                $selection .= '</i>';
            }
            if ( !$op && $ital ) {
                $selection = '<i>' . $selection;
            }
            if ( $op && $cl && ( $cl < $op ) && $ital ) {
                $selection = '<i>' . $selection;
                $selection .= '</i>';
            }
            if ( $op && ( $cl < $op ) && !$ital ) {
                $selection .= '</i>';
                $ital = 1;
            }
            if ( $cl && ( $op < $cl ) && $ital ) {
                if ($op) {
                    $selection = '<i>' . $selection;
                }
                $ital = 0;
            }
            $textwindow->ntinsert( "$step.0", '<li>' . $selection . '</li>' );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }
        if ($blkquot) {
            if ( $selection =~ s/^(\s+)// ) {
                my $space = length $1;
                $textwindow->ntdelete( "$step.0", "$step.0 +${space}c" );
            }
        }
        if ( $selection =~ /^\x7f*[\$\*]\// ) {
            $inblock = 0;
            $ital    = 0;
            $textwindow->replacewith( "$step.0", "$step.end", '</p>' );
            $step++;
            next;
        }
        if ( $selection =~ /^\x7f*\/[\$\*]/ ) {
            $inblock = 1;
            if ( ( $last5[2] ) && ( !$last5[3] ) ) {
                $textwindow->ntinsert( ( $step - 2 ) . '.end', '</p>' )
                    unless (
                    (   $textwindow->get( ( $step - 2 ) . '.0',
                            ( $step - 2 ) . '.end' )
                        =~ /<\/?[hd]\d?|<br.*?>|<\/p>/
                    )
                    );
            }
            $textwindow->replacewith( "$step.0", "$step.end", '<p>' );
            $step++;
            next;
        }
        if ( ( $last5[2] ) && ( !$last5[3] ) ) {
            $textwindow->ntinsert( ( $step - 2 ) . '.end', '</p>' )
                unless (
                (   $textwindow->get( ( $step - 2 ) . '.0',
                        ( $step - 2 ) . '.end' )
                    =~ /<\/?[hd]\d?|<br.*?>|<\/p>|<\/[uo]l>/
                )
                || ($inblock)
                );
        }
        if ( $inblock || ( $selection =~ /^\s/ ) ) {
            if ( $last5[3] ) {
                if ( $last5[3] =~ /^\S/ ) {
                    $last5[3] .= '<br />';
                    $textwindow->ntdelete( ( $step - 1 ) . '.0',
                        ( $step - 1 ) . '.end' );
                    $textwindow->ntinsert( ( $step - 1 ) . '.0', $last5[3] );
                }
            }
            $thisend = $textwindow->index( $step . ".end" );
            $textwindow->ntinsert( $thisend, '<br />' );
            if ( $selection =~ /^(\s+)/ ) {
                $indent = ( length($1) / 2 );
                $selection =~ s/^\s+//;
                $selection =~ s/  /&nbsp; /g;
                $selection
                    =~ s/(&nbsp; ){1,}\s?(<span class="linenum">)/ $2/g;
                my ( $op, $cl ) = ( 0, 0 );
                while ( ( my $temp = index $selection, '<i>', $op ) > 0 ) {
                    $op = $temp + 3;
                }
                while ( ( my $temp = index $selection, '</i>', $cl ) > 0 ) {
                    $cl = $temp + 4;
                }
                if ( !$cl && $ital ) {
                    $selection .= '</i>';
                }
                if ( !$op && $ital ) {
                    $selection = '<i>' . $selection;
                }
                if ( $op && $cl && ( $cl < $op ) && $ital ) {
                    $selection = '<i>' . $selection;
                    $selection .= '</i>';
                }
                if ( $op && ( $cl < $op ) && !$ital ) {
                    $selection .= '</i>';
                    $ital = 1;
                }
                if ( $cl && ( $op < $cl ) && $ital ) {
                    if ($op) {
                        $selection = '<i>' . $selection;
                    }
                    $ital = 0;
                }
                $selection
                    = '<span style="margin-left: ' 
                    . $indent . 'em;">'
                    . $selection
                    . '</span>';
                $textwindow->ntdelete( "$step.0", $thisend );
                $textwindow->ntinsert( "$step.0", $selection );
            }
            if ( ( $last5[2] ) && ( !$last5[3] ) && ( $selection =~ /\/\*/ ) )
            {
                $textwindow->ntinsert( ( $step - 2 ) . ".end", '</p>' )
                    unless (
                    $textwindow->get( ( $step - 2 ) . '.0',
                        ( $step - 2 ) . '.end' ) =~ /<\/[hd]\d?/
                    );
            }
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }
        {

            no warnings qw/uninitialized/;
            if (   ( !$last5[0] )
                && ( !$last5[1] )
                && ( !$last5[2] )
                && ( !$last5[3] )
                && ($selection) )
            {
                $textwindow->ntinsert( ( $step - 1 ) . '.0',
                    '<hr style="width: 65%;" />' )
                    unless ( $selection =~ /<[ph]/ );
                $aname =~ s/<\/?[hscalup].*?>//g;
                $aname = makeanchor( deaccent($selection) );
                $textwindow->ntinsert( "$step.0",
                          "<h2><a name=\"" 
                        . $aname
                        . "\" id=\""
                        . $aname
                        . "\"></a>" )
                    unless ( $selection =~ /<[ph]/ );
                $textwindow->ntinsert( "$step.end", '</h2>' )
                    unless ( $selection =~ /<[ph]/ );
                unless ( $selection =~ /<p/ ) {
                    $selection =~ s/<sup>.*?<\/sup>//g;
                    $selection =~ s/<[^>]+>//g;
                    $selection = "<b>$selection</b>";
                    push @contents,
                          "<a href=\"#" 
                        . $aname . "\">"
                        . $selection
                        . "</a><br />\n";
                }
                $selection .= '<h2>';
                $textwindow->see("$step.0");
                $textwindow->update;
            }
            elsif ( ( $last5[2] =~ /<h2>/ ) && ($selection) ) {
                $textwindow->ntinsert( "$step.0", '<p>' )
                    unless ( ( $selection =~ /<[pd]/ )
                    || ( $selection =~ /<[hb]r>/ )
                    || ($inblock) );
            }
            elsif ( ( $last5[2] ) && ( !$last5[3] ) && ($selection) ) {
                $textwindow->ntinsert( "$step.0", '<p>' )
                    unless ( ( $selection =~ /<[phd]/ )
                    || ( $selection =~ /<[hb]r>/ )
                    || ($inblock) );
            }
            elsif (( $last5[1] )
                && ( !$last5[2] )
                && ( !$last5[3] )
                && ($selection) )
            {
                $textwindow->ntinsert( "$step.0", '<p>' )
                    unless ( ( $selection =~ /<[phd]/ )
                    || ( $selection =~ /<[hb]r>/ )
                    || ($inblock) );
            }
            elsif (( $last5[0] )
                && ( !$last5[1] )
                && ( !$last5[2] )
                && ( !$last5[3] )
                && ($selection) )
            {
                $textwindow->ntinsert( "$step.0", '<p>' )
                    unless ( ( $selection =~ /<[phd]/ )
                    || ( $selection =~ /<[hb]r>/ )
                    || ($inblock) );
            }
        }
        push @last5, $selection;
        shift @last5 while ( scalar(@last5) > 4 );
        $step++;
    }
    push @contents, '</p>';

    html_cleanup_markers( $thisblockstart, $ler, $lec, $thisblockend );

#    working("Cleaning up\nblock Markers");
#    while ( $thisblockstart
#        = $textwindow->search( '-regexp', '--', '^\/[\*\$\#]', '1.0', 'end' )
#        )
#    {
#        ( $ler, $lec ) = split /\./, $thisblockstart;
#        $thisblockend = "$ler.end";
#        $textwindow->ntdelete( "$thisblockstart-1c", $thisblockend );
#    }
#    while ( $thisblockstart
#        = $textwindow->search( '-regexp', '--', '^[\*\$\#]\/', '1.0', 'end' )
#        )
#    {
#        ( $ler, $lec ) = split /\./, $thisblockstart;
#        $thisblockend = "$ler.end";
#        $textwindow->ntdelete( "$thisblockstart-1c", $thisblockend );
#    }
#    while ( $thisblockstart
#        = $textwindow->search( '-regexp', '--', '<\/h\d><br />', '1.0',
#            'end' ) )
#    {
#        $textwindow->ntdelete( "$thisblockstart+5c", "$thisblockstart+9c" );
#    }

    working("Converting underscore and small caps markup");
    while ( $thisblockstart
        = $textwindow->search( '-exact', '--', '<u>', '1.0', 'end' ) )
    {
        $textwindow->ntdelete( $thisblockstart, "$thisblockstart+3c" );
        $textwindow->ntinsert( $thisblockstart, '<span class="u">' );
    }
    while ( $thisblockstart
        = $textwindow->search( '-exact', '--', '</u>', '1.0', 'end' ) )
    {
        $textwindow->ntdelete( $thisblockstart, "$thisblockstart+4c" );
        $textwindow->ntinsert( $thisblockstart, '</span>' );
    }
    while ( $thisblockstart
        = $textwindow->search( '-exact', '--', '<sc>', '1.0', 'end' ) )
    {
        $textwindow->ntdelete( $thisblockstart, "$thisblockstart+4c" );
        $textwindow->ntinsert( $thisblockstart, '<span class="smcap">' );
    }
    while ( $thisblockstart
        = $textwindow->search( '-exact', '--', '</sc>', '1.0', 'end' ) )
    {
        $textwindow->ntdelete( $thisblockstart, "$thisblockstart+5c" );
        $textwindow->ntinsert( $thisblockstart, '</span>' );
    }
    while ( $thisblockstart
        = $textwindow->search( '-exact', '--', '</pre></p>', '1.0', 'end' ) )
    {
        $textwindow->ntdelete( "$thisblockstart+6c", "$thisblockstart+10c" );
    }
    $thisblockstart = '1.0';
    while (
        $thisblockstart = $textwindow->search(
            '-exact', '--', '<p>FOOTNOTES:', $thisblockstart, 'end'
        )
        )
    {
        $textwindow->ntdelete( $thisblockstart, "$thisblockstart+17c" );
        $textwindow->insert( $thisblockstart,
            '<div class="footnotes"><h3>FOOTNOTES:</h3>' );
        $thisblockstart
            = $textwindow->search( '-exact', '--', '<hr', $thisblockstart,
            'end' );
        if ($thisblockstart) {
            $textwindow->insert( "$thisblockstart-3l", '</div>' );
        }
        else {
            $textwindow->insert( 'end-1l', '</div>' );
            last;
        }
    }

    working("Converting\nSidenotes");
    my $thisnoteend;
    my $length;
    while (
        $thisblockstart = $textwindow->search(
            '-regexp',
            '-count' => \$length,
            '--', '(<p>)?\[Sidenote:\s*', '1.0', 'end'
        )
        )
    {
        $textwindow->ntdelete( $thisblockstart,
            $thisblockstart . '+' . $length . 'c' );
        $textwindow->ntinsert( $thisblockstart, '<div class="sidenote">' );
        $thisnoteend
            = $textwindow->search( '--', ']', $thisblockstart, 'end' );
        while (
            $textwindow->get( "$thisblockstart+1c", $thisnoteend ) =~ /\[/ )
        {
            $thisblockstart = $thisnoteend;
            $thisnoteend
                = $textwindow->search( '--', ']</p>', $thisblockstart,
                'end' );
        }
        $textwindow->ntdelete( $thisnoteend, "$thisnoteend+5c" )
            if $thisnoteend;
        $textwindow->ntinsert( $thisnoteend, '</div>' ) if $thisnoteend;
    }
    while ( $thisblockstart
        = $textwindow->search( '--', '</div></div></p>', '1.0', 'end' ) )
    {
        $textwindow->ntdelete( "$thisblockstart+12c", "$thisblockstart+16c" );
    }
    if ( $lglobal{pageanch} || $lglobal{pagecmt} ) {

        working("Inserting Page Markup");
        $|++;
        my ( $mark, $markindex );
        my @marknames = sort $textwindow->markNames;
        for $mark (@marknames) {
            if ( $mark =~ /Pg(\S+)/ ) {
                my $num = $pagenumbers{$mark}{label};
                $num =~ s/Pg // if defined $num;
                $num = $1 unless $pagenumbers{$mark}{action};
                next unless length $num;
                $num =~ s/^0+(\d)/$1/;
                $markindex = $textwindow->index($mark);
                my $check = $textwindow->get(
                    $markindex . 'linestart',
                    $markindex . 'linestart +4c'
                );
                if ( $check =~ /<h[12]>/ ) {
                    $markindex = $textwindow->index("$mark-1l lineend")
                        ;    # FIXME: HTML page number hangs here
                }
                $textwindow->ntinsert( $markindex,
                    "<span class=\"pagenum\"><a name=\"Page_$num\" id=\"Page_$num\">[Pg $num]</a></span>"
                ) if $lglobal{pageanch};

#$textwindow->ntinsert($markindex,"<span class="pagenum" id=\"Page_".$num."\">[Pg $num]</span>") if $lglobal{pageanch};
# FIXME: this is hanging up somewhere.
                $textwindow->ntinsert( $markindex,
                    '<!-- Page ' . $num . ' -->' )
                    if ( $lglobal{pagecmt} and $num );
                my $pstart
                    = $textwindow->search( '-backwards', '-exact', '--',
                    '<p>', $markindex, '1.0' )
                    || '1.0';
                my $pend
                    = $textwindow->search( '-backwards', '-exact', '--',
                    '</p>', $markindex, '1.0' )
                    || '1.0';
                my $sstart
                    = $textwindow->search( '-backwards', '-exact', '--',
                    '<div ', $markindex, '1.0' )
                    || '1.0';
                my $send
                    = $textwindow->search( '-backwards', '-exact', '--',
                    '</div>', $markindex, $pend )
                    || $pend;
                if ( $textwindow->compare( $pend, '>=', $pstart ) ) {
                    $textwindow->ntinsert( $markindex, '<p>' )
                        unless (
                        $textwindow->compare( $send, '<', $sstart ) );
                }
                my $anchorend
                    = $textwindow->search( '-exact', '--', ']</a></span>',
                    $markindex, 'end' );
                $anchorend = $textwindow->index("$anchorend+12c");
                $pstart
                    = $textwindow->search( '-exact', '--', '<p>', $anchorend,
                    'end' )
                    || 'end';
                $pend
                    = $textwindow->search( '-exact', '--', '</p>', $anchorend,
                    'end' )
                    || 'end';
                $sstart
                    = $textwindow->search( '-exact', '--', '<div ',
                    $anchorend, 'end' )
                    || 'end';
                $send
                    = $textwindow->search( '-exact', '--', '</div>',
                    $anchorend, $sstart )
                    || $sstart;
                if ( $textwindow->compare( $pend, '>=', $pstart ) ) {
                    $textwindow->ntinsert( $anchorend, '</p>' )
                        unless (
                        $textwindow->compare( $send, '<', $sstart ) );
                }
            }
        }
    }
    {
        local $" = '';
        $textwindow->insert( $incontents,
            "\n\n<!-- Autogenerated TOC. Modify or delete as required. -->\n@contents\n<!-- End Autogenerated TOC. -->\n\n"
        ) if @contents;
    }

    working("Converting Named\n and Numeric Characters");
    named( ' >', ' &gt;' );
    named( '< ', '&lt; ' );

    if ( !$lglobal{keep_latin1} ) { html_convert_latin1(); }

    html_convert_utf($thisblockstart);

 #    if ( $lglobal{leave_utf} ) {
 #        $thisblockstart
 #            = $textwindow->search( '-exact', '--', 'charset=iso-8859-1',
 #            '1.0', 'end' );
 #        if ($thisblockstart) {
 #            $textwindow->ntdelete( $thisblockstart, "$thisblockstart+18c" );
 #            $textwindow->ntinsert( $thisblockstart, 'charset=UTF-8' );
 #        }
 #    }
 #    unless ( $lglobal{leave_utf} ) {
 #        while (
 #            $thisblockstart = $textwindow->search(
 #                '-regexp', '--', '[\x{100}-\x{65535}]', '1.0', 'end'
 #            )
 #            )
 #        {
 #            my $xchar = ord( $textwindow->get($thisblockstart) );
 #            $textwindow->ntdelete($thisblockstart);
 #            $textwindow->ntinsert( $thisblockstart, "&#$xchar;" );
 #        }
 #    }

    fracconv( '1.0', 'end' ) if $lglobal{autofraction};
    $textwindow->ntinsert( '1.0', $headertext );
    if ( $lglobal{leave_utf} ) {
        $thisblockstart
            = $textwindow->search( '-exact', '--', 'charset=iso-8859-1',
            '1.0', 'end' );
        if ($thisblockstart) {
            $textwindow->ntdelete( $thisblockstart, "$thisblockstart+18c" );
            $textwindow->ntinsert( $thisblockstart, 'charset=utf-8' );
        }
    }
    $textwindow->ntinsert( 'end', "\n<\/body>\n<\/html>" );
    $thisblockstart = $textwindow->search( '--', '</style', '1.0', '250.0' );
    $thisblockstart = '75.0' unless $thisblockstart;
    $thisblockstart
        = $textwindow->search( -backwards, '--', '}', $thisblockstart,
        '10.0' );
    for ( reverse( sort( values( %{ $lglobal{classhash} } ) ) ) ) {
        $textwindow->ntinsert( $thisblockstart . ' +1l linestart', $_ )
            if keys %{ $lglobal{classhash} };
    }
    %{ $lglobal{classhash} } = ();
    working();
    $textwindow->Unbusy;
    $textwindow->see('1.0');
}

sub entity {
    my $char       = shift;
    my %markuphash = (
        '\x80' => '&#8364;',
        '\x81' => '&#129;',
        '\x82' => '&#8218;',
        '\x83' => '&#402;',
        '\x84' => '&#8222;',
        '\x85' => '&#8230;',
        '\x86' => '&#8224;',
        '\x87' => '&#8225;',
        '\x88' => '&#710;',
        '\x89' => '&#8240;',
        '\x8a' => '&#352;',
        '\x8b' => '&#8249;',
        '\x8c' => '&#338;',
        '\x8d' => '&#141;',
        '\x8e' => '&#381;',
        '\x8f' => '&#143;',
        '\x90' => '&#144;',
        '\x91' => '&#8216;',
        '\x92' => '&#8217;',
        '\x93' => '&#8220;',
        '\x94' => '&#8221;',
        '\x95' => '&#8226;',
        '\x96' => '&#8211;',
        '\x97' => '&#8212;',
        '\x98' => '&#732;',
        '\x99' => '&#8482;',
        '\x9a' => '&#353;',
        '\x9b' => '&#8250;',
        '\x9c' => '&#339;',
        '\x9d' => '&#157;',
        '\x9e' => '&#382;',
        '\x9f' => '&#376;',
        '\xa0' => '&nbsp;',
        '\xa1' => '&iexcl;',
        '\xa2' => '&cent;',
        '\xa3' => '&pound;',
        '\xa4' => '&curren;',
        '\xa5' => '&yen;',
        '\xa6' => '&brvbar;',
        '\xa7' => '&sect;',
        '\xa8' => '&uml;',
        '\xa9' => '&copy;',
        '\xaa' => '&ordf;',
        '\xab' => '&laquo;',
        '\xac' => '&not;',
        '\xad' => '&shy;',
        '\xae' => '&reg;',
        '\xaf' => '&macr;',
        '\xb0' => '&deg;',
        '\xb1' => '&plusmn;',
        '\xb2' => '&sup2;',
        '\xb3' => '&sup3;',
        '\xb4' => '&acute;',
        '\xb5' => '&micro;',
        '\xb6' => '&para;',
        '\xb7' => '&middot;',
        '\xb8' => '&cedil;',
        '\xb9' => '&sup1;',
        '\xba' => '&ordm;',
        '\xbb' => '&raquo;',
        '\xbc' => '&frac14;',
        '\xbd' => '&frac12;',
        '\xbe' => '&frac34;',
        '\xbf' => '&iquest;',
        '\xc0' => '&Agrave;',
        '\xc1' => '&Aacute;',
        '\xc2' => '&Acirc;',
        '\xc3' => '&Atilde;',
        '\xc4' => '&Auml;',
        '\xc5' => '&Aring;',
        '\xc6' => '&AElig;',
        '\xc7' => '&Ccedil;',
        '\xc8' => '&Egrave;',
        '\xc9' => '&Eacute;',
        '\xca' => '&Ecirc;',
        '\xcb' => '&Euml;',
        '\xcc' => '&Igrave;',
        '\xcd' => '&Iacute;',
        '\xce' => '&Icirc;',
        '\xcf' => '&Iuml;',
        '\xd0' => '&ETH;',
        '\xd1' => '&Ntilde;',
        '\xd2' => '&Ograve;',
        '\xd3' => '&Oacute;',
        '\xd4' => '&Ocirc;',
        '\xd5' => '&Otilde;',
        '\xd6' => '&Ouml;',
        '\xd7' => '&times;',
        '\xd8' => '&Oslash;',
        '\xd9' => '&Ugrave;',
        '\xda' => '&Uacute;',
        '\xdb' => '&Ucirc;',
        '\xdc' => '&Uuml;',
        '\xdd' => '&Yacute;',
        '\xde' => '&THORN;',
        '\xdf' => '&szlig;',
        '\xe0' => '&agrave;',
        '\xe1' => '&aacute;',
        '\xe2' => '&acirc;',
        '\xe3' => '&atilde;',
        '\xe4' => '&auml;',
        '\xe5' => '&aring;',
        '\xe6' => '&aelig;',
        '\xe7' => '&ccedil;',
        '\xe8' => '&egrave;',
        '\xe9' => '&eacute;',
        '\xea' => '&ecirc;',
        '\xeb' => '&euml;',
        '\xec' => '&igrave;',
        '\xed' => '&iacute;',
        '\xee' => '&icirc;',
        '\xef' => '&iuml;',
        '\xf0' => '&eth;',
        '\xf1' => '&ntilde;',
        '\xf2' => '&ograve;',
        '\xf3' => '&oacute;',
        '\xf4' => '&ocirc;',
        '\xf5' => '&otilde;',
        '\xf6' => '&ouml;',
        '\xf7' => '&divide;',
        '\xf8' => '&oslash;',
        '\xf9' => '&ugrave;',
        '\xfa' => '&uacute;',
        '\xfb' => '&ucirc;',
        '\xfc' => '&uuml;',
        '\xfd' => '&yacute;',
        '\xfe' => '&thorn;',
        '\xff' => '&yuml;',
    );
    my %pukramhash = reverse %markuphash;
    return $markuphash{$char} if $markuphash{$char};
    return $pukramhash{$char} if $pukramhash{$char};
    return $char;
}

sub named {
    my ( $from, $to, $start, $end ) = @_;
    my $length;
    my $searchstartindex = $start;
    $searchstartindex = '1.0' unless $searchstartindex;
    $end              = 'end' unless $end;
    $textwindow->markSet( 'srchend', $end );
    while (
        $searchstartindex = $textwindow->search(
            '-regexp',
            '-count' => \$length,
            '--', $from, $searchstartindex, 'srchend'
        )
        )
    {
        $textwindow->ntdelete( $searchstartindex,
            $searchstartindex . '+' . $length . 'c' );
        $textwindow->ntinsert( $searchstartindex, $to );
        $searchstartindex = $textwindow->index("$searchstartindex+1c");
    }
}

# FIXME: Page separator removal help
sub phelppopup {
    my $help_text = <<EOM;
Join Lines - join lines removing any spaces, asterisks and hyphens as necessary. - Hotkey j
Join, Keep hyphen - join lines removing any spaces and asterisks as necessary. - Hotkey k
Blank line - remove spaces as necessary. Keep one blank line. (paragraph break). - Hotkey l
New Section - remove spaces as necessary. Keep two blank lines (section break). - Hotkey t
New Chapter - remove spaces as necessary. Keep four blank lines (chapter break). - Hotkey h
Refresh - search for and center next page separator. - Hotkey r
Undo - undo the previous page separator edit. - Hotkey u
Delete - delete the page separator. Make no other edits. - Hotkey d
Full Auto - automatically search for and convert if possible the next page separator. - Toggle - a
Semi Auto - automatically search for and center the next page separator after an edit. - Toggle - s
EOM

    if ( defined( $lglobal{phelppop} ) ) {
        $lglobal{phelppop}->deiconify;
        $lglobal{phelppop}->raise;
        $lglobal{phelppop}->focus;
    }
    else {
        $lglobal{phelppop} = $top->Toplevel;
        $lglobal{phelppop}->title('Functions and Hotkeys');
        $lglobal{phelppop}->Label(
            -justify => "left",
            -text    => $help_text
        )->pack;
        my $button_ok = $lglobal{phelppop}->Button(
            -activebackground => $activecolor,
            -text             => 'OK',
            -command =>
                sub { $lglobal{phelppop}->destroy; undef $lglobal{phelppop} }
        )->pack;
        $lglobal{phelppop}->resizable( 'no', 'no' );
        $lglobal{phelppop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{phelppop}->destroy; undef $lglobal{phelppop} }
        );
        $lglobal{phelppop}->Icon( -image => $icon );
    }
}

sub convertfilnum {
    viewpagenums() if ( $lglobal{seepagenums} );
    $lglobal{joinundo} = 0;
    my ( $filenum, $line, $rnd1, $rnd2, $page );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    $searchstartindex = '1.0';
    $searchendindex   = '1.0';
    $searchstartindex
        = $textwindow->search( '-nocase', '-regexp', '--', '^-----*\s?File:',
        $searchendindex, 'end' );
    return unless $searchstartindex;
    $searchendindex = $textwindow->index("$searchstartindex lineend");
    $line = $textwindow->get( $searchstartindex, $searchendindex );
    $textwindow->tagAdd( 'highlight', $searchstartindex, $searchendindex )
        if $searchstartindex;
    $textwindow->yview('end');
    $textwindow->see($searchstartindex) if $searchstartindex;

    if ( $lglobal{jautomatic} && $searchstartindex ) {
        my ($index);
        $textwindow->markSet( 'page',  $searchstartindex );
        $textwindow->markSet( 'page1', "$searchstartindex+1l" );
        while (1) {
            $index = $textwindow->index('page');
            $line  = $textwindow->get("$index-1c");
            if ( ( $line =~ /[\s\n]$/ ) || ( $line =~ /[\w-]\*$/ ) ) {
                $textwindow->delete("$index-1c");
                $lglobal{joinundo}++;
            }
            else {
                last;
            }
        }
        $textwindow->insert( $index, "\n" );
        $lglobal{joinundo}++;
        if ( $line =~ /[\w;,]/ ) {
            while (1) {
                $index = $textwindow->index('page1');
                $line  = $textwindow->get($index);
                if ( $line =~ /[\n\*]/ ) {
                    $textwindow->delete($index);
                    $lglobal{joinundo}++;
                    last if $textwindow->compare( 'page1 +1l', '>=', 'end' );
                }
                else {
                    last;
                }
            }
        }
        if ( ( $line =~ /\p{IsLower}/ ) || ( $line =~ /^I / ) ) {
            joinlines('j');
        }
        my ( $r, $c ) = split /\./, $textwindow->index('page-1c');
        my ($size)
            = length(
            $textwindow->get( 'page+1l linestart', 'page+1l lineend' ) );
        if ( ( $line =~ /[\.\"\'\?]/ ) && ( $c < ( $size * 0.5 ) ) ) {
            joinlines('l');
        }
    }
    $textwindow->xviewMoveto(.0);
    $textwindow->markSet( 'insert', "$searchstartindex+2l" )
        if $searchstartindex;
}

sub showproofers {
    if ( defined( $lglobal{prooferpop} ) ) {
        $lglobal{prooferpop}->deiconify;
        $lglobal{prooferpop}->raise;
        $lglobal{prooferpop}->focus;
    }
    else {
        $lglobal{prooferpop} = $top->Toplevel;
        $lglobal{prooferpop}->title('Proofers For This File');
        my $bframe = $lglobal{prooferpop}->Frame->pack;

        $bframe->Button(
            -activebackground => $activecolor,
            -command          => sub {
                my @ranges      = $lglobal{prfrrotextbox}->tagRanges('sel');
                my $range_total = @ranges;
                my $proofer     = '';
                if ($range_total) {
                    $proofer = $lglobal{prfrrotextbox}
                        ->get( $ranges[0], $ranges[1] );
                    $proofer =~ s/^\s+//;
                    $proofer =~ s/\s\s.*//s;
                    $proofer =~ s/\s/%20/g;
                }
                prfrmessage($proofer);
            },
            -text  => 'Send Message',
            -width => 12
        )->grid( -row => 1, -column => 1, -padx => 3, -pady => 3 );
        $bframe->Button(
            -activebackground => $activecolor,
            -command          => \&prfrbypage,
            -text             => 'Page',
            -width            => 12
        )->grid( -row => 2, -column => 1, -padx => 3, -pady => 3 );
        $bframe->Button(
            -activebackground => $activecolor,
            -command          => \&prfrbyname,
            -text             => 'Name',
            -width            => 12
        )->grid( -row => 1, -column => 2, -padx => 3, -pady => 3 );
        $bframe->Button(
            -activebackground => $activecolor,
            -command          => sub { prfrby(0) },
            -text             => 'Total',
            -width            => 12
        )->grid( -row => 2, -column => 2, -padx => 3, -pady => 3 );
        for my $round ( 1 .. $lglobal{numrounds} ) {
            $bframe->Button(
                -activebackground => $activecolor,
                -command          => [ sub { prfrby( $_[0] ) }, $round ],
                -text             => "Round $round",
                -width            => 12
                )->grid(
                -row => ( ( $round + 1 ) % 2 ) + 1,
                -column => int( ( $round + 5 ) / 2 ),
                -padx   => 3,
                -pady   => 3
                );
        }
        my $frame = $lglobal{prooferpop}->Frame->pack(
            -anchor => 'nw',
            -expand => 'yes',
            -fill   => 'both'
        );
        $lglobal{prfrrotextbox} = $frame->Scrolled(
            'ROText',
            -scrollbars => 'se',
            -background => 'white',
            -font       => '{Courier} 10',
            -width      => 80,
            -height     => 40,
            -wrap       => 'none',
        )->pack( -anchor => 'nw', -expand => 'yes', -fill => 'both' );
        delete $proofers{''};
        drag( $lglobal{prfrrotextbox} );
        prfrbypage();
        $lglobal{prooferpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{prooferpop}->destroy;
                undef $lglobal{prooferpop};
            }
        );
        $lglobal{prooferpop}->Icon( -image => $icon );
    }
}

sub prfrmessage {
    my $proofer = shift;
    if ( $proofer eq '' ) {
        runner("$globalbrowserstart $no_proofer_url");
    }
    else {
        runner("$globalbrowserstart $yes_proofer_url$proofer");
    }
}

sub prfrhdr {
    my ($max) = @_;
    $lglobal{prfrrotextbox}
        ->insert( 'end', sprintf( "%*s     ", ( -$max ), '   Name' ) );
    for ( 1 .. $lglobal{numrounds} ) {
        $lglobal{prfrrotextbox}
            ->insert( 'end', sprintf( " %-8s", "Round $_" ) );
    }
    $lglobal{prfrrotextbox}->insert( 'end', sprintf( " %-8s\n", 'Total' ) );
}

sub prfrbypage {
    my @max = split //, ( '8' x ( $lglobal{numrounds} + 1 ) );
    for my $page ( keys %proofers ) {
        for my $round ( 1 .. $lglobal{numrounds} ) {
            my $name = $proofers{$page}->[$round];
            next unless defined $name;
            $max[$round] = length $name if length $name > $max[$round];
        }
    }
    $lglobal{prfrrotextbox}->delete( '1.0', 'end' );
    $lglobal{prfrrotextbox}->insert( 'end', sprintf( "%-8s", 'Page' ) );
    for my $round ( 1 .. $lglobal{numrounds} ) {
        $lglobal{prfrrotextbox}->insert( 'end',
            sprintf( " %*s", ( -$max[$round] - 2 ), "Round $round" ) );
    }
    $lglobal{prfrrotextbox}->insert( 'end', "\n" );
    delete $proofers{''};
    for my $page ( sort keys %proofers ) {
        $lglobal{prfrrotextbox}->insert( 'end', sprintf( "%-8s", $page ) );
        for my $round ( 1 .. $lglobal{numrounds} ) {
            $lglobal{prfrrotextbox}->insert(
                'end',
                sprintf( " %*s",
                    ( -$max[$round] - 2 ),
                    $proofers{$page}->[$round] || '<none>' )
            );
        }
        $lglobal{prfrrotextbox}->insert( 'end', "\n" );
    }
}

sub prfrbyname {
    my ( $page, $prfr, %proofersort );
    my $max = 8;
    for $page ( keys %proofers ) {
        for ( 1 .. $lglobal{numrounds} ) {
            $max = length $proofers{$page}->[$_]
                if ( $proofers{$page}->[$_]
                and length $proofers{$page}->[$_] > $max );
        }
    }
    $lglobal{prfrrotextbox}->delete( '1.0', 'end' );
    foreach $page ( keys %proofers ) {
        for ( 1 .. $lglobal{numrounds} ) {
            $proofersort{ $proofers{$page}->[$_] }[$_]++
                if $proofers{$page}->[$_];
            $proofersort{ $proofers{$page}->[$_] }[0]++
                if $proofers{$page}->[$_];
        }
    }
    prfrhdr($max);
    delete $proofersort{''};
    foreach $prfr ( sort { deaccent( lc($a) ) cmp deaccent( lc($b) ) }
        ( keys %proofersort ) )
    {
        for ( 1 .. $lglobal{numrounds} ) {
            $proofersort{$prfr}[$_] = "0" unless $proofersort{$prfr}[$_];
        }
        $lglobal{prfrrotextbox}
            ->insert( 'end', sprintf( "%*s", ( -$max - 2 ), $prfr ) );
        for ( 1 .. $lglobal{numrounds} ) {
            $lglobal{prfrrotextbox}
                ->insert( 'end', sprintf( " %8s", $proofersort{$prfr}[$_] ) );
        }
        $lglobal{prfrrotextbox}
            ->insert( 'end', sprintf( " %8s\n", $proofersort{$prfr}[0] ) );
    }
}

sub prfrby {
    my $which = shift;
    my ( $page, $prfr, %proofersort, %ptemp );
    my $max = 8;
    for $page ( keys %proofers ) {
        for ( 1 .. $lglobal{numrounds} ) {
            $max = length $proofers{$page}->[$_]
                if ( $proofers{$page}->[$_]
                and length $proofers{$page}->[$_] > $max );
        }
    }
    $lglobal{prfrrotextbox}->delete( '1.0', 'end' );
    foreach $page ( keys %proofers ) {
        for ( 1 .. $lglobal{numrounds} ) {
            $proofersort{ $proofers{$page}->[$_] }[$_]++
                if $proofers{$page}->[$_];
            $proofersort{ $proofers{$page}->[$_] }[0]++
                if $proofers{$page}->[$_];
        }
    }
    foreach $prfr ( keys(%proofersort) ) {
        $ptemp{$prfr} = ( $proofersort{$prfr}[$which] || '0' );
    }
    delete $ptemp{''};
    prfrhdr($max);
    foreach $prfr (
        sort {
            $ptemp{$b} <=> $ptemp{$a}
                || ( deaccent( lc($a) ) cmp deaccent( lc($b) ) )
        } keys %ptemp
        )
    {
        $lglobal{prfrrotextbox}
            ->insert( 'end', sprintf( "%*s", ( -$max - 2 ), $prfr ) );
        for ( 1 .. $lglobal{numrounds} ) {
            $lglobal{prfrrotextbox}->insert( 'end',
                sprintf( " %8s", $proofersort{$prfr}[$_] || '0' ) );
        }
        $lglobal{prfrrotextbox}
            ->insert( 'end', sprintf( " %8s\n", $proofersort{$prfr}[0] ) );
    }
}

sub joinlines {
    viewpagenums() if ( $lglobal{seepagenums} );
    my $op = shift;
    my ( $line, $index, $r, $c );
    $searchstartindex = '1.0';
    $searchendindex   = '1.0';
    $searchstartindex
        = $textwindow->search( '-regexp', '--', '^-----*\s?File:',
        $searchendindex, 'end' );
    unless ($searchstartindex) {
        $textwindow->bell unless $nobell;
        return;
    }
    $searchendindex = $textwindow->index("$searchstartindex lineend");
    $textwindow->see($searchstartindex) if $searchstartindex;
    $textwindow->update;
    my $pagesep = $textwindow->get( $searchstartindex, $searchendindex )
        if ( $searchstartindex && $searchendindex );
    my $pagemark = $pagesep;
    $pagesep =~ m/^-----*\s?File:\s?(\S+)\./;
    return unless $1;
    $pagesep  = " <!--Pg$1-->";
    $pagemark = 'Pg' . $1;
    $textwindow->delete( $searchstartindex, $searchendindex )
        if ( $searchstartindex && $searchendindex );
    $textwindow->markSet( 'page',    $searchstartindex );
    $textwindow->markSet( $pagemark, "$searchstartindex-1c" );
    $textwindow->markGravity( $pagemark, 'left' );
    $textwindow->markSet( 'insert', "$searchstartindex+1c" );
    $index = $textwindow->index('page');

    unless ( $op eq 'd' ) {
        while (1) {
            $index = $textwindow->index('page');
            $line  = $textwindow->get($index);
            if ( $line =~ /[\n\*]/ ) {
                $textwindow->delete($index);
                $lglobal{joinundo}++;
                last if ( $textwindow->compare( $index, '>=', 'end' ) );
            }
            else {
                last;
            }
        }
        while (1) {
            $index = $textwindow->index('page');
            last if ( $textwindow->compare( $index, '>=', 'end' ) );
            $line = $textwindow->get("$index-1c");
            if ( $line eq '*' ) {
                $line = $textwindow->get("$index-2c") . '*';
            }
            if ( ( $line =~ /[\s\n]$/ ) || ( $line =~ /[\w-]\*$/ ) ) {
                $textwindow->delete("$index-1c");
                $lglobal{joinundo}++;
            }
            else {
                last;
            }
        }
    }
    if ( $op eq 'j' ) {
        $index = $textwindow->index('page');

        # Note: $line here and in similar cases actually seems to contain the
        # last _character_ on the previous page.
        $line = $textwindow->get("$index-1c");
        my $hyphens = 0;
        if ( $line =~ /\// ) {
            $textwindow->delete( $index, "$index+3c" );
            $lglobal{joinundo}++;
            $textwindow->delete( "$index-3c", $index );
            $lglobal{joinundo}++;
            $index = $textwindow->index('page');
            $line  = $textwindow->get("$index-1c");
            last if ( $textwindow->compare( $index, '>=', 'end' ) );
            while ( $line eq '*' ) {
                $textwindow->delete("$index-1c");
                $index = $textwindow->index('page');
                $line  = $textwindow->get("$index-1c");
            }
            $line = $textwindow->get("$index-1c");
        }

        if ( $line =~ />/ ) {
            my $markupl = $textwindow->get( "$index-4c", $index );
            my $markupn = $textwindow->get( $index,      "$index+3c" );
            if ( ( $markupl =~ /<\/[ib]>/i ) && ( $markupn =~ /<[ib]>/i ) ) {
                $textwindow->delete( $index, "$index+3c" );
                $lglobal{joinundo}++;
                $textwindow->delete( "$index-4c", $index );
                $lglobal{joinundo}++;
                $index = $textwindow->index('page');
                $line  = $textwindow->get("$index-1c");
                last if ( $textwindow->compare( $index, '>=', 'end' ) );
            }
            while ( $line eq '*' ) {
                $textwindow->delete("$index-1c");
                $index = $textwindow->index('page');
                $line  = $textwindow->get("$index-1c");
            }
            $line = $textwindow->get("$index-1c");
        }
        if ( $line =~ /\-/ ) {
            unless (
                $textwindow->search(
                    '-regexp', '--', '-----*\s?File:', $index,
                    "$index lineend"
                )
                )
            {
                while ( $line =~ /\-/ ) {
                    $textwindow->delete("$index-1c");
                    $lglobal{joinundo}++;
                    $index = $textwindow->index('page');
                    $line  = $textwindow->get("$index-1c");
                    last if ( $textwindow->compare( $index, '>=', 'end' ) );
                }
                $line = $textwindow->get($index);
                if ( $line =~ /\*/ ) {
                    $textwindow->delete($index);
                    $lglobal{joinundo}++;
                }
                $index = $textwindow->search( '-regexp', '--', '\s', $index,
                    'end' );
                $textwindow->delete($index);
                $lglobal{joinundo}++;
            }
        }
        $textwindow->insert( $index, "\n" );
        $lglobal{joinundo}++;
        $textwindow->insert( $index, $pagesep ) if $lglobal{htmlpagenum};
        $lglobal{joinundo}++ if $lglobal{htmlpagenum};
    }
    elsif ( $op eq 'k' ) {
        $index = $textwindow->index('page');
        $line  = $textwindow->get("$index-1c");
        if ( $line =~ />/ ) {
            my $markupl = $textwindow->get( "$index-4c", $index );
            my $markupn = $textwindow->get( $index,      "$index+3c" );
            if ( ( $markupl =~ /<\/[ib]>/i ) && ( $markupn =~ /<[ib]>/i ) ) {
                $textwindow->delete( $index, "$index+3c" );
                $lglobal{joinundo}++;
                $textwindow->delete( "$index-4c", $index );
                $lglobal{joinundo}++;
                $index = $textwindow->index('page');
                $line  = $textwindow->get("$index-1c");
                last if ( $textwindow->compare( $index, '>=', 'end' ) );
            }
            while ( $line eq '*' ) {
                $textwindow->delete("$index-1c");
                $index = $textwindow->index('page');
                $line  = $textwindow->get("$index-1c");
            }
            $line = $textwindow->get($index);
            while ( $line eq '*' ) {
                $textwindow->delete($index);
                $index = $textwindow->index('page');
                $line  = $textwindow->get($index);
            }
            $line = $textwindow->get("$index-1c");
        }
        if ( $line =~ /-/ ) {
            unless (
                $textwindow->search(
                    '-regexp', '--', '^-----*\s?File:', $index,
                    "$index lineend"
                )
                )
            {
                $index = $textwindow->search( '-regexp', '--', '\s', $index,
                    'end' );
                $textwindow->delete($index);
                $lglobal{joinundo}++;
            }
        }
        $line = $textwindow->get($index);
        if ( $line =~ /-/ ) {

            #$textwindow->delete($index);
            $lglobal{joinundo}++;
            $index
                = $textwindow->search( '-regexp', '--', '\s', $index, 'end' );
            $textwindow->delete($index);
            $lglobal{joinundo}++;
        }
        $textwindow->insert( $index, "\n" );
        $lglobal{joinundo}++;
        $textwindow->insert( $index, $pagesep ) if $lglobal{htmlpagenum};
        $lglobal{joinundo}++ if $lglobal{htmlpagenum};
    }
    elsif ( $op eq 'l' ) {
        $textwindow->insert( $index, "\n\n" );
        $lglobal{joinundo}++;
        $textwindow->insert( $index, $pagesep ) if $lglobal{htmlpagenum};
        $lglobal{joinundo}++ if $lglobal{htmlpagenum};
    }
    elsif ( $op eq 't' ) {
        $textwindow->insert( $index, "\n\n\n" );
        $lglobal{joinundo}++;
        $textwindow->insert( $index, $pagesep ) if $lglobal{htmlpagenum};
        $lglobal{joinundo}++ if $lglobal{htmlpagenum};
    }
    elsif ( $op eq 'h' ) {
        $textwindow->insert( $index, "\n\n\n\n\n" );
        $lglobal{joinundo}++;
        $textwindow->insert( $index, $pagesep ) if $lglobal{htmlpagenum};
        $lglobal{joinundo}++ if $lglobal{htmlpagenum};
    }
    elsif ( $op eq 'd' ) {
        $textwindow->insert( $index, $pagesep ) if $lglobal{htmlpagenum};
        $lglobal{joinundo}++ if $lglobal{htmlpagenum};
        $textwindow->delete("$index-1c");
        $lglobal{joinundo}++;
    }
    $lglobal{joinundo} = 0;
    convertfilnum() if ( $lglobal{jautomatic} || $lglobal{jsemiautomatic} );
}

sub undojoin {
    if ( $lglobal{jautomatic} ) {
        $textwindow->undo;
        $textwindow->tagRemove( 'highlight', '1.0', 'end' );
        return;
    }
    my $index;
    $textwindow->undo for ( 0 .. $lglobal{joinundo} );
    convertfilnum();
}

sub tidypop_up {
    my ( %tidy, @tidylines );
    my ( $line, $lincol );
    viewpagenums() if ( $lglobal{seepagenums} );
    if ( $lglobal{tidypop} ) {
        $lglobal{tidypop}->deiconify;
    }
    else {
        $lglobal{tidypop} = $top->Toplevel;
        $lglobal{tidypop}->title('Tidy');
        $lglobal{tidypop}->geometry($geometry2) if $geometry2;
        $lglobal{tidypop}->transient($top)      if $stayontop;
        my $ptopframe = $lglobal{tidypop}->Frame->pack;
        my $opsbutton = $ptopframe->Button(
            -activebackground => $activecolor,
            -command          => sub {
                tidyrun(' -f tidyerr.err -o null ');
                unlink 'null' if ( -e 'null' );
            },
            -text  => 'Get Errors',
            -width => 16
            )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
            );

    #        my $opsbutton2 = $ptopframe->Button(
    #            -activebackground => $activecolor,
    #            -command          => sub { tidyrun(' -f tidyerr.err -m '); },
    #            -text             => 'Generate Tidied File',
    #            -width            => 16
    #            )->pack(
    #            -side   => 'left',
    #            -pady   => 10,
    #            -padx   => 2,
    #            -anchor => 'n'
    #            );
        my $pframe = $lglobal{tidypop}
            ->Frame->pack( -fill => 'both', -expand => 'both', );
        $lglobal{tidylistbox} = $pframe->Scrolled(
            'Listbox',
            -scrollbars  => 'se',
            -background  => 'white',
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
        drag( $lglobal{tidylistbox} );
        $lglobal{tidypop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{tidypop}->destroy;
                undef $lglobal{tidypop};
                %tidy      = ();
                @tidylines = ();
            }
        );
        $lglobal{tidypop}->Icon( -image => $icon );
        BindMouseWheel( $lglobal{tidylistbox} );
        $lglobal{tidylistbox}
            ->eventAdd( '<<view>>' => '<Button-1>', '<Return>' );
        $lglobal{tidylistbox}->bind(
            '<<view>>',
            sub {
                $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                my $line = $lglobal{tidylistbox}->get('active');
                if ( $line =~ /^line/ ) {
                    $textwindow->see( $tidy{$line} );
                    $textwindow->markSet( 'insert', $tidy{$line} );
                    update_indicators();
                }
                $textwindow->focus;
                $lglobal{tidypop}->raise;
                $geometry2 = $lglobal{tidypop}->geometry;
            }
        );
        $lglobal{tidypop}->bind(
            '<Configure>' => sub {
                $lglobal{tidypop}->XEvent;
                $geometry2 = $lglobal{tidypop}->geometry;
                $lglobal{geometryupdate} = 1;
            }
        );
        $lglobal{tidylistbox}->eventAdd(
            '<<remove>>' => '<ButtonRelease-2>',
            '<ButtonRelease-3>'
        );
        $lglobal{tidylistbox}->bind(
            '<<remove>>',
            sub {
                $lglobal{tidylistbox}->activate(
                    $lglobal{tidylistbox}->index(
                        '@'
                            . (
                                  $lglobal{tidylistbox}->pointerx
                                - $lglobal{tidylistbox}->rootx
                            )
                            . ','
                            . (
                                  $lglobal{tidylistbox}->pointery
                                - $lglobal{tidylistbox}->rooty
                            )
                    )
                );
                $lglobal{tidylistbox}->selectionClear( 0, 'end' );
                $lglobal{tidylistbox}
                    ->selectionSet( $lglobal{tidylistbox}->index('active') );
                $lglobal{tidylistbox}->delete('active');
                $lglobal{tidylistbox}->after( $lglobal{delay} );
            }
        );
        $lglobal{tidypop}->update;
    }
    $lglobal{tidylistbox}->focus;
    unless ( open( RESULTS, '<', 'tidyerr.err' ) ) {
        my $dialog = $top->Dialog(
            -text    => 'Could not find tidy error file.',
            -bitmap  => 'question',
            -title   => 'File not found',
            -buttons => [qw/OK/],
        );
        $dialog->Show;
    }
    my $mark = 0;
    %tidy      = ();
    @tidylines = ();
    my @marks = $textwindow->markNames;
    for (@marks) {
        if ( $_ =~ /^t\d+$/ ) {
            $textwindow->markUnset($_);
        }
    }
    while ( $line = <RESULTS> ) {
        $line =~ s/^\s//g;
        chomp $line;

        no warnings 'uninitialized';
        if ( ( $line =~ /^[lI\d]/ ) and ( $line ne $tidylines[-1] ) ) {
            push @tidylines, $line;
            $tidy{$line} = '';
            $lincol = '';
            if ( $line =~ /^line (\d+) column (\d+)/i ) {
                $lincol = "$1.$2";
                $mark++;
                $textwindow->markSet( "t$mark", $lincol );
                $tidy{$line} = "t$mark";
            }
        }
    }
    close RESULTS;
    unlink 'tidyerr.err';
    $lglobal{tidylistbox}->insert( 'end', @tidylines );
    $lglobal{tidylistbox}->yview( 'scroll', 1, 'units' );
    $lglobal{tidylistbox}->update;
    $lglobal{tidylistbox}->yview( 'scroll', -1, 'units' );
}

sub tidyrun {
    my $tidyoptions = shift;
    push @operations, ( localtime() . ' - Tidy' );
    viewpagenums() if ( $lglobal{seepagenums} );
    if ( $lglobal{tidypop} ) {
        $lglobal{tidylistbox}->delete( '0', 'end' );
    }
    my ( $name, $fname, $path, $extension, @path );
    $textwindow->focus;
    update_indicators();
    my $title = $top->cget('title');
    if ( $title =~ /No File Loaded/ ) { savefile() }
    my $types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
    unless ($tidycommand) {
        $tidycommand = $textwindow->getOpenFile(
            -filetypes => $types,
            -title     => 'Where is the Tidy executable?'
        );
    }
    return unless $tidycommand;
    $tidycommand = os_normal($tidycommand);
    $tidycommand = dos_path($tidycommand) if OS_Win;
    saveset();
    $top->Busy( -recurse => 1 );
    if ( $tidyoptions =~ /\-m/ ) {
        $title =~ s/$window_title - //;    # FIXME: duped in gutcheck code
        $title =~ s/edited - //;
        $title = os_normal($title);
        ( $fname, $path, $extension ) = fileparse( $title, '\.[^\.]*$' );
        $title = dos_path($title) if OS_Win;
        $name  = $title;
        $name  = "${path}tidy.$fname$extension";
    }
    else {
        $name = 'tidy.tmp';
    }
    if ( open my $td, '>', $name ) {
        my $count = 0;
        my $index = '1.0';
        my ($lines) = $textwindow->index('end - 1c') =~ /^(\d+)\./;
        while ( $textwindow->compare( $index, '<', 'end' ) ) {
            my $end = $textwindow->index("$index  lineend +1c");
            print $td $textwindow->get( $index, $end );
            $index = $end;
        }
        close $td;
    }
    else {
        warn "Could not open temp file for writing. $!";
        my $dialog = $top->Dialog(
            -text => 'Could not write to the '
                . cwd()
                . ' directory. Check for write permission or space problems.',
            -bitmap  => 'question',
            -title   => 'Tidy problem',
            -buttons => [qw/OK/],
        );
        $dialog->Show;
        return;
    }
    if ( $lglobal{tidypop} ) {
        $lglobal{tidylistbox}->delete( '0', 'end' );
    }
    system(qq/$tidycommand $tidyoptions $name/);
    $top->Unbusy;
    $lglobal{tidylistbox}->insert( 'end', "Tidied file written to $name" )
        if ( $tidyoptions =~ /\-m/ );
    unlink 'tidy.tmp';
    tidypop_up();
}

my @gsopt;

sub gcheckpop_up {
    my @gclines;
    my ( $line, $linenum, $colnum, $lincol, $word );
    viewpagenums() if ( $lglobal{seepagenums} );
    if ( $lglobal{gcpop} ) {
        $lglobal{gcpop}->deiconify;
        $lglobal{gclistbox}->delete( '0', 'end' );
    }
    else {
        $lglobal{gcpop} = $top->Toplevel;
        $lglobal{gcpop}->title('Gutcheck');
        $lglobal{gcpop}->geometry($geometry2) if $geometry2;
        $lglobal{gcpop}->transient($top)      if $stayontop;
        my $ptopframe = $lglobal{gcpop}->Frame->pack;
        my $opsbutton = $ptopframe->Button(
            -activebackground => $activecolor,
            -command          => sub { gcviewops( \@gclines ) },
            -text             => 'GC View Options',
            -width            => 16
            )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
            );
        my $opsbutton2 = $ptopframe->Button(
            -activebackground => $activecolor,
            -command          => sub { gutcheck() },
            -text             => 'Re-run Gutcheck',
            -width            => 16
            )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
            );
        my $opsbutton3 = $ptopframe->Button(
            -activebackground => $activecolor,
            -command          => sub { gutopts() },
            -text             => 'GC Run Options',
            -width            => 16
            )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
            );
        my $pframe = $lglobal{gcpop}
            ->Frame->pack( -fill => 'both', -expand => 'both', );
        $lglobal{gclistbox} = $pframe->Scrolled(
            'Listbox',
            -scrollbars  => 'se',
            -background  => 'white',
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
        drag( $lglobal{gclistbox} );
        $lglobal{gcpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{viewpop}->iconify if defined $lglobal{viewpop};
                $lglobal{gcpop}->destroy;
                undef $lglobal{gcpop};
                $textwindow->markUnset($_) for values %gc;
            }
        );
        $lglobal{gcpop}->Icon( -image => $icon );
        BindMouseWheel( $lglobal{gclistbox} );
        $lglobal{gclistbox}
            ->eventAdd( '<<view>>' => '<Button-1>', '<Return>' );
        $lglobal{gclistbox}->bind( '<<view>>', sub { gcview() } );
        $lglobal{gcpop}->bind(
            '<Configure>' => sub {
                $lglobal{gcpop}->XEvent;
                $geometry2 = $lglobal{gcpop}->geometry;
                $lglobal{geometryupdate} = 1;
            }
        );
        $lglobal{gclistbox}->eventAdd(
            '<<remove>>' => '<ButtonRelease-2>',
            '<ButtonRelease-3>'
        );
        $lglobal{gclistbox}->bind(
            '<<remove>>',
            sub {
                $lglobal{gclistbox}->activate(
                    $lglobal{gclistbox}->index(
                        '@'
                            . (
                                  $lglobal{gclistbox}->pointerx
                                - $lglobal{gclistbox}->rootx
                            )
                            . ','
                            . (
                                  $lglobal{gclistbox}->pointery
                                - $lglobal{gclistbox}->rooty
                            )
                    )
                );
                $textwindow->markUnset(
                    $gc{ $lglobal{gclistbox}->get('active') } );
                undef $gc{ $lglobal{gclistbox}->get('active') };
                $lglobal{gclistbox}->delete('active');
                $lglobal{gclistbox}->selectionClear( '0', 'end' );
                $lglobal{gclistbox}->selectionSet('active');
                gcview();
                $lglobal{gclistbox}->after( $lglobal{delay} );
            }
        );
        $lglobal{gclistbox}->bind(
            '<Button-3>',
            sub {
                $lglobal{gclistbox}->activate(
                    $lglobal{gclistbox}->index(
                        '@'
                            . (
                                  $lglobal{gclistbox}->pointerx
                                - $lglobal{gclistbox}->rootx
                            )
                            . ','
                            . (
                                  $lglobal{gclistbox}->pointery
                                - $lglobal{gclistbox}->rooty
                            )
                    )
                );
            }
        );
    }
    $lglobal{gclistbox}->focus;
    my $results;
    unless ( open $results, '<', 'gutrslts.txt' ) {
        my $dialog = $top->Dialog(
            -text =>
                'Could not read gutcheck results file. Problem with gutcheck.',
            -bitmap  => 'question',
            -title   => 'Gutcheck problem',
            -buttons => [qw/OK/],
        );
        $dialog->Show;
        return;
    }
    my $mark = 0;
    %gc      = ();
    @gclines = ();
    while ( $line = <$results> ) {
        $line =~ s/^\s//g;
        chomp $line;
        $line =~ s/^(File: )gutchk.tmp/$1$lglobal{global_filename}/g;
        {

            no warnings 'uninitialized';
            next if $line eq $gclines[-1];
        }
        push @gclines, $line;
        $gc{$line} = '';
        $colnum    = '0';
        $lincol    = '';
        if ( $line =~ /Line (\d+)/ ) {
            $linenum = $1;

            if ( $line =~ /Line \d+ column (\d+)/ ) {
                $colnum = $1;
                $colnum--
                    unless ( $line =~ /Long|Short|digit|space|bracket\?/ );
                my $tempvar
                    = $textwindow->get( "$linenum.0", "$linenum.$colnum" );
                while ( $tempvar =~ s/<[ib]>// ) {
                    $tempvar .= $textwindow->get( "$linenum.$colnum",
                        "$linenum.$colnum +3c" );
                    $colnum += 3;
                }
                while ( $tempvar =~ s/<\/[ib]>// ) {
                    $tempvar .= $textwindow->get( "$linenum.$colnum",
                        "$linenum.$colnum +4c" );
                    $colnum += 4;
                }
            }
            else {
                if ( $line =~ /Query digit in ([\w\d]+)/ ) {
                    $word   = $1;
                    $lincol = $textwindow->search( '--', $word, "$linenum.0",
                        "$linenum.0 +1l" );
                }
                if ( $line =~ /Query standalone (\d)/ ) {
                    $word   = '(?<=\D)' . $1 . '(?=\D)';
                    $lincol = $textwindow->search( '-regexp', '--', $word,
                        "$linenum.0", "$linenum.0 +1l" );
                }
                if ( $line =~ /Asterisk?/ ) {
                    $lincol = $textwindow->search( '--', '*', "$linenum.0",
                        "$linenum.0 +1l" );
                }
                if ( $line =~ /Hyphen at end of line?/ ) {
                    $lincol = $textwindow->search(
                        '-regexp', '--',
                        '-$',      "$linenum.0",
                        "$linenum.0 +1l"
                    );
                }
                if ( $line =~ /Non-ASCII character (\d+)/ ) {
                    $word   = chr($1);
                    $lincol = $textwindow->search( $word, "$linenum.0",
                        "$linenum.0 +1l" );
                }
                if ( $line =~ /dash\?/ ) {
                    $lincol = $textwindow->search(
                        '-regexp',       '--',
                        '-- | --| -|- ', "$linenum.0",
                        "$linenum.0 +1l"
                    );
                }
                if ( $line =~ /HTML symbol/ ) {
                    $lincol = $textwindow->search(
                        '-regexp', '--',
                        '&',       "$linenum.0",
                        "$linenum.0 +1l"
                    );
                }
                if ( $line =~ /HTML Tag/ ) {
                    $lincol = $textwindow->search(
                        '-regexp', '--',
                        '<',       "$linenum.0",
                        "$linenum.0 +1l"
                    );
                }
                if ( $line =~ /Query word ([\p{Alnum}']+)/ ) {
                    $word = $1;
                    if ( $word =~ /[\xA0-\xFF]/ ) {
                        $lincol
                            = $textwindow->search( '-regexp', '--',
                            '(?<!\p{Alnum})' . $word . '(?!\p{Alnum})',
                            "$linenum.0", "$linenum.0 +1l" );
                    }
                    elsif ( $word eq 'i' ) {
                        $lincol = $textwindow->search(
                            '-regexp',              '--',
                            ' ' . $word . '[^a-z]', "$linenum.0",
                            "$linenum.0 +1l"
                        );
                        $lincol
                            = $textwindow->search( '-regexp', '--',
                            '[^A-Za-z0-9<\/]' . $word . '[^A-Za-z0-9>]',
                            "$linenum.0", "$linenum.0 +1l" )
                            unless $lincol;
                        $lincol = $textwindow->index("$lincol +1c")
                            if ($lincol);
                    }
                    else {
                        $lincol = $textwindow->search(
                            '-regexp',           '--',
                            '\b' . $word . '\b', "$linenum.0",
                            "$linenum.0 +1l"
                        );
                    }
                }
                if ( $line =~ /Query he\/be/ ) {
                    $lincol = $textwindow->search(
                        '-regexp',       '--',
                        '(?<= )[bh]e\W', "$linenum.0",
                        "$linenum.0 +1l"
                    );
                }
                if ( $line =~ /Query hut\/but/ ) {
                    $lincol = $textwindow->search(
                        '-regexp',        '--',
                        '(?<= )[bh]ut\W', "$linenum.0",
                        "$linenum.0 +1l"
                    );
                }
            }
            $mark++;
            if ($lincol) {
                $textwindow->markSet( "g$mark", $lincol );
            }
            else {
                $colnum = '0' unless $colnum;
                $textwindow->markSet( "g$mark", "$linenum.$colnum" );
            }
            $gc{$line} = "g$mark";
        }
    }
    close $results;
    unlink 'gutrslts.txt';
    gutwindowpopulate( \@gclines );
}

sub gcview {
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    my $line = $lglobal{gclistbox}->get('active');
    if ( $line and $gc{$line} and $line =~ /Line/ ) {
        $textwindow->see('end');
        $textwindow->see( $gc{$line} );
        $textwindow->markSet( 'insert', $gc{$line} );
        update_indicators();
    }
    $textwindow->focus;
    $lglobal{gcpop}->raise;
    $geometry2 = $lglobal{gcpop}->geometry;
}

sub gcviewops {
    my $linesref = shift;
    my @gsoptions;
    @{ $lglobal{gcarray} } = (
        'Asterisk',
        'Begins with punctuation',
        'Broken em-dash',
        'Capital "S"',
        'Carat character',
        'CR without LF',
        'Double punctuation',
        'endquote missing punctuation',
        'Extra period',
        'Forward slash',
        'HTML symbol',
        'HTML Tag',
        'Hyphen at end of line',
        'Long line',
        'Mismatched curly brackets',
        'Mismatched quotes',
        'Mismatched round brackets',
        'Mismatched singlequotes',
        'Mismatched square brackets',
        'Mismatched underscores',
        'Missing space',
        'No CR',
        'No punctuation at para end',
        'Non-ASCII character',
        'Non-ISO-8859 character',
        'Paragraph starts with lower-case',
        'Query angled bracket with From',
        'Query digit in',
        "Query he\/be error",
        "Query hut\/but error",
        'Query I=exclamation mark',
        'Query missing paragraph break',
        'Query possible scanno',
        'Query punctuation after',
        'Query single character line',
        'Query standalone 0',
        'Query standalone 1',
        'Query word',
        'Short line',
        'Spaced dash',
        'Spaced doublequote',
        'Spaced em-dash',
        'Spaced punctuation',
        'Spaced quote',
        'Spaced singlequote',
        'Tab character',
        'Tilde character',
        'Two successive CRs',
        'Unspaced bracket',
        'Unspaced quotes',
        'Wrongspaced quotes',
        'Wrongspaced singlequotes',
    );
    my $gcrows = int( ( @{ $lglobal{gcarray} } / 3 ) + .9 );
    if ( defined( $lglobal{viewpop} ) ) {
        $lglobal{viewpop}->deiconify;
        $lglobal{viewpop}->raise;
        $lglobal{viewpop}->focus;
    }
    else {
        $lglobal{viewpop} = $top->Toplevel;
        $lglobal{viewpop}->title('Gutcheck view options');
        my $pframe = $lglobal{viewpop}->Frame->pack;
        $pframe->Label( -text => 'Select option to hide that error.', )->pack;
        my $pframe1 = $lglobal{viewpop}->Frame->pack;
        my ( $gcrow, $gccol );
        for ( 0 .. $#{ $lglobal{gcarray} } ) {
            $gccol         = int( $_ / $gcrows );
            $gcrow         = $_ % $gcrows;
            $gsoptions[$_] = $pframe1->Checkbutton(
                -variable    => \$gsopt[$_],
                -command     => sub { gutwindowpopulate($linesref) },
                -selectcolor => $lglobal{checkcolor},
                -text        => $lglobal{gcarray}->[$_],
            )->grid( -row => $gcrow, -column => $gccol, -sticky => 'nw' );
        }
        my $pframe2 = $lglobal{viewpop}->Frame->pack;
        $pframe2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                for ( 0 .. $#gsoptions ) {
                    $gsoptions[$_]->select;
                }
                gutwindowpopulate($linesref);
            },
            -text  => 'Hide all',
            -width => 12
            )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
            );
        $pframe2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                for ( 0 .. $#gsoptions ) {
                    $gsoptions[$_]->deselect;
                }
                gutwindowpopulate($linesref);
            },
            -text  => 'See all',
            -width => 12
            )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
            );
        $pframe2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                for ( 0 .. $#gsoptions ) {
                    $gsoptions[$_]->toggle;
                }
                gutwindowpopulate($linesref);
            },
            -text  => 'Toggle View',
            -width => 12
            )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
            );
        $pframe2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                for ( 0 .. $#mygcview ) {
                    if ( $mygcview[$_] ) {
                        $gsoptions[$_]->select;
                    }
                    else {
                        $gsoptions[$_]->deselect;
                    }
                }
                gutwindowpopulate($linesref);
            },
            -text  => 'Load My View',
            -width => 12
            )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
            );
        $pframe2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                for ( 0 .. $#gsopt ) {
                    $mygcview[$_] = $gsopt[$_];
                }
                saveset();
            },
            -text  => 'Save My View',
            -width => 12
            )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
            );
        $lglobal{viewpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{viewpop}->destroy;
                @{ $lglobal{gcarray} } = ();
                undef $lglobal{viewpop};
            }
        );
        $lglobal{viewpop}->resizable( 'no', 'no' );
        $lglobal{viewpop}->Icon( -image => $icon );
    }
}

sub gutwindowpopulate {
    my $linesref = shift;
    return unless defined $lglobal{gcpop};
    my ( $line, $flag, $count, $start );
    $lglobal{gclistbox}->delete( '0', 'end' );
    foreach $line ( @{$linesref} ) {
        $flag = 0;
        $start++ unless ( index( $line, 'Line', 0 ) > 0 );
        next unless defined $gc{$line};
        for ( 0 .. $#{ $lglobal{gcarray} } ) {
            next unless ( index( $line, $lglobal{gcarray}->[$_] ) > 0 );
            $gsopt[$_] = 0 unless defined $gsopt[$_];
            $flag = 1 if $gsopt[$_];
            last;
        }
        next if $flag;
        $count++;
        $lglobal{gclistbox}->insert( 'end', $line );
    }
    $count -= $start;
    $lglobal{gclistbox}->insert( $start, '', "  --> $count queries.", '' );
    $lglobal{gclistbox}->update;
    $lglobal{gclistbox}->yview( 'scroll', 1,  'units' );
    $lglobal{gclistbox}->yview( 'scroll', -1, 'units' );
}

sub gutcheckrun {
    my ( $gutcheckstart, $gutcheckoptions, $thisfile ) = @_;
    system(qq/$gutcheckstart $gutcheckoptions $thisfile > gutrslts.txt/);
}

sub fixpopup {
    viewpagenums() if ( $lglobal{seepagenums} );
    if ( defined( $lglobal{fixpop} ) ) {
        $lglobal{fixpop}->deiconify;
        $lglobal{fixpop}->raise;
        $lglobal{fixpop}->focus;
    }
    else {
        $lglobal{fixpop} = $top->Toplevel;
        $lglobal{fixpop}->title('Fixup Options');
        my $tframe = $lglobal{fixpop}->Frame->pack;
        $tframe->Button(
            -activebackground => $activecolor,
            -command          => sub {
                $lglobal{fixpop}->UnmapWindow;
                fixup();
                $lglobal{fixpop}->destroy;
                undef $lglobal{fixpop};
            },
            -text  => 'Go!',
            -width => 14
        )->pack( -pady => 6 );
        my $pframe = $lglobal{fixpop}->Frame->pack;
        $pframe->Label( -text => 'Select options for the fixup routine.', )
            ->pack;
        my $pframe1 = $lglobal{fixpop}->Frame->pack;
        ${ $lglobal{fixopt} }[15] = 1;
        my @rbuttons = (
            'Skip /* */ and /$  $/ marked blocks.',
            'Fix up spaces around hyphens.',
            'Remove spaces before periods.',
            'Remove spaces before exclamation marks.',
            'Remove spaces before question marks.',
            'Remove spaces before semicolons.',
            'Remove spaces before colons.',
            'Remove spaces before commas.',
            'Remove spaces after beginning and before ending double quote.',
            'Remove spaces after opening and before closing brackets, () [], {}.',
            'Convert multiple spaces to single spaces.',
            'Format a line with 5 * and nothing else as a standard thought break.',
            'Fix obvious l<->1 problems, lst, llth, etc.',
            'Format ellipses correctly',
            'Remove spaces after beginning and before ending angle quotes ´ ª.',

        );
        my $row = 0;
        for (@rbuttons) {
            $pframe1->Checkbutton(
                -variable    => \${ $lglobal{fixopt} }[$row],
                -selectcolor => $lglobal{checkcolor},
                -text        => $_,
            )->grid( -row => $row, -column => 1, -sticky => 'nw' );
            ++$row;
        }
        $pframe1->Radiobutton(
            -variable    => \${ $lglobal{fixopt} }[15],
            -selectcolor => $lglobal{checkcolor},
            -value       => 1,
            -text        => 'French style angle quotes ´guillemotsª',
        )->grid( -row => $row, -column => 1 );
        ++$row;
        $pframe1->Radiobutton(
            -variable    => \${ $lglobal{fixopt} }[15],
            -selectcolor => $lglobal{checkcolor},
            -value       => 0,
            -text        => 'German style angle quotes ªguillemots´',
        )->grid( -row => $row, -column => 1 );
        $lglobal{fixpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{fixpop}->destroy; undef $lglobal{fixpop} } );
        $lglobal{fixpop}->Icon( -image => $icon );
    }
}

sub ital_adjust {
    my $markuppop = $top->Toplevel( -title => 'Word count threshold', );
    my $f0 = $markuppop->Frame->pack( -side => 'top', -anchor => 'n' );
    $f0->Label( -text =>
            "Threshold word count for marked up phrase.\nPhrases with more words will be skipped.\nDefault is 4."
    )->pack;
    my $f1 = $markuppop->Frame->pack( -side => 'top', -anchor => 'n' );
    $f1->Entry(
        -width        => 10,
        -background   => 'white',
        -relief       => 'sunken',
        -textvariable => \$markupthreshold,
        -validate     => 'key',
        -vcmd         => sub {
            return 1 unless $_[1];
            return 1 unless ( $_[1] =~ /\D/ );
            return 0;
        },
    )->grid( -row => 1, -column => 1, -padx => 2, -pady => 4 );
    $f1->Button(
        -activebackground => $activecolor,
        -command          => sub {
            $markuppop->destroy;
            undef $markuppop;
        },
        -text  => 'OK',
        -width => 8
    )->grid( -row => 2, -column => 1, -padx => 2, -pady => 4 );
    $markuppop->protocol(
        'WM_DELETE_WINDOW' => sub { $markuppop->destroy; undef $markuppop; }
    );
    $markuppop->Icon( -image => $icon );
}

sub searchoptset {
    my @opt = @_;

# $sopt[0] --> 0 = pattern search               1 = whole word search
# $sopt[1] --> 0 = case insensitive             1 = case sensitive search
# $sopt[2] --> 0 = search forwards              1 = search backwards
# $sopt[3] --> 0 = normal search term   1 = regex search term - 3 and 0 are mutually exclusive
    for ( 0 .. 3 ) {
        if ( defined( $lglobal{search} ) ) {
            if ( $opt[$_] !~ /[a-zA-Z]/ ) {
                $opt[$_]
                    ? $lglobal{"searchop$_"}->select
                    : $lglobal{"searchop$_"}->deselect;
            }
        }
        else {
            if ( $opt[$_] !~ /[a-zA-Z]/ ) { $sopt[$_] = $opt[$_] }
        }
    }
}

## Word Frequency
sub harmonicspop {
    my ( $line, $word, $sword, $snum, @savesets, $wc );
    if ( $lglobal{hpopup} ) {
        $lglobal{hpopup}->deiconify;
        $lglobal{hpopup}->raise;
        $lglobal{hlistbox}->delete( '0', 'end' );
    }
    else {
        $lglobal{hpopup} = $top->Toplevel;
        $lglobal{hpopup}->title('Word harmonics');
        $lglobal{hpopup}->geometry($geometry3) if $geometry3;
        my $frame = $lglobal{hpopup}
            ->Frame->pack( -fill => 'both', -expand => 'both', );
        $lglobal{hlistbox} = $frame->Scrolled(
            'Listbox',
            -scrollbars  => 'se',
            -background  => 'white',
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
        drag( $lglobal{hlistbox} );
        $lglobal{hpopup}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $geometry3 = $lglobal{hpopup}->geometry;
                $lglobal{hpopup}->destroy;
                undef $lglobal{hpopup};
                undef $lglobal{hlistbox};
            }
        );
        $lglobal{hpopup}->Icon( -image => $icon );
        $lglobal{hpopup}->bind(
            '<Configure>' => sub {
                $lglobal{hpopup}->XEvent;
                $geometry3 = $lglobal{hpopup}->geometry;
                $lglobal{geometryupdate} = 1;
            }
        );
        BindMouseWheel( $lglobal{hlistbox} );
        $lglobal{hlistbox}->eventAdd( '<<search>>' => '<ButtonRelease-3>' );
        $lglobal{hlistbox}->bind(
            '<<search>>',
            sub {
                $lglobal{hlistbox}->selectionClear( 0, 'end' );
                $lglobal{hlistbox}->selectionSet(
                    $lglobal{hlistbox}->index(
                        '@'
                            . (
                                  $lglobal{hlistbox}->pointerx
                                - $lglobal{hlistbox}->rootx
                            )
                            . ','
                            . (
                                  $lglobal{hlistbox}->pointery
                                - $lglobal{hlistbox}->rooty
                            )
                    )
                );
                my ($sword)
                    = $lglobal{hlistbox}
                    ->get( $lglobal{hlistbox}->curselection );
                searchpopup();
                $sword =~ s/\d+\s+([\w'-]*)/$1/;
                $sword =~ s/\s+\*\*\*\*$//;
                $lglobal{searchentry}->delete( '1.0', 'end' );
                $lglobal{searchentry}->insert( 'end', $sword );
                updatesearchlabels();
                $geometry3 = $lglobal{hpopup}->geometry;
                $lglobal{searchentry}->after( $lglobal{delay} );
            }
        );
        $lglobal{hlistbox}->eventAdd( '<<find>>' => '<Double-Button-1>' );
        $lglobal{hlistbox}->bind(
            '<<find>>',
            sub {
                return unless $lglobal{hlistbox}->index('active');
                $top->Busy( -recurse => 1 );
                $sword = $lglobal{hlistbox}->get('active');
                return unless ( $lglobal{hlistbox}->curselection );
                $sword =~ s/(\d+)\s+([\w'-]*)/$2/;
                $snum = $1;
                $sword =~ s/\s+\*\*\*\*$//;
                @savesets = @sopt;

                unless ($snum) {
                    searchoptset(qw/0 x x 1/);
                    $sword = "(?<=-)$sword|$sword(?=-)";
                }
                searchtext($sword);
                searchoptset(@savesets);
                $geometry3 = $lglobal{hpopup}->geometry;
                $top->Unbusy( -recurse => 1 );
            }
        );
        $lglobal{hlistbox}->bind(
            '<Down>',
            sub {
                return unless defined $lglobal{wclistbox};
                my $index = $lglobal{wclistbox}->index('active');
                $lglobal{wclistbox}->selectionClear( '0', 'end' );
                $lglobal{wclistbox}->activate( $index + 1 );
                $lglobal{wclistbox}->selectionSet( $index + 1 );
                $lglobal{wclistbox}->see('active');
                harmonics( $lglobal{wclistbox}->get('active') );
                harmonicspop();
                $geometry3 = $lglobal{hpopup}->geometry;
                $lglobal{hpopup}->break;
            }
        );
        $lglobal{hlistbox}->bind(
            '<Up>',
            sub {
                return unless defined $lglobal{wclistbox};
                my $index = $lglobal{wclistbox}->index('active');
                $lglobal{wclistbox}->selectionClear( '0', 'end' );
                $lglobal{wclistbox}->activate( $index - 1 );
                $lglobal{wclistbox}->selectionSet( $index - 1 );
                $lglobal{wclistbox}->see('active');
                harmonics( $lglobal{wclistbox}->get('active') );
                harmonicspop();
                $geometry3 = $lglobal{hpopup}->geometry;
                $lglobal{hpopup}->break;
            }
        );
        $lglobal{hlistbox}->eventAdd( '<<harm>>' => '<Control-Button-1>' );
        $lglobal{hlistbox}->bind(
            '<<harm>>',
            sub {
                return unless ( $lglobal{hlistbox}->curselection );
                harmonics( $lglobal{hlistbox}->get('active') );
                harmonicspop();
                $geometry3 = $lglobal{hpopup}->geometry;
            }
        );
    }
    my $active = $lglobal{wclistbox}->get('active');
    $active =~ s/\d+\s+([\w'-]*)/$1/;
    $active =~ s/\*\*\*\*$//;
    $active =~ s/\s//g;
    $lglobal{hlistbox}->insert( 'end', 'Please wait... searching...' );
    $lglobal{hlistbox}->update;
    if ( defined $lglobal{harmonics} && $lglobal{harmonics} == 2 ) {
        harmonics2($active);
        $wc = scalar( keys( %{ $lglobal{harmonic} } ) );
        $lglobal{hlistbox}->delete( '0', 'end' );
        $lglobal{hlistbox}
            ->insert( 'end', "$wc 2nd order harmonics for $active." );
    }
    else {
        harmonics($active);
        $wc = scalar( keys( %{ $lglobal{harmonic} } ) );
        $lglobal{hlistbox}->delete( '0', 'end' );
        $lglobal{hlistbox}
            ->insert( 'end', "$wc 1st order harmonics for $active." );
    }
    foreach $word ( sort { deaccent( lc $a ) cmp deaccent( lc $b ) }
        ( keys %{ $lglobal{harmonic} } ) )
    {
        $line = sprintf( "%-8d %s", $lglobal{seen}->{$word}, $word )
            ;    # Print to the file
        $lglobal{hlistbox}->insert( 'end', $line );
    }
    %{ $lglobal{harmonic} } = ();
    $lglobal{hlistbox}->focus;
}

sub harmonics {
    my $word = shift;
    $word =~ s/\d+\s+([\w'-]*)/$1/;
    $word =~ s/\*\*\*\*$//;
    $word =~ s/\s//g;
    my $length = length $word;
    for my $test ( keys %{ $lglobal{seen} } ) {
        next if ( abs( $length - length $test ) > 1 );
        $lglobal{harmonic}{$test} = 1 if ( distance( $word, $test ) <= 1 );
    }
}

sub harmonics2 {
    my $word = shift;
    $word =~ s/\d+\s+([\w'-]*)/$1/;
    $word =~ s/\*\*\*\*$//;
    $word =~ s/\s//g;
    my $length = length $word;
    for my $test ( keys %{ $lglobal{seen} } ) {
        next if ( abs( $length - length $test ) > 2 );
        $lglobal{harmonic}{$test} = 1 if ( distance( $word, $test ) <= 2 );
    }
}

sub sortwords {
    my $href = shift;
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}->insert( 'end', 'Please wait, sorting list....' );
    $lglobal{wclistbox}->update;
    if ( $lglobal{alpha_sort} eq 'f' ) {    # Sorted by word frequency
        for ( natural_sort_freq($href) ) {
            my $line
                = sprintf( "%-8d %s", $$href{$_}, $_ );    # Print to the file
            $lglobal{wclistbox}->insert( 'end', $line );
        }
    }
    elsif ( $lglobal{alpha_sort} eq 'a' ) {    # Sorted alphabetically
        for ( natural_sort_alpha( keys %$href ) ) {
            my $line
                = sprintf( "%-8d %s", $$href{$_}, $_ );    # Print to the file
            $lglobal{wclistbox}->insert( 'end', $line );
        }
    }
    elsif ( $lglobal{alpha_sort} eq 'l' ) {    # Sorted by word length
        for ( natural_sort_length( keys %$href ) ) {
            my $line
                = sprintf( "%-8d %s", $$href{$_}, $_ );    # Print to the file
            $lglobal{wclistbox}->insert( 'end', $line );
        }
    }
    $lglobal{wclistbox}->delete('0');
    $lglobal{wclistbox}->insert( '0', $lglobal{saveheader} );
    $lglobal{wclistbox}->update;
    $lglobal{wclistbox}->yview( 'scroll', 1, 'units' );
    $lglobal{wclistbox}->update;
    $lglobal{wclistbox}->yview( 'scroll', -1, 'units' );
    $top->Unbusy;
}

sub commark {
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
    $lglobal{wclistbox}->update;
    my %display = ();
    my $wordw   = 0;
    my $ssindex = '1.0';
    my $length;
    my $filename = $textwindow->FileName;
    return if ( $filename =~ m/No File Loaded/ );
    savefile() unless ( $textwindow->numberChanges == 0 );
    my $wholefile;
    {
        local $/;    # slurp in the file
        open my $fh, '<', $filename;
        $wholefile = <$fh>;
        close $fh;
        utf8::decode($wholefile);
    }
    $wholefile =~ s/-----*\s?File:\s?\S+\.(png|jpg)---.*\r?\n?//g;
    while ( $wholefile =~ m/(,"?\n*\s*"?\p{Upper}\p{Alnum}*)/g ) {
        my $word = $1;
        $wordw++;
        $word =~ s/<\/?[bidhscalup].*?>//g;
        $word =~ s/(\p{Alnum})'(\p{Alnum})/$1PQzJ$2/g;
        $word =~ s/"/pQzJ/g;
        $word =~ s/(\p{Alnum})\.(\p{Alnum})/$1PqzJ$2/g;
        $word =~ s/(\p{Alnum})-(\p{Alnum})/$1PLXJ$2/g;
        $word =~ s/[^\s\p{Alnum}]//g;
        $word =~ s/PQzJ/'/g;
        $word =~ s/PqzJ/./g;
        $word =~ s/PLXJ/-/g;
        $word =~ s/pQzJ/"/g;
        $word =~ s/\P{Alnum}+$//g;
        $word =~ s/\x{d}//g;
        $word =~ s/\n/\\n/g;
        $display{ ',' . $word }++;
    }
    $lglobal{saveheader} = "$wordw words with uppercase following commas. "
        . '(\n means newline)';
    sortwords( \%display );
    $top->Unbusy;
    searchoptset(qw/0 x x 1/);
}

sub itwords {
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
    $lglobal{wclistbox}->update;
    my %display  = ();
    my $wordw    = 0;
    my $suspects = '0';
    my %words;
    my $ssindex = '1.0';
    my $length;
    my $filename = $textwindow->FileName;
    return if ( $filename =~ m/No File Loaded/ );
    savefile() unless ( $textwindow->numberChanges == 0 );
    my $wholefile;
    {
        local $/;    # slurp in the file
        open my $fh, '<', $filename;
        $wholefile = <$fh>;
        close $fh;
        utf8::decode($wholefile);
    }
    $wholefile =~ s/-----*\s?File:\s?\S+\.(png|jpg)---.*\r?\n?//g;
    $markupthreshold = 0 unless $markupthreshold;
    while ( $wholefile =~ m/(<[iIbB]>)(.*?)(<\/[IiBb]>)/sg ) {
        my $word   = $1 . $2 . $3;
        my $wordwo = $2;
        my $num    = 0;
        $num++ while ( $word =~ /(\S\s)/g );
        next if ( $num >= $markupthreshold );
        $word =~ s/\n/\\n/g;
        $display{$word}++;
        $words{$wordwo} = $display{$word};
    }
    $wordw = scalar keys %display;
    for my $wordwo ( keys %words ) {
        while ( $wholefile =~ m/(?<=\W)\Q$wordwo\E(?=\W)/sg ) {
            $wordwo =~ s/\n/\\n/g;
            $display{$wordwo}++;
        }
        $display{$wordwo} = $display{$wordwo} - $words{$wordwo}
            if ( ( $words{$wordwo} ) || ( $display{$wordwo} =~ /\\n/ ) );
        delete $display{$wordwo} unless $display{$wordwo};
    }
    $suspects = ( scalar keys %display ) - $wordw;
    $lglobal{saveheader}
        = "$wordw words/phrases with markup, $suspects similar without. (\\n means newline)";
    $wholefile = ();
    sortwords( \%display );
    $top->Unbusy;
    searchoptset(qw/1 x x 0/);
}

sub bangmark {
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
    $lglobal{wclistbox}->update;
    my %display  = ();
    my $wordw    = 0;
    my $ssindex  = '1.0';
    my $length   = 0;
    my $filename = $textwindow->FileName;
    return if ( $filename =~ m/No File Loaded/ );
    savefile() unless ( $textwindow->numberChanges == 0 );
    my $wholefile;
    {
        local $/;    # slurp in the file
        open my $fh, '<', $filename;
        $wholefile = <$fh>;
        close $fh;
        utf8::decode($wholefile);
    }
    $wholefile =~ s/-----*\s?File:\s?\S+\.(png|jpg)---.*\r?\n?//g;
    while ( $wholefile =~ m/(\p{Alnum}+\."?\n*\s*"?\p{Lower}\p{Alnum}*)/g ) {
        my $word = $1;
        $wordw++;
        $word =~ s/<\/?[bidhscalup].*?>//g;
        $word =~ s/(\p{Alnum})'(\p{Alnum})/$1PQzJ$2/g;
        $word =~ s/"/pQzJ/g;
        $word =~ s/(\p{Alnum})\.(\s*\S)/$1PqzJ$2/g;
        $word =~ s/(\p{Alnum})-(\p{Alnum})/$1PLXj$2/g;
        $word =~ s/[^\s\p{Alnum}]//g;
        $word =~ s/PQzJ/'/g;
        $word =~ s/PqzJ/./g;
        $word =~ s/PLXj/-/g;
        $word =~ s/pQzJ/"/g;
        $word =~ s/\P{Alnum}+$//g;
        $word =~ s/\x{d}//g;
        $word =~ s/\n/\\n/g;
        $display{$word}++;
    }
    $lglobal{saveheader} = "$wordw words with lower case after period. "
        . '(\n means newline)';
    sortwords( \%display );
    $top->Unbusy;
    searchoptset(qw/0 x x 1/);
}

sub hyphencheck {
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}
        ->insert( 'end', 'Please wait, building word list....' );
    $lglobal{wclistbox}->update;
    my $wordw   = 0;
    my $wordwo  = 0;
    my %display = ();
    foreach my $word ( keys %{ $lglobal{seen} } ) {
        next if ( $lglobal{seen}->{$word} < 1 );
        if ( $word =~ /-/ ) {
            $wordw++;
            my $wordtemp = $word;
            $display{$word} = $lglobal{seen}->{$word}
                unless $lglobal{suspects_only};
            $word =~ s/-/--/g;
            if ( $lglobal{seenm}->{$word} ) {
                $display{$wordtemp} = $lglobal{seen}->{$wordtemp}
                    if $lglobal{suspects_only};
                my $aword = $word . ' ****';
                $display{$aword} = $lglobal{seenm}->{$word};
                $wordwo++;
            }
            $word =~ s/-//g;
            if ( $lglobal{seen}->{$word} ) {
                $display{$wordtemp} = $lglobal{seen}->{$wordtemp}
                    if $lglobal{suspects_only};
                my $aword = $word . ' ****';
                $display{$aword} = $lglobal{seen}->{$word};
                $wordwo++;
            }
        }
    }
    $lglobal{saveheader}
        = "$wordw words with hyphens, $wordwo suspects (marked ****).";
    sortwords( \%display );
    $top->Unbusy;
}

sub dashcheck {
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
    $lglobal{wclistbox}->update;
    $lglobal{wclistbox}->delete( '0', 'end' );
    my $wordw   = 0;
    my $wordwo  = 0;
    my %display = ();
    foreach my $word ( keys %{ $lglobal{seenm} } ) {
        next if ( $lglobal{seenm}->{$word} < 1 );
        if ( $word =~ /-/ ) {
            $wordw++;
            my $wordtemp = $word;
            $display{$word} = $lglobal{seenm}->{$word}
                unless $lglobal{suspects_only};
            $word =~ s/--/-/g;
            if ( $lglobal{seen}->{$word} ) {
                my $aword = $word . ' ****';
                $display{$wordtemp} = $lglobal{seenm}->{$wordtemp}
                    if $lglobal{suspects_only};
                $display{$aword} = $lglobal{seen}->{$word};
                $wordwo++;
            }
        }
    }
    $lglobal{saveheader}
        = "$wordw emdash phrases, $wordwo suspects (marked with ****).";
    sortwords( \%display );
    searchoptset(qw /0 x x 0/);
    $top->Unbusy;
}

sub unicheck {
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}
        ->insert( 'end', 'Please wait, building word list....' );
    $lglobal{wclistbox}->update;
    my %display;
    my $wordw = 0;
    foreach ( sort ( keys %{ $lglobal{seen} } ) ) {
        if ( $_ =~ /[\x{100}-\x{FFEF}]/ ) {
            $display{$_} = $lglobal{seen}->{$_};
            $wordw++;
        }
    }
    $lglobal{saveheader} = "$wordw words with unicode chars > FF.";
    sortwords( \%display );
    $top->Unbusy;
}

sub wfspellcheck {
    spelloptions() unless $globalspellpath;
    return unless $globalspellpath;
    $top->Busy( -recurse => 1 );
    %{ $lglobal{spellsort} } = ();
    getprojectdic();
    do "$lglobal{projectdictname}";
    $lglobal{spellexename}
        = OS_Win
        ? dos_path($globalspellpath)
        : $globalspellpath;    # Make the exe path dos compliant
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}
        ->insert( 'end', 'Please wait, building word list....' );
    $lglobal{wclistbox}->update;
    my ( $words, $uwords );
    my $wordw = 0;
    searchoptset(qw/1 x x 0/);    # FIXME: Test for whole word search setting

    foreach ( sort ( keys %{ $lglobal{seen} } ) ) {
        if ( $_ !~ /[\x{100}-\x{FFEF}]/ ) {
            $words .= "$_\n";
        }
        else {
            next if ( exists( $projectdict{$_} ) );
            $lglobal{spellsort}->{$_} = $lglobal{seen}->{$_} || '0';
            $wordw++;
        }
    }
    if ($words) {
        utf8::decode($words);
        open( my $file, ">:bytes", "checkfil.txt" )
            ;    #save it to a file temporarily
        print $file $words;
        close $file;

        # FIXME: spellopt is getting set all over the joint
        my $spellopt
            = get_spellchecker_version() lt "0.6" ? "list " : "list ";
        $spellopt .= "-d $globalspelldictopt" if $globalspelldictopt;
        my @templist = `$lglobal{spellexename} $spellopt < "checkfil.txt"`
            ;  # feed the text to aspell, get an array of misspelled words out
        chomp @templist;    # get rid of any newlines

        for my $word (@templist) {
            next if ( exists( $projectdict{$word} ) );
            $lglobal{spellsort}->{$word} = $lglobal{seen}->{$word} || '0';
            $wordw++;
        }
    }
    $lglobal{saveheader} = "$wordw words not recognised by the spellchecker.";
    sortwords( \%{ $lglobal{spellsort} } );
    $top->Unbusy;
    unlink 'checkfil.txt';
}

sub alphanumcheck {
    $top->Busy( -recurse => 1 );
    my %display = ();
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}
        ->insert( 'end', 'Please wait, building word list....' );
    $lglobal{wclistbox}->update;
    $lglobal{wclistbox}->delete( '0', 'end' );
    my $wordw = 0;
    foreach ( keys %{ $lglobal{seen} } ) {
        next unless ( $_ =~ /\d/ );
        next unless ( $_ =~ /\p{Alpha}/ );
        $wordw++;
        $display{$_} = $lglobal{seen}->{$_};
    }
    $lglobal{saveheader} = "$wordw mixed alphanumeric words.";
    sortwords( \%display );
    $lglobal{wclistbox}->yview( 'scroll', 1, 'units' );
    $lglobal{wclistbox}->update;
    $lglobal{wclistbox}->yview( 'scroll', -1, 'units' );
    searchoptset(qw/0 x x 0/);
    $top->Unbusy;
}

sub accentcheck {
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}
        ->insert( 'end', 'Please wait, building word list....' );
    my %display = ();
    my %accent  = ();
    $lglobal{wclistbox}->update;
    my $wordw  = 0;
    my $wordwo = 0;

    foreach my $word ( keys %{ $lglobal{seen} } ) {
        if ( $word
            =~ /[\xC0-\xCF\xD1-\xD6\xD9-\xDD\xE0-\xEF\xF1-\xF6\xF9-\xFD]/ )
        {
            $wordw++;
            my $wordtemp = $word;
            $display{$word} = $lglobal{seen}->{$word}
                unless $lglobal{suspects_only};
            my @dwords = ( deaccent($word) );
            if ( $word =~ s/\xC6/Ae/ ) {
                push @dwords, ( deaccent($word) );
            }
            for my $wordd (@dwords) {
                my $line
                    = sprintf( "%-8d %s", $lglobal{seen}->{$wordd}, $wordd )
                    if $lglobal{seen}->{$wordd};
                if ( $lglobal{seen}->{$wordd} ) {
                    $display{$wordtemp} = $lglobal{seen}->{$wordtemp}
                        if $lglobal{suspects_only};
                    $display{ $wordd . ' ****' } = $lglobal{seen}->{$wordd};
                    $wordwo++;
                }
            }
            $accent{$word}++;
        }
    }
    $lglobal{saveheader}
        = "$wordw accented words, $wordwo suspects (marked with ****).";
    sortwords( \%display );
    searchoptset(qw/0 x x 0/);
    $top->Unbusy;
}

sub capscheck {
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}
        ->insert( 'end', 'Please wait, building word list....' );
    $lglobal{wclistbox}->update;
    my %display = ();
    my $wordw   = 0;
    foreach ( keys %{ $lglobal{seen} } ) {
        next if ( $_ =~ /\p{IsLower}/ );
        if ( $_ =~ /\p{IsUpper}+(?!\p{IsLower})/ ) {
            $wordw++;
            $display{$_} = $lglobal{seen}->{$_};
        }
    }
    $lglobal{saveheader} = "$wordw distinct capitalized words.";
    sortwords( \%display );
    searchoptset(qw/1 x x 0/);
    $top->Unbusy;
}

sub mixedcasecheck {
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}
        ->insert( 'end', 'Please wait, building word list....' );
    $lglobal{wclistbox}->update;
    my %display = ();
    my $wordw   = 0;
    foreach ( sort ( keys %{ $lglobal{seen} } ) ) {
        next unless ( $_ =~ /\p{IsUpper}/ );
        next unless ( $_ =~ /\p{IsLower}/ );
        next if ( $_ =~ /^\p{Upper}[\p{IsLower}\d'-]+$/ );
        $wordw++;
        $display{$_} = $lglobal{seen}->{$_};
    }
    $lglobal{saveheader} = "$wordw distinct mixed case words.";
    sortwords( \%display );
    searchoptset(qw/1 x x 0/);
    $top->Unbusy;
}

sub initcapcheck {
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}
        ->insert( 'end', 'Please wait, building word list....' );
    $lglobal{wclistbox}->update;
    my %display = ();
    my $wordw   = 0;
    foreach ( sort ( keys %{ $lglobal{seen} } ) ) {
        next unless ( $_ =~ /^\p{Upper}\P{Upper}+$/ );
        $wordw++;
        $display{$_} = $lglobal{seen}->{$_};
    }
    $lglobal{saveheader} = "$wordw distinct initial caps words.";
    sortwords( \%display );
    searchoptset(qw/1 x x 0/);
    $top->Unbusy;
}

sub charsortcheck {
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
    $lglobal{wclistbox}->update;
    my %display = ();
    my %chars;
    my $index    = '1.0';
    my $end      = $textwindow->index('end');
    my $wordw    = 0;
    my $filename = $textwindow->FileName;
    return if ( $filename =~ m/No File Loaded/ );
    savefile() unless ( $textwindow->numberChanges == 0 );
    open my $fh, '<', $filename;

    while ( my $line = <$fh> ) {
        utf8::decode($line);
        $line =~ s/^\x{FEFF}?// if ( $. < 2 );    # Drop the BOM!
        if ( $lglobal{ignore_case} ) { $line = lc($line) }
        my @words = split( //, $line );
        foreach (@words) {
            $chars{$_}++;
            $wordw++;
        }
        $index++;
        $index .= '.0';
    }
    close $fh;
    my ( $last_line, $last_col ) = split( /\./, $textwindow->index('end') );
    $wordw += ( $last_line - 2 );
    foreach ( keys %chars ) {
        next if ( $chars{$_} < 1 );
        next if ( $_ =~ / / );
        if ( $_ =~ /\t/ ) { $display{'*tab*'} = $chars{$_}; next }
        $display{$_} = $chars{$_};
    }
    $display{'*newline*'} = $last_line - 2;
    $display{'*space*'}   = $chars{' '};
    $display{'*nbsp*'}    = $chars{"\xA0"} if $chars{"\xA0"};
    delete $display{"\xA0"}  if $chars{"\xA0"};
    delete $display{"\x{d}"} if $chars{"\x{d}"};
    delete $display{"\n"}    if $chars{"\n"};
    $lglobal{saveheader} = "$wordw characters in the file.";
    sortwords( \%display );
    searchoptset(qw/0 x x 0/);
    $top->Unbusy;
}

sub stealthcheck {
    loadscannos();
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
    $lglobal{wclistbox}->update;
    my %display = ();
    my ( $line, $word, %list, @words, $scanno );
    my $index = '1.0';
    my $end   = $textwindow->index('end');
    my $wordw = 0;

    while ( ( $scanno, $word ) = each(%scannoslist) ) {
        $list{$word}   = '';
        $list{$scanno} = '';
    }
    foreach $word ( keys %{ $lglobal{seen} } ) {
        next unless exists( $list{$word} );
        $wordw++;
        $display{$word} = $lglobal{seen}->{$word};
    }
    $lglobal{saveheader} = "$wordw suspect words found in file.";
    sortwords( \%display );
    searchoptset(qw/1 x x 0/);
    $top->Unbusy;
}
## End Word Frequency

sub confirmdiscard {
    if ( $textwindow->numberChanges ) {
        my $ans = $top->messageBox(
            -icon    => 'warning',
            -type    => 'YesNoCancel',
            -default => 'yes',
            -message =>
                'The text has been modified without being saved. Save edits?'
        );
        if ( $ans =~ /yes/i ) {
            savefile();
        }
        else {
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
        $textwindow->EmptyDocument;
    }
    return $answer;
}

sub BindMouseWheel {
    my ($w) = @_;
    if (OS_Win) {
        $w->bind(
            '<MouseWheel>' => [
                sub {
                    $_[0]->yview( 'scroll', -( $_[1] / 120 ) * 3, 'units' );
                },
                Ev('D')
            ]
        );
    }
    else {
        $w->bind(
            '<4>' => sub {
                $_[0]->yview( 'scroll', -3, 'units' ) unless $Tk::strictMotif;
            }
        );
        $w->bind(
            '<5>' => sub {
                $_[0]->yview( 'scroll', +3, 'units' ) unless $Tk::strictMotif;
            }
        );
    }
}

sub working {
    my $msg = shift;
    if ( defined( $lglobal{workpop} ) && ( defined $msg ) ) {
        $lglobal{worklabel}->configure(
            -text => "\n\n\nWorking....\n$msg\nPlease wait.\n\n\n" );
        $lglobal{workpop}->update;
    }
    elsif ( defined $lglobal{workpop} ) {
        $lglobal{workpop}->destroy;
        undef $lglobal{workpop};
    }
    else {
        $lglobal{workpop} = $top->Toplevel;
        $lglobal{workpop}->transient($top);
        $lglobal{workpop}->title('Working.....');
        $lglobal{worklabel} = $lglobal{workpop}->Label(
            -text       => "\n\n\nWorking....\n$msg\nPlease wait.\n\n\n",
            -font       => '{helvetica} 20 bold',
            -background => $activecolor,
        )->pack;
        $lglobal{workpop}->resizable( 'no', 'no' );
        $lglobal{workpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{workpop}->destroy; undef $lglobal{workpop} } );
        $lglobal{workpop}->Icon( -image => $icon );
        $lglobal{workpop}->update;
    }
}

# FIXME: Just throw this crap out
sub handleDND {
    my ( $sel, $filename ) = shift;
    eval {    # In case of an error, do the SelectionGet in an eval block
        if (OS_Win) {
            $filename
                = $textwindow->SelectionGet( -selection => $sel, 'STRING' );
        }
        else {
            $filename = $textwindow->SelectionGet(
                -selection => $sel,
                'FILE_NAME'
            );
        }
    };
    if ( defined $filename && -T $filename ) {
        openfile($filename);
    }
}

sub pututf {
    my $utfpop = shift;
    my @xy     = $utfpop->pointerxy;
    my $widget = $utfpop->containing(@xy);
    my $letter = $widget->cget( -text );
    return unless $letter;
    my $ord = ord($letter);
    $letter = "&#$ord;" if ( $lglobal{uoutp} eq 'h' );
    insertit($letter);
}

sub insertit {
    my $letter  = shift;
    my $isatext = 0;
    my $spot;
    $isatext = 1 if $lglobal{hasfocus}->isa('Text');
    if ($isatext) {
        $spot = $lglobal{hasfocus}->index('insert');
        my @ranges = $lglobal{hasfocus}->tagRanges('sel');
        $lglobal{hasfocus}->delete(@ranges) if @ranges;
    }
    $lglobal{hasfocus}->insert( 'insert', $letter );
    $lglobal{hasfocus}
        ->markSet( 'insert', $spot . '+' . length($letter) . 'c' )
        if $isatext;
}

sub tblselect {
    $textwindow->tagRemove( 'table', '1.0', 'end' );
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    }
    else {
        my $end   = pop(@ranges);
        my $start = pop(@ranges);
        $textwindow->markSet( 'tblstart', $start );
        if ( $textwindow->index('tblstart') !~ /\.0/ ) {
            $textwindow->markSet( 'tblstart', $start . ' linestart' );
        }
        $textwindow->markGravity( 'tblstart', 'left' );
        $textwindow->markSet( 'tblend', $end );
        $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    }
    $textwindow->tagRemove( 'sel',     '1.0', 'end' );
    $textwindow->tagRemove( 'linesel', '1.0', 'end' );
    undef $lglobal{selectedline};
}

sub tlineremove {
    my @ranges      = $textwindow->tagRanges('linesel');
    my $range_total = @ranges;
    $operationinterrupt = 0;
    $textwindow->addGlobStart;
    if ( $range_total == 0 ) {
        $textwindow->addGlobEnd;
        return;
    }
    else {
        while (@ranges) {
            my $end   = pop(@ranges);
            my $start = pop(@ranges);
            $textwindow->replacewith( $start, $end, ' ' )
                if ( $textwindow->get($start) eq '|' );
        }
    }
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    $textwindow->tagRemove( 'linesel', '1.0', 'end' );
    $textwindow->addGlobEnd;
}

sub tlineselect {
    return unless $textwindow->index('tblstart');
    my $op         = shift;
    my @lineranges = $textwindow->tagRanges('linesel');
    $textwindow->tagRemove( 'linesel', '1.0', 'end' );
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    $operationinterrupt = 0;
    if ( $range_total == 0 ) {
        my $nextcolumn;
        if ( $op and ( $op eq 'p' ) ) {
            $textwindow->markSet( 'insert', $lineranges[0] ) if @lineranges;
            $nextcolumn = $textwindow->search(
                '-backward', '-exact',
                '--',        '|',
                'insert',    'insert linestart'
            );
        }
        else {
            $textwindow->markSet( 'insert', $lineranges[1] ) if @lineranges;
            $nextcolumn = $textwindow->search( '-exact', '--', '|', 'insert',
                'insert lineend' );
        }
        return 0 unless $nextcolumn;
        push @ranges, $nextcolumn;
        push @ranges, $textwindow->index("$nextcolumn +1c");
    }
    my $end   = pop(@ranges);
    my $start = pop(@ranges);
    my ( $row, $col ) = split /\./, $start;
    my $marker = $textwindow->get( $start, $end );
    if ( $marker ne '|' ) {
        $textwindow->tagRemove( 'sel', '1.0', 'end' );
        $textwindow->markSet( 'insert', $start );
        tlineselect($op);
        return;
    }
    $lglobal{selectedline} = $col;
    $textwindow->addGlobStart;
    $textwindow->markSet( 'insert', "$row.$col" );
    my ( $srow, $scol ) = split( /\./, $textwindow->index('tblstart') );
    my ( $erow, $ecol ) = split( /\./, $textwindow->index('tblend') );
    $erow -= 1 unless $ecol;
    for ( $srow .. $erow ) {
        $textwindow->tagAdd( 'linesel', "$_.$col" );
    }
    colcalc($srow);
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    $textwindow->addGlobEnd;
    return 1;
}

sub colcalc {
    my $srow = shift;
    my $widthline
        = $textwindow->get( "$srow.0", "$srow.$lglobal{selectedline}" );
    if ( $widthline =~ /([^|]*)$/ ) {
        $lglobal{columnspaces} = length($1);
    }
    else {
        $lglobal{columnspaces} = 0;
    }
    $lglobal{colwidthlbl}
        ->configure( -text => "Width $lglobal{columnspaces}" );
}

sub tblspace {
    my @ranges      = $textwindow->tagRanges('table');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    }
    else {
        $textwindow->addGlobStart;
        my $cursor = $textwindow->index('insert');
        my ( $erow, $ecol ) = split( /\./, ( $textwindow->index('tblend') ) );
        my ( $srow, $scol )
            = split( /\./, ( $textwindow->index('tblstart') ) );
        my $tline = $textwindow->get( "$srow.0", "$srow.end" );
        $tline =~ y/|/ /c;
        while ( $erow >= $srow ) {
            $textwindow->insert( "$erow.end", "\n$tline" )
                if length( $textwindow->get( "$erow.0", "$erow.end" ) );
            $erow--;
        }
        $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
        $textwindow->tagRemove( 'linesel', '1.0', 'end' );
        undef $lglobal{selectedline};
        $textwindow->markSet( 'insert', $cursor );
        $textwindow->addGlobEnd;
    }
}

sub tblcompress {
    my @ranges      = $textwindow->tagRanges('table');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    }
    else {
        $textwindow->addGlobStart;
        my $cursor = $textwindow->index('insert');
        my ( $erow, $ecol ) = split( /\./, ( $textwindow->index('tblend') ) );
        my ( $srow, $scol )
            = split( /\./, ( $textwindow->index('tblstart') ) );
        while ( $erow >= $srow ) {
            if ( $textwindow->get( "$erow.0", "$erow.end" ) =~ /^[ |]*$/ ) {
                $textwindow->delete( "$erow.0 -1c", "$erow.end" );
            }
            $erow--;
        }
        $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
        $textwindow->markSet( 'insert', $cursor );
        $textwindow->addGlobEnd;
    }
}

sub insertline {
    my $op     = shift;
    my $insert = $textwindow->index('insert');
    my ( $row, $col ) = split( /\./, $insert );
    my @ranges      = $textwindow->tagRanges('table');
    my $range_total = @ranges;
    $operationinterrupt = 0;
    if ( $range_total == 0 ) {
        $textwindow->bell;
        return;
    }
    else {
        $textwindow->addGlobStart;
        my $end   = pop(@ranges);
        my $start = pop(@ranges);
        my ( $srow, $scol ) = split( /\./, $start );
        my ( $erow, $ecol ) = split( /\./, $end );
        $erow -= 1 unless $ecol;
        for ( $srow .. $erow ) {
            my $rowlen = $textwindow->index("$_.end");
            my ( $lrow, $lcol ) = split( /\./, $rowlen );
            if ( $lcol < $col ) {
                $textwindow->ntinsert( "$_.end", ( ' ' x ( $col - $lcol ) ) );
            }
            if ( $op eq 'a' ) {
                $textwindow->delete("$_.$col")
                    if ( $textwindow->get("$_.$col") =~ /[ |]/ );
            }
            $textwindow->insert( "$_.$col", '|' );
        }
    }
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    $textwindow->markSet( 'insert', $insert );
    tlineselect('n');
    $textwindow->addGlobEnd;
}

sub coladjust {
    my $dir = shift;
    return 0 unless defined $lglobal{selectedline} or tlineselect();
    if ( $lglobal{tblrwcol} ) {
        $dir--;
        my @tbl;
        my $selection = $textwindow->get( 'tblstart', 'tblend' );
        my $templine
            = $textwindow->get( 'tblstart linestart', 'tblstart lineend' );
        my @col = ();
        push @col, 0;
        while ( length($templine) ) {
            my $index = index( $templine, '|' );
            if ( $index > -1 ) {
                push @col, ( $index + 1 + $col[-1] );
                substr( $templine, 0, $index + 1, '' );
                next;
            }
            $templine = '';
        }
        my $colindex;
        for ( 0 .. $#col ) {
            if ( $lglobal{selectedline} == $col[$_] - 1 ) {
                $colindex = $_;
                last;
            }
        }
        unless ($colindex) {
            $textwindow->tagRemove( 'linesel', '1.0', 'end' );
            $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
            undef $lglobal{selectedline};
            return 0;
        }
        $selection =~ s/\n +$/\n/g;
        my @table = split( /\n/, $selection );
        my $row = 0;
        my $blankline;
        for (@table) {
            my $cell = substr(
                $_,
                ( $col[ ( $colindex - 1 ) ] ),
                ( $col[$colindex] - $col[ ( $colindex - 1 ) ] - 1 ), ''
            );
            unless ($blankline) {
                $blankline = $_ if ( ( $_ =~ /^[ |]+$/ ) && ( $_ =~ /\|/ ) );
            }
            $cell .= ' ';
            $cell =~ s/^\s+$//;
            $tbl[$row] .= $cell;
            $row++;
        }
        my @cells      = ();
        my $cellheight = 1;
        my $cellflag   = 0;
        $row = 0;
        for (@tbl) {
            if ( ( length $_ ) && !$cellflag && !@cells ) {
                push @cells, 0;
                $cellflag = 1;
                next;
            }
            elsif ( ( length $_ ) && !$cellflag ) {
                push @cells, $cellheight;
                $cellheight = 1;
                $cellflag   = 1;
                next;
            }
            elsif ( !( length $_ ) && !$cellflag ) {
                $cellheight++;
                next;
            }
            elsif ( !( length $_ ) && $cellflag ) {
                $cellflag = 0;
                $cellheight++;
                next;
            }
            elsif ( ( length $_ ) && $cellflag ) {
                $cellheight++;
                next;
            }
        }
        push @cells, $cellheight;
        shift @cells unless $cells[0];
        my @tblwr;
        for my $cellcnt (@cells) {
            $templine = '';
            for ( 1 .. $cellcnt ) {
                last unless @tbl;
                $templine .= shift @tbl;
            }
            my $wrapped
                = wrapper( 0, 0,
                ( $col[$colindex] - $col[ ( $colindex - 1 ) ] + $dir ),
                $templine );
            push @tblwr, $wrapped;
        }
        my $rowcount = 0;
        $cellheight = 0;
        my $width = $col[$colindex] - $col[ ( $colindex - 1 ) ] + $dir;
        my @temptable = ();
        for (@tblwr) {
            my @temparray  = split( /\n/, $_ );
            my $tempheight = @temparray;
            my $diff       = $cells[$cellheight] - $tempheight;
            if ( $diff < 1 ) {
                for ( 1 .. $cells[$cellheight] ) {
                    my $wline = shift @temparray;
                    return 0 if ( length($wline) > $width );
                    my $pad  = $width - length($wline);
                    my $padl = int( $pad / 2 );
                    my $padr = int( $pad / 2 + .5 );
                    if ( $lglobal{tblcoljustify} eq 'l' ) {
                        $wline = $wline . ' ' x ($pad);
                    }
                    elsif ( $lglobal{tblcoljustify} eq 'c' ) {
                        $wline = ' ' x ($padl) . $wline . ' ' x ($padr);
                    }
                    elsif ( $lglobal{tblcoljustify} eq 'r' ) {
                        $wline = ' ' x ($pad) . $wline;
                    }
                    my $templine = shift @table;
                    substr( $templine, $col[ $colindex - 1 ], 0, $wline );
                    push @temptable, "$templine\n";
                }
                for (@temparray) {
                    my $pad  = $width - length($_);
                    my $padl = int( $pad / 2 );
                    my $padr = int( $pad / 2 + .5 );
                    if ( $lglobal{tblcoljustify} eq 'l' ) {
                        $_ = $_ . ' ' x ($pad);
                    }
                    elsif ( $lglobal{tblcoljustify} eq 'c' ) {
                        $_ = ' ' x ($padl) . $_ . ' ' x ($padr);
                    }
                    elsif ( $lglobal{tblcoljustify} eq 'r' ) {
                        $_ = ' ' x ($pad) . $_;
                    }
                    my $templine = $blankline;
                    substr( $templine, $col[ $colindex - 1 ], 0, $_ );
                    push @temptable, "$templine\n";
                }
                my $templine = $blankline;
                substr( $templine, $col[ $colindex - 1 ], 0, ' ' x $width );
                push @temptable, "$templine\n";
            }
            if ( $diff > 0 ) {
                for (@temparray) {
                    my $pad  = $width - length($_);
                    my $padl = int( $pad / 2 );
                    my $padr = int( $pad / 2 + .5 );
                    if ( $lglobal{tblcoljustify} eq 'l' ) {
                        $_ = $_ . ' ' x ($pad);
                    }
                    elsif ( $lglobal{tblcoljustify} eq 'c' ) {
                        $_ = ' ' x ($padl) . $_ . ' ' x ($padr);
                    }
                    elsif ( $lglobal{tblcoljustify} eq 'r' ) {
                        $_ = ' ' x ($pad) . $_;
                    }
                    return 0 if ( length($_) > $width );
                    my $templine = shift @table;
                    substr( $templine, $col[ $colindex - 1 ], 0, $_ );
                    push @temptable, "$templine\n";
                }
                for ( 1 .. $diff ) {
                    last unless @table;
                    my $templine = shift @table;
                    substr( $templine, $col[ $colindex - 1 ],
                        0, ' ' x $width );
                    push @temptable, "$templine\n";
                }
            }
            $cellheight++;
        }
        @table    = ();
        $cellflag = 0;
        for (@temptable) {
            if ( (/^[ |]+$/) && !$cellflag ) {
                $cellflag = 1;
                push @table, $_;
            }
            else {
                next if (/^[ |]+$/);
                push @table, $_;
                $cellflag = 0;
            }
        }
        $textwindow->addGlobStart;
        $textwindow->delete( 'tblstart', 'tblend' );
        for ( reverse @table ) {
            $textwindow->insert( 'tblstart', $_ );
        }
        $dir++;
    }
    else {
        my ( $srow, $scol ) = split( /\./, $textwindow->index('tblstart') );
        my ( $erow, $ecol ) = split( /\./, $textwindow->index('tblend') );
        $textwindow->addGlobStart;
        if ( $dir > 0 ) {
            for ( $srow .. $erow ) {
                $textwindow->insert( "$_.$lglobal{selectedline}", ' ' );
            }
        }
        else {
            for ( $srow .. $erow ) {
                return 0
                    if (
                    $textwindow->get("$_.@{[$lglobal{selectedline}-1]}") ne
                    ' ' );
            }
            for ( $srow .. $erow ) {
                $textwindow->delete("$_.@{[$lglobal{selectedline}-1]}");
            }
        }
    }
    $lglobal{selectedline} += $dir;
    $textwindow->addGlobEnd;
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    my ( $srow, $scol ) = split( /\./, $textwindow->index('tblstart') );
    my ( $erow, $ecol ) = split( /\./, $textwindow->index('tblend') );
    $erow -= 1 unless $ecol;
    for ( $srow .. $erow ) {
        $textwindow->tagAdd( 'linesel', "$_.$lglobal{selectedline}" );
    }
    colcalc($srow);
    return 1;
}

sub grid2step {
    my ( @table, @tbl, @trows, @tlines, @twords );
    my $row = 0;
    my $cols;
    return 0 unless ( $textwindow->markExists('tblstart') );
    unless ( $textwindow->get('tblstart') eq '|' ) {
        $textwindow->markSet( 'insert', 'tblstart' );
        insertline('i');
    }
    $lglobal{stepmaxwidth} = 70
        if ( ( $lglobal{stepmaxwidth} =~ /\D/ )
        || ( $lglobal{stepmaxwidth} < 15 ) );
    my $selection = $textwindow->get( 'tblstart', 'tblend' );
    $selection =~ s/\n +/\n/g;
    @trows = split( /^[ |]+$/ms, $selection );
    for my $trow (@trows) {
        @tlines = split( /\n/, $trow );
        my @temparray;
        for my $tline (@tlines) {
            $tline =~ s/^\|//;
            if ( $selection =~ /.\|/ ) {
                @twords = split( /\|/, $tline );
            }
            else {
                return;
            }
            my $word = 0;
            $cols = $#twords unless $cols;
            for (@twords) {
                $tbl[$row][$word] .= "$_ ";
                $word++;
            }
        }
        $row++;
    }
    $selection = '';
    my $cell = 0;
    for my $row ( 0 .. $#tbl ) {
        for ( 0 .. $cols ) {
            my $wrapped;
            $wrapped = wrapper(
                ( $cell * 5 ), ( $cell * 5 ),
                $lglobal{stepmaxwidth}, $tbl[$row][$_]
            ) if $tbl[$row][$_];
            $wrapped = " \n" unless $wrapped;
            my @temparray = split( /\n/, $wrapped );
            if ($cell) {
                for (@temparray) {
                    substr( $_, 0, ( $cell * 5 - 1 ), '    |' x $cell );
                }
            }
            push @table, @temparray;
            @temparray = ();
            $cell++;
        }
        push @table, '    |' x ($cols);
        $cell = 0;
    }
    $textwindow->addGlobStart;
    $textwindow->delete( 'tblstart', 'tblend' );
    for ( reverse @table ) {
        $textwindow->insert( 'tblstart', "$_\n" );
    }
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    undef $lglobal{selectedline};
    $textwindow->addGlobEnd;
}

sub step2grid {
    my ( @table, @tbl, @tcols );
    my $row = 0;
    my $col;
    return 0 unless ( $textwindow->markExists('tblstart') );
    my $selection = $textwindow->get( 'tblstart', 'tblend' );
    @tcols = split( /\n[ |\n]+\n/, $selection );
    for my $tcol (@tcols) {
        $col = 0;
        while ($tcol) {
            if ( $tcol =~ s/^(\S[^\n|]*)// ) {
                $tbl[$row][$col] .= $1 . ' ';
                $tcol =~ s/^[ |]+//;
                $tcol =~ s/^\n//;
            }
            else {
                $tcol =~ s/^ +\|//smg;
                $col++;
            }
        }
        $row++;
    }
    $selection = '';
    $row       = 0;
    $col       = 0;
    for $row (@tbl) {
        for (@$row) {
            $_ = wrapper( 0, 0, 20, $_ );
        }
    }
    for $row (@tbl) {
        my $line;
        while (1) {
            my $num;
            for (@$row) {
                if ( $_ =~ s/^([^\n]*)\n// ) {
                    $num = @$row;
                    $line .= $1;
                    my $pad = 20 - length($1);
                    $line .= ' ' x $pad . '|';
                }
                else {
                    $line .= ' ' x 20 . '|';
                    $num--;
                }
            }
            last if ( $num < 0 );
            $line .= "\n";
        }
        $table[$col] = $line;
        $col++;
    }
    $textwindow->addGlobStart;
    $textwindow->delete( 'tblstart', 'tblend' );
    for ( reverse @table ) {
        $textwindow->insert( 'tblstart', "$_\n" );
    }
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    $textwindow->addGlobEnd;
}

sub tblautoc {
    my ( @table, @tbl, @trows, @tlines, @twords );
    my $row = 0;
    my @cols;
    return 0 unless ( $textwindow->markExists('tblstart') );
    my $selection = $textwindow->get( 'tblstart', 'tblend' );
    @trows = split( /\n/, $selection );
    for my $tline (@trows) {
        $tline =~ s/^\|//;
        $tline =~ s/\s+$//;
        if ( $selection =~ /.\|/ ) {
            @twords = split( /\|/, $tline );
        }
        else {
            @twords = split( /  +/, $tline );
        }
        my $word = 0;
        for (@twords) {
            $_ =~ s/(^\s+)|(\s+$)//g;
            $_ = ' ' unless $_;
            my $size = ( length $_ );
            $cols[$word] = $size unless defined $cols[$word];
            $cols[$word] = $size if ( $size > $cols[$word] );
            $tbl[$row][$word] = $_;
            $word++;
        }
        $row++;
    }
    for $row ( 0 .. $#tbl ) {
        for my $word ( 0 .. $#cols ) {
            $tbl[$row][$word] = '' unless defined $tbl[$row][$word];
            my $pad = ' ' x ( $cols[$word] - ( length $tbl[$row][$word] ) );
            $table[$row] .= $tbl[$row][$word] . $pad . ' |';
        }
    }
    $textwindow->addGlobStart;
    $textwindow->delete( 'tblstart', 'tblend' );
    for ( reverse @table ) {
        $textwindow->insert( 'tblstart', "$_\n" );
    }
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    $textwindow->addGlobEnd;
}

sub fontinit {
    $lglobal{font} = "{$fontname} $fontsize $fontweight";
}

sub utffontinit {
    $lglobal{utffont} = "{$utffontname} $utffontsize";
}

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
    $lglobal{htmlimgar}        = 1;             #html image aspect ratio
    $lglobal{ignore_case}      = 0;
    $lglobal{keep_latin1}      = 1;
    $lglobal{lastmatchindex}   = '1.0';
    $lglobal{lastsearchterm}   = '';
    $lglobal{longordlabel}     = 0;
    $lglobal{proofbarvisible}  = 0;
    $lglobal{regaa}            = 0;
    $lglobal{seepagenums}      = 0;
    $lglobal{selectionsearch}  = 0;
    $lglobal{showblocksize}    = 1;
    $lglobal{spellencoding}    = "iso8859-1";
    $lglobal{stepmaxwidth}     = 70;
    $lglobal{suspects_only}    = 0;
    $lglobal{tblcoljustify}    = 'l';
    $lglobal{tblrwcol}         = 1;
    $lglobal{ToolBar}          = 1;
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
        "\x{1FFA}" => '‘\\',
        "\x{1FFB}" => '‘/',
        "\x{1FFC}" => '‘|',
        "\x{1F10}" => 'e)',
        "\x{1F11}" => 'e(',
        "\x{1F18}" => 'E)',
        "\x{1F19}" => 'E(',
        "\x{1F20}" => 'Í)',
        "\x{1F21}" => 'Í(',
        "\x{1F28}" => ' )',
        "\x{1F29}" => ' (',
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
        "\x{1F60}" => 'Ù)',
        "\x{1F61}" => 'Ù(',
        "\x{1F68}" => '‘)',
        "\x{1F69}" => '‘(',
        "\x{1F70}" => 'a\\',
        "\x{1F71}" => 'a/',
        "\x{1F72}" => 'e\\',
        "\x{1F73}" => 'e/',
        "\x{1F74}" => 'Í\\',
        "\x{1F75}" => 'Í/',
        "\x{1F76}" => 'i\\',
        "\x{1F77}" => 'i/',
        "\x{1F78}" => 'o\\',
        "\x{1F79}" => 'o/',
        "\x{1F7A}" => 'y\\',
        "\x{1F7B}" => 'y/',
        "\x{1F7C}" => 'Ù\\',
        "\x{1F7D}" => 'Ù/',
        "\x{1FB0}" => 'a=',
        "\x{1FB1}" => 'a_',
        "\x{1FB3}" => 'a|',
        "\x{1FB6}" => 'a~',
        "\x{1FB8}" => 'A=',
        "\x{1FB9}" => 'A_',
        "\x{1FBA}" => 'A\\',
        "\x{1FBB}" => 'A/',
        "\x{1FBC}" => 'A|',
        "\x{1FC3}" => 'Í|',
        "\x{1FC6}" => 'Í~',
        "\x{1FC8}" => 'E\\',
        "\x{1FC9}" => 'E/',
        "\x{1FCA}" => ' \\',
        "\x{1FCB}" => ' /',
        "\x{1FCC}" => ' |',
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
        "\x{1FF6}" => 'Ù~',
        "\x{1FF3}" => 'Ù|',
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
        "\x{1F22}" => 'Í)\\',
        "\x{1F23}" => 'Í(\\',
        "\x{1F24}" => 'Í)/',
        "\x{1F25}" => 'Í(/',
        "\x{1F26}" => 'Í~)',
        "\x{1F27}" => 'Í~(',
        "\x{1F2A}" => ' )\\',
        "\x{1F2B}" => ' (\\',
        "\x{1F2C}" => ' )/',
        "\x{1F2D}" => ' (/',
        "\x{1F2E}" => ' ~)',
        "\x{1F2F}" => ' ~(',
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
        "\x{1F62}" => 'Ù)\\',
        "\x{1F63}" => 'Ù(\\',
        "\x{1F64}" => 'Ù)/',
        "\x{1F65}" => 'Ù(/',
        "\x{1F66}" => 'Ù~)',
        "\x{1F67}" => 'Ù~(',
        "\x{1F6A}" => '‘)\\',
        "\x{1F6B}" => '‘(\\',
        "\x{1F6C}" => '‘)/',
        "\x{1F6D}" => '‘(/',
        "\x{1F6E}" => '‘~)',
        "\x{1F6F}" => '‘~(',
        "\x{1F80}" => 'a)|',
        "\x{1F81}" => 'a(|',
        "\x{1F88}" => 'A)|',
        "\x{1F89}" => 'A(|',
        "\x{1F90}" => 'Í)|',
        "\x{1F91}" => 'Í(|',
        "\x{1F98}" => ' )|',
        "\x{1F99}" => ' (|',
        "\x{1FA0}" => 'Ù)|',
        "\x{1FA1}" => 'Ù(|',
        "\x{1FA8}" => '‘)|',
        "\x{1FA9}" => '‘(|',
        "\x{1FB2}" => 'a\|',
        "\x{1FB4}" => 'a/|',
        "\x{1FB7}" => 'a~|',
        "\x{1FC2}" => 'Í\|',
        "\x{1FC4}" => 'Í/|',
        "\x{1FC7}" => 'Í~|',
        "\x{1FD2}" => 'i\+',
        "\x{1FD3}" => 'i/+',
        "\x{1FD7}" => 'i~+',
        "\x{1FE2}" => 'y\+',
        "\x{1FE3}" => 'y/+',
        "\x{1FE7}" => 'y~+',
        "\x{1FF2}" => 'Ù\|',
        "\x{1FF4}" => 'Ù/|',
        "\x{1FF7}" => 'Ù~|',
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
        "\x{1F92}" => 'Í)\|',
        "\x{1F93}" => 'Í(\|',
        "\x{1F94}" => 'Í)/|',
        "\x{1F95}" => 'Í(/|',
        "\x{1F96}" => 'Í~)|',
        "\x{1F97}" => 'Í~(|',
        "\x{1F9A}" => ' )\|',
        "\x{1F9B}" => ' (\|',
        "\x{1F9C}" => ' )/|',
        "\x{1F9D}" => ' (/|',
        "\x{1F9E}" => ' ~)|',
        "\x{1F9F}" => ' ~(|',
        "\x{1FA2}" => 'Ù)\|',
        "\x{1FA3}" => 'Ù(\|',
        "\x{1FA4}" => 'Ù)/|',
        "\x{1FA5}" => 'Ù(/|',
        "\x{1FA6}" => 'Ù~)|',
        "\x{1FA7}" => 'Ù~(|',
        "\x{1FAA}" => '‘)\|',
        "\x{1FAB}" => '‘(\|',
        "\x{1FAC}" => '‘)/|',
        "\x{1FAD}" => '‘(/|',
        "\x{1FAE}" => '‘~)|',
        "\x{1FAF}" => '‘~(|',
    );

    $lglobal{checkcolor} = (OS_Win) ? 'white' : $activecolor;
    my $scroll_gif
        = 'R0lGODlhCAAQAIAAAAAAAP///yH5BAEAAAEALAAAAAAIABAAAAIUjAGmiMutopz0pPgwk7B6/3SZphQAOw==';
    $lglobal{scrollgif} = $top->Photo(
        -data   => $scroll_gif,
        -format => 'gif',
    );
}

sub textbindings {

    # Set up a bunch of events and key bindings for the widget
    $textwindow->tagConfigure( 'footnote', -background => 'cyan' );
    $textwindow->tagConfigure( 'scannos',  -background => $highlightcolor );
    $textwindow->tagConfigure( 'bkmk',     -background => 'green' );
    $textwindow->tagConfigure( 'table',    -background => '#E7B696' );
    $textwindow->tagRaise('sel');
    $textwindow->tagConfigure( 'quotemark', -background => '#CCCCFF' );
    $textwindow->tagConfigure( 'highlight', -background => 'orange' );
    $textwindow->tagConfigure( 'linesel',   -background => '#8EFD94' );
    $textwindow->tagConfigure(
        'pagenum',
        -background  => 'yellow',
        -relief      => 'raised',
        -borderwidth => 2
    );
    $textwindow->tagBind( 'pagenum', '<ButtonRelease-1>', \&pnumadjust );
    $textwindow->eventAdd( '<<hlquote>>' => '<Control-quoteright>' );
    $textwindow->bind( '<<hlquote>>', sub { hilite('\'') } );
    $textwindow->eventAdd( '<<hldquote>>' => '<Control-quotedbl>' );
    $textwindow->bind( '<<hldquote>>', sub { hilite('"') } );
    $textwindow->eventAdd( '<<hlrem>>' => '<Control-0>' );
    $textwindow->bind(
        '<<hlrem>>',
        sub {
            $textwindow->tagRemove( 'highlight', '1.0', 'end' );
            $textwindow->tagRemove( 'quotemark', '1.0', 'end' );
        }
    );
    $textwindow->bind( 'TextUnicode', '<Control-s>' => \&savefile );
    $textwindow->bind( 'TextUnicode', '<Control-S>' => \&savefile );
    $textwindow->bind( 'TextUnicode',
        '<Control-a>' => sub { $textwindow->selectAll } );
    $textwindow->bind( 'TextUnicode',
        '<Control-A>' => sub { $textwindow->selectAll } );
    $textwindow->eventAdd(
        '<<Copy>>' => '<Control-C>',
        '<Control-c>', '<F1>'
    );
    $textwindow->bind( 'TextUnicode', '<<Copy>>' => \&copy );
    $textwindow->eventAdd(
        '<<Cut>>' => '<Control-X>',
        '<Control-x>', '<F2>'
    );
    $textwindow->bind( 'TextUnicode', '<<Cut>>' => sub { cut() } );

    $textwindow->bind( 'TextUnicode', '<Control-V>' => sub { paste() } );
    $textwindow->bind( 'TextUnicode', '<Control-v>' => sub { paste() } );
    $textwindow->bind(
        'TextUnicode',
        '<F3>' => sub {
            $textwindow->addGlobStart;
            $textwindow->clipboardColumnPaste;
            $textwindow->addGlobEnd;
        }
    );
    $textwindow->bind(
        'TextUnicode',
        '<Control-quoteleft>' => sub {
            $textwindow->addGlobStart;
            $textwindow->clipboardColumnPaste;
            $textwindow->addGlobEnd;
        }
    );

    $textwindow->bind(
        'TextUnicode',
        '<Delete>' => sub {
            my @ranges      = $textwindow->tagRanges('sel');
            my $range_total = @ranges;
            if ($range_total) {
                $textwindow->addGlobStart;
                while (@ranges) {
                    my $end   = pop @ranges;
                    my $start = pop @ranges;
                    $textwindow->delete( $start, $end );
                }
                $textwindow->addGlobEnd;
                $top->break;
            }
            else {
                $textwindow->Delete;
            }
        }
    );
    $textwindow->bind( 'TextUnicode', '<Control-l>' => sub { case ('lc'); } );
    $textwindow->bind( 'TextUnicode', '<Control-u>' => sub { case ('uc'); } );
    $textwindow->bind( 'TextUnicode',
        '<Control-t>' => sub { case ('tc'); $top->break } );
    $textwindow->bind(
        'TextUnicode',
        '<Control-Z>' => sub {
            $textwindow->undo;
            $textwindow->tagRemove( 'highlight', '1.0', 'end' );
        }
    );
    $textwindow->bind(
        'TextUnicode',
        '<Control-z>' => sub {
            $textwindow->undo;
            $textwindow->tagRemove( 'highlight', '1.0', 'end' );
        }
    );
    $textwindow->bind( 'TextUnicode',
        '<Control-Y>' => sub { $textwindow->redo } );
    $textwindow->bind( 'TextUnicode',
        '<Control-y>' => sub { $textwindow->redo } );
    $textwindow->bind( 'TextUnicode', '<Control-f>' => \&searchpopup );
    $textwindow->bind( 'TextUnicode', '<Control-F>' => \&searchpopup );
    $textwindow->bind( 'TextUnicode', '<Control-p>' => \&gotopage );
    $textwindow->bind( 'TextUnicode', '<Control-P>' => \&gotopage );
    $textwindow->bind(
        'TextUnicode',
        '<Control-w>' => sub {
            $textwindow->addGlobStart;
            floodfill();
            $textwindow->addGlobEnd;
        }
    );
    $textwindow->bind(
        'TextUnicode',
        '<Control-W>' => sub {
            $textwindow->addGlobStart;
            floodfill();
            $textwindow->addGlobEnd;
        }
    );
    $textwindow->bind( 'TextUnicode',
        '<Control-Shift-exclam>' => sub { setbookmark('1') } );
    $textwindow->bind( 'TextUnicode',
        '<Control-Shift-at>' => sub { setbookmark('2') } );
    $textwindow->bind( 'TextUnicode',
        '<Control-Shift-numbersign>' => sub { setbookmark('3') } );
    $textwindow->bind( 'TextUnicode',
        '<Control-Shift-dollar>' => sub { setbookmark('4') } );
    $textwindow->bind( 'TextUnicode',
        '<Control-Shift-percent>' => sub { setbookmark('5') } );
    $textwindow->bind( 'TextUnicode',
        '<Control-KeyPress-1>' => sub { gotobookmark('1') } );
    $textwindow->bind( 'TextUnicode',
        '<Control-KeyPress-2>' => sub { gotobookmark('2') } );
    $textwindow->bind( 'TextUnicode',
        '<Control-KeyPress-3>' => sub { gotobookmark('3') } );
    $textwindow->bind( 'TextUnicode',
        '<Control-KeyPress-4>' => sub { gotobookmark('4') } );
    $textwindow->bind( 'TextUnicode',
        '<Control-KeyPress-5>' => sub { gotobookmark('5') } );
    $textwindow->bind(
        'TextUnicode',
        '<Alt-Left>' => sub {
            $textwindow->addGlobStart;
            indent('out');
            $textwindow->addGlobEnd;
        }
    );
    $textwindow->bind(
        'TextUnicode',
        '<Alt-Right>' => sub {
            $textwindow->addGlobStart;
            indent('in');
            $textwindow->addGlobEnd;
        }
    );
    $textwindow->bind(
        'TextUnicode',
        '<Alt-Up>' => sub {
            $textwindow->addGlobStart;
            indent('up');
            $textwindow->addGlobEnd;
        }
    );
    $textwindow->bind(
        'TextUnicode',
        '<Alt-Down>' => sub {
            $textwindow->addGlobStart;
            indent('dn');
            $textwindow->addGlobEnd;
        }
    );
    $textwindow->bind( 'TextUnicode', '<F7>' => \&spellchecker );
    $textwindow->bind(
        'TextUnicode',
        '<Control-Alt-d>' => sub {
            if ($DEBUG) {
                $DEBUG = 0;
                rebuildmenu();
            }
            else {
                $DEBUG = 1;
                rebuildmenu();
            }
            print "Debug ", $DEBUG ? "on\n" : "off\n";
        }
    );
    $textwindow->bind(
        'TextUnicode',
        '<Control-Alt-s>' => sub {
            unless ( -e 'scratchpad.txt' ) {
                open my $fh, '>', 'scratchpad.txt'
                    or warn "Could not create file $!";
            }
            runner('start scratchpad.txt') if OS_Win;
        }
    );
    $textwindow->bind( 'TextUnicode',
        '<Control-Alt-r>' => sub { regexref() } );
    $textwindow->bind( 'TextUnicode', '<Shift-B1-Motion>', 'shiftB1_Motion' );
    $textwindow->eventAdd(
        '<<FindNext>>' => '<Control-Key-G>',
        '<Control-Key-g>'
    );
    $textwindow->bind( '<<ScrollDismiss>>', \&scrolldismiss );
    $textwindow->bind( 'TextUnicode', '<ButtonRelease-2>',
        sub { popscroll() unless $Tk::mouseMoved } );
    $textwindow->bind(
        '<<FindNext>>',
        sub {
            if ( $lglobal{search} ) {
                my $searchterm = $lglobal{searchentry}->get( '1.0', '1.end' );
                searchtext($searchterm);
            }
            else {
                searchpopup();
            }
        }
    );
    if (OS_Win) {
        $textwindow->bind( 'TextUnicode',
            '<3>' =>
                sub { scrolldismiss(); $menu->Popup( -popover => 'cursor' ) }
        );
    }
    else {
        $textwindow->bind( 'TextUnicode', '<3>' => sub { scrolldismiss() } )
            ;    # Try to trap odd right click error under OSX and Linux
    }
    $textwindow->bind( 'TextUnicode', '<Control-Alt-h>' => \&hilitepopup );
    $textwindow->bind( 'TextUnicode',
        '<FocusIn>' => sub { $lglobal{hasfocus} = $textwindow } );

    $lglobal{drag_img} = $top->Photo(
        -format => 'gif',
        -data   => '
R0lGODlhDAAMALMAAISChNTSzPz+/AAAAOAAyukAwRIA4wAAd8oA0MEAe+MTYHcAANAGgnsAAGAA
AAAAACH5BAAAAAAALAAAAAAMAAwAAwQfMMg5BaDYXiw178AlcJ6VhYFXoSoosm7KvrR8zfXHRQA7
'
    );

    $lglobal{hist_img} = $top->Photo(
        -format => 'gif',
        -data =>
            'R0lGODlhBwAEAIAAAAAAAP///yH5BAEAAAEALAAAAAAHAAQAAAIIhA+BGWoNWSgAOw=='
    );
    drag($textwindow);
}

sub popscroll {
    if ( $lglobal{scroller} ) {
        scrolldismiss();
        return;
    }
    my $x = $top->pointerx - $top->rootx;
    my $y = $top->pointery - $top->rooty - 8;
    $lglobal{scroller} = $top->Label(
        -background         => $textwindow->cget( -bg ),
        -image              => $lglobal{scrollgif},
        -cursor             => 'double_arrow',
        -borderwidth        => 0,
        -highlightthickness => 0,
        -relief             => 'flat',
    )->place( -x => $x, -y => $y );

    $lglobal{scroller}->eventAdd( '<<ScrollDismiss>>', qw/<1> <3>/ );
    $lglobal{scroller}
        ->bind( 'current', '<<ScrollDismiss>>', sub { scrolldismiss(); } );
    $lglobal{scroll_y}  = $y;
    $lglobal{scroll_x}  = $x;
    $lglobal{oldcursor} = $textwindow->cget( -cursor );
    %{ $lglobal{scroll_cursors} } = (
        '-1-1' => 'top_left_corner',
        '-10'  => 'top_side',
        '-11'  => 'top_right_corner',
        '0-1'  => 'left_side',
        '00'   => 'double_arrow',
        '01'   => 'right_side',
        '1-1'  => 'bottom_left_corner',
        '10'   => 'bottom_side',
        '11'   => 'bottom_right_corner',
    );
    $lglobal{scroll_id} = $top->repeat( $scrollupdatespd, \&b2scroll );
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
        $closeIndex = $textwindow->search( ']', $startIndex . '+1c', 'end' );
        my $openIndex
            = $textwindow->search( '[', $startIndex . '+1c', 'end' );
        if ( !$closeIndex ) {

            # no matching ]
            return $closeIndex;
        }
        if ( $textwindow->compare( $openIndex, '<', $closeIndex ) ) {
            $indentLevel++;
            $startIndex = $openIndex;
        }
        else {
            $indentLevel--;
            $startIndex = $closeIndex;
        }
    }
    return $closeIndex;
}

sub findgreek {
    my ($startIndex) = @_;
    my $chars;
    my $greekIndex
        = $textwindow->search( '[Greek:', $startIndex . '+5c', 'end' );
    if ($greekIndex) {
        my $closeIndex = findmatchingclosebracket($greekIndex);
        return ( $greekIndex, $closeIndex );
    }
    else {
        return ( $greekIndex, $greekIndex );
    }
}

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
    $lglobal{grtext}
        ->markSet( 'insert', $spot . '+' . length($letter) . 'c' );
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
    if ( $char =~ /[AaEe ÍIiOoYy‘ÙRr]/ ) {
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
    $phrase =~ s/hÍ/\x{1F21}/g;
    $phrase =~ s/hi/\x{1F31}/g;
    $phrase =~ s/ho/\x{1F41}/g;
    $phrase =~ s/hy/\x{1F51}/g;
    $phrase =~ s/hÙ/\x{1F61}/g;
    $phrase =~ s/ou/\x{03BF}\x{03C5}/g;
    $phrase =~ s/PS/\x{03A8}/gi;
    $phrase =~ s/HA/\x{1F09}/gi;
    $phrase =~ s/HE/\x{1F19}/gi;
    $phrase =~ s/H |HÍ/\x{1F29}/g;
    $phrase =~ s/HI/\x{1F39}/gi;
    $phrase =~ s/HO/\x{1F49}/gi;
    $phrase =~ s/HY/\x{1F59}/gi;
    $phrase =~ s/H‘|HÙ/\x{1F69}/g;
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
    $phrase =~ s/ /\x{0397}/g;
    $phrase =~ s/Í/\x{03B7}/g;
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
    $phrase =~ s/‘/\x{03A9}/g;
    $phrase =~ s/Ù/\x{03C9}/g;
    $phrase =~ s/\?/;/g;
    return $phrase;
}

sub fromgreektr {
    my $phrase = shift;
    $phrase =~ s/\x{03C2}($|\W)/s$1/g;
    $phrase =~ s/\x{03B8}/th/g;
    $phrase =~ s/\x{03B3}\x{03B3}/ng/g;
    $phrase =~ s/\x{03B3}\x{03BA}/nk/g;
    $phrase =~ s/\x{03B3}\x{03BE}/nx/g;
    $phrase =~ s/\x{1FE5}/rh/g;
    $phrase =~ s/\x{03C6}/ph/g;
    $phrase =~ s/\x{03B3}\x{03C7}/nch/g;
    $phrase =~ s/\x{03C7}/ch/g;
    $phrase =~ s/\x{03C8}/ps/g;
    $phrase =~ s/\x{1F01}/ha/g;
    $phrase =~ s/\x{1F11}/he/g;
    $phrase =~ s/\x{1F21}/hÍ/g;
    $phrase =~ s/\x{1F31}/hi/g;
    $phrase =~ s/\x{1F41}/ho/g;
    $phrase =~ s/\x{1F51}/hy/g;
    $phrase =~ s/\x{1F61}/hÙ/g;
    $phrase =~ s/\x{03A7}/Ch/g;
    $phrase =~ s/\x{0398}/Th/g;
    $phrase =~ s/\x{03A6}/Ph/g;
    $phrase =~ s/\x{03A8}/Ps/g;
    $phrase =~ s/\x{1F09}/Ha/g;
    $phrase =~ s/\x{1F19}/He/g;
    $phrase =~ s/\x{1F29}/HÍ/g;
    $phrase =~ s/\x{1F39}/Hi/g;
    $phrase =~ s/\x{1F49}/Ho/g;
    $phrase =~ s/\x{1F59}/Hy/g;
    $phrase =~ s/\x{1F69}/HÙ/g;
    $phrase =~ s/\x{0391}/A/g;
    $phrase =~ s/\x{03B1}/a/g;
    $phrase =~ s/\x{0392}/B/g;
    $phrase =~ s/\x{03B2}/b/g;
    $phrase =~ s/\x{0393}/G/g;
    $phrase =~ s/\x{03B3}/g/g;
    $phrase =~ s/\x{0394}/D/g;
    $phrase =~ s/\x{03B4}/d/g;
    $phrase =~ s/\x{0395}/E/g;
    $phrase =~ s/\x{03B5}/e/g;
    $phrase =~ s/\x{0396}/Z/g;
    $phrase =~ s/\x{03B6}/z/g;
    $phrase =~ s/\x{0397}/ /g;
    $phrase =~ s/\x{03B7}/Í/g;
    $phrase =~ s/\x{0399}/I/g;
    $phrase =~ s/\x{03B9}/i/g;
    $phrase =~ s/\x{039A}/K/g;
    $phrase =~ s/\x{03BA}/k/g;
    $phrase =~ s/\x{039B}/L/g;
    $phrase =~ s/\x{03BB}/l/g;
    $phrase =~ s/\x{039C}/M/g;
    $phrase =~ s/\x{03BC}/m/g;
    $phrase =~ s/\x{039D}/N/g;
    $phrase =~ s/\x{03BD}/n/g;
    $phrase =~ s/\x{039E}/X/g;
    $phrase =~ s/\x{03BE}/x/g;
    $phrase =~ s/\x{039F}/O/g;
    $phrase =~ s/\x{03BF}/o/g;
    $phrase =~ s/\x{03A0}/P/g;
    $phrase =~ s/\x{03C0}/p/g;
    $phrase =~ s/\x{03A1}/R/g;
    $phrase =~ s/\x{03C1}/r/g;
    $phrase =~ s/\x{03A3}/S/g;
    $phrase =~ s/\x{03C3}/s/g;
    $phrase =~ s/\x{03A4}/T/g;
    $phrase =~ s/\x{03C4}/t/g;
    $phrase =~ s/\x{03A9}/‘/g;
    $phrase =~ s/\x{03C9}/Ù/g;
    $phrase =~ s/\x{03A5}(?=\W)/Y/g;
    $phrase =~ s/\x{03C5}(?=\W)/y/g;
    $phrase =~ s/(?<=\W)\x{03A5}/U/g;
    $phrase =~ s/(?<=\W)\x{03C5}/u/g;
    $phrase =~ s/([AEIOU])\x{03A5}/$1U/g;
    $phrase =~ s/([AEIOUaeiou])\x{03C5}/$1u/g;
    $phrase =~ s/\x{03A5}/Y/g;
    $phrase =~ s/\x{03C5}/y/g;
    $phrase =~ s/;/?/g;
    $phrase =~ s/(\p{Upper}\p{Lower}\p{Upper})/\U$1\E/g;
    $phrase =~ s/([AEIOUaeiou])y/$1u/g;
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
    }
    else {
        for ( keys %{ $lglobal{grkbeta1} } ) {
            $phrase =~ s/$_/$lglobal{grkbeta1}{$_}/g;
        }
        for ( keys %{ $lglobal{grkbeta2} } ) {
            $phrase =~ s/$_/$lglobal{grkbeta2}{$_}/g;
        }
        for ( keys %{ $lglobal{grkbeta3} } ) {
            $phrase =~ s/$_/%{$lglobal{grkbeta3}}{$_}/g;
        }
        $phrase =~ s/\x{0386}/A\//g;
        $phrase =~ s/\x{0388}/E\//g;
        $phrase =~ s/\x{0389}/ \//g;
        $phrase =~ s/\x{038C}/O\//g;
        $phrase =~ s/\x{038E}/Y\//g;
        $phrase =~ s/\x{038F}/‘\//g;
        $phrase =~ s/\x{03AC}/a\//g;
        $phrase =~ s/\x{03AD}/e\//g;
        $phrase =~ s/\x{03AE}/Í\//g;
        $phrase =~ s/\x{03AF}/i\//g;
        $phrase =~ s/\x{03CC}/o\//g;
        $phrase =~ s/\x{03CE}/Ù\//g;
        $phrase =~ s/\x{03CD}/y\//g;
        return fromgreektr($phrase);
    }
}

sub betaascii {

    # Discards the accents
    my ($phrase) = @_;
    $phrase =~ s/[\)\/\\\|\~\+=_]//g;
    $phrase =~ s/r\(/rh/g;
    $phrase =~ s/([AEIOUY ‘])\(/H$1/g;
    $phrase =~ s/([aeiouyÍÙ]+)\(/h$1/g;
    return $phrase;
}

sub pageadjust {
    if ( defined $lglobal{padjpop} ) {
        $lglobal{padjpop}->deiconify;
        $lglobal{padjpop}->raise;
    }
    else {
        my @marks = $textwindow->markNames;
        my @pages = sort grep ( /^Pg\S+$/, @marks );
        my %pagetrack;

        $lglobal{padjpop} = $top->Toplevel;
        $lglobal{padjpop}->title('Configure Page Labels');
        $lglobal{padjpopgeom} = ('375x500') unless $lglobal{padjpopgeom};
        $lglobal{padjpop}->geometry( $lglobal{padjpopgeom} );
        $lglobal{padjpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{padjpopgoem} = $lglobal{padjpop}->geometry;
                $lglobal{padjpop}->destroy;
                undef $lglobal{padjpop};
            }
        );
        $lglobal{padjpop}->Icon( -image => $icon );
        my $frame0 = $lglobal{padjpop}
            ->Frame->pack( -side => 'top', -anchor => 'n', -pady => 4 );
        unless (@pages) {
            $frame0->Label(
                -text       => 'No Page Markers Found',
                -background => 'white',
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
                    }
                    elsif ( $pagetrack{$num}[3]->cget( -text ) eq 'Roman' ) {
                        $style = 'Roman';
                    }
                    if ( $style eq 'Roman' ) {
                        $label = lc( roman($index) );
                        $label =~ s/\.//;
                    }
                    else {
                        $label = $index;
                        $label =~ s/^0+// if $label and length $label;
                    }

                    if ( $pagetrack{$num}[4]->cget( -text ) eq 'No Count' ) {
                        $pagetrack{$num}[2]->configure( -text => '' );
                    }
                    else {
                        $pagetrack{$num}[2]
                            ->configure( -text => "Pg $label" );
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
                    $pagenumbers{$page}{label}
                        = $pagetrack{$num}[2]->cget( -text );
                    $pagenumbers{$page}{style}
                        = $pagetrack{$num}[3]->cget( -text );
                    $pagenumbers{$page}{action}
                        = $pagetrack{$num}[4]->cget( -text );
                    $pagenumbers{$page}{base} = $pagetrack{$num}[5]->get;
                }
                $recalc->invoke;
                $lglobal{padjpopgoem} = $lglobal{padjpop}->geometry;
                $lglobal{padjpop}->destroy;
                undef $lglobal{padjpop};
            }
        )->grid( -row => 1, -column => 2, -padx => 5 );
        my $frame1 = $lglobal{padjpop}->Scrolled(
            'Pane',
            -scrollbars => 'se',
            -background => 'white',
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
            $pagetrack{$num}[0] = $frame1->Label(
                -text       => "Image# $num  ",
                -background => 'white',
            )->grid( -row => $row, -column => 0, -padx => 2 );
            $pagetrack{$num}[1] = $frame1->Label(
                -text       => "Label -->",
                -background => 'white',
            )->grid( -row => $row, -column => 1 );

            my $temp = $num;
            $temp =~ s/^0+//;
            $pagetrack{$num}[2] = $frame1->Label(
                -text       => "Pg $temp",
                -background => 'yellow',
            )->grid( -row => $row, -column => 2 );

            $pagetrack{$num}[3] = $frame1->Button(
                -text => ( $page eq $pages[0] ) ? 'Arabic' : '"',
                -width   => 8,
                -command => [
                    sub {
                        if ( $pagetrack{ $_[0] }[3]->cget( -text ) eq
                            'Arabic' )
                        {
                            $pagetrack{ $_[0] }[3]
                                ->configure( -text => 'Roman' );
                        }
                        elsif (
                            $pagetrack{ $_[0] }[3]->cget( -text ) eq 'Roman' )
                        {
                            $pagetrack{ $_[0] }[3]->configure( -text => '"' );
                        }
                        elsif ( $pagetrack{ $_[0] }[3]->cget( -text ) eq '"' )
                        {
                            $pagetrack{ $_[0] }[3]
                                ->configure( -text => 'Arabic' );
                        }
                        else {
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
                        if ( $pagetrack{ $_[0] }[4]->cget( -text ) eq
                            'Start @' )
                        {
                            $pagetrack{ $_[0] }[4]
                                ->configure( -text => '+1' );
                        }
                        elsif (
                            $pagetrack{ $_[0] }[4]->cget( -text ) eq '+1' )
                        {
                            $pagetrack{ $_[0] }[4]
                                ->configure( -text => 'No Count' );
                        }
                        elsif ( $pagetrack{ $_[0] }[4]->cget( -text ) eq
                            'No Count' )
                        {
                            $pagetrack{ $_[0] }[4]
                                ->configure( -text => 'Start @' );
                        }
                        else {
                            $pagetrack{ $_[0] }[4]
                                ->configure( -text => '+1' );
                        }
                    },
                    $num
                ],
            )->grid( -row => $row, -column => 4, -padx => 2 );
            $pagetrack{$num}[5] = $frame1->Entry(
                -width    => 8,
                -validate => 'all',
                -vcmd     => sub { return 0 if ( $_[0] =~ /\D/ ); return 1; }
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
                $pagetrack{$num}[5]
                    ->insert( 'end', $pagenumbers{$page}{base} );
            }
        }
        $frame1->yview( 'scroll', => 1, 'units' );
        $top->update;
        $frame1->yview( 'scroll', -1, 'units' );
    }

}

## Page Number Adjust
sub pnumadjust {
    my $mark = $textwindow->index('current');
    while ( $mark = $textwindow->markPrevious($mark) ) {
        if ( $mark =~ /Pg(\d+)/ ) {
            last;
        }
    }
    $textwindow->markSet( 'insert', $mark || '1.0' );
    if ( $lglobal{pnumpop} ) {
        $lglobal{pnumpop}->deiconify;
        $lglobal{pnumpop}->raise;
        $lglobal{pagenumentry}->configure( -text => $mark );
    }
    else {
        $lglobal{pnumpop} = $top->Toplevel;
        $lglobal{pnumpop}->title('Adjust Page Markers');
        $lglobal{pnumpop}->geometry( $lglobal{pnpopgoem} )
            if $lglobal{pnpopgoem};
        my $frame2 = $lglobal{pnumpop}->Frame->pack( -pady => 5 );
        my $upbutton = $frame2->Button(
            -activebackground => $activecolor,
            -command          => \&pmoveup,
            -text             => 'Move Up',
            -width            => 10
        )->grid( -row => 1, -column => 2 );
        my $leftbutton = $frame2->Button(
            -activebackground => $activecolor,
            -command          => \&pmoveleft,
            -text             => 'Move Left',
            -width            => 10
        )->grid( -row => 2, -column => 1 );
        $lglobal{pagenumentry} = $frame2->Entry(
            -background => 'yellow',
            -relief     => 'sunken',
            -text       => $mark,
            -width      => 10,
            -justify    => 'center',
        )->grid( -row => 2, -column => 2 );
        my $rightbutton = $frame2->Button(
            -activebackground => $activecolor,
            -command          => \&pmoveright,
            -text             => 'Move Right',
            -width            => 10
        )->grid( -row => 2, -column => 3 );
        my $downbutton = $frame2->Button(
            -activebackground => $activecolor,
            -command          => \&pmovedown,
            -text             => 'Move Down',
            -width            => 10
        )->grid( -row => 3, -column => 2 );
        my $frame3 = $lglobal{pnumpop}->Frame->pack( -pady => 4 );
        my $prevbutton = $frame3->Button(
            -activebackground => $activecolor,
            -command          => \&pgprevious,
            -text             => 'Previous Marker',
            -width            => 14
        )->grid( -row => 1, -column => 1 );
        my $nextbutton = $frame3->Button(
            -activebackground => $activecolor,
            -command          => \&pgnext,
            -text             => 'Next Marker',
            -width            => 14
        )->grid( -row => 1, -column => 2 );
        my $frame4 = $lglobal{pnumpop}->Frame->pack( -pady => 5 );
        $frame4->Label( -text => 'Adjust Page Offset', )
            ->grid( -row => 1, -column => 1 );
        $lglobal{pagerenumoffset} = $frame4->Spinbox(
            -textvariable => 0,
            -from         => -999,
            -to           => 999,
            -increment    => 1,
            -width        => 6,
        )->grid( -row => 2, -column => 1 );
        $frame4->Button(
            -activebackground => $activecolor,
            -command          => \&pgrenum,
            -text             => 'Renumber',
            -width            => 12
        )->grid( -row => 3, -column => 1, -pady => 3 );
        my $frame5 = $lglobal{pnumpop}->Frame->pack( -pady => 5 );
        $frame5->Button(
            -activebackground => $activecolor,
            -command          => sub { $textwindow->bell unless pageadd() },
            -text             => 'Add',
            -width            => 8
        )->grid( -row => 1, -column => 1 );
        $frame5->Button(
            -activebackground => $activecolor,
            -command          => sub {
                my $insert = $textwindow->index('insert');
                unless ( pageadd() ) {
                    ;
                    $lglobal{pagerenumoffset}
                        ->configure( -textvariable => '1' );
                    $textwindow->markSet( 'insert', $insert );
                    pgrenum();
                    $textwindow->markSet( 'insert', $insert );
                    pageadd();
                }
                $textwindow->markSet( 'insert', $insert );
            },
            -text  => 'Insert',
            -width => 8
        )->grid( -row => 1, -column => 2 );
        $frame5->Button(
            -activebackground => $activecolor,
            -command          => \&pageremove,
            -text             => 'Remove',
            -width            => 8
        )->grid( -row => 1, -column => 3 );
        my $frame6 = $lglobal{pnumpop}->Frame->pack( -pady => 5 );
        $frame6->Button(
            -activebackground => $activecolor,
            -command          => sub {
                viewpagenums();
                $textwindow->addGlobStart;
                my @marks = $textwindow->markNames;
                for ( sort @marks ) {
                    if ( $_ =~ /Pg(\d+)/ ) {
                        my $pagenum = '[Pg ' . $1 . ']';
                        $textwindow->insert( $_, $pagenum );
                    }
                }
                $textwindow->addGlobEnd;
            },
            -text  => 'Insert Page Markers',
            -width => 20,
        )->grid( -row => 1, -column => 1 );

        $lglobal{pnumpop}->bind( $lglobal{pnumpop}, '<Up>'   => \&pmoveup );
        $lglobal{pnumpop}->bind( $lglobal{pnumpop}, '<Left>' => \&pmoveleft );
        $lglobal{pnumpop}
            ->bind( $lglobal{pnumpop}, '<Right>' => \&pmoveright );
        $lglobal{pnumpop}->bind( $lglobal{pnumpop}, '<Down>' => \&pmovedown );
        $lglobal{pnumpop}
            ->bind( $lglobal{pnumpop}, '<Prior>' => \&pgprevious );
        $lglobal{pnumpop}->bind( $lglobal{pnumpop}, '<Next>' => \&pgnext );
        $lglobal{pnumpop}
            ->bind( $lglobal{pnumpop}, '<Delete>' => \&pageremove );
        $lglobal{pnumpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{pnpopgoem} = $lglobal{pnumpop}->geometry;
                $lglobal{pnumpop}->destroy;
                undef $lglobal{pnumpop};
                viewpagenums() if ( $lglobal{seepagenums} );
            }
        );
        $lglobal{pnumpop}->Icon( -image => $icon );
        if (OS_Win) {
            $lglobal{pagerenumoffset}->bind(
                $lglobal{pagerenumoffset},
                '<MouseWheel>' => [
                    sub {
                        ( $_[1] > 0 )
                            ? $lglobal{pagerenumoffset}->invoke('buttonup')
                            : $lglobal{pagerenumoffset}->invoke('buttondown');
                    },
                    Ev('D')
                ]
            );
        }
    }
}

sub pageremove {    # Delete a page marker
    my $num = $lglobal{pagenumentry}->get;
    $num = $textwindow->index('insert') unless $num;
    viewpagenums() if $lglobal{seepagenums};
    $textwindow->markUnset($num);
    %pagenumbers = ();
    my @marks = $textwindow->markNames;
    for (@marks) {
        $pagenumbers{$_}{offset} = $textwindow->index($_) if $_ =~ /Pg\S+/;
    }
    viewpagenums();
}

sub pageadd {    # Add a page marker
    my ( $prev, $next, $mark, $length );
    my $insert = $textwindow->index('insert');
    $textwindow->markSet( 'insert', '1.0' );
    $prev = $insert;
    while ( $prev = $textwindow->markPrevious($prev) ) {
        if ( $prev =~ /Pg(\S+)/ ) {
            $mark   = $1;
            $length = length($1);
            last;
        }
    }
    unless ($prev) {
        $prev = $insert;
        while ( $prev = $textwindow->markNext($prev) ) {
            if ( $prev =~ /Pg(\S+)/ ) {
                $mark   = 0;
                $length = length($1);
                last;
            }
        }
        $prev = '1.0';
    }
    $mark = sprintf( "%0" . $length . 'd', $mark + 1 );
    $mark = "Pg$mark";
    $textwindow->markSet( 'insert', $insert );
    return 0 if ( $textwindow->markExists($mark) );
    viewpagenums() if $lglobal{seepagenums};
    $textwindow->markSet( $mark, $insert );
    $textwindow->markGravity( $mark, 'left' );
    %pagenumbers = ();
    my @marks = $textwindow->markNames;

    for (@marks) {
        $pagenumbers{$_}{offset} = $textwindow->index($_) if $_ =~ /Pg\S+/;
    }
    $lglobal{seepagenums} = 0;
    viewpagenums();
    return 1;
}

sub pgrenum {    # Re sequence page markers
    my ( $mark, $length, $num, $start, $end );
    my $offset = $lglobal{pagerenumoffset}->get;
    return if $offset !~ m/-?\d+/;
    my @marks;
    if ( $offset < 0 ) {
        @marks = ( sort( keys(%pagenumbers) ) );
        $num = $start = $lglobal{pagenumentry}->get;
        $start =~ s/Pg(\d+)/$1/;
        while ( $num = $textwindow->markPrevious($num) ) {
            if ( $num =~ /Pg\d+/ ) {
                $mark = $num;
                $mark =~ s/Pg(\d+)/$1/;
                if ( ( $mark - $start ) le $offset ) {
                    $offset = ( $mark - $start + 1 );
                }
                last;
            }
        }
        while ( !( $textwindow->markExists( $marks[$#marks] ) ) ) {
            pop @marks;
        }
        $end   = $marks[$#marks];
        $start = $lglobal{pagenumentry}->get;
        while ( $marks[0] ne $start ) { shift @marks }
    }
    else {
        @marks = reverse( sort( keys(%pagenumbers) ) );
        while ( !( $textwindow->markExists( $marks[0] ) ) ) { shift @marks }
        $start = $textwindow->index('end');
        $num   = $textwindow->index('insert');
        while ( $num = $textwindow->markNext($num) ) {
            if ( $num =~ /Pg\d+/ ) {
                $end = $num;
                last;
            }
        }
        $end = $lglobal{pagenumentry}->get unless $end;
        while ( $marks[$#marks] ne $end ) { pop @marks }
    }
    $textwindow->bell unless $offset;
    return unless $offset;
    $lglobal{seepagenums} = 1;
    viewpagenums();
    $textwindow->markSet( 'insert', '1.0' );
    %pagenumbers = ();
    while (1) {
        $start = shift @marks;
        last unless $start;
        $start =~ /Pg(\d+)/;
        $mark   = $1;
        $length = length($1);
        $mark   = sprintf( "%0" . $length . 'd', $mark + $offset );
        $mark   = "Pg$mark";
        $num    = $start;
        $start  = $textwindow->index($num);
        $textwindow->markUnset($num);
        $textwindow->markSet( $mark, $start );
        $textwindow->markGravity( $mark, 'left' );
        next if @marks;
        last;
    }
    @marks = $textwindow->markNames;
    for (@marks) {
        $pagenumbers{$_}{offset} = $textwindow->index($_) if $_ =~ /Pg\d+/;
    }
    $lglobal{seepagenums} = 0;
    viewpagenums();
}

sub pgprevious {    #move focus to previous page marker
    my $mark;
    my $num = $lglobal{pagenumentry}->get;
    $num = $textwindow->index('insert') unless $num;
    $mark = $num;
    while ( $num = $textwindow->markPrevious($num) ) {
        if ( $num =~ /Pg\S+/ ) { $mark = $num; last; }
    }
    $lglobal{pagenumentry}->delete( '0', 'end' );
    $lglobal{pagenumentry}->insert( 'end', $mark );
    $textwindow->yviewMoveto('1.0');
    $textwindow->see($mark);
}

sub pgnext {    #move focus to next page marker
    my $mark;
    my $num = $lglobal{pagenumentry}->get;
    $num = $textwindow->index('insert') unless $num;
    $mark = $num;
    while ( $num = $textwindow->markNext($num) ) {
        if ( $num =~ /Pg\S+/ ) { $mark = $num; last; }
    }
    $lglobal{pagenumentry}->delete( '0', 'end' );
    $lglobal{pagenumentry}->insert( 'end', $mark );
    $textwindow->yviewMoveto('1.0');
    $textwindow->see($mark);
}

sub pmoveup {    # move the page marker up a line
    my $mark;
    my $num = $lglobal{pagenumentry}->get;
    $num = $textwindow->index('insert') unless $num;
    $mark = $num;
    while ( $num = $textwindow->markPrevious($num) ) {
        last
            if $num =~ /Pg\S+/;
    }
    $num = '1.0' unless $num;
    my $pagenum = " $mark ";
    my $index   = $textwindow->index("$mark-1l");

    if ( $num eq '1.0' ) {
        return if $textwindow->compare( $index, '<', '1.0' );
    }
    else {
        return
            if $textwindow->compare( $index, '<',
            ( $textwindow->index( $num . '+' . length($pagenum) . 'c' ) ) );
    }
    $textwindow->ntdelete( $mark, $mark . ' +' . length($pagenum) . 'c' );
    $textwindow->markSet( $mark, $index );
    $textwindow->markGravity( $mark, 'right' );
    $textwindow->ntinsert( $mark, $pagenum );
    $textwindow->tagAdd( 'pagenum', $mark,
        $mark . ' +' . length($pagenum) . 'c' );
    $textwindow->see($mark);
}

sub pmoveleft {    # move the page marker left a character
    my $mark;
    my $num = $lglobal{pagenumentry}->get;
    $num = $textwindow->index('insert') unless $num;
    $mark = $num;
    while ( $num = $textwindow->markPrevious($num) ) {
        last
            if $num =~ /Pg\S+/;
    }
    $num = '1.0' unless $num;
    my $pagenum = " $mark ";
    my $index   = $textwindow->index("$mark-1c");

    if ( $num eq '1.0' ) {
        return if $textwindow->compare( $index, '<', '1.0' );
    }
    else {
        return
            if $textwindow->compare( $index, '<',
            ( $textwindow->index( $num . '+' . length($pagenum) . 'c' ) ) );
    }
    $textwindow->ntdelete( $mark, $mark . ' +' . length($pagenum) . 'c' );
    $textwindow->markSet( $mark, $index );
    $textwindow->markGravity( $mark, 'left' );
    $textwindow->ntinsert( $mark, $pagenum );
    $textwindow->tagAdd( 'pagenum', $mark,
        $mark . ' +' . length($pagenum) . 'c' );
    $textwindow->see($mark);
}

sub pmoveright {    # move the page marker right a character
    my $mark;
    my $num = $lglobal{pagenumentry}->get;
    $num = $textwindow->index('insert') unless $num;
    $mark = $num;
    while ( $num = $textwindow->markNext($num) ) { last if $num =~ /Pg\S+/ }
    $num = $textwindow->index('end') unless $num;
    my $pagenum = " $mark ";
    my $index   = $textwindow->index("$mark+1c");
    if ($textwindow->compare(
            $index,
            '>=',
            $textwindow->index($mark) . 'lineend -' . length($pagenum) . 'c'
        )
        )
    {
        $index = $textwindow->index(
            $textwindow->index($mark) . ' +1l linestart' );
    }
    if ( $textwindow->compare( $num, '==', 'end' ) ) {
        return if $textwindow->compare( $index, '>=', 'end' );
    }
    else {
        return
            if $textwindow->compare( $index . '+' . length($pagenum) . 'c',
            '>=', $num );
    }
    $textwindow->ntdelete( $mark, $mark . ' +' . length($pagenum) . 'c' );
    $textwindow->markSet( $mark, $index );
    $textwindow->markGravity( $mark, 'left' );
    $textwindow->ntinsert( $mark, $pagenum );
    $textwindow->tagAdd( 'pagenum', $mark,
        $mark . ' +' . length($pagenum) . 'c' );
    $textwindow->see($mark);
}

sub pmovedown {    # move the page marker down a line
    my $mark;
    my $num = $lglobal{pagenumentry}->get;
    $num = $textwindow->index('insert') unless $num;
    $mark = $num;
    while ( $num = $textwindow->markNext($num) ) { last if $num =~ /Pg\S+/ }
    $num = $textwindow->index('end') unless $num;
    my $pagenum = " $mark ";
    my $index   = $textwindow->index("$mark+1l");
    if ( $textwindow->compare( $num, '==', 'end' ) ) {
        return if $textwindow->compare( $index, '>=', 'end' );
    }
    else {
        return if $textwindow->compare( $index, '>', $num );
    }
    $textwindow->ntdelete( $mark, $mark . ' +' . length($pagenum) . 'c' );
    $textwindow->markSet( $mark, $index );
    $textwindow->markGravity( $mark, 'left' );
    $textwindow->ntinsert( $mark, $pagenum );
    $textwindow->tagAdd( 'pagenum', $mark,
        $mark . ' +' . length($pagenum) . 'c' );
    $textwindow->see($mark);
}
## End Page Number Adjust

## Save setting.rc file
sub saveset {
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
    $geometry = $top->geometry unless $geometry;
    if ( open my $save_handle, '>', $savefile ) {
        print $save_handle $message;
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

sub os_normal {
    $_[0] =~ s|/|\\|g if OS_Win;
    return $_[0];
}

sub escape_problems {
    $_[0] =~ s/\\+$/\\\\/g;
    $_[0] =~ s/(?!<\\)'/\\'/g;
    return $_[0];
}

sub utflabel_bind {
    my ( $widget, $block, $start, $end ) = @_;
    $widget->bind( '<Enter>',
        sub { $widget->configure( -background => $activecolor ); } );
    $widget->bind( '<Leave>',
        sub { $widget->configure( -background => 'white' ); } );
    $widget->bind(
        '<ButtonPress-1>',
        sub {
            utfpopup( $block, $start, $end );
        }
    );
}

sub utfchar_bind {
    my $widget = shift;
    $widget->bind( '<Enter>',
        sub { $widget->configure( -background => $activecolor ); } );
    $widget->bind( '<Leave>',
        sub { $widget->configure( -background => 'white' ) } );
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
    my $corner_label   = $corner->Label( -image => $lglobal{drag_img} )
        ->pack( -side => 'bottom', -anchor => 'se' );
    $corner_label->bind(
        '<Enter>',
        sub {
            if (OS_Win) {
                $corner->configure( -cursor => 'size_nw_se' );
            }
            else {
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

sub jeebiesrun {
    my $listbox = shift;
    $listbox->delete( '0', 'end' );
    savefile() if ( $textwindow->numberChanges );
    my $title = os_normal( $lglobal{global_filename} );
    $title = dos_path($title) if OS_Win;
    my $types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
    unless ($jeebiespath) {
        $jeebiespath = $textwindow->getOpenFile(
            -filetypes => $types,
            -title     => 'Where is the Jeebies executable?'
        );
    }
    return unless $jeebiespath;
    my $jeebiesoptions = "-$jeebiesmode" . 'e';
    $jeebiespath = os_normal($jeebiespath);
    $jeebiespath = dos_path($jeebiespath) if OS_Win;
    %jeeb        = ();
    my $mark = 0;
    $top->Busy( -recurse => 1 );
    $listbox->insert( 'end',
        '---------------- Please wait: Processing. ----------------' );
    $listbox->update;

    if ( open my $fh, '-|', "$jeebiespath $jeebiesoptions $title" ) {
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
    }
    else {
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
    $geometry2 = $lglobal{jeepop}->geometry;
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
    $oops->add( 'Label',
        -text =>
            "Your Perl installation is missing some files\nthat are critical for some Unicode operations.\n"
            . "Do you want to download/install them?\n(You need to have an active internet connection.)\n"
            . "If running under Linux or OSX, you will probably need to run the command\n\"sudo perl /[pathto]/guiguts/update_unicore.pl\"\n"
            . "in a terminal window for the updates to be installed correctly.",
    )->pack;
    $oops->Show;
    return 0;
}

#### Levenshtein edit distance calculations #################
#### taken from the Text::Levenshtein Module ################
#### If available, uses Text::LevenshteinXS #################
#### which is orders of magnitude faster. ###################

sub distance {
    if ( $lglobal{LevenshteinXS} ) {
        return Text::LevenshteinXS::distance(@_);
    }

    no warnings;
    my $word1 = shift;
    my $word2 = shift;

    return 0 if $word1 eq $word2;
    my @d;

    my $len1 = length $word1;
    my $len2 = length $word2;

    $d[0][0] = 0;
    for ( 1 .. $len1 ) {
        $d[$_][0] = $_;
        return $_
            if $_ != $len1 && substr( $word1, $_ ) eq substr( $word2, $_ );
    }
    for ( 1 .. $len2 ) {
        $d[0][$_] = $_;
        return $_
            if $_ != $len2 && substr( $word1, $_ ) eq substr( $word2, $_ );
    }

    for my $i ( 1 .. $len1 ) {
        my $w1 = substr( $word1, $i - 1, 1 );
        for ( 1 .. $len2 ) {
            $d[$i][$_] = _min(
                $d[ $i - 1 ][$_] + 1,
                $d[$i][ $_ - 1 ] + 1,
                $d[ $i - 1 ][ $_ - 1 ]
                    + ( $w1 eq substr( $word2, $_ - 1, 1 ) ? 0 : 1 )
            );
        }
    }
    return $d[$len1][$len2];
}

sub _min {
    return
          $_[0] < $_[1]
        ? $_[0] < $_[2]
            ? $_[0]
            : $_[2]
        : $_[1] < $_[2] ? $_[1]
        :                 $_[2];
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
        for ( my @x
        = map { [ $_[0]->{$_}, $_, lc deaccent $_ ] } keys %{ $_[0] } );
    map { $_->[1] } sort { $b->[0] <=> $a->[0] or $a->[2] cmp $b->[2] } @x;
}

## Low level file processing functions

# This turns long Windows path to DOS path, e.g., C:\Program Files\
# becomes C:\Progra~1\.
# Probably need this for DOS command window on Win98/95. Needed for XP also.
sub dos_path {
    $_[0] = Win32::GetShortPathName( $_[0] );
    return $_[0];
}

## FIXME: These are barfing on Unix systems, apparently.
# Normalize line endings
#sub eol_convert {
#    my $regex = qr(\cM\cJ|\cM|\cJ); # Windows/Mac/Unix
#    my $line = shift(@_);
#    $line =~ s/$regex/\n/g;
#    return $line;
#}

#sub eol_whitespace {
#    my $line = shift(@_);
#    my $regex = qr([\t \xA0]+$); #tab space no-break space
#    $line =~ s/$regex//;
#    return $line;
#}

## HTML processing routines
sub htmlbackup {
    $textwindow->Busy;
    my $savefn = $lglobal{global_filename};
    $lglobal{global_filename} =~ s/\.[^\.]*?$//;
    my $newfn = $lglobal{global_filename} . '-htmlbak.txt';
    working("Saving backup of file\nto $newfn");
    $textwindow->SaveUTF($newfn);
    $lglobal{global_filename} = $newfn;
    binsave();
    $lglobal{global_filename} = $savefn;
    $textwindow->FileName($savefn);
}

sub html_convert_codepage {
    working("Converting Windows Codepage 1252\ncharacters to Unicode");
    cp1252toUni();
}

sub html_convert_ampersands {
    working("Converting Ampersands");
    named( '&(?![\w#])', '&amp;' );
    named( '&$',         '&amp;' );
    named( '& ',         '&amp; ' );
    named( '&c\.',       '&amp;c.' );
    named( '&c,',        '&amp;c.,' );
    named( '&c ',        '&amp;c. ' );
}

# double hyphens go to character entity ref. FIXME: Add option for real emdash.
sub html_convert_emdashes {
    working("Converting Emdashes");
    named( '(?<=[^-!])--(?=[^>])', '&mdash;' );
    named( '(?<=[^<])!--(?=[^>])', '!&mdash;' );
    named( '(?<=[^-])--$',         '&mdash;' );
    named( '^--(?=[^-])',          '&mdash;' );
    named( "\x{A0}",               '&nbsp;' );
}

# convert latin1 and utf charactes to HTML Character Entity Reference's.
sub html_convert_latin1 {
    working("Converting Latin-1 Characters...");
    for ( 128 .. 255 ) {
        my $from = lc sprintf( "%x", $_ );
        named( '\x' . $from, entity( '\x' . $from ) );
    }
}

sub html_convert_utf {
    my $blockstart = @_;
    if ( $lglobal{leave_utf} ) {
        $blockstart
            = $textwindow->search( '-exact', '--', 'charset=iso-8859-1',
            '1.0', 'end' );
        if ($blockstart) {
            $textwindow->ntdelete( $blockstart, "$blockstart+18c" );
            $textwindow->ntinsert( $blockstart, 'charset=UTF-8' );
        }
    }
    unless ( $lglobal{leave_utf} ) {
        working("Converting UTF-8...");
        while (
            $blockstart = $textwindow->search(
                '-regexp', '--', '[\x{100}-\x{65535}]', '1.0', 'end'
            )
            )
        {
            my $xchar = ord( $textwindow->get($blockstart) );
            $textwindow->ntdelete($blockstart);
            $textwindow->ntinsert( $blockstart, "&#$xchar;" );
        }
    }

}

# Set <head><title></title></head>
#sub html_set_title { }

# Set author name in <title></title>
#sub html_set_author { }

# FIXME: Should be a general purpose function
sub html_cleanup_markers {
    my ( $blockstart, $xler, $xlec, $blockend ) = @_;

    working("Cleaning up\nblock Markers");

    while ( $blockstart
        = $textwindow->search( '-regexp', '--', '^\/[\*\$\#]', '1.0', 'end' )
        )
    {
        ( $xler, $xlec ) = split /\./, $blockstart;
        $blockend = "$xler.end";
        $textwindow->ntdelete( "$blockstart-1c", $blockend );
    }
    while ( $blockstart
        = $textwindow->search( '-regexp', '--', '^[\*\$\#]\/', '1.0', 'end' )
        )
    {
        ( $xler, $xlec ) = split /\./, $blockstart;
        $blockend = "$xler.end";
        $textwindow->ntdelete( "$blockstart-1c", $blockend );
    }
    while ( $blockstart
        = $textwindow->search( '-regexp', '--', '<\/h\d><br />', '1.0',
            'end' ) )
    {
        $textwindow->ntdelete( "$blockstart+5c", "$blockstart+9c" );
    }

}

#sub html_parse_header {
#
#    working('Parsing Header');
#
#    $selection = $textwindow->get( '1.0', '1.end' );
#    if ( $selection =~ /DOCTYPE/ ) {
#        $step = 1;
#        while (1) {
#            $selection = $textwindow->get( "$step.0", "$step.end" );
#            $headertext .= ( $selection . "\n" );
#            $textwindow->ntdelete( "$step.0", "$step.end" );
#            last if ( $selection =~ /^\<body/ );
#            $step++;
#            last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
#        }
#        $textwindow->ntdelete( '1.0', "$step.0 +1c" );
#    } else {
#        open my $infile, '<', 'header.txt'
#            or warn "Could not open header file. $!\n";
#        while (<$infile>) {
#            $_ =~ s/\cM\cJ|\cM|\cJ/\n/g;
#            # FIXME: $_ = eol_convert($_);
#            $headertext .= $_;
#        }
#        close $infile;
#    }
#}

sub html_convert_subscripts {
    my ( $selection, $step ) = @_;

    if ( $selection =~ s/_\{([^}]+?)\}/<sub>$1<\/sub>/g ) {
        $textwindow->ntdelete( "$step.0", "$step.end" );
        $textwindow->ntinsert( "$step.0", $selection );
    }
}

# FIXME: Doesn't convert Gen^rl; workaround Gen^{rl}
sub html_convert_superscripts {
    my ( $selection, $step ) = @_;

    if ( $selection =~ s/\^\{([^}]+?)\}/<sup>$1<\/sup>/g ) {
        $textwindow->ntdelete( "$step.0", "$step.end" );
        $textwindow->ntinsert( "$step.0", $selection );
    }
}

sub html_convert_tb {
    no warnings;    # FIXME: Warning-- Exiting subroutine via next
    my ( $selection, $step ) = @_;

    if ( $selection =~ s/\s{7}(\*\s{7}){4}\*/<hr style="width: 45%;" \/>/ ) {
        $textwindow->ntdelete( "$step.0", "$step.end" );
        $textwindow->ntinsert( "$step.0", $selection );
        next;
    }

    if ( $selection =~ s/<tb>/<hr style="width: 45%;" \/>/ ) {
        $textwindow->ntdelete( "$step.0", "$step.end" );
        $textwindow->ntinsert( "$step.0", $selection );
        next;
    }

}

### Internal Routines
## Status Bar
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
            $textwindow->showlinenum if $vislnnm;
            $textwindow->hidelinenum unless $vislnnm;
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
            }
            else {
                $lglobal{showblocksize} = 1;
            }
        }
    );
    $lglobal{selectionlabel}->bind( '<Double-1>', sub { selection() } );
    $lglobal{selectionlabel}->bind(
        '<3>',
        sub {
            if ( $textwindow->markExists('selstart') ) {
                $textwindow->tagAdd( 'sel', 'selstart', 'selend' );
            }
        }
    );
    $lglobal{selectionlabel}->bind(
        '<Shift-3>',
        sub {
            $textwindow->tagRemove( 'sel', '1.0', 'end' );
            if ( $textwindow->markExists('selstart') ) {
                my ( $srow, $scol ) = split /\./,
                    $textwindow->index('selstart');
                my ( $erow, $ecol ) = split /\./,
                    $textwindow->index('selend');
                for ( $srow .. $erow ) {
                    $textwindow->tagAdd( 'sel', "$_.$scol", "$_.$ecol" );
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
            }
            else {
                scannosfile() unless $scannoslist;
                return unless $scannoslist;
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
            if ( $textwindow->OverstrikeMode ) {
                $textwindow->OverstrikeMode(0);
            }
            else {
                $textwindow->OverstrikeMode(1);
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
    $lglobal{statushelp} = $top->Balloon( -initwait => 1000 );
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

# Routine to update the status bar when somthing has changed.
sub update_indicators {
    my ( $last_line, $last_col ) = split( /\./, $textwindow->index('end') );
    my ( $line, $column ) = split( /\./, $textwindow->index('insert') );
    $lglobal{current_line_label}->configure(
        -text => "Ln: $line/" . ( $last_line - 1 ) . "  -  Col: $column" );
    my $mode             = $textwindow->OverstrikeMode;
    my $overstrke_insert = ' I ';
    if ($mode) {
        $overstrke_insert = ' O ';
    }
    $lglobal{insert_overstrike_mode_label}
        ->configure( -text => " $overstrke_insert " );
    my $filename = $textwindow->FileName;
    $filename = 'No File Loaded' unless ( defined($filename) );
    $lglobal{highlighlabel}->configure( -background => $highlightcolor )
        if ( $lglobal{scanno_hl} );
    $lglobal{highlighlabel}->configure( -background => 'gray' )
        unless ( $lglobal{scanno_hl} );
    $filename = os_normal($filename);
    my $edit_flag = '';
    my $ordinal   = ord( $textwindow->get('insert') );
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

    }
    else {
        $lglobal{ordinallabel}->configure(
            -text  => " Dec $ordinal : Hex $hexi ",
            -width => 18
        );
    }
    if ( $textwindow->numberChanges ) {
        $edit_flag = 'edited';
    }

    # window label format: GG-version - [edited] - [file name]
    if ($edit_flag) {
        $top->configure( -title => $window_title . " - "
                . $edit_flag . " - "
                . $filename );
    }
    else {
        $top->configure( -title => $window_title . " - " . $filename );
    }

    #FIXME: need some logic behind this

    $lglobal{global_filename} = $filename;
    $textwindow->idletasks;
    my ( $mark, $pnum );
    my $markindex = $textwindow->index('insert');
    if ( $filename ne 'No File Loaded' or defined $lglobal{prepfile} ) {
        $lglobal{page_num_label}->configure( -text => 'Img: XXX' )
            if defined $lglobal{page_num_label};
        $lglobal{page_label}->configure( -text => ("Lbl: None ") )
            if defined $lglobal{page_label};
        $mark = $textwindow->markPrevious($markindex);
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
                }
                else {
                    $lglobal{page_label}
                        ->configure( -text => ("Lbl: None ") );
                }
                last;
            }
            else {
                if ( $textwindow->index('insert')
                    > ( $textwindow->index($mark) + 400 ) )
                {
                    last;
                }
                $mark = $textwindow->markPrevious($mark) if $mark;
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
    $textwindow->tagRemove( 'bkmk', '1.0', 'end' ) unless $bkmkhl;
    if ( $lglobal{geometryupdate} ) {
        saveset();
        $lglobal{geometryupdate} = 0;
    }

    # FIXME: Can this go? Maybe.
    if ( $autosave and $lglobal{autosaveinterval} and $DEBUG ) {
        my $elapsed
            = $autosaveinterval * 60 - ( time - $lglobal{autosaveinterval} );
        printf "%d:%02d\n", int( $elapsed / 60 ), $elapsed % 60;
    }
}

## Spell Check

# Initialize spellchecker
sub spellcheckfirst {
    $lglobal{spellexename}
        = ( OS_Win ? dos_path($globalspellpath) : $globalspellpath )
        ;    # Make the exe path dos compliant
    $lglobal{spellfilename} = (
        OS_Win
        ? dos_path( $lglobal{global_filename} )
        : $lglobal{global_filename}
    );       # make the file path dos compliant
    @{ $lglobal{misspelledlist} } = ();
    viewpagenums() if ( $lglobal{seepagenums} );
    getprojectdic();
    do "$lglobal{projectdictname}";
    $lglobal{lastmatchindex} = '1.0';

    # get list of mispelled words in selection (or file if nothing selected)
    spellget_misspellings();
    my $term = $lglobal{misspelledlist}[0];    # get first mispelled term
    $lglobal{misspelledentry}->delete( '0', 'end' );
    $lglobal{misspelledentry}->insert( 'end', $term )
        ;    # put it in the appropriate text box
    $lglobal{suggestionlabel}->configure( -text => 'Suggestions:' );
    return unless $term;    # no mispellings found, bail
    $lglobal{matchlength} = '0';
    $lglobal{matchindex}  = $textwindow->search(
        -forwards,
        -count => \$lglobal{matchlength},
        $term, $lglobal{spellindexstart}, 'end'
    );                      # search for the mispelled word in the text
    $lglobal{lastmatchindex}
        = spelladjust_index( $lglobal{matchindex}, $term )
        ;                   # find the index of the end of the match
    spelladdtexttags();     # highlight the word in the text
    update_indicators();    # update the status bar
    aspellstart();          # initialize the guess function
    spellguesses($term);    # get the guesses for the misspelling
    spellshow_guesses();    # populate the listbox with guesses

    if ( scalar( $lglobal{seen} ) ) {
        $lglobal{misspelledlabel}->configure( -text =>
                "Not in Dictionary:  -  $lglobal{seen}->{$term} in text." );
    }
    $lglobal{nextmiss} = 0;
}

sub getprojectdic {
    $lglobal{projectdictname} = $lglobal{global_filename};
    $lglobal{projectdictname} =~ s/\.[^\.]*?$/\.dic/;
    if ( $lglobal{projectdictname} eq $lglobal{global_filename} ) {
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
            if ( $lglobal{nextmiss}
            >= ( scalar( @{ $lglobal{misspelledlist} } ) ) );
    }
    $lglobal{suggestionlabel}->configure( -text => 'Suggestions:' );
    return
        if $lglobal{nextmiss} >= ( scalar( @{ $lglobal{misspelledlist} } ) )
    ;        # no more mispelled words, bail
    $lglobal{lastmatchindex} = $textwindow->index('spellindex');

#print $lglobal{misspelledlist}[$lglobal{nextmiss}]." | $lglobal{lastmatchindex}\n";
    if ( ( $lglobal{misspelledlist}[ $lglobal{nextmiss} ] =~ /^[\xC0-\xFF]/ )
        || ($lglobal{misspelledlist}[ $lglobal{nextmiss} ] =~ /[\xC0-\xFF]$/ )
        )
    {        # crappy workaround for accented character bug
        $lglobal{matchindex} = (
            $textwindow->search(
                -forwards,
                -count => \$lglobal{matchlength},
                $lglobal{misspelledlist}[ $lglobal{nextmiss} ],
                $lglobal{lastmatchindex}, 'end'
            )
        );
    }
    else {
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
    $lglobal{lastmatchindex}
        = spelladjust_index( $lglobal{matchindex},
        $lglobal{misspelledlist}[ $lglobal{nextmiss} ] )
        if $lglobal{matchindex};    #get the index of the end of the match
    spellguesses( $lglobal{misspelledlist}[ $lglobal{nextmiss} ] )
        ;    # get a list of guesses for the misspelling
    spellshow_guesses();    # and put them in the guess list
    update_indicators();    # update the status bar
    $lglobal{spellpopup}->configure( -title => 'Current Dictionary - '
            . ( $globalspelldictopt || '<default>' )
            . " | $#{$lglobal{misspelledlist}} words to check." );

    if ( scalar( $lglobal{seen} ) ) {
        $lglobal{misspelledlabel}->configure(
            -text => 'Not in Dictionary:  -  '
                . (
                $lglobal{seen}
                    ->{ $lglobal{misspelledlist}[ $lglobal{nextmiss} ] }
                    || '0'
                )
                . ' in text.'
        );
    }
    return 1;
}

sub spellgettextselection {
    return $textwindow->get( $lglobal{matchindex},
        "$lglobal{matchindex}+$lglobal{matchlength}c" );    # get the
                                                            # misspelled word
                                                            # as it appears in
                                                            # the text (may be
                                                            # checking case
                                                            # insensitive)
}

sub spellreplace {
    viewpagenums() if ( $lglobal{seepagenums} );
    my $replacement = $lglobal{spreplaceentry}
        ->get;    # get the word for the replacement box
    $textwindow->bell unless ( $replacement || $nobell );
    my $misspelled = $lglobal{misspelledentry}->get;
    return unless $replacement;
    $textwindow->replacewith( $lglobal{matchindex},
        "$lglobal{matchindex}+$lglobal{matchlength}c", $replacement );
    $lglobal{lastmatchindex}
        = spelladjust_index( ( $textwindow->index( $lglobal{matchindex} ) ),
        $replacement );    #adjust the index to the end of the replaced word
    print OUT '$$ra ' . "$misspelled, $replacement\n";
    shift @{ $lglobal{misspelledlist} };
    spellchecknext();      # and check the next word
}

# replace all instances of a word with another, pretty straightforward
sub spellreplaceall {
    $top->Busy;
    viewpagenums() if ( $lglobal{seepagenums} );
    my $lastindex   = '1.0';
    my $misspelled  = $lglobal{misspelledentry}->get;
    my $replacement = $lglobal{spreplaceentry}->get;
    my $repmatchindex;
    $textwindow->FindAndReplaceAll( '-exact', '-nocase', $misspelled,
        $replacement );
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
    open( DIC, ">$lglobal{projectdictname}" );
    print DIC "\%projectdict = (\n";
    for $term ( sort { $a cmp $b } keys %projectdict ) {
        $term =~ s/'/\\'/g;
        print DIC "'$term' => '',\n";
    }
    print DIC ");";
    close DIC;
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
    my @cmd = (    # FIXME: Need to see what options are going to aspell
        $lglobal{spellexename}, '-a', '-S', '--sug-mode', $globalaspellmode
    );
    push @cmd, '-d', $globalspelldictopt if $globalspelldictopt;
    $lglobal{spellpid} = open2( \*IN, \*OUT, @cmd );
    my $line = <IN>;
}

sub get_spellchecker_version {
    return $lglobal{spellversion} if $lglobal{spellversion};
    my $aspell_version;
    open my $aspell, '-|', "$lglobal{spellexename} help";
    while (<$aspell>) {
        $aspell_version = $1 if m/^Aspell ([\d\.]+)/;
    }
    close $aspell;
    return $lglobal{spellversion} = $aspell_version;
}

sub aspellstop {
    if ( $lglobal{spellpid} ) {
        close IN;
        close OUT;
        kill 9, $lglobal{spellpid}
            if OS_Win
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
    print OUT $word, "\n";    # send the word to the stdout file handle
    my $list = <IN>;          # and read the results
    $list =~ s/.*\: //
        ;    # remove incidental stuff (word, index, number of guesses)
    $list =~ s/\#.*0/\*none\*/;    # oops, no guesses, put a notice in.
    chomp $list;    # remove newline
    chop $list;     # and something else that listbox doesn't like
    @{ $lglobal{guesslist} }
        = ( split /, /, $list );    # split the words into an array
    $list = <IN>;                   # throw away extra newline
    $textwindow->Unbusy;            # done processing
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
        $lglobal{spellindexend}   = $ranges[0];
        $lglobal{spellindexstart} = $ranges[-1];
    }
    else {
        $lglobal{spellindexstart} = '1.0';
        $lglobal{spellindexend}   = $textwindow->index('end');
    }
}

sub spellget_misspellings {    # get list of misspelled words
    spellcheckrange();         # get chunck of text to process
    return if ( $lglobal{spellindexstart} eq $lglobal{spellindexend} );
    my ( $word, @templist );
    $top->Busy( -recurse => 1 );    # let user know something is going on
    my $section = $textwindow->get( $lglobal{spellindexstart},
        $lglobal{spellindexend} );    # get selection
    $section =~ s/^-----File:.*//g;
    open SAVE, '>:bytes', 'checkfil.txt';
    print SAVE $section;    # FIXME: probably encode before printing.
    close SAVE;
    my $spellopt
        = get_spellchecker_version() lt "0.6"
        ? "list --encoding=$lglobal{spellencoding} "
        : "list --encoding=$lglobal{spellencoding} ";
    $spellopt .= "-d $globalspelldictopt" if $globalspelldictopt;
    @templist = `$lglobal{spellexename} $spellopt < "checkfil.txt"`
        ;    # feed the text to aspell, get an array of misspelled words out
    chomp @templist;    # get rid of any newlines

    foreach $word (@templist) {
        next if ( exists( $projectdict{$word} ) );
        push @{ $lglobal{misspelledlist} },
            $word;      # filter out project dictionary word list.
    }
    if ( $#{ $lglobal{misspelledlist} } > 0 ) {
        $lglobal{spellpopup}->configure( -title => 'Current Dictionary - '
                . ( $globalspelldictopt || '<default>' )
                . " | $#{$lglobal{misspelledlist}} words to check." );
    }
    else {
        $lglobal{spellpopup}->configure( -title => 'Current Dictionary - '
                . ( $globalspelldictopt || '<default>' )
                . ' | No Misspelled Words Found.' );
    }
    $top->Unbusy( -recurse => 0 );    # done processing
    unlink 'checkfil.txt';
}

# remove ignored words from checklist
sub spellignoreall {
    my $next;
    my $word = $lglobal{misspelledentry}->get;   # get word you want to ignore
    $textwindow->bell unless ( $word || $nobell );
    return unless $word;
    my @ignorelist
        = @{ $lglobal{misspelledlist} };         # copy the mispellings array
    @{ $lglobal{misspelledlist} } = ();          # then clear it
    foreach $next (@ignorelist)
    {    # then put all of the words you are NOT ignoring back into the
            # mispellings list
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

## End Spellcheck

### File Menu
sub fileopen {    # Find a text file to open
    my ($name);
    return if ( confirmempty() =~ /cancel/i );
    my $types = [
        [ 'Text Files', [qw/.txt .text .ggp .htm .html .bk1 .bk2/] ],
        [ 'All Files',  ['*'] ],
    ];
    $name = $textwindow->getOpenFile(
        -filetypes  => $types,
        -title      => 'Open File',
        -initialdir => $globallastpath
    );
    if ( defined($name) and length($name) ) {
        openfile($name);
    }
}

sub openfile {    # and open it
    my $name = shift;
    return if ( $name eq '*empty*' );
    return if ( confirmempty() =~ /cancel/i );
    unless ( -e $name ) {
        my $dbox = $top->Dialog(
            -text    => 'Could not find file. Has it been moved or deleted?',
            -bitmap  => 'error',
            -title   => 'Could not find File.',
            -buttons => ['Ok']
        );
        $dbox->Show;
        return;
    }
    clearvars();
    if ( $lglobal{page_num_label} ) {
        $lglobal{page_num_label}->destroy;
        undef $lglobal{page_num_label};
    }
    if ( $lglobal{page_label} ) {
        $lglobal{page_label}->destroy;
        undef $lglobal{page_label};
    }
    if ( $lglobal{pagebutton} ) {
        $lglobal{pagebutton}->destroy;
        undef $lglobal{pagebutton};
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
    }
    recentupdate($name);
    update_indicators();
    markpages() if $auto_page_marks;
    push @operations, ( localtime() . " - Open $lglobal{global_filename}" );
    oppopupdate() if $lglobal{oppop};
    saveset();
    set_autosave() if $autosave;
}

sub savefile {    # Determine which save routine to use and then use it
    viewpagenums() if ( $lglobal{seepagenums} );
    if ( $lglobal{global_filename} =~ /No File Loaded/ ) {
        if ( $textwindow->numberChanges == 0 ) {
            return;
        }
        my ($name);
        $name = $textwindow->getSaveFile(
            -title      => 'Save As',
            -initialdir => $globallastpath
        );
        if ( defined($name) and length($name) ) {
            $textwindow->SaveUTF($name);
            $name = os_normal($name);
            recentupdate($name);
        }
        else {
            return;
        }
    }
    else {
        if ($autobackup) {
            if ( -e $lglobal{global_filename} ) {
                if ( -e "$lglobal{global_filename}.bk2" ) {
                    unlink "$lglobal{global_filename}.bk2";
                }
                if ( -e "$lglobal{global_filename}.bk1" ) {
                    rename(
                        "$lglobal{global_filename}.bk1",
                        "$lglobal{global_filename}.bk2"
                    );
                }
                rename(
                    $lglobal{global_filename},
                    "$lglobal{global_filename}.bk1"
                );
            }
        }
        $textwindow->SaveUTF;
    }
    $textwindow->ResetUndo;
    binsave();
    set_autosave() if $autosave;
    update_indicators();
}

sub file_savease { }
sub file_include { }
sub file_close   { }

sub prep_import {
    return if ( confirmempty() =~ /cancel/i );
    my $directory
        = $top->chooseDirectory( -title =>
            'Choose the directory containing the text files to be imported.',
        );
    return 0
        unless ( -d $directory and defined $directory and $directory ne '' );
    $top->Busy( -recurse => 1 );
    my $pwd = getcwd();
    chdir $directory;
    my @files = glob "*.txt";
    chdir $pwd;
    $directory .= '/';
    $directory      = os_normal($directory);
    $globallastpath = $directory;

    for my $file (@files) {
        if ( $file =~ /^(\d+)\.txt/ ) {
            $textwindow->ntinsert( 'end', ( "\n" . '-' x 6 ) );
            $textwindow->ntinsert( 'end', "File: $1.png" );
            $textwindow->ntinsert( 'end', ( '-' x 45 ) . "\n" );
            if ( open my $fh, '<', "$directory$file" ) {
                local $/ = undef;
                my $line = <$fh>;
                utf8::decode($line);
                $line =~ s/^\x{FEFF}?//;
                $line =~ s/\cM\cJ|\cM|\cJ/\n/g;

                #$line = eol_convert($line);
                $line =~ s/[\t \xA0]+$//smg;
                $textwindow->ntinsert( 'end', $line );
                close $file;
            }
            $top->update;
        }
    }
    $textwindow->markSet( 'insert', '1.0' );
    $lglobal{prepfile} = 1;
    markpages();
    $pngspath = '';
    $top->Unbusy( -recurse => 1 );
}

sub prep_export {
    my $directory = $top->chooseDirectory(
        -title => 'Choose the directory to export the text files to.', );
    return 0 unless ( defined $directory and $directory ne '' );
    unless ( -e $directory ) {
        mkdir $directory or warn "Could not make directory $!\n" and return;
    }
    $top->Busy( -recurse => 1 );
    my @marks = $textwindow->markNames;
    my @pages = sort grep ( /^Pg\S+$/, @marks );
    my $unicode
        = $textwindow->search( '-regexp', '--', '[\x{100}-\x{FFFE}]', '1.0',
        'end' );
    while (@pages) {
        my $page = shift @pages;
        my ($filename) = $page =~ /Pg(\S+)/;
        $filename .= '.txt';
        my $next;
        if (@pages) {
            $next = $pages[0];
        }
        else {
            $next = 'end';
        }
        my $file = $textwindow->get( $page, $next );
        $file =~ s/-{5,}File:.+?-{5}\n//;
        $file =~ s/\n+$//;
        open my $fh, '>', "$directory/$filename";
        if ($unicode) {
            $file = "\x{FEFF}" . $file;    # Add the BOM to beginning of file.
            utf8::encode($file);
        }
        print $fh $file;
    }
    $top->Unbusy( -recurse => 1 );
}

sub guesswindow {
    my ( $totpages, $line25, $linex );
    if ( $lglobal{pgpop} ) {
        $lglobal{pgpop}->deiconify;
    }
    else {
        $lglobal{pgpop} = $top->Toplevel;
        $lglobal{pgpop}->title('Guess Page Numbers');
        my $f0 = $lglobal{pgpop}->Frame->pack;
        $f0->Label( -text =>
                'This function should only be used if you have the page images but no page markers in the text.',
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        my $f1 = $lglobal{pgpop}->Frame->pack;
        $f1->Label( -text => 'How many pages are there total?', )
            ->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        my $tpages = $f1->Entry(
            -background => 'white',
            -width      => 8,
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
        $f1->Label( -text => 'What line # does page 25 start with?', )
            ->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
        my $page25 = $f1->Entry(
            -background => 'white',
            -width      => 8,
        )->grid( -row => 2, -column => 2, -padx => 1, -pady => 2 );
        my $f3 = $lglobal{pgpop}->Frame->pack;
        $f3->Label(
            -text => 'Select a page near the back, before the index starts.',
        )->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
        my $f4 = $lglobal{pgpop}->Frame->pack;
        $f4->Label( -text => 'Page #?.', )
            ->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        $f4->Label( -text => 'Line #?.', )
            ->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
        my $pagexe = $f4->Entry(
            -background => 'white',
            -width      => 8,
        )->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
        my $linexe = $f4->Entry(
            -background => 'white',
            -width      => 8,
        )->grid( -row => 2, -column => 2, -padx => 1, -pady => 2 );
        my $f2         = $lglobal{pgpop}->Frame->pack;
        my $calcbutton = $f2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                my ( $pnum, $lnum, $pagex, $linex, $number );
                $totpages = $tpages->get;
                $line25   = $page25->get;
                $pagex    = $pagexe->get;
                $linex    = $linexe->get;
                unless ( $totpages && $line25 && $line25 && $linex ) {
                    $top->messageBox(
                        -icon    => 'error',
                        -message => 'Need all values filled in.',
                        -title   => 'Missing values',
                        -type    => 'Ok',
                    );
                    return;
                }
                if ( $totpages <= $pagex ) {
                    $top->messageBox(
                        -icon => 'error',
                        -message =>
                            'Selected page must be lower than total pages',
                        -title => 'Bad value',
                        -type  => 'Ok',
                    );
                    return;
                }
                if ( $linex <= $line25 ) {
                    $top->messageBox(
                        -icon    => 'error',
                        -message => "Line number for selected page must be \n"
                            . "higher than that of page 25",
                        -title => 'Bad value',
                        -type  => 'Ok',
                    );
                    return;
                }
                my $end = $textwindow->index('end');
                $end = int( $end + .5 );
                my $average = ( int( $line25 + .5 ) / 25 );
                for $pnum ( 1 .. 24 ) {
                    $lnum = int( ( $pnum - 1 ) * $average ) + 1;
                    if ( $totpages > 999 ) {
                        $number = sprintf '%04s', $pnum;
                    }
                    else {
                        $number = sprintf '%03s', $pnum;
                    }
                    $textwindow->markSet( 'Pg' . $number, "$lnum.0" );
                    $textwindow->markGravity( "Pg$number", 'left' );
                }
                $average
                    = ( ( int( $linex + .5 ) ) - ( int( $line25 + .5 ) ) )
                    / ( $pagex - 25 );
                for $pnum ( 1 .. $pagex - 26 ) {
                    $lnum = int( ( $pnum - 1 ) * $average ) + 1 + $line25;
                    if ( $totpages > 999 ) {
                        $number = sprintf '%04s', $pnum + 25;
                    }
                    else {
                        $number = sprintf '%03s', $pnum + 25;
                    }
                    $textwindow->markSet( "Pg$number", "$lnum.0" );
                    $textwindow->markGravity( "Pg$number", 'left' );
                }
                $average
                    = ( $end - int( $linex + .5 ) ) / ( $totpages - $pagex );
                for $pnum ( 1 .. ( $totpages - $pagex ) ) {
                    $lnum = int( ( $pnum - 1 ) * $average ) + 1 + $linex;
                    if ( $totpages > 999 ) {
                        $number = sprintf '%04s', $pnum + $pagex;
                    }
                    else {
                        $number = sprintf '%03s', $pnum + $pagex;
                    }
                    $textwindow->markSet( "Pg$number", "$lnum.0" );
                    $textwindow->markGravity( "Pg$number", 'left' );
                }
                $lglobal{pgpop}->destroy;
                undef $lglobal{pgpop};
            },
            -text  => 'Guess Page #s',
            -width => 18
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        $lglobal{pgpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{pgpop}->destroy; undef $lglobal{pgpop} } );
        $lglobal{pgpop}->Icon( -image => $icon );
    }
}

#  Convert DP page separators to internal mark
sub markpages {
    $top->Busy( -recurse => 1 );
    viewpagenums() if ( $lglobal{seepagenums} );
    my ( $line, $index, $page, $rnd1, $rnd2, $pagemark );
    $searchstartindex = '1.0';
    $searchendindex   = '1.0';
    while ($searchstartindex) {
        $searchstartindex
            = $textwindow->search( '-nocase', '-regexp', '--',
            '-*\s?File:\s?(\S+)\.(png|jpg)---.*$',
            $searchendindex, 'end' );
        last unless $searchstartindex;
        $searchendindex = $textwindow->index("$searchstartindex lineend");
        $line = $textwindow->get( $searchstartindex, $searchendindex );

        # get the page name - we do this separate from pulling the
        # proofer names in case we did an Import Test Prep Files
        # which does not include proofer names
        #  look for one or more dashes followed by File: followed
        #  by zero or more spaces, then non-greedily capture everything
        #  up to the first period
        if ( $line =~ /-+File:\s*(.*?)\./ ) {
            $page = $1;
        }

        # get list of proofers:
        #  look for one or more dashes followed by File:, then
        #  non-greedily ignore everything up to the
        #  string of dashes, ignore the dashes, then capture
        #  everything until the dashes begin again (proofer string)
        if ( $line =~ /-+File:.*?-+([^-]+)-+/ ) {

            # split the proofer string into parts
            @{ $proofers{$page} } = split( "\Q\\\E", $1 );
        }

        $pagemark = 'Pg' . $page;
        $pagenumbers{$pagemark}{offset} = 1;
        $textwindow->markSet( $pagemark, $searchstartindex );
        $textwindow->markGravity( $pagemark, 'left' );
    }
    delete $proofers{''};
    $top->Unbusy( -recurse => 1 );
}

### Edit Menu
sub cut {
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    return unless $range_total;
    if ( $range_total == 2 ) {
        $textwindow->clipboardCut;
    }
    else {
        $textwindow->addGlobStart;
        $textwindow->clipboardColumnCut;
        $textwindow->addGlobEnd;
    }
}

sub copy {
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    return unless $range_total;
    $textwindow->clipboardClear;
    if ( $range_total == 2 ) {
        $textwindow->clipboardCopy;
    }
    else {
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
    }
    else {
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

    if ( defined( $lglobal{search} ) ) {
        $lglobal{search}->deiconify;
        $lglobal{search}->raise;
        $lglobal{search}->focus;
        $lglobal{searchentry}->focus;
    }
    else {
        $lglobal{search} = $top->Toplevel;
        $lglobal{search}->title('Search & Replace');
        $lglobal{search}->minsize( 460, 127 );
        my $sf1
            = $lglobal{search}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $searchlabel = $sf1->Label( -text => 'Search Text', )
            ->pack( -side => 'left', -anchor => 'n', -padx => 80 );
        $lglobal{searchnumlabel} = $sf1->Label(
            -text  => '',
            -width => 20,
        )->pack( -side => 'right', -anchor => 'e', -padx => 1 );
        my $sf11 = $lglobal{search}->Frame->pack(
            -side   => 'top',
            -anchor => 'w',
            -padx   => 3,
            -expand => 'y',
            -fill   => 'x'
        );

        $sf11->Button(
            -activebackground => $activecolor,
            -command          => sub {
                $textwindow->undo;
                $textwindow->tagRemove( 'highlight', '1.0', 'end' );
            },
            -text  => 'Undo',
            -width => 6
        )->pack( -side => 'right', -anchor => 'w' );
        $lglobal{searchbutton} = $sf11->Button(
            -activebackground => $activecolor,
            -command          => sub {
                add_search_history( $lglobal{searchentry}, \@search_history );
                searchtext('');
            },
            -text  => 'Search',
            -width => 6
            )->pack(
            -side   => 'right',
            -pady   => 1,
            -padx   => 2,
            -anchor => 'w'
            );

        $lglobal{searchentry} = $sf11->Text(
            -background => 'white',
            -width      => 60,
            -height     => 1,
            )->pack(
            -side   => 'right',
            -anchor => 'w',
            -expand => 'y',
            -fill   => 'x'
            );

        $sf11->Button(
            -activebackground => $activecolor,
            -command          => sub {
                search_history( $lglobal{searchentry}, \@search_history );
            },
            -image  => $lglobal{hist_img},
            -width  => 9,
            -height => 15,
        )->pack( -side => 'right', -anchor => 'w' );

        $lglobal{regrepeat}
            = $lglobal{searchentry}->repeat( 500, \&reg_check );

        my $sf2
            = $lglobal{search}->Frame->pack( -side => 'top', -anchor => 'w' );
        $lglobal{searchop1} = $sf2->Checkbutton(
            -variable    => \$sopt[1],
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Case Insensitive'
        )->pack( -side => 'left', -anchor => 'n', -pady => 1 );
        $lglobal{searchop0} = $sf2->Checkbutton(
            -variable    => \$sopt[0],
            -command     => [ \&searchoptset, 'x', 'x', 'x', 0 ],
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Whole Word'
        )->pack( -side => 'left', -anchor => 'n', -pady => 1 );
        $lglobal{searchop3} = $sf2->Checkbutton(
            -variable    => \$sopt[3],
            -command     => [ \&searchoptset, 0, 'x', 'x', 'x' ],
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Regex'
        )->pack( -side => 'left', -anchor => 'n', -pady => 1 );
        $lglobal{searchop2} = $sf2->Checkbutton(
            -variable    => \$sopt[2],
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Reverse'
        )->pack( -side => 'left', -anchor => 'n', -pady => 1 );
        $lglobal{searchop4} = $sf2->Checkbutton(
            -variable    => \$sopt[4],
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Start at Beginning'
        )->pack( -side => 'left', -anchor => 'n', -pady => 1 );

        my ( $sf13, $sf14, $sf5 );
        my $sf10 = $lglobal{search}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -expand => '1',
            -fill   => 'x'
        );
        my $replacelabel = $sf10->Label( -text => "Replacement Text\t\t", )
            ->grid( -row => 1, -column => 1 );

        $sf10->Label( -text => 'Terms - ' )->grid( -row => 1, -column => 2 );
        $sf10->Radiobutton(
            -text     => 'single',
            -variable => \$singleterm,
            -value    => 1,
            -command  => sub {
                for ( $sf13, $sf14 ) {
                    $_->packForget;
                }
            },
        )->grid( -row => 1, -column => 3 );
        $sf10->Radiobutton(
            -text     => 'multi',
            -variable => \$singleterm,
            -value    => 0,
            -command  => sub {
                for ( $sf13, $sf14 ) {
                    if ( defined $sf5 ) {
                        $_->pack(
                            -before => $sf5,
                            -side   => 'top',
                            -anchor => 'w',
                            -padx   => 3,
                            -expand => 'y',
                            -fill   => 'x'
                        );
                    }
                    else {
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
        my $sf12 = $lglobal{search}->Frame->pack(
            -side   => 'top',
            -anchor => 'w',
            -padx   => 3,
            -expand => 'y',
            -fill   => 'x'
        );

        $sf12->Button(
            -activebackground => $activecolor,
            -command          => sub {
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
            -activebackground => $activecolor,
            -command          => sub {
                replace( $lglobal{replaceentry}->get( '1.0', '1.end' ) );
                add_search_history( $lglobal{searchentry}, \@search_history );
                searchtext('');
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
            -activebackground => $activecolor,
            -command          => sub {
                replace( $lglobal{replaceentry}->get( '1.0', '1.end' ) );
                add_search_history( $lglobal{replaceentry},
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

        $lglobal{replaceentry} = $sf12->Text(
            -background => 'white',
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
            -activebackground => $activecolor,
            -command          => sub {
                search_history( $lglobal{replaceentry}, \@replace_history );
            },
            -image  => $lglobal{hist_img},
            -width  => 9,
            -height => 15,
        )->pack( -side => 'right', -anchor => 'w' );
        $sf13 = $lglobal{search}->Frame;

        $sf13->Button(
            -activebackground => $activecolor,
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
            -activebackground => $activecolor,
            -command          => sub {
                replace( $lglobal{replaceentry1}->get( '1.0', '1.end' ) );
                searchtext('');
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
            -activebackground => $activecolor,
            -command          => sub {
                replace( $lglobal{replaceentry1}->get( '1.0', '1.end' ) );
                add_search_history( $lglobal{replaceentry1},
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

        $lglobal{replaceentry1} = $sf13->Text(
            -background => 'white',
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
            -activebackground => $activecolor,
            -command          => sub {
                search_history( $lglobal{replaceentry1}, \@replace_history );
            },
            -image  => $lglobal{hist_img},
            -width  => 9,
            -height => 15,
        )->pack( -side => 'right', -anchor => 'w' );
        $sf14 = $lglobal{search}->Frame;

        $sf14->Button(
            -activebackground => $activecolor,
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
            -activebackground => $activecolor,
            -command          => sub {
                replace( $lglobal{replaceentry2}->get( '1.0', '1.end' ) );
                searchtext('');
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
            -activebackground => $activecolor,
            -command          => sub {
                replace( $lglobal{replaceentry2}->get( '1.0', '1.end' ) );
                add_search_history( $lglobal{replaceentry2},
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

        $lglobal{replaceentry2} = $sf14->Text(
            -background => 'white',
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
            -activebackground => $activecolor,
            -command          => sub {
                search_history( $lglobal{replaceentry2}, \@replace_history );
            },
            -image  => $lglobal{hist_img},
            -width  => 9,
            -height => 15,
        )->pack( -side => 'right', -anchor => 'w' );

        unless ($singleterm) {
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
            $sf5 = $lglobal{search}
                ->Frame->pack( -side => 'top', -anchor => 'n' );
            my $nextbutton = $sf5->Button(
                -activebackground => $activecolor,
                -command          => sub {
                    $lglobal{scannosindex}++
                        unless ( $lglobal{scannosindex}
                        >= scalar( @{ $lglobal{scannosarray} } ) );
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
            my $lastbutton = $sf5->Button(
                -activebackground => $activecolor,
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
            my $switchbutton = $sf5->Button(
                -activebackground => $activecolor,
                -command          => sub { swapterms() },
                -text             => 'Swap Terms',
                -width            => 15
                )->pack(
                -side   => 'left',
                -pady   => 5,
                -padx   => 2,
                -anchor => 'w'
                );
            my $hintbutton = $sf5->Button(
                -activebackground => $activecolor,
                -command          => sub { reghint() },
                -text             => 'Hint',
                -width            => 5
                )->pack(
                -side   => 'left',
                -pady   => 5,
                -padx   => 2,
                -anchor => 'w'
                );
            my $editbutton = $sf5->Button(
                -activebackground => $activecolor,
                -command          => sub { regedit() },
                -text             => 'Edit',
                -width            => 5
                )->pack(
                -side   => 'left',
                -pady   => 5,
                -padx   => 2,
                -anchor => 'w'
                );
            my $sf6 = $lglobal{search}
                ->Frame->pack( -side => 'top', -anchor => 'n' );
            $lglobal{regtracker} = $sf6->Label( -width => 15 )->pack(
                -side   => 'left',
                -pady   => 5,
                -padx   => 2,
                -anchor => 'w'
            );
            $aacheck = $sf6->Checkbutton(
                -text     => 'Auto Advance',
                -variable => \$lglobal{regaa},
                )->pack(
                -side   => 'left',
                -pady   => 5,
                -padx   => 2,
                -anchor => 'w'
                );
        }
        $lglobal{search}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{regrepeat}->cancel;
                undef $lglobal{regrepeat};
                $lglobal{search}->destroy;
                undef $lglobal{search};
                $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                undef $lglobal{hintpop} if $lglobal{hintpop};
            }
        );
        $lglobal{search}->Icon( -image => $icon );
        $lglobal{searchentry}->focus;
        $lglobal{search}->resizable( 'yes', 'no' );
        $lglobal{search}->transient($top) if $stayontop;
        $lglobal{search}->Tk::bind(
            '<Return>' => sub {
                $lglobal{searchentry}->see('1.0');
                $lglobal{searchentry}->delete('1.end');
                $lglobal{searchentry}->delete( '2.0', 'end' );
                $lglobal{replaceentry}->see('1.0');
                $lglobal{replaceentry}->delete('1.end');
                $lglobal{replaceentry}->delete( '2.0', 'end' );
                searchtext();
                $top->raise;
            }
        );
        $lglobal{search}->Tk::bind(
            '<Control-f>' => sub {
                $lglobal{searchentry}->see('1.0');
                $lglobal{searchentry}->delete( '2.0', 'end' );
                $lglobal{replaceentry}->see('1.0');
                $lglobal{replaceentry}->delete( '2.0', 'end' );
                searchtext();
                $top->raise;
            }
        );
        $lglobal{search}->Tk::bind(
            '<Control-F>' => sub {
                $lglobal{searchentry}->see('1.0');
                $lglobal{searchentry}->delete( '2.0', 'end' );
                $lglobal{replaceentry}->see('1.0');
                $lglobal{replaceentry}->delete( '2.0', 'end' );
                searchtext();
                $top->raise;
            }
        );
        $lglobal{search}->eventAdd(
            '<<FindNexte>>' => '<Control-Key-G>',
            '<Control-Key-g>'
        );

        $lglobal{searchentry}->bind(
            '<<FindNexte>>',
            sub {
                $lglobal{searchentry}->delete('insert -1c')
                    if ( $lglobal{searchentry}->get('insert -1c') eq "\cG" );
                searchtext( $lglobal{searchentry}->get( '1.0', '1.end' ) );
                $textwindow->focus;
            }
        );

        $lglobal{searchentry}->{_MENU_}   = ();
        $lglobal{replaceentry}->{_MENU_}  = ();
        $lglobal{replaceentry1}->{_MENU_} = ();
        $lglobal{replaceentry2}->{_MENU_} = ();

        $lglobal{searchentry}->bind( '<FocusIn>',
            sub { $lglobal{hasfocus} = $lglobal{searchentry} } );
        $lglobal{replaceentry}->bind( '<FocusIn>',
            sub { $lglobal{hasfocus} = $lglobal{replaceentry} } );
        $lglobal{replaceentry1}->bind( '<FocusIn>',
            sub { $lglobal{hasfocus} = $lglobal{replaceentry1} } );
        $lglobal{replaceentry2}->bind( '<FocusIn>',
            sub { $lglobal{hasfocus} = $lglobal{replaceentry2} } );

        $lglobal{search}->Tk::bind(
            '<Control-Return>' => sub {
                $lglobal{searchentry}->see('1.0');
                $lglobal{searchentry}->delete('1.end');
                $lglobal{searchentry}->delete( '2.0', 'end' );
                $lglobal{replaceentry}->see('1.0');
                $lglobal{replaceentry}->delete('1.end');
                $lglobal{replaceentry}->delete( '2.0', 'end' );
                replace( $lglobal{replaceentry}->get( '1.0', '1.end' ) );
                searchtext();
                $top->raise;
            }
        );
        $lglobal{search}->Tk::bind(
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
        $lglobal{search}->Tk::bind(
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
        searchtext('');
    }
}

sub stealthscanno {
    $lglobal{doscannos} = 1;
    $lglobal{search}->destroy if defined $lglobal{search};
    undef $lglobal{search};
    if ( loadscannos() ) {
        saveset();
        searchpopup();
        getnextscanno();
        searchtext();
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
            unless $globalspellpath; # Whoops, don't know where to find Aspell
        spellclearvars();
        spellcheckfirst();           # Start checking the spelling
    }
    else {                           # window doesn't exist so set it up
        $lglobal{spellpopup} = $top->Toplevel;
        $lglobal{spellpopup}
            ->title( 'Current Dictionary - ' . $globalspelldictopt
                || '<default>' );
        my $spf1 = $lglobal{spellpopup}
            ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        $lglobal{misspelledlabel}
            = $spf1->Label( -text => 'Not in Dictionary:', )
            ->pack( -side => 'top', -anchor => 'n', -pady => 5 );
        $lglobal{misspelledentry} = $spf1->Entry(
            -background => 'white',
            -width      => 42,
            -font       => $lglobal{font},
        )->pack( -side => 'top', -anchor => 'n', -pady => 1 );
        my $replacelabel = $spf1->Label( -text => 'Replacement Text:', )
            ->pack( -side => 'top', -anchor => 'n', -padx => 6 );
        $lglobal{spreplaceentry} = $spf1->Entry(
            -background => 'white',
            -width      => 42,
            -font       => $lglobal{font},
        )->pack( -side => 'top', -anchor => 'n', -padx => 1 );
        $lglobal{suggestionlabel} = $spf1->Label( -text => 'Suggestions:', )
            ->pack( -side => 'top', -anchor => 'n', -pady => 5 );
        $lglobal{replacementlist} = $spf1->ScrlListbox(
            -background => 'white',
            -scrollbars => 'osoe',
            -font       => $lglobal{font},
            -width      => 40,
        )->pack( -side => 'top', -anchor => 'n', -padx => 6, -pady => 6 );
        my $spf2 = $lglobal{spellpopup}
            ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        my $changebutton = $spf2->Button(
            -activebackground => $activecolor,
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
            -activebackground => $activecolor,
            -command =>
                sub { shift @{ $lglobal{misspelledlist} }; spellchecknext() },
            -text  => 'Skip <Ctrl+s>',
            -width => 14
            )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
            );
        my $spelloptionsbutton = $spf2->Button(
            -activebackground => $activecolor,
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
            -activebackground => $activecolor,
            -command          => sub {
                $spellindexbkmrk
                    = $textwindow->index( $lglobal{lastmatchindex} . '-1c' )
                    || '1.0';
                $textwindow->markSet( 'spellbkmk', $spellindexbkmrk );
                saveset();
            },
            -text  => 'Set Bookmark',
            -width => 14,
            )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
            );
        my $spf3 = $lglobal{spellpopup}
            ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        my $replaceallbutton = $spf3->Button(
            -activebackground => $activecolor,
            -command          => sub { spellreplaceall(); spellchecknext() },
            -text             => 'Change All',
            -width            => 14,
            )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
            );
        my $ignoreallbutton = $spf3->Button(
            -activebackground => $activecolor,
            -command          => sub { spellignoreall(); spellchecknext() },
            -text             => 'Skip All <Ctrl+i>',
            -width            => 14
            )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
            );
        my $closebutton = $spf3->Button(
            -activebackground => $activecolor,
            -command          => sub {
                @{ $lglobal{misspelledlist} } = ();
                $lglobal{spellpopup}->destroy;
                undef
                    $lglobal{spellpopup}; # completly remove spellcheck window
                print OUT "\cC\n"
                    if $lglobal{spellpid};    # send a quit signal to aspell
                aspellstop();                 # and remove the process
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
            -activebackground => $activecolor,
            -command          => sub {
                return unless $spellindexbkmrk;
                $textwindow->tagRemove( 'sel',       '1.0', 'end' );
                $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                $textwindow->tagAdd( 'sel', 'spellbkmk', 'end' );
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
        my $spf4 = $lglobal{spellpopup}
            ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        my $dictaddbutton = $spf4->Button(
            -activebackground => $activecolor,
            -command =>
                sub { spelladdword(); spellignoreall(); spellchecknext() },
            -text  => 'Add To Aspell Dic. <Ctrl+a>',
            -width => 22,
            )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
            );
        my $dictmyaddbutton = $spf4->Button(
            -activebackground => $activecolor,
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
                undef
                    $lglobal{spellpopup}; # completly remove spellcheck window
                print OUT "\cC\n"
                    if $lglobal{spellpid};    # send quit signal to aspell
                aspellstop();                 # and remove the process
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
        $lglobal{spellpopup}->bind( '<Return>',
            sub { $lglobal{spellpopup}->focus; spellreplace() } );
        $lglobal{spellpopup}->Icon( -image => $icon );
        $lglobal{spellpopup}->transient($top) if $stayontop;
        $lglobal{replacementlist}
            ->bind( '<Double-Button-1>', \&spellmisspelled_replace );
        $lglobal{replacementlist}->bind( '<Triple-Button-1>',
            sub { spellmisspelled_replace(); spellreplace() } );
        BindMouseWheel( $lglobal{replacementlist} );
        spelloptions()
            unless $globalspellpath; # Check to see if we know where Aspell is
        spellcheckfirst();           # Start the spellcheck
    }
}

# Pop up a window which will allow jumping directly to a specified line
sub gotoline {
    unless ( defined( $lglobal{gotolinepop} ) ) {
        $lglobal{gotolinepop} = $top->DialogBox(
            -buttons => [qw[Ok Cancel]],
            -title   => 'Goto Line Number',
            -popover => $top,
            -command => sub {

                no warnings 'uninitialized';
                if ( $_[0] eq 'Ok' ) {
                    $lglobal{line_number} =~ s/[\D.]//g;
                    my ( $last_line, $junk )
                        = split( /\./, $textwindow->index('end') );
                    ( $lglobal{line_number}, $junk )
                        = split( /\./, $textwindow->index('insert') )
                        unless $lglobal{line_number};
                    $lglobal{line_number} =~ s/^\s+|\s+$//g;
                    if ( $lglobal{line_number} > $last_line ) {
                        $lglobal{line_number} = $last_line;
                    }
                    $textwindow->markSet( 'insert',
                        "$lglobal{line_number}.0" );
                    $textwindow->see('insert');
                    update_indicators();
                    $lglobal{gotolinepop}->destroy;
                    undef $lglobal{gotolinepop};
                }
                else {
                    $lglobal{gotolinepop}->destroy;
                    undef $lglobal{gotolinepop};
                }
            }
        );
        $lglobal{gotolinepop}->resizable( 'no', 'no' );
        my $frame = $lglobal{gotolinepop}->Frame->pack( -fill => 'x' );
        $frame->Label( -text => 'Enter Line number: ' )
            ->pack( -side => 'left' );
        my $entry = $frame->Entry(
            -background   => 'white',
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
                        $lglobal{lastpage}
                            = sprintf( "%03s", $lglobal{lastpage} );
                    }
                    elsif ( $lglobal{pagedigits} == 4 ) {
                        $lglobal{lastpage}
                            = sprintf( "%04s", $lglobal{lastpage} );
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
                    my $index
                        = $textwindow->index( 'Pg' . $lglobal{lastpage} );
                    $textwindow->markSet( 'insert', "$index +1l linestart" );
                    $textwindow->see('insert');
                    $textwindow->focus;
                    update_indicators();
                    $lglobal{gotopagpop}->destroy;
                    undef $lglobal{gotopagpop};
                }
                else {
                    $lglobal{gotopagpop}->destroy;
                    undef $lglobal{gotopagpop};
                }
            }
        );
        $lglobal{gotopagpop}->resizable( 'no', 'no' );
        my $frame = $lglobal{gotopagpop}->Frame->pack( -fill => 'x' );
        $frame->Label( -text => 'Enter image number: ' )
            ->pack( -side => 'left' );
        my $entry = $frame->Entry(
            -background   => 'white',
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
    my $pattern = "[**";
    my $comment = $textwindow->search( $pattern, "insert" );
    my $index   = $textwindow->index("$comment +1c");
    $textwindow->SetCursor($index);
}

sub nextblock {
    my ( $mark, $direction ) = @_;
    unless ($searchstartindex) { $searchstartindex = '1.0' }
    if ( $mark eq 'default' ) {
        if ( $direction eq 'forward' ) {
            $searchstartindex
                = $textwindow->search( '-exact', '--', '/*',
                $searchstartindex, 'end' )
                if $searchstartindex;
        }
        elsif ( $direction eq 'reverse' ) {
            $searchstartindex
                = $textwindow->search( '-backwards', '-exact', '--', '/*',
                $searchstartindex, '1.0' )
                if $searchstartindex;
        }
    }
    elsif ( $mark eq 'indent' ) {
        if ( $direction eq 'forward' ) {
            $searchstartindex
                = $textwindow->search( '-regexp', '--', '^\S',
                $searchstartindex, 'end' )
                if $searchstartindex;
            $searchstartindex
                = $textwindow->search( '-regexp', '--', '^\s',
                $searchstartindex, 'end' )
                if $searchstartindex;
        }
        elsif ( $direction eq 'reverse' ) {
            $searchstartindex
                = $textwindow->search( '-backwards', '-regexp', '--', '^\S',
                $searchstartindex, '1.0' )
                if $searchstartindex;
            $searchstartindex
                = $textwindow->search( '-backwards', '-regexp', '--', '^\s',
                $searchstartindex, '1.0' )
                if $searchstartindex;
        }
    }
    elsif ( $mark eq 'stet' ) {
        if ( $direction eq 'forward' ) {
            $searchstartindex
                = $textwindow->search( '-exact', '--', '/$',
                $searchstartindex, 'end' )
                if $searchstartindex;
        }
        elsif ( $direction eq 'reverse' ) {
            $searchstartindex
                = $textwindow->search( '-backwards', '-exact', '--', '/$',
                $searchstartindex, '1.0' )
                if $searchstartindex;
        }
    }
    elsif ( $mark eq 'block' ) {
        if ( $direction eq 'forward' ) {
            $searchstartindex
                = $textwindow->search( '-exact', '--', '/#',
                $searchstartindex, 'end' )
                if $searchstartindex;
        }
        elsif ( $direction eq 'reverse' ) {
            $searchstartindex
                = $textwindow->search( '-backwards', '-exact', '--', '/#',
                $searchstartindex, '1.0' )
                if $searchstartindex;
        }
    }
    elsif ( $mark eq 'poetry' ) {
        if ( $direction eq 'forward' ) {
            $searchstartindex
                = $textwindow->search( '-regexp', '--', '\/[pP]',
                $searchstartindex, 'end' )
                if $searchstartindex;
        }
        elsif ( $direction eq 'reverse' ) {
            $searchstartindex
                = $textwindow->search( '-backwards', '-regexp', '--',
                '\/[pP]', $searchstartindex, '1.0' )
                if $searchstartindex;
        }
    }
    $textwindow->markSet( 'insert', $searchstartindex ) if $searchstartindex;
    $textwindow->see($searchstartindex) if $searchstartindex;
    $textwindow->update;
    $textwindow->focus;
    if ( $direction eq 'forward' ) {
        $searchstartindex += 1;
    }
    elsif ( $direction eq 'reverse' ) {
        $searchstartindex -= 1;
    }
    if ( $searchstartindex = int($searchstartindex) ) {
        $searchstartindex .= '.0';
    }
    update_indicators();
}

sub brackets {
    my $psel;
    if ( defined( $lglobal{brkpop} ) ) {
        $lglobal{brkpop}->deiconify;
        $lglobal{brkpop}->raise;
        $lglobal{brkpop}->focus;
    }
    else {
        $lglobal{brkpop} = $top->Toplevel;
        $lglobal{brkpop}->title('Find orphan brackets');
        $lglobal{brkpop}->Label( -text => 'Bracket or Markup Style' )->pack;
        my $frame = $lglobal{brkpop}->Frame->pack;
        $psel = $frame->Radiobutton(
            -variable    => \$lglobal{brsel},
            -selectcolor => $lglobal{checkcolor},
            -value       => '[\(\)]',
            -text        => '(  )',
        )->grid( -row => 1, -column => 1 );
        my $ssel = $frame->Radiobutton(
            -variable    => \$lglobal{brsel},
            -selectcolor => $lglobal{checkcolor},
            -value       => '[\[\]]',
            -text        => '[  ]',
        )->grid( -row => 1, -column => 2 );
        my $csel = $frame->Radiobutton(
            -variable    => \$lglobal{brsel},
            -selectcolor => $lglobal{checkcolor},
            -value       => '[\{\}]',
            -text        => '{  }',
        )->grid( -row => 1, -column => 3, -pady => 5 );
        my $asel = $frame->Radiobutton(
            -variable    => \$lglobal{brsel},
            -selectcolor => $lglobal{checkcolor},
            -value       => '[<>]',
            -text        => '<  >',
        )->grid( -row => 1, -column => 4, -pady => 5 );
        my $frame1 = $lglobal{brkpop}->Frame->pack;
        my $dsel   = $frame1->Radiobutton(
            -variable    => \$lglobal{brsel},
            -selectcolor => $lglobal{checkcolor},
            -value       => '\/\*|\*\/',
            -text        => '/* */',
        )->grid( -row => 1, -column => 1, -pady => 5 );
        my $nsel = $frame1->Radiobutton(
            -variable    => \$lglobal{brsel},
            -selectcolor => $lglobal{checkcolor},
            -value       => '\/#|#\/',
            -text        => '/# #/',
        )->grid( -row => 1, -column => 2, -pady => 5 );
        my $stsel = $frame1->Radiobutton(
            -variable    => \$lglobal{brsel},
            -selectcolor => $lglobal{checkcolor},
            -value       => '\/\$|\$\/',
            -text        => '/$ $/',
        )->grid( -row => 1, -column => 3, -pady => 5 );
        my $frame3 = $lglobal{brkpop}->Frame->pack;
        my $psel   = $frame3->Radiobutton(
            -variable    => \$lglobal{brsel},
            -selectcolor => $lglobal{checkcolor},
            -value       => '^\/[Pp]|[Pp]\/',
            -text        => '/p p/',
        )->grid( -row => 2, -column => 1, -pady => 5 );
        my $qusel = $frame3->Radiobutton(
            -variable    => \$lglobal{brsel},
            -selectcolor => $lglobal{checkcolor},
            -value       => '´|ª',
            -text        => 'Angle quotes ´ ª',
        )->grid( -row => 2, -column => 2, -pady => 5 );

        my $gqusel = $frame3->Radiobutton(
            -variable    => \$lglobal{brsel},
            -selectcolor => $lglobal{checkcolor},
            -value       => 'ª|´',
            -text        => 'German Angle quotes ª ´',
        )->grid( -row => 3, -column => 2 );

        my $frame2     = $lglobal{brkpop}->Frame->pack;
        my $brsearchbt = $frame2->Button(
            -activebackground => $activecolor,
            -text             => 'Search',
            -command          => \&brsearch,
            -width            => 10,
        )->grid( -row => 1, -column => 2, -pady => 5 );
        my $brnextbt = $frame2->Button(
            -activebackground => $activecolor,
            -text             => 'Next',
            -command          => sub {
                shift @{ $lglobal{brbrackets} } if @{ $lglobal{brbrackets} };
                shift @{ $lglobal{brindicies} } if @{ $lglobal{brindicies} };
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
    $lglobal{brkpop}->Icon( -image => $icon );
    $lglobal{brkpop}->transient($top) if $stayontop;
    $psel->select;

    sub brsearch {
        viewpagenums() if ( $lglobal{seepagenums} );
        @{ $lglobal{brbrackets} } = ();
        @{ $lglobal{brindicies} } = ();
        $lglobal{brindex} = '1.0';
        my $brcount = 0;
        my $brlength;
        while ( $lglobal{brindex} ) {
            $lglobal{brindex} = $textwindow->search(
                '-regexp',
                '-count' => \$brlength,
                '--', $lglobal{brsel}, $lglobal{brindex}, 'end'
            );
            last unless $lglobal{brindex};
            $lglobal{brbrackets}[$brcount]
                = $textwindow->get( $lglobal{brindex},
                $lglobal{brindex} . '+' . $brlength . 'c' );
            $lglobal{brindicies}[$brcount] = $lglobal{brindex};
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
                (      ( $lglobal{brbrackets}[0] =~ /[\[\(\{\<´]/ )
                    && ( $lglobal{brbrackets}[1] =~ /[\]\)\}\>ª]/ )
                )
                || (   ( $lglobal{brbrackets}[0] =~ /[\[\(\{\<ª]/ )
                    && ( $lglobal{brbrackets}[1] =~ /[\]\)\}\>´]/ ) )
                || (   ( $lglobal{brbrackets}[0] =~ /^\x7f*\/\*/ )
                    && ( $lglobal{brbrackets}[1] =~ /^\x7f*\*\// ) )
                || (   ( $lglobal{brbrackets}[0] =~ /^\x7f*\/\$/ )
                    && ( $lglobal{brbrackets}[1] =~ /^\x7f*\$\// ) )
                || (   ( $lglobal{brbrackets}[0] =~ /^\x7f*\/[Pp]/ )
                    && ( $lglobal{brbrackets}[1] =~ /^\x7f*[Pp]\// ) )
                || (   ( $lglobal{brbrackets}[0] =~ /^\x7f*\/\#/ )
                    && ( $lglobal{brbrackets}[1] =~ /^\x7f*\#\// ) )
                );
            shift @{ $lglobal{brbrackets} };
            shift @{ $lglobal{brbrackets} };
            shift @{ $lglobal{brindicies} };
            shift @{ $lglobal{brindicies} };
            $lglobal{brbrackets}[0] = $lglobal{brbrackets}[0] || '';
            $lglobal{brbrackets}[1] = $lglobal{brbrackets}[1] || '';
            last unless @{ $lglobal{brbrackets} };
        }
        if ( ( $lglobal{brbrackets}[2] ) && ( $lglobal{brbrackets}[3] ) ) {
            if (   ( $lglobal{brbrackets}[0] eq $lglobal{brbrackets}[1] )
                && ( $lglobal{brbrackets}[2] eq $lglobal{brbrackets}[3] ) )
            {
                shift @{ $lglobal{brbrackets} };
                shift @{ $lglobal{brbrackets} };
                shift @{ $lglobal{brindicies} };
                shift @{ $lglobal{brindicies} };
                shift @{ $lglobal{brbrackets} };
                shift @{ $lglobal{brbrackets} };
                shift @{ $lglobal{brindicies} };
                shift @{ $lglobal{brindicies} };
                brnext();
            }
        }
        if ( @{ $lglobal{brbrackets} } ) {
            $textwindow->markSet( 'insert', $lglobal{brindicies}[0] )
                if $lglobal{brindicies}[0];
            $textwindow->see( $lglobal{brindicies}[0] )
                if $lglobal{brindicies}[0];
            $textwindow->tagAdd( 'highlight', $lglobal{brindicies}[0],
                      $lglobal{brindicies}[0] . '+'
                    . ( length( $lglobal{brbrackets}[0] ) )
                    . 'c' )
                if $lglobal{brindicies}[0];
            $textwindow->tagAdd( 'highlight', $lglobal{brindicies}[1],
                      $lglobal{brindicies}[1] . '+'
                    . ( length( $lglobal{brbrackets}[1] ) )
                    . 'c' )
                if $lglobal{brindicies}[1];
            $textwindow->focus;
        }
    }
}

sub hilite {
    my $mark = shift;
    $mark = quotemeta($mark)
        if $lglobal{hilitemode} eq
            'exact';    # FIXME: uninitialized 'hilitemode'
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    my ( $index, $lastindex );
    if ( $range_total == 0 ) {
        return;
    }
    else {
        my $end            = pop(@ranges);
        my $start          = pop(@ranges);
        my $thisblockstart = $start;
        $lastindex = $start;
        my $thisblockend = $end;
        $textwindow->tagRemove( 'quotemark', '1.0', 'end' );
        my $length;
        while ($lastindex) {
            $index = $textwindow->search(
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

sub hilitepopup {
    viewpagenums() if ( $lglobal{seepagenums} );
    if ( defined( $lglobal{hilitepop} ) ) {
        $lglobal{hilitepop}->deiconify;
        $lglobal{hilitepop}->raise;
        $lglobal{hilitepop}->focus;
    }
    else {
        $lglobal{hilitepop} = $top->Toplevel;
        $lglobal{hilitepop}->title('Character Highlight');
        $lglobal{hilitemode} = 'exact';
        my $f = $lglobal{hilitepop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f->Label( -text => 'Highlight Character(s) or Regex', )
            ->pack( -side => 'top', -pady => 2, -padx => 2, -anchor => 'n' );
        my $entry = $f->Entry(
            -width      => 40,
            -background => 'white',
            -font       => $lglobal{font},
            -relief     => 'sunken',
            )->pack(
            -expand => 1,
            -fill   => 'x',
            -padx   => 3,
            -pady   => 3,
            -anchor => 'n'
            );
        my $f2 = $lglobal{hilitepop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
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
        my $f3 = $lglobal{hilitepop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f3->Button(
            -activebackground => $activecolor,
            -command          => sub {

                if ( $textwindow->markExists('selstart') ) {
                    $textwindow->tagAdd( 'sel', 'selstart', 'selend' );
                }
            },
            -text  => 'Previous Selection',
            -width => 16,
        )->grid( -row => 1, -column => 1, -padx => 2, -pady => 2 );

        $f3->Button(
            -activebackground => $activecolor,
            -command => sub { $textwindow->tagAdd( 'sel', '1.0', 'end' ) },
            -text    => 'Select Whole File',
            -width   => 16,
        )->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
        $f3->Button(
            -activebackground => $activecolor,
            -command          => sub { hilite( $entry->get ) },
            -text             => 'Apply Highlights',
            -width            => 16,
        )->grid( -row => 2, -column => 1, -padx => 2, -pady => 2 );
        $f3->Button(
            -activebackground => $activecolor,
            -command =>
                sub { $textwindow->tagRemove( 'quotemark', '1.0', 'end' ) },
            -text  => 'Remove Highlight',
            -width => 16,
        )->grid( -row => 2, -column => 2, -padx => 2, -pady => 2 );

        $lglobal{hilitepop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{hilitepop}->destroy;
                undef $lglobal{hilitepop};
            }
        );
        $lglobal{hilitepop}->Icon( -image => $icon );
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

sub case {
    saveset();
    my $marker      = shift;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    my $done        = '';
    if ( $range_total == 0 ) {
        return;
    }
    else {
        $textwindow->addGlobStart;
        while (@ranges) {
            my $end            = pop(@ranges);
            my $start          = pop(@ranges);
            my $thisblockstart = $start;
            my $thisblockend   = $end;
            my $selection
                = $textwindow->get( $thisblockstart, $thisblockend );
            my @words         = ();
            my $buildsentence = '';
            if ( $marker eq 'uc' ) {
                $done = uc($selection);
            }
            elsif ( $marker eq 'lc' ) {
                $done = lc($selection);
            }
            elsif ( $marker eq 'sc' ) {
                $done = lc($selection);
                $done =~ s/(^\W*\w)/\U$1\E/;
            }
            elsif ( $marker eq 'tc' ) {
                $done = lc($selection);
                $done =~ s/(^\W*\w)/\U$1\E/;
                $done =~ s/([\s\n]+\W*\w)/\U$1\E/g;
            }
            $textwindow->replacewith( $start, $end, $done );
        }
        $textwindow->addGlobEnd;
    }
}

sub surround {
    if ( defined( $lglobal{surpop} ) ) {
        $lglobal{surpop}->deiconify;
        $lglobal{surpop}->raise;
        $lglobal{surpop}->focus;
    }
    else {
        $lglobal{surpop} = $top->Toplevel;
        $lglobal{surpop}->title('Surround text with:');
        my $f
            = $lglobal{surpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f->Label( -text =>
                "Surround the selection with?\n\\n will be replaced with a newline.",
        )->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        my $f1
            = $lglobal{surpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $surstrt = $f1->Entry(
            -width      => 8,
            -background => 'white',
            -font       => $lglobal{font},
            -relief     => 'sunken',
            )
            ->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'n' );
        my $surend = $f1->Entry(
            -width      => 8,
            -background => 'white',
            -font       => $lglobal{font},
            -relief     => 'sunken',
            )
            ->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'n' );
        my $f2
            = $lglobal{surpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $gobut = $f2->Button(
            -activebackground => $activecolor,
            -command => sub { surroundit( $surstrt->get, $surend->get ) },
            -text    => 'OK',
            -width   => 16
        )->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        $lglobal{surpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{surpop}->destroy; undef $lglobal{surpop} } );
        $surstrt->insert( 'end', '_' ) unless ( $surstrt->get );
        $surend->insert( 'end', '_' ) unless ( $surend->get );
        $lglobal{surpop}->Icon( -image => $icon );
    }
}

sub flood {
    if ( defined( $lglobal{floodpop} ) ) {
        $lglobal{floodpop}->deiconify;
        $lglobal{floodpop}->raise;
        $lglobal{floodpop}->focus;
    }
    else {
        $lglobal{floodpop} = $top->Toplevel;
        $lglobal{floodpop}->title('Flood Fill String:');
        my $f = $lglobal{floodpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f->Label( -text =>
                "Flood fill string.\n(Blank will default to spaces.)\nHotkey Control+w",
        )->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        my $f1 = $lglobal{floodpop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -expand => 'y',
            -fill   => 'x'
        );
        my $floodch = $f1->Entry(
            -background   => 'white',
            -font         => $lglobal{font},
            -relief       => 'sunken',
            -textvariable => \$lglobal{ffchar},
            )->pack(
            -side   => 'left',
            -pady   => 5,
            -padx   => 2,
            -anchor => 'w',
            -expand => 'y',
            -fill   => 'x'
            );
        my $f2 = $lglobal{floodpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        my $gobut = $f2->Button(
            -activebackground => $activecolor,
            -command          => sub { floodfill() },
            -text             => 'Flood Fill',
            -width            => 16
        )->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        $lglobal{floodpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{floodpop}->destroy; undef $lglobal{floodpop} }
        );
        $lglobal{floodpop}->Icon( -image => $icon );
    }
}

sub indent {
    saveset();
    my $indent      = shift;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    $operationinterrupt = 0;
    if ( $range_total == 0 ) {
        return;
    }
    else {
        my @selarray;
        if ( $indent eq 'up' ) { @ranges = reverse @ranges }
        while (@ranges) {
            my $end            = pop(@ranges);
            my $start          = pop(@ranges);
            my $thisblockstart = int($start) . '.0';
            my $thisblockend   = int($end) . '.0';
            my $index          = $thisblockstart;
            if ( $thisblockstart == $thisblockend ) {
                my $char;
                if ( $indent eq 'in' ) {
                    if ( $textwindow->compare( $end, '==', "$end lineend" ) )
                    {
                        $char = ' ';
                    }
                    else {
                        $char = $textwindow->get($end);
                        $textwindow->delete($end);
                    }
                    $textwindow->insert( $start, $char )
                        unless ( $textwindow->get( $start, "$start lineend" )
                        =~ /^$/ );
                    $end = "$end+1c"
                        unless (
                        $textwindow->get( $end, "$end lineend" ) =~ /^$/ );
                    push @selarray, ( "$start+1c", $end );
                }
                elsif ( $indent eq 'out' ) {
                    if ($textwindow->compare(
                            $start, '==', "$start linestart"
                        )
                        )
                    {
                        push @selarray, ( $start, $end );
                        next;
                    }
                    else {
                        $char = $textwindow->get("$start-1c");
                        $textwindow->insert( $end, $char );
                        $textwindow->delete("$start-1c");
                        push @selarray, ( "$start-1c", "$end-1c" );
                    }
                }
            }
            else {
                while ( $index <= $thisblockend ) {
                    if ( $indent eq 'in' ) {
                        $textwindow->insert( $index, ' ' )
                            unless (
                            $textwindow->get( $index, "$index lineend" )
                            =~ /^$/ );
                    }
                    elsif ( $indent eq 'out' ) {
                        if ( $textwindow->get( $index, "$index+1c" ) eq ' ' )
                        {
                            $textwindow->delete( $index, "$index+1c" );
                        }
                    }
                    $index++;
                    $index .= '.0';
                }
                push @selarray, ( $thisblockstart, "$thisblockend lineend" );
            }
            if ( $indent eq 'up' ) {
                my $temp = $end, $end = $start;
                $start = $temp;
                if ( $textwindow->compare( "$start linestart", '==', '1.0' ) )
                {
                    push @selarray, ( $start, $end );
                    push @selarray, @ranges;
                    last;
                }
                else {
                    while (
                        $textwindow->compare(
                            "$end-1l", '>=', "$end-1l lineend"
                        )
                        )
                    {
                        $textwindow->insert( "$end-1l lineend", ' ' );
                    }
                    my $templine = $textwindow->get( "$start-1l", "$end-1l" );
                    $textwindow->replacewith( "$start-1l", "$end-1l",
                        ( $textwindow->get( $start, $end ) ) );
                    push @selarray, ( "$start-1l", "$end-1l" );
                    while (@ranges) {
                        $start = pop(@ranges);
                        $end   = pop(@ranges);
                        $textwindow->replacewith( "$start-1l", "$end-1l",
                            ( $textwindow->get( $start, $end ) ) );
                        push @selarray, ( "$start-1l", "$end-1l" );
                    }
                    $textwindow->replacewith( $start, $end, $templine );
                }
            }
            elsif ( $indent eq 'dn' ) {
                if ($textwindow->compare(
                        "$end+1l", '>=', $textwindow->index('end')
                    )
                    )
                {
                    push @selarray, ( $start, $end );
                    push @selarray, @ranges;
                    last;
                }
                else {
                    while (
                        $textwindow->compare(
                            "$end+1l", '>=', "$end+1l lineend"
                        )
                        )
                    {
                        $textwindow->insert( "$end+1l lineend", ' ' );
                    }
                    my $templine = $textwindow->get( "$start+1l", "$end+1l" );
                    $textwindow->replacewith( "$start+1l", "$end+1l",
                        ( $textwindow->get( $start, $end ) ) );
                    push @selarray, ( "$start+1l", "$end+1l" );
                    while (@ranges) {
                        $end   = pop(@ranges);
                        $start = pop(@ranges);
                        $textwindow->replacewith( "$start+1l", "$end+1l",
                            ( $textwindow->get( $start, $end ) ) );
                        push @selarray, ( "$start+1l", "$end+1l" );
                    }
                    $textwindow->replacewith( $start, $end, $templine );
                }
            }
            $textwindow->focus;
            $textwindow->tagRemove( 'sel', '1.0', 'end' );
        }
        while (@selarray) {
            my $end   = pop(@selarray);
            my $start = pop(@selarray);
            $textwindow->tagAdd( 'sel', $start, $end );
        }
    }
}

sub selectrewrap {
    viewpagenums() if ( $lglobal{seepagenums} );
    saveset();
    my $marker      = shift @_;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    my $thisblockstart;
    my $start;
    my $scannosave = $lglobal{scanno_hl};
    $lglobal{scanno_hl} = 0;
    $operationinterrupt = 0;

    if ( $range_total == 0 ) {
        return;
    }
    else {
        my $end = pop(@ranges);    #get the end index of the selection
        $start = pop(@ranges);     #get the start index of the selection
        my @marklist = $textwindow->dump( -mark, $start, $end )
            ;                      #see if there any page markers set
        my ( $markname, @savelist, $markindex, %markhash );
        while (@marklist) {        #save the pagemarkers if they have been set
            shift @marklist;
            $markname  = shift @marklist;
            $markindex = shift @marklist;
            if ( $markname =~ /Pg\S+/ ) {
                $textwindow->insert( $markindex, "\x7f" )
                    ;              #mark the page breaks for rewrapping
                push @savelist, $markname;
            }
        }
        while ( $textwindow->get($start) =~ /^\s*\n/ )
        {                          #if the selection starts on a blank line
            $start = $textwindow->index(
                "$start+1c")    #advance the selection start until it isn't.
        }
        while ( $textwindow->get("$end+1c") =~ /^\s*\n/ )
        {    #if the selection ends at the end of a line but not over it
            $end = $textwindow->index( "$end+1c"
                )  #advance the selection end until it does. (traps odd spaces
        }    #at paragraph end bug)
        $thisblockstart = $start;
        my $thisblockend   = $end;
        my $indentblockend = $end;
        my $inblock        = 0;
        my $infront        = 0;
        my $enableindent;
        my $leftmargin  = $blocklmargin;
        my $rightmargin = $blockrmargin;
        my $firstmargin = $blocklmargin;
        my ( $rewrapped, $initial_tab, $subsequent_tab, $spaces );
        my $indent = 0;
        my $offset = 0;
        my $poem   = 0;
        my $textline;
        my $lastend = $start;
        my ( $sr, $sc, $er, $ec, $line );
        my $textend      = $textwindow->index('end');
        my $toplineblank = 0;

        if ( $textend eq $end ) {
            $textwindow->tagAdd( 'blockend', "$end-1c"
                ) #set a marker at the end of the selection, or one charecter less
        }
        else {    #if the selection ends at the text end
            $textwindow->tagAdd( 'blockend', $end );
        }
        if ( $textwindow->get( '1.0', '1.end' ) eq '' )
        {         #trap top line delete bug
            $toplineblank = 1;
        }
        opstop();
        $spaces = 0;
        while (1) {
            $indent       = $defaultindent;
            $thisblockend = $textwindow->search( '-regex', '--', '^(\x7f)*$',
                $thisblockstart, $end );    #find end of paragraph
            if ($thisblockend) {
                $thisblockend
                    = $textwindow->index( $thisblockend . ' lineend' );
            }
            else {
                $thisblockend = $end;
            }
            ;    #or end of text if end of selection
            my $selection = $textwindow->get( $thisblockstart, $thisblockend )
                if $thisblockend;    #get the paragraph of text
            unless ($selection) {
                $thisblockstart = $thisblockend;
                $thisblockstart = $textwindow->index("$thisblockstart+1c");
                last
                    if (
                    $textwindow->compare( $thisblockstart, '>=', $end ) );
                last if $operationinterrupt;
                next;
            }
            last
                if ( ( $thisblockend eq $lastend )
                || ( $textwindow->compare( $thisblockend, '<', $lastend ) ) )
                ;    #quit if the search isn't advancing
            $textwindow->see($thisblockend);
            $textwindow->update;

            #$firstmargin = $leftmargin if $blockwrap;
            if ( $selection =~ /^\x7f*\/\#/ ) {
                $blockwrap   = 1;
                $leftmargin  = $blocklmargin + 1;
                $firstmargin = $blocklmargin + 1;
                $rightmargin = $blockrmargin;
                if ( $selection =~ /^\x7f*\/#\[(\d+)/ )
                {    #check for block rewrapping with parameter markup
                    if ($1) { $leftmargin = $1 + 1 }
                    $firstmargin = $leftmargin;
                }
                if ( $selection =~ /^\x7f*\/#\[(\d+)?(\.)(\d+)/ ) {
                    if ( length $3 ) { $firstmargin = $3 + 1 }
                }
                if ( $selection =~ /^\x7f*\/#\[(\d+)?(\.)?(\d+)?,(\d+)/ ) {
                    if ($4) { $rightmargin = $4 }
                }
            }
            if ( $selection =~ /^\x7f*\/[\*Ll]/ ) {
                $inblock      = 1;
                $enableindent = 1;
            }    #check for no rewrap markup
            if ( $selection =~ /^\x7f*\/\*\[(\d+)/ ) { $indent = $1 }
            if ( $selection =~ /^\x7f*\/[pP]/ ) {
                $inblock      = 1;
                $enableindent = 1;
                $poem         = 1;
                $indent       = 4;
            }
            if ( $selection =~ /^\x7f*\/[Xx\$]/ ) { $inblock = 1 }
            if ( $selection =~ /^\x7f*\/[fF]/ )   { $inblock = 1 }
            $textwindow->markSet( 'rewrapend', $thisblockend )
                ; #Set a mark at the end of the text so it can be found after rewrap
            unless ( $selection =~ /^\x7f*\s*?(\*\s*){4}\*/ )
            {     #skip rewrap if paragraph is a thought break
                if ($inblock) {
                    if ($enableindent) {
                        $indentblockend = $textwindow->search( '-regex', '--',
                            '^\x7f*[pP\*Ll]\/', $thisblockstart, $end );
                        $indentblockend = $indentblockend || $end;
                        $textwindow->markSet( 'rewrapend', $indentblockend );
                        unless ($offset) { $offset = 0 }
                        ( $sr, $sc ) = split /\./, $thisblockstart;
                        ( $er, $ec ) = split /\./, $indentblockend;
                        unless ($offset) {
                            $offset = 100;
                            for $line ( $sr + 1 .. $er - 1 ) {
                                $textline = $textwindow->get( "$line.0",
                                    "$line.end" );
                                if ($textline) {
                                    $textwindow->search(
                                        '-regexp',
                                        '-count' => \$spaces,
                                        '--', '^\s+', "$line.0", "$line.end"
                                    );
                                    unless ($spaces) { $spaces = 0 }
                                    if ( $spaces < $offset ) {
                                        $offset = $spaces;
                                    }
                                    $spaces = 0;
                                }
                            }
                            $indent = $indent - $offset;
                        }
                        for $line ( $sr .. $er - 1 ) {
                            $textline
                                = $textwindow->get( "$line.0", "$line.end" );
                            next
                                if ( ( $textline =~ /^\x7f*\/[pP\*Ll]/ )
                                || ( $textline =~ /^\x7f*[pP\*Ll]\// ) );
                            if ($enableindent) {
                                $textwindow->insert( "$line.0",
                                    ( ' ' x $indent ) )
                                    if ( $indent > 0 );
                                if ( $indent < 0 ) {
                                    if ($textwindow->get( "$line.0",
                                            "$line.@{[abs $indent]}" ) =~ /\S/
                                        )
                                    {
                                        while ( $textwindow->get("$line.0") eq
                                            ' ' )
                                        {
                                            $textwindow->delete("$line.0");
                                        }
                                    }
                                    else {
                                        $textwindow->delete( "$line.0",
                                            "$line.@{[abs $indent]}" );
                                    }
                                }
                            }
                        }
                        $indent       = 0;
                        $offset       = 0;
                        $enableindent = 0;
                        $poem         = 0;
                        $inblock      = 0;
                    }
                }
                else {
                    $selection =~ s/<i>/\x8d/g
                        ; #convert some characters that will interfere with rewrap
                    $selection =~ s/<\/i>/\x8e/g;
                    $selection =~ s/\[/\x8A/g;
                    $selection =~ s/\]/\x9A/g;
                    $selection =~ s/\(/\x9d/g;
                    $selection =~ s/\)/\x98/g;
                    if ($blockwrap) {
                        $rewrapped = wrapper(
                            $leftmargin,  $firstmargin,
                            $rightmargin, $selection
                        );
                    }
                    else {    #rewrap the paragraph
                        $rewrapped = wrapper( $lmargin, $lmargin, $rmargin,
                            $selection );
                    }
                    $rewrapped =~ s/\x8d/<i>/g;   #convert the characters back
                    $rewrapped =~ s/\x8e/<\/i>/g;
                    $rewrapped =~ s/\x8A/\[/g;
                    $rewrapped =~ s/\x9A/\]/g;
                    $rewrapped =~ s/\x98/\)/g;
                    $rewrapped =~ s/\x9d/\(/g;
                    $textwindow->delete( $thisblockstart, $thisblockend )
                        ;    #delete the original paragraph
                    $textwindow->insert( $thisblockstart, $rewrapped )
                        ;    #insert the rewrapped paragraph
                    my @endtemp = $textwindow->tagRanges('blockend')
                        ;    #find the end of the rewrapped text
                    $end = shift @endtemp;
                }
            }
            if ( $selection =~ /^\x7f*[XxFf\$]\//m ) {
                $inblock      = 0;
                $indent       = 0;
                $offset       = 0;
                $enableindent = 0;
                $poem         = 0;
            }
            if ( $selection =~ /\x7f*#\// ) { $blockwrap = 0 }
            last unless $end;
            $thisblockstart = $textwindow->index('rewrapend')
                ;    #advance to the next paragraph
            $lastend = $textwindow->index("$thisblockstart+1c")
                ;    #track where the end of the last paragraph was
            while (1) {
                $thisblockstart = $textwindow->index("$thisblockstart+1l")
                    ; #if there are blank lines before the next paragraph, advance past them
                last
                    if (
                    $textwindow->compare( $thisblockstart, '>=', 'end' ) );
                next
                    if (
                    $textwindow->get( $thisblockstart,
                        "$thisblockstart lineend" ) eq ''
                    );
                last;
            }
            $blockwrap = 0
                if $operationinterrupt
            ;    #reset blockwrap if rewrap routine is interrupted
            last if $operationinterrupt;    #then quit
            last
                if ( $thisblockstart eq $end )
                ;    #quit if next paragrapn starts at end of selection
            update_indicators();    # update line and page numbers
        }
        if ( $lglobal{stoppop} ) {
            $lglobal{stoppop}->destroy;
            undef $lglobal{stoppop};
        }
        ;                           #destroy interrupt popup
        $operationinterrupt = 0;
        $textwindow->focus;
        $textwindow->update;
        $textwindow->Busy( -recurse => 1 );
        if (@savelist) {            #if there are saved page markers
            while (@savelist) {     #reinsert them
                $markname = shift @savelist;
                $markindex
                    = $textwindow->search( '-regex', '--', '\x7f', '1.0',
                    'end' );
                $textwindow->delete($markindex); #then remove the page markers
                $textwindow->markSet( $markname, $markindex );
                $textwindow->markGravity( $markname, 'left' );
            }
        }
        if ( $start eq '1.0' ) {  #reinsert deleted top line if it was removed
            if ( $toplineblank == 1 ) {    #(kinda half assed but it works)
                $textwindow->insert( '1.0', "\n" );
            }
        }
        $textwindow->tagRemove( 'blockend', '1.0', 'end' );
    }
    while (1) {
        $thisblockstart
            = $textwindow->search( '-regexp', '--', '^[\x7f\s]+$', '1.0',
            'end' );
        last unless $thisblockstart;
        $textwindow->delete( $thisblockstart, "$thisblockstart lineend" );
    }
    $textwindow->see($start);
    $lglobal{scanno_hl} = $scannosave;
    $textwindow->Unbusy( -recurse => 1 );
}

sub blockrewrap {
    $blockwrap = 1;
    selectrewrap();
    $blockwrap = 0;
}

sub asciipopup {
    viewpagenums() if ( $lglobal{seepagenums} );
    if ( defined( $lglobal{asciipop} ) ) {
        $lglobal{asciipop}->deiconify;
        $lglobal{asciipop}->raise;
        $lglobal{asciipop}->focus;
    }
    else {
        $lglobal{asciipop} = $top->Toplevel;
        $lglobal{asciipop}->title('ASCII Boxes');
        my $f = $lglobal{asciipop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f->Label( -text => 'ASCII Drawing Characters', )
            ->pack( -side => 'top', -pady => 2, -padx => 2, -anchor => 'n' );
        my $f5 = $lglobal{asciipop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        my ( $row, $col );
        for ( 0 .. 8 ) {
            next if $_ == 4;
            $row = int $_ / 3;
            $col = $_ % 3;
            $f5->Entry(
                -width        => 1,
                -background   => 'white',
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

        my $f0 = $lglobal{asciipop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        my $wlabel = $f0->Label(
            -width => 16,
            -text  => 'ASCII Box Width',
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'n' );
        my $wmentry = $f0->Entry(
            -width        => 6,
            -background   => 'white',
            -relief       => 'sunken',
            -textvariable => \$lglobal{asciiwidth},
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'n' );
        my $f1 = $lglobal{asciipop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        my $leftjust = $f1->Radiobutton(
            -text        => 'left justified',
            -selectcolor => $lglobal{checkcolor},
            -variable    => \$lglobal{asciijustify},
            -value       => 'left',
        )->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
        my $centerjust = $f1->Radiobutton(
            -text        => 'centered',
            -selectcolor => $lglobal{checkcolor},
            -variable    => \$lglobal{asciijustify},
            -value       => 'center',
        )->grid( -row => 2, -column => 2, -padx => 1, -pady => 2 );
        my $rightjust = $f1->Radiobutton(
            -selectcolor => $lglobal{checkcolor},
            -text        => 'right justified',
            -variable    => \$lglobal{asciijustify},
            -value       => 'right',
        )->grid( -row => 2, -column => 3, -padx => 1, -pady => 2 );
        my $asciiw = $f1->Checkbutton(
            -variable    => \$lglobal{asciiwrap},
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Don\'t Rewrap'
        )->grid( -row => 3, -column => 2, -padx => 1, -pady => 2 );
        my $gobut = $f1->Button(
            -activebackground => $activecolor,
            -command          => sub { asciibox() },
            -text             => 'Draw Box',
            -width            => 16
        )->grid( -row => 4, -column => 2, -padx => 1, -pady => 2 );
        $lglobal{asciipop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{asciipop}->destroy; undef $lglobal{asciipop} }
        );
        $lglobal{asciipop}->Icon( -image => $icon );
        $lglobal{asciipop}->resizable( 'no', 'no' );
    }
}

sub alignpopup {
    if ( defined( $lglobal{alignpop} ) ) {
        $lglobal{alignpop}->deiconify;
        $lglobal{alignpop}->raise;
        $lglobal{alignpop}->focus;
    }
    else {
        $lglobal{alignpop} = $top->Toplevel;
        $lglobal{alignpop}->title('Align text');
        my $f = $lglobal{alignpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f->Label( -text => 'String to align on (first occurence)', )
            ->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        my $f1 = $lglobal{alignpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f1->Entry(
            -width        => 8,
            -background   => 'white',
            -font         => $lglobal{font},
            -relief       => 'sunken',
            -textvariable => \$lglobal{alignstring},
        )->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        my $gobut = $f1->Button(
            -activebackground => $activecolor,
            -command          => [ \&aligntext ],
            -text             => 'Align selected text',
            -width            => 16
        )->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        $lglobal{alignpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{alignpop}->destroy; undef $lglobal{alignpop} }
        );
        $lglobal{alignpop}->Icon( -image => $icon );
    }
}

sub tonamed {
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    }
    else {
        while (@ranges) {
            my $end   = pop @ranges;
            my $start = pop @ranges;
            $textwindow->markSet( 'srchend', $end );
            my $thisblockstart;
            named( '&(?![\w#])',           '&amp;',   $start, 'srchend' );
            named( '&$',                   '&amp;',   $start, 'srchend' );
            named( '"',                    '&quot;',  $start, 'srchend' );
            named( '(?<=[^-!])--(?=[^>])', '&mdash;', $start, 'srchend' );
            named( '(?<=[^-])--$',         '&mdash;', $start, 'srchend' );
            named( '^--(?=[^-])',          '&mdash;', $start, 'srchend' );
            named( '& ',                   '&amp; ',  $start, 'srchend' );
            named( '&c\.',                 '&amp;c.', $start, 'srchend' );
            named( ' >',                   ' &gt;',   $start, 'srchend' );
            named( '< ',                   '&lt; ',   $start, 'srchend' );
            my $from;

            for ( 128 .. 255 ) {
                $from = lc sprintf( "%x", $_ );
                named(
                    '\x' . $from,
                    entity( '\x' . $from ),
                    $start, 'srchend'
                );
            }
            while (
                $thisblockstart = $textwindow->search(
                    '-regexp',             '--',
                    '[\x{100}-\x{65535}]', $start,
                    'srchend'
                )
                )
            {
                my $xchar = ord( $textwindow->get($thisblockstart) );
                $textwindow->ntdelete( $thisblockstart,
                    "$thisblockstart+1c" );
                $textwindow->ntinsert( $thisblockstart, "&#$xchar;" );
            }
            $textwindow->markUnset('srchend');
        }
    }
}

sub fromnamed {
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    }
    else {
        while (@ranges) {
            my $end   = pop @ranges;
            my $start = pop @ranges;
            $textwindow->markSet( 'srchend', $end );
            my ( $thisblockstart, $length );
            named( '&amp;',   '&',  $start, 'srchend' );
            named( '&quot;',  '"',  $start, 'srchend' );
            named( '&mdash;', '--', $start, 'srchend' );
            named( ' &gt;',   ' >', $start, 'srchend' );
            named( '&lt; ',   '< ', $start, 'srchend' );
            my $from;

            for ( 160 .. 255 ) {
                $from = lc sprintf( "%x", $_ );
                named( entity( '\x' . $from ), chr($_), $start, 'srchend' );
            }
            while (
                $thisblockstart = $textwindow->search(
                    '-regexp',
                    '-count' => \$length,
                    '--', '&#\d+;', $start, $end
                )
                )
            {
                my $xchar = $textwindow->get( $thisblockstart,
                    $thisblockstart . '+' . $length . 'c' );
                $textwindow->ntdelete( $thisblockstart,
                    $thisblockstart . '+' . $length . 'c' );
                $xchar =~ s/&#(\d+);/$1/;
                $textwindow->ntinsert( $thisblockstart, chr($xchar) );
            }
            $textwindow->markUnset('srchend');
        }
    }
}

sub fracconv {
    my ( $start, $end ) = @_;
    my %frachash = (
        '\b1\/2\b' => '&frac12;',
        '\b1\/4\b' => '&frac14;',
        '\b3\/4\b' => '&frac34;',
    );
    my ( $ascii, $html, $length );
    my $thisblockstart = 1;
    while ( ( $ascii, $html ) = each(%frachash) ) {
        while (
            $thisblockstart = $textwindow->search(
                '-regexp',
                '-count' => \$length,
                '--', "-?$ascii", $start, $end
            )
            )
        {
            $textwindow->replacewith( $thisblockstart,
                $thisblockstart . "+$length c", $html );
        }
    }

}

### Fixup

## Word Frequency
sub wordcount {
    push @operations, ( localtime() . ' - Word Frequency' );
    viewpagenums() if ( $lglobal{seepagenums} );
    oppopupdate()  if $lglobal{oppop};
    $lglobal{seen} = ();
    %{ $lglobal{seenm} } = ();
    my ( @words, $match, @savesets );
    my $index = '1.0';
    my $wc    = 0;
    my $end   = $textwindow->index('end');

    if ( $lglobal{popup} ) {
        $lglobal{popup}->deiconify;
        $lglobal{popup}->raise;
        $lglobal{wclistbox}->delete( '0', 'end' );
    }
    else {
        $lglobal{popup} = $top->Toplevel;
        $lglobal{popup}
            ->title('Word frequency - Ctrl+s to save, Ctrl+x to export');
        $lglobal{popup}->geometry($geometry2) if $geometry2;
        my $wcseframe
            = $lglobal{popup}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $wcopt3 = $wcseframe->Checkbutton(
            -variable    => \$lglobal{suspects_only},
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Suspects'
        )->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
        my $wcopt1 = $wcseframe->Checkbutton(
            -variable    => \$lglobal{ignore_case},
            -selectcolor => $lglobal{checkcolor},
            -text        => 'No case',
        )->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
        $wcseframe->Radiobutton(
            -variable    => \$lglobal{alpha_sort},
            -selectcolor => $lglobal{checkcolor},
            -value       => 'a',
            -text        => 'Alph',
        )->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
        $wcseframe->Radiobutton(
            -variable    => \$lglobal{alpha_sort},
            -selectcolor => $lglobal{checkcolor},
            -value       => 'f',
            -text        => 'Frq',
        )->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
        $wcseframe->Radiobutton(
            -variable    => \$lglobal{alpha_sort},
            -selectcolor => $lglobal{checkcolor},
            -value       => 'l',
            -text        => 'Len',
        )->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
        $wcseframe->Button(
            -activebackground => $activecolor,
            -command          => sub {
                return unless ( $lglobal{wclistbox}->curselection );
                $lglobal{harmonics} = 1;
                harmonicspop();
            },
            -text => '1st Harm',
            )->pack(
            -side   => 'left',
            -padx   => 1,
            -pady   => 1,
            -anchor => 'nw'
            );
        $wcseframe->Button(
            -activebackground => $activecolor,
            -command          => sub {
                return unless ( $lglobal{wclistbox}->curselection );
                $lglobal{harmonics} = 2;
                harmonicspop();
            },
            -text => '2nd Harm',
            )->pack(
            -side   => 'left',
            -padx   => 1,
            -pady   => 1,
            -anchor => 'nw'
            );
        $wcseframe->Button(
            -activebackground => $activecolor,
            -command          => sub {
                return if $lglobal{global_filename} =~ /No File Loaded/;
                savefile() unless ( $textwindow->numberChanges == 0 );
                wordcount();
            },
            -text => 'Re Run ',
            )->pack(
            -side   => 'left',
            -padx   => 2,
            -pady   => 1,
            -anchor => 'nw'
            );
        my $wcseframe1
            = $lglobal{popup}->Frame->pack( -side => 'top', -anchor => 'n' );
        my @wfbuttons = (
            [ 'Emdashes'  => \&dashcheck ],
            [ 'Hyphens'   => \&hyphencheck ],
            [ 'Alpha/num' => \&alphanumcheck ],
            [   'All Words' => sub {
                    $lglobal{saveheader}
                        = "$wc total words. " .
                        keys( %{ $lglobal{seen} } )
                        . " distinct words in file.";
                    sortwords( $lglobal{seen} );
                    }
            ],
            [ 'Check Spelling', \&wfspellcheck ],
            [ 'Ital/Bold Words', \&itwords, \&ital_adjust ],
            [ 'ALL CAPS',        \&capscheck ],
            [ 'MiXeD CasE',      \&mixedcasecheck ],
            [ 'Initial Caps',    \&initcapcheck ],
            [ 'Character Cnts',  \&charsortcheck ],
            [ 'Check , Upper',   \&commark ],
            [ 'Check . Lower',   \&bangmark ],
            [ 'Check Accents',   \&accentcheck ],
            [ 'Unicode > FF',    \&unicheck ],
            [ 'Stealtho Check',  \&stealthcheck ],
        );
        my ( $row, $col, $inc ) = ( 0, 0, 0 );
        for (@wfbuttons) {
            $row = int( $inc / 5 );
            $col = $inc % 5;
            my $button = $wcseframe1->Button(
                -activebackground => $activecolor,
                -command          => $_->[1],
                -text             => $_->[0],
                -width            => 13
                )->grid(
                -row    => $row,
                -column => $col,
                -padx   => 1,
                -pady   => 1
                );
            ++$inc;
            $button->bind( '<3>' => $_->[2] ) if $_->[2];
        }

        my $wcframe = $lglobal{popup}
            ->Frame->pack( -fill => 'both', -expand => 'both', );
        $lglobal{wclistbox} = $wcframe->Scrolled(
            'Listbox',
            -scrollbars  => 'se',
            -background  => 'white',
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
        drag( $lglobal{wclistbox} );
        $lglobal{popup}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{popup}->destroy;
                undef $lglobal{popup};
                undef $lglobal{wclistbox};
            }
        );
        $lglobal{popup}->Icon( -image => $icon );
        BindMouseWheel( $lglobal{wclistbox} );
        $lglobal{wclistbox}->eventAdd( '<<search>>' => '<ButtonRelease-3>' );
        $lglobal{wclistbox}->bind(
            '<<search>>',
            sub {
                $lglobal{wclistbox}->selectionClear( 0, 'end' );
                $lglobal{wclistbox}->selectionSet(
                    $lglobal{wclistbox}->index(
                        '@'
                            . (
                                  $lglobal{wclistbox}->pointerx
                                - $lglobal{wclistbox}->rootx
                            )
                            . ','
                            . (
                                  $lglobal{wclistbox}->pointery
                                - $lglobal{wclistbox}->rooty
                            )
                    )
                );
                my ($sword)
                    = $lglobal{wclistbox}
                    ->get( $lglobal{wclistbox}->curselection );
                searchpopup();
                $sword =~ s/\d+\s+(\S)/$1/;
                $sword =~ s/\s+\*\*\*\*$//;
                if ( $sword =~ /\*space\*/ ) {
                    $sword = ' ';
                    searchoptset(qw/0 x x 1/);
                }
                elsif ( $sword =~ /\*tab\*/ ) {
                    $sword = '\t';
                    searchoptset(qw/0 x x 1/);
                }
                elsif ( $sword =~ /\*newline\*/ ) {
                    $sword = '\n';
                    searchoptset(qw/0 x x 1/);
                }
                elsif ( $sword =~ /\*nbsp\*/ ) {
                    $sword = '\x{A0}';
                    searchoptset(qw/0 x x 1/);
                }
                elsif ( $sword =~ /\W/ ) {
                    $sword =~ s/([^\w\s\\])/\\$1/g;
                    searchoptset(qw/0 x x 1/);
                }
                $lglobal{searchentry}->delete( '1.0', 'end' );
                $lglobal{searchentry}->insert( 'end', $sword );
                updatesearchlabels();
                $lglobal{searchentry}->after( $lglobal{delay} );
            }
        );
        $lglobal{wclistbox}
            ->eventAdd( '<<find>>' => '<Double-Button-1>', '<Return>' );
        $lglobal{wclistbox}->bind(
            '<<find>>',
            sub {
                my ($sword)
                    = $lglobal{wclistbox}
                    ->get( $lglobal{wclistbox}->curselection );
                return unless length $sword;
                @savesets = @sopt;
                $sword =~ s/(\d+)\s+(\S)/$2/;
                my $snum = $1;
                $sword =~ s/\s+\*\*\*\*$//;
                if ( $sword =~ /\W/ ) {
                    $sword =~ s/\*nbsp\*/\x{A0}/;
                    $sword =~ s/\*tab\*/\t/;
                    $sword =~ s/\*newline\*/\n/;
                    $sword =~ s/\*space\*/ /;
                    $sword =~ s/([^\w\s\\])/\\$1/g;
                    $sword .= '\b'
                        if ( ( length $sword gt 1 ) && ( $sword =~ /\w$/ ) );
                    searchoptset(qw/0 x x 1/);
                }
                if    ( $sword =~ /\*space\*/ )   { $sword = ' ' }
                elsif ( $sword =~ /\*tab\*/ )     { $sword = "\t" }
                elsif ( $sword =~ /\*newline\*/ ) { $sword = "\n" }
                elsif ( $sword =~ /\*nbsp\*/ )    { $sword = "\xA0" }
                unless ($snum) {
                    searchoptset(qw/0 x x 1/);
                    unless ( $sword =~ m/--/ ) {
                        $sword = "(?<=-)$sword|$sword(?=-)";
                    }
                }
                searchtext($sword);
                searchoptset(@savesets);
                $top->raise;
            }
        );
        $lglobal{wclistbox}->eventAdd( '<<harm>>' => '<Control-Button-1>' );
        $lglobal{wclistbox}->bind(
            '<<harm>>',
            sub {
                return unless ( $lglobal{wclistbox}->curselection );
                harmonics( $lglobal{wclistbox}->get('active') );
                harmonicspop();
            }
        );
        $lglobal{wclistbox}->eventAdd(
            '<<adddict>>' => '<Control-Button-2>',
            '<Control-Button-3>'
        );
        $lglobal{wclistbox}->bind(
            '<<adddict>>',
            sub {
                return unless ( $lglobal{wclistbox}->curselection );
                return unless $lglobal{wclistbox}->index('active');
                my $sword = $lglobal{wclistbox}->get('active');
                $sword =~ s/\d+\s+([\w'-]*)/$1/;
                $sword =~ s/\*\*\*\*$//;
                $sword =~ s/\s//g;
                return if ( $sword =~ /[^\p{Alnum}']/ );
                spellmyaddword($sword);
                delete( $lglobal{spellsort}->{$sword} );
                $lglobal{saveheader} = scalar( keys %{ $lglobal{spellsort} } )
                    . ' words not recognised by the spellchecker.';
                sortwords( \%{ $lglobal{spellsort} } );
            }
        );
        $lglobal{popup}->bind(
            '<Configure>' => sub {
                $lglobal{popup}->XEvent;
                $geometry2 = $lglobal{popup}->geometry;
                $lglobal{geometryupdate} = 1;
            }
        );
        $lglobal{wclistbox}->eventAdd(
            '<<pnext>>' => '<Next>',
            '<Prior>', '<Up>', '<Down>'
        );
        $lglobal{wclistbox}->bind(
            '<<pnext>>',
            sub {
                $lglobal{wclistbox}->selectionClear( 0, 'end' );
                $lglobal{wclistbox}
                    ->selectionSet( $lglobal{wclistbox}->index('active') );
            }
        );
        $lglobal{wclistbox}->bind(
            '<Home>',
            sub {
                $lglobal{wclistbox}->selectionClear( 0, 'end' );
                $lglobal{wclistbox}->see(0);
                $lglobal{wclistbox}->selectionSet(1);
                $lglobal{wclistbox}->activate(1);
            }
        );
        $lglobal{wclistbox}->bind(
            '<End>',
            sub {
                $lglobal{wclistbox}->selectionClear( 0, 'end' );
                $lglobal{wclistbox}->see( $lglobal{wclistbox}->index('end') );
                $lglobal{wclistbox}
                    ->selectionSet( $lglobal{wclistbox}->index('end') - 1 );
                $lglobal{wclistbox}
                    ->activate( $lglobal{wclistbox}->index('end') - 1 );
            }
        );
        $lglobal{popup}->bind(
            '<Control-s>' => sub {
                my ($name);
                $name = $textwindow->getSaveFile(
                    -title       => 'Save Word Frequency List As',
                    -initialdir  => $globallastpath,
                    -initialfile => 'wordfreq.txt'
                );
                if ( defined($name) and length($name) ) {
                    open( my $SAVE, ">$name" );
                    print $SAVE join "\n",
                        $lglobal{wclistbox}->get( '0', 'end' );
                }
            }
        );
        $lglobal{popup}->bind(
            '<Control-x>' => sub {
                my ($name);
                $name = $textwindow->getSaveFile(
                    -title       => 'Export Word Frequency List As',
                    -initialdir  => $globallastpath,
                    -initialfile => 'wordlist.txt'
                );
                if ( defined($name) and length($name) ) {
                    my $count = $lglobal{wclistbox}->index('end');
                    open( my $SAVE, ">$name" );
                    for ( 1 .. $count ) {
                        my $word = $lglobal{wclistbox}->get($_);
                        if ( ( defined $word ) && ( length $word ) ) {
                            $word =~ s/^\d+\s+//;
                            $word =~ s/\s+\*{4}\s*$//;
                            print $SAVE $word, "\n";
                        }
                    }
                }
            }
        );
    }
    my $filename = $textwindow->FileName;
    unless ($filename) {
        $filename = 'tempfile.tmp';
        open( my $file, ">$filename" );
        my ($lines) = $textwindow->index('end - 1 chars') =~ /^(\d+)\./;
        while ( $textwindow->compare( $index, '<', 'end' ) ) {
            my $end = $textwindow->index("$index  lineend +1c");
            my $line = $textwindow->get( $index, $end );
            print $file $line;
            $index = $end;
        }
    }
    $top->Busy( -recurse => 1 );
    $lglobal{wclistbox}->focus;
    $lglobal{wclistbox}
        ->insert( 'end', 'Please wait, building word list....' );
    savefile()
        if ( ( $textwindow->FileName )
        && ( $textwindow->numberChanges != 0 ) );
    open my $fh, '<', $filename;
    while ( my $line = <$fh> ) {
        utf8::decode($line);
        next if $line =~ m/^-----*\s?File:\s?\S+\.(png|jpg)---/;
        $line =~ s/_/ /g;
        $line =~ s/<!--//g;
        $line =~ s/-->//g;

        #print "$line\n";
        if ( $lglobal{ignore_case} ) { $line = lc($line) }
        @words = split( /\s+/, $line );
        for my $word (@words) {
            next unless ( $word =~ /--/ );
            next if ( $word =~ /---/ );
            $word =~ s/[\.,']$//;
            $word =~ s/^[\.'-]+//;
            next if ( $word eq '' );
            $match = ( $lglobal{ignore_case} ) ? lc($word) : $word;
            $lglobal{seenm}->{$match}++;
        }
        $line =~ s/[^'\.,\p{Alnum}-]/ /g;
        $line =~ s/--/ /g;
        $line =~ s/(\D),/$1 /g;
        $line =~ s/,(\D)/ $1/g;
        @words = split( /\s+/, $line );
        for my $word (@words) {
            $word =~ s/[\.',-]+$//;
            $word =~ s/^[\.,'-]+//;
            next if ( $word eq '' );
            $wc++;
            $match = ( $lglobal{ignore_case} ) ? lc($word) : $word;
            $lglobal{seen}->{$match}++;
        }
        $index++;
        $index .= '.0';
        $textwindow->update;
    }
    close $fh;
    unlink 'tempfile.tmp' if ( -e 'tempfile.tmp' );

    #print "$index  ";
    $lglobal{saveheader} = "$wc total words. " .
        keys( %{ $lglobal{seen} } ) . " distinct words in file.";
    $lglobal{wclistbox}->delete( '0', 'end' );
    $lglobal{last_sort} = $lglobal{ignore_case};
    searchoptset(qw/x 1 x x/) if $lglobal{ignore_case};
    $top->Unbusy( -recurse => 1 );
    sortwords( \%{ $lglobal{seen} } );
    update_indicators();
}

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
    $top->Busy( -recurse => 1 );

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
    }
    else {
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
    $title =~ s/$window_title - //
        ;    #FIXME: sub this out; this and next in the tidy code
    $title =~ s/edited - //;
    $title = os_normal($title);
    $title = dos_path($title) if OS_Win;
    ( $name, $path, $extension ) = fileparse( $title, '\.[^\.]*$' );
    my $types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
    unless ($gutpath) {
        $gutpath = $textwindow->getOpenFile(
            -filetypes => $types,
            -title     => 'Where is the Gutcheck executable?'
        );
    }
    return unless $gutpath;
    my $gutcheckoptions = ' -ey'
        ; # e - echo queried line. y - puts errors to stdout instead of stderr.
    if ( $gcopt[0] ) { $gutcheckoptions .= 't' }
    ;     # Check common typos
    if ( $gcopt[1] ) { $gutcheckoptions .= 'x' }
    ;     # "Trust no one" Paranoid mode. Queries everything
    if ( $gcopt[2] ) { $gutcheckoptions .= 'p' }
    ;     # Require closure of quotes on every paragraph
    if ( $gcopt[3] ) { $gutcheckoptions .= 's' }
    ;     # Force checking for matched pairs of single quotes
    if ( $gcopt[4] ) { $gutcheckoptions .= 'm' }
    ;     # Ignore markup in < >
    if ( $gcopt[5] ) { $gutcheckoptions .= 'l' }
    ;     # Line end checking - defaults on
    if ( $gcopt[6] ) { $gutcheckoptions .= 'v' }
    ;     # Verbose - list EVERYTHING!
    if ( $gcopt[7] ) { $gutcheckoptions .= 'u' }
    ;     # Use file of User-defined Typos
    if ( $gcopt[8] ) { $gutcheckoptions .= 'd' }
    ;     # Ignore DP style page separators
    $gutcheckoptions .= ' ';
    $gutpath = os_normal($gutpath);
    $gutpath = dos_path($gutpath) if OS_Win;
    saveset();

    if ( $lglobal{gcpop} ) {
        $lglobal{gclistbox}->delete( '0', 'end' );
    }
    gutcheckrun( $gutpath, $gutcheckoptions, 'gutchk.tmp' );
    $top->Unbusy;
    unlink 'gutchk.tmp';
    gcheckpop_up();
}

sub gutopts {
    my $gcdialog
        = $top->DialogBox( -title => 'Gutcheck Options', -buttons => ['OK'] );
    my $gcopt6 = $gcdialog->add(
        'Checkbutton',
        -variable    => \$gcopt[6],
        -selectcolor => $lglobal{checkcolor},
        -text        => '-v Enable verbose mode (Recommended).',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt0 = $gcdialog->add(
        'Checkbutton',
        -variable    => \$gcopt[0],
        -selectcolor => $lglobal{checkcolor},
        -text        => '-t Disable check for common typos.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt1 = $gcdialog->add(
        'Checkbutton',
        -variable    => \$gcopt[1],
        -selectcolor => $lglobal{checkcolor},
        -text        => '-x Disable paranoid mode.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt2 = $gcdialog->add(
        'Checkbutton',
        -variable    => \$gcopt[2],
        -selectcolor => $lglobal{checkcolor},
        -text        => '-p Report ALL unbalanced double quotes.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt3 = $gcdialog->add(
        'Checkbutton',
        -variable    => \$gcopt[3],
        -selectcolor => $lglobal{checkcolor},
        -text        => '-s Report ALL unbalanced single quotes.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt4 = $gcdialog->add(
        'Checkbutton',
        -variable    => \$gcopt[4],
        -selectcolor => $lglobal{checkcolor},
        -text        => '-m Interpret HTML markup.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt5 = $gcdialog->add(
        'Checkbutton',
        -variable    => \$gcopt[5],
        -selectcolor => $lglobal{checkcolor},
        -text        => '-l Do not report non DOS newlines.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt7 = $gcdialog->add(
        'Checkbutton',
        -variable    => \$gcopt[7],
        -selectcolor => $lglobal{checkcolor},
        -text        => '-u Flag words from the .typ file.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt8 = $gcdialog->add(
        'Checkbutton',
        -variable    => \$gcopt[8],
        -selectcolor => $lglobal{checkcolor},
        -text        => '-d Ignore DP style page separators.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    $gcdialog->Show;
    saveset();
}

sub jeebiespop_up {
    my @jlines;
    viewpagenums() if ( $lglobal{seepagenums} );
    if ( $lglobal{jeepop} ) {
        $lglobal{jeepop}->deiconify;
    }
    else {
        $lglobal{jeepop} = $top->Toplevel;
        $lglobal{jeepop}->title('Jeebies');
        $lglobal{jeepop}->geometry($geometry2) if $geometry2;
        $lglobal{jeepop}->transient($top)      if $stayontop;
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
            -activebackground => $activecolor,
            -command          => sub { jeebiesrun( $lglobal{jelistbox} ) },
            -text             => 'Re-run Jeebies',
            -width            => 16
            )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
            );
        my $pframe = $lglobal{jeepop}
            ->Frame->pack( -fill => 'both', -expand => 'both', );
        $lglobal{jelistbox} = $pframe->Scrolled(
            'Listbox',
            -scrollbars  => 'se',
            -background  => 'white',
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
        $lglobal{jeepop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{jeepop}->destroy; undef $lglobal{jeepop} } );
        $lglobal{jeepop}->Icon( -image => $icon );
        BindMouseWheel( $lglobal{jelistbox} );
        $lglobal{jelistbox}
            ->eventAdd( '<<jview>>' => '<Button-1>', '<Return>' );
        $lglobal{jelistbox}->bind( '<<jview>>', sub { jeebiesview() } );
        $lglobal{jeepop}->bind(
            '<Configure>' => sub {
                $lglobal{jeepop}->XEvent;
                $geometry2 = $lglobal{jeepop}->geometry;
                $lglobal{geometryupdate} = 1;
            }
        );
        $lglobal{jelistbox}->eventAdd(
            '<<jremove>>' => '<ButtonRelease-2>',
            '<ButtonRelease-3>'
        );
        $lglobal{jelistbox}->bind(
            '<<jremove>>',
            sub {
                $lglobal{jelistbox}->activate(
                    $lglobal{jelistbox}->index(
                        '@'
                            . (
                                  $lglobal{jelistbox}->pointerx
                                - $lglobal{jelistbox}->rootx
                            )
                            . ','
                            . (
                                  $lglobal{jelistbox}->pointery
                                - $lglobal{jelistbox}->rooty
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

## Fixup Popup

sub fixup {
    push @operations, ( localtime() . ' - Fixup Routine' );
    viewpagenums() if ( $lglobal{seepagenums} );
    oppopupdate()  if $lglobal{oppop};
    my ($line);
    my $index     = '1.0';
    my $lastindex = '1.0';
    my $inblock   = 0;
    my $update    = 0;
    my $edited    = 0;
    my $end       = $textwindow->index('end');
    $operationinterrupt = 0;

    while ( $lastindex < $end ) {
        $line = $textwindow->get( $lastindex, $index );
        if ( $line =~ /\/[\$\*]/ ) { $inblock = 1 }
        if ( $line =~ /[\$\*]\// ) { $inblock = 0 }
        unless ( $inblock && ${ $lglobal{fixopt} }[0] ) {
            if ( ${ $lglobal{fixopt} }[10] ) {
                while ( $line =~ s/(?<=\S)\s\s+(?=\S)/ / ) { $edited++ }
            }
            if ( ${ $lglobal{fixopt} }[12] ) {
                $edited++ if $line =~ s/llth/11th/g;
                $edited++ if $line =~ s/(?<=\d)lst/1st/g;
                $edited++ if $line =~ s/(?<=\s)lst/1st/g;
                $edited++ if $line =~ s/^lst/1st/;
            }
            if ( ${ $lglobal{fixopt} }[1] ) {
                $edited++ if $line =~ s/ -/-/g;   # Remove space before hyphen
                $edited++ if $line =~ s/- /-/g;   # Remove space after hyphen
                $edited++
                    if $line =~ s/(?<![-])([-]*---)(?=[^\s\\"F-])/$1 /g
                ; # Except leave a space after a string of three or more hyphens
            }
            if ( ${ $lglobal{fixopt} }[2] ) {
                $edited++ if $line =~ s/ +\.(?=\D)/\./g;
            }
            ;     # Get rid of space before periods
            if ( ${ $lglobal{fixopt} }[3] ) {
                $edited++
                    if $line =~ s/ +!/!/g;
            }
            ;     # Get rid of space before exclamation points
            if ( ${ $lglobal{fixopt} }[4] ) {
                $edited++
                    if $line =~ s/ +\?/\?/g;
            }
            ;     # Get rid of space before question marks

            if ( ${ $lglobal{fixopt} }[5] ) {
                $edited++
                    if $line =~ s/ +\;/\;/g;
            }
            ;     # Get rid of space before semicolons
            if ( ${ $lglobal{fixopt} }[6] ) {
                $edited++
                    if $line =~ s/ +:/:/g;
            }
            ;     # Get rid of space before colons

            if ( ${ $lglobal{fixopt} }[7] ) {
                $edited++
                    if $line =~ s/ +,/,/g;
            }
            ;     # Get rid of space before commas
            if ( ${ $lglobal{fixopt} }[8] ) {
                $edited++
                    if $line =~ s/^\" +/\"/
                ; # Remove space after doublequote if it is the first character on a line
                $edited++
                    if $line =~ s/ +\"$/\"/
                ; # Remove space before doublequote if it is the last character on a line
            }
            if ( ${ $lglobal{fixopt} }[9] ) {
                $edited++
                    if $line =~ s/(?<=(\(|\{|\[)) //g
                ;    # Get rid of space after opening brackets
                $edited++
                    if $line =~ s/ (?=(\)|\}|\]))//g
                ;    # Get rid of space before closing brackets
            }
            if ( ${ $lglobal{fixopt} }[13] ) {
                $edited++ if $line =~ s/(?<![\.\!\?])\.{3}(?!\.)/ \.\.\./g;
                $edited++ if $line =~ s/^ \./\./;
            }
            if ( ${ $lglobal{fixopt} }[11] ) {
                $edited++
                    if $line
                        =~ s/^\s*(\*\s*){5}$/       \*       \*       \*       \*       \*\n/;
            }
            $edited++ if ( $line =~ s/ +$// );
            if ( ${ $lglobal{fixopt} }[14] and ${ $lglobal{fixopt} }[15] ) {
                $edited++ if $line =~ s/´\s+/´/g;
                $edited++ if $line =~ s/\s+ª/ª/g;
            }
            if ( ${ $lglobal{fixopt} }[14] and !${ $lglobal{fixopt} }[15] ) {
                $edited++ if $line =~ s/\s+´/´/g;
                $edited++ if $line =~ s/ª\s+/ª/g;
            }
            $update++ if ( ( $index % 250 ) == 0 );
            $textwindow->see($index) if ( $edited || $update );
            if ($edited) {
                $textwindow->replacewith( $lastindex, $index, $line );
            }
        }
        $textwindow->markSet( 'insert', $index ) if $update;
        $textwindow->update if ( $edited || $update );
        update_indicators() if ( $edited || $update );
        $edited    = 0;
        $update    = 0;
        $lastindex = $index;
        $index++;
        $index .= '.0';
        if ( $index > $end ) { $index = $end }
        if ($operationinterrupt) { $operationinterrupt = 0; return }
    }
    $textwindow->markSet( 'insert', 'end' );
    $textwindow->see('end');
    update_indicators();
}

sub separatorpopup {
    push @operations, ( localtime() . ' - Page Separators Fixup' );
    oppopupdate() if $lglobal{oppop};
    if ( defined( $lglobal{pagepop} ) ) {
        $lglobal{pagepop}->deiconify;
        $lglobal{pagepop}->raise;
        $lglobal{pagepop}->focus;
    }
    else {
        $lglobal{pagepop} = $top->Toplevel;
        $lglobal{pagepop}->title('Page separators');
        my $sf1 = $lglobal{pagepop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        my $joinbutton = $sf1->Button(
            -activebackground => $activecolor,
            -command          => sub { joinlines('j') },
            -text             => 'Join Lines',
            -underline        => 0,
            -width            => 18
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $joinhybutton = $sf1->Button(
            -activebackground => $activecolor,
            -command          => sub { joinlines('k') },
            -text             => 'Join, Keep Hyphen',
            -underline        => 6,
            -width            => 18
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );

        my $sf2 = $lglobal{pagepop}
            ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        my $blankbutton = $sf2->Button(
            -activebackground => $activecolor,
            -command          => sub { joinlines('l') },
            -text             => 'Blank Line',
            -underline        => 6,
            -width            => 12
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );

        my $sectjoinbutton = $sf2->Button(
            -activebackground => $activecolor,
            -command          => sub { joinlines('t') },
            -text             => 'New Section',
            -underline        => 7,
            -width            => 12
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $chjoinbutton = $sf2->Button(
            -activebackground => $activecolor,
            -command          => sub { joinlines('h') },
            -text             => 'New Chapter',
            -underline        => 5,
            -width            => 12
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $sf3 = $lglobal{pagepop}
            ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        my $jautobutton = $sf3->Checkbutton(
            -variable => \$lglobal{jautomatic},
            -command  => sub {
                $lglobal{jsemiautomatic} = 0 if $lglobal{jsemiautomatic};
            },
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Full Auto',
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $jsautobutton = $sf3->Checkbutton(
            -variable => \$lglobal{jsemiautomatic},
            -command =>
                sub { $lglobal{jautomatic} = 0 if $lglobal{jautomatic}; },
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Semi Auto',
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $sf4 = $lglobal{pagepop}
            ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        my $refreshbutton = $sf4->Button(
            -activebackground => $activecolor,
            -command          => sub { convertfilnum() },
            -text             => 'Refresh',
            -underline        => 0,
            -width            => 8
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $undobutton = $sf4->Button(
            -activebackground => $activecolor,
            -command          => sub { undojoin() },
            -text             => 'Undo',
            -underline        => 0,
            -width            => 8
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $delbutton = $sf4->Button(
            -activebackground => $activecolor,
            -command          => sub { joinlines('d') },
            -text             => 'Delete',
            -underline        => 0,
            -width            => 8
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $phelpbutton = $sf4->Button(
            -activebackground => $activecolor,
            -command          => sub { phelppopup() },
            -text             => '?',
            -width            => 1
            )
            ->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        $lglobal{jsemiautomatic} = 1;
    }
    $lglobal{pagepop}->protocol(
        'WM_DELETE_WINDOW' => sub {
            $lglobal{pagepop}->destroy;
            undef $lglobal{pagepop};
            $textwindow->tagRemove( 'highlight', '1.0', 'end' );
        }
    );
    $lglobal{pagepop}->Icon( -image => $icon );
    $lglobal{pagepop}->Tk::bind( '<j>' => sub { joinlines('j') } );
    $lglobal{pagepop}->Tk::bind( '<k>' => sub { joinlines('k') } );
    $lglobal{pagepop}->Tk::bind( '<l>' => sub { joinlines('l') } );
    $lglobal{pagepop}->Tk::bind( '<h>' => sub { joinlines('h') } );
    $lglobal{pagepop}->Tk::bind( '<d>' => sub { joinlines('d') } );
    $lglobal{pagepop}->Tk::bind( '<t>' => sub { joinlines('t') } );
    $lglobal{pagepop}->Tk::bind( '<r>' => \&convertfilnum );
    $lglobal{pagepop}
        ->Tk::bind( '<v>' => sub { openpng(); $lglobal{pagepop}->raise; } );
    $lglobal{pagepop}->Tk::bind( '<u>' => \&undojoin );
    $lglobal{pagepop}->Tk::bind(
        '<a>' => sub {
            if   ( $lglobal{jautomatic} ) { $lglobal{jautomatic} = 0 }
            else                          { $lglobal{jautomatic} = 1 }
        }
    );
    $lglobal{pagepop}->Tk::bind(
        '<s>' => sub {
            if   ( $lglobal{jsemiautomatic} ) { $lglobal{jsemiautomatic} = 0 }
            else                              { $lglobal{jsemiautomatic} = 1 }
        }
    );
    $lglobal{pagepop}->transient($top) if $stayontop;
}

sub delblanklines {
    viewpagenums() if ( $lglobal{seepagenums} );
    my ( $line, $index, $r, $c, $pagemark );
    $searchstartindex = '2.0';
    $searchendindex   = '2.0';
    $textwindow->Busy;
    while ($searchstartindex) {
        $searchstartindex
            = $textwindow->search( '-nocase', '-regexp', '--',
            '^-----*\s*File:\s?(\S+)\.(png|jpg)---.*$',
            $searchendindex, 'end' );
        {

            no warnings 'uninitialized';
            $searchstartindex = '2.0' if $searchstartindex eq '1.0';
        }
        last unless $searchstartindex;
        ( $r, $c ) = split /\./, $searchstartindex;
        if ($textwindow->get( ( $r - 1 ) . '.0', ( $r - 1 ) . '.end' ) eq '' )
        {
            $textwindow->delete( "$searchstartindex -1c", $searchstartindex );
            $searchendindex = $textwindow->index("$searchstartindex -2l");
            $textwindow->see($searchstartindex);
            $textwindow->update;
            next;
        }
        $searchendindex = $r ? "$r.end" : '2.0';

    }
    $textwindow->Unbusy;
}

## Pop up a window where footnotes can be found, fixed and formatted. (heh)
sub footnotepop {
    push @operations, ( localtime() . ' - Footnote Fixup' );
    viewpagenums() if ( $lglobal{seepagenums} );
    oppopupdate()  if $lglobal{oppop};
    if ( defined( $lglobal{footpop} ) ) {
        $lglobal{footpop}->deiconify;
        $lglobal{footpop}->raise;
        $lglobal{footpop}->focus;
    }
    else {
        $lglobal{fncount} = '1' unless $lglobal{fncount};
        $lglobal{fnalpha} = '1' unless $lglobal{fnalpha};
        $lglobal{fnroman} = '1' unless $lglobal{fnroman};
        $lglobal{fnindex} = '0' unless $lglobal{fnindex};
        $lglobal{fntotal} = '0' unless $lglobal{fntotal};
        $lglobal{footpop} = $top->Toplevel;
        my ( $checkn, $checka, $checkr );
        $lglobal{footpop}->title('Footnote Fix Up');
        my $frame2 = $lglobal{footpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $frame2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                $textwindow->yview('end');
                $textwindow->see(
                    $lglobal{fnarray}->[ $lglobal{fnindex} ][2] )
                    if $lglobal{fnarray}->[ $lglobal{fnindex} ][2];
            },
            -text  => 'See Anchor',
            -width => 14
        )->grid( -row => 1, -column => 1, -padx => 2, -pady => 4 );
        $lglobal{footnotetotal}
            = $frame2->Label->grid( -row => 1, -column => 2 );
        $frame2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                footnoteshow();
            },
            -text  => 'See Footnote',
            -width => 14
        )->grid( -row => 1, -column => 3, -padx => 2, -pady => 4 );
        $frame2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                $lglobal{fnindex}--;
                footnoteshow();
            },
            -text  => '<--- Last FN',
            -width => 14
        )->grid( -row => 2, -column => 1 );
        $lglobal{fnindexbrowse} = $frame2->BrowseEntry(
            -label     => 'Go to - #',
            -variable  => \$lglobal{fnindex},
            -state     => 'readonly',
            -width     => 8,
            -listwidth => 22,
            -browsecmd => sub {
                $lglobal{fnindex} = $lglobal{fntotal}
                    if ( $lglobal{fnindex} > $lglobal{fntotal} );
                $lglobal{fnindex} = 1 if ( $lglobal{fnindex} < 1 );
                footnoteshow();
            }
        )->grid( -row => 2, -column => 2 );
        $frame2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                $lglobal{fnindex}++;
                footnoteshow();
            },
            -text  => 'Next FN --->',
            -width => 14
        )->grid( -row => 2, -column => 3 );
        $lglobal{footnotenumber} = $frame2->Label(
            -background => 'white',
            -relief     => 'sunken',
            -justify    => 'center',
            -font       => '{Times} 10',
            -width      => 10,
        )->grid( -row => 3, -column => 1, -padx => 2, -pady => 4 );
        $lglobal{footnoteletter} = $frame2->Label(
            -background => 'white',
            -relief     => 'sunken',
            -justify    => 'center',
            -font       => '{Times} 10',
            -width      => 10,
        )->grid( -row => 3, -column => 2, -padx => 2, -pady => 4 );
        $lglobal{footnoteroman} = $frame2->Label(
            -background => 'white',
            -relief     => 'sunken',
            -justify    => 'center',
            -font       => '{Times} 10',
            -width      => 10,
        )->grid( -row => 3, -column => 3, -padx => 2, -pady => 4 );
        $checkn = $frame2->Checkbutton(
            -variable => \$lglobal{fntypen},
            -command  => sub {
                return if ( $lglobal{footstyle} eq 'inline' );
                $checka->deselect;
                $checkr->deselect;
            },
            -text  => 'All to Number',
            -width => 14
        )->grid( -row => 4, -column => 1, -padx => 2, -pady => 4 );
        $checka = $frame2->Checkbutton(
            -variable => \$lglobal{fntypea},
            -command  => sub {
                return if ( $lglobal{footstyle} eq 'inline' );
                $checkn->deselect;
                $checkr->deselect;
            },
            -text  => 'All to Letter',
            -width => 14
        )->grid( -row => 4, -column => 2, -padx => 2, -pady => 4 );
        $checkr = $frame2->Checkbutton(
            -variable => \$lglobal{fntyper},
            -command  => sub {
                return if ( $lglobal{footstyle} eq 'inline' );
                $checka->deselect;
                $checkn->deselect;
            },
            -text  => 'All to Roman',
            -width => 14
        )->grid( -row => 4, -column => 3, -padx => 2, -pady => 4 );
        $frame2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                return if ( $lglobal{footstyle} eq 'inline' );
                fninsertmarkers('n');
                footnoteshow();
            },
            -text  => 'Number',
            -width => 14
        )->grid( -row => 5, -column => 1, -padx => 2, -pady => 4 );
        $frame2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                return if ( $lglobal{footstyle} eq 'inline' );
                fninsertmarkers('a');
                footnoteshow();
            },
            -text  => 'Letter',
            -width => 14
        )->grid( -row => 5, -column => 2, -padx => 2, -pady => 4 );
        $frame2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                return if ( $lglobal{footstyle} eq 'inline' );
                fninsertmarkers('r');
                footnoteshow();
            },
            -text  => 'Roman',
            -width => 14
        )->grid( -row => 5, -column => 3, -padx => 2, -pady => 4 );
        $frame2->Button(
            -activebackground => $activecolor,
            -command          => sub { fnjoin() },
            -text             => 'Join With Previous',
            -width            => 14
        )->grid( -row => 6, -column => 1, -padx => 2, -pady => 4 );
        $frame2->Button(
            -activebackground => $activecolor,
            -command          => sub { footnoteadjust() },
            -text             => 'Adjust Bounds',
            -width            => 14
        )->grid( -row => 6, -column => 2, -padx => 2, -pady => 4 );
        $frame2->Button(
            -activebackground => $activecolor,
            -command          => sub { setanchor() },
            -text             => 'Set Anchor',
            -width            => 14
        )->grid( -row => 6, -column => 3, -padx => 2, -pady => 4 );
        $frame2->Checkbutton(
            -variable => \$lglobal{fncenter},
            -text     => 'Center on Search'
        )->grid( -row => 7, -column => 1, -padx => 3, -pady => 4 );
        $frame2->Button(
            -activebackground => $activecolor,
            -command => sub { $lglobal{fnsecondpass} = 0; footnotefixup() },
            -text    => 'First Pass',
            -width   => 14
        )->grid( -row => 7, -column => 2, -padx => 2, -pady => 4 );
        my $fnrb1 = $frame2->Radiobutton(
            -text        => 'Inline',
            -variable    => \$lglobal{footstyle},
            -selectcolor => $lglobal{checkcolor},
            -value       => 'inline',
            -command     => sub {
                $lglobal{fnindex} = 1;
                footnoteshow();
                $lglobal{fnmvbutton}->configure( -state => 'disabled' );
            },
        )->grid( -row => 8, -column => 1 );
        $lglobal{fnfpbutton} = $frame2->Button(
            -activebackground => $activecolor,
            -command          => sub { footnotefixup() },
            -text             => 'Re Index',
            -state            => 'disabled',
            -width            => 14
        )->grid( -row => 8, -column => 2, -padx => 2, -pady => 4 );
        my $fnrb2 = $frame2->Radiobutton(
            -text        => 'Out-of-Line',
            -variable    => \$lglobal{footstyle},
            -selectcolor => $lglobal{checkcolor},
            -value       => 'end',
            -command     => sub {
                $lglobal{fnindex} = 1;
                footnoteshow();
                $lglobal{fnmvbutton}->configure( -state => 'normal' )
                    if ( $lglobal{fnsecondpass}
                    && ( defined $lglobal{fnlzs} and @{ $lglobal{fnlzs} } ) );
            },
        )->grid( -row => 8, -column => 3 );
        my $frame1 = $lglobal{footpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $frame1->Button(
            -activebackground => $activecolor,
            -command          => sub { setlz() },
            -text             => 'Set LZ @ cursor',
            -width            => 14
        )->grid( -row => 1, -column => 1, -padx => 2, -pady => 4 );
        $frame1->Button(
            -activebackground => $activecolor,
            -command          => sub { autochaptlz() },
            -text             => 'Autoset Chap. LZ',
            -width            => 14
        )->grid( -row => 1, -column => 2, -padx => 2, -pady => 4 );
        $frame1->Button(
            -activebackground => $activecolor,
            -command          => sub { autoendlz() },
            -text             => 'Autoset End LZ',
            -width            => 14
        )->grid( -row => 1, -column => 3, -padx => 2, -pady => 4 );
        $frame1->Button(
            -activebackground => $activecolor,
            -command          => sub {
                getlz();
                return unless $lglobal{fnlzs} and @{ $lglobal{fnlzs} };
                $lglobal{zoneindex}-- unless $lglobal{zoneindex} < 1;
                if ( $lglobal{fnlzs}[ $lglobal{zoneindex} ] ) {
                    $textwindow->see( 'LZ' . $lglobal{zoneindex} );
                    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                    $textwindow->tagAdd(
                        'highlight',
                        'LZ' . $lglobal{zoneindex},
                        'LZ' . $lglobal{zoneindex} . '+10c'
                    );
                }
            },
            -text  => '<--- Last LZ',
            -width => 12
        )->grid( -row => 2, -column => 1, -padx => 2, -pady => 4 );

        $frame1->Button(
            -activebackground => $activecolor,
            -command          => sub {
                getlz();
                return unless $lglobal{fnlzs} and @{ $lglobal{fnlzs} };
                $lglobal{zoneindex}++
                    unless $lglobal{zoneindex}
                        > ( ( scalar( @{ $lglobal{fnlzs} } ) ) - 2 );
                if ( $lglobal{fnlzs}[ $lglobal{zoneindex} ] ) {
                    $textwindow->see( 'LZ' . $lglobal{zoneindex} );
                    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                    $textwindow->tagAdd(
                        'highlight',
                        'LZ' . $lglobal{zoneindex},
                        'LZ' . $lglobal{zoneindex} . '+10c'
                    );
                }
            },
            -text  => 'Next LZ --->',
            -width => 12
        )->grid( -row => 2, -column => 3, -padx => 6, -pady => 4 );
        my $frame3 = $lglobal{footpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $frame3->Checkbutton(
            -variable => \$lglobal{fnsearchlimit},
            -text     => 'Unlimited Anchor Search'
        )->grid( -row => 1, -column => 1, -padx => 3, -pady => 4 );
        $lglobal{fnmvbutton} = $frame3->Button(
            -activebackground => $activecolor,
            -command          => sub { footnotemove() },
            -text             => 'Move Footnotes To Landing Zone(s)',
            -state            => 'disabled',
            -width            => 30
        )->grid( -row => 1, -column => 2, -padx => 3, -pady => 4 );
        my $frame4 = $lglobal{footpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $frame4->Button(
            -activebackground => $activecolor,
            -command          => sub { footnotetidy() },
            -text             => 'Tidy Up Footnotes',
            -width            => 18
        )->grid( -row => 1, -column => 1, -padx => 6, -pady => 4 );
        $frame4->Button(
            -activebackground => $activecolor,
            -command          => sub { fnview() },
            -text             => 'Check Footnotes',
            -width            => 14
        )->grid( -row => 1, -column => 2, -padx => 6, -pady => 4 );
        $lglobal{footpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{footpop}->destroy;
                undef $lglobal{footpop};
                $textwindow->tagRemove( 'footnote', '1.0', 'end' );
            }
        );
        $lglobal{footpop}->Icon( -image => $icon );
        $fnrb2->select;
        my ( $start, $end );
        $start = '1.0';
        while (1) {
            $start = $textwindow->markNext($start);
            last unless $start;
            next unless ( $start =~ /^fns/ );
            $end = $start;
            $end =~ s/^fns/fne/;
            $textwindow->tagAdd( 'footnote', $start, $end );
        }
        $lglobal{footnotenumber}->configure( -text => $lglobal{fncount} );
        $lglobal{footnoteletter}
            ->configure( -text => alpha( $lglobal{fnalpha} ) );
        $lglobal{footnoteroman}
            ->configure( -text => roman( $lglobal{fnroman} ) );
        $lglobal{footnotetotal}->configure(
            -text => "# $lglobal{fnindex}" . "/" . "$lglobal{fntotal}" );
        $lglobal{fnsecondpass} = 0;
    }
}

sub markpopup {    # FIXME: Rename html_popup
    push @operations, ( localtime() . ' - HTML Markup' );
    viewpagenums() if ( $lglobal{seepagenums} );
    if ( defined( $lglobal{markpop} ) ) {
        $lglobal{markpop}->deiconify;
        $lglobal{markpop}->raise;
        $lglobal{markpop}->focus;
    }
    else {
        my $blockmarkup;
        $lglobal{markpop} = $top->Toplevel;
        $lglobal{markpop}->title('HTML Markup');
        my $tableformat;
        my $f0 = $lglobal{markpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f0->Button(
            -activebackground => $activecolor,
            -command          => sub { htmlautoconvert() },
            -text             => 'Autogenerate HTML',
            -width            => 16
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        $f0->Button(
            -text    => 'Custom Page Labels',
            -command => sub { pageadjust() },
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
        $f0->Button(
            -activebackground => $activecolor,
            -command          => sub { htmlimages(); },
            -text             => 'Auto Illus Search',
            -width            => 16,
        )->grid( -row => 1, -column => 3, -padx => 1, -pady => 2 );
        my $pagecomments = $f0->Checkbutton(
            -variable    => \$lglobal{pagecmt},
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Pg #s as comments',
            -anchor      => 'w',
            )->grid(
            -row    => 2,
            -column => 1,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
            );
        my $pageanchors = $f0->Checkbutton(
            -variable    => \$lglobal{pageanch},
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Insert Anchors at Pg #s',
            -anchor      => 'w',
            )->grid(
            -row    => 2,
            -column => 3,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
            );
        $pageanchors->select;
        my $fractions = $f0->Checkbutton(
            -variable    => \$lglobal{autofraction},
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Convert Fractions',
            -anchor      => 'w',
            )->grid(
            -row    => 3,
            -column => 1,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
            );

        my $utfconvert = $f0->Checkbutton(
            -variable    => \$lglobal{leave_utf},
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Keep UTF-8 Chars',
            -anchor      => 'w',
            )->grid(
            -row    => 3,
            -column => 2,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
            );

        my $latin1_convert = $f0->Checkbutton(
            -variable    => \$lglobal{keep_latin1},
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Keep Latin-1 Chars',
            -anchor      => 'w',
            )->grid(
            -row    => 3,
            -column => 4,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
            );

        $blockmarkup = $f0->Checkbutton(
            -variable    => \$lglobal{cssblockmarkup},
            -selectcolor => $lglobal{checkcolor},
            -command     => sub {

                if ( $lglobal{cssblockmarkup} ) {
                    $blockmarkup->configure( '-text' => 'CSS blockquote' );
                }
                else {
                    $blockmarkup->configure( '-text' => 'Std. <blockquote>' );
                }
            },
            -text   => 'CSS blockquote',
            -anchor => 'w',
            )->grid(
            -row    => 3,
            -column => 3,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
            );
        my $f1 = $lglobal{markpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        my ( $inc, $row, $col ) = ( 0, 0, 0 );
        for (
            qw/i b u center h1 h2 h3 h4 h5 h6 p hr br big small ol ul li sup sub table tr td blockquote code/
            )
        {
            $col = $inc % 5;
            $row = int $inc / 5;
            $f1->Button(
                -activebackground => $activecolor,
                -command          => [ sub { markup( $_[0] ) }, $_ ],
                -text             => "<$_>",
                -width            => 10
                )->grid(
                -row    => $row,
                -column => $col,
                -padx   => 1,
                -pady   => 2
                );
            ++$inc;
        }

        $f1->Button(
            -activebackground => $activecolor,
            -command          => sub { markup('&nbsp;') },
            -text             => 'nb space',
            -width            => 10
        )->grid( -row => 8, -column => 3, -padx => 1, -pady => 2 );
        $f1->Button(
            -activebackground => $activecolor,
            -command          => \&poetryhtml,
            -text             => 'Poetry',
            -width            => 10
        )->grid( -row => 8, -column => 4, -padx => 1, -pady => 2 );

        my $f2 = $lglobal{markpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        my %hbuttons = (
            'anchor', 'Named anchor',  'img',   'Image',
            'elink',  'External Link', 'ilink', 'Internal Link'
        );
        ( $row, $col ) = ( 0, 0 );
        for ( keys %hbuttons ) {
            $f2->Button(
                -activebackground => $activecolor,
                -command          => [ sub { markup( $_[0] ) }, $_ ],
                -text             => "$hbuttons{$_}",
                -width            => 13
                )->grid(
                -row    => $row,
                -column => $col,
                -padx   => 1,
                -pady   => 2
                );
            ++$col;
        }

        my $f3 = $lglobal{markpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f3->Button(
            -activebackground => $activecolor,
            -command          => sub { markup('del') },
            -text             => 'Remove markup from selection',
            -width            => 28
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        $f3->Button(
            -activebackground => $activecolor,
            -command          => sub {
                for my $orphan (
                    'b',  'i',  'center', 'u',  'sub', 'sup',
                    'sc', 'h1', 'h2',     'h3', 'h4',  'h5',
                    'h6', 'p',  'span'
                    )
                {
                    working( 'Checking <' . $orphan . '>' );
                    last if orphans($orphan);
                }
                working();
            },
            -text  => 'Find orphaned markup',
            -width => 28
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
        my $f4 = $lglobal{markpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        my $unorderselect = $f4->Radiobutton(
            -text        => 'unordered',
            -selectcolor => $lglobal{checkcolor},
            -variable    => \$lglobal{liststyle},
            -value       => 'ul',
        )->grid( -row => 1, -column => 1 );
        my $orderselect = $f4->Radiobutton(
            -text        => 'ordered',
            -selectcolor => $lglobal{checkcolor},
            -variable    => \$lglobal{liststyle},
            -value       => 'ol',
        )->grid( -row => 1, -column => 2 );
        my $autolbutton = $f4->Button(
            -activebackground => $activecolor,
            -command          => sub { autolist(); $textwindow->focus },
            -text             => 'Auto List',
            -width            => 16
        )->grid( -row => 1, -column => 4, -padx => 1, -pady => 2 );
        $f4->Checkbutton(
            -text     => 'ML',
            -variable => \$lglobal{list_multiline},
            -onvalue  => 1,
            -offvalue => 0
        )->grid( -row => 1, -column => 5 );
        my $leftselect = $f4->Radiobutton(
            -text        => 'left',
            -selectcolor => $lglobal{checkcolor},
            -variable    => \$lglobal{tablecellalign},
            -value       => ' align="left"',
        )->grid( -row => 2, -column => 1 );
        my $censelect = $f4->Radiobutton(
            -text        => 'center',
            -selectcolor => $lglobal{checkcolor},
            -variable    => \$lglobal{tablecellalign},
            -value       => ' align="center"',
        )->grid( -row => 2, -column => 2 );
        my $rghtselect = $f4->Radiobutton(
            -text        => 'right',
            -selectcolor => $lglobal{checkcolor},
            -variable    => \$lglobal{tablecellalign},
            -value       => ' align="right"',
        )->grid( -row => 2, -column => 3 );
        $leftselect->select;
        $unorderselect->select;
        $f4->Button(
            -activebackground => $activecolor,
            -command =>
                sub { autotable( $tableformat->get ); $textwindow->focus },
            -text  => 'Auto Table',
            -width => 16
        )->grid( -row => 2, -column => 4, -padx => 1, -pady => 2 );
        $f4->Checkbutton(
            -text     => 'ML',
            -variable => \$lglobal{tbl_multiline},
            -onvalue  => 1,
            -offvalue => 0
        )->grid( -row => 2, -column => 5 );
        my $f5 = $lglobal{markpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $tableformat = $f5->Entry(
            -width      => 40,
            -background => 'white',
            -relief     => 'sunken',
        )->grid( -row => 0, -column => 1, -pady => 2 );
        $f5->Label( -text => 'Column Fmt', )
            ->grid( -row => 0, -column => 2, -padx => 2, -pady => 2 );
        my $diventry = $f5->Entry(
            -width      => 40,
            -background => 'white',
            -relief     => 'sunken',
        )->grid( -row => 1, -column => 1, -pady => 2 );
        $f5->Button(
            -activebackground => $activecolor,
            -command =>
                sub { markup( 'div', $diventry->get ); $textwindow->focus },
            -text  => 'div',
            -width => 8
        )->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
        my $f6 = $lglobal{markpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        my $spanentry = $f6->Entry(
            -width      => 40,
            -background => 'white',
            -relief     => 'sunken',
        )->grid( -row => 1, -column => 1, -pady => 2 );
        $f6->Button(
            -activebackground => $activecolor,
            -command =>
                sub { markup( 'span', $spanentry->get ); $textwindow->focus },
            -text  => 'span',
            -width => 8
        )->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
        my $f7 = $lglobal{markpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f7->Checkbutton(
            -variable    => \$lglobal{poetrynumbers},
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Find and Format Poetry Line Numbers'
        )->grid( -row => 1, -column => 1, -pady => 2 );
        $f7->Button(
            -activebackground => $activecolor,
            -command          => sub {
                open my $infile, '<', 'header.txt'
                    or warn "Could not open header file. $!\n";
                my $headertext;
                while (<$infile>) {
                    $_ =~ s/\cM\cJ|\cM|\cJ/\n/g;

                    #$_ = eol_convert($_);
                    $headertext .= $_;
                }
                $textwindow->insert( '1.0', $headertext );
                close $infile;
                $textwindow->insert( 'end', "<\/body>\n<\/html>" );
            },
            -text  => 'Header',
            -width => 16
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
        my $f8 = $lglobal{markpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f8->Button(
            -activebackground => $activecolor,
            -command          => \&linkcheck,
            -text             => 'Link Checker',
            -width            => 16
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        $f8->Button(
            -activebackground => $activecolor,
            -command          => sub {
                tidyrun('-f tidyerr.err -o null');
                unlink 'null' if ( -e 'null' );
            },
            -text  => 'HTML Tidy',
            -width => 16
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
        $diventry->insert( 'end', ' style="margin-left: 2em;"' );
        $spanentry->insert( 'end', ' style="margin-left: 2em;"' );
        $lglobal{markpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{markpop}->destroy; undef $lglobal{markpop} } );
        $lglobal{markpop}->Icon( -image => $icon );
        $lglobal{markpop}->transient($top) if $stayontop;
    }
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
        $bracketstartndx = $textwindow->search( '-regexp', '--', '\[sidenote',
            $sdnoteindexstart, 'end' );
        if ($bracketstartndx) {
            $textwindow->replacewith( "$bracketstartndx+1c",
                "$bracketstartndx+2c", 'S' );
            $textwindow->markSet( 'sidenote', "$bracketstartndx+1c" );
            next;
        }
        $textwindow->markSet( 'sidenote', '1.0' );
        last;
    }
    while (1) {
        $sdnoteindexstart = $textwindow->index('sidenote');
        $bracketstartndx = $textwindow->search( '-regexp', '--', '\[Sidenote',
            $sdnoteindexstart, 'end' );
        last unless $bracketstartndx;
        $bracketndx = "$bracketstartndx+1c";
        while (1) {
            $bracketendndx
                = $textwindow->search( '--', ']', $bracketndx, 'end' );
            $bracketendndx = $textwindow->index("$bracketstartndx+9c")
                unless $bracketendndx;
            $bracketendndx = $textwindow->index("$bracketendndx+1c")
                if $bracketendndx;
            $nextbracketndx
                = $textwindow->search( '--', '[', $bracketndx, 'end' );
            if (($nextbracketndx)
                && ($textwindow->compare(
                        $nextbracketndx, '<', $bracketendndx
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
        $paragraphp
            = $textwindow->search( '-backwards', '-regexp', '--', '^$',
            $bracketstartndx, '1.0' );
        $paragraphn
            = $textwindow->search( '-regexp', '--', '^$', $bracketstartndx,
            'end' );
        $sidenote = $textwindow->get( $bracketstartndx, $bracketendndx );
        if ( $textwindow->get( "$bracketstartndx-2c", $bracketstartndx ) ne
            "\n\n" )
        {
            if ((   $textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq
                    ' '
                )
                || ($textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq
                    "\n" )
                )
            {
                $textwindow->delete( $bracketendndx, "" );
            }
            $textwindow->delete( $bracketstartndx, $bracketendndx );
            $textwindow->see($bracketstartndx);
            $textwindow->insert( "$paragraphp+1l", $sidenote . "\n\n" );
        }
        elsif (
            $textwindow->compare( "$bracketendndx+1c", '<', $paragraphn ) )
        {
            if ((   $textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq
                    ' '
                )
                || ($textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq
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
    my $error
        = $textwindow->search( '-regexp', '--', '(?<=[^\[])[Ss]idenote[: ]',
        '1.0', 'end' );
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
        $searchstartindex
            = $textwindow->search( '-regexp', '--', '(?<=\S)\s\s+\d+$',
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
        while ( $thisblockstart
            = $textwindow->search( '-exact', '--', $term, '1.0', 'end' ) )
        {
            $textwindow->ntdelete( $thisblockstart, "$thisblockstart+1c" );
            $textwindow->ntinsert( $thisblockstart, $cp{$term} );
        }
    }
}

## ASCII Table Special Effects
sub tablefx {
    viewpagenums() if ( $lglobal{seepagenums} );
    if ( defined( $lglobal{tblfxpop} ) ) {
        $lglobal{tblfxpop}->deiconify;
        $lglobal{tblfxpop}->raise;
        $lglobal{tblfxpop}->focus;
    }
    else {
        $lglobal{columnspaces} = '';
        $lglobal{tblfxpop}     = $top->Toplevel;
        $lglobal{tblfxpop}->title('ASCII Table Special Effects');
        my $f0 = $lglobal{tblfxpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        my %tb_buttons = (
            'Table Select'   => sub { tblselect() },
            'Table Deselect' => sub {
                $textwindow->tagRemove( 'table',   '1.0', 'end' );
                $textwindow->tagRemove( 'linesel', '1.0', 'end' );
                $textwindow->markUnset( 'tblstart', 'tblend' );
                undef $lglobal{selectedline};
            },
            'Insert Vertical Line' => sub {
                insertline('i');
            },
            'Add Vertical Line' => sub {
                insertline('a');
            },
            'Space Out Table' => sub {
                tblspace();
            },
            'Auto Columns' => sub {
                tblautoc();
            },
            'Compress Table' => sub {
                tblcompress();
            },
            'Select Prev Line' => sub {
                tlineselect('p');
            },
            'Select Next Line' => sub {
                tlineselect('n');
            },
            'Line Deselect' => sub {
                $textwindow->tagRemove( 'linesel', '1.0', 'end' );
                undef $lglobal{selectedline};
            },
            'Delete Sel. Line' => sub {
                my @ranges      = $textwindow->tagRanges('linesel');
                my $range_total = @ranges;
                $operationinterrupt = 0;
                $textwindow->addGlobStart;
                if ( $range_total == 0 ) {
                    $textwindow->addGlobEnd;
                    return;
                }
                else {
                    while (@ranges) {
                        my $end   = pop(@ranges);
                        my $start = pop(@ranges);
                        $textwindow->delete( $start, $end )
                            if ( $textwindow->get($start) eq '|' );
                    }
                }
                $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
                $textwindow->tagRemove( 'linesel', '1.0', 'end' );
                $textwindow->addGlobEnd;
            },
            'Remove Sel. Line' => sub {
                tlineremove();
            },
        );
        my ( $inc, $row, $col ) = ( 0, 0, 0 );
        for ( keys %tb_buttons ) {
            $row = int( $inc / 4 );
            $col = $inc % 4;
            $f0->Button(
                -activebackground => $activecolor,
                -command          => $tb_buttons{$_},
                -text             => $_,
                -width            => 16
                )->grid(
                -row    => $row,
                -column => $col,
                -padx   => 1,
                -pady   => 2
                );
            ++$inc;
        }

        my $f1 = $lglobal{tblfxpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f1->Label( -text => 'Justify', )
            ->grid( -row => 1, -column => 0, -padx => 1, -pady => 2 );
        my $rb1 = $f1->Radiobutton(
            -text        => 'L',
            -variable    => \$lglobal{tblcoljustify},
            -selectcolor => $lglobal{checkcolor},
            -value       => 'l',
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        my $rb2 = $f1->Radiobutton(
            -text        => 'C',
            -variable    => \$lglobal{tblcoljustify},
            -selectcolor => $lglobal{checkcolor},
            -value       => 'c',
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
        my $rb3 = $f1->Radiobutton(
            -text        => 'R',
            -variable    => \$lglobal{tblcoljustify},
            -selectcolor => $lglobal{checkcolor},
            -value       => 'r',
        )->grid( -row => 1, -column => 3, -padx => 1, -pady => 2 );
        $f1->Checkbutton(
            -variable    => \$lglobal{tblrwcol},
            -selectcolor => $lglobal{checkcolor},
            -text        => 'Rewrap Cols',
            -command     => sub {
                if ( $lglobal{tblrwcol} ) {
                    $rb1->configure( -state => 'active' );
                    $rb2->configure( -state => 'active' );
                    $rb3->configure( -state => 'active' );
                }
                else {
                    $rb1->configure( -state => 'disabled' );
                    $rb2->configure( -state => 'disabled' );
                    $rb3->configure( -state => 'disabled' );
                }
            },
        )->grid( -row => 1, -column => 4, -padx => 1, -pady => 2 );
        $lglobal{colwidthlbl} = $f1->Label(
            -text  => "Width $lglobal{columnspaces}",
            -width => 8,
        )->grid( -row => 1, -column => 5, -padx => 1, -pady => 2 );
        $f1->Button(
            -activebackground => $activecolor,
            -command          => sub { coladjust(-1) },
            -text             => 'Move Left',
            -width            => 10
        )->grid( -row => 1, -column => 6, -padx => 1, -pady => 2 );
        $f1->Button(
            -activebackground => $activecolor,
            -command          => sub { coladjust(1) },
            -text             => 'Move Right',
            -width            => 10
        )->grid( -row => 1, -column => 7, -padx => 1, -pady => 2 );
        my $f3 = $lglobal{tblfxpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f3->Label( -text => 'Table Right Column', )
            ->grid( -row => 1, -column => 0, -padx => 1, -pady => 2 );
        $f3->Entry(
            -width        => 6,
            -background   => 'white',
            -textvariable => \$lglobal{stepmaxwidth},
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        $f3->Button(
            -activebackground => $activecolor,
            -command          => sub { grid2step() },
            -text             => 'Convert Grid to Step',
            -width            => 16
        )->grid( -row => 1, -column => 3, -padx => 1, -pady => 2 );
        my $f4 = $lglobal{tblfxpop}
            ->Frame->pack( -side => 'top', -anchor => 'n' );
        $f4->Button(
            -activebackground => $activecolor,
            -command          => sub {
                $textwindow->undo;
                $textwindow->tagRemove( 'highlight', '1.0', 'end' );
            },
            -text  => 'Undo',
            -width => 10
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        $f4->Button(
            -activebackground => $activecolor,
            -command          => sub { $textwindow->redo },
            -text             => 'Redo',
            -width            => 10
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
        $f4->Button(
            -activebackground => $activecolor,
            -command          => sub { step2grid() },
            -text             => 'Convert Step to Grid',
            -width            => 16
        )->grid( -row => 1, -column => 3, -padx => 1, -pady => 2 );
        $lglobal{tblfxpop}->bind( '<Control-Left>',  sub { coladjust(-1) } );
        $lglobal{tblfxpop}->bind( '<Control-Right>', sub { coladjust(1) } );
        $lglobal{tblfxpop}->bind( '<Left>',  sub { tlineselect('p') } );
        $lglobal{tblfxpop}->bind( '<Right>', sub { tlineselect('n') } );
        $lglobal{tblfxpop}->bind(
            '<Control-z>',
            sub {
                $textwindow->undo;
                $textwindow->tagRemove( 'highlight', '1.0', 'end' );
            }
        );
        $lglobal{tblfxpop}->bind( '<Delete>', sub { tlineremove() } );
        tblselect();
    }
    $lglobal{tblfxpop}->protocol(
        'WM_DELETE_WINDOW' => sub {
            $textwindow->tagRemove( 'table',   '1.0', 'end' );
            $textwindow->tagRemove( 'linesel', '1.0', 'end' );
            $textwindow->markUnset( 'tblstart', 'tblend' );
            $lglobal{tblfxpop}->destroy;
            undef $lglobal{tblfxpop};
        }
    );
    $lglobal{tblfxpop}->Icon( -image => $icon );

}

## Clean Up Rewrap
sub cleanup {
    $top->Busy( -recurse => 1 );
    $searchstartindex = '1.0';
    viewpagenums() if ( $lglobal{seepagenums} );
    while (1) {
        $searchstartindex
            = $textwindow->search( '-regexp', '--',
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

## Convert Greek
# sub convertgreek {

#     # does nothing yet
# }

### Text Processing

sub text_convert_italic {
    my $italic  = qr/<\/?i>/;
    my $replace = $italic_char;
    $textwindow->FindAndReplaceAll( '-regexp', '-nocase', $italic, $replace );
}

sub text_convert_bold {
    my $bold    = qr/<\/?b>/;
    my $replace = "$bold_char";
    $textwindow->FindAndReplaceAll( '-regexp', '-nocase', $bold, $replace );
}

#sub text_convert_smcap { }

## Insert a "Thought break" (duh)
sub thoughtbreak {
    $textwindow->insert( ( $textwindow->index('insert') ) . ' lineend',
        '       *' x 5 );
}

sub text_DP_tb {
    $textwindow->insert( $textwindow->index('insert') . ' lineend', '<tb>' );
}

sub text_convert_tb {
    my $tb = '       *       *       *       *       *';
    $textwindow->FindAndReplaceAll( '-exact', '-nocase', '<tb>', $tb );
}

# Popup for choosing replacement characters, etc.
sub text_convert_options {

    my $options = $top->DialogBox(
        -title   => "Text Processing Options",
        -buttons => ["OK"],
    );

    my $italic_frame = $options->add('Frame')
        ->pack( -side => 'top', -padx => 5, -pady => 3 );
    my $italic_label = $italic_frame->Label(
        -width => 25,
        -text  => "Italic Replace Character"
    )->pack( -side => 'left' );
    my $italic_entry = $italic_frame->Entry(
        -width        => 6,
        -background   => 'white',
        -relief       => 'sunken',
        -textvariable => \$italic_char,
    )->pack( -side => 'left' );

    my $bold_frame = $options->add('Frame')
        ->pack( -side => 'top', -padx => 5, -pady => 3 );
    my $bold_label = $bold_frame->Label(
        -width => 25,
        -text  => "Bold Replace Character"
    )->pack( -side => 'left' );
    my $bold_entry = $bold_frame->Entry(
        -width        => 6,
        -background   => 'white',
        -relief       => 'sunken',
        -textvariable => \$bold_char,
    )->pack( -side => 'left' );
    $options->Show;
    saveset();
}

### External
sub externalpopup {    # Set up the external commands menu
    my $menutempvar;
    if ( $lglobal{xtpop} ) {
        $lglobal{xtpop}->deiconify;
    }
    else {
        $lglobal{xtpop} = $top->Toplevel( -title => 'External programs', );
        my $f0
            = $lglobal{xtpop}->Frame->pack( -side => 'top', -anchor => 'n' );
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
                . '(So, to pass the currently open file, use $d$f$e.)'
                . "\n\n"
                . "\$i = the directory with full path that the png files are in.\n"
                . "\$p = the number of the page that the cursor is currently in.\n"
        )->pack;
        my $f1
            = $lglobal{xtpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        for $menutempvar ( 0 .. 9 ) {
            $f1->Entry(
                -width        => 50,
                -background   => 'white',
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
                -background   => 'white',
                -relief       => 'sunken',
                -textvariable => \$extops[$menutempvar]{command},
                )->grid(
                -row    => "$menutempvar" + 1,
                -column => 2,
                -padx   => 2,
                -pady   => 4
                );
        }
        my $f2
            = $lglobal{xtpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $gobut = $f2->Button(
            -activebackground => $activecolor,
            -command          => sub {
                saveset();
                rebuildmenu();
                $lglobal{xtpop}->destroy;
                undef $lglobal{xtpop};
            },
            -text  => 'OK',
            -width => 8
        )->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        $lglobal{xtpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{xtpop}->destroy; undef $lglobal{xtpop} } );
        $lglobal{xtpop}->Icon( -image => $icon );
    }
}

sub xtops {    # run an external program through the external commands menu
    my $index = shift;
    return unless $extops[$index]{command};
    runner( cmdinterp( $extops[$index]{command} ) );
}

### Unicode

sub utfpopup {
    $top->Busy( -recurse => 1 );
    my ( $block, $start, $end ) = @_;
    my $utfpop = $top->Toplevel;
    $utfpop->geometry('600x300+10+10');
    my $blln = $utfpop->Balloon( -initwait => 750 );
    my ( $frame, $pframe, $sizelabel, @buttons );
    my $rows = ( ( hex $end ) - ( hex $start ) + 1 ) / 16 - 1;
    $utfpop->title( $block . ': ' . $start . ' - ' . $end );
    my $cframe   = $utfpop->Frame->pack;
    my $fontlist = $cframe->BrowseEntry(
        -label     => 'Font',
        -browsecmd => sub {
            utffontinit();
            for (@buttons) {
                $_->configure( -font => $lglobal{utffont} );
            }
        },
        -variable => \$utffontname,
    )->grid( -row => 1, -column => 1, -padx => 8, -pady => 2 );
    my $bigger = $cframe->Button(
        -activebackground => $activecolor,
        -text             => 'Bigger',
        -command          => sub {
            $utffontsize++;
            utffontinit();
            for (@buttons) {
                $_->configure( -font => $lglobal{utffont} );
            }
            $sizelabel->configure( -text => $utffontsize );
        },
    )->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
    $sizelabel = $cframe->Label( -text => $utffontsize )
        ->grid( -row => 1, -column => 3, -padx => 2, -pady => 2 );
    my $smaller = $cframe->Button(
        -activebackground => $activecolor,
        -text             => 'Smaller',
        -command          => sub {
            $utffontsize--;
            utffontinit();
            for (@buttons) {
                $_->configure( -font => $lglobal{utffont} );
            }
            $sizelabel->configure( -text => $utffontsize );
        },
    )->grid( -row => 1, -column => 4, -padx => 2, -pady => 2 );
    my $usel = $cframe->Radiobutton(
        -variable    => \$lglobal{uoutp},
        -selectcolor => $lglobal{checkcolor},
        -value       => 'u',
        -text        => 'Unicode',
    )->grid( -row => 1, -column => 5, -padx => 5 );
    $cframe->Radiobutton(
        -variable    => \$lglobal{uoutp},
        -selectcolor => $lglobal{checkcolor},
        -value       => 'h',
        -text        => 'HTML code',
    )->grid( -row => 1, -column => 6 );
    $usel->select;
    $fontlist->insert( 'end', sort( $textwindow->fontFamilies ) );
    $pframe = $utfpop->Frame( -background => 'white' )
        ->pack( -expand => 'y', -fill => 'both' );
    $frame = $pframe->Scrolled(
        'Pane',
        -background => 'white',
        -scrollbars => 'se',
        -sticky     => 'nswe'
    )->pack( -expand => 'y', -fill => 'both' );
    drag($frame);
    for my $y ( 0 .. $rows ) {

        for my $x ( 0 .. 15 ) {
            my $name = hex($start) + ( $y * 16 ) + $x;
            my $hex   = sprintf "%04X", $name;
            my $msg   = "Dec. $name, Hex. $hex";
            my $cname = charnames::viacode($name);
            $msg .= ", $cname" if $cname;
            $name = 0 unless $cname;

            # FIXME: See Todo
            $buttons[ ( $y * 16 ) + $x ] = $frame->Button(

                #    $buttons( ( $y * 16 ) + $x ) = $frame->Button(
                -activebackground   => $activecolor,
                -text               => chr($name),
                -font               => $lglobal{utffont},
                -relief             => 'flat',
                -borderwidth        => 0,
                -background         => 'white',
                -command            => [ \&pututf, $utfpop ],
                -highlightthickness => 0,
            )->grid( -row => $y, -column => $x );
            $buttons[ ( $y * 16 ) + $x ]->bind(
                '<ButtonPress-3>',
                sub {
                    $textwindow->clipboardClear;
                    $textwindow->clipboardAppend(
                        $buttons[ ( $y * 16 ) + $x ]->cget('-text') );
                }
            );
            $blln->attach( $buttons[ ( $y * 16 ) + $x ],
                -balloonmsg => $msg, );
            $utfpop->update;
        }
    }
    $utfpop->protocol(
        'WM_DELETE_WINDOW' => sub { $blln->destroy; $utfpop->destroy; } );
    $utfpop->Icon( -image => $icon );
    $top->Unbusy( -recurse => 1 );
}

### Prefs

sub setmargins {
    my $getmargins = $top->DialogBox(
        -title   => 'Set margins for rewrap.',
        -buttons => ['OK'],
    );
    my $lmframe = $getmargins->add('Frame')
        ->pack( -side => 'top', -padx => 5, -pady => 3 );
    my $lmlabel = $lmframe->Label(
        -width => 25,
        -text  => 'Rewrap Left Margin',
    )->pack( -side => 'left' );
    my $lmentry = $lmframe->Entry(
        -width        => 6,
        -background   => 'white',
        -relief       => 'sunken',
        -textvariable => \$lmargin,
    )->pack( -side => 'left' );
    my $rmframe = $getmargins->add('Frame')
        ->pack( -side => 'top', -padx => 5, -pady => 3 );
    my $rmlabel = $rmframe->Label(
        -width => 25,
        -text  => 'Rewrap Right Margin',
    )->pack( -side => 'left' );
    my $rmentry = $rmframe->Entry(
        -width        => 6,
        -background   => 'white',
        -relief       => 'sunken',
        -textvariable => \$rmargin,
    )->pack( -side => 'left' );
    my $blmframe = $getmargins->add('Frame')
        ->pack( -side => 'top', -padx => 5, -pady => 3 );
    my $blmlabel = $blmframe->Label(
        -width => 25,
        -text  => 'Block Rewrap Left Margin',
    )->pack( -side => 'left' );
    my $blmentry = $blmframe->Entry(
        -width        => 6,
        -background   => 'white',
        -relief       => 'sunken',
        -textvariable => \$blocklmargin,
    )->pack( -side => 'left' );
    my $brmframe = $getmargins->add('Frame')
        ->pack( -side => 'top', -padx => 5, -pady => 3 );
    my $brmlabel = $brmframe->Label(
        -width => 25,
        -text  => 'Block Rewrap Right Margin',
    )->pack( -side => 'left' );
    my $brmentry = $brmframe->Entry(
        -width        => 6,
        -background   => 'white',
        -relief       => 'sunken',
        -textvariable => \$blockrmargin,
    )->pack( -side => 'left' );
    my $didntframe = $getmargins->add('Frame')
        ->pack( -side => 'top', -padx => 5, -pady => 3 );
    my $didntlabel = $didntframe->Label(
        -width => 25,
        -text  => 'Default Indent for /*  */ Blocks',
    )->pack( -side => 'left' );
    my $didntmentry = $didntframe->Entry(
        -width        => 6,
        -background   => 'white',
        -relief       => 'sunken',
        -textvariable => \$defaultindent,
    )->pack( -side => 'left' );
    $getmargins->Icon( -image => $icon );
    $getmargins->Show;

    if (   ( $blockrmargin eq '' )
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
    if (   ( $blockrmargin =~ /[\D\.]/ )
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
    saveset();
}

sub fontsize {
    my $sizelabel;
    if ( defined( $lglobal{fspop} ) ) {
        $lglobal{fspop}->deiconify;
        $lglobal{fspop}->raise;
        $lglobal{fspop}->focus;
    }
    else {
        $lglobal{fspop} = $top->Toplevel;
        $lglobal{fspop}->title('Font');
        my $tframe   = $lglobal{fspop}->Frame->pack;
        my $fontlist = $tframe->BrowseEntry(
            -label     => 'Font',
            -browsecmd => sub {
                fontinit();
                $textwindow->configure( -font => $lglobal{font} );
            },
            -variable => \$fontname
        )->grid( -row => 1, -column => 1, -pady => 5 );
        $fontlist->insert( 'end', sort( $textwindow->fontFamilies ) );
        my $mframe        = $lglobal{fspop}->Frame->pack;
        my $smallerbutton = $mframe->Button(
            -activebackground => $activecolor,
            -command          => sub {
                $fontsize++;
                fontinit();
                $textwindow->configure( -font => $lglobal{font} );
                $sizelabel->configure( -text => $fontsize );
            },
            -text  => 'Bigger',
            -width => 10
        )->grid( -row => 1, -column => 1, -pady => 5 );
        $sizelabel = $mframe->Label( -text => $fontsize )
            ->grid( -row => 1, -column => 2, -pady => 5 );
        my $biggerbutton = $mframe->Button(
            -activebackground => $activecolor,
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
            -selectcolor => $activecolor,
            -command     => sub {
                fontinit();
                $textwindow->configure( -font => $lglobal{font} );
            },
            -text => 'Bold'
        )->grid( -row => 2, -column => 2, -pady => 5 );
        my $button_ok = $mframe->Button(
            -activebackground => $activecolor,
            -text             => 'OK',
            -command          => sub {
                $lglobal{fspop}->destroy;
                undef $lglobal{fspop};
                saveset();
            }
        )->grid( -row => 3, -column => 2, -pady => 5 );
        $lglobal{fspop}->resizable( 'no', 'no' );
        $lglobal{fspop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{fspop}->destroy; undef $lglobal{fspop} } );
        $lglobal{fspop}->Icon( -image => $icon );
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
    my $browserentry = $browsepop->Entry(
        -width        => 60,
        -background   => 'white',
        -textvariable => $globalbrowserstart,
    )->grid( -row => 1, -column => 1, -columnspan => 2, -pady => 3 );
    my $button_ok = $browsepop->Button(
        -activebackground => $activecolor,
        -text             => 'OK',
        -width            => 6,
        -command          => sub {
            $globalbrowserstart = $browserentry->get;
            saveset();
            $browsepop->destroy;
            undef $browsepop;
        }
    )->grid( -row => 2, -column => 1, -pady => 8 );
    my $button_cancel = $browsepop->Button(
        -activebackground => $activecolor,
        -text             => 'Cancel',
        -width            => 6,
        -command          => sub {
            $browsepop->destroy;
            undef $browsepop;
        }
    )->grid( -row => 2, -column => 2, -pady => 8 );
    $browsepop->protocol(
        'WM_DELETE_WINDOW' => sub { $browsepop->destroy; undef $browsepop; }
    );
    $browsepop->Icon( -image => $icon );
}

sub viewerpath {    #Find your image viewer
    my $types;
    if (OS_Win) {
        $types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
    }
    else {
        $types = [ [ 'All Files', ['*'] ] ];
    }
    $lglobal{pathtemp} = $textwindow->getOpenFile(
        -filetypes  => $types,
        -title      => 'Where is your image viewer?',
        -initialdir => dirname($globalviewerpath)
    );
    $globalviewerpath = $lglobal{pathtemp} if $lglobal{pathtemp};
    $globalviewerpath = os_normal($globalviewerpath);
    saveset();
}

sub setpngspath {
    my $path = $textwindow->chooseDirectory(
        -title      => 'Choose the image file directory.',
        -initialdir => "$globallastpath" . "pngs",
    );
    return unless defined $path and -e $path;
    $path .= '/';
    $path     = os_normal($path);
    $pngspath = $path;
    openpng();
}

sub toolbar_toggle {    # Set up / remove the tool bar
    if ( $notoolbar && $lglobal{toptool} ) {
        $lglobal{toptool}->destroy;
        undef $lglobal{toptool};
    }
    elsif ( !$notoolbar && !$lglobal{toptool} ) {

# FIXME: if Tk::ToolBar isn't available, show a message and disable
# the toolbar
# if ( !$lglobal{ToolBar} ) {
#     my $dbox = $top->Dialog(
#         -text =>
#             'Tk::ToolBar package not found, unable to create Toolbar. The toolbar will be disabled.',
#         -title   => 'Unable to create Toolbar.',
#         -buttons => ['OK']
#     );
#     $dbox->Show;

        #     # disable toolbar in settings
        #     $notoolbar = 1;
        #     saveset();
        #     return;
        #}

        $lglobal{toptool}
            = $top->ToolBar( -side => $toolside, -close => '30' );
        $lglobal{toolfont} = $top->Font(
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
        OS_Win
            ? ( $lglobal{spellexename} = dos_path($globalspellpath) )
            : ( $lglobal{spellexename} = $globalspellpath );
        aspellstart() unless $lglobal{spellpid};
    }
    my $dicts;
    my $dictlist;
    my $spellop = $top->DialogBox(
        -title   => 'Spellcheck Options',
        -buttons => ['Close']
    );
    my $spellpathlabel
        = $spellop->add( 'Label', -text => 'Aspell executable file?' )->pack;
    my $spellpathentry
        = $spellop->add( 'Entry', -width => 60, -background => 'white' )
        ->pack;
    my $spellpathbrowse = $spellop->add(
        'Button',
        -text    => 'Browse',
        -width   => 12,
        -command => sub {
            my $name
                = $spellop->getOpenFile( -title => 'Aspell executable?' );
            if ($name) {
                $globalspellpath = $name;
                $globalspellpath = os_normal($globalspellpath);
                $spellpathentry->delete( 0, 'end' );
                $spellpathentry->insert( 'end', $globalspellpath );
                saveset();

                OS_Win
                    ? ( $lglobal{spellexename} = dos_path($globalspellpath) )
                    : ( $lglobal{spellexename} = $globalspellpath );
                open my $infile, '-|', "$lglobal{spellexename} dump dicts"
                    or warn "Unable to access dictionaries. $!\n";
                while ( $dicts = <$infile> ) {
                    chomp $dicts;
                    next if ( $dicts =~ m/-/ );
                    $dictlist->insert( 'end', $dicts );
                }
                close $infile;
            }
        }
    )->pack( -pady => 4 );
    $spellpathentry->insert( 'end', $globalspellpath );

    my $spellencodinglabel = $spellop->add( 'Label',
        -text => 'Set encoding: default = iso8859-1' )->pack;

    my $spellencodingentry = $spellop->add(
        'Entry',
        -width        => 30,
        -textvariable => \$lglobal{spellencoding},
    )->pack;

# FIXME: Switching to utf-8 is barfola. Probably down in the checkfil.txt thingy.

    my $dictlabel
        = $spellop->add( 'Label', -text => 'Dictionary files' )->pack;
    $dictlist = $spellop->add(
        'ScrlListbox',
        -scrollbars => 'oe',
        -selectmode => 'browse',
        -background => 'white',
        -height     => 10,
        -width      => 40,
    )->pack( -pady => 4 );
    my $spelldiclabel
        = $spellop->add( 'Label', -text => 'Current Dictionary (ies)' )->pack;
    my $spelldictxt = $spellop->add(
        'ROText',
        -width      => 40,
        -height     => 1,
        -background => 'white'
    )->pack;
    $spelldictxt->delete( '1.0', 'end' );
    $spelldictxt->insert( '1.0', $globalspelldictopt );
    $dictlist->insert( 'end', "<default>" );

    if ($globalspellpath) {
        OS_Win
            ? ( $lglobal{spellexename} = dos_path($globalspellpath) )
            : ( $lglobal{spellexename} = $globalspellpath );
        open my $infile, '-|', "$lglobal{spellexename} dump dicts"
            or warn "Unable to access dictionaries. $!\n";
        while ( $dicts = <$infile> ) {
            chomp $dicts;
            next if ( $dicts =~ m/-/ );
            $dictlist->insert( 'end', $dicts );
        }
        close $infile;
    }
    $dictlist->eventAdd( '<<dictsel>>' => '<Double-Button-1>' );
    $dictlist->bind(
        '<<dictsel>>',
        sub {
            my $selection = $dictlist->get('active');
            $spelldictxt->delete( '1.0', 'end' );
            $spelldictxt->insert( '1.0', $selection );
            $selection = '' if $selection eq "<default>";
            $globalspelldictopt = $selection;
            saveset();
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
    }
    else {
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
    }
    else {
        $lglobal{intervalpop} = $top->Toplevel;
        $lglobal{intervalpop}->title('Autosave Interval');
        $lglobal{intervalpop}->resizable( 'no', 'no' );
        my $frame = $lglobal{intervalpop}
            ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        $frame->Label( -text => 'Minutes between Autosave' )
            ->pack( -side => 'left' );
        my $entry = $frame->Entry(
            -background   => 'white',
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
        my $frame1 = $lglobal{intervalpop}
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
        $lglobal{intervalpop}->Icon( -image => $icon );
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
            flash_save()
                if $lglobal{global_filename} !~ /No File Loaded/;
        }
    );
    $lglobal{savetool}
        ->configure( -background => 'green', -activebackground => 'green' )
        unless $notoolbar;
    $lglobal{autosaveinterval} = time;
}

sub hilitetgl {    # Enable / disable word highlighting in the text
    if ( $lglobal{scanno_hl} ) {
        $lglobal{hl_index} = 1;
        highlightscannos();
        $lglobal{scanno_hlid} = $top->repeat( 400, \&highlightscannos );
    }
    else {
        $lglobal{scanno_hlid}->cancel if $lglobal{scanno_hlid};
        undef $lglobal{scanno_hlid};
        $textwindow->tagRemove( 'scannos', '1.0', 'end' );
    }
    update_indicators();
    saveset();
}

sub searchsize
{    # Pop up a window where you can adjust the search history size
    if ( $lglobal{hssizepop} ) {
        $lglobal{hssizepop}->deiconify;
        $lglobal{hssizepop}->raise;
    }
    else {
        $lglobal{hssizepop} = $top->Toplevel;
        $lglobal{hssizepop}->title('History Size');
        $lglobal{hssizepop}->resizable( 'no', 'no' );
        my $frame = $lglobal{hssizepop}
            ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        $frame->Label( -text => 'History Size: # of terms to save - ' )
            ->pack( -side => 'left' );
        my $entry = $frame->Entry(
            -background   => 'white',
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
        my $frame2 = $lglobal{hssizepop}
            ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        $frame2->Button(
            -text    => 'Ok',
            -width   => 10,
            -command => sub {
                saveset();
                $lglobal{hssizepop}->destroy;
                undef $lglobal{hssizepop};
            }
        )->pack;
        $lglobal{hssizepop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{hssizepop}->destroy;
                undef $lglobal{hssizepop};
            }
        );
        $lglobal{hssizepop}->Icon( -image => $icon );
    }
}

### Help
# FIXME: generalize about, version, etc. into one function.
sub about_pop_up {
    my $about_text = <<EOM;
Guiguts.pl post processing toolkit/interface to gutcheck.

Provides easy to use interface to gutcheck and an array of
other useful postprocessing functions.

This version produced by a number of volunteers.
See the Thanks.txt file for details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

Original guiguts written by Stephen Schulze.
Partially based on the Gedi editor - Gregs editor.
Copyright 1999, 2003 - Greg London
EOM

    if ( defined( $lglobal{aboutpop} ) ) {
        $lglobal{aboutpop}->deiconify;
        $lglobal{aboutpop}->raise;
        $lglobal{aboutpop}->focus;
    }
    else {
        $lglobal{aboutpop} = $top->Toplevel;
        $lglobal{aboutpop}->title('About');
        $lglobal{aboutpop}->Label(
            -justify => "left",
            -text    => $about_text
        )->pack;
        my $button_ok = $lglobal{aboutpop}->Button(
            -activebackground => $activecolor,
            -text             => 'OK',
            -command =>
                sub { $lglobal{aboutpop}->destroy; undef $lglobal{aboutpop} }
        )->pack( -pady => 6 );
        $lglobal{aboutpop}->resizable( 'no', 'no' );
        $lglobal{aboutpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{aboutpop}->destroy; undef $lglobal{aboutpop} }
        );
        $lglobal{aboutpop}->Icon( -image => $icon );
    }
}

sub showversion {
    my ($top) = @_;
    my $os = $^O;
    $os =~ s/^([^\[]+)\[.+/$1/;
    my $winver = "\n";
    if (OS_Win) {
        $winver = `ver`;
        $winver =~ s/([\s\w]* Windows \w+) .*/$1/;
    }
    my $dialog = $top->Dialog(
        -title   => 'Versions',
        -popover => $top,
        -text    => "Currently Running :\n"
            . "$0\nVersion : $currentver\n"
            . "Platform : $os"
            . $winver
            . ( sprintf "Perl v%vd\n", $^V )
            . "perl/Tk Version : $Tk::VERSION\n"
            . "Tk patchLevel : $Tk::patchLevel\n"
            . "Tk libraries : $Tk::library\n",
        -justify => 'center'
    );
    $dialog->Show;
}

# Check to see if this is the most recent version
# FIXME: Doesn't work.
# sub checkver {
#     my ( $dbox, $answer );
#     my $ua = LWP::UserAgent->new(
#         env_proxy  => 1,
#         keep_alive => 1,
#         timeout    => 30,
#     );
#     my $response = $ua->get('http://guiguts.sourceforge.net/ggversion.txt');
#     unless ( $response->content ) {
#         $dbox = $top->Dialog(
#             -text =>
#                 'Could not check for updates, unable to connect to server.',
#             -bitmap  => 'error',
#             -title   => 'Could not connect.',
#             -buttons => ['Ok']
#         );
#         $dbox->Show;
#         return;
#     }
#     if ( $response->content gt $currentver ) {
#         print $response->content;
#         $dbox = $top->Dialog(
#             -text =>
#                 "A newer version is available.\nDo you want to go to the home page?",
#             -title   => 'Newer version available.',
#             -buttons => [ 'Ok', 'Cancel' ]
#         );
#     }
#     else {
#         $dbox = $top->Dialog(
#             -text    => 'This is the most current version.',
#             -title   => 'Up to date.',
#             -buttons => ['Cancel']
#         );
#     }
#     $answer = $dbox->Show;
#     if ( $answer =~ /ok/i ) {
#         runner("$globalbrowserstart http://guiguts.sourceforge.net/");
#     }
# }

sub hotkeyshelp {
    if ( defined( $lglobal{hotpop} ) ) {
        $lglobal{hotpop}->deiconify;
        $lglobal{hotpop}->raise;
        $lglobal{hotpop}->focus;
    }
    else {
        $lglobal{hotpop} = $top->Toplevel;
        $lglobal{hotpop}->title('Hot key combinations');
        my $frame = $lglobal{hotpop}->Frame->pack(
            -anchor => 'nw',
            -expand => 'yes',
            -fill   => 'both'
        );
        my $rotextbox = $frame->Scrolled(
            'ROText',
            -scrollbars => 'se',
            -background => 'white',
            -font       => '{Helvetica} 10',
            -width      => 80,
            -height     => 25,
            -wrap       => 'none',
        )->pack( -anchor => 'nw', -expand => 'yes', -fill => 'both' );
        drag($rotextbox);
        $rotextbox->focus;
        $rotextbox->insert(    #FIXME: Make this a here doc.
            'end',
                  "\nMAIN WINDOW\n\n"
                . "<ctrl>+x -- cut or column cut\n"
                . "<ctrl>+c -- copy or column copy\n"
                . "<ctrl>+v -- paste\n"
                . "<ctrl>+` -- column paste\n"
                . "<ctrl>+a -- select all\n\n"
                .

                "F1 -- column copy\n"
                . "F2 -- column cut\n"
                . "F3 -- column paste\n\n"
                .

                "F7 -- spell check selection (or document, if no selection made)\n\n"
                .

                "<ctrl>+z -- undo\n" . "<ctrl>+y -- redo\n\n" .

                "<ctrl>+/ -- select all\n"
                . "<ctrl>+\\ -- unselect all\n"
                . "<Esc> -- unselect all\n\n"
                .

                "<ctrl>+u -- Convert case of selection to upper case\n"
                . "<ctrl>+l -- Convert case of selection to lower case\n"
                . "<ctrl>+t -- Convert case of selection to title case\n\n"
                .

                "<ctrl>+i -- insert a tab character before cursor (Tab)\n"
                . "<ctrl>+j -- insert a newline character before cursor (Enter)\n"
                . "<ctrl>+o -- insert a newline character after cursor\n\n"
                .

                "<ctrl>+d -- delete character after cursor (Delete)\n"
                . "<ctrl>+h -- delete character to the left of the cursor (Backspace)\n"
                . "<ctrl>+k -- delete from cursor to end of line\n\n"
                .

                "<ctrl>+e -- move cursor to end of current line. (End)\n"
                . "<ctrl>+b -- move cursor left one character (left arrow)\n"
                . "<ctrl>+p -- move cursor up one line (up arrow)\n"
                . "<ctrl>+n -- move cursor down one line (down arrow)\n\n"
                .

                "<ctrl>Home -- move cursor to the start of the text\n"
                . "<ctrl>End -- move cursor to end of the text\n"
                . "<ctrl>+right arrow -- move to the start of the next word\n"
                . "<ctrl>+left arrow -- move to the start of the previous word\n"
                . "<ctrl>+up arrow -- move to the start of the current paragraph\n"
                . "<ctrl>+down arrow -- move to the start of the next paragraph\n"
                . "<ctrl>+PgUp -- scroll left one screen\n\n"
                . "<ctrl>+PgDn -- scroll right one screen\n\n"
                .

                "<shift>+Home -- adjust selection to beginning of current line\n"
                . "<shift>+End -- adjust selection to end of current line\n"
                . "<shift>+up arrow -- adjust selection up one line\n"
                . "<shift>+down arrow -- adjust selection down one line\n"
                . "<shift>+left arrow -- adjust selection left one character\n"
                . "<shift>+right arrow -- adjust selection right one character\n\n"
                .

                "<shift><ctrl>Home -- adjust selection to the start of the text\n"
                . "<shift><ctrl>End -- adjust selection to end of the text\n"
                . "<shift><ctrl>+left arrow -- adjust selection to the start of the previous word\n"
                . "<shift><ctrl>+right arrow -- adjust selection to the start of the next word\n"
                . "<shift><ctrl>+up arrow -- adjust selection to the start of the current paragraph\n"
                . "<shift><ctrl>+down arrow -- adjust selection to the start of the next paragraph\n\n"
                .

                "<ctrl>+' -- highlight all apostrophes in selection.\n"
                . "<ctrl>+\" -- highlight all double quotes in selection.\n"
                . "<ctrl>+0 -- remove all highlights.\n\n"
                .

                "<Insert> -- Toggle insert / overstrike mode\n\n" .

                "Double click left mouse button -- select word\n"
                . "Triple click left mouse button -- select line\n\n"
                .

                "<shift> click left mouse button -- adjust selection to click point\n"
                . "<shift> Double click left mouse button -- adjust selection to include word clicked on\n"
                . "<shift> Triple click left mouse button -- adjust selection to include line clicked on\n"
                .

                "Single click right mouse button -- pop up shortcut to menu bar\n\n"
                .

                "BOOKMARKS\n\n"
                . "<ctrl>+<shift>+1 -- set bookmark 1\n"
                . "<ctrl>+<shift>+2 -- set bookmark 1\n"
                . "<ctrl>+<shift>+3 -- set bookmark 3\n"
                . "<ctrl>+<shift>+4 -- set bookmark 4\n"
                . "<ctrl>+<shift>+5 -- set bookmark 5\n\n"
                .

                "<ctrl>+1 -- go to bookmark 1\n"
                . "<ctrl>+2 -- go to bookmark 2\n"
                . "<ctrl>+3 -- go to bookmark 3\n"
                . "<ctrl>+4 -- go to bookmark 4\n"
                . "<ctrl>+5 -- go to bookmark 5\n\n"
                .

                "MENUS\n\n"
                . "<alt>+f -- file menu\n"
                . "<alt>+e -- edit menu\n"
                . "<alt>+b -- bookmarks\n"
                . "<alt>+s -- search menu\n"
                . "<alt>+g -- gutcheck menu\n"
                . "<alt>+x -- fixup menu\n"
                . "<alt>+w -- word frequency menu\n\n"
                .

                "\nSEARCH POPUP\n\n"
                . "<Enter> -- Search\n"
                . "<shift><Enter> -- Replace\n"
                . "<ctrl><Enter> -- Replace & Search\n"
                . "<ctrl><shift><Enter> -- Replace All\n"
                . "\nPAGE SEPARATOR POPUP\n\n"
                . "'j' -- Join Lines - join lines, remove all blank lines, spaces, asterisks and hyphens.\n"
                . "'k' -- Join, Keep Hyphen - join lines, remove all blank lines, spaces and asterisks, keep hyphen.\n"
                . "'l' -- Blank Line - leave one blank line. Close up any other whitespace. (Paragraph Break)\n"
                . "'t' -- New Section - leave two blank lines. Close up any other whitespace. (Section Break)\n"
                . "'h' -- New Chapter - leave four blank lines. Close up any other whitespace. (Chapter Break)\n"
                . "'r' -- Refresh - search for, highlight and re-center the next page separator.\n"
                . "'u' -- Undo - undo the last edit. (Note: in Full Automatic mode,\n\tthis just single steps back through the undo buffer)\n"
                . "'d' -- Delete - delete the page separator. Make no other edits.\n"
                . "'v' -- View the current page in the image viewer.\n"
                . "'a' -- Toggle Full Automatic mode.\n"
                . "'s' -- Toggle Semi Automatic mode.\n" . "\n"
        );
        my $button_ok = $frame->Button(
            -activebackground => $activecolor,
            -text             => 'OK',
            -command =>
                sub { $lglobal{hotpop}->destroy; undef $lglobal{hotpop} }
        )->pack( -pady => 8 );
        $lglobal{hotpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{hotpop}->destroy; undef $lglobal{hotpop} } );
        $lglobal{hotpop}->Icon( -image => $icon );
    }
}

# Pop up an "Operation" history. Track which functions have already been
# run.
sub opspop_up {
    if ( $lglobal{oppop} ) {
        $lglobal{oppop}->deiconify;
        $lglobal{oppop}->raise;
    }
    else {
        $lglobal{oppop} = $top->Toplevel;
        $lglobal{oppop}->title('Function history');
        $lglobal{oppop}->geometry($geometry2) if $geometry2;
        my $frame = $lglobal{oppop}->Frame->pack(
            -anchor => 'nw',
            -fill   => 'both',
            -expand => 'both',
            -padx   => 2,
            -pady   => 2
        );
        $lglobal{oplistbox} = $frame->Scrolled(
            'Listbox',
            -scrollbars  => 'se',
            -background  => 'white',
            -selectmode  => 'single',
            -activestyle => 'none',
            )->pack(
            -anchor => 'nw',
            -fill   => 'both',
            -expand => 'both',
            -padx   => 2,
            -pady   => 2
            );
        drag( $lglobal{oplistbox} );
        $lglobal{oppop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{oppop}->destroy; undef $lglobal{oppop} } );
        $lglobal{oppop}->Icon( -image => $icon );
    }
    oppopupdate();
    $lglobal{oppop}->bind(
        '<Configure>' => sub {
            $lglobal{oppop}->XEvent;
            $geometry2 = $lglobal{oppop}->geometry;
            $lglobal{geometryupdate} = 1;
        }
    );
}

sub greekpopup {
    my $buildlabel;
    my %attributes;
    if ( defined( $lglobal{grpop} ) ) {
        $lglobal{grpop}->deiconify;
        $lglobal{grpop}->raise;
        $lglobal{grpop}->focus;
    }
    else {
        my @greek = (
            [ 'a',    'calpha',   'lalpha',   'chalpha',   'halpha' ],
            [ 'b',    'cbeta',    'lbeta',    '',          '' ],
            [ 'g',    'cgamma',   'lgamma',   'ng',        '' ],
            [ 'd',    'cdelta',   'ldelta',   '',          '' ],
            [ 'e',    'cepsilon', 'lepsilon', 'chepsilon', 'hepsilon' ],
            [ 'z',    'czeta',    'lzeta',    '',          '' ],
            [ 'Í',    'ceta',     'leta',     'cheta',     'heta' ],
            [ 'th',   'ctheta',   'ltheta',   '',          '' ],
            [ 'i',    'ciota',    'liota',    'chiota',    'hiota' ],
            [ 'k',    'ckappa',   'lkappa',   'nk',        '' ],
            [ 'l',    'clambda',  'llambda',  '',          '' ],
            [ 'm',    'cmu',      'lmu',      '',          '' ],
            [ 'n',    'cnu',      'lnu',      '',          '' ],
            [ 'x',    'cxi',      'lxi',      'nx',        '' ],
            [ 'o',    'comicron', 'lomicron', 'chomicron', 'homicron' ],
            [ 'p',    'cpi',      'lpi',      '',          '' ],
            [ 'r',    'crho',     'lrho',     'hrho',      '' ],
            [ 's',    'csigma',   'lsigma',   'lsigmae',   '' ],
            [ 't',    'ctau',     'ltau',     '',          '' ],
            [ '(yu)', 'cupsilon', 'lupsilon', 'chupsilon', 'hupsilon' ],
            [ 'ph',   'cphi',     'lphi',     '',          '' ],
            [ 'ch',   'cchi',     'lchi',     'nch',       '' ],
            [ 'ps',   'cpsi',     'lpsi',     '',          '' ],
            [ 'Ù',    'comega',   'lomega',   'chomega',   'homega' ],
            [ 'st',   'cstigma',  'lstigma',  '',          '' ],
            [ '6',    'cdigamma', 'ldigamma', '',          '' ],
            [ '90',   'ckoppa',   'lkoppa',   '',          '' ],
            [ '900',  'csampi',   'lsampi',   '',          '' ]
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
            'ng' =>
                [ 'ng', 'gamma gamma', '&#947;&#947;', "\x{03B3}\x{03B3}" ],
            'cdelta'    => [ 'D',  'Delta',   '&#916;',  "\x{0394}" ],
            'ldelta'    => [ 'd',  'delta',   '&#948;',  "\x{03B4}" ],
            'cepsilon'  => [ 'E',  'Epsilon', '&#917;',  "\x{0395}" ],
            'lepsilon'  => [ 'e',  'epsilon', '&#949;',  "\x{03B5}" ],
            'chepsilon' => [ 'He', 'Epsilon', '&#7961;', "\x{1F19}" ],
            'hepsilon'  => [ 'he', 'epsilon', '&#7953;', "\x{1F11}" ],
            'czeta'     => [ 'Z',  'Zeta',    '&#918;',  "\x{0396}" ],
            'lzeta'     => [ 'z',  'zeta',    '&#950;',  "\x{03B6}" ],
            'ceta'      => [ ' ',  'Eta',     '&#919;',  "\x{0397}" ],
            'leta'      => [ 'Í',  'eta',     '&#951;',  "\x{03B7}" ],
            'cheta'     => [ 'HÍ', 'Eta',     '&#7977;', "\x{1F29}" ],
            'heta'      => [ 'hÍ', 'eta',     '&#7969;', "\x{1F21}" ],
            'ctheta'    => [ 'Th', 'Theta',   '&#920;',  "\x{0398}" ],
            'ltheta'    => [ 'th', 'theta',   '&#952;',  "\x{03B8}" ],
            'ciota'     => [ 'I',  'Iota',    '&#921;',  "\x{0399}" ],
            'liota'     => [ 'i',  'iota',    '&#953;',  "\x{03B9}" ],
            'chiota'    => [ 'Hi', 'Iota',    '&#7993;', "\x{1F39}" ],
            'hiota'     => [ 'hi', 'iota',    '&#7985;', "\x{1F31}" ],
            'ckappa'    => [ 'K',  'Kappa',   '&#922;',  "\x{039A}" ],
            'lkappa'    => [ 'k',  'kappa',   '&#954;',  "\x{03BA}" ],
            'nk' =>
                [ 'nk', 'gamma kappa', '&#947;&#954;', "\x{03B3}\x{03BA}" ],
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
            'nch' =>
                [ 'nch', 'gamma chi', '&#947;&#967;', "\x{03B3}\x{03C7}" ],
            'cpsi'     => [ 'Ps', 'Psi',     '&#936;',  "\x{03A8}" ],
            'lpsi'     => [ 'ps', 'psi',     '&#968;',  "\x{03C8}" ],
            'comega'   => [ '‘',  'Omega',   '&#937;',  "\x{03A9}" ],
            'lomega'   => [ 'Ù',  'omega',   '&#969;',  "\x{03C9}" ],
            'chomega'  => [ 'HÙ', 'Omega',   '&#8041;', "\x{1F69}" ],
            'homega'   => [ 'hÙ', 'omega',   '&#8033;', "\x{1F61}" ],
            'cstigma'  => [ 'St', 'Stigma',  '&#986;',  "\x{03DA}" ],
            'lstigma'  => [ 'st', 'stigma',  '&#987;',  "\x{03DB}" ],
            'cdigamma' => [ '6',  'Digamma', '&#988;',  "\x{03DC}" ],
            'ldigamma' => [ '6',  'digamma', '&#989;',  "\x{03DD}" ],
            'ckoppa'   => [ '9',  'Koppa',   '&#990;',  "\x{03DE}" ],
            'lkoppa'   => [ '9',  'koppa',   '&#991;',  "\x{03DF}" ],
            'csampi'   => [ '9',  'Sampi',   '&#992;',  "\x{03E0}" ],
            'lsampi'   => [ '9',  'sampi',   '&#993;',  "\x{03E1}" ],
            'oulig' => [ 'ou', 'oulig', '&#959;&#965;', "\x{03BF}\x{03C5}" ]
        );
        my $grfont = '{Times} 14';

        my %grkgifs;

        $grkgifs{calpha} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJGRmZKSqpOTq5BQSFFRWVDQyNHR2dLS6tPz+/AD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGZgAADcAAD8AAB3AJjAAKRmABL4AAB3
                AGweMKQCpxJ4EgABAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJhAAAAAABsAAAAAABwAAAAADBoAOMAABRhAAAAAHAuABYAAPhiAHcAAP9tMP8A4/9wFP8AAHwA
                MKIA4xIAFAAAAK0AADkAAOkAAHcAAAAAAAAA4BMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYw
                cwDjcgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiEABsIHEiwoMGDCBMqXMiwoUOBBgg8PEgAAIOJBAdUTIBxoIABCgAc6HhAogEACzoWMCAQAYKO
                EgUuAMDyYYAAAw8AEDBRQUEBIh0aKFCQAQCiDUMCWMoUwEuGA3gaBFpTYYKLBo36VKgxYUWsBwcg
                kHowJAKwBAM0xZmx6c6OcOPKlRsQADs=
                ';

        $grkgifs{cbeta} = '
                R0lGODlhGAAYAPcAAAQCBISGhMTKxERCRCQiJKSqpOTq5FRWVBQSFJSWlNTa1DQyNLS6tPz+/GRm
                ZAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOhDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABhlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJiAAAAAABlAAAAAAB0AAAAADBhAOMAABQuAAAAAHBiABYAAPhtAHcAAP9wMP8A4/8AFP8AAHwA
                MKIA4xIAFAAAAK0AADkAAOkAAHcAAAAAAAAA4BMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGP9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGAATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYw
                cwDjcgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WKKlpxJOEgAAAJw85vml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiBABsIHEiwoMGDCBMqXMiwoUIAECNCRDCggEMGEA0MZDAAwAKHEA06AOCgYUiDABCYBHDw5EKX
                AwsAOLCSoIIACBAoWCkR4gKNNTd2BBAgKEGZABIwhDkwAQACS1m2lPqQKkEDT6MePEB0IUYAAo4u
                IPmyZ0QCByw6XMu2rdu3AwMCADs=
                ';

        $grkgifs{cchi} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOlDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABdlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJjAAAAAABoAAAAAABpAAAAADAuAOMAABRiAAAAAHBtABYAAPhwAHcAAP8AMP8A4/8AFP8AAHwA
                MKIA4xIAFAAAAK0AADkAAOkAAHcAAAAAAAAA4BMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QF/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYw
                cwDjcgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0V6KlpxJOEgAAAJw85/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiQAB8IHEiwoMGDCBMqXMiwIcIBACJKFDBQgEQAFBEWQBCxQcEFABgMWLiAY4KCCRg4LBBxwcAB
                CA44fGAg5EACI2c+IAAgwAMFPnU+ANlTgdCBCSIeJcgx6FEHDji6FDqAYlKVQglU7KlTgUeBB6Q6
                NOCgIEsEUxMWYKC14IGICL4evAgg54MAdDMu3cu3r86AADs=
                ';

        $grkgifs{cdelta} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJGRmZKSqpOTq5BQSFJSWlFRWVDQyNHR2dPz+/AD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJkAAAAAABlAAAAAABsAAAAADB0AOMAABRhAAAAAHAuABYAAPhiAHcAAP9tMP8A4/9wFP8AAHwA
                MKIA4xIAFAAAAK0AADkAAOkAAHcAAAAAAAAA4BMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYw
                cwDjcgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiCABsIHEiwoMGDCBMqXMiwoUOBBQ48PAigwMSCAQAguEiQgAIAATg2MFBgAAACIglIFADAwMUB
                CgQaALDgooABAwkAwOnwgACCCQDEdFjAJUEEACQ2RFmQAQAGDQMkMHhA41KEBQBMVWgA6kGTTBOq
                TMjS6FcAaNOqTftTpNu3cDkGBAA7
                ';

        $grkgifs{cdigamma} = '
                R0lGODlhGAAYAPcAAAQCBKyyrPTy9NTW1FRSVLy+vGxqbLSytPz+/FxWXMTCxDw6PPT29NzW3FRW
                VLzCvHx6fLS2tGTKAF8aAGfaAAG2AICK1wFSKwA6QQCa/wCu1wAuFo56JwEGpQAW1wCaFq/yTFkq
                UNf6xivKFv/aABUGAACGAADGAABKjwAmFgDuLgCqdAwWAHPSAAluAlI2dACSAAGyAAB2jgAOAJ8e
                dtCOAABeAAA+AICyVqR+H3b2AAAuAM7+AOnOAEvexQAAFWYArwAAFwD/SwD/AJgAZaQCAHYPRAAo
                vGz3YqS/gHa2AQBRAPJoALJzAE4oAAAAANm3AP8BAP8AEP8AAAAXAABqAAAAGAABAO8AAOgAAEuf
                AADQwNgAO7AA0HYnEgBqACcAAAAAAAAnIwAcApiPAKSxAHb5AAC/AGwDRKQAdHbeAAB0AOQDjxwA
                FlTPSABAdH8AAAgAAPpGxb+XFfzur04TF/X34L+/u/9sYv+jgP92yv8AFf9Qr//wF/+az/+BFpcQ
                xgNSFgCfAACBAABzAACxAAD5dQC/AQgAzwAwFgB2ZAAAdOIOABOhAPf3AL+/AH8mBwGzAAD3AAC/
                AGQAh87wAfeadb+BAfcAAEEAAPcAAL8AABQAAFIAAJ8AAIEAAPp/ANoIAPf6AL+/AJDgAJRVAPxQ
                AL8AAJeUrwOjFwB2hwAAAUBWJwCrAAD4AAC/AIwI/6Lm/3YA/wCA/yQgJ9tcAPcAAL+AAFwg2Deq
                sKkAdoGAAECYAAAQAAABAACAABQAuFIBpJ8AdoEAABMQCAGqtQAAS8CAABTkmFIcpJ9UdoEAAEB/
                8wAIsgD6TgC/AJf8zANOpAD1dgC/AIC0f0ukCAN2+tIAv9Trb6O2p3b5dgC/AP0E1/Tw//dO/78A
                f/8MSP/wp/9Odv8AAIDc5ACbHAD8VAC/AAO0fwCjCAB2+gAAv0MA5DoBHFwAVGIAAG/gAG9VAGtQ
                AHMAAFwAr3IASXQAR2bQAFyMSHAIp3IAdmUAAHAcSFwsp3Q8dmXQACH5BAAAAAAALAAAAAAYABgA
                BwhrABEIHEiwoMGDCBMqXMiwocOHEB9GMOCAQAICGC8OcBgBwIICCkIGWKDAYQEABAoeKNlQAQAH
                EQmeTBlToEuYNRGcBMATAMuHNxEwoAlxps2YQXMazZk0ZgMIPAMIiDlAAUgFDHJq3cpVa0AAOw==
                ';

        $grkgifs{cepsilon} = '
                R0lGODlhGAAYAPcAAAQCBISGhMTKxOTq5CQiJLS6tJSWlNTa1Pz+/DQyNAASEwAAAAD/RQD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOVDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABtlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJlAAAAAABwAAAAAABzAAAAADBpAOMAABRsAAAAAHBvABYAAPhuAHcAAP8uMP8A4/9iFP8AAHxt
                MKIA4xJwFAAAAK0AADkAAOkAAHcAAAAAAAAA4BMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QG/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYw
                cwDjcgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0W6KlpxJOEgAAAJw84/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhiABEIHEiwoMGDCBMqXMiwoUIAECNKhNiwAEWCAxIAcHiRoEWOGw2GZNjRYcGSCEY2LBlAJcmJ
                KBeydCnTJc2HN03GNJnypoAEK28SMMDQIoADBA9oHFATZkSgPKNKnUqVYUAAOw==
                ';

        $grkgifs{ceta} = '
                R0lGODlhGAAYAPcAAAQCBLS6tPz+/AAAdwAAAAIAAAAAEwAAAAqweACjEwASEwAAAAD/RQD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOlDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABdlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJlAAAAAAB0AAAAAABhAAAAADAuAOMAABRiAAAAAHBtABYAAPhwAHcAAP8AMP8A4/8AFP8AAHwA
                MKIA4xIAFAAAAK0AADkAAOkAAHcAAAAAAAAA4BMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QF/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYw
                cwDjcgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0V6KlpxJOEgAAAJw85/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhiAAUIHEiwoMGDCBMqXMiwoUIAECMOjCgxYQCIAQpeBJBxIcSDHxmGLDjyIQCQJ0WmJLnSJMqG
                FGOWTDhTYM2XBm/mbDmRJ8KbOlni9OhTQNCBGzsixWiSYk+nDqNKnUq1akAAOw==
                ';

        $grkgifs{cgamma} = '
                R0lGODlhGAAYAPcAAAQCBKSqpOTq5DQyNLS6tPz+/AAAEwAAAAqweACjEwASEwAAAAD/RQD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJnAAAAAABhAAAAAABtAAAAADBtAOMAABRhAAAAAHAuABYAAPhiAHcAAP9tMP8A4/9wFP8AAHwA
                MKIA4xIAFAAAAK0AADkAAOkAAHcAAAAAAAAA4BMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYw
                cwDjcgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhTAAsIHEiwoMGDCBMqXMiw4UIAECNKhNgwAEWCAgYAcHiRIIGNDTsSBMlQpMORJE+iVGnQJEuX
                KmGelMkxJcsCNEPaVGkRQICbOCcCHUq0qNGBAQEAOw==
                ';

        $grkgifs{chalpha} = '
                R0lGODlhGAAYAIUAAf///+fr5wAAAFJVUqWqpSEgIRAQELW6tWNlY8bLxnN1c0JBQjEwMYSGhAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAGAAYAAUGeUCAcEgsGo/IpHLJ
                bCoDgsGQUHAKCQZiQXCwIrrCxFbqVBAXCYYgYB0GqgSBuQ1AEISGLL0qVAjuVg0NbgILbQxFC2tO
                BAhFBwKOTWoClZYCeksJhkaKgEoDYI8CiEpiSVuiRgkGnEdqBqpDDZeDRAmXhXS7vL2+REEAOw==
                ';

        $grkgifs{chepsilon} = '
                R0lGODlhGAAYAIUAAf///+fr5wAAAFJVUqWqpRAQELW6tdbb1jEwMWNlY3N1c4SGhMbLxpSWlAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAGAAYAAUGW0CAcEgsGo/IpHLJ
                bCIDggFAQK1aqUhCYWjAEg8IATJhIHqJBPFRUTybnW6nWT2kN90LO/NalU/teX5xektxfn+HbYQA
                DAh3iwgNTF0CB19hAYV8Vo6Jnp+goUEAOw==
                ';

        $grkgifs{cheta} = '
                R0lGODlhGAAYAIUAAf///+fr5wAAAFJVUqWqpRAQELW6tWNlY3N1cwAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAGAAYAAUGXECAcEgsGo/IpHLJ
                bB4DggFAQK0Sq9YhoTA0UA1GrwBMPJCFVGS6iCiuje9k/Cpgzod3eP2Yd2P/fXRqe0p9gXiEfnaJ
                gkuGjHyQaJJEYmddX3J/dFhOnp+goaFBADs=
                ';

        $grkgifs{chiota} = '
                R0lGODlhGAAYAIUAAf///+fr5wAAAFJVUqWqpRAQELW6tWNlY3N1cwAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAGAAYAAUGRECAcEgsGo/IpHLJ
                bC4DggFAQK06CYWhgWpwAg7dIdULQBTH5LMgrWYT0e7pOi6n1+lwd569T/e9WwJhflV/doeIiUNB
                ADs=
                ';

        $grkgifs{chomega} = '
                R0lGODlhHAAZAIUAAf///+fr5wAAAFJVUmNlYyEgIcbLxqWqpRAQEISGhNbb1rW6tXN1c0JBQjEw
                MZSWlAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAHAAZAAUGiECAcEgsGo/IpHLJ
                bDqf0GRAMBAGCAWBoEAwPA8IYYKqECoGAoKTsACME8ZDuskAKAQNZEPgbRIEbUcLVE5ZSgJhTVqH
                Ak6LSY9MDgJlR1MOTgwCD0hycE0BCAVIDolOcg0BRAFogU8GBXlDDQ19ipUAmLNDd0xav41DwJGQ
                w0TDwVHKy8zNzUEAOw==
                ';

        $grkgifs{chomicron} = '
                R0lGODlhGAAYAIUAAf///+fr5wAAAFJVUqWqpRAQEEJBQjEwMbW6tWNlY3N1c8bLxiEgIZSWlNbb
                1gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAGAAYAAUGgECAcEgsGo/IpHLJ
                bCIDgsGQMCgIBAbCklAQBg4HxBQcSCbEgILUWC0fFUJDF1kwKAkCOFIh0CIHAgtJC1FJVksCc0dX
                iAJJjEqQRwyOkQxJgGhHhAlJeJ1IDYFKBwVuRgx2Sg4FB0cJrkwOBwx+AAQMsU4EBldqtk7BwsPE
                xUJBADs=
                ';

        $grkgifs{chupsilon} = '
                R0lGODlhGAAYAIUAAf///+fr5wAAAFJVUqWqpRAQECEgIYSGhEJBQpSWlGNlY7W6tTEwMXN1c9bb
                1sbLxgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
                AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAGAAYAAUGbECAcEgsGo/IpHLJ
                bBoDggFAQK0KitarkFAYEgzUwxEhSBAViyKjPCYUG0aHoBAoLuDNgwBRNDiFZGJCaH8AAQUCDgAP
                fIUACQIMAAx1jgADAgaCllNanJ2fQlShoKGjnwtUaZZZnqSvsLFGQQA7
                ';

        $grkgifs{ciota} = '
                R0lGODlhGAAYAPcAAAQCBLS6tPz+/AAAdwAAAAIAAAAAEwAAAAqweACjEwASEwAAAAD/RQD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOhDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABhlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJpAAAAAABvAAAAAAB0AAAAADBhAOMAABQuAAAAAHBiABYAAPhtAHcAAP9wMP8A4/8AFP8AAHwA
                MKIA4xIAFAAAAK0AADkAAOkAAHcAAAAAAAAA4BMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGP9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGAATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYw
                cwDjcgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WKKlpxJOEgAAAJw85vml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhLAAUIHEiwoMGDCBMqXMiwoUMAECM6LBgAYoCJBiFizAhgY0GNHgeCDClgZEiTHlFuVImR5USX
                DzuSLCkzZEUAF1NGhDmzp8+fBgMCADs=
                ';

        $grkgifs{ckappa} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRNTa1CQiJGRmZKSqpPz+/BQSFFRWVOTq5DQyNHR2dLS6tAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJrAAAAAABhAAAAAABwAAAAADBwAOMAABRhAAAAAHAuABYAAPhiAHcAAP9tMP8A4/9wFP8AAHwA
                MKIA4xIAFAAAAK0AADkAAOkAAHcAAAAAAAAA4BMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYw
                cwDjcgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                Bwh9AA8IHEiwoMGDCBMqXMiwoUIAECMOjAhRgMIGEBsUFACgwACGEA0S+Ngw5EAFBRQ4PGDywACL
                K1kCEGigQEyBIQPYvCmzAACSNyH6RAB0ZUifBHia9Lkg6EyBTGO2PBDV4dQDDAAgCMAQIwCNBBNA
                3JqQYkuOZnmqXcuWbUAAOw==
                ';

        $grkgifs{ckoppa} = '
                R0lGODlhGAAYAPcAAAQCBISKhNze3KSmpFRSVGxqbLS2tJSalOzy7KyyrHR6dIyKjGRmZPz+/Hx6
                fDw6POTi5KyqrFRWVLy+vJyanPT29LSytIyOjHx+fACa/wCu1wAuFo56JwEGpQAW1wCaFq/yTFkq
                UNf6xivKFv/aABUGAACGAADGAABKjwAmFgDuLgCqdAwWAHPSAAluAlI2dACSAAGyAAB2jgAOAJ8e
                dtCOAABeAAA+AICyVqR+H3b2AAAuAM7+AOnOAEvexQAAFWYArwAAFwD/SwD/AJgAZaQCAHYPRAAo
                vGz3YqS/gHa2AQBRAPJoALJzAE4oAAAAANu3AP8BAP8AEP8AAAAXAABqAAAAGAABAO8AAOgAAEuf
                AADQwNgAO7AA0HYnEgBqACUAAAAAAAAnIwAcApiPAKSxAHb5AAC/AGwDRKQAdHbeAAB0AOQDjxwA
                FlTPSABAdH8AAAgAAPpGxb+XFfzur04TF/X34L+/u/9sYv+jgP92yv8AFf9Qr//wF/+az/+BFsQQ
                xgNSFgCfAACBAABzAACxAAD5dQC/AQgAzwAwFgB2ZAAAdOIOABOhAPf3AL+/AH8mBwGzAAD3AAC/
                AGQAh87wAfeadb+BAfcAAEEAAPcAAL8AABQAAFIAAJ8AAIEAAPp/ANoIAPf6AL+/AJDgAJRVAPxQ
                AL8AAMSUrwOjFwB2hwAAAUBWJQCrAAD4AAC/AIwI/6Lm/3YA/wCA/yQgJdtcAPcAAL+AAFwg2Deq
                sKkAdoGAAECYAAAQAAABAACAABQAuFIBpJ8AdoEAABMQCAGqtQAAS8CAABTkmFIcpJ9UdoEAAEB/
                8wAIsgD6TgC/AMT8zANOpAD1dgC/AIC0f0ukCAN2+tIAv9TrbaO2p3b5dgC/AP0E2fTw//dO/78A
                f/8MSP/wp/9Odv8AAIDc5ACbHAD8VAC/AAO0fwCjCAB2+gAAv0MA5DoBHFwAVGIAAG/gAG9VAGtQ
                AHMAAFwAr3IASXQAR2bQAFyMSHAIp3IAdmUAAHAcSFwsp3Q8dmXQACH5BAAAAAAALAAAAAAYABgA
                Bwh6ABsIHEiwoMGDCBMqXMiwocOHByNQMACxYIAFACRULIgBwEaCDxx8FCgAQIKRDQZ4JGiBwkMC
                BUheAABAZEMEAAYMeECTJsWGBnoCeGDgwMqGDGgugCDwgYKHFyYQrGASZQIAFVAWIICywdAGWT8G
                pdl1AtOuaNMmDAgAOw==
                ';

        $grkgifs{clambda} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOZDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABplAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJsAAAAAABhAAAAAABtAAAAAHBiALcAABVkAAAAAHBhABYAAPguAHcAAP9icP8At/9tFf8AAHxw
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGv9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGgATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WqKlpxJOEgAAAJw85Pml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiDAB8IHEiwoMGDCBMqXMiwocMHDQw8PKgAwUSDAAAEuDgwgQEAFjk+IHDgYwGOAwQ8OACAAEcD
                Jx8oABDzoUuBAwCofFjAAUEBAAY8ZLCAYM6dDBcwMAj0QEMHNQfmlMjwpkECAJwq9IiwAACqCBMA
                UIAwQMYECDOqxag2o8i3cONyDAgAOw==
                ';

        $grkgifs{cmu} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOpDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABZlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJtAAAAAAB1AAAAAAAuAAAAAHBiALcAABVtAAAAAHBwABYAAPgAAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QFv9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFgATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0VqKlpxJOEgAAAJw86Pml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwirAB8IHEiwoMGDCBMqXMiw4UEAEAE4SLggIgCDASAiSGgAYgOEABAAKICQAMSEADoSOFig40WQ
                ByAOMKhgwEmQDwSkLHhg5c2HDxpAPEAwQYAHPw2+NHl0IAGiSQu+TABgpcAFCgRGJfjygUiSDwyA
                3Tqwa0cBAq0i7ap0YEwABxoYKMtWKkGdBhQsoIuSoFAEDLjWHSj0o1MACQh7VGpxIFW6jR1Knky5
                cuWAADs=
                ';

        $grkgifs{cnu} = '
                R0lGODlhGAAYAPcAAAQCBISGhMTKxERCRCQiJKSqpOTq5HR2dBQSFJSWlNTa1FRWVDQyNLS6tPz+
                /AD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOpDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABZlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJuAAAAAAB1AAAAAAAuAAAAAHBiALcAABVtAAAAAHBwABYAAPgAAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QFv9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFgATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0VqKlpxJOEgAAAJw86Pml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiCAB0IHEiwoMGDCBMqXMiwIUIBACICOGBQYsSEChZEbGCwAQCOCyMiMFCxIQAGJ0syBKAAwcSC
                AEw6KLCRYMyVAjUisClTIAEAAwbeDDlQQcQAAocqVJogogAHShNG1Qm1J8GfA6Ii1Gr0Ik6DTbV2
                /HhQY0iLBwk4TEhyrdu3cBcGBAA7
                ';

        $grkgifs{comega} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJvAAAAAABtAAAAAABlAAAAAHBnALcAABVhAAAAAHAuABYAAPhiAHcAAP9tcP8At/9wFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiTAB8IHEiwoMGDCBMqXMiwYcMDBggAAEDAwACHDwIAULBA4AIFAAw01BjAYIGQCxcAEIBQAICL
                CQ0AaICwwUaFEhUCQKATQM+fCScqZACg48EDABgodAAgAcKTJRMeQEAAIQOeC08KOEDwAEiaDAcQ
                YDlQgACYQY0+UFp2oEqEE+P6HChX6MG6cwXixci3r9+/GAMCADs=
                ';

        $grkgifs{comicron} = '
                R0lGODlhGAAYAPcAAAQCBJSWlERCRNTa1CQiJLS6tGRmZPz+/BQSFKSqpFRWVOTq5DQyNMTKxHR2
                dAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOVDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABtlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJvAAAAAABtAAAAAABpAAAAAHBjALcAABVyAAAAAHBvABYAAPhuAHcAAP8ucP8At/9iFf8AAHxt
                cKIAtxJwFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QG/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0W6KlpxJOEgAAAJw84/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiOAA8IHEiwoMGDCBMqXMiwYcMEChAAACAggcMDCxgwKDAwgcYFDREoOBgRpEIBCBIiEKAwAQAH
                CR0AsIhQAYAGCRsAGIlQ4kIAKRFO/Akg4VCFRw8SKIqUQEKbHBHqNJDQJVWEAW4qZIDApEECLBUO
                QMDgoIGyDAcwIEDzQAICaB0mEDBRZNuLePPq3Zs3IAA7
                ';

        $grkgifs{cphi} = '
                R0lGODlhGAAYAPcAAAQCBJyenPz+/Hx+fLy+vHEAdIB6AFpzAAADugAAZ0cnALwGAADFAAA/0I8v
                OgEC0ACsAgABAgAzAAACAOy5AHEBAEEtL1kCdgCqQQAB/wAT1wAEFgC8JwABpQAA1wAwFq9oTFnP
                UC8AxnbQFv85ABXQAAAAAAAAAAAAjwAAFgAzLgACdAwAAHMAAAkzAlICdAC3AAEBAABEjgBzAIcA
                dhsAAAACAAACAIAAVqQAH3ZJAAAAAM4AAOkAAEsPxQAAFWYArwAAFwD/SwD/AJgAZaQCAHYPRAAo
                vGz3YqS/gHa2AQBRAPJoALJzAE4oAAAAANS3AP8BAP8AEP8AAABPAAA7AAAAGAABAO8AAOgAAEuH
                AAAb8NgAOrAA0HY3EgCRACwAAAAAAABfIwCnApiPAKSxAHb5AAC/AGwCRKQAdHbeAAB0AOQDjxwA
                FlTPSABAdH8AAAgAAPpGxb+XFfwAr04AF/Vq4L/3u/8DYv8AgP8Iyv90Ff8Dr/8AF/8nz/8GFhRW
                xgEfFtYvAAECADhzAJSxAC/5dbG/ASQAz3MwFgJ2ZAAAdEeqAAABAE8TADsEAAK8BwABAKoAAIIw
                APVoh7/PATwAdY7QAbc5AATQAOAAALsAAGwAAAQAAJYAAAcAAAB/AAAIAKL6AGa/ACfgAAZVAABQ
                AAAAACmUrwCjF892hxYAAQdWLACrAAD4AAC/AI5A/3L8/8QA/0aA/wBYLADnAAAAAACAAIcw2AHR
                sAAAdgCAAJiAAKJbAHYAAACAAHsAuLcBpPcAdr8AAPdICEF7tfcAS7+AAJDkmJQcpPxUdr8AAJZ/
                87cIsvf6Tr+/AJD8zJROpPz1dr+/AIe0fwGkCAB2+gAAv7DrdKK2p3b5dgC/ACgE0rjw//dO/78A
                f2wMSATwp6ROdoEAAPfc5EGbHPf8VL+/AJC0f5SjCPx2+r8Av04A5LgBHPcAVL8AAAHgAABVAABQ
                AAAAAAEArwAASTMARwLQALeMSAEIp88AdkAAAAAcSABcp0Y7dpfQACH5BAAAAAAALAAAAAAYABgA
                BwiCAAUIHEiwoMGDCBMqXMiwoUMAECM6LBgAYoCJAgkMGBAR4gACDTkGAAlRAIGKAxZyBCmwZEYA
                KRFWvDjQpcCZCFcStGkSJkKeAoACrQmgoNCiB3USJUjA50GcSwdCTQqAZVCkPWMmFEmy6EmnCzV2
                9GjVYUUANDFe7ai2rdu3cBUGBAA7
                ';

        $grkgifs{cpi} = '
                R0lGODlhGAAYAPcAAAQCBKSqpPz+/LS6tAAAAAIAAAAAEwAAAAqweACjEwASEwAAAAD/RQD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOpDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABZlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJwAAAAAABpAAAAAAAuAAAAAHBiALcAABVtAAAAAHBwABYAAPgAAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QFv9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFgATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0VqKlpxJOEgAAAJw86Pml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhgAAUIHEiwoMGDCBMqXMiwYUIAECNKnKgwAMSDEAMwvGiQ40KPBEE+BICR5EaTBUUiVCmAZUeU
                IWGOLNmQpcuUMgXejEnzZM+POVsGLWgRwACiGRVORLnUodOnUKNKFRgQADs=
                ';

        $grkgifs{cpsi} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJOTq5KSqpFRWVBQSFNTa1DQyNPz+/LS6tGRmZAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOlDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABdlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJwAAAAAABzAAAAAABpAAAAAHAuALcAABViAAAAAHBtABYAAPhwAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QF/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0V6KlpxJOEgAAAJw85/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiAABcIHEiwoMGDCBMqXMiwYUIABwYCmEhx4AEACAcACDCQwUQGAxsAGPCQAMGJBAlgfLhSIEqJ
                LQ++dBlz5kEFABLAHJgAgAKFATbuFBiUo0IBGwssQFkgqICGBg4goAgAwQEDDk/GzDqUq1avBW2C
                FcvVIwCQY6luBcu2rdu3AQEAOw==
                ';

        $grkgifs{crho} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJGRmZOTq5KSqpBQSFFRWVNTa1DQyNHR2dPz+/LS6
                tAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOlDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABdlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJyAAAAAABoAAAAAABvAAAAAHAuALcAABViAAAAAHBtABYAAPhwAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QF/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0V6KlpxJOEgAAAJw85/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhpABsIHEiwoMGDCBMqXMiw4UIAECMCQCDggMMGDiAaEDggAYACFyEW9BjAoUiCCgAQMAnA4EmG
                LwUamMiyYAEADFhabGDA44KQEgEsKAn04sGYRgUiTbrUaFOHGQE4SKo0KNWrWLNqRRgQADs=
                ';

        $grkgifs{csampi} = '
                R0lGODlhGAAYAPcAAAQCBIyKjNTW1KyqrFRSVOzy7Ly+vGRqZJSalNze3KyyrPz+/Hx6fDw6PPTy
                9KSmpLSytJSWlNzW3FRWVMTCxGxqbJyanOTi5Hx+fDw+PPT29LS2tI56JwEGpQAW1wCaFq/yTFkq
                UNf6xivKFv/aABUGAACGAADGAABKjwAmFgDuLgCqdAwWAHPSAAluAlI2dACSAAGyAAB2jgAOAJ8e
                dtCOAABeAAA+AICyVqR+H3b2AAAuAM7+AOnOAEvexQAAFWYArwAAFwD/SwD/AJgAZaQCAHYPRAAo
                vGz3YqS/gHa2AQBRAPJoALJzAE4oAAAAANu3AP8BAP8AEP8AAAAXAABqAAAAGAABAO8AAOgAAEuf
                AADQwNgAO7AA0HYnEgBqACUAAAAAAAAnIwAcApiPAKSxAHb5AAC/AGwDRKQAdHbeAAB0AOQDjxwA
                FlTPSABAdH8AAAgAAPpGxb+XFfzur04TF/X34L+/u/9sYv+jgP92yv8AFf9Qr//wF/+az/+BFuAQ
                xgNSFgCfAACBAABzAACxAAD5dQC/AQgAzwAwFgB2ZAAAdOIOABOhAPf3AL+/AH8mBwGzAAD3AAC/
                AGQAh87wAfeadb+BAfcAAEEAAPcAAL8AABQAAFIAAJ8AAIEAAPp/ANoIAPf6AL+/AJDgAJRVAPxQ
                AL8AAOCUrwOjFwB2hwAAAUBWJQCrAAD4AAC/AIwI/6Lm/3YA/wCA/yQgJdtcAPcAAL+AAFwg2Deq
                sKkAdoGAAECYAAAQAAABAACAABQAuFIBpJ8AdoEAABMQCAGqtQAAS8CAABTkmFIcpJ9UdoEAAEB/
                8wAIsgD6TgC/AOD8zANOpAD1dgC/AIC0f0ukCAN2+tIAv9TrbaO2p3b5dgC/AP0E2fTw//dO/78A
                f/8MSP/wp/9Odv8AAIDc5ACbHAD8VAC/AAO0fwCjCAB2+gAAv0MA5DoBHFwAVGIAAG/gAG9VAGtQ
                AHMAAFwAr3IASXQAR2bQAFyMSHAIp3IAdmUAAHAcSFwsp3Q8dmXQACH5BAAAAAAALAAAAAAYABgA
                BwidABcIHEiwoMGDCBMqXMiw4cIEFghMIGABgsMFGgIAADABgYUGGw0w1NAggAMLEQYa2Ghh4YMN
                Aj0SdLBxgEOUBTUCENDQQkuBCQhUqADgQM8HAgUAgKkUgIOLCwBgGBjyooKdAwkASOkQAwCCEwD8
                bCiRoFaLDicSzAAgwcWyVL9eTMBTIAQAaKEOZNBAL0ENACT4HQgB5uDDiAcHBAA7
                ';

        $grkgifs{csigma} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJzAAAAAABpAAAAAABnAAAAAHBtALcAABVhAAAAAHAuABYAAPhiAHcAAP9tcP8At/9wFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                Bwh7AB8IHEiwoMGDCBMqXMiw4UICACJKnCiA4QIEABYUXMCgIsMGABAcKNiAgMMEABgYBODwgQEA
                CloeZAAggEyDGAvcJHgRwU6CAnT+dCn0ZwEHQx8UMGDwAEuGA2IaDOBR4YKqAw+glJrwAMaJYG0q
                pAkWbNGkaNOqRRgQADs=
                ';

        $grkgifs{cstigma} = '
                R0lGODlhGAAYAPcAAAQCBIyKjNTW1KyqrFRSVJSalOzy7Ly+vGxqbKyyrPz+/JSWlFxWXKSmpPTy
                9Hx6fLSytDw6PIyOjNze3FRWVJyanMTCxPT29Hx+fLS2tAD21wC2Fo56JwEGpQAW1wCaFq/yTFkq
                UNf6xivKFv/aABUGAACGAADGAABKjwAmFgDuLgCqdAwWAHPSAAluAlI2dACSAAGyAAB2jgAOAJ8e
                dtCOAABeAAA+AICyVqR+H3b2AAAuAM7+AOnOAEvexQAAFWYArwAAFwD/SwD/AJgAZaQCAHYPRAAo
                vGz3YqS/gHa2AQBRAPJoALJzAE4oAAAAANq3AP8BAP8AEP8AAAAXAABqAAAAGAABAO8AAOgAAEuf
                AADQwNgAO7AA0HYnEgBqACYAAAAAAAAnIwAcApiPAKSxAHb5AAC/AGwDRKQAdHbeAAB0AOQDjxwA
                FlTPSABAdH8AAAgAAPpGxb+XFfzur04TF/X34L+/u/9sYv+jgP92yv8AFf9Qr//wF/+az/+BFvsQ
                xgNSFgCfAACBAABzAACxAAD5dQC/AQgAzwAwFgB2ZAAAdOIOABOhAPf3AL+/AH8mBwGzAAD3AAC/
                AGQAh87wAfeadb+BAfcAAEEAAPcAAL8AABQAAFIAAJ8AAIEAAPp/ANoIAPf6AL+/AJDgAJRVAPxQ
                AL8AAPuUrwOjFwB2hwAAAUBWJgCrAAD4AAC/AIwI/6Lm/3YA/wCA/yQgJttcAPcAAL+AAFwg2Deq
                sKkAdoGAAECYAAAQAAABAACAABQAuFIBpJ8AdoEAABMQCAGqtQAAS8CAABTkmFIcpJ9UdoEAAEB/
                8wAIsgD6TgC/APv8zANOpAD1dgC/AIC0f0ukCAN2+tIAv9TrbqO2p3b5dgC/AP0E2PTw//dO/78A
                f/8MSP/wp/9Odv8AAIDc5ACbHAD8VAC/AAO0fwCjCAB2+gAAv0MA5DoBHFwAVGIAAG/gAG9VAGtQ
                AHMAAFwAr3IASXQAR2bQAFyMSHAIp3IAdmUAAHAcSFwsp3Q8dmXQACH5BAAAAAAALAAAAAAYABgA
                BwiGABUIHEiwoMGDCBMqXMiwYcMLAx4QoEAgwASHCjIAANDAwgGNAAY0TLDRAUGNFBhe2Ciy4AAL
                DAdsxGiwAgAGNAsuAEAg58mSPgdGABChpc8JDDYCQNBAgE8BASgoBZAgqAILNgEssCqQAACuCiR8
                9WngQACiNKduxGASI4QKHZ2CnUuXYUAAOw==
                ';

        $grkgifs{ctau} = '
                R0lGODlhGAAYAPcAAAQCBLS6tPz+/DQyNNTa1MTKxERCRAAAAAqweACjEwASEwAAAAD/RQD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOlDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABdlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJ0AAAAAABhAAAAAAB1AAAAAHAuALcAABViAAAAAHBtABYAAPhwAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QF/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0V6KlpxJOEgAAAJw85/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhYAAUIHEiwoMGDCBMqXMiwoUIAECNKlPhwAIGBEAcWGADgYQCCGQcG6JjQQMGQA006FIByJUiS
                Ll/GPAlzJsuaM1vmxBlTZ0+eLn2uHAng406KNpMqXbo0IAA7
                ';

        $grkgifs{ctheta} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJ0AAAAAABoAAAAAABlAAAAAHB0ALcAABVhAAAAAHAuABYAAPhiAHcAAP9tcP8At/9wFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwigAB8IHEiwoMGDCBMqXMiwocMCChAAACCggEOBAhg0GFiAAYMDDA8gUHBQAAKQChkgSIiAgcIC
                ABwkdADAIkIFAAY8AFCQ5wAAJBFKFAggwMAAPHeuRDiR6MSnSZsyjQpVqtSDBKIaFYiUKIGEBgBs
                TDrQJwADCX+iRYhUZ0KTKA0iELBQpEuDCu4uXEBAI0cGdC8mEDBxpM2LiBMrXpw4IAA7
                ';

        $grkgifs{cupsilon} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJGRmZOTq5KSqpBQSFFRWVNTa1DQyNHR2dPz+/LS6
                tAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOVDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABtlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJ1AAAAAABwAAAAAABzAAAAAHBpALcAABVsAAAAAHBvABYAAPhuAHcAAP8ucP8At/9iFf8AAHxt
                cKIAtxJwFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QG/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0W6KlpxJOEgAAAJw84/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhyABsIHEiwoMGDCBMqXMiwYUIAECMGGBggIsSEBxAASGDQAAACDhYq+NiRgEMGAAoUFDDAYQMC
                AFoKdKDSpQOSAhcYcClQAICJASbybOARwQCTQwVWjJl04MWmAp9CldqUalKrPG8CCHnVIgCoYMOK
                bRoQADs=
                ';

        $grkgifs{cxi} = '
                R0lGODlhGAAYAPcAAAQCBISGhPz+/HR2dLS6tAIAAAAAEwAAAAqweACjEwASEwAAAAD/RQD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOpDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABZlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJ4AAAAAABpAAAAAAAuAAAAAHBiALcAABVtAAAAAHBwABYAAPgAAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QFv9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFgATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0VqKlpxJOEgAAAJw86Pml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhYAAUIHEiwoMGDCBMqXMiwIUMAECNKBNBwosWKAw4GoPgwIUeHIBF+FDiyIoGBBEo+vBjSosqF
                AE4KTBlSQMmXNR3iHLiTZICEG2G6nCh0aMScSJMqXSogIAA7
                ';

        $grkgifs{czeta} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOhDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABhlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhjALEA
                ABJ6AAAAAABlAAAAAAB0AAAAAHBhALcAABUuAAAAAHBiABYAAPhtAHcAAP9wcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGP9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGAATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WKKlpxJOEgAAAJw85vml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                Bwh6AB8IHEiwoMGDCBMqXMiw4UIAECNKBMCAIQAEAwouuHjAYgGDDAAkaAjAoAMAChwaHHBRpUEC
                ADK6HKgAgIOZAxtQxCnwAAIAC3g+EAAggNAEAAQI3Yig40qGIT8aXEBg4cmUBw1gRcgSAUKkRhP+
                nEhWptCzaNM2DAgAOw==
                ';

        $grkgifs{halpha} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhoALEA
                ABJhAAAAAABsAAAAAABwAAAAAHBoALcAABVhAAAAAHAuABYAAPhiAHcAAP9tcP8At/9wFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiEAB8IHEiwoMGDCBMqXMiwocMHBwAoeGiwAAKKBg00wFjQAcePCA0AAOAxIoGHDAgceGAgQQOJ
                DhMAKDCQQQAACRwKALBgoEwAAxyOLDhUKACCCwAIeFhUYAGSKAGsFCiSpsObVk0aoIhA5QMGQAUs
                WHCR4QEFIwUEbYAAgVWQcOPKdRgQADs=
                ';

        $grkgifs{hepsilon} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJGRmZKSqpOTq5BQSFFRWVDQyNHR2dLS6tPz+/AD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOVDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABtlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhoALEA
                ABJlAAAAAABwAAAAAABzAAAAAHBpALcAABVsAAAAAHBvABYAAPhuAHcAAP8ucP8At/9iFf8AAHxt
                cKIAtxJwFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QG/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0W6KlpxJOEgAAAJw84/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhwABsIHEiwoMGDCBMqXMiwocMGBwAkeGjQAAKKBgswwFhwAcePCBkIAAAAQYEDFAMAKCCwAAAC
                FBEAIKhAQcyZIBsYABAgZ4MBJAsggElxZ0+QMn3KRDmQgE2HOxWgPODyqcMBCWQCEGDAp9evYBcG
                BAA7
                ';

        $grkgifs{heta} = '
                R0lGODlhGAAYAPcAAAQCBJyenPz+/Hx+fLy+vHFldIByAFpzAABcugBwZ0dwALxcAABpAABs0I9s
                OgFc0ABjAgBwAgBoAABpAOwuAHFnAEFpL1lmdgAAQQAB/wAT1wAEFgC8JwABpQAA1wAwFq9oTFnP
                UC8AxnbQFv85ABXQAAAAAAAAAAAAjwAAFgAzLgACdAwAAHMAAAkzAlICdAC3AAEBAABEjgBzAIcA
                dhsAAAACAAACAIAAVqQAH3ZJAAAAAM4AAOkAAEsPxQAAFWYArwAAFwD/SwD/AJgAZaQCAHYPRAAo
                vGz3YqS/gHa2AQBRAPJoALJzAE4oAAAAANS3AP8BAP8AEP8AAABPAAA7AAAAGAABAO8AAOgAAEuH
                AAAb8NgAOrAA0HY3EgCRACwAAAAAAABfIwCnApiPAKSxAHb5AAC/AGwCRKQAdHbeAAB0AOQDjxwA
                FlTPSABAdH8AAAgAAPpGxb+XFfzur04TF/X34L+/u/9sYv+jgP92yv8AFf9Qr//wF/+az/+BFpZ8
                xgLVFgCgAACBAABzAACxAAD5dQC/AQgAzwAwFgB2ZAAAdOIOABOhAPf3AL+/AH8mBwGzAAD3AAC/
                AGQAh87wAfeadb+BAfcAAEEAAPcAAL8AAIAAANUAAKAAAIEAAPp/ANoIAPf6AL+/AJDgAJRVAPxQ
                AL8AAJaUrwKjFwB2hwAAATRWLACrAAD4AAC/AIxA/6L8/3YA/wCA/yRYLNvnAPcAAL+AAGww2ATR
                sKQAdoGAADSAAABbAAAAAACAAIAAuNUBpKAAdoEAABNICAF7tQAAS8CAAIDkmNUcpKBUdoEAADR/
                8wAIsgD6TgC/AJb8zAJOpAD1dgC/APC0f9mkCA92+tIAv9TrdKO2p3b5dgC/AP0E0vTw//dO/78A
                f/8MSP/wp/9Odv8AAIDc5ACbHAD8VAC/AAO0fwCjCAB2+gAAv0MA5DoBHFwAVGIAAG/gAG9VAGtQ
                AHMAAFwAr24ASWUAR3fQACCMSHAIp3IAdm8AAGocSGVcp2M7dnTQACH5BAAAAAAALAAAAAAYABgA
                BwhlAAUIHEiwoMGDCBMqJEgAwICFCgMAgKhwAAGKCQNg3EixIQCNEh1utAjg40WJDylOLHlRYEmO
                LwfGxDhTQE2INW8uzDlxI0+YPV0GVTlUp8KfHAsa9Tk0qc2mSZdiHACgpdOFAQEAOw==
                ';

        $grkgifs{hiota} = '
                R0lGODlhGAAYAPcAAAQCBJSWlERCRNTa1GRmZCQiJKSqpPz+/BQSFFRWVOTq5HR2dLS6tAD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOhDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABhlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhoALEA
                ABJpAAAAAABvAAAAAAB0AAAAAHBhALcAABUuAAAAAHBiABYAAPhtAHcAAP9wcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGP9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGAATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WKKlpxJOEgAAAJw85vml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhUAA8IHEiwoMGDCBMqXMiwoUOBCgAkeGjQAAKKBgkwwFhwAcePCBUESAAAJAIAKEEeGJBSZUuQ
                Lz/G5DgTY02KLS9yLABgQAACHxnwFKCyqNGjDwMCADs=
                ';

        $grkgifs{homega} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhoALEA
                ABJvAAAAAABtAAAAAABlAAAAAHBnALcAABVhAAAAAHAuABYAAPhiAHcAAP9tcP8At/9wFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiWAB8IHEiwoMGDCBMqXMiwoUOBBwAoeGiwAAKKBg00wFjQAcePBhcYIABAIAACBhY0LACAwcaB
                DRgAKLBwwcmBBiYKlKkyoYGZAwGUFNgAgAGFJA8EHWqSgEKhBAFcXPqU6QMFOk1aNSiTYAKaQZ0m
                DABUIFaYRhcyIKA0AYIBCR4cYIBA6UIHCAAIUNmA5F6QgAMLphgQADs=
                ';

        $grkgifs{homicron} = '
                R0lGODlhGAAYAPcAAAQCBISGhFRWVMTKxCQiJOTq5KSqpHR2dBQSFGRmZNTa1DQyNPz+/LS6tAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOVDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABtlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhoALEA
                ABJvAAAAAABtAAAAAABpAAAAAHBjALcAABVyAAAAAHBvABYAAPhuAHcAAP8ucP8At/9iFf8AAHxt
                cKIAtxJwFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QG/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0W6KlpxJOEgAAAJw84/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                Bwh3ABkIHEiwoMGDCBMqXMiwoUOBBQAIeGjQAAKKBhM0wFjwAMePCAcIAABgwUaKFjcWGOnRYUQD
                BAkAGOAwAYCCBiQ6lFkw4s2GJA0GbYgAgIKCAAg4HBkAaQKHAwBcHJizwMMDJa0OQACTYoMFJAXQ
                BEm2rFmOAQEAOw==
                ';

        $grkgifs{hrho} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJGRmZOTq5KSqpBQSFFRWVNTa1DQyNHR2dPz+/LS6
                tAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOlDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABdlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhoALEA
                ABJyAAAAAABoAAAAAABvAAAAAHAuALcAABViAAAAAHBtABYAAPhwAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QF/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0V6KlpxJOEgAAAJw85/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                Bwh9ABsIHEiwoMGDCA0ASICwIcEDCBxKbFDAwUSHDC5q3MhR4oAEABYO6MggYwOIAA5sdACAoAIE
                ACxeFNCSYAAACzSGLKhg50WfBIFKFCoQp86aA3sGODpyYAICG0MKGGmgAAIFUQEooImgQEeiX5F2
                LCq2o8KcYwWyFJA2bUAAOw==
                ';

        $grkgifs{hupsilon} = '
                R0lGODlhGAAYAPcAAAQCBJSWlFRWVNTa1CQiJLS6tHR2dPz+/BQSFKSqpGRmZOTq5DQyNMTKxAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOVDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABtlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhoALEA
                ABJ1AAAAAABwAAAAAABzAAAAAHBpALcAABVsAAAAAHBvABYAAPhuAHcAAP8ucP8At/9iFf8AAHxt
                cKIAtxJwFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QG/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0W6KlpxJOEgAAAJw84/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                Bwh5AA8IHEiwoMGDCBMqXMiwoUOBCwAIeGgwAQKKBhUUwFjQAMePBQcQQJBgIAIFDwU0AHBRYAME
                DBwCOABg5sAEAAI8rEkwYkyZNgfyBFpwaEOjAgEQ2Bn0wEqPDhkAGDDQAIIFDwsAYIA1AIKNFAtI
                lUgVpNmzaDkGBAA7
                ';

        $grkgifs{lalpha} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJhAAAAAABsAAAAAABwAAAAAHBoALcAABVhAAAAAHAuABYAAPhiAHcAAP9tcP8At/9wFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                Bwh8AB8IHEiwoMGDCBMqXMiwocOHECNKLGgAAAAHDw4AIPCQAYEDDwwkaABAgcMEAAoMZBAAQAKH
                AgAsGIgSwACHFgvmxAmA4AIAAh7uFFjgYkcAIAVWVOmwJVONBAxARPDxAQObAhYsQNDwgAKLAm42
                QICA6cSzaNOqXTsxIAA7
                ';

        $grkgifs{lbeta} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOhDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABhlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJiAAAAAABlAAAAAAB0AAAAAHBhALcAABUuAAAAAHBiABYAAPhtAHcAAP9wcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGP9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGAATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WKKlpxJOEgAAAJw85vml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiPAB8IHEiwoMGDBQ0gAIDAwAGECA8gQDDgwQAGCBZANGgAQIOBDQAI2FiQAICCAE6SHJgSpcqV
                D1oOPABAAUyBMgUGQPDwpkwCExPcxPnSIgAHQ3MK7FjAZ9EHIRk4Nah0Y9WYTyFWpWkTZtUAACp6
                rdkzwdGkHhmkFPAR7dCDV9/GvbkAAIG3BUN2xctXYEAAOw==
                ';

        $grkgifs{lchi} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJGRmZOTq5KSqpBQSFJSWlFRWVNTa1DQyNHR2dPz+
                /AD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOlDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABdlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJjAAAAAABoAAAAAABpAAAAAHAuALcAABViAAAAAHBtABYAAPhwAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QF/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0V6KlpxJOEgAAAJw85/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                Bwh3AB0IHEiwoMGDCBMqXMiwocOHECNKJGiAAIADAwcAIOCwAAAACAYKuOiQQAMHCjBq5OgQgMAF
                BRyMxCiRwMqJMmfiDLARp0ySE2/iHOky6EYFAybOTJBA4s0FCgYWZajTgU0HARg0FOqgwUcAARpW
                FThSgE+FAQEAOw==
                ';

        $grkgifs{ldelta} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJkAAAAAABlAAAAAABsAAAAAHB0ALcAABVhAAAAAHAuABYAAPhiAHcAAP9tcP8At/9wFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiEAB8IHEiwoMGDCBMqXMiwYcMFCgAAQGDggMOBBBI8OMAAAIGLAgEQFMAA5AMHBkwaNKBAZUED
                BBa4HMgAQQGXDhgUMADgJkgDJQUSAGDRYQEADQYmAJDSYUeCByZelFiQqkOrA6U6HAqV6cUAADQK
                BCvzYs2bA2yqNIAAAIMBM+PKdRkQADs=
                ';

        $grkgifs{ldigamma} = '
                R0lGODlhGAAYAPcAAAQCBJSWlNTW1LSytFRSVKSmpOzy7Ly+vHR6dJyanOTi5FRWVKyqrPz+/MTC
                xAFn0OxpAnFmAmQAAF/eAGdWAAGaAIDC1wH2KwB+QQC2/wD21wC2Fo56JwEGpQAW1wCaFq/yTFkq
                UNf6xivKFv/aABUGAACGAADGAABKjwAmFgDuLgCqdAwWAHPSAAluAlI2dACSAAGyAAB2jgAOAJ8e
                dtCOAABeAAA+AICyVqR+H3b2AAAuAM7+AOnOAEvexQAAFWYArwAAFwD/SwD/AJgAZaQCAHYPRAAo
                vGz3YqS/gHa2AQBRAPJoALJzAE4oAAAAANm3AP8BAP8AEP8AAAAXAABqAAAAGAABAO8AAOgAAEuf
                AADQwNgAO7AA0HYnEgBqACcAAAAAAAAnIwAcApiPAKSxAHb5AAC/AGwDRKQAdHbeAAB0AOQDjxwA
                FlTPSABAdH8AAAgAAPpGxb+XFfzur04TF/X34L+/u/9sYv+jgP92yv8AFf9Qr//wF/+az/+BFhUQ
                xgRSFgCfAACBAABzAACxAAD5dQC/AQgAzwAwFgB2ZAAAdOIOABOhAPf3AL+/AH8mBwGzAAD3AAC/
                AGQAh87wAfeadb+BAfcAAEEAAPcAAL8AABQAAFIAAJ8AAIEAAPp/ANoIAPf6AL+/AJDgAJRVAPxQ
                AL8AABWUrwSjFwB2hwAAAUBWJwCrAAD4AAC/AIwI/6Lm/3YA/wCA/yQgJ9tcAPcAAL+AAFwg2Deq
                sKkAdoGAAECYAAAQAAABAACAABQAuFIBpJ8AdoEAABMQCAGqtQAAS8CAABTkmFIcpJ9UdoEAAEB/
                8wAIsgD6TgC/ABX8zAROpAD1dgC/AIC0f0ukCAN2+tIAv9Trb6O2p3b5dgC/AP0E1/Tw//dO/78A
                f/8MSP/wp/9Odv8AAIDc5ACbHAD8VAC/AAO0fwCjCAB2+gAAv0MA5DoBHFwAVGIAAG/gAG9VAGtQ
                AHMAAFwAr3IASXQAR2bQAFyMSHAIp3IAdmUAAHAcSFwsp3Q8dmXQACH5BAAAAAAALAAAAAAYABgA
                BwhXABsIHEiwoMGDCBMqXMiwocOHECNKnKhQAIIFBDAuGBAxAYADAgckiBgAgIOBAjp+bKBgYskC
                BQJM9MhApEuTFBt4BEmx5EmKO3P6zOnx500DOZMqlRgQADs=
                ';

        $grkgifs{lepsilon} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpFRWVOTq5BQSFDQyNLS6tGRmZPz+/AD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOVDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABtlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJlAAAAAABwAAAAAABzAAAAAHBpALcAABVsAAAAAHBvABYAAPhuAHcAAP8ucP8At/9iFf8AAHxt
                cKIAtxJwFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QG/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0W6KlpxJOEgAAAJw84/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhiABkIHEiwoMGDCBMqXMiwocOHECNKnEjxoQIBAAAgWHAAYgAACwQuAEAAIgIABBMkMImyYgEA
                ASoyGJBxAYKSEF/GpHhS5smOAwmsdPgyQccDI4c6HGDgJAABBWRKnUpVYUAAOw==
                ';

        $grkgifs{leta} = '
                R0lGODlhGAAYAPcAAAQCBJSWlERCRNTa1LS6tGRmZCQiJBQSFKSqpFRWVPz+/MTKxHR2dAD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOlDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABdlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJlAAAAAAB0AAAAAABhAAAAAHAuALcAABViAAAAAHBtABYAAPhwAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QF/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0V6KlpxJOEgAAAJw85/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhmABUIHEiwoMGDCBMqXMiwocOHEB8OMHAAgQIGAAAIeJhgAYADDBYoCACggEMACjIOGAjAAMSM
                BGE+lCmQZkObNhniRDmTZ02fN4HmXLjzpVCgEVMijTjUaFKCB5ZCFACAwNOrDwMCADs=
                ';

        $grkgifs{lgamma} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJnAAAAAABhAAAAAABtAAAAAHBtALcAABVhAAAAAHAuABYAAPhiAHcAAP9tcP8At/9wFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                Bwh0AB8IHEiwoMGDCBMqXMiwocOHBg8QABCA4AAAAhoaAMBxwcCNAxoiSPBAQMUHBwAYcAhAYIOM
                DwIAOABRYMsHCFbWLHmgAIKdAh0MYHByZwIFP4E+uFgUKAGlAg/AVJogqVIBN5UiyAoUwFOoDBxA
                HUt2Z0AAOw==
                ';

        $grkgifs{liota} = '
                R0lGODlhGAAYAPcAAAQCBJSWlERCRNTa1CQiJFRWVPz+/BQSFLS6tOTq5GRmZAAAAAD/RQD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOhDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABhlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJpAAAAAABvAAAAAAB0AAAAAHBhALcAABUuAAAAAHBiABYAAPhtAHcAAP9wcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGP9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGAATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WKKlpxJOEgAAAJw85vml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhGAA0IHEiwoMGDCBMqXMiwocOHECNKnEixosQEAQoAoHgAgMeKAz5WFEmR5ESTElFGVAlR5IGJ
                BAAMCKBgIoKYAizq3MkwIAA7
                ';

        $grkgifs{lkappa} = '
                R0lGODlhGAAYAPcAAAQCBISGhMTKxERCRCQiJKSqpOTq5FRWVBQSFJSWlNTa1DQyNLS6tPz+/GRm
                ZAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJrAAAAAABhAAAAAABwAAAAAHBwALcAABVhAAAAAHAuABYAAPhiAHcAAP9tcP8At/9wFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhmABsIHEiwoMGDCBMqXMiwocOHECNKnEiRoYEEBwAQFLAAwACGBAgA0CgQYwACCxyOFFgggMSV
                BRxMHFmAAMWRHRPM1ChSwEuNChAg+CmQAYCUEFeWBHBAwUOlAh2MJFmxqtWrCgMCADs=
                ';

        $grkgifs{lkoppa} = '
                R0lGODlhGAAYAPcAAAQCBIyOjNTW1FRSVKyyrPTy9GxqbKSmpJSWlNze3GRmZFxWXLy+vPz+/Jya
                nDw6PNzW3FRWVLS2tPT29Hx6fJSalOTi5AH2KwB+QQC2/wD21wC2Fo56JwEGpQAW1wCaFq/yTFkq
                UNf6xivKFv/aABUGAACGAADGAABKjwAmFgDuLgCqdAwWAHPSAAluAlI2dACSAAGyAAB2jgAOAJ8e
                dtCOAABeAAA+AICyVqR+H3b2AAAuAM7+AOnOAEvexQAAFWYArwAAFwD/SwD/AJgAZaQCAHYPRAAo
                vGz3YqS/gHa2AQBRAPJoALJzAE4oAAAAANu3AP8BAP8AEP8AAAAXAABqAAAAGAABAO8AAOgAAEuf
                AADQwNgAO7AA0HYnEgBqACUAAAAAAAAnIwAcApiPAKSxAHb5AAC/AGwDRKQAdHbeAAB0AOQDjxwA
                FlTPSABAdH8AAAgAAPpGxb+XFfzur04TF/X34L+/u/9sYv+jgP92yv8AFf9Qr//wF/+az/+BFh8Q
                xgRSFgCfAACBAABzAACxAAD5dQC/AQgAzwAwFgB2ZAAAdOIOABOhAPf3AL+/AH8mBwGzAAD3AAC/
                AGQAh87wAfeadb+BAfcAAEEAAPcAAL8AABQAAFIAAJ8AAIEAAPp/ANoIAPf6AL+/AJDgAJRVAPxQ
                AL8AAB+UrwSjFwB2hwAAAUBWJQCrAAD4AAC/AIwI/6Lm/3YA/wCA/yQgJdtcAPcAAL+AAFwg2Deq
                sKkAdoGAAECYAAAQAAABAACAABQAuFIBpJ8AdoEAABMQCAGqtQAAS8CAABTkmFIcpJ9UdoEAAEB/
                8wAIsgD6TgC/AB/8zAROpAD1dgC/AIC0f0ukCAN2+tIAv9TrbaO2p3b5dgC/AP0E2fTw//dO/78A
                f/8MSP/wp/9Odv8AAIDc5ACbHAD8VAC/AAO0fwCjCAB2+gAAv0MA5DoBHFwAVGIAAG/gAG9VAGtQ
                AHMAAFwAr3IASXQAR2bQAFyMSHAIp3IAdmUAAHAcSFwsp3Q8dmXQACH5BAAAAAAALAAAAAAYABgA
                BwhfABsIHEiwoMGDCBMqXMiwocOHECM2EACAgMSBAQBMuCgQgAGOEwEcAOkAQAKQDwAMiDBgwQCI
                CQDInBkBZAEACEASACAAJAUAIBsAUAAypkWOCABYACmAQdCnUKMyDAgAOw==
                ';

        $grkgifs{llambda} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOZDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABplAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJsAAAAAABhAAAAAABtAAAAAHBiALcAABVkAAAAAHBhABYAAPguAHcAAP9icP8At/9tFf8AAHxw
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGv9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGgATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WqKlpxJOEgAAAJw85Pml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiBAB8IHEiwoMGDCBMqXMiwIUMBABw4NBhAwYMEBSYSZLBAoEWNAgEMlAiyYIMGJQkeIJnywQEG
                LQUaENnyAAAAKFMGAEDAQEsEABYg0AnAooKcGgkAGPCgAEuHBQAIGEhgIM2FSpkKFOAzwdCFDXgS
                jHrT50KIGQk6AAAzptu3DAMCADs=
                ';

        $grkgifs{lmu} = '
                R0lGODlhGAAYAPcAAAQCBJSWlERCRNTa1CQiJGRmZLS6tBQSFFRWVPz+/DQyNHR2dMTKxAD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOpDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABZlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJtAAAAAAB1AAAAAAAuAAAAAHBiALcAABVtAAAAAHBwABYAAPgAAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QFv9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFgATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0VqKlpxJOEgAAAJw86Pml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhlABMIHEiwoMGDCBMqXMiwocOHECNKJAgAAEWLDytehKhxYEeHHxOEZBhy5MKSGEGmFLmS5EqT
                ClEKPNCwYoEEDBYcADAgwE2SAgAQMJDAAAEAAkBOHGigZUQETjlGfShAwdKlAQEAOw==
                ';

        $grkgifs{lnu} = '
                R0lGODlhGAAYAPcAAAQCBKSqpERCRNTa1CQiJGRmZPz+/BQSFLS6tFRWVOTq5DQyNHR2dAD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOpDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABZlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJuAAAAAAB1AAAAAAAuAAAAAHBiALcAABVtAAAAAHBwABYAAPgAAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QFv9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFgATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0VqKlpxJOEgAAAJw86Pml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhiAA0IHEiwoMGDCBMqXMiwocOHECNKnEix4sMBDAgUKLhgQUMBCwAcKCjyIQEACAgC2OgwwEqV
                CiACADAwAMuHCQAEEEggJkSXCQzYnHiAZs+JBQAsuBkRwUyfRJlanEpVYUAAOw==
                ';

        $grkgifs{lomega} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJvAAAAAABtAAAAAABlAAAAAHBnALcAABVhAAAAAHAuABYAAPhiAHcAAP9tcP8At/9wFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiKAB8IHEiwoMGDCBMqXMiwocOHECNKnEix4QIDBAAIBEDAwIKGBQAwaECwAQMABRYu4DjQgIKB
                Jz8mNIByIACNAhsAMKAw4wGbODcSUHiTIAAERoMeLDpQwUugCk8STJDS5tCEAWoKdDpQJ8+oBH4m
                QDAgwYMDDBD8XOgAAQABHxtkhFuxrt27DAMCADs=
                ';

        $grkgifs{lomicron} = '
                R0lGODlhGAAYAPcAAAQCBISGhFRWVMTKxCQiJOTq5KSqpHR2dBQSFGRmZNTa1DQyNPz+/LS6tAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOVDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABtlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJvAAAAAABtAAAAAABpAAAAAHBjALcAABVyAAAAAHBvABYAAPhuAHcAAP8ucP8At/9iFf8AAHxt
                cKIAtxJwFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QG/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0W6KlpxJOEgAAAJw84/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhuABkIHEiwoMGDCBMqXMiwocOHECNKnEjx4QABAAAsaBDRAAKOBTAeeFgAgAGCBAAMcJgAQEED
                AAQ4TFmwpMuGGQ3mbIgAgIKCAAg4xBgAaAKHAwAgIAizwMMDGp0OQHASYoMFGQWsrMi1q1eHAQEA
                Ow==
                ';

        $grkgifs{lphi} = '
                R0lGODlhGAAYAPcAAAQCBISGhMTKxERCRCQiJKSqpOTq5FRWVBQSFJSWlNTa1DQyNLS6tPz+/GRm
                ZAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOlDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABdlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJwAAAAAABoAAAAAABpAAAAAHAuALcAABViAAAAAHBtABYAAPhwAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QF/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0V6KlpxJOEgAAAJw85/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiCABsIHEiwoMGDCBMqXMiwocOHECNKLOgAQQMFAwAQCPBwAQIBDQ6AdADAQcMAABIIBDAwYwGG
                CwAoWDmQAYABDAGwpDlQZ86dDYAGFYqQAFChGhmSZMCzQQEAHBcquNmUAAGHTw8YYFnA6kyHCg4g
                0DlA5USiEtFGVAuR7UO3ExEGBAA7
                ';

        $grkgifs{lpi} = '
                R0lGODlhGAAYAPcAAAQCBISGhMTKxERCRCQiJKSqpOTq5GRmZBQSFJSWlNTa1DQyNLS6tPz+/HR2
                dAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOpDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABZlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJwAAAAAABpAAAAAAAuAAAAAHBiALcAABVtAAAAAHBwABYAAPgAAHcAAP8AcP8At/8AFf8AAHwA
                cKIAtxIAFQAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFQAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QFv9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFgATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABZw
                cwC3cgAVTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0VqKlpxJOEgAAAJw86Pml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhyABsIHEiwoMGDCBMqXMiwocOHECNKnJhQAAEAGDNmbIhAo0cADB0sMNAAZAMBAAI4JCCggQIE
                AgOkjMhggMADAApEdGCzwQAALSEScCDwYkSZKkuadKgAY1CnLxtehFk044GGPxMMtAigJ8WvYMOK
                fRgQADs=
                ';

        $grkgifs{lpsi} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJOTq5GRmZBQSFJSWlNTa1DQyNPz+/HR2dAD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOlDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABdlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJwAAAAAABzAAAAAABpAAAAAAAuALoAABRiAAAAAHBtABYAAPhwAHcAAP8AAP8Auv8AFP8AAHwA
                AKIAuhIAFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QF/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0V6KlpxJOEgAAAJw85/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiFABcIHEiwoMGDCBMqXMiwocOHECNKXEAAgACCAAgKAEBAYUUDAzMKNMBxYYCSAkVSBBBg4QAA
                KmMCGLCwAMwEKQXaBIBzIUyaC0S+VKlQAQAEORcgAKCg4UmQQUeydEjgQNIDVh0mOKDAZgEFB3o6
                LMCgIgEDBSZGVZuULdGJbyXGZZswIAA7
                ';

        $grkgifs{lrho} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJGRmZOTq5KSqpBQSFFRWVNTa1DQyNHR2dPz+/LS6
                tAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOlDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABdlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJyAAAAAABoAAAAAABvAAAAAAAuALoAABRiAAAAAHBtABYAAPhwAHcAAP8AAP8Auv8AFP8AAHwA
                AKIAuhIAFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QF/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0V6KlpxJOEgAAAJw85/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhzABsIHEiwoMGDCBMqXMiwocOHECM2GJAAAIAEAyIyYCDwAAIABx46AEBQwUcHDgWQJBgAwAKH
                FgsqiNmQJkGbC3EKdAlz5cCZAXpmHJiAwEOLAjIaKIBAwVEAClQiKBBRZ1WfEhtYfWiAZ9YGIwV8
                HTs2IAA7
                ';

        $grkgifs{lsampi} = '
                R0lGODlhGAAYAPcAAAQCBIyKjNTW1KyyrFRWVPTy9Ly+vGxqbJyanNze3LSytGRmZPz+/Dw6PJSW
                lFxWXPT29LzCvHx6fKSmpOTi5LS2tIDi1wH2KwB+QQC2/wD21wC2Fo56JwEGpQAW1wCaFq/yTFkq
                UNf6xivKFv/aABUGAACGAADGAABKjwAmFgDuLgCqdAwWAHPSAAluAlI2dACSAAGyAAB2jgAOAJ8e
                dtCOAABeAAA+AICyVqR+H3b2AAAuAM7+AOnOAEvexQAAFWYArwAAFwD/SwD/AJgAZaQCAHYPRAAo
                vGz3YqS/gHa2AQBRAPJoALJzAE4oAAAAANu3AP8BAP8AEP8AAAAXAABqAAAAGAABAO8AAOgAAEuf
                AADQwNgAO7AA0HYnEgBqACUAAAAAAAAnIwAcApiPAKSxAHb5AAC/AGwDRKQAdHbeAAB0AOQDjxwA
                FlTPSABAdH8AAAgAAPpGxb+XFfzur04TF/X34L+/u/9sYv+jgP92yv8AFf9Qr//wF/+az/+BFjsQ
                xgRSFgCfAACBAABzAACxAAD5dQC/AQgAzwAwFgB2ZAAAdOIOABOhAPf3AL+/AH8mBwGzAAD3AAC/
                AGQAh87wAfeadb+BAfcAAEEAAPcAAL8AABQAAFIAAJ8AAIEAAPp/ANoIAPf6AL+/AJDgAJRVAPxQ
                AL8AADuUrwSjFwB2hwAAAUBWJQCrAAD4AAC/AIwI/6Lm/3YA/wCA/yQgJdtcAPcAAL+AAFwg2Deq
                sKkAdoGAAECYAAAQAAABAACAABQAuFIBpJ8AdoEAABMQCAGqtQAAS8CAABTkmFIcpJ9UdoEAAEB/
                8wAIsgD6TgC/ADv8zAROpAD1dgC/AIC0f0ukCAN2+tIAv9TrbaO2p3b5dgC/AP0E2fTw//dO/78A
                f/8MSP/wp/9Odv8AAIDc5ACbHAD8VAC/AAO0fwCjCAB2+gAAv0MA5DoBHFwAVGIAAG/gAG9VAGtQ
                AHMAAFwAr3IASXQAR2bQAFyMSHAIp3IAdmUAAHAcSFwsp3Q8dmXQACH5BAAAAAAALAAAAAAYABgA
                BwhhABkIHEiwoMGDCBMqXMiwocOHEB8aiBCxIAQJDwRUJDgAwISNAwUAkABSYMePIDsCSFBRwIEJ
                EAAEqEihAAOVGyEsqEABAIWcAhtUKMkggAOiERAQpbCAKAMCTqNKnWowIAA7
                ';

        $grkgifs{lsigma} = '
                R0lGODlhGAAYAPcAAAQCBISGhNTa1ERCRCQiJKSqpPz+/BQSFJSWlOTq5GRmZDQyNLS6tAD/AAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJzAAAAAABpAAAAAABnAAAAAABtALoAABRhAAAAAHAuABYAAPhiAHcAAP9tAP8Auv9wFP8AAHwA
                AKIAuhIAFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhuAA0IHEiwoMGDCBMqXMiwocOHECNKnEjRYYEBADJqBOBQwcaPDQtkDJDAgIIAEDEiILhAwcOM
                BUUycAizIIAFDgkAKEmwJsMAAAoQTADgwMMDRgcCdelQwIEFAgwweBoxgYIDAAigrMi1q9eHAQEA
                Ow==
                ';

        $grkgifs{lsigmae} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJOTq5KSqpFRWVBQSFNTa1DQyNPz+/LS6tGRmZAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOZDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABplAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJzAAAAAABpAAAAAABnAAAAAABtALoAABRhAAAAAHBlABYAAPguAHcAAP9iAP8Auv9tFP8AAHxw
                AKIAuhIAFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGv9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGgATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WqKlpxJOEgAAAJw85Pml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhiABcIHEiwoMGDCBMqXMiwocOHECNKPBiAAAAEBiQqAMDxYkQBBwosYCBAAUQDAiYOPMBApUAE
                LgUCiLkAgEiXBxQkcJkAQUcABHZCTCDgZ0qXA2bGVOrSpMsGLTUCzUhTYUAAOw==
                ';

        $grkgifs{lstigma} = '
                R0lGODlhGAAYAPcAAAQCBIyKjNTW1FRSVKyqrGxqbJyanPT29Ly+vHR6dDw6PJSWlNze3FxWXHx6
                fIyOjFRWVLSytKSmpPz+/MTCxDw+PNzi3Hx+fAB+QQC2/wD21wC2Fo56JwEGpQAW1wCaFq/yTFkq
                UNf6xivKFv/aABUGAACGAADGAABKjwAmFgDuLgCqdAwWAHPSAAluAlI2dACSAAGyAAB2jgAOAJ8e
                dtCOAABeAAA+AICyVqR+H3b2AAAuAM7+AOnOAEvexQAAFWYArwAAFwD/SwD/AJgAZaQCAHYPRAAo
                vGz3YqS/gHa2AQBRAPJoALJzAE4oAAAAANq3AP8BAP8AEP8AAAAXAABqAAAAGAABAO8AAOgAAEuf
                AADQwNgAO7AA0HYnEgBqACYAAAAAAAAnIwAcApiPAKSxAHb5AAC/AGwDRKQAdHbeAAB0AOQDjxwA
                FlTPSABAdH8AAAgAAPpGxb+XFfzur04TF/X34L+/u/9sYv+jgP92yv8AFf9Qr//wF/+az/+BFlEQ
                xgRSFgCfAACBAABzAACxAAD5dQC/AQgAzwAwFgB2ZAAAdOIOABOhAPf3AL+/AH8mBwGzAAD3AAC/
                AGQAh87wAfeadb+BAfcAAEEAAPcAAL8AABQAAFIAAJ8AAIEAAPp/ANoIAPf6AL+/AJDgAJRVAPxQ
                AL8AAFGUrwSjFwB2hwAAAUBWJgCrAAD4AAC/AIwI/6Lm/3YA/wCA/yQgJttcAPcAAL+AAFwg2Deq
                sKkAdoGAAECYAAAQAAABAACAABQAuFIBpJ8AdoEAABMQCAGqtQAAS8CAABTkmFIcpJ9UdoEAAEB/
                8wAIsgD6TgC/AFH8zAROpAD1dgC/AIC0f0ukCAN2+tIAv9TrbqO2p3b5dgC/AP0E2PTw//dO/78A
                f/8MSP/wp/9Odv8AAIDc5ACbHAD8VAC/AAO0fwCjCAB2+gAAv0MA5DoBHFwAVGIAAG/gAG9VAGtQ
                AHMAAFwAr3IASXQAR2bQAFyMSHAIp3IAdmUAAHAcSFwsp3Q8dmXQACH5BAAAAAAALAAAAAAYABgA
                BwhoACcIHEiwoMGDCBMqXMiwocOHECNKnEjR4QECDwZAGFBBwEMBAEKKVPDwAAACFCggoODxoQQH
                FScYMBBzAcmKIAswqGggpIICCyxIpOCggkgEMQ0kiCngwsQADhYAiDCxQUiqMbMyDAgAOw==
                ';

        $grkgifs{ltau} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRNTa1CQiJKSqpGRmZPz+/BQSFJSWlFRWVOTq5DQyNLS6tHR2
                dAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOlDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABdlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJ0AAAAAABhAAAAAAB1AAAAAAAuALoAABRiAAAAAHBtABYAAPhwAHcAAP8AAP8Auv8AFP8AAHwA
                AKIAuhIAFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QF/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0V6KlpxJOEgAAAJw85/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhaAA8IHEiwoMGDCBMqXMiwocOHECNKnEjRYQEEADJqfLgAo8aNDh0oODAAgAGJBBYcKAAgQEUH
                ABJUFABgQEUCACoeyKgzo8wGBFB+dBlxAAMACBzoXMq06cKAADs=
                ';

        $grkgifs{ltheta} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJGRmZOTq5BQSFKSqpFRWVNTa1DQyNHR2dPz+/AD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOdDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABllAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJ0AAAAAABoAAAAAABlAAAAAAB0ALoAABRhAAAAAHAuABYAAPhiAHcAAP9tAP8Auv9wFP8AAHwA
                AKIAuhIAFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WaKlpxJOEgAAAJw85fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiDABsIHEiwoMGDCBMqXMiwocMGBQ4ASKDg4cAFBQQyOFDxYQIBBAWAdGgAAAKCCAAMcMgAQEeB
                CgBkbCgAgEEAIxlKvGmzIYCfQIM6/MlzaE+CRGkCMECwZM6FBVQSHACAgUOqVgcGcPlQAAGCBBJY
                NHBgZoEFFgUaiCozrdu3cOMuDAgAOw==
                ';

        $grkgifs{lupsilon} = '
                R0lGODlhGAAYAPcAAAQCBJSWlFRWVNTa1CQiJLS6tHR2dPz+/BQSFKSqpGRmZOTq5DQyNMTKxAD/
                AAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOVDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABtlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJ1AAAAAABwAAAAAABzAAAAAABpALoAABRsAAAAAHBvABYAAPhuAHcAAP8uAP8Auv9iFP8AAHxt
                AKIAuhJwFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QG/9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGwATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0W6KlpxJOEgAAAJw84/ml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwhuAA8IHEiwoMGDCBMqXMiwocOHECNKnEiR4QACCBIMRKDgoYAGABAMbICAgUMABwCgHJgAQICH
                KgkuAGDy5MqBMW0WzNmQp0AABGDePADSwEMGAAYMNIBgwcMCNJ0GQFAgYgGkAAQorci1q1eHAQEA
                Ow==
                ';

        $grkgifs{lxi} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOpDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABZlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJ4AAAAAABpAAAAAAAuAAAAAABiALoAABRtAAAAAHBwABYAAPgAAHcAAP8AAP8Auv8AFP8AAHwA
                AKIAuhIAFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QFv9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFgATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0VqKlpxJOEgAAAJw86Pml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwiBAB8IHEiwoMGDAxMgQMiwIIAFAgsQWNjQIIEEDxgAAOCgosEFCjYKKODxYACMJRFSTHmQQYEB
                BggAIMBS4AEEMmcGqPlAwACeBBlABCowwE6iAgkcQCoQAFOBCH4yNSD0KQKRGwEI4GngalYABp4m
                cPqULFMGTw00IKqRwNqnDQMCADs=
                ';

        $grkgifs{lzeta} = '
                R0lGODlhGAAYAPcAAAQCBJSWlERCRNTa1CQiJLS6tGRmZPz+/BQSFKSqpFRWVOTq5DQyNMTKxHR2
                dAD/AACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOhDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABhlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhsALEA
                ABJ6AAAAAABlAAAAAAB0AAAAAABhALoAABQuAAAAAHBiABYAAPhtAHcAAP9wAP8Auv8AFP8AAHwA
                AKIAuhIAFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QGP9gAP8TAP8AAADh/wAb/wDo/wB3/wDoGAATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0WKKlpxJOEgAAAJw85vml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                Bwh3AA8IHEiwoMGDBAcwQMiwIIIGAhsIANDw4MMDDgAASFDRYAICABAYgNjR4AAHJRkqSInQAUmW
                BBcIgGkwQACaBQUMwEkQAU+CFH8KDCoUQQGhBwxc/DkAgcanOmEOUPBU40qhAYj+1MpzoVADR3Ey
                AEDgJtKGAQEAOw==
                ';

        $grkgifs{nch} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOpDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABZlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhuALEA
                ABJjAAAAAABoAAAAAAAuAAAAAABiALoAABRtAAAAAHBwABYAAPgAAHcAAP8AAP8Auv8AFP8AAHwA
                AKIAuhIAFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QFv9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFgATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0VqKlpxJOEgAAAJw86Pml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                Bwi8AB8IHEiwoMGDCBMqXMiwocOHEBMeIAAgAMEBAAQ8mAigwECMBAQaAEBywcCRAx6MBIBgoICO
                AhEkeCDA4kYABgQScPBAgUeQAwEIbKDxQQAABwQKfbAg50uPBpciyGmQANCDAg4UaIn1KUIHAxjY
                NHg0JMIECrhihYkQ49iCVxOaXbsU4YGiBkEqSHlWbcGnCWYifHkQ6AIFQQsiqEvQ6wOrRhkUBDD3
                I+WBDkhWLMiA51+2Al/ijUh6YUAAOw==
                ';

        $grkgifs{ng} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOtDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABVlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhuALEA
                ABJnAAAAAAAuAAAAAABiAAAAAABtALoAABRwAAAAAHAAABYAAPgAAHcAAP8AAP8Auv8AFP8AAHwA
                AKIAuhIAFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QFf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0VaKlpxJOEgAAAJw86fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwilAB8IHEiwoMGDCBMqXMiwocOHECNCPEAAQACCAwAIoGgRo0aBBgCIXDAw5ICQI0sCGCAQQYIH
                Ai4+OADAwAOXMGXStCkQgMAGAgQGAHDggc8HQIUSPXgUAU+CTZ8W3FgAwUGqVhE6GMBAZsGtXRMm
                UJDV4NiyBzN6Lah2IQGFbxUeCIpw7sIEaAviXSjg6FW/CBEALih4IYC4TBEjZOAgIWOJDAMCADs=
                ';

        $grkgifs{nk} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOtDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABVlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhuALEA
                ABJrAAAAAAAuAAAAAABiAAAAAABtALoAABRwAAAAAHAAABYAAPgAAHcAAP8AAP8Auv8AFP8AAHwA
                AKIAuhIAFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QFf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0VaKlpxJOEgAAAJw86fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwirAB8IHEiwoMGDCBMqXMiwocOHECNCPEAAQACCAwAIOJBAAQCMDDQ+MACg5IKBJAcQqPhRYMcA
                BBg8QJDggYCLDw4AMDCwpMACOHsKbCBAYAAAB3p+LMAzYUsETQWWLEBg4cYCCAqWDFkzoYMBDIJK
                /VhxQMKOWbV+XIAg7cGMYscOBSATYVWDPl0CUHCy4IGieFsKJJl3YAK3Em0KToxgsUQAdxM/YOBA
                suWAADs=
                ';

        $grkgifs{nx} = '
                R0lGODlhGAAYAPcAAAQCBISGhERCRMTKxCQiJKSqpGRmZOTq5BQSFJSWlFRWVNTa1DQyNLS6tHR2
                dPz+/ACE2AClIQASEwAAAAAaxAACowAAEgAAABAIAAAAAgAAAAAAAACEgAClpQASEgAAABDh9KJm
                ZBL4+wB3dwBg8ADcMAD8+AB3dxbA/yZm//v4/3d3/wB4kABmpRP4EgB3AMgAMmDsjRP9/AB/dwAA
                eAAAEwAAEwAAAIADCqQAAhIAAAAAADcAGrYAAksAAAAAAGYgAABCAACOAAAAAJgAAKQAABKOAAAA
                AGwkMKSjpxISEgAAAHICZHIAp04AEgAAAOtDAP8AAP86AP8AAABcAAAAAAByAAAAAFh0ALUAAEtm
                AAAAABhcALEAABJ0AAAAABVlAAAAAABzAAAAAJh0AKQAABJcAAAAAGwxAKQAABJcAAAAABhuALEA
                ABJ4AAAAAAAuAAAAAABiAAAAAABtALoAABRwAAAAAHAAABYAAPgAAHcAAP8AAP8Auv8AFP8AAHwA
                AKIAuhIAFAAAAK0AADkAAOkAAHcAAAAAAAAAsBMAFAAAAAAAAAAAAAAAAAAAAAgAB3gAABUAAAAA
                ABYAEAAApQAAEsAAANAAAGAAABMAAAAAAACQAACjAAASAAAAAH6tAAATAADpAMB3AAAAAAAAAAAA
                AAAAAP8AqP8ApP8AEv8AAP/QFf9gAP8TAP8AAADh/wAb/wDo/wB3/wDoFQATAADpAAB3AACwGACj
                sQASEgAAAADgAAAbABPoAAB3AGgAuAAApAAAEgAAAAAArmAAgRMASwAAAKkAmDMApOkAEncAABYA
                cwC6cgAUTsAAAAG0zKOkpBISEgAAAABBAAETAADpAAB3ACA0VaKlpxJOEgAAAJw86fml/xJO/wAA
                f5zgQPkbpxLoEgB3APSwGGSjsfsSEncAAHAAABYAAPgAAHcAAP+AGP/7sf9PEv8AAFwAGKMAExIA
                6QAAd6UArxoAAukAR3cAAADsQACjpxMSEgAAAABFQAAApwAAEgAAACH5BAAAAAAALAAAAAAYABgA
                BwjGAB8IHEiwoMGDCAUmQJCw4UAACwQWIMDQYUECCR4wAADAgcWCCxRwFFDgo8EAGU0erHjwAAEA
                AQgOACBgIIMCAwy8JDDQAEeIPQEMGHgAwUsABGIKRJBRgNIDAAwQFDD0IACBDWo+CADggM2IFq8+
                QCBVYAClFgUcKMDyAQGvHx0MYID2gdiPCRS0HVvV4sy6DwwwAGuRp0EEI39qLXhgcUEDiH9GNbjQ
                ZIK7AwVgdrh5bOeEDAwiNWmggUEGHhtuJGBaZcOAADs=
                ';

        $grkgifs{oulig} = '
                R0lGODlhGAAYAPcAAAQCBISChMTCxERCRCQiJNzi3JyenBQSFMzSzGRiZDQyNIySjOzy7KyurCQq
                JHRydPT69AwKDMTKxBwaHNTa1Ly2vIyKjFRSVDw6PJyanLSutDQuNHx6fAwGDBwWHJSalPTy9Cwq
                LPz6/MzKzNza3AQGBISGhMTGxExKTCQmJOzu7KyqrBQWFNTS1GxubDQ2NJSSlKyyrHR2dBQOFBwe
                HIyOjFxeXDw+PLSytHx+fPT29CwuLPz+/MzOzNze3AAAFWYArwAAFwD/SwD/AJgAZaQCAHYPRAAo
                vGz3YqS/gHa2AQBRAPJoALJzAE4oAAAAANy3AP8BAP8AEP8AAAAXAABqAAAAGAABAO8AAOgAAEuf
                AADQwNgAO7AA0HYnEgBqACQAAAAAAAAnIwAcApiPAKSxAHb5AAC/AGwDRKQAdHbeAAB0AOQDjxwA
                FlTPSABAdH8AAAgAAPpGxb+XFfwAr04AF/VW4L+yu/8DYv8AgP8Iyv90Ff8Cr/8AF/8nz/8GFhRW
                xgEfFtYvAAECAIBzAHSxALf5dTK/ASgAzyswFgN2ZAAAdEeqAAABAHYTAAAEAGC8B6IBAHYAAACQ
                AKlph3PPAfcAdb9AAQRoAAHPAAAAAAAAABYAAAAAAAAAAAAAAEN/ADoIAFz6AGK/AG/gAG9VAGtQ
                AHMAAFyUr3KjF892hxYAAQdWJACrAAD4AAC/AI4I/3Lm/8QA/0aA/wAgJABcAAAAAACAAIcg2AGq
                sAAAdgCAAJiYAKIQAHYBAACAAHsAuLcBpPcAdr8AAPcQCEGqtfcAS7+AAJDkmJQcpPxUdr8AAJZ/
                87cIsvf6Tr+/AJD8zJROpPz1dr+/AIe0fwGkCAB2+gAAv7DrbKK2p3b5dgC/ACgE2rjw//dO/78A
                f1wMSDfwp6lOdoEAAPfc5EGbHPf8VL+/AJC0f5SjCPx2+r8Av04A5LgBHPcAVL8AAAHgAABVAABQ
                AAAAAAEArwAASTMARwLQALeMSAEIp88AdkAAAAAcSAAsp0Y8dpfQACH5BAAAAAAALAAAAAAYABgA
                Bwi7AHkIHEiwoMGDCBMqXMiwocOHECOC6AEhIkEVLSzyEGHCwoYdIAQyWGCi4sIWAAB0SCBCoIYS
                ADQwhAGghAccAiHcKNHBwEaFBTx4mIGiQYMXKneQaLiiQcqaKh1IcDjiRAeoHWbIbEhhwA2VBy48
                CGHDpEIQN652gCGAhIgPHWowjFGC54CBDHYAeMCwgsoOHAa2KBHBBUMfBFJ2CEAjRIS6GRkWGIDB
                g0qVKTJELGBCRoAAkTWKHq0xIAA7
                ';

        for my $image ( keys %attributes ) {
            $lglobal{images}->{$image} = $top->Photo(
                -format => 'gif',
                -data   => $grkgifs{$image},
            );
        }
        $lglobal{grpop} = $top->Toplevel;
        $lglobal{grpop}->title('Greek Transliteration');
        my $tframe = $lglobal{grpop}
            ->Frame->pack( -expand => 'no', -fill => 'none', -anchor => 'n' );
        my $glatin = $tframe->Radiobutton(
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
            -activebackground => $activecolor,
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
            -activebackground => $activecolor,
            -command          => \&movegreek,
            -text             => 'Transfer',
        )->grid( -row => 1, -column => 6 );
        $tframe->Button(
            -activebackground => $activecolor,
            -command          => sub { movegreek(); findandextractgreek(); },
            -text             => 'Transfer and get next',
        )->grid( -row => 1, -column => 7 );
        if ( $Tk::version ge 8.4 ) {
            my $tframe2 = $lglobal{grpop}->Frame->pack(
                -expand => 'no',
                -fill   => 'none',
                -anchor => 'n',
                -pady   => 3
            );
            $tframe2->Button(
                -activebackground => $activecolor,
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
                -activebackground => $activecolor,
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
                        ->insert( $start, fromgreektr($selection) );
                    if ( $lglobal{grtext}->get( 'end -1c', 'end' ) =~ /^$/ ) {
                        $lglobal{grtext}->delete( 'end -1c', 'end' );
                    }
                },
                -text => 'Greek->ASCII',
            )->grid( -row => 1, -column => 2, -padx => 2 );
            $tframe2->Button(
                -activebackground => $activecolor,
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
                    $lglobal{grtext}->insert( $start,
                        betagreek( 'unicode', $selection ) );
                    if ( $lglobal{grtext}->get( 'end -1c', 'end' ) =~ /^$/ ) {
                        $lglobal{grtext}->delete( 'end -1c', 'end' );
                    }
                },
                -text => 'Beta code->Unicode',
            )->grid( -row => 1, -column => 3, -padx => 2 );
            $tframe2->Button(
                -activebackground => $activecolor,
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
        my $frame = $lglobal{grpop}->Frame( -background => 'white' )
            ->pack( -expand => 'no', -fill => 'none', -anchor => 'n' );
        my $index = 0;
        for my $column (@greek) {
            my $row = 1;
            $index++;
            $frame->Label(
                -text       => ${$column}[0],
                -font       => $grfont,
                -background => 'white',
            )->grid( -row => $row, -column => $index, -padx => 2 );
            $row++;
            $lglobal{buttons}->{ ${$column}[1] } = $frame->Button(
                -activebackground => $activecolor,
                -image            => $lglobal{images}->{ ${$column}[1] },
                -relief           => 'flat',
                -borderwidth      => 0,
                -command          => [
                    sub { putgreek( $_[0], \%attributes ) }, ${$column}[1]
                ],
                -highlightthickness => 0,
            )->grid( -row => $row, -column => $index, -padx => 2 );
            $row++;
            $lglobal{buttons}->{ ${$column}[2] } = $frame->Button(
                -activebackground => $activecolor,
                -image            => $lglobal{images}->{ ${$column}[2] },
                -relief           => 'flat',
                -borderwidth      => 0,
                -command          => [
                    sub { putgreek( $_[0], \%attributes ) }, ${$column}[2]
                ],
                -highlightthickness => 0,
            )->grid( -row => $row, -column => $index, -padx => 2 );
            $row++;
            next unless ( ${$column}[3] );
            $lglobal{buttons}->{ ${$column}[3] } = $frame->Button(
                -activebackground => $activecolor,
                -image            => $lglobal{images}->{ ${$column}[3] },
                -relief           => 'flat',
                -borderwidth      => 0,
                -command          => [
                    sub { putgreek( $_[0], \%attributes ) }, ${$column}[3]
                ],
                -highlightthickness => 0,
            )->grid( -row => $row, -column => $index, -padx => 2 );
            $row++;
            next unless ( ${$column}[4] );
            $lglobal{buttons}->{ ${$column}[4] } = $frame->Button(
                -activebackground => $activecolor,
                -image            => $lglobal{images}->{ ${$column}[4] },
                -relief           => 'flat',
                -borderwidth      => 0,
                -command          => [
                    sub { putgreek( $_[0], \%attributes ) }, ${$column}[4]
                ],
                -highlightthickness => 0,
            )->grid( -row => $row, -column => $index, -padx => 2 );
        }
        $frame->Label(
            -text       => 'ou',
            -font       => $grfont,
            -background => 'white',
        )->grid( -row => 4, -column => 16, -padx => 2 );
        $lglobal{buttons}->{'oulig'} = $frame->Button(
            -activebackground   => $activecolor,
            -image              => $lglobal{images}->{'oulig'},
            -relief             => 'flat',
            -borderwidth        => 0,
            -command            => sub { putgreek( 'oulig', \%attributes ) },
            -highlightthickness => 0,
        )->grid( -row => 5, -column => 16 );
        my $bframe = $lglobal{grpop}->Frame->pack(
            -expand => 'yes',
            -fill   => 'both',
            -anchor => 'n'
        );
        $lglobal{grtext} = $bframe->Scrolled(
            'TextEdit',
            -height     => 8,
            -width      => 50,
            -wrap       => 'word',
            -background => 'white',
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
        $lglobal{grtext}->bind( '<FocusIn>',
            sub { $lglobal{hasfocus} = $lglobal{grtext} } );
        drag( $lglobal{grtext} );
        if ( $Tk::version ge 8.4 ) {
            my $bframe2 = $lglobal{grpop}->Frame( -relief => 'ridge' )
                ->pack( -expand => 'n', -anchor => 's' );
            $bframe2->Label(
                -text => 'Character Builder',
                -font => $lglobal{utffont},
            )->pack( -side => 'left', -padx => 2 );
            $buildlabel = $bframe2->Label(
                -text       => '',
                -width      => 5,
                -font       => $lglobal{utffont},
                -background => 'white',
                -relief     => 'ridge'
            )->pack( -side => 'left', -padx => 2 );
            $lglobal{buildentry} = $bframe2->Entry(
                -width      => 5,
                -font       => $lglobal{utffont},
                -background => 'white',
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
                    $hash{" "}    = "\x{397}";
                    $hash{"Í"}    = "\x{3B7}";
                    $hash{'I'}    = "\x{399}";
                    $hash{'i'}    = "\x{3B9}";
                    $hash{'O'}    = "\x{39F}";
                    $hash{'o'}    = "\x{3BF}";
                    $hash{'Y'}    = "\x{3A5}";
                    $hash{'y'}    = "\x{3C5}";
                    $hash{'U'}    = "\x{3A5}";
                    $hash{'u'}    = "\x{3C5}";
                    $hash{"‘"}    = "\x{3A9}";
                    $hash{"Ù"}    = "\x{3C9}";
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
            $lglobal{buildentry}->bind( '<FocusIn>',
                sub { $lglobal{hasfocus} = $lglobal{buildentry} } );
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
                        $string =~ tr/OoEe/‘Ù Í/;
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
                        $string =~ tr/WwHh/‘Ù Í/;
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
                    }
                    else {
                        $lglobal{grtext}->delete( 'insert -1c', 'insert' );
                    }
                }
            );
            for (qw!( ) / \ | ~ + = _!) {
                $bframe2->Button(
                    -activebackground => $activecolor,
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
        $lglobal{grpop}->Icon( -image => $icon );
        $glatin->select;
        $lglobal{grtext}->SetGUICallbacks( [] );
    }
}

sub latinpopup {
    if ( defined( $lglobal{latinpop} ) ) {
        $lglobal{latinpop}->deiconify;
        $lglobal{latinpop}->raise;
        $lglobal{latinpop}->focus;
    }
    else {
        my @lbuttons;
        $lglobal{latinpop} = $top->Toplevel;
        $lglobal{latinpop}->title('Latin-1 ISO 8859-1');
        my $b       = $lglobal{latinpop}->Balloon( -initwait => 750 );
        my $tframe  = $lglobal{latinpop}->Frame->pack;
        my $default = $tframe->Radiobutton(
            -variable    => \$lglobal{latoutp},
            -selectcolor => $lglobal{checkcolor},
            -value       => 'l',
            -text        => 'Latin-1 Character',
        )->grid( -row => 1, -column => 1 );
        $tframe->Radiobutton(
            -variable    => \$lglobal{latoutp},
            -selectcolor => $lglobal{checkcolor},
            -value       => 'h',
            -text        => 'HTML Named Entity',
        )->grid( -row => 1, -column => 2 );
        my $frame = $lglobal{latinpop}->Frame( -background => 'white' )->pack;
        my @latinchars = (
            [ '¿', '¡', '¬', '√', 'ƒ', '≈', '∆',      '«' ],
            [ '‡', '·', '‚', '„', '‰', 'Â', 'Ê',      'Á' ],
            [ '»', '…', ' ', 'À', 'Ã', 'Õ', 'Œ',      'œ' ],
            [ 'Ë', 'È', 'Í', 'Î', 'Ï', 'Ì', 'Ó',      'Ô' ],
            [ '“', '”', '‘', '’', '÷', 'ÿ', '—',      'ﬁ' ],
            [ 'Ú', 'Û', 'Ù', 'ı', 'ˆ', '¯', 'Ò',      '˛' ],
            [ 'Ÿ', '⁄', '€', '‹', '–', 'ﬂ', '›',      '◊' ],
            [ '˘', '˙', '˚', '¸', '', 'ˇ', '˝',      '˜' ],
            [ '°', 'ø', '´', 'ª', 'º', 'Ω', 'æ',      '¨' ],
            [ '∞', 'µ', '©', 'Æ', 'π', '≤', '≥',      '±' ],
            [ '£', '¢', '¶', 'ß', '∂', '∫', '™',      '∑' ],
            [ '§', '•', 'Ø', '∏', '®', '¥', "\x{A0}", '' ],
        );

        for my $y ( 0 .. 11 ) {
            for my $x ( 0 .. 7 ) {
                $lbuttons[ ( $y * 16 ) + $x ] = $frame->Button(
                    -activebackground   => $activecolor,
                    -text               => $latinchars[$y][$x],
                    -font               => '{Times} 18',
                    -relief             => 'flat',
                    -borderwidth        => 0,
                    -background         => 'white',
                    -command            => \&putlatin,
                    -highlightthickness => 0,
                )->grid( -row => $y, -column => $x, -padx => 2 );
                my $name  = ord( $latinchars[$y][$x] );
                my $hex   = uc sprintf( "%04x", $name );
                my $msg   = "Dec. $name, Hex. $hex";
                my $cname = charnames::viacode($name);
                $msg .= ", $cname" if $cname;
                $b->attach( $lbuttons[ ( $y * 16 ) + $x ],
                    -balloonmsg => $msg, );
            }
        }
        $default->select;

        sub putlatin {
            my @xy     = $lglobal{latinpop}->pointerxy;
            my $widget = $lglobal{latinpop}->containing(@xy);
            my $letter = $widget->cget( -text );
            return unless $letter;
            my $hex = sprintf( "%x", ord($letter) );
            $letter = entity( '\x' . $hex ) if ( $lglobal{latoutp} eq 'h' );
            insertit($letter);
        }
        $lglobal{latinpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{latinpop}->destroy; undef $lglobal{latinpop} }
        );
        $lglobal{latinpop}->Icon( -image => $icon );
        $lglobal{latinpop}->resizable( 'no', 'no' );
    }
}

sub regexref {
    if ( defined( $lglobal{regexrefpop} ) ) {
        $lglobal{regexrefpop}->deiconify;
        $lglobal{regexrefpop}->raise;
        $lglobal{regexrefpop}->focus;
    }
    else {
        $lglobal{regexrefpop} = $top->Toplevel;
        $lglobal{regexrefpop}->title('Regex Quick Reference');
        my $button_ok = $lglobal{regexrefpop}->Button(
            -activebackground => $activecolor,
            -text             => 'Close',
            -command          => sub {
                $lglobal{regexrefpop}->destroy;
                undef $lglobal{regexrefpop};
            }
        )->pack( -pady => 6 );
        my $regtext = $lglobal{regexrefpop}->Scrolled(
            'ROText',
            -scrollbars => 'se',
            -background => 'white',
            -font       => $lglobal{font},
        )->pack( -anchor => 'n', -expand => 'y', -fill => 'both' );
        drag($regtext);
        $lglobal{regexrefpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $lglobal{regexrefpop}->destroy;
                undef $lglobal{regexrefpop};
            }
        );
        $lglobal{regexrefpop}->Icon( -image => $icon );
        if ( -e 'regref.txt' ) {
            if ( open my $ref, '<', 'regref.txt' ) {
                while (<$ref>) {
                    $_ =~ s/\cM\cJ|\cM|\cJ/\n/g;

                    #$_ = eol_convert($_);
                    $regtext->insert( 'end', $_ );
                }
            }
            else {
                $regtext->insert( 'end',
                    'Could not open Regex Reference file - regref.txt.' );
            }
        }
        else {
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
    }
    else {
        $lglobal{ordpop} = $top->Toplevel;
        $lglobal{ordpop}->title('Ordinal to Char');
        $lglobal{ordpop}->resizable( 'yes', 'no' );
        my $frame = $lglobal{ordpop}
            ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        my $frame2 = $lglobal{ordpop}
            ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
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
            -background   => 'white',
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
                }
                elsif ( $base eq 'dec' ) {
                    return 0
                        unless ( ( $_[0] =~ /^\d{0,5}$/ )
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
            -background => 'white',
            -relief     => 'sunken',
            -font       => '{sanserif} 14',
            -width      => 6,
            -height     => 1,
        )->grid( -row => 2, -column => 2 );
        my $frame1 = $lglobal{ordpop}
            ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        my $button = $frame1->Button(
            -text    => 'OK',
            -width   => 8,
            -command => sub {
                $lglobal{hasfocus}
                    ->insert( 'insert', $outentry->get( '1.0', 'end -1c' ) );
            },
        )->grid( -row => 1, -column => 1 );
        $frame1->Button(
            -text  => 'Close',
            -width => 8,
            -command =>
                sub { $lglobal{ordpop}->destroy; undef $lglobal{ordpop} },
        )->grid( -row => 1, -column => 2 );
        $lglobal{ordpop}->protocol( 'WM_DELETE_WINDOW' =>
                sub { $lglobal{ordpop}->destroy; undef $lglobal{ordpop} } );
        $lglobal{ordpop}->Icon( -image => $icon );
    }
}

sub uchar {
    if ( defined $lglobal{ucharpop} ) {
        $lglobal{ucharpop}->deiconify;
        $lglobal{ucharpop}->raise;
    }
    else {
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
        $lglobal{ucharpop}->geometry('550x450');
        $lglobal{ucharpop}->protocol(
            'WM_DELETE_WINDOW' =>
                sub { $lglobal{ucharpop}->destroy; undef $lglobal{ucharpop}; }
        );
        $lglobal{ucharpop}->Icon( -image => $icon );
        my $cframe = $lglobal{ucharpop}->Frame->pack;
        my $frame0 = $lglobal{ucharpop}
            ->Frame->pack( -side => 'top', -anchor => 'n', -pady => 4 );
        my $sizelabel;
        my ( @textchars, @textlabels );
        my $pane = $lglobal{ucharpop}->Scrolled(
            'Pane',
            -background => 'white',
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
            -activebackground => $activecolor,
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
        $sizelabel = $cframe->Label( -text => $utffontsize )
            ->grid( -row => 1, -column => 3, -padx => 2, -pady => 2 );
        my $smaller = $cframe->Button(
            -activebackground => $activecolor,
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
        my $characteristics = $frame0->Entry(
            -width      => 40,
            -background => 'white'
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
                                if (   hex( $blocks{$_}[0] ) <= hex($ord)
                                    && hex( $blocks{$_}[1] ) >= hex($ord) )
                                {
                                    $block = $_;
                                    last;
                                }
                            }
                            $textchars[$row] = $pane->Label(
                                -text       => chr( hex $ord ),
                                -font       => $lglobal{utffont},
                                -background => 'white',
                                )->grid(
                                -row    => $row,
                                -column => 0,
                                -sticky => 'w'
                                );
                            utfchar_bind( $textchars[$row] );

                            $textlabels[$row] = $pane->Label(
                                -text => "$name  -  Ordinal $ord  -  $block",
                                -background => 'white',
                                )->grid(
                                -row    => $row,
                                -column => 1,
                                -sticky => 'w'
                                );
                            utflabel_bind(
                                $textlabels[$row],  $block,
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

MainLoop;
