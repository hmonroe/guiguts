package Guiguts::SelectionMenu;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&case &surround &surroundit &flood &indent &asciibox &aligntext &tonamed &fromnamed &fracconv
	&selectrewrap &wrapper)
}

sub wrapper {
	my @words       = ();
	my $word        = '';
	my $line        = '';
	my $leftmargin  = shift;
	my $firstmargin = shift;
	my $rightmargin = shift;
	my $paragraph   = shift;
	my $rwhyphenspace = shift;
	$leftmargin--  if $leftmargin;
	$firstmargin-- if $firstmargin;
	$rightmargin++;
	$paragraph =~ s/-\n/-/g unless $rwhyphenspace;
	$paragraph =~ s/\n/ /g;
	return ("\n") unless ($paragraph);
	@words     = split /\s+/, $paragraph;
	$paragraph = '';
	$line      = ' ' x $firstmargin;

	while (@words) {
		$word = shift @words;
		next unless defined $word and length $word;
		if ( $word =~ /\/#/ ) {
			$firstmargin = $leftmargin = $main::blocklmargin;
			if ( $word =~ /^\x7f*\/#\x8A(\d+)/ )
			{    #check for block rewrapping with parameter markup
				if ( length $1 ) {
					$leftmargin  = $1;
					$firstmargin = $leftmargin;
				}
			}
			if ( $word =~ /^\x7f*\/#\x8A(\d+)?(\.)(\d+)/ ) {
				if ( length $3 ) { $firstmargin = $3 }
			}
			if ( $word =~ /^\x7f*\/#\x8A(\d+)?(\.)?(\d+)?,(\d+)/ ) {
				if ($4) { $rightmargin = $4 }
			}
			$line =~ s/\s$//;
			if ( $line =~ /\S/ ) {
				$paragraph .= $line . "\n" . $word . "\n";
			} else {
				$paragraph .= $word . "\n";
			}
			$line = ' ' x $firstmargin;
			next;
		}
		if ( $word =~ /#\// ) {
			$paragraph .= $line . "\n" if $line;
			$paragraph .= $word . "\n";
			$leftmargin = $lmargin - 1;
			$line       = '';
			next;
		}
		my $thisline = $line . $word;
		$thisline =~ s/<\/?[^>]+?>//g;    #ignore HTML markup when rewrapping
		if ( length($thisline) < $rightmargin ) {
			$line .= $word . ' ';
		} else {
			if ( $line =~ /\S/ ) {
				$line =~ s/\s$//;
				$paragraph .= $line . "\n";
				$line = ' ' x $leftmargin;
				$line .= $word . ' ';
			} else {
				$paragraph .= $line . $word . "\n";
				$line = ' ' x $leftmargin;
			}
		}
		unless ( scalar(@words) ) {
			$line =~ s/\s$//;
			$paragraph .= "$line\n";
			last;
		}
	}
	if ( $paragraph =~ /-[#\*]\// )
	{    # Trap bug when there is a hyphen at the end of a block
		$paragraph =~ s/\n(\S+)-([#\*]\/)/ $1-\n$2/;
	}
	return ($paragraph);
}

sub selectrewrap {
	my ($textwindow, $seepagenums,$scanno_hl ) = @_;
	
	&main::viewpagenums() if ( $seepagenums );
	&main::saveset();
	my $marker      = shift @_;
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	my $thisblockstart;
	my $start;
	my $scannosave = $scanno_hl;
	$scanno_hl = 0;
	$main::operationinterrupt = 0;

	if ( $range_total == 0 ) {
		return;
	} else {
		my $end = pop(@ranges);    #get the end index of the selection
		$start = pop(@ranges);     #get the start index of the selection
		my @marklist = $textwindow->dump( -mark, $start, $end )
		  ;                        #see if there any page markers set
		my ( $markname, @savelist, $markindex, %markhash );
		while (@marklist) {        #save the pagemarkers if they have been set
			shift @marklist;
			$markname  = shift @marklist;
			$markindex = shift @marklist;
			if ( $markname =~ /Pg\S+/ ) {
				$textwindow->insert( $markindex, "\x7f" )
				  ;                #mark the page breaks for rewrapping
				push @savelist, $markname;
			}
		}
		while ( $textwindow->get($start) =~ /^\s*\n/ )
		{                          #if the selection starts on a blank line
			$start = $textwindow->index(
					   "$start+1c") #advance the selection start until it isn't.
		}
		while ( $textwindow->get("$end+1c") =~ /^\s*\n/ )
		{    #if the selection ends at the end of a line but not over it
			$end = $textwindow->index( "$end+1c"
			  )    #advance the selection end until it does. (traps odd spaces
		}    #at paragraph end bug)
		$thisblockstart = $start;
		my $thisblockend   = $end;
		my $indentblockend = $end;
		my $inblock        = 0;
		my $infront        = 0;
		my $enableindent;
		my $fblock      = 0;
		my $leftmargin  = $main::blocklmargin;
		my $rightmargin = $main::blockrmargin;
		my $firstmargin = $main::blocklmargin;
		my ( $rewrapped, $initial_tab, $subsequent_tab, $spaces );
		my $indent = 0;
		my $offset = 0;
		my $poem   = 0;
		my $textline;
		my $lastend = $start;
		my ( $sr, $sc, $er, $ec, $line );
		my $textend      = $textwindow->index('end');
		my $toplineblank = 0;
		my $selection;

		if ( $textend eq $end ) {
			$textwindow->tagAdd( 'blockend', "$end-1c"
			  ) #set a marker at the end of the selection, or one charecter less
		} else {    #if the selection ends at the text end
			$textwindow->tagAdd( 'blockend', $end );
		}
		if ( $textwindow->get( '1.0', '1.end' ) eq '' )
		{           #trap top line delete bug
			$toplineblank = 1;
		}
		&main::opstop();
		$spaces = 0;
		while (1) {
			$indent = $main::defaultindent;
			$thisblockend =
			  $textwindow->search( '-regex', '--', '^(\x7f)*$', $thisblockstart,
								   $end );    #find end of paragraph
			if ($thisblockend) {
				$thisblockend =
				  $textwindow->index( $thisblockend . ' lineend' );
			} else {
				$thisblockend = $end;
			}
			;    #or end of text if end of selection
			$selection = $textwindow->get( $thisblockstart, $thisblockend )
			  if $thisblockend;    #get the paragraph of text
			unless ($selection) {
				$thisblockstart = $thisblockend;
				$thisblockstart = $textwindow->index("$thisblockstart+1c");
				last
				  if ( $textwindow->compare( $thisblockstart, '>=', $end ) );
				last if $main::operationinterrupt;
				next;
			}
			last
			  if (    ( $thisblockend eq $lastend )
				   || ( $textwindow->compare( $thisblockend, '<', $lastend ) ) )
			  ;                    #quit if the search isn't advancing
			$textwindow->see($thisblockend);
			$textwindow->update;

			#$firstmargin = $leftmargin if $blockwrap;
			if ( $selection =~ /^\x7f*\/\#/ ) {
				$main::blockwrap   = 1;
				$leftmargin  = $main::blocklmargin + 1;
				$firstmargin = $main::blocklmargin + 1;
				$rightmargin = $main::blockrmargin;
				if ( $selection =~ /^\x7f*\/#\[(\d+)/ )
				{    #check for block rewrapping with parameter markup
					if ($1) { $leftmargin = $1 + 1 }
					$firstmargin = $leftmargin;
				}
				if ( $selection =~ /^\x7f*\/#\[(\d+)?(\.)(\d+)/ ) {
					if ( length $3 ) { $firstmargin = $3 + 1 }
				}
				if ( $selection =~ /^\x7f*\/#\[(\d+)?(\.)?(\d+)?,(\d+)/ ) {
					if ($4) { $rightmargin = $4 }
				}
			}
			if ( $selection =~ /^\x7f*\/[\*Ll]/ ) {
				$inblock      = 1;
				$enableindent = 1;
			}    #check for no rewrap markup
			if ( $selection =~ /^\x7f*\/\*\[(\d+)/ ) { $indent = $1 }
			if ( $selection =~ /^\x7f*\/[pP]/ ) {
				$inblock      = 1;
				$enableindent = 1;
				$poem         = 1;
				$indent       = $main::poetrylmargin;
			}
			if ( $selection =~ /^\x7f*\/[Xx\$]/ ) { $inblock = 1 }
			if ( $selection =~ /^\x7f*\/[fF]/ ) {
				$inblock = 1;
			}
			$textwindow->markSet( 'rewrapend', $thisblockend )
			  ; #Set a mark at the end of the text so it can be found after rewrap
			unless ( $selection =~ /^\x7f*\s*?(\*\s*){4}\*/ )
			{    #skip rewrap if paragraph is a thought break
				if ($inblock) {
					if ($enableindent) {
						$indentblockend = $textwindow->search( '-regex', '--',
									'^\x7f*[pP\*Ll]\/', $thisblockstart, $end );
						$indentblockend = $indentblockend || $end;
						$textwindow->markSet( 'rewrapend', $indentblockend );
						unless ($offset) { $offset = 0 }
						( $sr, $sc ) = split /\./, $thisblockstart;
						( $er, $ec ) = split /\./, $indentblockend;
						unless ($offset) {
							$offset = 100;
							for my $line ( $sr + 1 .. $er - 1 ) {
								$textline =
								  $textwindow->get( "$line.0", "$line.end" );
								if ($textline) {
									$textwindow->search(
											'-regexp',
											'-count' => \$spaces,
											'--', '^\s+', "$line.0", "$line.end"
									);
									unless ($spaces) { $spaces = 0 }
									if ( $spaces < $offset ) {
										$offset = $spaces;
									}
									$spaces = 0;
								}
							}
							$indent = $indent - $offset;
						}
						for my $line ( $sr .. $er - 1 ) {
							$textline =
							  $textwindow->get( "$line.0", "$line.end" );
							next
							  if (    ( $textline =~ /^\x7f*\/[pP\*Ll]/ )
								   || ( $textline =~ /^\x7f*[pP\*LlFf]\// ) );
							if ( $enableindent and $fblock == 0 ) {
								$textwindow->insert( "$line.0",
													 ( ' ' x $indent ) )
								  if ( $indent > 0 );
								if ( $indent < 0 ) {
									if (
										 $textwindow->get( "$line.0",
											  "$line.@{[abs $indent]}" ) =~ /\S/
									  )
									{
										while (
											$textwindow->get("$line.0") eq ' ' )
										{
											$textwindow->delete("$line.0");
										}
									} else {
										$textwindow->delete( "$line.0",
													 "$line.@{[abs $indent]}" );
									}
								}
							} else {
							}
						}
						$indent       = 0;
						$offset       = 0;
						$enableindent = 0;
						$poem         = 0;
						$inblock      = 0;
					}
				} else {
					$selection =~ s/<i>/\x8d/g
					  ; #convert some characters that will interfere with rewrap
					$selection =~ s/<\/i>/\x8e/g;
					$selection =~ s/\[/\x8A/g;
					$selection =~ s/\]/\x9A/g;
					$selection =~ s/\(/\x9d/g;
					$selection =~ s/\)/\x98/g;
					if ($main::blockwrap) {
						$rewrapped =
						  &main::wrapper( $leftmargin,  $firstmargin,
								   $rightmargin, $selection, $rwhyphenspace );
					} else {    #rewrap the paragraph
						$rewrapped =
						  &main::wrapper( $main::lmargin, $main::lmargin, $main::rmargin, $selection,  
						  $rwhyphenspace);
					}
					$rewrapped =~ s/\x8d/<i>/g;     #convert the characters back
					$rewrapped =~ s/\x8e/<\/i>/g;
					$rewrapped =~ s/\x8A/\[/g;
					$rewrapped =~ s/\x9A/\]/g;
					$rewrapped =~ s/\x98/\)/g;
					$rewrapped =~ s/\x9d/\(/g;
					$textwindow->delete( $thisblockstart, $thisblockend )
					  ;    #delete the original paragraph
					$textwindow->insert( $thisblockstart, $rewrapped )
					  ;    #insert the rewrapped paragraph
					my @endtemp = $textwindow->tagRanges('blockend')
					  ;    #find the end of the rewrapped text
					$end = shift @endtemp;
				}
			}
			if ( $selection =~ /^\x7f*[XxFf\$]\//m ) {
				$inblock      = 0;
				$indent       = 0;
				$offset       = 0;
				$enableindent = 0;
				$poem         = 0;
			}
			if ( $selection =~ /\x7f*#\// ) { $main::blockwrap = 0 }
			last unless $end;
			$thisblockstart =
			  $textwindow->index('rewrapend');    #advance to the next paragraph
			$lastend = $textwindow->index("$thisblockstart+1c")
			  ;    #track where the end of the last paragraph was
			while (1) {
				$thisblockstart = $textwindow->index("$thisblockstart+1l")
				  ; #if there are blank lines before the next paragraph, advance past them
				last
				  if ( $textwindow->compare( $thisblockstart, '>=', 'end' ) );
				next
				  if (
					   $textwindow->get( $thisblockstart,
										 "$thisblockstart lineend" ) eq ''
				  );
				last;
			}
			$main::blockwrap = 0
			  if $main::operationinterrupt
			;       #reset blockwrap if rewrap routine is interrupted
			last if $main::operationinterrupt;    #then quit
			last
			  if ( $thisblockstart eq $end )
			  ;    #quit if next paragrapn starts at end of selection
			&main::update_indicators();    # update line and page numbers
		}
		&main::killstoppop();
		$main::operationinterrupt = 0;
		$textwindow->focus;
		$textwindow->update;
		$textwindow->Busy( -recurse => 1 );
		if (@savelist) {            #if there are saved page markers

			while (@savelist) {     #reinsert them
				$markname = shift @savelist;
				$markindex =
				  $textwindow->search( '-regex', '--', '\x7f', '1.0', 'end' );
				$textwindow->delete($markindex);   #then remove the page markers
				$textwindow->markSet( $markname, $markindex );
				$textwindow->markGravity( $markname, 'left' );
			}
		}
		if ( $start eq '1.0' ) {    #reinsert deleted top line if it was removed
			if ( $toplineblank == 1 ) {    #(kinda half assed but it works)
				$textwindow->insert( '1.0', "\n" );
			}
		}
		$textwindow->tagRemove( 'blockend', '1.0', 'end' );
	}
	while (1) {
		$thisblockstart =
		  $textwindow->search( '-regexp', '--', '^[\x7f\s]+$', '1.0', 'end' );
		last unless $thisblockstart;
		$textwindow->delete( $thisblockstart, "$thisblockstart lineend" );
	}
	$textwindow->see($start);
	#$lglobal{scanno_hl} = $scannosave;
	$textwindow->Unbusy( -recurse => 1 );
}

sub fracconv {
	my ($textwindow, $start, $end ) = @_;
	my %frachash = (
					 '\b1\/2\b' => '&frac12;',
					 '\b1\/4\b' => '&frac14;',
					 '\b3\/4\b' => '&frac34;',
	);
	my ( $ascii, $html, $length );
	my $thisblockstart = 1;
	while ( ( $ascii, $html ) = each(%frachash) ) {
		while (
				$thisblockstart =
				$textwindow->search(
									 '-regexp',
									 '-count' => \$length,
									 '--', "-?$ascii", $start, $end
				)
		  )
		{
			$textwindow->replacewith( $thisblockstart,
									  $thisblockstart . "+$length c", $html );
		}
	}

}

sub fromnamed {
	my ($textwindow) = @_;
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		while (@ranges) {
			my $end   = pop @ranges;
			my $start = pop @ranges;
			$textwindow->markSet( 'srchend', $end );
			my ( $thisblockstart, $length );
			&main::named( '&amp;',   '&',  $start, 'srchend' );
			&main::named( '&quot;',  '"',  $start, 'srchend' );
			&main::named( '&mdash;', '--', $start, 'srchend' );
			&main::named( ' &gt;',   ' >', $start, 'srchend' );
			&main::named( '&lt; ',   '< ', $start, 'srchend' );
			my $from;

			for ( 160 .. 255 ) {
				$from = lc sprintf( "%x", $_ );
				&main::named( &main::entity( '\x' . $from ), chr($_), $start, 'srchend' );
			}
			while (
					$thisblockstart =
					$textwindow->search(
										 '-regexp',
										 '-count' => \$length,
										 '--', '&#\d+;', $start, $end
					)
			  )
			{
				my $xchar =
				  $textwindow->get( $thisblockstart,
									$thisblockstart . '+' . $length . 'c' );
				$textwindow->ntdelete( $thisblockstart,
									   $thisblockstart . '+' . $length . 'c' );
				$xchar =~ s/&#(\d+);/$1/;
				$textwindow->ntinsert( $thisblockstart, chr($xchar) );
			}
			$textwindow->markUnset('srchend');
		}
	}
}

sub tonamed {
	my ($textwindow) = @_;
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		while (@ranges) {
			my $end   = pop @ranges;
			my $start = pop @ranges;
			$textwindow->markSet( 'srchend', $end );
			my $thisblockstart;
			&main::named( '&(?![\w#])',           '&amp;',   $start, 'srchend' );
			&main::named( '&$',                   '&amp;',   $start, 'srchend' );
			&main::named( '"',                    '&quot;',  $start, 'srchend' );
			&main::named( '(?<=[^-!])--(?=[^>])', '&mdash;', $start, 'srchend' );
			&main::named( '(?<=[^-])--$',         '&mdash;', $start, 'srchend' );
			&main::named( '^--(?=[^-])',          '&mdash;', $start, 'srchend' );
			&main::named( '& ',                   '&amp; ',  $start, 'srchend' );
			&main::named( '&c\.',                 '&amp;c.', $start, 'srchend' );
			&main::named( ' >',                   ' &gt;',   $start, 'srchend' );
			&main::named( '< ',                   '&lt; ',   $start, 'srchend' );
			my $from;

			for ( 128 .. 255 ) {
				$from = lc sprintf( "%x", $_ );
				&main::named( '\x' . $from, &main::entity( '\x' . $from ), $start,
					   'srchend' );
			}
			while (
					$thisblockstart =
					$textwindow->search(
										 '-regexp',             '--',
										 '[\x{100}-\x{65535}]', $start,
										 'srchend'
					)
			  )
			{
				my $xchar = ord( $textwindow->get($thisblockstart) );
				$textwindow->ntdelete( $thisblockstart, "$thisblockstart+1c" );
				$textwindow->ntinsert( $thisblockstart, "&#$xchar;" );
			}
			$textwindow->markUnset('srchend');
		}
	}
}

sub aligntext {
	my ($textwindow,$alignstring) = @_;
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		my $textindex = 0;
		my ( $linenum, $line, $sr, $sc, $er, $ec, $r, $c, @indexpos );
		my $end   = pop(@ranges);
		my $start = pop(@ranges);
		$textwindow->addGlobStart;
		( $sr, $sc ) = split /\./, $start;
		( $er, $ec ) = split /\./, $end;
		for my $linenum ( $sr .. $er - 1 ) {
			$indexpos[$linenum] =
			  $textwindow->search( '--', $alignstring,
								   "$linenum.0 -1c",
								   "$linenum.end" );
			if ( $indexpos[$linenum] ) {
				( $r, $c ) = split /\./, $indexpos[$linenum];
			} else {
				$c = -1;
			}
			if ( $c > $textindex ) { $textindex = $c }
			$indexpos[$linenum] = $c;
		}
		for my $linenum ( $sr .. $er ) {
			if ( $indexpos[$linenum] > (-1) ) {
				$textwindow->insert(
									 "$linenum.0",
									 (
										' ' x
										  ( $textindex - $indexpos[$linenum] )
									 )
				);
			}
		}
		$textwindow->addGlobEnd;
	}
}

sub asciibox {
	my ($textwindow,$asciiwrap,$asciiwidth,$ascii,$asciijustify) = @_;
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		my ( $linenum, $line, $sr, $sc, $er, $ec, $lspaces, $rspaces );
		my $end   = pop(@ranges);
		my $start = pop(@ranges);
		$textwindow->markSet( 'asciistart', $start );
		$textwindow->markSet( 'asciiend',   $end );
		my $saveleft  = $lmargin;
		my $saveright = $rmargin;
		$textwindow->addGlobStart;
		$lmargin = 0;
		$rmargin = ( $asciiwidth - 4 );
		&main::selectrewrap unless $asciiwrap;
		$lmargin = $saveleft;
		$rmargin = $saveright;
		$textwindow->insert(
							 'asciistart',
							 ${ $ascii }[0]
							   . (
								   ${ $ascii }[1] x
									 ( $asciiwidth - 2 )
							   )
							   . ${ $ascii }[2] . "\n"
		);
		$textwindow->insert(
							 'asciiend',
							 "\n" 
							   . ${ $ascii }[6]
							   . (
								   ${ $ascii }[7] x
									 ( $asciiwidth - 2 )
							   )
							   . ${ $ascii }[8] . "\n"
		);
		$start = $textwindow->index('asciistart');
		$end   = $textwindow->index('asciiend');
		( $sr, $sc ) = split /\./, $start;
		( $er, $ec ) = split /\./, $end;

		for my $linenum ( $sr .. $er - 2 ) {
			$line = $textwindow->get( "$linenum.0", "$linenum.end" );
			$line =~ s/^\s*//;
			$line =~ s/\s*$//;
			if ( $asciijustify eq 'left' ) {
				$lspaces = 1;
				$rspaces = ( $asciiwidth - 3 ) - length($line);
			} elsif ( $asciijustify eq 'center' ) {
				$lspaces = ( $asciiwidth - 2 ) - length($line);
				if ( $lspaces % 2 ) {
					$rspaces = ( $lspaces / 2 ) + .5;
					$lspaces = $rspaces - 1;
				} else {
					$rspaces = $lspaces / 2;
					$lspaces = $rspaces;
				}
			} elsif ( $asciijustify eq 'right' ) {
				$rspaces = 1;
				$lspaces = ( $asciiwidth - 3 ) - length($line);
			}
			$line =
			    ${ $ascii }[3]
			  . ( ' ' x $lspaces )
			  . $line
			  . ( ' ' x $rspaces )
			  . ${ $ascii }[5];
			$textwindow->delete( "$linenum.0", "$linenum.end" );
			$textwindow->insert( "$linenum.0", $line );
		}
		$textwindow->addGlobEnd;
	}
}

sub case {
	&main::saveset();
	my ($textwindow,$marker) = @_;
	#my $marker      = shift;
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	my $done        = '';
	if ( $range_total == 0 ) {
		return;
	} else {
		$textwindow->addGlobStart;
		while (@ranges) {
			my $end            = pop(@ranges);
			my $start          = pop(@ranges);
			my $thisblockstart = $start;
			my $thisblockend   = $end;
			my $selection = $textwindow->get( $thisblockstart, $thisblockend );
			my @words     = ();
			my $buildsentence = '';
			if ( $marker eq 'uc' ) {
				$done = uc($selection);
			} elsif ( $marker eq 'lc' ) {
				$done = lc($selection);
			} elsif ( $marker eq 'sc' ) {
				$done = lc($selection);
				$done =~ s/(^\W*\w)/\U$1\E/;
			} elsif ( $marker eq 'tc' ) {
				$done = lc($selection);
				$done =~ s/(^\W*\w)/\U$1\E/;
				$done =~ s/([\s\n]+\W*\w)/\U$1\E/g;
			}
			$textwindow->replacewith( $start, $end, $done );
		}
		$textwindow->addGlobEnd;
	}
}

sub surround {
	my ($textwindow,$surpop,$top,$font,$activecolor,$icon) = @_;
	if ( defined( $surpop ) ) {
		$surpop->deiconify;
		$surpop->raise;
		$surpop->focus;
	} else {
		$surpop = $top->Toplevel;
		$surpop->title('Surround text with:');
		
		my $f = $surpop->Frame->pack( -side => 'top', -anchor => 'n' );
		$f->Label( -text =>
"Surround the selection with?\n\\n will be replaced with a newline.",
		)->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
		my $f1 =
		  $surpop->Frame->pack( -side => 'top', -anchor => 'n' );
		my $surstrt = $f1->Entry(
								  -width      => 8,
								  -background => 'white',
								  -font       => $font,
								  -relief     => 'sunken',
		)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'n' );
		my $surend = $f1->Entry(
								 -width      => 8,
								 -background => 'white',
								 -font       => $font,
								 -relief     => 'sunken',
		)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'n' );
		my $f2 =
		  $surpop->Frame->pack( -side => 'top', -anchor => 'n' );
		my $gobut = $f2->Button(
			-activebackground => $activecolor,
			-command          => sub {
				surroundit( $surstrt->get, $surend->get ,$textwindow);
			},
			-text  => 'OK',
			-width => 16
		)->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
		$surpop->protocol(
			'WM_DELETE_WINDOW' => sub {
				$surpop->destroy;
				undef $surpop;
			}
		);
		$surstrt->insert( 'end', '_' ) unless ( $surstrt->get );
		$surend->insert( 'end', '_' ) unless ( $surend->get );
		$surpop->Icon( -image => $icon );
	}
	return $surpop
}

sub surroundit {
	my ( $pre, $post,$textwindow ) = @_;
	$pre  =~ s/\\n/\n/;
	$post =~ s/\\n/\n/;
	my @ranges = $textwindow->tagRanges('sel');
	unless (@ranges) {
		push @ranges, $textwindow->index('insert');
		push @ranges, $textwindow->index('insert');
	}
	$textwindow->addGlobStart;
	while (@ranges) {
		my $end   = pop(@ranges);
		my $start = pop(@ranges);
		$textwindow->replacewith( $start, $end,
							  $pre . $textwindow->get( $start, $end ) . $post );
	}
	$textwindow->addGlobEnd;
}

sub flood {
	my ($textwindow,$top,$floodpop,$font,$activecolor,$icon) = @_;
	my $ffchar;
	if ( defined( $floodpop ) ) {
		$floodpop->deiconify;
		$floodpop->raise;
		$floodpop->focus;
	} else {
		$floodpop = $top->Toplevel;
		$floodpop->title('Flood Fill String:');
		my $f =
		  $floodpop->Frame->pack( -side => 'top', -anchor => 'n' );
		$f->Label( -text =>
"Flood fill string.\n(Blank will default to spaces.)\nHotkey Control+w",
		)->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
		my $f1 =
		  $floodpop->Frame->pack(
										   -side   => 'top',
										   -anchor => 'n',
										   -expand => 'y',
										   -fill   => 'x'
		  );
		my $floodch = $f1->Entry(
								  -background   => 'white',
								  -font         => $font,
								  -relief       => 'sunken',
								  -textvariable => \$ffchar,
		  )->pack(
				   -side   => 'left',
				   -pady   => 5,
				   -padx   => 2,
				   -anchor => 'w',
				   -expand => 'y',
				   -fill   => 'x'
		  );
		my $f2 =
		  $floodpop->Frame->pack( -side => 'top', -anchor => 'n' );
		my $gobut = $f2->Button(
								 -activebackground => $activecolor,
								 -command          => sub { floodfill($textwindow,$ffchar) },
								 -text             => 'Flood Fill',
								 -width            => 16
		)->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
		$floodpop->protocol(
			'WM_DELETE_WINDOW' => sub {
				$floodpop->destroy;
				undef $floodpop;
			}
		);
		$floodpop->Icon( -image => $icon );
	}
	return $floodpop;
}

sub floodfill {
	my ($textwindow,$ffchar) = @_;
	my @ranges = $textwindow->tagRanges('sel');
	return unless @ranges;
	$ffchar = ' ' unless length $ffchar;
	$textwindow->addGlobStart;
	while (@ranges) {
		my $end       = pop(@ranges);
		my $start     = pop(@ranges);
		my $selection = $textwindow->get( $start, $end );
		my $temp = substr(
						   $ffchar x (
												(
												  ( length $selection ) /
													( length $ffchar )
												) + 1
						   ),
						   0,
						   ( length $selection )
		);
		chomp $selection;
		my @temparray = split( /\n/, $selection );
		my $replacement;
		for (@temparray) {
			$replacement .= substr( $temp, 0, ( length $_ ), '' );
			$replacement .= "\n";
		}
		chomp $replacement;
		$textwindow->replacewith( $start, $end, $replacement );
	}
	$textwindow->addGlobEnd;

}


sub indent {
	&main::saveset();
	my ($textwindow,$indent) = @_;
	#my $indent      = shift;
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	$main::operationinterrupt = 0;
	if ( $range_total == 0 ) {
		return;
	} else {
		my @selarray;
		if ( $indent eq 'up' ) { @ranges = reverse @ranges }
		while (@ranges) {
			my $end            = pop(@ranges);
			my $start          = pop(@ranges);
			my $thisblockstart = int($start) . '.0';
			my $thisblockend   = int($end) . '.0';
			my $index          = $thisblockstart;
			if ( $thisblockstart == $thisblockend ) {
				my $char;
				if ( $indent eq 'in' ) {
					if ( $textwindow->compare( $end, '==', "$end lineend" ) ) {
						$char = ' ';
					} else {
						$char = $textwindow->get($end);
						$textwindow->delete($end);
					}
					$textwindow->insert( $start, $char )
					  unless (
						 $textwindow->get( $start, "$start lineend" ) =~ /^$/ );
					$end = "$end+1c"
					  unless (
							 $textwindow->get( $end, "$end lineend" ) =~ /^$/ );
					push @selarray, ( "$start+1c", $end );
				} elsif ( $indent eq 'out' ) {
					if (
						 $textwindow->compare( $start, '==', "$start linestart"
						 )
					  )
					{
						push @selarray, ( $start, $end );
						next;
					} else {
						$char = $textwindow->get("$start-1c");
						$textwindow->insert( $end, $char );
						$textwindow->delete("$start-1c");
						push @selarray, ( "$start-1c", "$end-1c" );
					}
				}
			} else {
				while ( $index <= $thisblockend ) {
					if ( $indent eq 'in' ) {
						$textwindow->insert( $index, ' ' )
						  unless (
								 $textwindow->get( $index, "$index lineend" ) =~
								 /^$/ );
					} elsif ( $indent eq 'out' ) {
						if ( $textwindow->get( $index, "$index+1c" ) eq ' ' ) {
							$textwindow->delete( $index, "$index+1c" );
						}
					}
					$index++;
					$index .= '.0';
				}
				push @selarray, ( $thisblockstart, "$thisblockend lineend" );
			}
			if ( $indent eq 'up' ) {
				my $temp = $end, $end = $start;
				$start = $temp;
				if ( $textwindow->compare( "$start linestart", '==', '1.0' ) ) {
					push @selarray, ( $start, $end );
					push @selarray, @ranges;
					last;
				} else {
					while (
							$textwindow->compare(
											  "$end-1l", '>=', "$end-1l lineend"
							)
					  )
					{
						$textwindow->insert( "$end-1l lineend", ' ' );
					}
					my $templine = $textwindow->get( "$start-1l", "$end-1l" );
					$textwindow->replacewith( "$start-1l", "$end-1l",
										 ( $textwindow->get( $start, $end ) ) );
					push @selarray, ( "$start-1l", "$end-1l" );
					while (@ranges) {
						$start = pop(@ranges);
						$end   = pop(@ranges);
						$textwindow->replacewith( "$start-1l", "$end-1l",
										 ( $textwindow->get( $start, $end ) ) );
						push @selarray, ( "$start-1l", "$end-1l" );
					}
					$textwindow->replacewith( $start, $end, $templine );
				}
			} elsif ( $indent eq 'dn' ) {
				if (
					 $textwindow->compare(
									  "$end+1l", '>=', $textwindow->index('end')
					 )
				  )
				{
					push @selarray, ( $start, $end );
					push @selarray, @ranges;
					last;
				} else {
					while (
							$textwindow->compare(
											  "$end+1l", '>=', "$end+1l lineend"
							)
					  )
					{
						$textwindow->insert( "$end+1l lineend", ' ' );
					}
					my $templine = $textwindow->get( "$start+1l", "$end+1l" );
					$textwindow->replacewith( "$start+1l", "$end+1l",
										 ( $textwindow->get( $start, $end ) ) );
					push @selarray, ( "$start+1l", "$end+1l" );
					while (@ranges) {
						$end   = pop(@ranges);
						$start = pop(@ranges);
						$textwindow->replacewith( "$start+1l", "$end+1l",
										 ( $textwindow->get( $start, $end ) ) );
						push @selarray, ( "$start+1l", "$end+1l" );
					}
					$textwindow->replacewith( $start, $end, $templine );
				}
			}
			$textwindow->focus;
			$textwindow->tagRemove( 'sel', '1.0', 'end' );
		}
		while (@selarray) {
			my $end   = pop(@selarray);
			my $start = pop(@selarray);
			$textwindow->tagAdd( 'sel', $start, $end );
		}
	}
}


1;


