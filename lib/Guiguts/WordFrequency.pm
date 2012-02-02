package Guiguts::WordFrequency;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&wordfrequencybuildwordlist &wordfrequency &bangmark)
}

sub wordfrequencybuildwordlist {
	my $textwindow = shift;
	my ( @words, $match, @savesets );
	my $index = '1.0';
	my $wc    = 0;
	my $end   = $textwindow->index('end');
	$main::lglobal{seenwordsdoublehyphen} = ();
	$main::lglobal{seenwords} = ();
	$main::lglobal{seenwordpairs} = ();
	

	my $filename = $textwindow->FileName;
	unless ($filename) {
		$filename = 'tempfile.tmp';
		open( my $file, ">", "$filename" );
		my ($lines) = $textwindow->index('end - 1 chars') =~ /^(\d+)\./;
		while ( $textwindow->compare( $index, '<', 'end' ) ) {
			my $end = $textwindow->index("$index  lineend +1c");
			my $line = $textwindow->get( $index, $end );
			print $file $line;
			$index = $end;
		}
	}
	savefile()
	  if (    ( $textwindow->FileName )
		   && ( $textwindow->numberChanges != 0 ) );
	open my $fh, '<', $filename;
	my $lastwordseen = '';
	while ( my $line = <$fh> ) {
		utf8::decode($line);
		next if $line =~ m/^-----*\s?File:\s?\S+\.(png|jpg)---/;
		$line =~ s/_/ /g;
		$line =~ s/<!--//g;
		$line =~ s/-->//g;
		if ( $main::lglobal{ignore_case} ) { $line = lc($line) }
		@words = split( /\s+/, $line );

		# build a list of "word--word""
		for my $word (@words) {
			next unless ( $word =~ /--/ );
			next if ( $word =~ /---/ );
			$word =~ s/[\.,']$//;
			$word =~ s/^[\.'-]+//;
			next if ( $word eq '' );
			$match = ( $main::lglobal{ignore_case} ) ? lc($word) : $word;
			$main::lglobal{seenwordsdoublehyphen}->{$match}++;
		}
		$line =~ s/[^'\.,\p{Alnum}-]/ /g;    # get rid of nonalphanumeric
		$line =~ s/--/ /g;                   # get rid of --
		$line =~
		  s/—/ /g;    # trying to catch words with real em-dashes, from dp2rst
		$line =~ s/(\D),/$1 /g;    # throw away comma after non-digit
		$line =~ s/,(\D)/ $1/g;    # and before
		@words = split( /\s+/, $line );
		for my $word (@words) {
			if ($lastwordseen && not ("$lastwordseen $match" =~ m/\d/)) {
				$main::lglobal{seenwordpairs}->{"$lastwordseen $match"}++;
			}
			$lastwordseen = $word;
			$word =~ s/\*//;    # throw away punctuation at end
			$word =~ s/[\.',-]+$//;    # throw away punctuation at end
			$word =~ s/^[\.,'-]+//;    #and at the beginning
			next if ( $word eq '' );
			$wc++;
			$match = ( $main::lglobal{ignore_case} ) ? lc($word) : $word;
			$main::lglobal{seenwords}->{$match}++;
		}
		$index++;
		$index .= '.0';
		$textwindow->update;
	}
	close $fh;
	unlink 'tempfile.tmp' if ( -e 'tempfile.tmp' );

	return $wc;
}

## Word Frequency
sub wordfrequency {
	my ($textwindow,$top) = @_;
	push @main::operations, ( localtime() . ' - Word Frequency' );
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	&main::oppopupdate()  if $main::lglobal{oppop};
	#$main::lglobal{seenwords} = ();
	#%{ $main::lglobal{seenwordsdoublehyphen} } = ();
	my ( @words, $match, @savesets );
	my $index = '1.0';
	my $wc    = 0;
	my $end   = $textwindow->index('end');
	&main::searchoptset(qw/1 0 x 0/);    # Default is whole word search

	if ( $main::lglobal{wfpop} ) {
		$main::lglobal{wfpop}->deiconify;
		$main::lglobal{wfpop}->raise;
		$main::lglobal{wclistbox}->delete( '0', 'end' );
	} else {
		$main::lglobal{wfpop} = $top->Toplevel;
		$main::lglobal{wfpop}
		  ->title('Word frequency - Ctrl+s to save, Ctrl+x to export');
		&main::initialize_popup_without_deletebinding('wfpop');
		my $wordfreqseframe =
		  $main::lglobal{wfpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my $wcopt3 =
		  $wordfreqseframe->Checkbutton(
										 -variable => \$main::lglobal{suspects_only},
										 -selectcolor => $main::lglobal{checkcolor},
										 -text        => 'Suspects only'
		  )->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		my $wcopt1 =
		  $wordfreqseframe->Checkbutton(
										 -variable    => \$main::lglobal{ignore_case},
										 -selectcolor => $main::lglobal{checkcolor},
										 -text        => 'No case',
		  )->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		$wordfreqseframe->Radiobutton(
									   -variable    => \$main::alpha_sort,
									   -selectcolor => $main::lglobal{checkcolor},
									   -value       => 'a',
									   -text        => 'Alph',
		)->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		$wordfreqseframe->Radiobutton(
									   -variable    => \$main::alpha_sort,
									   -selectcolor => $main::lglobal{checkcolor},
									   -value       => 'f',
									   -text        => 'Frq',
		)->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		$wordfreqseframe->Radiobutton(
									   -variable    => \$main::alpha_sort,
									   -selectcolor => $main::lglobal{checkcolor},
									   -value       => 'l',
									   -text        => 'Len',
		)->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		$wordfreqseframe->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				return unless ( $main::lglobal{wclistbox}->curselection );
				$main::lglobal{harmonics} = 1;
				&main::harmonicspop();
			},
			-text => '1st Harm',
		  )->pack(
				   -side   => 'left',
				   -padx   => 1,
				   -pady   => 1,
				   -anchor => 'nw'
		  );
		$wordfreqseframe->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				return unless ( $main::lglobal{wclistbox}->curselection );
				$main::lglobal{harmonics} = 2;
				&main::harmonicspop();
			},
			-text => '2nd Harm',
		  )->pack(
				   -side   => 'left',
				   -padx   => 1,
				   -pady   => 1,
				   -anchor => 'nw'
		  );
		$wordfreqseframe->Button(
			-activebackground => $main::activecolor,
			-command          => sub {

				#return if $main::lglobal{global_filename} =~ /No File Loaded/;
				#savefile() unless ( $textwindow->numberChanges == 0 );
				wordfrequency($textwindow);
			},
			-text => 'Rerun '
		  )->pack(
				   -side   => 'left',
				   -padx   => 2,
				   -pady   => 1,
				   -anchor => 'nw'
		  );
		my $wordfreqseframe1 =
		  $main::lglobal{wfpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my @wfbuttons = (
			[ 'Emdashes'  => \&main::dashcheck ],
			[ 'Hyphens'   => \&main::hyphencheck ],
			[ 'Alpha/num' => \&main::alphanumcheck ],
			[
			   'All Words' => sub {
				   $main::lglobal{saveheader} =
					 "$wc total words. " .
					 keys( %{ $main::lglobal{seenwords} } )
					 . " distinct words in file.";
				   &main::sortwords( $main::lglobal{seenwords} );
				   &main::searchoptset(qw/1 0 x 0/);    #default is whole word search
				 }
			],
			[ 'Check Spelling', \&main::wordfrequencyspellcheck ],
			[ 'Ital/Bold/SC', \&main::itwords, \&main::ital_adjust ],
			[ 'ALL CAPS',     \&main::capscheck ],
			[ 'MiXeD CasE',   \&main::mixedcasecheck ],
			[
			   'Initial Caps',
			   [
				  \&main::anythingwfcheck, 'words with initial caps',
				  '^\p{Upper}\P{Upper}+$'
			   ]
			],
			[ 'Character Cnts', \&main::charsortcheck ],
			[ 'Check , Upper',  \&main::commark ],
			[ 'Check . Lower',  sub{&main::bangmark($top) }],
			[ 'Check Accents',  \&main::accentcheck ],
			[
			   'Unicode > FF',
			   [
				  \&main::anythingwfcheck, 'words with unicode chars > FF',
				  '[\x{100}-\x{FFEF}]'
			   ]
			],

			[ 'Stealtho Check', \&main::stealthcheck ],
			[
			   'Ligatures',
			   [
				  \&main::anythingwfcheck,
				  'words with possible ligatures',
				  '(oe|ae|æ|Æ|\x{0153}|\x{0152})'
			   ]
			],
			[ 'RegExpEntry', [ \&main::anythingwfcheck, 'dummy entry', 'dummy' ] ],
			[
			   '<--RegExp',
			   [
				  sub {
					  &main::anythingwfcheck( 'words matching regular expression',
									   $main::regexpentry );
					}
			   ]
			],

		);
		my ( $row, $col, $inc ) = ( 0, 0, 0 );
		for (@wfbuttons) {
			$row = int( $inc / 5 );
			$col = $inc % 5;
			++$inc;
			if ( not( $_->[0] eq 'RegExpEntry' ) ) {
				my $button =
				  $wordfreqseframe1->Button(
											 -activebackground => $main::activecolor,
											 -command          => $_->[1],
											 -text             => $_->[0],
											 -width            => 13
				  )->grid(
						   -row    => $row,
						   -column => $col,
						   -padx   => 1,
						   -pady   => 1
				  );
				$button->bind( '<3>' => $_->[2] ) if $_->[2];
			} else {
				$main::lglobal{regexpentry} =
				  $wordfreqseframe1->Entry(
											-background   => $main::bkgcolor,
											-textvariable => \$main::regexpentry,
											-width        => 13,
				  )->grid( -row => $row, -column => $col );
			}
		}

		my $wcframe =
		  $main::lglobal{wfpop}->Frame->pack( -fill => 'both', -expand => 'both', );
		$main::lglobal{wclistbox} =
		  $wcframe->Scrolled(
							  'Listbox',
							  -scrollbars  => 'se',
							  -background  => $main::bkgcolor,
							  -font        => $main::lglobal{font},
							  -selectmode  => 'single',
							  -activestyle => 'none',
		  )->pack(
				   -anchor => 'nw',
				   -fill   => 'both',
				   -expand => 'both',
				   -padx   => 2,
				   -pady   => 2
		  );
		&main::drag( $main::lglobal{wclistbox} );
		$main::lglobal{wfpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$main::lglobal{wfpop}->destroy;
				undef $main::lglobal{wfpop};
				undef $main::lglobal{wclistbox};
			}
		);
		&main::BindMouseWheel( $main::lglobal{wclistbox} );
		$main::lglobal{wclistbox}->eventAdd( '<<search>>' => '<ButtonRelease-3>' );
		$main::lglobal{wclistbox}->bind(
			'<<search>>',
			sub {
				$main::lglobal{wclistbox}->selectionClear( 0, 'end' );
				$main::lglobal{wclistbox}->selectionSet(
										 $main::lglobal{wclistbox}->index(
											 '@'
											   . (
												 $main::lglobal{wclistbox}->pointerx -
												   $main::lglobal{wclistbox}->rootx
											   )
											   . ','
											   . (
												 $main::lglobal{wclistbox}->pointery -
												   $main::lglobal{wclistbox}->rooty
											   )
										 )
				);

				# right click means popup a search box
				my ($sword) =
				  $main::lglobal{wclistbox}->get( $main::lglobal{wclistbox}->curselection );
				&main::searchpopup();
				$sword =~ s/\d+\s+(\S)/$1/;
				$sword =~ s/\s+\*\*\*\*$//;
				if ( $sword =~ /\*space\*/ ) {
					$sword = ' ';
					&main::searchoptset(qw/0 x x 1/);
				} elsif ( $sword =~ /\*tab\*/ ) {
					$sword = '\t';
					&main::searchoptset(qw/0 x x 1/);
				} elsif ( $sword =~ /\*newline\*/ ) {
					$sword = '\n';
					&main::searchoptset(qw/0 x x 1/);
				} elsif ( $sword =~ /\*nbsp\*/ ) {
					$sword = '\x{A0}';
					&main::searchoptset(qw/0 x x 1/);
				} elsif ( $sword =~ /\W/ ) {
					$sword =~ s/([^\w\s\\])/\\$1/g;
					&main::searchoptset(qw/0 x x 1/);
				}
				$main::lglobal{searchentry}->delete( '1.0', 'end' );
				$main::lglobal{searchentry}->insert( 'end', $sword );
				&main::updatesearchlabels();
				$main::lglobal{searchentry}->after( $main::lglobal{delay} );
			}
		);
		$main::lglobal{wclistbox}
		  ->eventAdd( '<<find>>' => '<Double-Button-1>', '<Return>' );
		$main::lglobal{wclistbox}->bind(    # FIXME: This needs to go in GC code.
			'<<find>>',
			sub {
				my ($sword) =
				  $main::lglobal{wclistbox}->get( $main::lglobal{wclistbox}->curselection );
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

					#$sword = escape_regexmetacharacters($sword);
					$sword .= '\b'
					  if ( ( length $sword gt 1 ) && ( $sword =~ /\w$/ ) );
					&main::searchoptset(qw/0 0 x 1/);    # Case sensitive
				}

				# not whole word search from character cnts popup
				if (     ( length($sword) == 1 )
					 and ( $main::lglobal{saveheader} =~ /characters in the file./ ) )
				{
					&main::searchoptset(qw/0 0 x 0/);
				}
				if ( $main::intelligentWF && $sword =~ /^\\,(\s|\\n)/ ) {

		# during comma-Upper ck, ignore if name followed by period, !, or ?
		# NOTE: sword will be used as a regular expression filter during display
					$sword .= '([^\.\?\!]|$)';
				}

				if    ( $sword =~ /\*space\*/ )   { $sword = ' ' }
				elsif ( $sword =~ /\*tab\*/ )     { $sword = "\t" }
				elsif ( $sword =~ /\*newline\*/ ) { $sword = "\n" }
				elsif ( $sword =~ /\*nbsp\*/ )    { $sword = "\xA0" }
				unless ($snum) {
					&main::searchoptset(qw/0 x x 1/);
					unless ( $sword =~ m/--/ ) {
						$sword = "(?<=-)$sword|$sword(?=-)";
					}
				}

				#print $sopt[0],$sopt[1],$sopt[2],$sopt[3],$sopt[4].":sopt\n";
				&main::searchfromstartifnew($sword);
				&main::searchtext($sword);
				&main::searchoptset(@savesets);
				$main::top->raise;
			}
		);
		$main::lglobal{wclistbox}->eventAdd( '<<harm>>' => '<Control-Button-1>' );
		$main::lglobal{wclistbox}->bind(
			'<<harm>>',
			sub {
				return unless ( $main::lglobal{wclistbox}->curselection );
				&main::harmonics( $main::lglobal{wclistbox}->get('active') );
				&main::harmonicspop();
			}
		);
		$main::lglobal{wclistbox}->eventAdd( '<<adddict>>' => '<Control-Button-2>',
									   '<Control-Button-3>' );
		$main::lglobal{wclistbox}->bind(
			'<<adddict>>',
			sub {
				return unless ( $main::lglobal{wclistbox}->curselection );
				return unless $main::lglobal{wclistbox}->index('active');
				my $sword = $main::lglobal{wclistbox}->get('active');
				$sword =~ s/\d+\s+([\w'-]*)/$1/;
				$sword =~ s/\*\*\*\*$//;
				$sword =~ s/\s//g;
				return if ( $sword =~ /[^\p{Alnum}']/ );
				&main::spellmyaddword($sword);
				delete( $main::lglobal{spellsort}->{$sword} );
				$main::lglobal{saveheader} =
				  scalar( keys %{ $main::lglobal{spellsort} } )
				  . ' words not recognised by the spellchecker.';
				&main::sortwords( \%{ $main::lglobal{spellsort} } );
			}
		);
		&main::add_navigation_events( $main::lglobal{wclistbox} );
		$main::lglobal{wfpop}->bind(
			'<Control-s>' => sub {
				my ($name);
				$name =
				  $textwindow->getSaveFile(
										-title => 'Save Word Frequency List As',
										-initialdir  => $main::globallastpath,
										-initialfile => 'wordfreq.txt'
				  );
				if ( defined($name) and length($name) ) {
					open( my $save, ">", "$name" );
					print $save join "\n",
					  $main::lglobal{wclistbox}->get( '0', 'end' );
				}
			}
		);
		$main::lglobal{wfpop}->bind(
			'<Control-x>' => sub {
				my ($name);
				$name =
				  $textwindow->getSaveFile(
									  -title => 'Export Word Frequency List As',
									  -initialdir  => $main::globallastpath,
									  -initialfile => 'wordlist.txt'
				  );
				if ( defined($name) and length($name) ) {
					my $count = $main::lglobal{wclistbox}->index('end');
					open( my $save, ">", "$name" );
					for ( 1 .. $count ) {
						my $word = $main::lglobal{wclistbox}->get($_);
						if ( ( defined $word ) && ( length $word ) ) {
							$word =~ s/^\d+\s+//;
							$word =~ s/\s+\*{4}\s*$//;
							print $save $word, "\n";
						}
					}
				}
			}
		);
	}
	$top->Busy( -recurse => 1 );
	$main::lglobal{wclistbox}->focus;
	$main::lglobal{wclistbox}->insert( 'end', 'Please wait, building word list....' );
	$wc = wordfrequencybuildwordlist($textwindow);

	#print "$index  ";
	$main::lglobal{saveheader} = "$wc total words. " .
	  keys( %{ $main::lglobal{seenwords} } ) . " distinct words in file.";
	$main::lglobal{wclistbox}->delete( '0', 'end' );
	$main::lglobal{last_sort} = $main::lglobal{ignore_case};

	#print $main::lglobal{ignore_case}.":ignore\n";
	if ( $main::lglobal{ignore_case} ) {
		&main::searchoptset("x 1 x x");
	} else {
		&main::searchoptset("x 0 x x");
	}
	$top->Unbusy( -recurse => 1 );
	&main::sortwords( \%{ $main::lglobal{seenwords} } );
	&main::update_indicators();
}

sub bangmark {
	my $top=shift;
	$top->Busy( -recurse => 1 );
	$main::lglobal{wclistbox}->delete( '0', 'end' );
	my %display = ();
	my $wordw   = 0;
	my $ssindex = '1.0';
	my $length  = 0;
	return if ( &main::nofileloaded() );
	$main::lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
	$main::lglobal{wclistbox}->update;
	my $wholefile = &main::slurpfile();

	while (
		   $wholefile =~ m/(\p{Alnum}+\.['"]?\n*\s*['"]?\p{Lower}\p{Alnum}*)/g )
	{
		my $word = $1;
		$wordw++;
		if ( $wordw == 0 ) {

			# FIXME: think this code DOESN'T WORK. skipping
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
		}
		$word =~ s/\n/\\n/g;
		$main::display{$word}++;
	}
	$main::lglobal{saveheader} =
	  "$wordw words with lower case after period. " . '(\n means newline)';
	&main::sortwords( \%main::display );
	$top->Unbusy;
	&main::searchoptset(qw/0 x x 1/);
}



1;


