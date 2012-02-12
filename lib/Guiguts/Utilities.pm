package Guiguts::Utilities;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&openpng &get_image_file &setviewerpath &setdefaultpath &arabic &roman
	&textbindings &cmdinterp &nofileloadedwarning &getprojectid &win32_cmdline &win32_start &win32_is_exe
	&win32_create_process &runner &debug_dump)
}

sub get_image_file {
	my $pagenum = shift;
	my $number;
	my $imagefile;
	unless ($::pngspath) {
		if ($::OS_WIN) {
			$::pngspath = "${::globallastpath}pngs\\";
		} else {
			$::pngspath = "${::globallastpath}pngs/";
		}
		&::setpngspath($pagenum) unless ( -e "$::pngspath$pagenum.png" );
	}
	if ($::pngspath) {
		$imagefile = "$::pngspath$pagenum.png";
		unless ( -e $imagefile ) {
			$imagefile = "$::pngspath$pagenum.jpg";
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
	if ( not $::globalviewerpath ) {
		&::setviewerpath($textwindow);
	}
	my $imagefile = &::get_image_file($pagenum);
	if ( $imagefile && $::globalviewerpath ) {
		&::runner( $::globalviewerpath, $imagefile );
	} else {
		&::setpngspath($pagenum);
	}
	return;
}

sub setviewerpath {    #Find your image viewer
	my $textwindow = shift;
	my $types;
	if ($::OS_WIN) {
		$types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
	} else {
		$types = [ [ 'All Files', ['*'] ] ];
	}
	#print $::globalviewerpath."aa\n";
#	print &::dirname($::globalviewerpath)."aa\n";
	
	$::lglobal{pathtemp} =
	  $textwindow->getOpenFile(
								-filetypes  => $types,
								-title      => 'Where is your image viewer?',
								-initialdir => &::dirname($::globalviewerpath)
	  );
	$::globalviewerpath = $::lglobal{pathtemp} if $::lglobal{pathtemp};
	$::globalviewerpath = &::os_normal($::globalviewerpath);
	&::savesettings();
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
	my $textwindow = $::textwindow;
	my $top = $::top;

	# Set up a bunch of events and key bindings for the widget
	$textwindow->tagConfigure( 'footnote', -background => 'cyan' );
	$textwindow->tagConfigure( 'scannos',  -background => $::highlightcolor );
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
	$textwindow->tagBind( 'pagenum', '<ButtonRelease-1>', \&::pnumadjust );
	$textwindow->eventAdd( '<<hlquote>>' => '<Control-quoteright>' );
	$textwindow->bind( '<<hlquote>>', sub { &::hilite('\'') } );
	$textwindow->eventAdd( '<<hldquote>>' => '<Control-quotedbl>' );
	$textwindow->bind( '<<hldquote>>', sub { &::hilite('"') } );
	$textwindow->eventAdd( '<<hlrem>>' => '<Control-0>' );
	$textwindow->bind(
		'<<hlrem>>',
		sub {
			$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			$textwindow->tagRemove( 'quotemark', '1.0', 'end' );
		}
	);
	$textwindow->bind( 'TextUnicode', '<Control-s>' => \&::savefile );
	$textwindow->bind( 'TextUnicode', '<Control-S>' => \&::savefile );
	$textwindow->bind( 'TextUnicode',
					   '<Control-a>' => sub { $textwindow->selectAll } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-A>' => sub { $textwindow->selectAll } );
	$textwindow->eventAdd( '<<Copy>>' => '<Control-C>',
						   '<Control-c>', '<F1>' );
	$textwindow->bind( 'TextUnicode', '<<Copy>>' => \&::textcopy );
	$textwindow->eventAdd( '<<Cut>>' => '<Control-X>',
						   '<Control-x>', '<F2>' );
	$textwindow->bind( 'TextUnicode', '<<Cut>>' => sub { &::cut() } );

	$textwindow->bind( 'TextUnicode', '<Control-V>' => sub { &::paste() } );
	$textwindow->bind( 'TextUnicode', '<Control-v>' => sub { &::paste() } );
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
					   '<Control-l>' => sub { &::case ( $textwindow, 'lc' ); } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-u>' => sub { &::case ( $textwindow, 'uc' ); } );
	$textwindow->bind( 'TextUnicode',
			 '<Control-t>' => sub { &::case ( $textwindow, 'tc' ); $top->break } );
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
	$textwindow->bind( 'TextUnicode', '<Control-f>' => \&::searchpopup );
	$textwindow->bind( 'TextUnicode', '<Control-F>' => \&::searchpopup );
	$textwindow->bind( 'TextUnicode', '<Control-p>' => \&::gotopage );
	$textwindow->bind( 'TextUnicode', '<Control-P>' => \&::gotopage );
	$textwindow->bind(
		'TextUnicode',
		'<Control-w>' => sub {
			$textwindow->addGlobStart;
			&::floodfill();
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Control-W>' => sub {
			$textwindow->addGlobStart;
			&::floodfill();
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind( 'TextUnicode',
					   '<Control-Shift-exclam>' => sub { &::setbookmark('1') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-Shift-at>' => sub { &::setbookmark('2') } );
	$textwindow->bind( 'TextUnicode',
					 '<Control-Shift-numbersign>' => sub { &::setbookmark('3') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-Shift-dollar>' => sub { &::setbookmark('4') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-Shift-percent>' => sub { &::setbookmark('5') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-KeyPress-1>' => sub { &::gotobookmark('1') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-KeyPress-2>' => sub { &::gotobookmark('2') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-KeyPress-3>' => sub { &::gotobookmark('3') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-KeyPress-4>' => sub { &::gotobookmark('4') } );
	$textwindow->bind( 'TextUnicode',
					   '<Control-KeyPress-5>' => sub { &::gotobookmark('5') } );
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Left>' => sub {
			$textwindow->addGlobStart;
			&::indent('out');
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Right>' => sub {
			$textwindow->addGlobStart;
			&::indent('in');
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Up>' => sub {
			$textwindow->addGlobStart;
			&::indent('up');
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Down>' => sub {
			$textwindow->addGlobStart;
			&::indent('dn');
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind( 'TextUnicode', '<F7>' => \&::spellchecker );

	$textwindow->bind(
		'TextUnicode',
		'<Control-Alt-s>' => sub {
			unless ( -e 'scratchpad.txt' ) {
				open my $fh, '>', 'scratchpad.txt'
				  or warn "Could not create file $!";
			}
			&::runner('start scratchpad.txt') if $::OS_WIN;
		}
	);
	$textwindow->bind( 'TextUnicode', '<Control-Alt-r>' => sub { &::regexref() } );
	$textwindow->bind( 'TextUnicode', '<Shift-B1-Motion>', 'shiftB1_Motion' );
	$textwindow->eventAdd( '<<FindNext>>' => '<Control-Key-G>',
						   '<Control-Key-g>' );
	$textwindow->bind( '<<ScrollDismiss>>', \&::scrolldismiss );
	$textwindow->bind( 'TextUnicode', '<ButtonRelease-2>',
					   sub { popscroll() unless $Tk::mouseMoved } );
	$textwindow->bind(
		'<<FindNext>>',
		sub {
			if ( $::lglobal{searchpop} ) {
				my $searchterm = $::lglobal{searchentry}->get( '1.0', '1.end' );
				&::searchtext($textwindow,$top,$searchterm);
			} else {
				&::searchpopup();
			}
		}
	);
	if ($::OS_WIN) {
		$textwindow->bind(
			'TextUnicode',
			'<3>' => sub {
				&::scrolldismiss();
				$::menubar->Popup( -popover => 'cursor' );
			}
		);
	} else {
		$textwindow->bind( 'TextUnicode', '<3>' => sub { &::scrolldismiss() } )
		  ;    # Try to trap odd right click error under OSX and Linux
	}
	$textwindow->bind( 'TextUnicode', '<Control-Alt-h>' => \&::hilitepopup );
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
	&::drag($textwindow);
}

sub popscroll {
	if ( $::lglobal{scroller} ) {
		&::scrolldismiss();
		return;
	}
	my $x = $::top->pointerx - $::top->rootx;
	my $y = $::top->pointery - $::top->rooty - 8;
	$::lglobal{scroller} = $::top->Label(
									  -background  => $::textwindow->cget( -bg ),
									  -image       => $::lglobal{scrollgif},
									  -cursor      => 'double_arrow',
									  -borderwidth => 0,
									  -highlightthickness => 0,
									  -relief             => 'flat',
	)->place( -x => $x, -y => $y );

	$::lglobal{scroller}->eventAdd( '<<ScrollDismiss>>', qw/<1> <3>/ );
	$::lglobal{scroller}
	  ->bind( 'current', '<<ScrollDismiss>>', sub { &::scrolldismiss(); } );
	$::lglobal{scroll_y}  = $y;
	$::lglobal{scroll_x}  = $x;
	$::lglobal{oldcursor} = $::textwindow->cget( -cursor );
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
	$::lglobal{scroll_id} = $::top->repeat( $::scrollupdatespd, \&::b2scroll );
}

# Command parsing for External command routine
sub cmdinterp {
	# Allow basic quoting, in case anyone specifies paths with spaces.
	# Don't support paths with quotes.  The standard \" and \\ escapes
	# would not be friendly on Windows-style paths.
	my $textwindow = $::textwindow;
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
			$arg = &::encode( "utf-8", $arg );
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
				$arg =~ s/project/$::projectid/;
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
			return ' ' unless $::pngspath;
			$arg =~ s/\$i/$::pngspath/;
		}
	}
	return @args;
}

sub nofileloadedwarning {
	my $top = $::top;
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
	my ( $f, $d, $e ) = &::fileparse( $fname, qr{\.[^\.]*$} );
	opendir( DIR, "$d" );
	for ( readdir(DIR) ) {
		if ( $_ =~ m/(project.*)_comments.html/ ) {
			$::projectid = $1;
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

	foreach my $ext ( split ';', $::ENV{PATHEXT} )
	{
		my $p = $exe . $ext;
		return $p if win32_is_exe($p);
	}

	if ( ! File::Spec->file_name_is_absolute($exe) )
	{
		foreach my $path ( split ';', $::ENV{PATH} )
		{
			my $stem = &::catfile($path, $exe);
			return $stem if win32_is_exe($stem);

			foreach my $ext ( split ';', $::ENV{PATHEXT} ) {
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

	if ( ! $::OS_WIN ) {
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

	if ( ! $::OS_WIN ) {
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
		::run( @args );

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
	for my $key (keys %::projectdict){
		print $save "$key => $::projectdict{$key}\n";
	};
	close $save;
};



1;