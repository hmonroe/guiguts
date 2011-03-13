#$Id: HTMLConvert.pm 56 2008-09-27 17:37:26Z vlsimpson $

package Guiguts::HTMLConvert;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&html_convert_tb  &html_convert_subscripts &html_convert_superscripts
	&html_convert_ampersands &html_convert_emdashes &html_convert_latin1 &html_convert_codepage &html_convert_utf
	&html_cleanup_markers &html_convert_footnotes &html_convert_body &html_convert_underscoresmallcaps 
	&html_convert_sidenotes &html_convert_pageanchors)
}

sub html_convert_tb {
	no warnings;    # FIXME: Warning-- Exiting subroutine via next
	my ($textwindow, $selection, $step ) = @_;

	if ( $selection =~ s/\s{7}(\*\s{7}){4}\*/<hr style="width: 45%;" \/>/ ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
		$next;
	}

	if ( $selection =~ s/<tb>/<hr style="width: 45%;" \/>/ ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
		next;
	}

}

sub html_convert_subscripts {
	my ($textwindow, $selection, $step ) = @_;

	if ( $selection =~ s/_\{([^}]+?)\}/<sub>$1<\/sub>/g ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
	}
}

# FIXME: Doesn't convert Gen^rl; workaround Gen^{rl}
sub html_convert_superscripts {
	my ($textwindow, $selection, $step ) = @_;

	if ( $selection =~ s/\^\{([^}]+?)\}/<sup>$1<\/sup>/g ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
	}
}

sub html_convert_ampersands {
	&main::working("Converting Ampersands");
	&main::named( '&(?![\w#])', '&amp;' );
	&main::named( '&$',         '&amp;' );
	&main::named( '& ',         '&amp; ' );
	&main::named( '&c\.',       '&amp;c.' );
	&main::named( '&c,',        '&amp;c.,' );
	&main::named( '&c ',        '&amp;c. ' );
}

# double hyphens go to character entity ref. FIXME: Add option for real emdash.
sub html_convert_emdashes {
	&main::working("Converting Emdashes");
	&main::named( '(?<=[^-!])--(?=[^>])', '&mdash;' );
	&main::named( '(?<=[^<])!--(?=[^>])', '!&mdash;' );
	&main::named( '(?<=[^-])--$',         '&mdash;' );
	&main::named( '^--(?=[^-])',          '&mdash;' );
	&main::named( "\x{A0}",               '&nbsp;' );
}

# convert latin1 and utf charactes to HTML Character Entity Reference's.
sub html_convert_latin1 {
	&main::working("Converting Latin-1 Characters...");
	for ( 128 .. 255 ) {
		my $from = lc sprintf( "%x", $_ );
		&main::named( '\x' . $from, entity( '\x' . $from ) );
	}
}

sub html_convert_codepage {
	&main::working("Converting Windows Codepage 1252\ncharacters to Unicode");
	&main::cp1252toUni();
}

sub html_convert_utf {
	my ($textwindow,$blockstart) = @_;
	if ( $lglobal{leave_utf} ) {
		$blockstart =
		  $textwindow->search(
							   '-exact',             '--',
							   'charset=iso-8859-1', '1.0',
							   'end'
		  );
		if ($blockstart) {
			$textwindow->ntdelete( $blockstart, "$blockstart+18c" );
			$textwindow->ntinsert( $blockstart, 'charset=UTF-8' );
		}
	}
	unless ( $lglobal{leave_utf} ) {
		&main::working("Converting UTF-8...");
		while (
				$blockstart =
				$textwindow->search(
									 '-regexp',             '--',
									 '[\x{100}-\x{65535}]', '1.0',
									 'end'
				)
		  )
		{
			my $xchar = ord( $textwindow->get($blockstart) );
			$textwindow->ntdelete($blockstart);
			$textwindow->ntinsert( $blockstart, "&#$xchar;" );
		}
	}

}

# FIXME: Should be a general purpose function
sub html_cleanup_markers {
	my ($textwindow, $blockstart, $xler, $xlec, $blockend ) = @_;

	&main::working("Cleaning up\nblock Markers");

	while ( $blockstart =
		   $textwindow->search( '-regexp', '--', '^\/[\*\$\#]', '1.0', 'end' ) )
	{
		( $xler, $xlec ) = split /\./, $blockstart;
		$blockend = "$xler.end";
		$textwindow->ntdelete( "$blockstart-1c", $blockend );
	}
	while ( $blockstart =
		   $textwindow->search( '-regexp', '--', '^[\*\$\#]\/', '1.0', 'end' ) )
	{
		( $xler, $xlec ) = split /\./, $blockstart;
		$blockend = "$xler.end";
		$textwindow->ntdelete( "$blockstart-1c", $blockend );
	}
	while ( $blockstart =
		 $textwindow->search( '-regexp', '--', '<\/h\d><br />', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( "$blockstart+5c", "$blockstart+9c" );
	}

}


sub html_convert_footnotes {
	my ($textwindow ) = @_;
	my $thisblank  = q{};
	my $step = 0;
	
	
	# Footnotes
	$lglobal{fnsecondpass}  = 0;
	$lglobal{fnsearchlimit} = 1;
	&main::working('Converting Footnotes');
	&main::footnotefixup();
	&main::getlz();
	$textwindow->tagRemove( 'footnote',  '1.0', 'end' );
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	$textwindow->see('1.0');
	$textwindow->update;

	while (1) {
		$step++;
		last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
		last unless $lglobal{fnarray}->[$step][0];
		next unless $lglobal{fnarray}->[$step][3];
		$textwindow->ntdelete( 'fne' . "$step" . '-1c', 'fne' . "$step" );
		$textwindow->ntinsert( 'fne' . "$step", '</p></div>' );
		$textwindow->ntinsert(
							 (
							   'fns' . "$step" . '+'
								 . (
									length( $lglobal{fnarray}->[$step][4] ) + 11
								 )
								 . "c"
							 ),
							 ']</span></a>'
		);
		$textwindow->ntdelete(
							   'fns' . "$step" . '+'
								 . (
									length( $lglobal{fnarray}->[$step][4] ) + 10
								 )
								 . 'c',
							   "fns" . "$step" . '+'
								 . (
									length( $lglobal{fnarray}->[$step][4] ) + 11
								 )
								 . 'c'
		);
		$textwindow->ntinsert(
							   'fns' . "$step" . '+10c',
							   "<div class=\"footnote\"><p><a name=\"Footnote_"
								 . $lglobal{fnarray}->[$step][4] . '_'
								 . $step
								 . "\" id=\"Footnote_"
								 . $lglobal{fnarray}->[$step][4] . '_'
								 . $step
								 . "\"></a><a href=\"#FNanchor_"
								 . $lglobal{fnarray}->[$step][4] . '_'
								 . $step
								 . "\"><span class=\"label\">["
		);
		$textwindow->ntdelete( 'fns' . "$step", 'fns' . "$step" . '+10c' );
		$textwindow->ntinsert( 'fnb' . "$step", '</a>' )
		  if ( $lglobal{fnarray}->[$step][3] );
		$textwindow->ntinsert(
							   'fna' . "$step",
							   "<a name=\"FNanchor_"
								 . $lglobal{fnarray}->[$step][4] . '_'
								 . $step
								 . "\" id=\"FNanchor_"
								 . $lglobal{fnarray}->[$step][4] . '_'
								 . $step
								 . "\"></a><a href=\"#Footnote_"
								 . $lglobal{fnarray}->[$step][4] . '_'
								 . $step
								 . "\" class=\"fnanchor\">"
		) if ( $lglobal{fnarray}->[$step][3] );

		while (
				$thisblank =
				$textwindow->search(
									 '-regexp', '--',
									 '^$',      'fns' . "$step",
									 "fne" . "$step"
				)
		  )
		{
			$textwindow->ntinsert( $thisblank, '</p><p>' );
		}
	}
	
}

sub html_convert_body {
	my ($textwindow, @contents) = @_;
	&main::working('Converting Body');
	my $aname = q{};
	my $author;
	my $blkquot = 0;
	my $cflag   = 0;
	my $front;
	my $headertext;
	my $inblock    = 0;
	my $incontents = '1.0';
	my $indent     = 0;
	my $intitle    = 0;
	my $ital       = 0;
	my $listmark   = 0;
	my $pgoffset   = 0;
	my $poetry     = 0;
	my $selection  = q{};
	my $skip       = 0;
	my $thisblank  = q{};
	my $thisblockend;
	my $thisblockstart = '1.0';
	my $thisend        = q{};
	my @last5        = [ '1', '1', '1', '1', '1', '1' ];
	my $step         = 1;
	my ( $ler, $lec );
	
	$thisblockend = $textwindow->index('end');
	my ( $blkopen, $blkclose );
	if ( $lglobal{cssblockmarkup} ) {
		$blkopen  = '<div class="blockquot"><p>';
		$blkclose = '</p></div>';
	} else {
		$blkopen  = '<blockquote><p>';
		$blkclose = '</p></blockquote>';
	}
	
	
	( $ler, $lec ) = split /\./, $thisblockend;
	while ( $step <= $ler ) {
		unless ( $step % 500 ) {
			$textwindow->see("$step.0");
			$textwindow->update;
		}
		$selection = $textwindow->get( "$step.0", "$step.end" );
		$incontents = "$step.end"
		  if (    ( $step < 100 )
			   && ( $selection =~ /contents/i )
			   && ( $incontents eq '1.0' ) );

		# Subscripts
		html_convert_subscripts($textwindow, $selection, $step );

		# Superscripts
		html_convert_superscripts($textwindow, $selection, $step );

		# Thought break conversion
		html_convert_tb( $textwindow,$selection, $step );

	 # /x|/X gets <pre>
		if ( $selection =~ m"^/x"i ) {
			$skip = 1;
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->insert( "$step.0", '<pre>' );
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				$textwindow->ntinsert( ( $step - 2 ) . ".end", '</p>' )
				  unless (
						   $textwindow->get( ( $step - 2 ) . '.0',
											 ( $step - 2 ) . '.end' ) =~ /<\/p>/
				  );
			}
			$step++;
			next;
		}

		# and end tag gets </pre>
		if ( $selection =~ m"^x/"i ) {
			$skip = 0;
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.0", '</pre>' );
			$step++;
			$step++;
			next;
		}
		if ($skip) {
			$step++;
			next;
		}
		if ( $selection =~ m"^/f"i ) {
			$front = 1;
			$textwindow->ntdelete( "$step.0", "$step.end +1c" );
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				$textwindow->ntinsert( ( $step - 2 ) . ".end", '</p>' )
				  unless (
						   $textwindow->get( ( $step - 2 ) . '.0',
											 ( $step - 2 ) . '.end' ) =~ /<\/p>/
				  );
			}
			next;
		}
		if ($front) {
			if ( $selection =~ m"^f/"i ) {
				$front = 0;
				$textwindow->ntdelete( "$step.0", "$step.end +1c" );
				$step++;
				next;
			}
			if ( $selection =~ /^<h/ ) {
				push @last5, $selection;
				shift @last5 while ( scalar(@last5) > 4 );
				$step++;
				next;
			}
			$textwindow->ntinsert( "$step.0", '<p class="center">' )
			  if (    length($selection)
				   && ( !$last5[3] )
				   && ( $selection !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) );
			$textwindow->ntinsert( ( $step - 1 ) . '.end', '</p>' )
			  if (   !( length($selection) )
				   && ( $last5[3] )
				   && ( $last5[3] !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}
		if ( $lglobal{poetrynumbers} && ( $selection =~ s/\s\s(\d+)$// ) ) {
			$selection .= '<span class="linenum">' . $1 . '</span>';
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.0", $selection );
		}
		if ($poetry) {
			if ( $selection =~ /^\x7f*[pP]\/<?/ ) {
				$poetry    = 0;
				$selection = '</div></div>';
				$textwindow->ntdelete( "$step.0", "$step.0 +2c" );
				$textwindow->ntinsert( "$step.0", $selection );
				push @last5, $selection;
				shift @last5 while ( scalar(@last5) > 4 );
				$ital = 0;
				$step++;
				next;
			}
			if ( $selection =~ /^$/ ) {
				$textwindow->ntinsert( "$step.0",
									   '</div><div class="stanza">' );
				while (1) {
					$step++;
					$selection = $textwindow->get( "$step.0", "$step.end" );
					last if ( $step ge $ler );
					next if ( $selection =~ /^$/ );
					last;
				}
				next;
			}
			if ( $selection =~
				 s/\s{2,}(\d+)\s*$/<span class="linenum">$1<\/span>/ )
			{
				$textwindow->ntdelete( "$step.0", "$step.end" );
				$textwindow->ntinsert( "$step.0", $selection );
			}
			my $indent = 0;
			$indent = length($1) if $selection =~ s/^(\s+)//;
			$textwindow->ntdelete( "$step.0", "$step.$indent" ) if $indent;
			$indent -= 4;
			$indent = 0 if ( $indent < 0 );
			my ( $op, $cl ) = ( 0, 0 );
			while ( ( my $temp = index $selection, '<i>', $op ) > 0 ) {
				$op = $temp + 3;
			}
			while ( ( my $temp = index $selection, '</i>', $cl ) > 0 ) {
				$cl = $temp + 4;
			}
			if ( !$cl && $ital ) {
				$textwindow->ntinsert( "$step.end", '</i>' );
			}
			if ( !$op && $ital ) {
				$textwindow->ntinsert( "$step.0", '<i>' );
			}
			if ( $op && $cl && ( $cl < $op ) && $ital ) {
				$textwindow->ntinsert( "$step.0",   '<i>' );
				$textwindow->ntinsert( "$step.end", '</i>' );
			}
			if ( $op && ( $cl < $op ) && !$ital ) {
				$textwindow->ntinsert( "$step.end", '</i>' );
				$ital = 1;
			}
			if ( $cl && ( $op < $cl ) && $ital ) {
				if ($op) {
					$textwindow->ntinsert( "$step.0", '<i>' );
				}
				$ital = 0;
			}
			$lglobal{classhash}->{$indent} =
			    '    .poem span.i' 
			  . $indent
			  . '     {display: block; margin-left: '
			  . $indent
			  . 'em; padding-left: 3em; text-indent: -3em;}' . "\n"
			  if ( $indent and ( $indent != 2 ) and ( $indent != 4 ) );
			$textwindow->ntinsert( "$step.0",   "<span class=\"i$indent\">" );
			$textwindow->ntinsert( "$step.end", '<br /></span>' );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}
		if ( $selection =~ /^\x7f*\/[pP]$/ ) {
			$poetry = 1;
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				$textwindow->ntinsert( ( $step - 2 ) . ".end", '</p>' )
				  unless (
						   $textwindow->get( ( $step - 2 ) . '.0',
											 ( $step - 2 ) . '.end' ) =~ /<\/p>/
				  );
			}
			$textwindow->ntdelete( $step . '.end -2c', $step . '.end' );
			$selection = '<div class="poem"><div class="stanza">';
			$textwindow->ntinsert( $step . '.end', $selection );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}
		if ( $selection =~ /^\x7f*\/\#/ ) {
			$blkquot = 1;
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			$selection = $textwindow->get( "$step.0", "$step.end" );
			$selection =~ s/^\s+//;
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.0", $blkopen . $selection );

			if ( ( $last5[1] ) && ( !$last5[2] ) ) {
				$textwindow->ntinsert( ( $step - 3 ) . ".end", '</p>' )
				  unless (
						   $textwindow->get( ( $step - 3 ) . '.0',
											 ( $step - 2 ) . '.end' ) =~
						   /<\/?h\d?|<br.*?>|<\/p>|<\/div>/
				  );
			}
			$textwindow->ntinsert( ($step) . ".end", '</p>' )
			  unless (
					   length $textwindow->get(
									( $step + 1 ) . '.0', ( $step + 1 ) . '.end'
					   )
			  );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}
		if ( $selection =~ /^\x7f*\/[Ll]/ ) {
			$listmark = 1;
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				$textwindow->ntinsert( ( $step - 2 ) . ".end", '</p>' )
				  unless (
						   $textwindow->get( ( $step - 2 ) . '.0',
											 ( $step - 2 ) . '.end' ) =~ /<\/p>/
				  );
			}
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$step++;
			$selection = $textwindow->get( "$step.0", "$step.end" );
			$selection = '<ul><li>' . $selection . '</li>';
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.0", $selection );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}
		if ( $selection =~ /^\x7f*\#\// ) {
			$blkquot = 0;
			$textwindow->ntinsert( ( $step - 1 ) . '.end', $blkclose );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}
		if ( $selection =~ /^\x7f*[Ll]\// ) {
			$listmark = 0;
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.end", '</ul>' );
			push @last5, '</ul>';
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}
		if ($listmark) {
			if ( $selection eq '' ) { $step++; next; }
			$textwindow->ntdelete( "$step.0", "$step.end" );
			my ( $op, $cl ) = ( 0, 0 );
			while ( ( my $temp = index $selection, '<i>', $op ) > 0 ) {
				$op = $temp + 3;
			}
			while ( ( my $temp = index $selection, '</i>', $cl ) > 0 ) {
				$cl = $temp + 4;
			}
			if ( !$cl && $ital ) {
				$selection .= '</i>';
			}
			if ( !$op && $ital ) {
				$selection = '<i>' . $selection;
			}
			if ( $op && $cl && ( $cl < $op ) && $ital ) {
				$selection = '<i>' . $selection;
				$selection .= '</i>';
			}
			if ( $op && ( $cl < $op ) && !$ital ) {
				$selection .= '</i>';
				$ital = 1;
			}
			if ( $cl && ( $op < $cl ) && $ital ) {
				if ($op) {
					$selection = '<i>' . $selection;
				}
				$ital = 0;
			}
			$textwindow->ntinsert( "$step.0", '<li>' . $selection . '</li>' );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}
		if ($blkquot) {
			if ( $selection =~ s/^(\s+)// ) {
				my $space = length $1;
				$textwindow->ntdelete( "$step.0", "$step.0 +${space}c" );
			}
		}
		if ( $selection =~ /^\x7f*[\$\*]\// ) {
			$inblock = 0;
			$ital    = 0;
			$textwindow->replacewith( "$step.0", "$step.end", '</p>' );
			$step++;
			next;
		}
		if ( $selection =~ /^\x7f*\/[\$\*]/ ) {
			$inblock = 1;
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				$textwindow->ntinsert( ( $step - 2 ) . '.end', '</p>' )
				  unless (
						   (
							 $textwindow->get( ( $step - 2 ) . '.0',
											   ( $step - 2 ) . '.end' ) =~
							 /<\/?[hd]\d?|<br.*?>|<\/p>/
						   )
				  );
			}
			$textwindow->replacewith( "$step.0", "$step.end", '<p>' );
			$step++;
			next;
		}
		if ( ( $last5[2] ) && ( !$last5[3] ) ) {
			$textwindow->ntinsert( ( $step - 2 ) . '.end', '</p>' )
			  unless (
					   (
						 $textwindow->get( ( $step - 2 ) . '.0',
										   ( $step - 2 ) . '.end' ) =~
						 /<\/?[hd]\d?|<br.*?>|<\/p>|<\/[uo]l>/
					   )
					   || ($inblock)
			  );
		}
		if ( $inblock || ( $selection =~ /^\s/ ) ) {
			if ( $last5[3] ) {
				if ( $last5[3] =~ /^\S/ ) {
					$last5[3] .= '<br />';
					$textwindow->ntdelete( ( $step - 1 ) . '.0',
										   ( $step - 1 ) . '.end' );
					$textwindow->ntinsert( ( $step - 1 ) . '.0', $last5[3] );
				}
			}
			$thisend = $textwindow->index( $step . ".end" );
			$textwindow->ntinsert( $thisend, '<br />' );
			if ( $selection =~ /^(\s+)/ ) {
				$indent = ( length($1) / 2 );
				$selection =~ s/^\s+//;
				$selection =~ s/  /&nbsp; /g;
				$selection =~ s/(&nbsp; ){1,}\s?(<span class="linenum">)/ $2/g;
				my ( $op, $cl ) = ( 0, 0 );
				while ( ( my $temp = index $selection, '<i>', $op ) > 0 ) {
					$op = $temp + 3;
				}
				while ( ( my $temp = index $selection, '</i>', $cl ) > 0 ) {
					$cl = $temp + 4;
				}
				if ( !$cl && $ital ) {
					$selection .= '</i>';
				}
				if ( !$op && $ital ) {
					$selection = '<i>' . $selection;
				}
				if ( $op && $cl && ( $cl < $op ) && $ital ) {
					$selection = '<i>' . $selection;
					$selection .= '</i>';
				}
				if ( $op && ( $cl < $op ) && !$ital ) {
					$selection .= '</i>';
					$ital = 1;
				}
				if ( $cl && ( $op < $cl ) && $ital ) {
					if ($op) {
						$selection = '<i>' . $selection;
					}
					$ital = 0;
				}
				$selection =
				    '<span style="margin-left: ' 
				  . $indent . 'em;">'
				  . $selection
				  . '</span>';
				$textwindow->ntdelete( "$step.0", $thisend );
				$textwindow->ntinsert( "$step.0", $selection );
			}
			if ( ( $last5[2] ) && ( !$last5[3] ) && ( $selection =~ /\/\*/ ) ) {
				$textwindow->ntinsert( ( $step - 2 ) . ".end", '</p>' )
				  unless (
						   $textwindow->get( ( $step - 2 ) . '.0',
										( $step - 2 ) . '.end' ) =~ /<\/[hd]\d?/
				  );
			}
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}
		{

			no warnings qw/uninitialized/;
			if (    ( !$last5[0] )
				 && ( !$last5[1] )
				 && ( !$last5[2] )
				 && ( !$last5[3] )
				 && ($selection) )
			{
				$textwindow->ntinsert( ( $step - 1 ) . '.0',
									   '<hr style="width: 65%;" />' )
				  unless ( $selection =~ /<[ph]/ );
				$aname =~ s/<\/?[hscalup].*?>//g;
				$aname = &main::makeanchor( &main::deaccent($selection) );
				$textwindow->ntinsert(
									   "$step.0",
									   "<h2><a name=\"" 
										 . $aname
										 . "\" id=\""
										 . $aname
										 . "\"></a>"
				) unless ( $selection =~ /<[ph]/ );
				$textwindow->ntinsert( "$step.end", '</h2>' )
				  unless ( $selection =~ /<[ph]/ );
				unless ( $selection =~ /<p/ ) {
					$selection =~ s/<sup>.*?<\/sup>//g;
					$selection =~ s/<[^>]+>//g;
					$selection = "<b>$selection</b>";
					push @contents,
					    "<a href=\"#" 
					  . $aname . "\">"
					  . $selection
					  . "</a><br />\n";
				}
				$selection .= '<h2>';
				$textwindow->see("$step.0");
				$textwindow->update;
			} elsif ( ( $last5[2] =~ /<h2>/ ) && ($selection) ) {
				$textwindow->ntinsert( "$step.0", '<p>' )
				  unless (    ( $selection =~ /<[pd]/ )
						   || ( $selection =~ /<[hb]r>/ )
						   || ($inblock) );
			} elsif ( ( $last5[2] ) && ( !$last5[3] ) && ($selection) ) {
				$textwindow->ntinsert( "$step.0", '<p>' )
				  unless (    ( $selection =~ /<[phd]/ )
						   || ( $selection =~ /<[hb]r>/ )
						   || ($inblock) );
			} elsif (    ( $last5[1] )
					  && ( !$last5[2] )
					  && ( !$last5[3] )
					  && ($selection) )
			{
				$textwindow->ntinsert( "$step.0", '<p>' )
				  unless (    ( $selection =~ /<[phd]/ )
						   || ( $selection =~ /<[hb]r>/ )
						   || ($inblock) );
			} elsif (    ( $last5[0] )
					  && ( !$last5[1] )
					  && ( !$last5[2] )
					  && ( !$last5[3] )
					  && ($selection) )
			{
				$textwindow->ntinsert( "$step.0", '<p>' )
				  unless (    ( $selection =~ /<[phd]/ )
						   || ( $selection =~ /<[hb]r>/ )
						   || ($inblock) );
			}
		}
		push @last5, $selection;
		shift @last5 while ( scalar(@last5) > 4 );
		$step++;
	}
	push @contents, '</p>';

	
}

sub html_convert_underscoresmallcaps {
	my ($textwindow) = @_;
	my $thisblockstart = '1.0';
	
	
	
	&main::working("Converting underscore and small caps markup");
	while ( $thisblockstart =
			$textwindow->search( '-exact', '--', '<u>', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( $thisblockstart, "$thisblockstart+3c" );
		$textwindow->ntinsert( $thisblockstart, '<span class="u">' );
	}
	while ( $thisblockstart =
			$textwindow->search( '-exact', '--', '</u>', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( $thisblockstart, "$thisblockstart+4c" );
		$textwindow->ntinsert( $thisblockstart, '</span>' );
	}
	while ( $thisblockstart =
			$textwindow->search( '-exact', '--', '<sc>', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( $thisblockstart, "$thisblockstart+4c" );
		$textwindow->ntinsert( $thisblockstart, '<span class="smcap">' );
	}
	while ( $thisblockstart =
			$textwindow->search( '-exact', '--', '</sc>', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( $thisblockstart, "$thisblockstart+5c" );
		$textwindow->ntinsert( $thisblockstart, '</span>' );
	}
	while ( $thisblockstart =
			$textwindow->search( '-exact', '--', '</pre></p>', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( "$thisblockstart+6c", "$thisblockstart+10c" );
	}
	$thisblockstart = '1.0';
	while (
			$thisblockstart =
			$textwindow->search(
								 '-exact',        '--',
								 '<p>FOOTNOTES:', $thisblockstart,
								 'end'
			)
	  )
	{
		$textwindow->ntdelete( $thisblockstart, "$thisblockstart+17c" );
		$textwindow->insert( $thisblockstart,
							 '<div class="footnotes"><h3>FOOTNOTES:</h3>' );
		$thisblockstart =
		  $textwindow->search( '-exact', '--', '<hr', $thisblockstart, 'end' );
		if ($thisblockstart) {
			$textwindow->insert( "$thisblockstart-3l", '</div>' );
		} else {
			$textwindow->insert( 'end-1l', '</div>' );
			last;
		}
	}

	
}

sub html_convert_sidenotes {
	my ($textwindow) = @_;
	&main::working("Converting\nSidenotes");
	my $thisnoteend;
	my $length;
	my $thisblockstart = '1.0';
	
	while (
			$thisblockstart =
			$textwindow->search(
								 '-regexp',
								 '-count' => \$length,
								 '--', '(<p>)?\[Sidenote:\s*', '1.0', 'end'
			)
	  )
	{
		$textwindow->ntdelete( $thisblockstart,
							   $thisblockstart . '+' . $length . 'c' );
		$textwindow->ntinsert( $thisblockstart, '<div class="sidenote">' );
		$thisnoteend = $textwindow->search( '--', ']', $thisblockstart, 'end' );
		while ( $textwindow->get( "$thisblockstart+1c", $thisnoteend ) =~ /\[/ )
		{
			$thisblockstart = $thisnoteend;
			$thisnoteend =
			  $textwindow->search( '--', ']</p>', $thisblockstart, 'end' );
		}
		$textwindow->ntdelete( $thisnoteend, "$thisnoteend+5c" )
		  if $thisnoteend;
		$textwindow->ntinsert( $thisnoteend, '</div>' ) if $thisnoteend;
	}
	while ( $thisblockstart =
			$textwindow->search( '--', '</div></div></p>', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( "$thisblockstart+12c", "$thisblockstart+16c" );
	}
	
	
}


sub html_convert_pageanchors {
	
	my ($textwindow, $incontents, @contents) = @_;	
	if ( $lglobal{pageanch} || $lglobal{pagecmt} ) {

		working("Inserting Page Markup");
		$|++;
		my ( $mark, $markindex );
		my @marknames = sort $textwindow->markNames;
		for $mark (@marknames) {
			if ( $mark =~ /Pg(\S+)/ ) {
				my $num = $pagenumbers{$mark}{label};
				$num =~ s/Pg // if defined $num;
				$num = $1 unless $pagenumbers{$mark}{action};
				next unless length $num;
				$num =~ s/^0+(\d)/$1/;
				$markindex = $textwindow->index($mark);
				my $check =
				  $textwindow->get( $markindex . 'linestart',
									$markindex . 'linestart +4c' );
				if ( $check =~ /<h[12]>/ ) {
					$markindex = $textwindow->index("$mark-1l lineend")
					  ;    # FIXME: HTML page number hangs here
				}
				$textwindow->ntinsert(
					$markindex,
"<span class=\"pagenum\"><a name=\"Page_$num\" id=\"Page_$num\">[Pg $num]</a></span>"
				) if $lglobal{pageanch};

#$textwindow->ntinsert($markindex,"<span class="pagenum" id=\"Page_".$num."\">[Pg $num]</span>") if $lglobal{pageanch};
# FIXME: this is hanging up somewhere.
				$textwindow->ntinsert( $markindex,
									   '<!-- Page ' . $num . ' -->' )
				  if ( $lglobal{pagecmt} and $num );
				my $pstart =
				  $textwindow->search( '-backwards', '-exact', '--', '<p>',
									   $markindex, '1.0' )
				  || '1.0';
				my $pend =
				  $textwindow->search( '-backwards', '-exact', '--', '</p>',
									   $markindex, '1.0' )
				  || '1.0';
				my $sstart =
				  $textwindow->search( '-backwards', '-exact', '--', '<div ',
									   $markindex, '1.0' )
				  || '1.0';
				my $send =
				  $textwindow->search( '-backwards', '-exact', '--', '</div>',
									   $markindex, $pend )
				  || $pend;
				if ( $textwindow->compare( $pend, '>=', $pstart ) ) {
					$textwindow->ntinsert( $markindex, '<p>' )
					  unless ( $textwindow->compare( $send, '<', $sstart ) );
				}
				my $anchorend =
				  $textwindow->search( '-exact', '--', ']</a></span>',
									   $markindex, 'end' );
				$anchorend = $textwindow->index("$anchorend+12c");
				$pstart =
				  $textwindow->search( '-exact', '--', '<p>', $anchorend,
									   'end' )
				  || 'end';
				$pend =
				  $textwindow->search( '-exact', '--', '</p>', $anchorend,
									   'end' )
				  || 'end';
				$sstart =
				  $textwindow->search( '-exact', '--', '<div ', $anchorend,
									   'end' )
				  || 'end';
				$send =
				  $textwindow->search(
									   '-exact', '--',
									   '</div>', $anchorend,
									   $sstart
				  ) || $sstart;
				if ( $textwindow->compare( $pend, '>=', $pstart ) ) {
					$textwindow->ntinsert( $anchorend, '</p>' )
					  unless ( $textwindow->compare( $send, '<', $sstart ) );
				}
			}
		}
	}
	{
		local $" = '';
		$textwindow->insert(
			$incontents,
"\n\n<!-- Autogenerated TOC. Modify or delete as required. -->\n@contents\n<!-- End Autogenerated TOC. -->\n\n"
		) if @contents;
	}

	
}


1;


