package Guiguts::SelectionMenu;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&case &surround &flood &indent &asciibox &aligntext &tonamed &fromnamed)
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
	my ($textwindow,$indent,$operationinterrupt) = @_;
	#my $indent      = shift;
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	$operationinterrupt = 0;
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


