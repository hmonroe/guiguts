package Guiguts::FileMenu;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&file_open &file_saveas &file_include &file_export &file_import &file_close 
	&_flash_save &_exit )
}

sub file_open {    # Find a text file to open
	my $textwindow = shift;
	my ($name);
	return if ( &main::confirmempty() =~ /cancel/i );
	my $types = [
				  [
					'Text Files',
					[qw/.txt .text .ggp .htm .html .rst .bk1 .bk2 .xml .tei/]
				  ],
				  [ 'All Files', ['*'] ],
	];
	$name = $textwindow->getOpenFile(
									  -filetypes  => $types,
									  -title      => 'Open File',
									  -initialdir => $main::globallastpath
	);
	if ( defined($name) and length($name) ) {
		&main::openfile($name);
	}
}



sub file_include {    # FIXME: Should include even if no file loaded.
	my $textwindow= shift;
	my ($name);
	my $types = [
				  [
					 'Text Files',
					 [ '.txt', '.text', '.ggp', '.htm', '.html', '.rst','.tei','.xml' ]
				  ],
				  [ 'All Files', ['*'] ],
	];
	return if $main::lglobal{global_filename} =~ m{No File Loaded};
	$name = $textwindow->getOpenFile(
									  -filetypes  => $types,
									  -title      => 'File Include',
									  -initialdir => $main::globallastpath
	);
	$textwindow->IncludeFile($name)
	  if defined($name)
		  and length($name);
	&main::update_indicators();
	return;
}

sub file_saveas {
	my $textwindow = shift;
	my ($name);
	$name = $textwindow->getSaveFile( -title      => 'Save As',
									  -initialdir => $main::globallastpath );
	if ( defined($name) and length($name) ) {
		my $binname = $name;
		$binname =~ s/\.[^\.]*?$/\.bin/;
		if ( $binname eq $name ) { $binname .= '.bin' }
		if ( -e $binname ) {
			my $warning = $top->Dialog(    # FIXME: heredoc
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
		( $fname, $main::globallastpath, $extension ) = &main::fileparse($name);
		$main::globallastpath = &main::os_normal($main::globallastpath);
		$name           = &main::os_normal($name);
		$textwindow->FileName($name);
		$main::lglobal{global_filename} = $name;
		&main::_bin_save();
		&main::_recentupdate($name);
	} else {
		return;
	}
	&main::update_indicators();
	return;
}


sub file_close {
	return if ( &main::confirmempty() =~ m{cancel}i );
	&main::clearvars();
	&main::update_indicators();
	return;
}

sub file_import {
	my ($textwindow,$top)=@_;
	return if ( &main::confirmempty() =~ /cancel/i );
	my $directory = $top->chooseDirectory( -title =>
			'Choose the directory containing the text files to be imported.', );
	return 0
	  unless ( -d $directory and defined $directory and $directory ne '' );
	$top->Busy( -recurse => 1 );
	my $pwd = &main::getcwd();
	chdir $directory;
	my @files = glob "*.txt";
	chdir $pwd;
	$directory .= '/';
	$directory      = &main::os_normal($directory);
	$main::globallastpath = $directory;

	for my $file (sort {$a <=> $b} @files) {
		if ( $file =~ /^(\w+)\.txt/ ) {
			$textwindow->ntinsert( 'end', ( "\n" . '-' x 5 ) );
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
	$main::lglobal{prepfile} = 1;
	&main::file_mark_pages();
	$main::pngspath = '';
	$top->Unbusy( -recurse => 1 );
	return;
}

sub file_export {
	my ($textwindow,$top)=@_;
	my $directory = $top->chooseDirectory(
			   -title => 'Choose the directory to export the text files to.', );
	return 0 unless ( defined $directory and $directory ne '' );
	unless ( -e $directory ) {
		mkdir $directory or warn "Could not make directory $!\n" and return;
	}
	$top->Busy( -recurse => 1 );
	my @marks = $textwindow->markNames;
	my @pages = sort grep ( /^Pg\S+$/, @marks );
	my $unicode =
	  $textwindow->search( '-regexp', '--', '[\x{100}-\x{FFFE}]', '1.0',
						   'end' );
	while (@pages) {
		my $page = shift @pages;
		my ($filename) = $page =~ /Pg(\S+)/;
		$filename .= '.txt';
		my $next;
		if (@pages) {
			$next = $pages[0];
		} else {
			$next = 'end';
		}
		my $file = $textwindow->get( $page, $next );
		$file =~ s/-*\s?File:\s?(\S+)\.(png|jpg)---[^\n]*\n//;
		$file =~ s/\n+$//;
		open my $fh, '>', "$directory/$filename";
		if ($unicode) {

			#$file = "\x{FEFF}" . $file;    # Add the BOM to beginning of file.
			utf8::encode($file);
		}
		print $fh $file;
	}
	$top->Unbusy( -recurse => 1 );
	return;
}

sub _flash_save {
	$main::lglobal{saveflashingid} = $top->repeat(
		500,
		sub {
			if ( $main::lglobal{savetool}->cget('-background') eq 'yellow' ) {
				$main::lglobal{savetool}->configure(
											   -background       => 'green',
											   -activebackground => 'green'
				) unless $main::notoolbar;
			} else {
				$main::lglobal{savetool}->configure(
											   -background       => 'yellow',
											   -activebackground => 'yellow'
				) if ($textwindow->numberChanges and (!$main::notoolbar));
			}
		}
	);
	return;
}


## Global Exit
sub _exit {
	if ( &main::confirmdiscard() =~ m{no}i ) {
		&main::aspellstop() if $main::lglobal{spellpid};
		exit;
	}
}



1;


