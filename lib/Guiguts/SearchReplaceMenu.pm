package Guiguts::SearchReplaceMenu;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&add_search_history &searchtext &search_history &reg_check &regedit 
	&getnextscanno)
}

sub add_search_history {
	if ($main::scannosearch) {
		return; # do not add to search history during a scannos check		
	} 
	my ( $term, $history_array_ref,$history_size ) = @_;
	my @temparray = @$history_array_ref;
	@$history_array_ref = ();
	push @$history_array_ref, $term;
	for (@temparray) {
		next if $_ eq $term;
		push @$history_array_ref, $_;
		last if @$history_array_ref >= $history_size;
	}
}

sub searchtext {
	my ($textwindow,$top,$searchterm)=@_;
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );

	#print $sopt[0],$sopt[1],$sopt[2],$sopt[3],$sopt[4].":sopt\n";

# $sopt[0] --> 0 = pattern search                       1 = whole word search
# $sopt[1] --> 0 = case sensitive                     1 = case insensitive search
# $sopt[2] --> 0 = search forwards    \                  1 = search backwards
# $sopt[3] --> 0 = normal search term           1 = regex search term - 3 and 0 are mutually exclusive
# $sopt[4] --> 0 = search from last index       1 = Start from beginning

#	$searchstartindex--where the last search for this $searchterm ended
#   replaced with the insertion point if the user has clicked someplace else

	#print $sopt[4]."from beginning\n";
	$searchterm = '' unless defined $searchterm;
	if ( length($searchterm) ) {    #and not ($searchterm =~ /\W/)
		&main::add_search_history( $searchterm, \@main::search_history, $main::history_size );
	}
	$main::lglobal{lastsearchterm} = 'stupid variable needs to be initialized'
	  unless length( $main::lglobal{lastsearchterm} );
	$textwindow->tagRemove( 'highlight', '1.0', 'end' ) if $main::searchstartindex;
	my ( $start, $end );
	my $foundone    = 1;
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	$main::searchstartindex = $textwindow->index('insert') unless $main::searchstartindex;
	my $searchstartingpoint = $textwindow->index('insert');
	# this is a search within a selection
	if ( $range_total == 0 && $main::lglobal{selectionsearch} ) {
		$start = $textwindow->index('insert');
		$end   = $main::lglobal{selectionsearch};
		# this is a search through the end of the document
	} elsif ( $range_total == 0 && !$main::lglobal{selectionsearch} ) {
		$start = $textwindow->index('insert');
		$end   = 'end';
		$end   = '1.0' if ( $main::sopt[2] );
	} else {
		$end                      = pop(@ranges);
		$start                    = pop(@ranges);
		$main::lglobal{selectionsearch} = $end;
	}
	if ( $main::sopt[4] ) {
		if ( $main::sopt[2] ) {

			# search backwards and Start From Beginning so start from the end
			$start = 'end';
			$end   = '1.0';
		} else {
			# search forwards and Start From Beginning so start from the end
			$start = '1.0';
			$end   = 'end';
		}
		$main::lglobal{searchop4}->deselect if ( defined $main::lglobal{searchpop} );
		$main::lglobal{lastsearchterm} = "resetresetreset";
	}
	#print "start:$start\n";
	if ($start) {    # but start is always defined?
		if ( $main::sopt[2] ) {    # if backwards
			$main::searchstartindex = $start;
		} else {
			$main::searchendindex = "$start+1c";  #forwards. #unless ( $start eq '1.0' )
		  #print $main::searchstartindex.":".$main::searchendindex."4\n";
			
		}
		# forward search begin +1c or the next search would find the same match
	}
	{   # Turn off warnings temporarily since $searchterm is undefined on first
		# search
		no warnings;
		unless ( length($searchterm) ) {
			$searchterm = $main::lglobal{searchentry}->get( '1.0', '1.end' );
			&main::add_search_history( $searchterm, \@main::search_history, $main::history_size );
		}
	} # warnings back on; keep this bracket
	return ('') unless length($searchterm);
	if ( $main::sopt[3] ) {
		unless ( &main::isvalid($searchterm) ) {
			&main::badreg();
			return;
		}
	}
	# if this is a new searchterm
	unless ( $searchterm eq $main::lglobal{lastsearchterm} ) {
		if ( $main::sopt[2] ) {
			( $range_total == 0 )
			  ? ( $main::searchstartindex = 'end' )
			  : ( $main::searchstartindex = $end );
		}
		$main::lglobal{lastsearchterm} = $searchterm
		  unless ( ( $searchterm =~ m/\\n/ ) && ( $main::sopt[3] ) );
		&main::clearmarks() if ( ( $searchterm =~ m/\\n/ ) && ( $main::sopt[3] ) );
	}
	$textwindow->tagRemove( 'sel', '1.0', 'end' );
	my $length = '0';
	my ($tempindex);

	# Search across line boundaries with regexp "this\nand"
	if ( ( $searchterm =~ m/\\n/ ) && ( $main::sopt[3] ) ) {
		unless ( $searchterm eq $main::lglobal{lastsearchterm} ) {
			{
				$top->Busy;

				# have to search on the whole file
				my $wholefile = $textwindow->get( '1.0', $end );

				# search is case sensitive if $sopt[1] is set
				if ( $main::sopt[1] ) {
					while ( $wholefile =~ m/$searchterm/smgi ) {
						push @{ $main::lglobal{nlmatches} },
						  [ $-[0], ( $+[0] - $-[0] ) ];
					}
				} else {
					while ( $wholefile =~ m/$searchterm/smg ) {
						push @{ $main::lglobal{nlmatches} },
						  [ $-[0], ( $+[0] - $-[0] ) ];
					}
				}
				$top->Unbusy;
			}
			my $matchidx = 0;
			my $lineidx  = 1;
			my $matchacc = 0;
			foreach my $match ( @{ $main::lglobal{nlmatches} } ) {
				while (1) {
					my $linelen =
					  length( $textwindow->get( "$lineidx.0", "$lineidx.end" ) )
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
			$main::lglobal{lastsearchterm} = $searchterm;
		}
		my $mark;
		if ( $main::sopt[2] ) {
			$mark = &main::getmark($main::searchstartindex);
		} else {
			$mark = &main::getmark($main::searchendindex);
		}
		while ($mark) {
			if ( $mark =~ /nls\d+q(\d+)/ ) {
				$length           = $1;
				#print $length."1\n";
				$main::searchstartindex = $textwindow->index($mark);
				last;
			} else {
				$mark = &main::getmark($mark) if $mark;
				next;
			}
		}

		$main::searchstartindex = 0 unless $mark;
		$main::lglobal{lastsearchterm} = 'reset' unless $mark;
	} else {    # not a search across line boundaries
		my $exactsearch = $searchterm;
		$exactsearch = &main::escape_regexmetacharacters($exactsearch);
		$searchterm  = '(?<!\p{Alnum})' . $exactsearch . '(?!\p{Alnum})'
		  if $main::sopt[0];
		my ( $direction, $searchstart, $mode );
		if   ( $main::sopt[2] ) { $searchstart = $main::searchstartindex }
		else              { $searchstart = $main::searchendindex }
		if   ( $main::sopt[2] ) { $direction = '-backwards' }
		else              { $direction = '-forwards' }
		if   ( $main::sopt[0] or $main::sopt[3] ) { $mode = '-regexp' }
		else                          { $mode = '-exact' }

		if ($main::debug) {print "$mode:$direction:$length:$searchterm:$searchstart:$end\n";}
				#print $length."2\n";
		

		#finally we actually do some searching
		if ( $main::sopt[1] ) {
			$main::searchstartindex =
			  $textwindow->search(
								   $mode, $direction, '-nocase',
								   '-count' => \$length,
								   '--', $searchterm, $searchstart, $end
			  );
			  				#print $length."3\n";
			  
		} else {
			$main::searchstartindex =
			  $textwindow->search(
								   $mode, $direction,
								   '-count' => \$length,
								   '--', $searchterm, $searchstart, $end
			  );
			  				#print $length."4\n";
		}
	}
	if ($main::searchstartindex) {
		$tempindex = $main::searchstartindex;
		  #print $main::searchstartindex.":".$main::searchendindex."7\n";
		my ( $row, $col ) = split /\./, $tempindex;
		#print "$row:$col:$length 5\n";
		
		$col += $length;
		$main::searchendindex = "$row.$col" if $length;
		  #print $main::searchstartindex.":".$main::searchendindex."3\n";
		$main::searchendindex = $textwindow->index("$main::searchstartindex +${length}c")
		  if ( $searchterm =~ m/\\n/ );
		  #print $main::searchstartindex.":".$main::searchendindex."2\n";
		$main::searchendindex = $textwindow->index("$main::searchstartindex +1c")
		  unless $length;
		  #print $main::searchstartindex.":".$main::searchendindex."1\n";
		$textwindow->markSet( 'insert', $main::searchstartindex )
		  if $main::searchstartindex;    # position the cursor at the index
		  #print $main::searchstartindex.":".$main::searchendindex."\n";
		$textwindow->tagAdd( 'highlight', $main::searchstartindex, $main::searchendindex )
		  if $main::searchstartindex;    # highlight the text
		$textwindow->yviewMoveto(1);
		$textwindow->see($main::searchstartindex)
		  if ( $main::searchendindex && $main::sopt[2] )
		  ;    # scroll text box, if necessary, to make found text visible
		$textwindow->see($main::searchendindex) if ( $main::searchendindex && !$main::sopt[2] );
		$main::searchendindex = $main::searchstartindex unless $length;
		  #print $main::searchstartindex.":".$main::searchendindex.":10\n";
	}
	unless ($main::searchstartindex) {
		  #print $main::searchstartindex.":".$main::searchendindex.":11\n";
		$foundone = 0;
		unless ( $main::lglobal{selectionsearch} ) { $start = '1.0'; $end = 'end' }
		if ( $main::sopt[2] ) {
			$main::searchstartindex = $end;
		  #print $main::searchstartindex.":".$main::searchendindex.":12\n";
			$textwindow->markSet( 'insert', $main::searchstartindex );
			$textwindow->see($main::searchendindex);
		} else {
			$main::searchendindex = $start;
		   #print $main::searchstartindex.":".$main::searchendindex.":13\n";
			$textwindow->markSet( 'insert', $start );
			$textwindow->see($start);
		}
		$main::lglobal{selectionsearch} = 0;
		unless ( $main::lglobal{regaa} ) {
			$textwindow->bell unless $main::nobell;
			$main::lglobal{searchbutton}->flash if defined $main::lglobal{searchpop};
			$main::lglobal{searchbutton}->flash if defined $main::lglobal{searchpop};

			# If nothing found, return cursor to starting point
			if ($main::failedsearch) {
				$main::searchendindex = $searchstartingpoint;
				$textwindow->markSet( 'insert', $searchstartingpoint );
				$textwindow->see($searchstartingpoint);
			}
		}
	}
	&main::updatesearchlabels();
	&main::update_indicators();
	return $foundone;    # return index of where found text started
}

sub search_history {
	my ( $widget, $history_array_ref ) = @_;
	my $menu = $widget->Menu( -title => 'History', -tearoff => 0 );
	$menu->command( -label   => 'Clear History',
					-command => sub { @$history_array_ref = (); &main::savesettings(); }, );
	$menu->separator;
	for my $item (@$history_array_ref) {
		$menu->command(
				-label   => $item,
				-command => [ sub {load_hist_term( $widget, $_[0] ) }, $item ],
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
	$main::lglobal{searchentry}->tagConfigure( 'reg', -foreground => 'black' );
	$main::lglobal{searchentry}->tagRemove( 'reg', '1.0', 'end' );
	return unless $main::sopt[3];
	$main::lglobal{searchentry}->tagAdd( 'reg', '1.0', 'end' );
	my $term = $main::lglobal{searchentry}->get( '1.0', 'end' );
	return if ( $term eq '^' or $term eq '$' );
	return if &main::isvalid($term);
	$main::lglobal{searchentry}->tagConfigure( 'reg', -foreground => 'red' );
	return;
}

sub regedit {
	my $top = $main::top;
	my $editor = $top->DialogBox( -title   => 'Regex editor',
								  -buttons => [ 'Save', 'Cancel' ] );
	my $regsearchlabel = $editor->add( 'Label', -text => 'Search Term' )->pack;
	$main::lglobal{regsearch} = $editor->add(
										'Text',
										-background => $main::bkgcolor,
										-width      => 40,
										-height     => 1,
	)->pack;
	my $regreplacelabel =
	  $editor->add( 'Label', -text => 'Replacement Term' )->pack;
	$main::lglobal{regreplace} = $editor->add(
										 'Text',
										 -background => $main::bkgcolor,
										 -width      => 40,
										 -height     => 1,
	)->pack;
	my $reghintlabel = $editor->add( 'Label', -text => 'Hint Text' )->pack;
	$main::lglobal{reghinted} = $editor->add(
										'Text',
										-background => $main::bkgcolor,
										-width      => 40,
										-height     => 8,
										-wrap       => 'word',
	)->pack;
	my $buttonframe = $editor->add('Frame')->pack;
	$buttonframe->Button(
		-activebackground => $main::activecolor,
		-text             => '<--',
		-command          => sub {
			$main::lglobal{scannosindex}-- if $main::lglobal{scannosindex};
			regload();
		},
	)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
	$buttonframe->Button(
		-activebackground => $main::activecolor,
		-text             => '-->',
		-command          => sub {
			$main::lglobal{scannosindex}++
			  if $main::lglobal{scannosarray}[ $main::lglobal{scannosindex} ];
			regload();
		},
	)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
	$buttonframe->Button(
						  -activebackground => $main::activecolor,
						  -text             => 'Add',
						  -command          => \&regadd,
	)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
	$buttonframe->Button(
						  -activebackground => $main::activecolor,
						  -text             => 'Del',
						  -command          => \&regdel,
	)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
	$main::lglobal{regsearch}->insert(
								 'end',
								 (
									$main::lglobal{searchentry}->get( '1.0', '1.end' )
								 )
	) if $main::lglobal{searchentry}->get( '1.0', '1.end' );
	$main::lglobal{regreplace}->insert(
								  'end',
								  (
									 $main::lglobal{replaceentry}
									   ->get( '1.0', '1.end' )
								  )
	) if $main::lglobal{replaceentry}->get( '1.0', '1.end' );
	$main::lglobal{reghinted}->insert(
								 'end',
								 (
									$main::reghints{
										$main::lglobal{searchentry}
										  ->get( '1.0', '1.end' )
									  }
								 )
	) if $main::reghints{ $main::lglobal{searchentry}->get( '1.0', '1.end' ) };
	my $button = $editor->Show;
	if ( $button =~ /save/i ) {
		open my $reg, ">", "$main::lglobal{scannosfilename}";
		print $reg "\%main::scannoslist = (\n";
		foreach my $word ( sort ( keys %main::scannoslist ) ) {
			my $srch = $word;
			$srch =~ s/'/\\'/;
			my $repl = $main::scannoslist{$word};
			$repl =~ s/'/\\'/;
			print $reg "'$srch' => '$repl',\n";
		}
		print $reg ");\n\n";
		print $reg <<'EOF';
# For a hint, use the regex expression EXACTLY as it appears in the %main::scannoslist hash
# but replace the replacement term (heh) with the hint text. Note: if a single quote
# appears anywhere in the hint text, you'll need to escape it with a backslash. I.E. isn't
# I could have made this more compact by converting the scannoslist hash into a two dimensional
# hash, but would have sacrificed backward compatibility.

EOF
		print $reg '%reghints = (' . "\n";

		foreach my $word ( sort ( keys %main::reghints ) ) {
			my $srch = $word;
			$srch =~ s/'/\\'/;
			my $repl = $main::reghints{$word};
			$repl =~ s/([\\'])/\\$1/;
			print $reg "'$srch' => '$repl'\n";
		}
		print $reg ");\n\n";
		close $reg;
	}
}

sub regload {
	my $word = '';
	$word = $main::lglobal{scannosarray}[ $main::lglobal{scannosindex} ];
	$main::lglobal{regsearch}->delete( '1.0', 'end' );
	$main::lglobal{regreplace}->delete( '1.0', 'end' );
	$main::lglobal{reghinted}->delete( '1.0', 'end' );
	$main::lglobal{regsearch}->insert( 'end', $word ) if defined $word;
	$main::lglobal{regreplace}->insert( 'end', $main::scannoslist{$word} )
	  if defined $word;
	$main::lglobal{reghinted}->insert( 'end', $main::reghints{$word} ) if defined $word;
}

sub regadd {
	my $st = $main::lglobal{regsearch}->get( '1.0', '1.end' );
	unless ( isvalid($st) ) {
		badreg();
		return;
	}
	my $rt = $main::lglobal{regsearch}->get( '1.0', '1.end' );
	my $rh = $main::lglobal{reghinted}->get( '1.0', 'end' );
	$rh =~ s/(?!<\\)'/\\'/;
	$rh =~ s/\n/ /;
	$rh =~ s/  / /;
	$rh =~ s/\s+$//;
	$main::reghints{$st} = $rh;

	unless ( defined $main::scannoslist{$st} ) {
		$main::scannoslist{$st} = $rt;
		$main::lglobal{scannosindex} = 0;
		@{ $main::lglobal{scannosarray} } = ();
		foreach ( sort ( keys %main::scannoslist ) ) {
			push @{ $main::lglobal{scannosarray} }, $_;
		}
		foreach ( @{ $main::lglobal{scannosarray} } ) {
			$main::lglobal{scannosindex}++ unless ( $_ eq $st );
			next unless ( $_ eq $st );
			last;
		}
	} else {
		$main::scannoslist{$st} = $rt;
	}
	regload();
}

sub regdel {
	my $word = '';
	my $st = $main::lglobal{regsearch}->get( '1.0', '1.end' );
	delete $main::reghints{$st};
	delete $main::scannoslist{$st};
	$main::lglobal{scannosindex}--;
	@{ $main::lglobal{scannosarray} } = ();
	foreach my $word ( sort ( keys %main::scannoslist ) ) {
		push @{ $main::lglobal{scannosarray} }, $word;
	}
	regload();
}

sub reghint {
	my $message = 'No hints for this entry.';
	my $reg = $main::lglobal{searchentry}->get( '1.0', '1.end' );
	if ( $main::reghints{$reg} ) { $message = $main::reghints{$reg} }
	if ( defined( $main::lglobal{hintpop} ) ) {
		$main::lglobal{hintpop}->deiconify;
		$main::lglobal{hintpop}->raise;
		$main::lglobal{hintpop}->focus;
		$main::lglobal{hintmessage}->delete( '1.0', 'end' );
		$main::lglobal{hintmessage}->insert( 'end', $message );
	} else {
		$main::lglobal{hintpop} = $main::lglobal{searchpop}->Toplevel;
		initialize_popup_with_deletebinding('hintpop');
		$main::lglobal{hintpop}->title('Search Term Hint');
		my $frame =
		  $main::lglobal{hintpop}->Frame->pack(
										  -anchor => 'nw',
										  -expand => 'yes',
										  -fill   => 'both'
		  );
		$main::lglobal{hintmessage} =
		  $frame->ROText(
						  -width      => 40,
						  -height     => 6,
						  -background => $main::bkgcolor,
						  -wrap       => 'word',
		  )->pack(
				   -anchor => 'nw',
				   -expand => 'yes',
				   -fill   => 'both',
				   -padx   => 4,
				   -pady   => 4
		  );
		$main::lglobal{hintmessage}->insert( 'end', $message );
	}
}

sub getnextscanno {
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	$main::scannosearch = 1;

	findascanno();
	unless ( &main::searchtext($textwindow,$top) ) {
		if ( $main::lglobal{regaa} ) {
			while (1) {
				last
				  if (
					 $main::lglobal{scannosindex}++ >= $#{ $main::lglobal{scannosarray} } );
				findascanno();
				last if &main::searchtext($textwindow,$top);
			}
		}
	}
}

sub findascanno {
	my $textwindow = $main::textwindow;
	$main::searchendindex = '1.0';
	my $word = '';
	$word = $main::lglobal{scannosarray}[ $main::lglobal{scannosindex} ];
	$main::lglobal{searchentry}->delete( '1.0', 'end' );
	$main::lglobal{replaceentry}->delete( '1.0', 'end' );
	$textwindow->bell unless ( $word || $main::nobell || $main::lglobal{regaa} );
	$main::lglobal{searchbutton}->flash unless ( $word || $main::lglobal{regaa} );
	$main::lglobal{regtracker}
	  ->configure( -text => ( $main::lglobal{scannosindex} + 1 ) . '/'
				   . scalar( @{ $main::lglobal{scannosarray} } ) );
	$main::lglobal{hintmessage}->delete( '1.0', 'end' )
	  if ( defined( $main::lglobal{hintpop} ) );
	return 0 unless $word;
	$main::lglobal{searchentry}->insert( 'end', $word );
	$main::lglobal{replaceentry}->insert( 'end', ( $main::scannoslist{$word} ) );
	$main::sopt[2]
	  ? $textwindow->markSet( 'insert', 'end' )
	  : $textwindow->markSet( 'insert', '1.0' );
	&main::reghint() if ( defined( $main::lglobal{hintpop} ) );
	$textwindow->update;
	return 1;
}


1;