package Guiguts::SearchReplaceMenu;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&add_search_history &searchtext &search_history &reg_check &getnextscanno &updatesearchlabels
	&isvalid &swapterms &findascanno &reghint &replaceeval &replace &opstop &replaceall &killstoppop)
}

sub add_search_history {
	if ($::scannosearch) {
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
	&main::viewpagenums() if ( $::lglobal{seepagenums} );

	#print $::sopt[0],$::sopt[1],$::sopt[2],$::sopt[3],$::sopt[4].":sopt\n";

# $::sopt[0] --> 0 = pattern search                       1 = whole word search
# $::sopt[1] --> 0 = case sensitive                     1 = case insensitive search
# $::sopt[2] --> 0 = search forwards    \                  1 = search backwards
# $::sopt[3] --> 0 = normal search term           1 = regex search term - 3 and 0 are mutually exclusive
# $::sopt[4] --> 0 = search from last index       1 = Start from beginning

#	$::searchstartindex--where the last search for this $searchterm ended
#   replaced with the insertion point if the user has clicked someplace else

	#print $::sopt[4]."from beginning\n";
	$searchterm = '' unless defined $searchterm;
	if ( length($searchterm) ) {    #and not ($searchterm =~ /\W/)
		&::add_search_history( $searchterm, \@main::search_history, $main::history_size );
	}
	$::lglobal{lastsearchterm} = 'stupid variable needs to be initialized'
	  unless length( $::lglobal{lastsearchterm} );
	$textwindow->tagRemove( 'highlight', '1.0', 'end' ) if $main::searchstartindex;
	my ( $start, $end );
	my $foundone    = 1;
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	$main::searchstartindex = $textwindow->index('insert') unless $main::searchstartindex;
	my $searchstartingpoint = $textwindow->index('insert');
	# this is a search within a selection
	if ( $range_total == 0 && $::lglobal{selectionsearch} ) {
		$start = $textwindow->index('insert');
		$end   = $::lglobal{selectionsearch};
		# this is a search through the end of the document
	} elsif ( $range_total == 0 && !$::lglobal{selectionsearch} ) {
		$start = $textwindow->index('insert');
		$end   = 'end';
		$end   = '1.0' if ( $main::sopt[2] );
	} else {
		$end                      = pop(@ranges);
		$start                    = pop(@ranges);
		$::lglobal{selectionsearch} = $end;
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
		$::lglobal{searchop4}->deselect if ( defined $::lglobal{searchpop} );
		$::lglobal{lastsearchterm} = "resetresetreset";
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
			$searchterm = $::lglobal{searchentry}->get( '1.0', '1.end' );
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
	unless ( $searchterm eq $::lglobal{lastsearchterm} ) {
		if ( $main::sopt[2] ) {
			( $range_total == 0 )
			  ? ( $main::searchstartindex = 'end' )
			  : ( $main::searchstartindex = $end );
		}
		$::lglobal{lastsearchterm} = $searchterm
		  unless ( ( $searchterm =~ m/\\n/ ) && ( $main::sopt[3] ) );
		&main::clearmarks() if ( ( $searchterm =~ m/\\n/ ) && ( $main::sopt[3] ) );
	}
	$textwindow->tagRemove( 'sel', '1.0', 'end' );
	my $length = '0';
	my ($tempindex);

	# Search across line boundaries with regexp "this\nand"
	if ( ( $searchterm =~ m/\\n/ ) && ( $main::sopt[3] ) ) {
		unless ( $searchterm eq $::lglobal{lastsearchterm} ) {
			{
				$top->Busy;

				# have to search on the whole file
				my $wholefile = $textwindow->get( '1.0', $end );

				# search is case sensitive if $::sopt[1] is set
				if ( $main::sopt[1] ) {
					while ( $wholefile =~ m/$searchterm/smgi ) {
						push @{ $::lglobal{nlmatches} },
						  [ $-[0], ( $+[0] - $-[0] ) ];
					}
				} else {
					while ( $wholefile =~ m/$searchterm/smg ) {
						push @{ $::lglobal{nlmatches} },
						  [ $-[0], ( $+[0] - $-[0] ) ];
					}
				}
				$top->Unbusy;
			}
			my $matchidx = 0;
			my $lineidx  = 1;
			my $matchacc = 0;
			foreach my $match ( @{ $::lglobal{nlmatches} } ) {
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
			$::lglobal{lastsearchterm} = $searchterm;
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
		$::lglobal{lastsearchterm} = 'reset' unless $mark;
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
		unless ( $::lglobal{selectionsearch} ) { $start = '1.0'; $end = 'end' }
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
		$::lglobal{selectionsearch} = 0;
		unless ( $::lglobal{regaa} ) {
			$textwindow->bell unless $main::nobell;
			$::lglobal{searchbutton}->flash if defined $::lglobal{searchpop};
			$::lglobal{searchbutton}->flash if defined $::lglobal{searchpop};

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
	$::lglobal{searchentry}->tagConfigure( 'reg', -foreground => 'black' );
	$::lglobal{searchentry}->tagRemove( 'reg', '1.0', 'end' );
	return unless $main::sopt[3];
	$::lglobal{searchentry}->tagAdd( 'reg', '1.0', 'end' );
	my $term = $::lglobal{searchentry}->get( '1.0', 'end' );
	return if ( $term eq '^' or $term eq '$' );
	return if &main::isvalid($term);
	$::lglobal{searchentry}->tagConfigure( 'reg', -foreground => 'red' );
	return;
}

sub regedit {
	my $top = $main::top;
	my $editor = $top->DialogBox( -title   => 'Regex editor',
								  -buttons => [ 'Save', 'Cancel' ] );
	my $regsearchlabel = $editor->add( 'Label', -text => 'Search Term' )->pack;
	$::lglobal{regsearch} = $editor->add(
										'Text',
										-background => $::bkgcolor,
										-width      => 40,
										-height     => 1,
	)->pack;
	my $regreplacelabel =
	  $editor->add( 'Label', -text => 'Replacement Term' )->pack;
	$::lglobal{regreplace} = $editor->add(
										 'Text',
										 -background => $::bkgcolor,
										 -width      => 40,
										 -height     => 1,
	)->pack;
	my $reghintlabel = $editor->add( 'Label', -text => 'Hint Text' )->pack;
	$::lglobal{reghinted} = $editor->add(
										'Text',
										-background => $::bkgcolor,
										-width      => 40,
										-height     => 8,
										-wrap       => 'word',
	)->pack;
	my $buttonframe = $editor->add('Frame')->pack;
	$buttonframe->Button(
		-activebackground => $::activecolor,
		-text             => '<--',
		-command          => sub {
			$::lglobal{scannosindex}-- if $::lglobal{scannosindex};
			regload();
		},
	)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
	$buttonframe->Button(
		-activebackground => $::activecolor,
		-text             => '-->',
		-command          => sub {
			$::lglobal{scannosindex}++
			  if $::lglobal{scannosarray}[ $::lglobal{scannosindex} ];
			regload();
		},
	)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
	$buttonframe->Button(
						  -activebackground => $::activecolor,
						  -text             => 'Add',
						  -command          => \&regadd,
	)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
	$buttonframe->Button(
						  -activebackground => $::activecolor,
						  -text             => 'Del',
						  -command          => \&regdel,
	)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
	$::lglobal{regsearch}->insert(
								 'end',
								 (
									$::lglobal{searchentry}->get( '1.0', '1.end' )
								 )
	) if $::lglobal{searchentry}->get( '1.0', '1.end' );
	$::lglobal{regreplace}->insert(
								  'end',
								  (
									 $::lglobal{replaceentry}
									   ->get( '1.0', '1.end' )
								  )
	) if $::lglobal{replaceentry}->get( '1.0', '1.end' );
	$::lglobal{reghinted}->insert(
								 'end',
								 (
									$::reghints{
										$::lglobal{searchentry}
										  ->get( '1.0', '1.end' )
									  }
								 )
	) if $::reghints{ $::lglobal{searchentry}->get( '1.0', '1.end' ) };
	my $button = $editor->Show;
	if ( $button =~ /save/i ) {
		open my $reg, ">", "$::lglobal{scannosfilename}";
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
		print $reg '%main::reghints = (' . "\n";

		foreach my $word ( sort ( keys %main::reghints ) ) {
			my $srch = $word;
			$srch =~ s/'/\\'/;
			my $repl = $::reghints{$word};
			$repl =~ s/([\\'])/\\$1/;
			print $reg "'$srch' => '$repl'\n";
		}
		print $reg ");\n\n";
		close $reg;
	}
}

sub regload {
	my $word = '';
	$word = $::lglobal{scannosarray}[ $::lglobal{scannosindex} ];
	$::lglobal{regsearch}->delete( '1.0', 'end' );
	$::lglobal{regreplace}->delete( '1.0', 'end' );
	$::lglobal{reghinted}->delete( '1.0', 'end' );
	$::lglobal{regsearch}->insert( 'end', $word ) if defined $word;
	$::lglobal{regreplace}->insert( 'end', $main::scannoslist{$word} )
	  if defined $word;
	$::lglobal{reghinted}->insert( 'end', $::reghints{$word} ) if defined $word;
}

sub regadd {
	my $st = $::lglobal{regsearch}->get( '1.0', '1.end' );
	unless ( isvalid($st) ) {
		badreg();
		return;
	}
	my $rt = $::lglobal{regsearch}->get( '1.0', '1.end' );
	my $rh = $::lglobal{reghinted}->get( '1.0', 'end' );
	$rh =~ s/(?!<\\)'/\\'/;
	$rh =~ s/\n/ /;
	$rh =~ s/  / /;
	$rh =~ s/\s+$//;
	$::reghints{$st} = $rh;

	unless ( defined $main::scannoslist{$st} ) {
		$main::scannoslist{$st} = $rt;
		$::lglobal{scannosindex} = 0;
		@{ $::lglobal{scannosarray} } = ();
		foreach ( sort ( keys %main::scannoslist ) ) {
			push @{ $::lglobal{scannosarray} }, $_;
		}
		foreach ( @{ $::lglobal{scannosarray} } ) {
			$::lglobal{scannosindex}++ unless ( $_ eq $st );
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
	my $st = $::lglobal{regsearch}->get( '1.0', '1.end' );
	delete $::reghints{$st};
	delete $main::scannoslist{$st};
	$::lglobal{scannosindex}--;
	@{ $::lglobal{scannosarray} } = ();
	foreach my $word ( sort ( keys %main::scannoslist ) ) {
		push @{ $::lglobal{scannosarray} }, $word;
	}
	regload();
}

sub reghint {
	my $message = 'No hints for this entry.';
	my $reg = $::lglobal{searchentry}->get( '1.0', '1.end' );
	if ( $::reghints{$reg} ) { $message = $::reghints{$reg} }
	if ( defined( $::lglobal{hintpop} ) ) {
		$::lglobal{hintpop}->deiconify;
		$::lglobal{hintpop}->raise;
		$::lglobal{hintpop}->focus;
		$::lglobal{hintmessage}->delete( '1.0', 'end' );
		$::lglobal{hintmessage}->insert( 'end', $message );
	} else {
		$::lglobal{hintpop} = $::lglobal{searchpop}->Toplevel;
		::initialize_popup_with_deletebinding('hintpop');
		$::lglobal{hintpop}->title('Search Term Hint');
		my $frame =
		  $::lglobal{hintpop}->Frame->pack(
										  -anchor => 'nw',
										  -expand => 'yes',
										  -fill   => 'both'
		  );
		$::lglobal{hintmessage} =
		  $frame->ROText(
						  -width      => 40,
						  -height     => 6,
						  -background => $::bkgcolor,
						  -wrap       => 'word',
		  )->pack(
				   -anchor => 'nw',
				   -expand => 'yes',
				   -fill   => 'both',
				   -padx   => 4,
				   -pady   => 4
		  );
		$::lglobal{hintmessage}->insert( 'end', $message );
	}
}

sub getnextscanno {
	$::scannosearch = 1;

	::findascanno();
	unless ( searchtext($::textwindow,$::top) ) {
		if ( $::lglobal{regaa} ) {
			while (1) {
				last
				  if (
					 $::lglobal{scannosindex}++ >= $#{ $::lglobal{scannosarray} } );
				::findascanno();
				last if searchtext($::textwindow,$::top);
			}
		}
	}
}

sub swapterms {
	my $tempholder = $::lglobal{replaceentry}->get( '1.0', '1.end' );
	$::lglobal{replaceentry}->delete( '1.0', 'end' );
	$::lglobal{replaceentry}
	  ->insert( 'end', $::lglobal{searchentry}->get( '1.0', '1.end' ) );
	$::lglobal{searchentry}->delete( '1.0', 'end' );
	$::lglobal{searchentry}->insert( 'end', $tempholder );
	searchtext($::textwindow,$::top);
}

sub isvalid {
	my $term = shift;
	return eval { '' =~ m/$term/; 1 } || 0;
}

sub badreg {
	my $warning = $::top->Dialog(
		-text =>
"Invalid Regex search term.\nDo you have mismatched\nbrackets or parenthesis?",
		-title   => 'Invalid Regex',
		-bitmap  => 'warning',
		-buttons => ['Ok'],
	);
	$warning->Icon( -image => $::icon );
	$warning->Show;
}

sub clearmarks {
	@{ $::lglobal{nlmatches} } = ();
	my ( $mark, $mindex );
	$mark = $::textwindow->markNext($::searchendindex);
	while ($mark) {
		if ( $mark =~ /nls\d+q(\d+)/ ) {
			$mindex = $::textwindow->index($mark);
			$::textwindow->markUnset($mark);
			$mark = $mindex;
		}
		$mark = $::textwindow->markNext($mark) if $mark;
	}
}

sub getmark {
	my $start = shift;
	if ( $::sopt[2] ) {    # search reverse
		return $::textwindow->markPrevious($start);
	} else {             # search forward
		return $::textwindow->markNext($start);
	}
}

sub updatesearchlabels {
	if ( $::lglobal{seenwords} && $::lglobal{searchpop} ) {
		my $replaceterm = $::lglobal{replaceentry}->get( '1.0', '1.end' );
		my $searchterm1 = $::lglobal{searchentry}->get( '1.0', '1.end' );
		if ( ( $::lglobal{seenwords}->{$searchterm1} ) && ( $::sopt[0] ) ) {
			$::lglobal{searchnumlabel}->configure(
				  -text => "Found $::lglobal{seenwords}->{$searchterm1} times." );
		} elsif ( ( $searchterm1 eq '' ) || ( !$::sopt[0] ) ) {
			$::lglobal{searchnumlabel}->configure( -text => '' );
		} else {
			$::lglobal{searchnumlabel}->configure( -text => 'Not Found.' );
		}
	}
}

# calls the replacewith command after calling replaceeval
# to allow arbitrary perl code to be included in the replace entry
sub replace {
	viewpagenums() if ( $::lglobal{seepagenums} );
	my $replaceterm = shift;
	$replaceterm = '' unless length $replaceterm;
	return unless $::searchstartindex;
	my $searchterm = $::lglobal{searchentry}->get( '1.0', '1.end' );
	$replaceterm = replaceeval( $searchterm, $replaceterm ) if ( $::sopt[3] );
	if ($::searchstartindex) {
		$::textwindow->replacewith( $::searchstartindex, $::searchendindex,
								  $replaceterm );
	}
	return 1;
}

sub findascanno {
	my $textwindow = $::textwindow;
	$::searchendindex = '1.0';
	my $word = '';
	$word = $::lglobal{scannosarray}[ $::lglobal{scannosindex} ];
	$::lglobal{searchentry}->delete( '1.0', 'end' );
	$::lglobal{replaceentry}->delete( '1.0', 'end' );
	$textwindow->bell unless ( $word || $::nobell || $::lglobal{regaa} );
	$::lglobal{searchbutton}->flash unless ( $word || $::lglobal{regaa} );
	$::lglobal{regtracker}
	  ->configure( -text => ( $::lglobal{scannosindex} + 1 ) . '/'
				   . scalar( @{ $::lglobal{scannosarray} } ) );
	$::lglobal{hintmessage}->delete( '1.0', 'end' )
	  if ( defined( $::lglobal{hintpop} ) );
	return 0 unless $word;
	$::lglobal{searchentry}->insert( 'end', $word );
	$::lglobal{replaceentry}->insert( 'end', ( $::scannoslist{$word} ) );
	$::sopt[2]
	  ? $textwindow->markSet( 'insert', 'end' )
	  : $textwindow->markSet( 'insert', '1.0' );
	reghint() if ( defined( $::lglobal{hintpop} ) );
	$textwindow->update;
	return 1;
}

# allow the replacment term to contain arbitrary perl code
# called only from replace()
sub replaceeval {
	my $textwindow = $::textwindow;
	my $top = $::top;
	my ( $searchterm, $replaceterm ) = @_;
	my @replarray = ();
	my ( $replaceseg, $seg1, $seg2, $replbuild );
	my ( $m1, $m2, $m3, $m4, $m5, $m6, $m7, $m8 );
	my (
		 $cfound,  $lfound,  $ufound, $tfound,
		 $gafound, $gbfound, $gfound, $afound
	);

	#check for control codes before the $1 codes for text found are inserted
	if ( $replaceterm =~ /\\C/ )  { $cfound  = 1; }
	if ( $replaceterm =~ /\\L/ )  { $lfound  = 1; }
	if ( $replaceterm =~ /\\U/ )  { $ufound  = 1; }
	if ( $replaceterm =~ /\\T/ )  { $tfound  = 1; }
	if ( $replaceterm =~ /\\GA/ ) { $gafound = 1; }
	if ( $replaceterm =~ /\\GB/ ) { $gbfound = 1; }
	if ( $replaceterm =~ /\\G/ )  { $gfound  = 1; }
	if ( $replaceterm =~ /\\A/ )  { $afound  = 1; }

	my $found = $textwindow->get( $::searchstartindex, $::searchendindex );
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

# For an explanation see
# http://www.pgdp.net/wiki/PPTools/Guiguts/Searching#Replacing_by_Modifying_Quoted_Text
# \C indicates perl code to be run
	if ($cfound) {
		if ( $::lglobal{codewarn} ) {
			my $message = <<'END';
WARNING!! The replacement term will execute arbitrary perl code.
If you do not want to, or are not sure of what you are doing, cancel the operation.
It is unlikely that there is a problem. However, it is possible (and not terribly difficult)
to construct an expression that would delete files, execute arbitrary malicious code,
reformat hard drives, etc.
Do you want to proceed?
END

			my $dialog = $top->Dialog(
								 -text    => $message,
								 -bitmap  => 'warning',
								 -title   => 'WARNING! Code in term.',
								 -buttons => [ 'OK', 'Warnings Off', 'Cancel' ],
			);
			my $answer = $dialog->Show;
			$::lglobal{codewarn} = 0 if ( $answer eq 'Warnings Off' );
			return $replaceterm
			  unless (    ( $answer eq 'OK' )
					   || ( $answer eq 'Warnings Off' ) );
		}
		$replbuild = '';
		if ( $replaceterm =~ s/^\\C// ) {
			if ( $replaceterm =~ s/\\C// ) {
				@replarray = split /\\C/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
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

	# \Ltest\L is converted to lower case
	if ($lfound) {
		if ( $replaceterm =~ s/^\\L// ) {
			if ( $replaceterm =~ s/\\L// ) {
				@replarray = split /\\L/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
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

	# \Utest\U is converted to lower case
	if ($ufound) {
		if ( $replaceterm =~ s/^\\U// ) {
			if ( $replaceterm =~ s/\\U// ) {
				@replarray = split /\\U/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
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

	# \Ttest\T is converted to title case
	if ($tfound) {
		if ( $replaceterm =~ s/^\\T// ) {
			if ( $replaceterm =~ s/\\T// ) {
				@replarray = split /\\T/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
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

	# \GA runs betaascii
	if ($gafound) {
		if ( $replaceterm =~ s/^\\GA// ) {
			if ( $replaceterm =~ s/\\GA// ) {
				@replarray = split /\\GA/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
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

	# \GB runs betagreek
	if ($gbfound) {
		if ( $replaceterm =~ s/^\\GB// ) {
			if ( $replaceterm =~ s/\\GB// ) {
				@replarray = split /\\GB/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
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

	# \G runs betagreek unicode
	if ($gfound) {
		if ( $replaceterm =~ s/^\\G// ) {
			if ( $replaceterm =~ s/\\G// ) {
				@replarray = split /\\G/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
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

	# \A converts to anchor
	if ($afound) {
		if ( $replaceterm =~ s/^\\A// ) {
			if ( $replaceterm =~ s/\\A// ) {
				@replarray = split /\\A/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
			@replarray = split /\\A/, $replaceterm;
			$replbuild = shift @replarray;
		}
		while ( $replaceseg = shift @replarray ) {
			$seg1 = $seg2 = '';
			( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
			my $linkname;
			$linkname = makeanchor( deaccent($seg1) );
			$seg1     = "<a id=\"$linkname\"></a>";
			$replbuild .= $seg1;
			$replbuild .= $seg2 if $seg2;
		}
		$replaceterm = $replbuild;
	}
	return $replaceterm;
}

sub opstop {
	if ( defined( $::lglobal{stoppop} ) ) {
		$::lglobal{stoppop}->deiconify;
		$::lglobal{stoppop}->raise;
		$::lglobal{stoppop}->focus;
	} else {
		$::lglobal{stoppop} = $::top->Toplevel;
		$::lglobal{stoppop}->title('Interrupt');
		::initialize_popup_with_deletebinding('stoppop');

		my $frame = $::lglobal{stoppop}->Frame->pack;
		my $stopbutton = $frame->Button(
									-activebackground => $::activecolor,
									-command => sub { $::operationinterrupt = 1 },
									-text    => 'Interrupt Operation',
									-width   => 16
		)->grid( -row => 1, -column => 1, -padx => 10, -pady => 10 );
	}
}

sub killstoppop {
	if ( $::lglobal{stoppop} ) {
		$::lglobal{stoppop}->destroy;
		undef $::lglobal{stoppop};
	}
	;    #destroy interrupt popup
}

sub replaceall {
	my $replacement = shift;
	$replacement = '' unless $replacement;
	my $textwindow =$::textwindow;
	my $top =$::top;

	# Check if replaceall applies only to a selection
	my @ranges = $textwindow->tagRanges('sel');
	if (@ranges) {
		$::lglobal{lastsearchterm} =
		  $::lglobal{replaceentry}->get( '1.0', '1.end' );
		$::searchstartindex = pop @ranges;
		$::searchendindex   = pop @ranges;
	} else {
		my $searchterm = $::lglobal{searchentry}->get( '1.0', '1.end' );
		$::lglobal{lastsearchterm} = '';

		# if not a search across line boundary
		# and not a search within a selection do a speedy FindAndReplaceAll
		unless ( ( $::sopt[3] ) or ( $replacement =~ $searchterm ) )
		{    #( $searchterm =~ m/\\n/ ) &&
			my $exactsearch = $searchterm;

			# escape metacharacters for whole word matching
			$exactsearch = escape_regexmetacharacters($exactsearch)
			  ;    # this is a whole word search
			$searchterm = '(?<!\p{Alnum})' . $exactsearch . '(?!\p{Alnum})'
			  if $::sopt[0];
			my ( $searchstart, $mode );
			if   ( $::sopt[0] or $::sopt[3] ) { $mode = '-regexp' }
			else                          { $mode = '-exact' }
			working("Replace All");
			if ( $::sopt[1] ) {
				$textwindow->FindAndReplaceAll( $mode, '-nocase', $searchterm,
												$replacement );
			} else {
				$textwindow->FindAndReplaceAll( $mode, '-case', $searchterm,
												$replacement );
			}
			working();
			return;
		}
	}

	#print "repl:$replacement:ranges:@ranges:\n";
	$textwindow->focus;
	opstop();
	while ( searchtext($textwindow,$top) )
	{    # keep calling search() and replace() until you return undef
		last unless replace($replacement);
		last if $::operationinterrupt;
		$textwindow->update;
	}
	$::operationinterrupt = 0;
	$::lglobal{stoppop}->destroy;
	undef $::lglobal{stoppop};
}



1;