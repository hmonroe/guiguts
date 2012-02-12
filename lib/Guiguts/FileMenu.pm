package Guiguts::FileMenu;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&file_open &file_saveas &file_include &file_export &file_import &_bin_save &file_close 
	&_flash_save &clearvars &savefile &_exit &file_mark_pages &_recentupdate &file_guess_page_marks
	&oppopupdate &opspop_up)
}

sub file_open {    # Find a text file to open
	my $textwindow = shift;
	#my %lglobal;
	#%lglobal = %{\%::lglobal};
	#$::lglobal{test}="abcd";	
	
	my ($name);
	return if ( &::confirmempty() =~ /cancel/i );
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
									  -initialdir => $::globallastpath
	);
	if ( defined($name) and length($name) ) {
		&::openfile($name);
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
	return if $::lglobal{global_filename} =~ m{No File Loaded};
	$name = $textwindow->getOpenFile(
									  -filetypes  => $types,
									  -title      => 'File Include',
									  -initialdir => $::globallastpath
	);
	$textwindow->IncludeFile($name)
	  if defined($name)
		  and length($name);
	&::update_indicators();
	return;
}

sub file_saveas {
	my $textwindow = shift;
	my ($name);
	$name = $textwindow->getSaveFile( -title      => 'Save As',
									  -initialdir => $::globallastpath );
	if ( defined($name) and length($name) ) {
		my $binname = $name;
		$binname =~ s/\.[^\.]*?$/\.bin/;
		if ( $binname eq $name ) { $binname .= '.bin' }
		if ( -e $binname ) {
			my $warning = $::top->Dialog(    # FIXME: heredoc
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
		( $fname, $::globallastpath, $extension ) = &::fileparse($name);
		$::globallastpath = &::os_normal($::globallastpath);
		$name           = &::os_normal($name);
		$textwindow->FileName($name);
		$::lglobal{global_filename} = $name;
		_bin_save($textwindow,$::top);
		&::_recentupdate($name);
	} else {
		return;
	}
	&::update_indicators();
	return;
}

sub file_close {
	my $textwindow = shift;
	return if ( &::confirmempty() =~ m{cancel}i );
	clearvars($textwindow);
	&::update_indicators();
	return;
}

sub file_import {
	my ($textwindow,$top)=@_;
	return if ( &::confirmempty() =~ /cancel/i );
	my $directory = $top->chooseDirectory( -title =>
			'Choose the directory containing the text files to be imported.', );
	return 0
	  unless ( -d $directory and defined $directory and $directory ne '' );
	$top->Busy( -recurse => 1 );
	my $pwd = &::getcwd();
	chdir $directory;
	my @files = glob "*.txt";
	chdir $pwd;
	$directory .= '/';
	$directory      = &::os_normal($directory);
	$::globallastpath = $directory;

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
	$::lglobal{prepfile} = 1;
	&::file_mark_pages();
	$::pngspath = '';
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
	$::lglobal{saveflashingid} = $::top->repeat(
		500,
		sub {
			if ( $::lglobal{savetool}->cget('-background') eq 'yellow' ) {
				$::lglobal{savetool}->configure(
											   -background       => 'green',
											   -activebackground => 'green'
				) unless $::notoolbar;
			} else {
				$::lglobal{savetool}->configure(
											   -background       => 'yellow',
											   -activebackground => 'yellow'
				) if ($::textwindow->numberChanges and (!$::notoolbar));
			}
		}
	);
	return;
}

## save the .bin file associated with the text file
sub _bin_save {
	my ($textwindow,$top)=@_;
	push @::operations, ( localtime() . ' - File Saved' );
	&::oppopupdate() if $::lglobal{oppop};
	my $mark = '1.0';
	while ( $textwindow->markPrevious($mark) ) {
		$mark = $textwindow->markPrevious($mark);
	}
	my $markindex;
	while ($mark) {
		if ( $mark =~ m{Pg(\S+)} ) {
			$markindex                  = $textwindow->index($mark);
			$::pagenumbers{$mark}{offset} = $markindex;
			$mark                       = $textwindow->markNext($mark);
		} else {
			$mark = $textwindow->markNext($mark) if $mark;
			next;
		}
	}
	return if ( $::lglobal{global_filename} =~ m{No File Loaded} );
	my $binname = "$::lglobal{global_filename}.bin";
	if ( $textwindow->markExists('spellbkmk') ) {
		$::spellindexbkmrk = $textwindow->index('spellbkmk');
	}
	my $bak = "$binname.bak";
	if ( -e $bak ) {
		my $perms = ( stat($bak) )[2] & 7777;
		unless ( $perms & 300 ) {
			$perms = $perms | 300;
			chmod $perms, $bak or warn "Can not back up .bin file: $!\n";
		}
		unlink $bak;
	}
	if ( -e $binname ) {
		my $perms = ( stat($binname) )[2] & 7777;
		unless ( $perms & 300 ) {
			$perms = $perms | 300;
			chmod $perms, $binname
			  or warn "Can not save .bin file: $!\n" and return;
		}
		rename $binname, $bak or warn "Can not back up .bin file: $!\n";
	}
	my $fh = FileHandle->new("> $binname");
	if ( defined $fh ) {
		print $fh "\%pagenumbers = (\n";
		for my $page ( sort { $a cmp $b } keys %::pagenumbers ) {
			no warnings 'uninitialized';
			if ( $page eq "Pg" ) {
				next;
			}
			print $fh " '$page' => {";
			print $fh "'offset' => '$::pagenumbers{$page}{offset}', ";
			print $fh "'label' => '$::pagenumbers{$page}{label}', ";
			print $fh "'style' => '$::pagenumbers{$page}{style}', ";
			print $fh "'action' => '$::pagenumbers{$page}{action}', ";
			print $fh "'base' => '$::pagenumbers{$page}{base}'},\n";
		}
		print $fh ");\n\n";

		print $fh '$::bookmarks[0] = \'' . $textwindow->index('insert') . "';\n";
		for ( 1 .. 5 ) {
			print $fh '$::bookmarks[' 
			  . $_ 
			  . '] = \''
			  . $textwindow->index( 'bkmk' . $_ ) . "';\n"
			  if $::bookmarks[$_];
		}
		if ($::pngspath) {
			print $fh "\n\$::pngspath = '@{[&::escape_problems($::pngspath)]}';\n\n";
		}
		my ($prfr);
		delete $::proofers{''};
		foreach my $page ( sort keys %::proofers ) {

			no warnings 'uninitialized';
			for my $round ( 1 .. $::lglobal{numrounds} ) {
				if ( defined $::proofers{$page}->[$round] ) {
					print $fh '$::proofers{\'' 
					  . $page . '\'}[' 
					  . $round
					  . '] = \''
					  . $::proofers{$page}->[$round] . '\';' . "\n";
				}
			}
		}
		print $fh "\n\n";
		print $fh "\@operations = (\n";
		for my $mark (@::operations) {
			$mark = &::escape_problems($mark);
			print $fh "'$mark',\n";
		}
		print $fh ");\n\n";
		print $fh "\$::spellindexbkmrk = '$::spellindexbkmrk';\n\n";
		print $fh "\$projectid = '$::projectid';\n\n";
		print $fh "\$booklang = '$::booklang';\n\n";
		print $fh
"\$scannoslistpath = '@{[&::escape_problems(&::os_normal($::scannoslistpath))]}';\n\n";
		print $fh '1;';
		$fh->close;
	} else {
		$top->BackTrace("Cannot open $binname:$!");
	}
	return;
}


## Clear persistent variables before loading another file
sub clearvars {
	my $textwindow = shift;
	my @marks = $textwindow->markNames;
	for (@marks) {
		unless ( $_ =~ m{insert|current} ) {
			$textwindow->markUnset($_);
		}
	}
	%::reghints = ();
	%{ $::lglobal{seenwordsdoublehyphen} } = ();
	$::lglobal{seenwords}     = ();
	$::lglobal{seenwordpairs} = ();
	$::lglobal{fnarray}       = ();
	%::proofers               = ();
	%::pagenumbers            = ();
	@::operations             = ();
	@::bookmarks              = ();
	$::pngspath               = q{};
	$::lglobal{seepagenums}   = 0;
	@{ $::lglobal{fnarray} } = ();
	undef $::lglobal{prepfile};
	return;
}

sub savefile {    # Determine which save routine to use and then use it
	my ($textwindow,$top)=($::textwindow,$::top);
	&::viewpagenums() if ( $::lglobal{seepagenums} );
	if ( $::lglobal{global_filename} =~ /No File Loaded/ ) {
		if ( $textwindow->numberChanges == 0 ) {
			return;
		}
		my ($name);
		$name =
		  $textwindow->getSaveFile( -title      => 'Save As',
									-initialdir => $::globallastpath );
		if ( defined($name) and length($name) ) {
			$textwindow->SaveUTF($name);
			$name = &::os_normal($name);
			&::_recentupdate($name);
		} else {
			return;
		}
	} else {
		if ($::autobackup) {
			if ( -e $::lglobal{global_filename} ) {
				if ( -e "$::lglobal{global_filename}.bk2" ) {
					unlink "$::lglobal{global_filename}.bk2";
				}
				if ( -e "$::lglobal{global_filename}.bk1" ) {
					rename( "$::lglobal{global_filename}.bk1",
							"$::lglobal{global_filename}.bk2" );
				}
				rename( $::lglobal{global_filename},
						"$::lglobal{global_filename}.bk1" );
			}
		}
		$textwindow->SaveUTF;
	}
	$textwindow->ResetUndo;
	&::_bin_save($textwindow,$top);
	&::set_autosave() if $::autosave;
	&::update_indicators();
}

sub file_mark_pages {
	my $top =$::top;
	my $textwindow = $::textwindow;
	
	$top->Busy( -recurse => 1 );
	&::viewpagenums() if ( $::lglobal{seepagenums} );
	my ( $line, $index, $page, $rnd1, $rnd2, $pagemark );
	$::searchstartindex = '1.0';
	$::searchendindex   = '1.0';
	while ($::searchstartindex) {
		#$::searchstartindex =
		#  $textwindow->search( '-exact', '--',
		#					   '--- File:',
		#					   $::searchendindex, 'end' );
 		$::searchstartindex =$textwindow->search( '-nocase', '-regexp', '--',
							   '-*\s?File:\s?(\S+)\.(png|jpg)---.*$',
							   $::searchendindex, 'end' );
		last unless $::searchstartindex;
		my ( $row, $col ) = split /\./, $::searchstartindex;
		$line = $textwindow->get( "$row.0", "$row.end" );
		$::searchendindex = $textwindow->index("$::searchstartindex lineend");
		#$line = $textwindow->get( $::searchstartindex, $::searchendindex );

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
		#		if ( $line =~ /-+File:.*?-+([^-]+)-+/ ) {
		if ( $line =~ /^-----*\s?File:\s?\S+\.(png|jpg)---(.*)$/ ) {
			my $prftrim = $2;
			$prftrim =~ s/-*$//g;

			# split the proofer string into parts
			@{ $::proofers{$page} } = split( "\Q\\\E", $prftrim );
		}

		$pagemark = 'Pg' . $page;
		$::pagenumbers{$pagemark}{offset} = 1;
		$textwindow->markSet( $pagemark, $::searchstartindex );
		$textwindow->markGravity( $pagemark, 'left' );
	}
	delete $::proofers{''};
	$top->Unbusy( -recurse => 1 );
	return;
}

## Track recently open files for the menu
sub _recentupdate {    # FIXME: Seems to be choking.
	my $name = shift;

	# remove $name or any *empty* values from the list
	@::recentfile = grep( !/(?: \Q$name\E | \Q*empty*\E )/x, @::recentfile );

	# place $name at the top
	unshift @::recentfile, $name;

	# limit the list to 10 entries
	pop @::recentfile while ( $#::recentfile > 10 );
	&::menurebuild();
	return;
}



## Global Exit
sub _exit {
	if ( &::confirmdiscard() =~ m{no}i ) {
		&::aspellstop() if $::lglobal{spellpid};
		exit;
	}
}

sub file_guess_page_marks {
	my $top = $::top;
	my $textwindow = $::textwindow;
	my ( $totpages, $line25, $linex );
	if ( $::lglobal{pgpop} ) {
		$::lglobal{pgpop}->deiconify;
	} else {
		$::lglobal{pgpop} = $top->Toplevel;
		$::lglobal{pgpop}->title('Guess Page Numbers');
		&::initialize_popup_with_deletebinding('pgpop');
		my $f0 = $::lglobal{pgpop}->Frame->pack;
		$f0->Label( -text =>
'This function should only be used if you have the page images but no page markers in the text.',
		)->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		my $f1 = $::lglobal{pgpop}->Frame->pack;
		$f1->Label( -text => 'How many pages are there total?', )
		  ->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		my $tpages = $f1->Entry(
								 -background => $::bkgcolor,
								 -width      => 8,
		)->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
		$f1->Label( -text => 'What line # does page 25 start with?', )
		  ->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
		my $page25 = $f1->Entry(
								 -background => $::bkgcolor,
								 -width      => 8,
		)->grid( -row => 2, -column => 2, -padx => 1, -pady => 2 );
		my $f3 = $::lglobal{pgpop}->Frame->pack;
		$f3->Label(
			 -text => 'Select a page near the back, before the index starts.', )
		  ->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
		my $f4 = $::lglobal{pgpop}->Frame->pack;
		$f4->Label( -text => 'Page #?.', )
		  ->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		$f4->Label( -text => 'Line #?.', )
		  ->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
		my $pagexe = $f4->Entry(
								 -background => $::bkgcolor,
								 -width      => 8,
		)->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
		my $linexe = $f4->Entry(
								 -background => $::bkgcolor,
								 -width      => 8,
		)->grid( -row => 2, -column => 2, -padx => 1, -pady => 2 );
		my $f2 = $::lglobal{pgpop}->Frame->pack;
		my $calcbutton = $f2->Button(
			-activebackground => $::activecolor,
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
				for my $pnum ( 1 .. 24 ) {
					$lnum = int( ( $pnum - 1 ) * $average ) + 1;
					if ( $totpages > 999 ) {
						$number = sprintf '%04s', $pnum;
					} else {
						$number = sprintf '%03s', $pnum;
					}
					$textwindow->markSet( 'Pg' . $number, "$lnum.0" );
					$textwindow->markGravity( "Pg$number", 'left' );
				}
				$average =
				  ( ( int( $linex + .5 ) ) - ( int( $line25 + .5 ) ) ) /
				  ( $pagex - 25 );
				for my $pnum ( 1 .. $pagex - 26 ) {
					$lnum = int( ( $pnum - 1 ) * $average ) + 1 + $line25;
					if ( $totpages > 999 ) {
						$number = sprintf '%04s', $pnum + 25;
					} else {
						$number = sprintf '%03s', $pnum + 25;
					}
					$textwindow->markSet( "Pg$number", "$lnum.0" );
					$textwindow->markGravity( "Pg$number", 'left' );
				}
				$average =
				  ( $end - int( $linex + .5 ) ) / ( $totpages - $pagex );
				for my $pnum ( 1 .. ( $totpages - $pagex ) ) {
					$lnum = int( ( $pnum - 1 ) * $average ) + 1 + $linex;
					if ( $totpages > 999 ) {
						$number = sprintf '%04s', $pnum + $pagex;
					} else {
						$number = sprintf '%03s', $pnum + $pagex;
					}
					$textwindow->markSet( "Pg$number", "$lnum.0" );
					$textwindow->markGravity( "Pg$number", 'left' );
				}
				$::lglobal{pgpop}->destroy;
				undef $::lglobal{pgpop};
			},
			-text  => 'Guess Page #s',
			-width => 18
		)->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
	}
	return;
}

## Update the Operations history
sub oppopupdate {
	$::lglobal{oplistbox}->delete( '0', 'end' );
	$::lglobal{oplistbox}->insert( 'end', @::operations );
}

# Pop up an "Operation" history. Track which functions have already been
# run.
sub opspop_up {
	my $top = $::top;
	if ( $::lglobal{oppop} ) {
		$::lglobal{oppop}->deiconify;
		$::lglobal{oppop}->raise;
	} else {
		$::lglobal{oppop} = $top->Toplevel;
		$::lglobal{oppop}->title('Function history');
		&::initialize_popup_with_deletebinding('oppop');
		my $frame =
		  $::lglobal{oppop}->Frame->pack(
										-anchor => 'nw',
										-fill   => 'both',
										-expand => 'both',
										-padx   => 2,
										-pady   => 2
		  );
		$::lglobal{oplistbox} =
		  $frame->Scrolled(
							'Listbox',
							-scrollbars  => 'se',
							-background  => $::bkgcolor,
							-selectmode  => 'single',
							-activestyle => 'none',
		  )->pack(
				   -anchor => 'nw',
				   -fill   => 'both',
				   -expand => 'both',
				   -padx   => 2,
				   -pady   => 2
		  );
		&::drag( $::lglobal{oplistbox} );
	}
	&::oppopupdate();
}



1;


