package Guiguts::FileMenu;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&file_open &file_saveas &file_include &file_export &file_import &_bin_save &file_close 
	&_flash_save &clearvars &savefile &_exit &file_mark_pages &_recentupdate)
}

sub file_open {    # Find a text file to open
	my $textwindow = shift;
	#my %lglobal;
	#%lglobal = %{\%main::lglobal};
	#$lglobal{test}="abcd";	
	
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
			my $warning = $main::top->Dialog(    # FIXME: heredoc
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
		_bin_save($textwindow,$main::top);
		&main::_recentupdate($name);
	} else {
		return;
	}
	&main::update_indicators();
	return;
}

sub file_close {
	my $textwindow = shift;
	return if ( &main::confirmempty() =~ m{cancel}i );
	clearvars($textwindow);
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
	$main::lglobal{saveflashingid} = $main::top->repeat(
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
				) if ($main::textwindow->numberChanges and (!$main::notoolbar));
			}
		}
	);
	return;
}

## save the .bin file associated with the text file
sub _bin_save {
	my ($textwindow,$top)=@_;
	push @main::operations, ( localtime() . ' - File Saved' );
	&main::oppopupdate() if $main::lglobal{oppop};
	my $mark = '1.0';
	while ( $textwindow->markPrevious($mark) ) {
		$mark = $textwindow->markPrevious($mark);
	}
	my $markindex;
	while ($mark) {
		if ( $mark =~ m{Pg(\S+)} ) {
			$markindex                  = $textwindow->index($mark);
			$main::pagenumbers{$mark}{offset} = $markindex;
			$mark                       = $textwindow->markNext($mark);
		} else {
			$mark = $textwindow->markNext($mark) if $mark;
			next;
		}
	}
	return if ( $main::lglobal{global_filename} =~ m{No File Loaded} );
	my $binname = "$main::lglobal{global_filename}.bin";
	if ( $textwindow->markExists('spellbkmk') ) {
		$main::spellindexbkmrk = $textwindow->index('spellbkmk');
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
		for my $page ( sort { $a cmp $b } keys %main::pagenumbers ) {
			no warnings 'uninitialized';
			if ( $page eq "Pg" ) {
				next;
			}
			print $fh " '$page' => {";
			print $fh "'offset' => '$main::pagenumbers{$page}{offset}', ";
			print $fh "'label' => '$main::pagenumbers{$page}{label}', ";
			print $fh "'style' => '$main::pagenumbers{$page}{style}', ";
			print $fh "'action' => '$main::pagenumbers{$page}{action}', ";
			print $fh "'base' => '$main::pagenumbers{$page}{base}'},\n";
		}
		print $fh ");\n\n";

		print $fh '$main::bookmarks[0] = \'' . $textwindow->index('insert') . "';\n";
		for ( 1 .. 5 ) {
			print $fh '$main::bookmarks[' 
			  . $_ 
			  . '] = \''
			  . $textwindow->index( 'bkmk' . $_ ) . "';\n"
			  if $main::bookmarks[$_];
		}
		if ($main::pngspath) {
			print $fh "\n\$main::pngspath = '@{[&main::escape_problems($main::pngspath)]}';\n\n";
		}
		my ($prfr);
		delete $main::proofers{''};
		foreach my $page ( sort keys %main::proofers ) {

			no warnings 'uninitialized';
			for my $round ( 1 .. $main::lglobal{numrounds} ) {
				if ( defined $main::proofers{$page}->[$round] ) {
					print $fh '$main::proofers{\'' 
					  . $page . '\'}[' 
					  . $round
					  . '] = \''
					  . $main::proofers{$page}->[$round] . '\';' . "\n";
				}
			}
		}
		print $fh "\n\n";
		print $fh "\@operations = (\n";
		for my $mark (@main::operations) {
			$mark = &main::escape_problems($mark);
			print $fh "'$mark',\n";
		}
		print $fh ");\n\n";
		print $fh "\$main::spellindexbkmrk = '$main::spellindexbkmrk';\n\n";
		print $fh "\$projectid = '$main::projectid';\n\n";
		print $fh "\$booklang = '$main::booklang';\n\n";
		print $fh
"\$scannoslistpath = '@{[&main::escape_problems(&main::os_normal($main::scannoslistpath))]}';\n\n";
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
	%main::reghints = ();
	%{ $main::lglobal{seenwordsdoublehyphen} } = ();
	$main::lglobal{seenwords}     = ();
	$main::lglobal{seenwordpairs} = ();
	$main::lglobal{fnarray}       = ();
	%main::proofers               = ();
	%main::pagenumbers            = ();
	@main::operations             = ();
	@main::bookmarks              = ();
	$main::pngspath               = q{};
	$main::lglobal{seepagenums}   = 0;
	@{ $main::lglobal{fnarray} } = ();
	undef $main::lglobal{prepfile};
	return;
}

sub savefile {    # Determine which save routine to use and then use it
	my ($textwindow,$top)=($main::textwindow,$main::top);
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	if ( $main::lglobal{global_filename} =~ /No File Loaded/ ) {
		if ( $textwindow->numberChanges == 0 ) {
			return;
		}
		my ($name);
		$name =
		  $textwindow->getSaveFile( -title      => 'Save As',
									-initialdir => $main::globallastpath );
		if ( defined($name) and length($name) ) {
			$textwindow->SaveUTF($name);
			$name = &main::os_normal($name);
			&main::_recentupdate($name);
		} else {
			return;
		}
	} else {
		if ($main::autobackup) {
			if ( -e $main::lglobal{global_filename} ) {
				if ( -e "$main::lglobal{global_filename}.bk2" ) {
					unlink "$main::lglobal{global_filename}.bk2";
				}
				if ( -e "$main::lglobal{global_filename}.bk1" ) {
					rename( "$main::lglobal{global_filename}.bk1",
							"$main::lglobal{global_filename}.bk2" );
				}
				rename( $main::lglobal{global_filename},
						"$main::lglobal{global_filename}.bk1" );
			}
		}
		$textwindow->SaveUTF;
	}
	$textwindow->ResetUndo;
	&main::_bin_save($textwindow,$top);
	&main::set_autosave() if $main::autosave;
	&main::update_indicators();
}

sub file_mark_pages {
	my $top =$main::top;
	my $textwindow = $main::textwindow;
	
	$top->Busy( -recurse => 1 );
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	my ( $line, $index, $page, $rnd1, $rnd2, $pagemark );
	$main::searchstartindex = '1.0';
	$main::searchendindex   = '1.0';
	while ($main::searchstartindex) {
		#$main::searchstartindex =
		#  $textwindow->search( '-exact', '--',
		#					   '--- File:',
		#					   $main::searchendindex, 'end' );
 		$main::searchstartindex =$textwindow->search( '-nocase', '-regexp', '--',
							   '-*\s?File:\s?(\S+)\.(png|jpg)---.*$',
							   $main::searchendindex, 'end' );
		last unless $main::searchstartindex;
		my ( $row, $col ) = split /\./, $main::searchstartindex;
		$line = $textwindow->get( "$row.0", "$row.end" );
		$main::searchendindex = $textwindow->index("$main::searchstartindex lineend");
		#$line = $textwindow->get( $main::searchstartindex, $main::searchendindex );

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
			@{ $main::proofers{$page} } = split( "\Q\\\E", $prftrim );
		}

		$pagemark = 'Pg' . $page;
		$main::pagenumbers{$pagemark}{offset} = 1;
		$textwindow->markSet( $pagemark, $main::searchstartindex );
		$textwindow->markGravity( $pagemark, 'left' );
	}
	delete $main::proofers{''};
	$top->Unbusy( -recurse => 1 );
	return;
}

## Track recently open files for the menu
sub _recentupdate {    # FIXME: Seems to be choking.
	my $name = shift;

	# remove $name or any *empty* values from the list
	@main::recentfile = grep( !/(?: \Q$name\E | \Q*empty*\E )/x, @main::recentfile );

	# place $name at the top
	unshift @main::recentfile, $name;

	# limit the list to 10 entries
	pop @main::recentfile while ( $#main::recentfile > 10 );
	&main::menurebuild();
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


