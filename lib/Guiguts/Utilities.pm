package Guiguts::Utilities;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&openpng &get_image_file &setviewerpath &::setdefaultpath &arabic &roman
	&textbindings &cmdinterp &nofileloadedwarning &getprojectid &win32_cmdline &win32_start 
	&win32_is_exe &win32_create_process &runner &debug_dump &run &escape_regexmetacharacters 
	&deaccent &BindMouseWheel &working &initialize &fontinit &initialize_popup_with_deletebinding 
	&initialize_popup_without_deletebinding)
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
	$::lglobal{pageimageviewed} = $pagenum;
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
	
	$::lglobal{pathtemp} =
	  $textwindow->getOpenFile(
								-filetypes  => $types,
								-title      => 'Where is your image viewer?',
								-initialdir => &main::dirname($main::globalviewerpath)
	  );
	$main::globalviewerpath = $::lglobal{pathtemp} if $::lglobal{pathtemp};
	$main::globalviewerpath = &main::os_normal($main::globalviewerpath);
	&main::savesettings();
}
sub ::setdefaultpath {
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
	my $textwindow = $::textwindow;
	my $top = $::top;

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
	$textwindow->bind( '<<ScrollDismiss>>', \&scrolldismiss );
	$textwindow->bind( 'TextUnicode', '<ButtonRelease-2>',
					   sub { popscroll() unless $Tk::mouseMoved } );
	$textwindow->bind(
		'<<FindNext>>',
		sub {
			if ( $::lglobal{searchpop} ) {
				my $searchterm = $::lglobal{searchentry}->get( '1.0', '1.end' );
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
				scrolldismiss();
				$main::menubar->Popup( -popover => 'cursor' );
			}
		);
	} else {
		$textwindow->bind( 'TextUnicode', '<3>' => sub { &scrolldismiss() } )
		  ;    # Try to trap odd right click error under OSX and Linux
	}
	$textwindow->bind( 'TextUnicode', '<Control-Alt-h>' => \&main::hilitepopup );
	$textwindow->bind( 'TextUnicode',
					  '<FocusIn>' => sub { $::lglobal{hasfocus} = $textwindow } );

	$::lglobal{drag_img} = $top->Photo(
		-format => 'gif',
		-data   => '
R0lGODlhDAAMALMAAISChNTSzPz+/AAAAOAAyukAwRIA4wAAd8oA0MEAe+MTYHcAANAGgnsAAGAA
AAAAACH5BAAAAAAALAAAAAAMAAwAAwQfMMg5BaDYXiw178AlcJ6VhYFXoSoosm7KvrR8zfXHRQA7
'
	);

	$::lglobal{hist_img} = $top->Photo(
		-format => 'gif',
		-data =>
		  'R0lGODlhBwAEAIAAAAAAAP///yH5BAEAAAEALAAAAAAHAAQAAAIIhA+BGWoNWSgAOw=='
	);
	&main::drag($textwindow);
}

sub popscroll {
	if ( $::lglobal{scroller} ) {
		scrolldismiss();
		return;
	}
	my $x = $main::top->pointerx - $main::top->rootx;
	my $y = $main::top->pointery - $main::top->rooty - 8;
	$::lglobal{scroller} = $main::top->Label(
									  -background  => $main::textwindow->cget( -bg ),
									  -image       => $::lglobal{scrollgif},
									  -cursor      => 'double_arrow',
									  -borderwidth => 0,
									  -highlightthickness => 0,
									  -relief             => 'flat',
	)->place( -x => $x, -y => $y );

	$::lglobal{scroller}->eventAdd( '<<ScrollDismiss>>', qw/<1> <3>/ );
	$::lglobal{scroller}
	  ->bind( 'current', '<<ScrollDismiss>>', sub { &scrolldismiss(); } );
	$::lglobal{scroll_y}  = $y;
	$::lglobal{scroll_x}  = $x;
	$::lglobal{oldcursor} = $main::textwindow->cget( -cursor );
	%{ $::lglobal{scroll_cursors} } = (
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
	$::lglobal{scroll_id} = $main::top->repeat( $main::scrollupdatespd, \&main::b2scroll );
}

# Command parsing for External command routine
sub cmdinterp {
	# Allow basic quoting, in case anyone specifies paths with spaces.
	# Don't support paths with quotes.  The standard \" and \\ escapes
	# would not be friendly on Windows-style paths.
	my $textwindow = $main::textwindow;
	my @args = shift =~ m/"[^"]+"|\S+/g;

	my ( $fname, $pagenum, $number, $pname );
	my ( $selection, $ranges );

	foreach my $arg (@args) {
		$arg =~ s/^"(.*)"$/$1/;

		# Replace $t with selected text for instance for a dictionary search
		if ( $arg =~ m/\$t/ ) {
			my @ranges = $textwindow->tagRanges('sel');
			return ' ' unless @ranges;
			my $end   = pop(@ranges);
			my $start = pop(@ranges);
			$selection = $textwindow->get( $start, $end );
			$arg =~ s/\$t/$selection/;
			$arg = &main::encode( "utf-8", $arg );
		}

# Pass file to default file handler, $f $d $e give the fully specified path/filename
		if ( $arg =~ m/\$f|\$d|\$e/ ) {
			return if nofileloadedwarning();
			$fname = $::lglobal{global_filename};
			my ( $f, $d, $e ) = fileparse( $fname, qr{\.[^\.]*$} );
			$arg =~ s/\$f/$f/ if $f;
			$arg =~ s/\$d/$d/ if $d;
			$arg =~ s/\$e/$e/ if $e;
			if ( $arg =~ m/project_comments.html/ ) {
				$arg =~ s/project/$main::projectid/;
			}
		}

		# Pass image file to default file handler
		if ( $arg =~ m/\$p/ ) {
			return unless $::lglobal{img_num_label};
			$number = $::lglobal{img_num_label}->cget( -text );
			$number =~ s/.+?(\d+).*/$1/;
			$pagenum = $number;
			return ' ' unless $pagenum;
			$arg =~ s/\$p/$number/;
		}
		if ( $arg =~ m/\$i/ ) {
			return ' ' unless $main::pngspath;
			$arg =~ s/\$i/$main::pngspath/;
		}
	}
	return @args;
}

sub nofileloadedwarning {
	my $top = $main::top;
	if ( $::lglobal{global_filename} =~ m/No File Loaded/ ) {
		my $dialog = $top->Dialog(
								   -text    => "No File Loaded",
								   -bitmap  => 'warning',
								   -title   => "No File Loaded",
								   -buttons => ['OK']
		);
		my $answer = $dialog->Show;
		return 1;
	}
}

#FIXME: doesnt work quite right if multiple volumes held in same directory!
sub getprojectid {
	my $fname = $::lglobal{global_filename};
	my ( $f, $d, $e ) = &main::fileparse( $fname, qr{\.[^\.]*$} );
	opendir( DIR, "$d" );
	for ( readdir(DIR) ) {
		if ( $_ =~ m/(project.*)_comments.html/ ) {
			$main::projectid = $1;
		}
	}
	closedir(DIR);
	return;
}

sub win32_cmdline {
	my @args = @_;

	# <http://blogs.msdn.com/b/twistylittlepassagesallalike/archive/2011/04/23/
	#  everyone-quotes-arguments-the-wrong-way.aspx>
	#
	# which includes perl's system(LIST).  So we do our own quoting.
	#
	foreach ( @args ) {
		s/(\\*)\"/$!$!\\\"/g;
		s/^(.*)(\\*)$/\"$1$2$2\"/ if m/[ "]/;
	}
	return join " ", @args;
}

sub win32_start {
	my @args = @_;

	# Windows command to open a file (or URL) using the default program

	# start command must be run through CMD.EXE
	# (we don't have Win32:Gui, or we could use ShellExecute())
	#
	# <http://www.autohotkey.net/~deleyd/parameters/parameters.htm>
	#
	# Other external commands can go through win32_create_process(),
	# which doesn't have this limitation.
	#
	foreach ( @args ) {
		if ( m/["<>|&()!%^]/ ) {
			warn 'Refusing to run "start" command with unsafe characters ("<>|&()!%^): '
			     . join(" ", @args);
			return -1;
		}
	}

	# <http://stackoverflow.com/questions/72671/
	#  how-to-create-batch-file-in-windows-using-start-with-a-path-and-command-with-s
	#
	# Users never need to create a titled DOS window,
	# but they may need to run the 'start' command on files with spaces.
	#
	@args = ( 'start', '', @args );

	my $cmdline = win32_cmdline( @args );
	system $cmdline;
}

sub win32_is_exe {
	my ( $exe ) = @_;
	return -x $exe && ! -d $exe;
}

sub win32_find_exe {
	my ( $exe ) = @_;

	return $exe if win32_is_exe($exe);

	foreach my $ext ( split ';', $main::ENV{PATHEXT} )
	{
		my $p = $exe . $ext;
		return $p if win32_is_exe($p);
	}

	if ( ! File::Spec->file_name_is_absolute($exe) )
	{
		foreach my $path ( split ';', $main::ENV{PATH} )
		{
			my $stem = ::catfile($path, $exe);
			return $stem if win32_is_exe($stem);

			foreach my $ext ( split ';', $main::ENV{PATHEXT} ) {
				my $p = $stem . $ext;
				return $p if win32_is_exe($p);
			}
		}
	}

	# No such program; caller will find out :).
	return $exe;
}

sub win32_create_process {
	require Win32;
	require Win32::Process;

	my @args = @_;

	my $exe = win32_find_exe( $args[0] );
	my $cmdline = win32_cmdline( @args );

	my $proc;
	if ( Win32::Process::Create( $proc, $exe, $cmdline, 1, 0, '.' ) ) {
		return $proc;
	} else {
		print STDERR "Failed to run $args[0]: ";
		print STDERR Win32::FormatMessage( Win32::GetLastError() );
		return undef;
	}
	return;
}

# system(LIST)
# (but slightly more robust, particularly on Windows).
sub run {
	my @args = @_;

	if ( ! $main::OS_WIN ) {
		system { $args[0] } @args;
	} else {
		require Win32;
		require Win32::Process;

		my $proc = win32_create_process( @args );
		return -1 unless defined $proc;
		$proc->Wait( Win32::Process::INFINITE() );
		$proc->GetExitCode( my $exitcode );
		$? = $exitcode << 8;
	}
	return;
}

# Start an external program
sub runner {
	my @args = @_;
	unless ( @args ) {
		warn "Tried to run an empty command";
		return -1;
	}

	if ( ! $main::OS_WIN ) {
		# We can't call perl fork() in the main GUI process, because Tk crashes
		system( "perl", "$::lglobal{guigutsdirectory}/spawn.pl", @args );
	} else {
		if ( $args[0] eq 'start') {
			win32_start( @args[1 .. $#args] );
		} else {
			my $proc = win32_create_process( @args );
			return (defined $proc) ? 0 : -1;
		}
	}
	return;
}

# Run external program, with stdin and/or stdout redirected to temporary files
{
	package runner;

	sub tofile {
		my ($outfile) = @_;
		withfiles(undef, $outfile);
	}
	sub withfiles {
		my ($infile, $outfile) = @_;
		bless {
			infile => $infile,
			outfile => $outfile,
		}, 'runner';
	}
	sub run {
		my ($self, @args) = @_;

		my ($oldstdout, $oldstdin);
		unless ( open $oldstdin, '<&', \*STDIN ) {
			warn "Failed to save stdin: $!";
			return -1;
		}
		unless ( open $oldstdout, '>&', \*STDOUT ) {
			warn "Failed to save stdout: $!";
			return -1;
		}

		if ( defined $self->{infile} ) {
			unless ( open STDIN, '<', $self->{infile} ) {
				warn "Failed to open '$self->{infile}': $!";
				return -1;
			}
		}
		if ( defined $self->{outfile} ) {
			unless ( open STDOUT, '>', $self->{outfile} ) {
				warn "Failed to open '$self->{outfile}' for writing: $!";
				# Don't bother to restore STDIN here.
				return -1;
			}
		}
		main::run( @args );

		unless ( open STDOUT, '>&', $oldstdout ) {
			warn "Failed to restore stdout: $!";
		}

		# We restore STDIN here, just because perl warns about it otherwise.
		unless ( open STDIN, '<&', $oldstdin ) {
			warn "Failed to restore stdin: $!";
		}

		return $?;
	}
}

# just working out how to do things
# prints everything I can think of to debug.txt
# prints seenwords to words.txt
sub debug_dump {
	open my $save, '>', 'debug.txt';
	print $save "\%lglobal values:\n";
	for my $key (keys %::lglobal) { 
		if ($::lglobal{$key}){ print $save "$key => $::lglobal{$key}\n";}
		else { print $save "$key x=>\n";}
		};
	print $save "\n\@ARGV command line arguments:\n";
	for my $element (@ARGV) {
		print $save "$element\n";
		};
	print $save "\n\%SIG variables:\n";
	for my $key (keys %SIG) { 
		if ($SIG{$key}){
			print $save "$key => $SIG{$key}\n";
		} else { print $save "$key x=>\n"; 	}
	};
	print $save "\n\%ENV environment variables:\n";
	for my $key (keys %ENV) { 
		print $save "$key => $ENV{$key}\n";
		};
	print $save "\n\@INC include path:\n";
	for my $element (@INC) {
		print $save "$element\n";
		};
	print $save "\n\%INC included filenames:\n";
	for my $key (keys %INC) { 
		print $save "$key => $INC{$key}\n";
		};
	close $save;
	my $section = "\%lglobal{seenwords}\n";
	open $save, '>:bytes', 'words.txt';
	for my $key (keys %{$::lglobal{seenwords}}){
		$section .= "$key => $::lglobal{seenwords}{$key}\n";
	};
	utf8::encode($section);
	print $save $section;
	close $save;
	$section = "\%lglobal{seenwordsland}\n";
	open $save, '>:bytes', 'words2.txt';
	for my $key (keys %{$::lglobal{seenwords}}){
		if ($::lglobal{seenwordslang}{$key}) {
			$section .= "$key => $::lglobal{seenwordslang}{$key}\n";
		} else {
			$section .= "$key x=>\n";
		}
	};
	utf8::encode($section);
	print $save $section;
	close $save;
	open $save, '>', 'project.txt';
	print $save "\%projectdict\n";
	for my $key (keys %main::projectdict){
		print $save "$key => $main::projectdict{$key}\n";
	};
	close $save;
};

sub escape_regexmetacharacters {
	my $inputstring = shift;
	$inputstring =~ s/([\{\}\[\]\(\)\^\$\.\|\*\+\?\\])/\\$1/g;
	$inputstring =~ s/\\\\(['-])/\\$1/g;
	return $inputstring;
}

sub deaccent {
	my $phrase = shift;
	return $phrase unless ( $phrase =~ y/\xC0-\xFF// );
	$phrase =~
tr/ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÑñÙÚÛÜùúûüÝÿý/AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiOOOOOOooooooNnUUUUuuuuYyy/;
	my %trans = qw(Æ AE æ ae Þ TH þ th Ð TH ð th ß ss);
	$phrase =~ s/([ÆæÞþÐðß])/$trans{$1}/g;
	return $phrase;
}


sub BindMouseWheel {
	my ($w) = @_;
	if ($::OS_WIN) {
		$w->bind(
			'<MouseWheel>' => [
				sub {
					$_[0]->yview( 'scroll', -( $_[1] / 120 ) * 3, 'units' );
				},
				::Ev('D')
			]
		);
	} else {
		$w->bind(
			'<4>' => sub {
				$_[0]->yview( 'scroll', -3, 'units' )
				  unless $Tk::strictMotif;
			}
		);
		$w->bind(
			'<5>' => sub {
				$_[0]->yview( 'scroll', +3, 'units' )
				  unless $Tk::strictMotif;
			}
		);
	}
}

sub working {
	my $msg = shift;
	my $top = $::top;
	if ( defined( $::lglobal{workpop} ) && ( defined $msg ) ) {
		$::lglobal{worklabel}
		  ->configure( -text => "\n\n\nWorking....\n$msg\nPlease wait.\n\n\n" );
		$::lglobal{workpop}->update;
	} elsif ( defined $::lglobal{workpop} ) {
		$::lglobal{workpop}->destroy;
		undef $::lglobal{workpop};
	} else {
		$::lglobal{workpop} = $top->Toplevel;
		$::lglobal{workpop}->transient($top);
		$::lglobal{workpop}->title('Working.....');
		$::lglobal{worklabel} =
		  $::lglobal{workpop}->Label(
						 -text => "\n\n\nWorking....\n$msg\nPlease wait.\n\n\n",
						 -font => '{helvetica} 20 bold',
						 -background => $::activecolor,
		  )->pack;
		$::lglobal{workpop}->resizable( 'no', 'no' );
		$::lglobal{workpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$::lglobal{workpop}->destroy;
				undef $::lglobal{workpop};
			}
		);
		$::lglobal{workpop}->Icon( -image => $::icon );
		$::lglobal{workpop}->update;
	}
}

sub initialize {
  # Initialize a whole bunch of global values that used to be discrete variables
  # spread willy-nilly through the code. Refactored them into a global
  # hash and gathered them together in a single subroutine.
	my $top = $::top;
	$::lglobal{alignstring}       = '.';
	$::lglobal{asciijustify}      = 'center';
	$::lglobal{asciiwidth}        = 64;
	$::lglobal{codewarn}          = 1;
	$::lglobal{cssblockmarkup}    = 0;
	$::lglobal{delay}             = 50;
	$::lglobal{footstyle}         = 'end';
	$::lglobal{ftnoteindexstart}  = '1.0';
	$::lglobal{groutp}            = 'l';
	$::lglobal{htmlimgar}         = 1;             #html image aspect ratio
	$::lglobal{ignore_case}       = 0;
	$::lglobal{keep_latin1}       = 1;
	$::lglobal{lastmatchindex}    = '1.0';
	$::lglobal{lastsearchterm}    = '';
	$::lglobal{longordlabel}      = 0;
	$::lglobal{proofbarvisible}   = 0;
	$::lglobal{regaa}             = 0;
	$::lglobal{runtests}          = 0;
	$::lglobal{seepagenums}       = 0;
	$::lglobal{selectionsearch}   = 0;
	$::lglobal{showblocksize}     = 1;
	$::lglobal{showthispageimage} = 0;
	$::lglobal{spellencoding}     = "iso8859-1";
	$::lglobal{stepmaxwidth}      = 70;
	$::lglobal{suspects_only}     = 0;
	$::lglobal{tblcoljustify}     = 'l';
	$::lglobal{tblrwcol}          = 1;
	$::lglobal{ToolBar}           = 1;
	$::lglobal{uoutp}             = 'h';
	$::lglobal{utfrangesort}      = 0;
	$::lglobal{visibleline}       = '';
	$::lglobal{zoneindex}         = 0;
	@{ $::lglobal{ascii} } = qw/+ - + | | | + - +/;
	@{ $::lglobal{fixopt} } = ( 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 );

	if ( $0 =~ m/\/|\\/ ) {
		my $dir = $0;
		$dir =~ s/(\/|\\)[^\/\\]+$/$1/;
		chdir $dir if length $dir;
	}

	::readsettings();

	# For backward compatibility, carry over old geometry settings
	unless ($::geometry2) {
		$::geometry2 = '462x583+684+72';
	}
	unless ( $::geometryhash{wfpop} ) {
		$::geometryhash{wfpop}         = $::geometry2;
		$::geometryhash{gcpop}         = $::geometry2;
		$::geometryhash{jeepop}        = $::geometry2;
		$::geometryhash{errorcheckpop} = $::geometry2;
		$::geometryhash{hpopup}        = $::geometry3;
		$::geometryhash{ucharpop}      = '550x450+53+87';
		$::geometryhash{utfpop}        = '791x422+46+46';
		$::geometryhash{regexrefpop}   = '663x442+106+72';
		$::geometryhash{pagepop}       = '281x112+334+176';
		$::geometryhash{fixpop}        = '441x440+34+22';
		$::geometryhash{wfpop}         = '462x583+565+63';
		$::geometryhash{pnumpop}       = '210x253+502+97';
		$::geometryhash{hotpop}        = '583x462+144+119';
		$::geometryhash{hpopup}        = '187x197+884+211';
		$::geometryhash{footpop}       = '352x361+255+157';
		$::geometryhash{gcpop}         = '462x583+684+72';
		$::geometryhash{xtpop}         = '800x543+120+38';
		$::geometryhash{grpop}         = '50x8+144+153';
		$::geometryhash{errorcheckpop} = '508x609+684+72';
		$::geometryhash{alignpop}      = '168x94+338+83';
		$::geometryhash{brkpop}        = '201x203+482+131';
		$::geometryhash{aboutpop}      = '378x392+312+136';
		$::geometryhash{asciipop}      = '278x209+358+187';
		$::geometryhash{ordpop}        = '316x150+191+132';
		$::geometryhash{jeepop}        = '462x583+684+72';

	}

	$::lglobal{guigutsdirectory} = ::dirname( ::rel2abs($0) )
	  unless defined $::lglobal{guigutsdirectory};
	$::scannospath = ::::catfile( $::lglobal{guigutsdirectory}, 'scannos' )
         unless $::scannospath;

	if ($::OS_WIN) {
		$::gutcommand =::setdefaultpath($::gutcommand,::catfile($::lglobal{guigutsdirectory},'tools', 'gutcheck', 'gutcheck.exe'));
		$::jeebiescommand =::setdefaultpath($::jeebiescommand,::catfile( $::lglobal{guigutsdirectory},'tools','jeebies','jeebies.exe' ));
		$::tidycommand =::setdefaultpath($::tidycommand,::catfile( $::lglobal{guigutsdirectory}, 'tools', 'tidy', 'tidy.exe' ));
		$::globalviewerpath=::setdefaultpath($::globalviewerpath,::catfile('\Program Files', 'XnView', 'xnview.exe' ));
		$::globalspellpath=::setdefaultpath($::globalspellpath,::catfile('\Program Files', 'Aspell','bin','aspell.exe' ));
		$::validatecommand = ::setdefaultpath($::validatecommand,::catfile($::lglobal{guigutsdirectory}, 'tools', 'W3C', 'onsgmls.exe') );
		$::validatecsscommand = ::setdefaultpath($::validatecsscommand,::catfile($::lglobal{guigutsdirectory},'tools', 'W3C', 'css-validator.jar'));
		$::validatecsscommand = ::setdefaultpath($::validatecsscommand,::catfile($::lglobal{guigutsdirectory},'tools', 'W3C', 'css-validator.jar'));
		$::gnutenbergdirectory = ::setdefaultpath($::gnutenbergdirectory,::catfile($::lglobal{guigutsdirectory}, 'tools', 'gnutenberg', '0.4' ));
	} else {
		$::gutcommand = ::setdefaultpath($::gutcommand,::catfile( $::lglobal{guigutsdirectory},'tools','gutcheck','gutcheck' ));
		$::jeebiescommand = ::setdefaultpath($::jeebiescommand,::catfile( $::lglobal{guigutsdirectory},'tools', 'jeebies', 'jeebies' ));
	}
	%{ $::lglobal{utfblocks} } = (
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

	%{ $::lglobal{grkbeta1} } = (
								"\x{1F00}" => 'a)',
								"\x{1F01}" => 'a(',
								"\x{1F08}" => 'A)',
								"\x{1F09}" => 'A(',
								"\x{1FF8}" => 'O\\',
								"\x{1FF9}" => 'O/',
								"\x{1FFA}" => 'Ô\\',
								"\x{1FFB}" => 'Ô/',
								"\x{1FFC}" => 'Ô|',
								"\x{1F10}" => 'e)',
								"\x{1F11}" => 'e(',
								"\x{1F18}" => 'E)',
								"\x{1F19}" => 'E(',
								"\x{1F20}" => 'ê)',
								"\x{1F21}" => 'ê(',
								"\x{1F28}" => 'Ê)',
								"\x{1F29}" => 'Ê(',
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
								"\x{1F60}" => 'ô)',
								"\x{1F61}" => 'ô(',
								"\x{1F68}" => 'Ô)',
								"\x{1F69}" => 'Ô(',
								"\x{1F70}" => 'a\\',
								"\x{1F71}" => 'a/',
								"\x{1F72}" => 'e\\',
								"\x{1F73}" => 'e/',
								"\x{1F74}" => 'ê\\',
								"\x{1F75}" => 'ê/',
								"\x{1F76}" => 'i\\',
								"\x{1F77}" => 'i/',
								"\x{1F78}" => 'o\\',
								"\x{1F79}" => 'o/',
								"\x{1F7A}" => 'y\\',
								"\x{1F7B}" => 'y/',
								"\x{1F7C}" => 'ô\\',
								"\x{1F7D}" => 'ô/',
								"\x{1FB0}" => 'a=',
								"\x{1FB1}" => 'a_',
								"\x{1FB3}" => 'a|',
								"\x{1FB6}" => 'a~',
								"\x{1FB8}" => 'A=',
								"\x{1FB9}" => 'A_',
								"\x{1FBA}" => 'A\\',
								"\x{1FBB}" => 'A/',
								"\x{1FBC}" => 'A|',
								"\x{1FC3}" => 'ê|',
								"\x{1FC6}" => 'ê~',
								"\x{1FC8}" => 'E\\',
								"\x{1FC9}" => 'E/',
								"\x{1FCA}" => 'Ê\\',
								"\x{1FCB}" => 'Ê/',
								"\x{1FCC}" => 'Ê|',
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
								"\x{1FF6}" => 'ô~',
								"\x{1FF3}" => 'ô|',
								"\x{03AA}" => 'I+',
								"\x{03AB}" => 'Y+',
								"\x{03CA}" => 'i+',
								"\x{03CB}" => 'y+',
								"\x{03DE}" => '*#1',
								"\x{03DE}" => '#1',
								"\x{03DA}" => '*#2',
								"\x{03DB}" => '#2',
								"\x{03D8}" => '*#3',
								"\x{03D9}" => '#3',
								"\x{03E0}" => '*#5',
								"\x{03E1}" => '#5',
								"\x{20EF}" => '#6',
								"\x{03FD}" => '#10',
								"\x{03FF}" => '#11',
								"\x{203B}" => '#13',
								"\x{2E16}" => '#14',
								"\x{03FE}" => '#16',
								"\x{0259}" => '#55',
								"\x{205A}" => '#73',
								"\x{205D}" => '#74',
	);

	%{ $::lglobal{grkbeta2} } = (
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
								"\x{1F22}" => 'ê)\\',
								"\x{1F23}" => 'ê(\\',
								"\x{1F24}" => 'ê)/',
								"\x{1F25}" => 'ê(/',
								"\x{1F26}" => 'ê~)',
								"\x{1F27}" => 'ê~(',
								"\x{1F2A}" => 'Ê)\\',
								"\x{1F2B}" => 'Ê(\\',
								"\x{1F2C}" => 'Ê)/',
								"\x{1F2D}" => 'Ê(/',
								"\x{1F2E}" => 'Ê~)',
								"\x{1F2F}" => 'Ê~(',
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
								"\x{1F62}" => 'ô)\\',
								"\x{1F63}" => 'ô(\\',
								"\x{1F64}" => 'ô)/',
								"\x{1F65}" => 'ô(/',
								"\x{1F66}" => 'ô~)',
								"\x{1F67}" => 'ô~(',
								"\x{1F6A}" => 'Ô)\\',
								"\x{1F6B}" => 'Ô(\\',
								"\x{1F6C}" => 'Ô)/',
								"\x{1F6D}" => 'Ô(/',
								"\x{1F6E}" => 'Ô~)',
								"\x{1F6F}" => 'Ô~(',
								"\x{1F80}" => 'a)|',
								"\x{1F81}" => 'a(|',
								"\x{1F88}" => 'A)|',
								"\x{1F89}" => 'A(|',
								"\x{1F90}" => 'ê)|',
								"\x{1F91}" => 'ê(|',
								"\x{1F98}" => 'Ê)|',
								"\x{1F99}" => 'Ê(|',
								"\x{1FA0}" => 'ô)|',
								"\x{1FA1}" => 'ô(|',
								"\x{1FA8}" => 'Ô)|',
								"\x{1FA9}" => 'Ô(|',
								"\x{1FB2}" => 'a\|',
								"\x{1FB4}" => 'a/|',
								"\x{1FB7}" => 'a~|',
								"\x{1FC2}" => 'ê\|',
								"\x{1FC4}" => 'ê/|',
								"\x{1FC7}" => 'ê~|',
								"\x{1FD2}" => 'i\+',
								"\x{1FD3}" => 'i/+',
								"\x{1FD7}" => 'i~+',
								"\x{1FE2}" => 'y\+',
								"\x{1FE3}" => 'y/+',
								"\x{1FE7}" => 'y~+',
								"\x{1FF2}" => 'ô\|',
								"\x{1FF4}" => 'ô/|',
								"\x{1FF7}" => 'ô~|',
								"\x{0390}" => 'i/+',
								"\x{03B0}" => 'y/+',
	);

	%{ $::lglobal{grkbeta3} } = (
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
								"\x{1F92}" => 'ê)\|',
								"\x{1F93}" => 'ê(\|',
								"\x{1F94}" => 'ê)/|',
								"\x{1F95}" => 'ê(/|',
								"\x{1F96}" => 'ê~)|',
								"\x{1F97}" => 'ê~(|',
								"\x{1F9A}" => 'Ê)\|',
								"\x{1F9B}" => 'Ê(\|',
								"\x{1F9C}" => 'Ê)/|',
								"\x{1F9D}" => 'Ê(/|',
								"\x{1F9E}" => 'Ê~)|',
								"\x{1F9F}" => 'Ê~(|',
								"\x{1FA2}" => 'ô)\|',
								"\x{1FA3}" => 'ô(\|',
								"\x{1FA4}" => 'ô)/|',
								"\x{1FA5}" => 'ô(/|',
								"\x{1FA6}" => 'ô~)|',
								"\x{1FA7}" => 'ô~(|',
								"\x{1FAA}" => 'Ô)\|',
								"\x{1FAB}" => 'Ô(\|',
								"\x{1FAC}" => 'Ô)/|',
								"\x{1FAD}" => 'Ô(/|',
								"\x{1FAE}" => 'Ô~)|',
								"\x{1FAF}" => 'Ô~(|',
	);

	$::lglobal{checkcolor} = ($::OS_WIN) ? 'white' : $::activecolor;
	my $scroll_gif =
'R0lGODlhCAAQAIAAAAAAAP///yH5BAEAAAEALAAAAAAIABAAAAIUjAGmiMutopz0pPgwk7B6/3SZphQAOw==';
	$::lglobal{scrollgif} =
	  $top->Photo( -data   => $scroll_gif,
				   -format => 'gif', );
}

sub scrolldismiss {
	my $textwindow = $::textwindow;
	return unless $::lglobal{scroller};
	$textwindow->configure( -cursor => $::lglobal{oldcursor} );
	$::lglobal{scroller}->destroy;
	$::lglobal{scroller} = '';
	$::lglobal{scroll_id}->cancel if $::lglobal{scroll_id};
	$::lglobal{scroll_id}     = '';
	$::lglobal{scrolltrigger} = 0;
}

sub b2scroll {
	my $top = $::top;
	my $textwindow = $::textwindow;
	my $scrolly = $top->pointery - $top->rooty - $::lglobal{scroll_y} - 8;
	my $scrollx = $top->pointerx - $top->rootx - $::lglobal{scroll_x} - 8;
	my $signy   = ( abs $scrolly > 5 ) ? ( $scrolly < 0 ? -1 : 1 ) : 0;
	my $signx   = ( abs $scrollx > 5 ) ? ( $scrollx < 0 ? -1 : 1 ) : 0;
	$textwindow->configure(
						  -cursor => $::lglobal{scroll_cursors}{"$signy$signx"} );
	$scrolly = ( $scrolly**2 - 25 ) / 800;
	$scrollx = ( $scrollx**2 - 25 ) / 2000;
	$::lglobal{scrolltriggery} += $scrolly;

	if ( $::lglobal{scrolltriggery} > 1 ) {
		$textwindow->yview( 'scroll', ( $signy * $::lglobal{scrolltriggery} ),
							'units' );
		$::lglobal{scrolltriggery} = 0;
	}
	$::lglobal{scrolltriggerx} += $scrollx;
	if ( $::lglobal{scrolltriggerx} > 1 ) {
		$textwindow->xview( 'scroll', ( $signx * $::lglobal{scrolltriggerx} ),
							'units' );
		$::lglobal{scrolltriggerx} = 0;
	}
}

sub fontinit {
	$::lglobal{font} = "{$::fontname} $::fontsize $::fontweight";
}

sub initialize_popup_with_deletebinding {
	my $popupname = shift;
	initialize_popup_without_deletebinding($popupname);
	$::lglobal{$popupname}->protocol(
		'WM_DELETE_WINDOW' => sub {
			$::lglobal{$popupname}->destroy;
			undef $::lglobal{$popupname};
		}
	);
}

sub initialize_popup_without_deletebinding {
	my $top = $::top;
	my $popupname = shift;
	$::lglobal{$popupname}->geometry( $::geometryhash{$popupname} )
	  if $::geometryhash{$popupname};
	$::lglobal{"$popupname"}->bind(
		'<Configure>' => sub {
			$::geometryhash{"$popupname"} = $::lglobal{"$popupname"}->geometry;
			$::lglobal{geometryupdate} = 1;
		}
	);
	$::lglobal{$popupname}->Icon( -image => $::icon );
	if ( ($::stayontop) and ( not $popupname eq "wfpop" ) ) {
		$::lglobal{$popupname}->transient($top);
	}
	if ( ($::wfstayontop) and ( $popupname eq "wfpop" ) ) {
		$::lglobal{$popupname}->transient($top);
	}
}



1;