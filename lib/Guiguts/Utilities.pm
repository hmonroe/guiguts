package Guiguts::Utilities;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&openpng &get_image_file &setviewerpath &setdefaultpath &arabic &roman
	&textbindings)
}

sub get_image_file {
	my $pagenum = shift;
	my $number;
	my $imagefile;
	unless ($main::pngspath) {
		if ($main::OS_WIN) {
			$main::pngspath = "${main::globallastpath}pngs\\";
		} else {
			$main::pngspath = "${main::globallastpath}pngs/";
		}
		&main::setpngspath($pagenum) unless ( -e "$main::pngspath$pagenum.png" );
	}
	if ($main::pngspath) {
		$imagefile = "$main::pngspath$pagenum.png";
		unless ( -e $imagefile ) {
			$imagefile = "$main::pngspath$pagenum.jpg";
		}
	}
	return $imagefile;
}



# Routine to handle image viewer file requests
sub openpng {
	my ($textwindow,$pagenum) = @_;
	if ( $pagenum eq 'Pg' ) {
		return;
	}
	$main::lglobal{pageimageviewed} = $pagenum;
	if ( not $main::globalviewerpath ) {
		&main::setviewerpath($textwindow);
	}
	my $imagefile = &main::get_image_file($pagenum);
	if ( $imagefile && $main::globalviewerpath ) {
		&main::runner( $main::globalviewerpath, $imagefile );
	} else {
		&main::setpngspath($pagenum);
	}
	return;
}

sub setviewerpath {    #Find your image viewer
	my $textwindow = shift;
	my $types;
	if ($main::OS_WIN) {
		$types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
	} else {
		$types = [ [ 'All Files', ['*'] ] ];
	}
	#print $main::globalviewerpath."aa\n";
#	print &main::dirname($main::globalviewerpath)."aa\n";
	
	$main::lglobal{pathtemp} =
	  $textwindow->getOpenFile(
								-filetypes  => $types,
								-title      => 'Where is your image viewer?',
								-initialdir => &main::dirname($main::globalviewerpath)
	  );
	$main::globalviewerpath = $main::lglobal{pathtemp} if $main::lglobal{pathtemp};
	$main::globalviewerpath = &main::os_normal($main::globalviewerpath);
	&main::savesettings();
}
sub setdefaultpath {
	my ($pathname,$path) = @_;
	if ($pathname) {return $pathname}
	if ((!$pathname) && (-e $path)) {return $path;} else {
	return ''}
}

# Roman numeral conversion taken directly from the Roman.pm module Copyright
# (c) 1995 OZAWA Sakuro. Done to avoid users having to install downloadable
# modules.
sub roman {
	my %roman_digit = qw(1 IV 10 XL 100 CD 1000 MMMMMM);
	my @figure      = reverse sort keys %roman_digit;
	grep( $roman_digit{$_} = [ split( //, $roman_digit{$_}, 2 ) ], @figure );
	my $arg = shift;
	return unless defined $arg;
	0 < $arg and $arg < 4000 or return;
	my ( $x, $roman );
	foreach (@figure) {
		my ( $digit, $i, $v ) = ( int( $arg / $_ ), @{ $roman_digit{$_} } );
		if ( 1 <= $digit and $digit <= 3 ) {
			$roman .= $i x $digit;
		} elsif ( $digit == 4 ) {
			$roman .= "$i$v";
		} elsif ( $digit == 5 ) {
			$roman .= $v;
		} elsif ( 6 <= $digit
				  and $digit <= 8 )
		{
			$roman .= $v . $i x ( $digit - 5 );
		} elsif ( $digit == 9 ) {
			$roman .= "$i$x";
		}
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

sub textbindings {
	my $textwindow = $main::textwindow;
	my $top = $main::top;

	# Set up a bunch of events and key bindings for the widget
	$textwindow->tagConfigure( 'footnote', -background => 'cyan' );
	$textwindow->tagConfigure( 'scannos',  -background => $main::highlightcolor );
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
	$textwindow->tagBind( 'pagenum', '<ButtonRelease-1>', \&main::pnumadjust );
	$textwindow->eventAdd( '<<hlquote>>' => '<Control-quoteright>' );
	$textwindow->bind( '<<hlquote>>', sub { &main::hilite('\'') } );
	$textwindow->eventAdd( '<<hldquote>>' => '<Control-quotedbl>' );
	$textwindow->bind( '<<hldquote>>', sub { &main::hilite('"') } );
	$textwindow->eventAdd( '<<hlrem>>' => '<Control-0>' );
	$textwindow->bind(
		'<<hlrem>>',
		sub {
			$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			$textwindow->tagRemove( 'quotemark', '1.0', 'end' );
		}
	);
	$textwindow->bind( 'TextUnicode', '<Control-s>' => \&main::savefile );
	$textwindow->bind( 'TextUnicode', '<Control-S>' => \&main::savefile );
	$textwindow->bind( 'TextUnicode',
					   '<Control-a>' => sub { $textwindow->selectAll } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-A>' => sub { $textwindow->selectAll } );
	$textwindow->eventAdd( '<<Copy>>' => '<Control-C>',
						   '<Control-c>', '<F1>' );
	$textwindow->bind( 'TextUnicode', '<<Copy>>' => \&main::textcopy );
	$textwindow->eventAdd( '<<Cut>>' => '<Control-X>',
						   '<Control-x>', '<F2>' );
	$textwindow->bind( 'TextUnicode', '<<Cut>>' => sub { &main::cut() } );

	$textwindow->bind( 'TextUnicode', '<Control-V>' => sub { &main::paste() } );
	$textwindow->bind( 'TextUnicode', '<Control-v>' => sub { &main::paste() } );
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
			} else {
				$textwindow->Delete;
			}
		}
	);
	$textwindow->bind( 'TextUnicode',
					   '<Control-l>' => sub { &main::case ( $textwindow, 'lc' ); } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-u>' => sub { &main::case ( $textwindow, 'uc' ); } );
	$textwindow->bind( 'TextUnicode',
			 '<Control-t>' => sub { &main::case ( $textwindow, 'tc' ); $top->break } );
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
	$textwindow->bind( 'TextUnicode', '<Control-f>' => \&main::searchpopup );
	$textwindow->bind( 'TextUnicode', '<Control-F>' => \&main::searchpopup );
	$textwindow->bind( 'TextUnicode', '<Control-p>' => \&main::gotopage );
	$textwindow->bind( 'TextUnicode', '<Control-P>' => \&main::gotopage );
	$textwindow->bind(
		'TextUnicode',
		'<Control-w>' => sub {
			$textwindow->addGlobStart;
			&main::floodfill();
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Control-W>' => sub {
			$textwindow->addGlobStart;
			&main::floodfill();
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind( 'TextUnicode',
					   '<Control-Shift-exclam>' => sub { &main::setbookmark('1') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-Shift-at>' => sub { &main::setbookmark('2') } );
	$textwindow->bind( 'TextUnicode',
					 '<Control-Shift-numbersign>' => sub { &main::setbookmark('3') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-Shift-dollar>' => sub { &main::setbookmark('4') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-Shift-percent>' => sub { &main::setbookmark('5') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-KeyPress-1>' => sub { &main::gotobookmark('1') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-KeyPress-2>' => sub { &main::gotobookmark('2') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-KeyPress-3>' => sub { &main::gotobookmark('3') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-KeyPress-4>' => sub { &main::gotobookmark('4') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-KeyPress-5>' => sub { &main::gotobookmark('5') } );
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Left>' => sub {
			$textwindow->addGlobStart;
			&main::indent('out');
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Right>' => sub {
			$textwindow->addGlobStart;
			&main::indent('in');
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Up>' => sub {
			$textwindow->addGlobStart;
			&main::indent('up');
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Down>' => sub {
			$textwindow->addGlobStart;
			&main::indent('dn');
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind( 'TextUnicode', '<F7>' => \&main::spellchecker );

	$textwindow->bind(
		'TextUnicode',
		'<Control-Alt-s>' => sub {
			unless ( -e 'scratchpad.txt' ) {
				open my $fh, '>', 'scratchpad.txt'
				  or warn "Could not create file $!";
			}
			&main::runner('start scratchpad.txt') if $main::OS_WIN;
		}
	);
	$textwindow->bind( 'TextUnicode', '<Control-Alt-r>' => sub { &main::regexref() } );
	$textwindow->bind( 'TextUnicode', '<Shift-B1-Motion>', 'shiftB1_Motion' );
	$textwindow->eventAdd( '<<FindNext>>' => '<Control-Key-G>',
						   '<Control-Key-g>' );
	$textwindow->bind( '<<ScrollDismiss>>', \&main::scrolldismiss );
	$textwindow->bind( 'TextUnicode', '<ButtonRelease-2>',
					   sub { popscroll() unless $Tk::mouseMoved } );
	$textwindow->bind(
		'<<FindNext>>',
		sub {
			if ( $main::lglobal{searchpop} ) {
				my $searchterm = $main::lglobal{searchentry}->get( '1.0', '1.end' );
				&main::searchtext($textwindow,$top,$searchterm);
			} else {
				&main::searchpopup();
			}
		}
	);
	if ($main::OS_WIN) {
		$textwindow->bind(
			'TextUnicode',
			'<3>' => sub {
				&main::scrolldismiss();
				$main::menubar->Popup( -popover => 'cursor' );
			}
		);
	} else {
		$textwindow->bind( 'TextUnicode', '<3>' => sub { &main::scrolldismiss() } )
		  ;    # Try to trap odd right click error under OSX and Linux
	}
	$textwindow->bind( 'TextUnicode', '<Control-Alt-h>' => \&main::hilitepopup );
	$textwindow->bind( 'TextUnicode',
					  '<FocusIn>' => sub { $main::lglobal{hasfocus} = $textwindow } );

	$main::lglobal{drag_img} = $top->Photo(
		-format => 'gif',
		-data   => '
R0lGODlhDAAMALMAAISChNTSzPz+/AAAAOAAyukAwRIA4wAAd8oA0MEAe+MTYHcAANAGgnsAAGAA
AAAAACH5BAAAAAAALAAAAAAMAAwAAwQfMMg5BaDYXiw178AlcJ6VhYFXoSoosm7KvrR8zfXHRQA7
'
	);

	$main::lglobal{hist_img} = $top->Photo(
		-format => 'gif',
		-data =>
		  'R0lGODlhBwAEAIAAAAAAAP///yH5BAEAAAEALAAAAAAHAAQAAAIIhA+BGWoNWSgAOw=='
	);
	&main::drag($textwindow);
}

sub popscroll {
	if ( $main::lglobal{scroller} ) {
		&main::scrolldismiss();
		return;
	}
	my $x = $main::top->pointerx - $main::top->rootx;
	my $y = $main::top->pointery - $main::top->rooty - 8;
	$main::lglobal{scroller} = $main::top->Label(
									  -background  => $main::textwindow->cget( -bg ),
									  -image       => $main::lglobal{scrollgif},
									  -cursor      => 'double_arrow',
									  -borderwidth => 0,
									  -highlightthickness => 0,
									  -relief             => 'flat',
	)->place( -x => $x, -y => $y );

	$main::lglobal{scroller}->eventAdd( '<<ScrollDismiss>>', qw/<1> <3>/ );
	$main::lglobal{scroller}
	  ->bind( 'current', '<<ScrollDismiss>>', sub { &main::scrolldismiss(); } );
	$main::lglobal{scroll_y}  = $y;
	$main::lglobal{scroll_x}  = $x;
	$main::lglobal{oldcursor} = $main::textwindow->cget( -cursor );
	%{ $main::lglobal{scroll_cursors} } = (
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
	$main::lglobal{scroll_id} = $main::top->repeat( $main::scrollupdatespd, \&main::b2scroll );
}



1;


