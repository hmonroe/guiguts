package Guiguts::WordFrequency;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&wordfrequencybuildwordlist &wordfrequency)
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
	my $textwindow = shift;
	push @main::operations, ( localtime() . ' - Word Frequency' );
	&main::viewpagenums() if ( $lglobal{seepagenums} );
	&main::oppopupdate()  if $lglobal{oppop};
	#$lglobal{seenwords} = ();
	#%{ $lglobal{seenwordsdoublehyphen} } = ();
	my ( @words, $match, @savesets );
	my $index = '1.0';
	my $wc    = 0;
	my $end   = $textwindow->index('end');
	&main::searchoptset(qw/1 0 x 0/);    # Default is whole word search

	if ( $lglobal{wfpop} ) {
		$lglobal{wfpop}->deiconify;
		$lglobal{wfpop}->raise;
		$lglobal{wclistbox}->delete( '0', 'end' );
	} else {
		$lglobal{wfpop} = $top->Toplevel;
		$lglobal{wfpop}
		  ->title('Word frequency - Ctrl+s to save, Ctrl+x to export');
		&main::initialize_popup_without_deletebinding('wfpop');
		my $wordfreqseframe =
		  $lglobal{wfpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my $wcopt3 =
		  $wordfreqseframe->Checkbutton(
										 -variable => \$lglobal{suspects_only},
										 -selectcolor => $lglobal{checkcolor},
										 -text        => 'Suspects only'
		  )->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		my $wcopt1 =
		  $wordfreqseframe->Checkbutton(
										 -variable    => \$lglobal{ignore_case},
										 -selectcolor => $lglobal{checkcolor},
										 -text        => 'No case',
		  )->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		$wordfreqseframe->Radiobutton(
									   -variable    => \$alpha_sort,
									   -selectcolor => $lglobal{checkcolor},
									   -value       => 'a',
									   -text        => 'Alph',
		)->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		$wordfreqseframe->Radiobutton(
									   -variable    => \$alpha_sort,
									   -selectcolor => $lglobal{checkcolor},
									   -value       => 'f',
									   -text        => 'Frq',
		)->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		$wordfreqseframe->Radiobutton(
									   -variable    => \$alpha_sort,
									   -selectcolor => $lglobal{checkcolor},
									   -value       => 'l',
									   -text        => 'Len',
		)->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		$wordfreqseframe->Button(
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
		$wordfreqseframe->Button(
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
		$wordfreqseframe->Button(
			-activebackground => $activecolor,
			-command          => sub {

				#return if $lglobal{global_filename} =~ /No File Loaded/;
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
		  $lglobal{wfpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my @wfbuttons = (
			[ 'Emdashes'  => \&main::dashcheck ],
			[ 'Hyphens'   => \&main::hyphencheck ],
			[ 'Alpha/num' => \&main::alphanumcheck ],
			[
			   'All Words' => sub {
				   $lglobal{saveheader} =
					 "$wc total words. " .
					 keys( %{ $lglobal{seenwords} } )
					 . " distinct words in file.";
				   &main::sortwords( $lglobal{seenwords} );
				   searchoptset(qw/1 0 x 0/);    #default is whole word search
				 }
			],
			[ 'Check Spelling', \&main::wordfrequencyspellcheck ],
			[ 'Ital/Bold/SC', \&main::itwords, \&main::ital_adjust ],
			[ 'ALL CAPS',     \&main::capscheck ],
			[ 'MiXeD CasE',   \&main::mixedcasecheck ],
			[
			   'Initial Caps',
			   [
				  \&anythingwfcheck, 'words with initial caps',
				  '^\p{Upper}\P{Upper}+$'
			   ]
			],
			[ 'Character Cnts', \&main::charsortcheck ],
			[ 'Check , Upper',  \&main::commark ],
			[ 'Check . Lower',  \&main::bangmark ],
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
				  \&anythingwfcheck,
				  'words with possible ligatures',
				  '(oe|ae|æ|Æ|\x{0153}|\x{0152})'
			   ]
			],
			[ 'RegExpEntry', [ \&anythingwfcheck, 'dummy entry', 'dummy' ] ],
			[
			   '<--RegExp',
			   [
				  sub {
					  anythingwfcheck( 'words matching regular expression',
									   $regexpentry );
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
				$button->bind( '<3>' => $_->[2] ) if $_->[2];
			} else {
				$lglobal{regexpentry} =
				  $wordfreqseframe1->Entry(
											-background   => $bkgcolor,
											-textvariable => \$regexpentry,
											-width        => 13,
				  )->grid( -row => $row, -column => $col );
			}
		}

		my $wcframe =
		  $lglobal{wfpop}->Frame->pack( -fill => 'both', -expand => 'both', );
		$lglobal{wclistbox} =
		  $wcframe->Scrolled(
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
		drag( $lglobal{wclistbox} );
		$lglobal{wfpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$lglobal{wfpop}->destroy;
				undef $lglobal{wfpop};
				undef $lglobal{wclistbox};
			}
		);
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
												 $lglobal{wclistbox}->pointerx -
												   $lglobal{wclistbox}->rootx
											   )
											   . ','
											   . (
												 $lglobal{wclistbox}->pointery -
												   $lglobal{wclistbox}->rooty
											   )
										 )
				);

				# right click means popup a search box
				my ($sword) =
				  $lglobal{wclistbox}->get( $lglobal{wclistbox}->curselection );
				searchpopup();
				$sword =~ s/\d+\s+(\S)/$1/;
				$sword =~ s/\s+\*\*\*\*$//;
				if ( $sword =~ /\*space\*/ ) {
					$sword = ' ';
					searchoptset(qw/0 x x 1/);
				} elsif ( $sword =~ /\*tab\*/ ) {
					$sword = '\t';
					searchoptset(qw/0 x x 1/);
				} elsif ( $sword =~ /\*newline\*/ ) {
					$sword = '\n';
					searchoptset(qw/0 x x 1/);
				} elsif ( $sword =~ /\*nbsp\*/ ) {
					$sword = '\x{A0}';
					searchoptset(qw/0 x x 1/);
				} elsif ( $sword =~ /\W/ ) {
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
		$lglobal{wclistbox}->bind(    # FIXME: This needs to go in GC code.
			'<<find>>',
			sub {
				my ($sword) =
				  $lglobal{wclistbox}->get( $lglobal{wclistbox}->curselection );
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
					searchoptset(qw/0 0 x 1/);    # Case sensitive
				}

				# not whole word search from character cnts popup
				if (     ( length($sword) == 1 )
					 and ( $lglobal{saveheader} =~ /characters in the file./ ) )
				{
					searchoptset(qw/0 0 x 0/);
				}
				if ( $intelligentWF && $sword =~ /^\\,(\s|\\n)/ ) {

		# during comma-Upper ck, ignore if name followed by period, !, or ?
		# NOTE: sword will be used as a regular expression filter during display
					$sword .= '([^\.\?\!]|$)';
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

				#print $sopt[0],$sopt[1],$sopt[2],$sopt[3],$sopt[4].":sopt\n";
				searchfromstartifnew($sword);
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
		$lglobal{wclistbox}->eventAdd( '<<adddict>>' => '<Control-Button-2>',
									   '<Control-Button-3>' );
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
				$lglobal{saveheader} =
				  scalar( keys %{ $lglobal{spellsort} } )
				  . ' words not recognised by the spellchecker.';
				sortwords( \%{ $lglobal{spellsort} } );
			}
		);
		add_navigation_events( $lglobal{wclistbox} );
		$lglobal{wfpop}->bind(
			'<Control-s>' => sub {
				my ($name);
				$name =
				  $textwindow->getSaveFile(
										-title => 'Save Word Frequency List As',
										-initialdir  => $globallastpath,
										-initialfile => 'wordfreq.txt'
				  );
				if ( defined($name) and length($name) ) {
					open( my $save, ">", "$name" );
					print $save join "\n",
					  $lglobal{wclistbox}->get( '0', 'end' );
				}
			}
		);
		$lglobal{wfpop}->bind(
			'<Control-x>' => sub {
				my ($name);
				$name =
				  $textwindow->getSaveFile(
									  -title => 'Export Word Frequency List As',
									  -initialdir  => $globallastpath,
									  -initialfile => 'wordlist.txt'
				  );
				if ( defined($name) and length($name) ) {
					my $count = $lglobal{wclistbox}->index('end');
					open( my $save, ">", "$name" );
					for ( 1 .. $count ) {
						my $word = $lglobal{wclistbox}->get($_);
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
	$lglobal{wclistbox}->focus;
	$lglobal{wclistbox}->insert( 'end', 'Please wait, building word list....' );
	$wc = wordfrequencybuildwordlist($textwindow);

	#print "$index  ";
	$lglobal{saveheader} = "$wc total words. " .
	  keys( %{ $lglobal{seenwords} } ) . " distinct words in file.";
	$lglobal{wclistbox}->delete( '0', 'end' );
	$lglobal{last_sort} = $lglobal{ignore_case};

	#print $lglobal{ignore_case}.":ignore\n";
	if ( $lglobal{ignore_case} ) {
		searchoptset("x 1 x x");
	} else {
		searchoptset("x 0 x x");
	}
	$top->Unbusy( -recurse => 1 );
	sortwords( \%{ $lglobal{seenwords} } );
	update_indicators();
}



1;


