package Guiguts::HTMLConvert;

BEGIN {
	use Exporter();
	use List::Util qw[min max];
	@ISA    = qw(Exporter);
	@EXPORT = qw(&htmlautoconvert &htmlpopup &makeanchor &autoindex);
}

use strict;
use warnings;

sub html_convert_tb {
	my ( $textwindow, $selection, $step ) = @_;
	no warnings;    # FIXME: Warning-- Exiting subroutine via next
	if ( $selection =~ s/\s{7}(\*\s{7}){4}\*/<hr class="tb" \/>/ ) {

		#if ($selection =~ s/\s{7}(\*\s{7}){4}\*/<hr style="width: 45%;" \/>/ ){
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
		next;
	}
	if ( $selection =~ s/<tb>/<hr class="tb" \/>/ ) {

		#if ( $selection =~ s/<tb>/<hr style="width: 45%;" \/>/ ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
		next;
	}
	return;
}

sub html_convert_subscripts {
	my ( $textwindow, $selection, $step ) = @_;
	if ( $selection =~ s/_\{([^}]+?)\}/<sub>$1<\/sub>/g ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
	}
	return;
}

# FIXME: Doesn't convert Gen^rl; workaround Gen^{rl}
sub html_convert_superscripts {
	my ( $textwindow, $selection, $step ) = @_;
	if ( $selection =~ s/\^\{([^}]+?)\}/<sup>$1<\/sup>/g ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
	}

  # Fixed a bug--did not handle the case without curly brackets, i.e., Philad^a.
	if ( $selection =~ s/\^(.)/<sup>$1<\/sup>/g ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
	}

	# handle <g>gesperrt text</g>
	if ( $selection =~ s/<g>(.*)<\/g>/<em class="gesperrt">$1<\/em>/g ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
	}
	return;
}

sub html_convert_ampersands {
	my $textwindow = shift;
	&main::working("Converting Ampersands");
	&main::named( '&(?![\w#])', '&amp;' );
	&main::named( '&$',         '&amp;' );
	&main::named( '& ',         '&amp; ' );
	&main::named( '&c\.',       '&amp;c.' );
	&main::named( '&c,',        '&amp;c.,' );
	&main::named( '&c ',        '&amp;c. ' );
	$textwindow->FindAndReplaceAll( '-regexp',                 '-nocase',
									"(?<![a-zA-Z0-9/\\-\"])>", "&gt;" );
	$textwindow->FindAndReplaceAll( '-regexp', '-nocase',
									"(?![\\n0-9])<(?![a-zA-Z0-9/\\-\\n])",
									'&lt;' );
	return;
}

# double hyphens go to character entity ref. FIXME: Add option for real emdash.
sub html_convert_emdashes {
	&main::working("Converting Emdashes");
	&main::named( '(?<=[^-!])--(?=[^>])', '&mdash;' );
	&main::named( '(?<=[^<])!--(?=[^>])', '!&mdash;' );
	&main::named( '(?<=[^-])--$',         '&mdash;' );
	&main::named( '^--(?=[^-])',          '&mdash;' );
	&main::named( '^--$',                 '&mdash;' );
	&main::named( "\x{A0}",               '&nbsp;' );
	return;
}

# convert latin1 and utf charactes to HTML Character Entity Reference's.
sub html_convert_latin1 {
	&main::working("Converting Latin-1 Characters...");
	for ( 128 .. 255 ) {
		my $from = lc sprintf( "%x", $_ );
		&main::named( '\x' . $from, &main::entity( '\x' . $from ) );
	}
	return;
}

sub html_convert_codepage {
	&main::working("Converting Windows Codepage 1252\ncharacters to Unicode");
	&main::cp1252toUni();
	return;
}

sub html_convert_utf {
	my ( $textwindow, $leave_utf, $keep_latin1 ) = @_;
	my $blockstart;
	if ($leave_utf) {
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
	unless ($leave_utf) {
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
	&main::working("Converting Named\n and Numeric Characters");
	&main::named( ' >', ' &gt;' )
	  ;    # see html_convert_ampersands -- probably no effect
	&main::named( '< ', '&lt; ' );
	if ( !$keep_latin1 ) { html_convert_latin1(); }
	return;
}

sub html_cleanup_markers {
	my ($textwindow) = @_;
	my $thisblockend;
	my $thisblockstart = '1.0';
	my $thisend        = q{};
	my ( $ler, $lec );
	&main::working("Cleaning up\nblock Markers");
	while ( $main::blockstart =
		   $textwindow->search( '-regexp', '--', '^\/[\*\$\#]', '1.0', 'end' ) )
	{
		( $main::xler, $main::xlec ) = split /\./, $main::blockstart;
		$main::blockend = "$main::xler.end";
		$textwindow->ntdelete( "$main::blockstart-1c", $main::blockend );
	}
	while ( $main::blockstart =
		   $textwindow->search( '-regexp', '--', '^[\*\$\#]\/', '1.0', 'end' ) )
	{
		( $main::xler, $main::xlec ) = split /\./, $main::blockstart;
		$main::blockend = "$main::xler.end";
		$textwindow->ntdelete( "$main::blockstart-1c", $main::blockend );
	}
	while ( $main::blockstart =
		 $textwindow->search( '-regexp', '--', '<\/h\d><br />', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( "$main::blockstart+5c", "$main::blockstart+9c" );
	}
	return;
}

sub html_convert_footnotes {
	my ( $textwindow, $fnarray ) = @_;
	my $thisblank = q{};
	my $step      = 0;
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
		last unless $fnarray->[$step][0];
		next unless $fnarray->[$step][3];
		$textwindow->ntdelete( 'fne' . "$step" . '-1c', 'fne' . "$step" );
		$textwindow->ntinsert( 'fne' . "$step", '</p></div>' );
		$textwindow->ntinsert(
							   (
								      'fns' . "$step" . '+'
									. ( length( $fnarray->[$step][4] ) + 11 )
									. "c"
							   ),
							   ']</span></a>'
		);
		$textwindow->ntdelete(
							   'fns' . "$step" . '+'
								 . ( length( $fnarray->[$step][4] ) + 10 )
								 . 'c',
							   "fns" . "$step" . '+'
								 . ( length( $fnarray->[$step][4] ) + 11 ) . 'c'
		);
		$textwindow->ntinsert(
							   'fns' . "$step" . '+10c',
							   "<div class=\"footnote\"><p><a name=\"Footnote_"
								 . $fnarray->[$step][4] . '_'
								 . $step
								 . "\" id=\"Footnote_"
								 . $fnarray->[$step][4] . '_'
								 . $step
								 . "\"></a><a href=\"#FNanchor_"
								 . $fnarray->[$step][4] . '_'
								 . $step
								 . "\"><span class=\"label\">["
		);
		$textwindow->ntdelete( 'fns' . "$step", 'fns' . "$step" . '+10c' );
		$textwindow->ntinsert( 'fnb' . "$step", '</a>' )
		  if ( $fnarray->[$step][3] );
		$textwindow->ntinsert(
							   'fna' . "$step",
							   "<a name=\"FNanchor_"
								 . $fnarray->[$step][4] . '_'
								 . $step
								 . "\" id=\"FNanchor_"
								 . $fnarray->[$step][4] . '_'
								 . $step
								 . "\"></a><a href=\"#Footnote_"
								 . $fnarray->[$step][4] . '_'
								 . $step
								 . "\" class=\"fnanchor\">"
		) if ( $fnarray->[$step][3] );

		while (
				$thisblank =
				$textwindow->search(
									 '-regexp', '--',
									 '^$',      'fns' . "$step",
									 "fne" . "$step"
				)
		  )
		{
			$textwindow->ntinsert( $thisblank, "</p>\n<p>" );
		}
	}
	return;
}

sub html_convert_body {
	my ( $textwindow, $headertext, $cssblockmarkup, $poetrynumbers, $classhash )
	  = @_;

#outline of subroutine: make a single pass through all lines $selection
# with the last four lines stored in @last5
# for a given line, convert subscripts, superscriptions and thought breaks for the line
# /x|/X gets <pre>
# and end tag gets </pre>
# in front matter /F enter close para two lines above if needed
# 	delete close front tag
# 	Now in the title; skip ahead
# 	no longer in title
# 	now in some other header than <h1>
# 	close para end of the last line before if the previous line does not already close
# if poetrynumbers, and line ends with two spaces and digits, create line number
# if end of poetry, delete two characters, insert closing </div></div>
# end of stanza
# if line ends spaces plus digits insert line number
#delete indent based on number of digits
# open poetry, if beginning x/ /p
#   close para if needed before open poetry
# in blockquote
#   close para if needed before open blockquote
# deal with block quotes
# deal with lists
# if nonblank followed by blank, insert close para after the nonblank  unless
#   it already has a closing tag (problematic one)
# at end of block, insert close para
# in a block, insert <br />
# four blank lines--start of chapter
# Sets a mark for the horizontal rule at the page marker rather than just before
# the header.
# make an anchor for autogenerate TOC
# insert chapter heading unless already a para or heading open
# bold face insertion into autogenerated TOC
#open subheading with <p>
#open with para if blank line then nonblank line
#open with para if blank line then two nonblank lines
#open with para if blank line then three nonblank lines
#
	&main::working('Converting Body');
	my @contents = ("\n");
	my $aname    = q{};
	my $author;
	my $blkquot = 0;
	my $cflag   = 0;
	my $front;

	#my $headertext;
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
	my @last5          = [ '1', '1', '1', '1', '1', '1' ];
	my $step           = 1;
	my ( $ler, $lec );
	$thisblockend = $textwindow->index('end');
	my ( $blkopen, $blkclose );

	if ($cssblockmarkup) {
		$blkopen  = '<div class="blockquot"><p>';
		$blkclose = '</p></div>';
	} else {
		$blkopen  = '<blockquote><p>';
		$blkclose = '</p></blockquote>';
	}

	#last line and column
	( $ler, $lec ) = split /\./, $thisblockend;

	#step through all the lines
	while ( $step <= $ler ) {
		unless ( $step % 500 ) {    #refresh window every 550 steps
			$textwindow->see("$step.0");
			$textwindow->update;
		}

		#with with one row (line) at a time
		$selection = $textwindow->get( "$step.0", "$step.end" );

		#flag--in table of contents
		$incontents = "$step.end"
		  if (    ( $step < 100 )
			   && ( $selection =~ /contents/i )
			   && ( $incontents eq '1.0' ) );
		html_convert_subscripts( $textwindow, $selection, $step );
		html_convert_superscripts( $textwindow, $selection, $step );
		html_convert_tb( $textwindow, $selection, $step );

		# /x|/X gets <pre>
		if ( $selection =~ m"^/x"i ) {
			$skip = 1;

			# delete the line
			$textwindow->ntdelete( "$step.0", "$step.end" );

			#insert <pre> instead
			$textwindow->insert( "$step.0", '<pre>' );

			# added this--was not getting close para before <pre>
			insert_paragraph_close( $textwindow, ( $step - 1 ) . '.end' )
			  if (    ( $last5[3] )
				   && ( $last5[3] !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) );
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
				  unless (
						   $textwindow->get( ( $step - 2 ) . '.0',
											 ( $step - 2 ) . '.end' ) =~ /<\/p>/
				  );
			}
			$step++;
			next;    #done with this row
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

		# skip the row after /X
		if ($skip) {
			$step++;
			next;
		}

		# in front matter /F enter close para two lines above if needed
		if ( $selection =~ m"^/f"i ) {
			$front = 1;
			$textwindow->ntdelete( "$step.0", "$step.end +1c" );
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
				  unless (
						   $textwindow->get( ( $step - 2 ) . '.0',
											 ( $step - 2 ) . '.end' ) =~ /<\/p>/
				  );
			}
			next;
		}
		if ($front) {

			# delete close front tag F/, replace with close para if needed
			if ( $selection =~ m"^f/"i ) {
				$front = 0;
				$textwindow->ntdelete( "$step.0", "$step.end" )
				  ;    #"$step.end +1c"
				insert_paragraph_close( $textwindow, $step . '.end' );
				$step++;
				next;
			}

			# Now in the title; skip ahead
			if ( ( $selection =~ /^<h1/ ) and ( not $selection =~ /<\/h1/ ) ) {
				$intitle = 1;
				push @last5, $selection;
				shift @last5 while ( scalar(@last5) > 4 );
				$step++;
				next;
			}

			# no longer in title
			if ( $selection =~ /<\/h1/ ) {
				$intitle = 0;
				push @last5, $selection;
				shift @last5 while ( scalar(@last5) > 4 );
				$step++;
				next;
			}

			# now in some other header than <h1>
			if ( $selection =~ /^<h/ ) {
				push @last5, $selection;
				shift @last5 while ( scalar(@last5) > 4 );
				$step++;
				next;
			}

# <p class="center"> if selection does not have /h, /d, <br>, </p>, or </div> (or last line closed markup)
#   print "int:$intitle:las:$last5[3]:sel:$selection\n";
			if (
				 (
				   length($selection) 
				   && (    ( !$last5[3] )
						or ( $last5[3] =~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) )
				   && ( $selection !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ )
				   && ( not $intitle )
				 )
			  )
			{
				$textwindow->ntinsert( "$step.0", '<p class="center">' );
			}

# close para end of the last line before if the previous line does not already close
			insert_paragraph_close( $textwindow, ( $step - 1 ) . '.end' )
			  if (   !( length($selection) )
				   && ( $last5[3] )
				   && ( $last5[3] !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}    # done with front matter

 #if poetrynumbers, and line ends with two spaces and digits, create line number
		if ( $poetrynumbers && ( $selection =~ s/\s\s(\d+)$// ) ) {
			$selection .= '<span class="linenum">' . $1 . '</span>';
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.0", $selection );
		}

		# if line begin x ? p/< (unclear, end of poetry)
		if ($poetry) {
			if ( $selection =~ /^\x7f*[pP]\/<?/ ) {
				$poetry    = 0;
				$selection = '</div></div>';

				#delete two characters, insert closing </div></div>
				$textwindow->ntdelete( "$step.0", "$step.0 +2c" );
				$textwindow->ntinsert( "$step.0", $selection );
				push @last5, $selection;
				shift @last5 while ( scalar(@last5) > 4 );
				$ital = 0;
				$step++;
				next;
			}

			# end of stanza
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

			# if line ends spaces plus digits insert line number
			if ( $selection =~
				 s/\s{2,}(\d+)\s*$/<span class="linenum">$1<\/span>/ )
			{
				$textwindow->ntdelete( "$step.0", "$step.end" );
				$textwindow->ntinsert( "$step.0", $selection );
			}
			my $indent = 0;

			#delete indent based on number of digits
			$indent = length($1) if $selection =~ s/^(\s+)//;
			$textwindow->ntdelete( "$step.0", "$step.$indent" ) if $indent;
			$indent -= 4;
			$indent = 0 if ( $indent < 0 );

			# something with italics, unclear
			my ( $op, $cl ) = ( 0, 0 );
			while ( ( my $temp = index $selection, '<i>', $op ) > 0 ) {
				$op = $temp + 3;
			}
			while ( ( my $temp = index $selection, '</i>', $cl ) > 0 ) {
				$cl = $temp + 4;
			}

			# close italics if needed
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

			# italics for poetry
			$classhash->{$indent} =
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

		# open poetry, if beginning x/ /p
		if ( $selection =~ /^\x7f*\/[pP]$/ ) {
			$poetry = 1;
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {

				# close para
				insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
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

		# in blockquote /#
		if ( $selection =~ /^\x7f*\/\#/ ) {
			$blkquot = 1;
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			$selection = $textwindow->get( "$step.0", "$step.end" );
			$selection =~ s/^\s+//;
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.0", $blkopen . $selection );

			# close para
			if ( ( $last5[1] ) && ( !$last5[2] ) ) {
				insert_paragraph_close( $textwindow, ( $step - 3 ) . ".end" )
				  unless (
						   $textwindow->get( ( $step - 3 ) . '.0',
											 ( $step - 2 ) . '.end' ) =~
						   /<\/?h\d?|<br.*?>|<\/p>|<\/div>/
				  );
			}

			# close para
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

		# list
		if ( $selection =~ /^\x7f*\/[Ll]/ ) {
			$listmark = 1;
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
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

		# close blockquote #/
		if ( $selection =~ /^\x7f*\#\// ) {
			$blkquot = 0;
			$textwindow->ntinsert( ( $step - 1 ) . '.end', $blkclose );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}

		#close list
		if ( $selection =~ /^\x7f*[Ll]\// ) {
			$listmark = 0;
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.end", '</ul>' );
			push @last5, '</ul>';
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}

		#in list
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

		# delete spaces
		if ($blkquot) {
			if ( $selection =~ s/^(\s+)// ) {
				my $space = length $1;
				$textwindow->ntdelete( "$step.0", "$step.0 +${space}c" );
			}
		}

		# close para at $/ or */
		if ( $selection =~ /^\x7f*[\$\*]\// ) {
			$inblock = 0;
			$ital    = 0;
			$textwindow->replacewith( "$step.0", "$step.end", '</p>' );
			$step++;
			next;
		}

		#insert close para, open para at /$ or /*
		if ( $selection =~ /^\x7f*\/[\$\*]/ ) {
			$inblock = 1;
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				insert_paragraph_close( $textwindow, ( $step - 2 ) . '.end' )
				  unless (
						   (
							 $textwindow->get( ( $step - 2 ) . '.0',
											   ( $step - 2 ) . '.end' ) =~
							 /<\/?[hd]\d?|<br.*?>|<\/p>/
						   )
				  );
			}

			#			$textwindow->replacewith( "$step.0", "$step.end", '<p>' );
			$textwindow->delete( "$step.0", "$step.end" );
			insert_paragraph_open( $textwindow, "$step.0" );
			$step++;
			next;
		}

		# if not in title or in block, close para
		if ( ( $last5[2] ) && ( !$last5[3] ) && ( not $intitle ) ) {
			insert_paragraph_close( $textwindow, ( $step - 2 ) . '.end' )
			  unless (
					   (
						 $textwindow->get( ( $step - 2 ) . '.0',
										   ( $step - 2 ) . '.end' ) =~
						 /<\/?[hd]\d?|<br.*?>|<\/p>|<\/[uo]l>/
					   )
					   || ($inblock)
			  );
		}

		# in block, insert <br />
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
				insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
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

		# four blank lines--start of chapter
		no warnings qw/uninitialized/;
		if (    ( !$last5[0] )
			 && ( !$last5[1] )
			 && ( !$last5[2] )
			 && ( !$last5[3] )
			 && ($selection) )
		{
			#Find the previous page marker
			my $hmark = $textwindow->markPrevious( ( $step  ) . '.0' );
			#print $hmark.":hmarkprevious\n";
			if ($hmark) {
				my $hmarkindex = $textwindow->index($hmark);
				my ( $pagemarkline, $pagemarkcol ) = split /\./, $hmarkindex;

# This sets a mark for the horizontal rule at the page marker rather than just before
# the header.
				if ( $step - 5 <= $pagemarkline ) {
					$textwindow->markSet( "HRULE$pagemarkline", $hmarkindex );
				}
			}

			# make an anchor for autogenerate TOC
			$aname =~ s/<\/?[hscalup].*?>//g;
			$aname = makeanchor( &main::deaccent($selection) );
			my $completeheader = $selection;

			# insert chapter heading unless already a para or heading open
			if ( not $selection =~ /<[ph]/ ) {
				$textwindow->ntinsert( "$step.0",
					  "<h2><a name=\"" . $aname . "\" id=\"" . $aname . "\">" );
				$step++;
				$selection = $textwindow->get( "$step.0", "$step.end" );
				my $restofheader = $selection;
				$restofheader =~ s/^\s+|\s+$//g;
				if ( length($restofheader) ) {
					$textwindow->ntinsert( "$step.end", '</a></h2>' );
					$completeheader .= ' ' . $restofheader;
				} else {
					$step--;
					$textwindow->ntinsert( "$step.end", '</a></h2>' );
				}
			}

			# bold face insertion into autogenerated TOC
			unless ( ( $selection =~ /<p/ ) or ( $selection =~ /<h1/ ) ) {
				$selection =~ s/<sup>.*?<\/sup>//g;
				$selection =~ s/<[^>]+>//g;
				$selection = "<b>$selection</b>";
				push @contents,
				    "<a href=\"#" 
				  . $aname . "\">"
				  . $completeheader
				  . "</a><br />\n";
			}
			$selection .= '<h2>';
			$textwindow->see("$step.0");
			$textwindow->update;

			#open subheading with <p>
		} elsif ( ( $last5[2] =~ /<h2>/ ) && ($selection) ) {
			$textwindow->ntinsert( "$step.0", '<p>' )
			  unless (    ( $selection =~ /<[pd]/ )
					   || ( $selection =~ /<[hb]r>/ )
					   || ($inblock) );

			#open with para if blank line then nonblank line
		} elsif ( ( $last5[2] ) && ( !$last5[3] ) && ($selection) ) {
			$textwindow->ntinsert( "$step.0", '<p>' )
			  unless (    ( $selection =~ /<[phd]/ )
					   || ( $selection =~ /<[hb]r>/ )
					   || ($inblock) );

			#open with para if blank line then two nonblank lines
		} elsif (    ( $last5[1] )
				  && ( !$last5[2] )
				  && ( !$last5[3] )
				  && ($selection) )
		{
			$textwindow->ntinsert( "$step.0", '<p>' )
			  unless (    ( $selection =~ /<[phd]/ )
					   || ( $selection =~ /<[hb]r>/ )
					   || ($inblock) );

			#open with para if blank line then three nonblank lines
		} elsif (    ( $last5[0] )
				  && ( !$last5[1] )
				  && ( !$last5[2] )
				  && ( !$last5[3] )
				  && ($selection) )
		{   #start of new paragraph unless line contains <p, <h, <d, <hr, or <br
			$textwindow->ntinsert( "$step.0", '<p>' )
			  unless (    ( $selection =~ /<[phd]/ )
					   || ( $selection =~ /<[hb]r>/ )
					   || ($inblock) );
		}
		push @last5, $selection;
		shift @last5 while ( scalar(@last5) > 4 );
		$step++;
	}

	# close the autogenerated TOC and insert at line called contents
	#push @contents, '</p>';
	local $" = '';
	my $contentstext =
"\n\n<!-- Autogenerated TOC. Modify or delete as required. -->\n@contents\n<!-- End Autogenerated TOC. -->\n\n";
	$contentstext = "<p>" . $contentstext . "</p>"
	  unless is_paragraph_open( $textwindow, $incontents );
	$textwindow->insert( $incontents, $contentstext ) if @contents;
	return;
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
	return;
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
	return;
}

sub html_convert_pageanchors {
	my ($textwindow) = @_;
	&main::working("Inserting Page Number Markup");
	$|++;
	my $markindex;
	my @pagerefs;   # keep track of first/last page markers at the same position
	my $tempcounter;
	my $mark = '1.0';
	while ( $textwindow->markPrevious($mark) ) {
		$mark = $textwindow->markPrevious($mark);
	}
	while ( $mark = $textwindow->markNext($mark) ) {

		#print "mark:$mark\n";
		if ( $mark =~ m{Pg(\S+)} ) {
			my $num = $main::pagenumbers{$mark}{label};
			$num =~ s/Pg // if defined $num;
			$num = $1 unless $main::pagenumbers{$mark}{action};
			next unless length $num;
			$num =~ s/^0+(\d)/$1/;
			$markindex = $textwindow->index($mark);
			my $check =
			  $textwindow->get( $markindex . 'linestart',
								$markindex . 'linestart +4c' );
			if ( $check =~ /<h[12]>/ ) {

				#$markindex = $textwindow->index("$mark-1l lineend");
			}
			my $pagereference;
			my $marknext = $textwindow->markNext($mark);
			my $marknextindex;
			while ($marknext) {
				if ( not $marknext =~ m{Pg(\S+)} ) {
					$marknext = $textwindow->markNext($marknext);
				} else {
					last;
				}
			}
			if ($marknext) {
				$marknextindex = $textwindow->index($marknext);
			} else {
				$marknextindex = 0;
			}
			if ( $markindex == $marknextindex ) {
				$pagereference = "";
				push @pagerefs, $num;
			} else {

				#multiple page reference in one spot
				push @pagerefs, $num;
				if (@pagerefs) {
					my $br = "";
					$pagereference = "";
					no warnings;    # roman numerals are nonnumeric
					for ( sort { $a <=> $b } @pagerefs ) {
						$pagereference .= "$br"
						  . "<a name=\"Page_$_\" id=\"Page_$_\">[Pg $_]</a>";
						$br = "<br />";
					}
					@pagerefs = ();
				} else {

					# just one page reference
					$pagereference =
					  "<a name=\"Page_$num\" id=\"Page_$num\">[Pg $num]</a>";
				}
			}

			# comment only
			$textwindow->ntinsert( $markindex, '<!-- Page ' . $num . ' -->' )
			  if ( $main::pagecmt and $num );

			#print $pagereference."3\n";
			if ($pagereference) {
				my $insertpoint = $markindex;
				my $inserted    = 0;

				# logic move page ref if at end of paragraph
				# TODO: move out of header, other markup
				my $nextpstart =
				  $textwindow->search( '--', '<p', $markindex, 'end' )
				  || 'end';
				my $nextpend =
				  $textwindow->search( '--', '</p>', $markindex, 'end' )
				  || 'end';
				my $inserttext =
				  "<span class=\"pagenum\">$pagereference</span>";
				if ( $textwindow->compare( $nextpend, '<=', $markindex . '+1c' )
				  )
				{

					#move page anchor from end of paragraph
					$insertpoint = $nextpend . '+4c';
					$inserttext  = '<p>' . $inserttext . '</p>';
				}
				my $pstart =
				  $textwindow->search( '-backwards', '-exact', '--', '<p',
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
									   $markindex, '1.0' )    #$pend
				  || '1.0';                                   #$pend
				   # if the previous <p> or <div>is not closed, then wrap in <p>
				if (
					 not( $textwindow->compare( $pend, '<', $pstart )
						  or ( $textwindow->compare( $send, '<', $sstart ) ) )
				  )
				{
					$inserttext = '<p>' . $inserttext . '</p>';
				}
				my $hstart =
				  $textwindow->search( '-backwards', '-exact', '--', '<h',
									   $markindex, '1.0' )
				  || '1.0';
				my $hend =
				  $textwindow->search( '-backwards', '-exact', '--', '</h',
									   $markindex, '1.0' )
				  || '1.0';
				if ( $textwindow->compare( $hend, '<', $hstart ) ) {
					$insertpoint = $textwindow->index("$hstart-1l lineend");
				}
				my $spanstart =
				  $textwindow->search( '-backwards', '-exact', '--', '<span',
									   $markindex, '1.0' )
				  || '1.0';
				my $spanend =
				  $textwindow->search( '-backwards', '-exact', '--', '</span',
									   $markindex, '1.0' )
				  || '1.0';
				if ( $textwindow->compare( $spanend, '<', $spanstart ) ) {
					$insertpoint = $spanend . '+7c';
				}
				$textwindow->ntinsert( $insertpoint, $inserttext )
				  if $main::lglobal{pageanch};
			}
		} else {
			if ( $mark =~ m{HRULE} )
			{    #place the <hr> for a chapter before the page number
				#print $mark. "xx\n";
				my $hrulemarkindex = $textwindow->index($mark);
				my $pgstart =
				  $textwindow->search( '--', '<p><span',
									   $hrulemarkindex . '-5c', 'end' )
				  || 'end';
				#print "hrule:$hrulemarkindex:pgstart:$pgstart\n";
				if (
					 $textwindow->compare(
										   $hrulemarkindex . '+100c',
										   '>', $pgstart
					 )
				  )
				{
					$textwindow->ntinsert( $pgstart, '<hr class="chap" />' );
				}
			}
		}
	}
	return;
}

sub html_parse_header {
	my ( $textwindow, $headertext ) = @_;
	my $selection;
	my $step;
	my $title;
	my $author;
	&main::working('Parsing Header');
	$selection = $textwindow->get( '1.0', '1.end' );
	if ( $selection =~ /DOCTYPE/ ) {
		$step = 1;
		while (1) {
			$selection = $textwindow->get( "$step.0", "$step.end" );
			$headertext .= ( $selection . "\n" );
			$textwindow->ntdelete( "$step.0", "$step.end" );
			last if ( $selection =~ /^\<body/ );
			$step++;
			last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
		}
		$textwindow->ntdelete( '1.0', "$step.0 +1c" );
	} else {
		unless ( -e 'header.txt' ) {
			&main::copy( 'headerdefault.txt', 'header.txt' );
		}
		open my $infile, '<', 'header.txt'
		  or warn "Could not open header file. $!\n";
		while (<$infile>) {
			$_ =~ s/\cM\cJ|\cM|\cJ/\n/g;

			# FIXME: $_ = eol_convert($_);
			$headertext .= $_;
		}
		close $infile;
	}
	$step = 0;
	my $completetitle = '';
	my $intitle       = 0;
	while (1) {
		$step++;
		last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
		$selection = $textwindow->get( "$step.0", "$step.end" );
		next if ( $selection =~ /^\[Illustr/i );    # Skip Illustrations
		next if ( $selection =~ /^\/[\$fx]/i );     # Skip /$|/F tags
		if (     ($intitle)
			 and ( ( not length($selection) or ( $selection =~ /^f\//i ) ) ) )
		{
			$step--;
			$textwindow->ntinsert( "$step.end", '</h1>' );
			last;
		}                                           #done finding title
		next if ( $selection =~ /^\/[\$fx]/i );     # Skip /$|/F tags
		next unless length($selection);
		$title = $selection;
		$title =~ s/[,.]$//;                        #throw away trailing , or .
		$title = lc($title);                        #lowercase title
		$title =~ s/(^\W*\w)/\U$1\E/;
		$title =~ s/([\s\n]+\W*\w)/\U$1\E/g;
		$title =~ s/^\s+|\s+$//g;
		$title =~ s/<[^>]*>//g;

		if ( $intitle == 0 ) {
			$textwindow->ntinsert( "$step.0", '<h1>' );
			$completetitle = $title;
			$intitle       = 1;
		} else {
			if ( ( $title =~ /^by/i ) or ( $title =~ /\Wby\s/i ) ) {
				$step--;
				$textwindow->ntinsert( "$step.end", '</h1>' );
				last;
			}
			$completetitle .= ' ' . $title;
		}
	}
	if ($completetitle) {
		$headertext =~ s/TITLE/$completetitle/;
	}
	while (1) {
		$step++;
		last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
		$selection = $textwindow->get( "$step.0", "$step.end" );
		if ( ( $selection =~ /^by/i ) and ( $step < 100 ) ) {
			last if ( $selection =~ /[\/[Ff]/ );
			if ( $selection =~ /^by$/i ) {
				$selection = '<h3>' . $selection . '</h3>';
				$textwindow->ntdelete( "$step.0", "$step.end" );
				$textwindow->ntinsert( "$step.0", $selection );
				do {
					$step++;
					$selection = $textwindow->get( "$step.0", "$step.end" );
				} until ( $selection ne "" );
				$author = $selection;
				$author =~ s/,$//;
			} else {
				$author = $selection;
				$author =~ s/\s$//i;
			}
		}

		#		Dropped this--not an accurate way to find the author
		#		$selection = '<h2>' . $selection . '</h2>' if $author;
		#		$textwindow->ntdelete( "$step.0", "$step.end" );
		#		$textwindow->ntinsert( "$step.0", $selection );
		last if $author || ( $step > 100 );
	}
	if ($author) {
		$author =~ s/^by //i;
		$author = ucfirst( lc($author) );
		$author     =~ s/(\W)(\w)/$1\U$2\E/g;
		$headertext =~ s/AUTHOR/$author/;
	}
	return $headertext;
}

sub html_wrapup {
	my ( $textwindow, $headertext, $leave_utf, $autofraction, $classhash ) = @_;
	my $thisblockstart;
	&main::fracconv( $textwindow, '1.0', 'end' ) if $autofraction;
	$textwindow->ntinsert( '1.0', $headertext );
	if ($leave_utf) {
		$thisblockstart =
		  $textwindow->search(
							   '-exact',             '--',
							   'charset=iso-8859-1', '1.0',
							   'end'
		  );
		if ($thisblockstart) {
			$textwindow->ntdelete( $thisblockstart, "$thisblockstart+18c" );
			$textwindow->ntinsert( $thisblockstart, 'charset=utf-8' );
		}
	}
	insert_paragraph_close( $textwindow, 'end' );
	$textwindow->ntinsert( 'end', "\n<\/body>\n<\/html>" );
	$thisblockstart = $textwindow->search( '--', '</style', '1.0', '250.0' );
	$thisblockstart = '75.0' unless $thisblockstart;
	$thisblockstart =
	  $textwindow->search( -backwards, '--', '}', $thisblockstart, '10.0' );
	for ( reverse( sort( values( %{$classhash} ) ) ) ) {
		$textwindow->ntinsert( $thisblockstart . ' +1l linestart', $_ )
		  if keys %{$classhash};
	}
	%{$classhash} = ();
	&main::working();
	$textwindow->Unbusy;
	$textwindow->see('1.0');
	return;
}

# insert </p> only if there is an open <p> tag
sub insert_paragraph_close {
	my ( $textwindow, $index ) = @_;
	if ( is_paragraph_open( $textwindow, $index ) ) {
		$textwindow->ntinsert( $index, '</p>' );
		return 1;
	}
	return 0;
}

sub is_paragraph_open {
	my ( $textwindow, $index ) = @_;
	my $pstart =
	  $textwindow->search( '-backwards', '-regexp', '--', '<p(>| )', $index,
						   '1.0' )
	  || '1.0';
	my $pend = $textwindow->search( '-backwards', '--', '</p>', $index, '1.0' )
	  || '1.0';
	if ( $textwindow->compare( $pend, '<', $pstart ) ) {
		return 1;
	}
	return 0;
}

# insert <p> only if there is not an open <p> tag
sub insert_paragraph_open {
	my ( $textwindow, $index ) = @_;
	if ( not is_paragraph_open( $textwindow, $index ) ) {
		$textwindow->ntinsert( $index, '<p>' );
		return 1;
	}
	return 0;
}

sub htmlimage {
	my ( $textwindow, $top, $thisblockstart, $thisblockend ) = @_;
	$thisblockstart = 'insert'        unless $thisblockstart;
	$thisblockend   = $thisblockstart unless $thisblockend;
	$textwindow->markSet( 'thisblockstart', $thisblockstart );
	$textwindow->markSet( 'thisblockend',   $thisblockend );
	my $selection;
	$selection = $textwindow->get( $thisblockstart, $thisblockend ) if @_;
	$selection = '' unless $selection;
	my $preservep = '';
	$preservep = '<p>' if $selection !~ /<\/p>$/;
	$selection =~ s/<p>\[Illustration:/[Illustration:/;
	$selection =~ s/\[Illustration:?\s*(\.*)/$1/;
	$selection =~ s/\]<\/p>$/]/;
	$selection =~ s/(\.*)\]$/$1/;
	my ( $fname, $extension );
	my $xpad = 0;
	$main::globalimagepath = $main::globallastpath
	  unless $main::globalimagepath;
	my ($alignment);
	$main::lglobal{htmlorig}  = $top->Photo;
	$main::lglobal{htmlthumb} = $top->Photo;

	if ( defined( $main::lglobal{htmlimpop} ) ) {
		$main::lglobal{htmlimpop}->deiconify;
		$main::lglobal{htmlimpop}->raise;
		$main::lglobal{htmlimpop}->focus;
	} else {
		$main::lglobal{htmlimpop} = $top->Toplevel;
		$main::lglobal{htmlimpop}->title('Image');
		&main::initialize_popup_without_deletebinding('htmlimpop');
		my $f1 =
		  $main::lglobal{htmlimpop}->LabFrame( -label => 'File Name' )
		  ->pack( -side => 'top', -anchor => 'n', -padx => 2 );
		$main::lglobal{imgname} =
		  $f1->Entry( -width => 45, )->pack( -side => 'left' );
		my $f3 =
		  $main::lglobal{htmlimpop}->LabFrame( -label => 'Alt text' )
		  ->pack( -side => 'top', -anchor => 'n' );
		$main::lglobal{alttext} =
		  $f3->Entry( -width => 45, )->pack( -side => 'left' );
		my $f4a =
		  $main::lglobal{htmlimpop}->LabFrame( -label => 'Caption text' )
		  ->pack( -side => 'top', -anchor => 'n' );
		$main::lglobal{captiontext} =
		  $f4a->Entry( -width => 45, )->pack( -side => 'left' );
		my $f4 =
		  $main::lglobal{htmlimpop}->LabFrame( -label => 'Title text' )
		  ->pack( -side => 'top', -anchor => 'n' );
		$main::lglobal{titltext} =
		  $f4->Entry( -width => 45, )->pack( -side => 'left' );
		my $f5 =
		  $main::lglobal{htmlimpop}->LabFrame( -label => 'Geometry' )
		  ->pack( -side => 'top', -anchor => 'n' );
		my $f51 = $f5->Frame->pack( -side => 'top', -anchor => 'n' );
		$f51->Label( -text => 'Width' )->pack( -side => 'left' );
		$main::lglobal{widthent} = $f51->Entry(
			-width    => 10,
			-validate => 'all',
			-vcmd     => sub {
				return 1 if ( !$main::lglobal{ImageSize} );
				return 1 unless $main::lglobal{htmlimgar};
				return 1 unless ( $_[0] && $_[2] );
				return 0 unless ( defined $_[1] && $_[1] =~ /\d/ );
				my ( $sizex, $sizey ) =
				  Image::Size::imgsize( $main::lglobal{imgname}->get );
				$main::lglobal{heightent}->delete( 0, 'end' );
				$main::lglobal{heightent}
				  ->insert( 'end', ( int( $sizey * ( $_[0] / $sizex ) ) ) );
				return 1;
			}
		)->pack( -side => 'left' );
		$f51->Label( -text => 'Height' )->pack( -side => 'left' );
		$main::lglobal{heightent} = $f51->Entry(
			-width    => 10,
			-validate => 'all',
			-vcmd     => sub {
				return 1 if ( !$main::lglobal{ImageSize} );
				return 1 unless $main::lglobal{htmlimgar};
				return 1 unless ( $_[0] && $_[2] );
				return 0 unless ( defined $_[1] && $_[1] =~ /\d/ );
				my ( $sizex, $sizey ) =
				  Image::Size::imgsize( $main::lglobal{imgname}->get );
				$main::lglobal{widthent}->delete( 0, 'end' );
				$main::lglobal{widthent}
				  ->insert( 'end', ( int( $sizex * ( $_[0] / $sizey ) ) ) );
				return 1;
			}
		)->pack( -side => 'left' );
		my $ar = $f51->Checkbutton(
									-text     => 'Maintain AR',
									-variable => \$main::lglobal{htmlimgar},
									-onvalue  => 1,
									-offvalue => 0
		)->pack( -side => 'left' );
		$ar->select;
		my $f52 = $f5->Frame->pack( -side => 'top', -anchor => 'n' );
		$main::lglobal{htmlimggeom} =
		  $f52->Label( -text => '' )->pack( -side => 'left' );
		my $f2 =
		  $main::lglobal{htmlimpop}->LabFrame( -label => 'Alignment' )
		  ->pack( -side => 'top', -anchor => 'n' );
		$f2->Radiobutton(
						  -variable    => \$alignment,
						  -text        => 'Left',
						  -selectcolor => $main::lglobal{checkcolor},
						  -value       => 'left',
		)->grid( -row => 1, -column => 1 );
		my $censel = $f2->Radiobutton(
									 -variable    => \$alignment,
									 -text        => 'Center',
									 -selectcolor => $main::lglobal{checkcolor},
									 -value       => 'center',
		)->grid( -row => 1, -column => 2 );
		$f2->Radiobutton(
						  -variable    => \$alignment,
						  -text        => 'Right',
						  -selectcolor => $main::lglobal{checkcolor},
						  -value       => 'right',
		)->grid( -row => 1, -column => 3 );
		$censel->select;
		my $f8 =
		  $main::lglobal{htmlimpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n' );
		$f8->Button(
			-text    => 'Ok',
			-width   => 10,
			-command => sub {
				my $name = $main::lglobal{imgname}->get;
				if ($name) {
					my $sizexy =
					    'width="'
					  . $main::lglobal{widthent}->get
					  . '" height="'
					  . $main::lglobal{heightent}->get . '"';
					my $width = $main::lglobal{widthent}->get;
					return unless $name;
					( $fname, $main::globalimagepath, $extension ) =
					  &main::fileparse($name);
					$main::globalimagepath =
					  &main::os_normal($main::globalimagepath);
					$name =~ s/[\/\\]/\;/g;
					my $tempname = $main::globallastpath;
					$tempname =~ s/[\/\\]/\;/g;
					$name     =~ s/$tempname//;
					$name     =~ s/;/\//g;
					$alignment = 'center' unless $alignment;
					$selection = $main::lglobal{captiontext}->get;
					$selection ||= '';
					$selection =~ s/"/&quot;/g;
					$selection =~ s/'/&#39;/g;
					my $alt = $main::lglobal{alttext}->get;
					$alt       = " alt=\"$alt\"";
					$selection = "<span class=\"caption\">$selection</span>\n"
					  if $selection;
					$preservep = '' unless $selection;
					my $title = $main::lglobal{titltext}->get || '';
					$title =~ s/"/&quot;/g;
					$title =~ s/'/&#39;/g;
					$title = " title=\"$title\"" if $title;
					$textwindow->addGlobStart;
					my $closeimg =
"px;\">\n<img src=\"$name\" $sizexy$alt$title />\n$selection</div>$preservep";

					if ( $alignment eq 'center' ) {
						$textwindow->delete( 'thisblockstart', 'thisblockend' );
						$textwindow->insert( 'thisblockstart',
									 "<div class=\"figcenter\" style=\"width: " 
									   . $width
									   . $closeimg );
					} elsif ( $alignment eq 'left' ) {
						$textwindow->delete( 'thisblockstart', 'thisblockend' );
						$textwindow->insert( 'thisblockstart',
									   "<div class=\"figleft\" style=\"width: " 
										 . $width
										 . $closeimg );
					} elsif ( $alignment eq 'right' ) {
						$textwindow->delete( 'thisblockstart', 'thisblockend' );
						$textwindow->insert( 'thisblockstart',
									  "<div class=\"figright\" style=\"width: " 
										. $width
										. $closeimg );
					}
					$textwindow->addGlobEnd;
					$main::lglobal{htmlthumb}->delete
					  if $main::lglobal{htmlthumb};
					$main::lglobal{htmlthumb}->destroy
					  if $main::lglobal{htmlthumb};
					$main::lglobal{htmlorig}->delete
					  if $main::lglobal{htmlorig};
					$main::lglobal{htmlorig}->destroy
					  if $main::lglobal{htmlorig};
					for (
						  $main::lglobal{alttext},  $main::lglobal{titltext},
						  $main::lglobal{widthent}, $main::lglobal{heightent},
						  $main::lglobal{imagelbl}, $main::lglobal{imgname}
					  )
					{
						$_->destroy;
					}
					$textwindow->tagRemove( 'highlight', '1.0', 'end' );
					$main::lglobal{htmlimpop}->destroy
					  if $main::lglobal{htmlimpop};
					undef $main::lglobal{htmlimpop}
					  if $main::lglobal{htmlimpop};
				}
			}
		)->pack;
		my $f = $main::lglobal{htmlimpop}->Frame->pack;
		$main::lglobal{imagelbl} =
		  $f->Label(
					 -text       => 'Thumbnail',
					 -justify    => 'center',
					 -background => $main::bkgcolor,
		  )->grid( -row => 1, -column => 1 );
		$main::lglobal{imagelbl}
		  ->bind( $main::lglobal{imagelbl}, '<1>', \&thumbnailbrowse );
		$main::lglobal{htmlimpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$main::lglobal{htmlthumb}->delete  if $main::lglobal{htmlthumb};
				$main::lglobal{htmlthumb}->destroy if $main::lglobal{htmlthumb};
				$main::lglobal{htmlorig}->delete   if $main::lglobal{htmlorig};
				$main::lglobal{htmlorig}->destroy  if $main::lglobal{htmlorig};
				for (
					  $main::lglobal{alttext},  $main::lglobal{titltext},
					  $main::lglobal{widthent}, $main::lglobal{heightent},
					  $main::lglobal{imagelbl}, $main::lglobal{imgname}
				  )
				{
					$_->destroy;
				}
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
				$main::lglobal{htmlimpop}->destroy;
				undef $main::lglobal{htmlimpop};
			}
		);
		$main::lglobal{htmlimpop}->transient($top);
	}
	$main::lglobal{alttext}->delete( 0, 'end' ) if $main::lglobal{alttext};
	$main::lglobal{titltext}->delete( 0, 'end' ) if $main::lglobal{titltext};
	$main::lglobal{captiontext}->insert( 'end', $selection );
	&thumbnailbrowse();
}

sub htmlimages {
	my ( $textwindow, $top ) = @_;
	my $length;
	my $start =
	  $textwindow->search(
						   '-regexp',              '--',
						   '(<p>)?\[Illustration', '1.0',
						   'end'
	  );
	return unless $start;
	$textwindow->see($start);
	my $end = $textwindow->search(
								   '-regexp',
								   '-count' => \$length,
								   '--', '\](<\/p>)?', $start, 'end'
	);
	$end = $textwindow->index( $end . ' +' . $length . 'c' );
	return unless $end;
	$textwindow->tagAdd( 'highlight', $start, $end );
	$textwindow->markSet( 'insert', $start );
	&main::update_indicators();
	htmlimage( $textwindow, $top, $start, $end );
}

sub htmlautoconvert {
	my ( $textwindow, $top ) = @_;
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	my $headertext;
	if ( $main::lglobal{global_filename} =~ /No File Loaded/ ) {
		$top->messageBox(
						  -icon    => 'warning',
						  -type    => 'OK',
						  -message => 'File must be saved first.'
		);
		return;
	}

	# Backup file
	$textwindow->Busy;
	my $savefn = $main::lglobal{global_filename};
	$main::lglobal{global_filename} =~ s/\.[^\.]*?$//;
	my $newfn = $main::lglobal{global_filename} . '-htmlbak.txt';
	&main::working("Saving backup of file\nto $newfn");
	$textwindow->SaveUTF($newfn);
	$main::lglobal{global_filename} = $newfn;
	&main::_bin_save( $textwindow, $top );
	$main::lglobal{global_filename} = $savefn;
	$textwindow->FileName($savefn);
	html_convert_codepage();
	html_convert_ampersands($textwindow);
	$headertext = html_parse_header( $textwindow, $headertext );
	html_convert_emdashes();
	$main::lglobal{fnsecondpass}  = 0;
	$main::lglobal{fnsearchlimit} = 1;
	html_convert_footnotes( $textwindow, $main::lglobal{fnarray} );
	html_convert_body(
					   $textwindow,
					   $headertext,
					   $main::lglobal{cssblockmarkup},
					   $main::lglobal{poetrynumbers},
					   $main::lglobal{classhash}
	);
	html_cleanup_markers($textwindow);
	html_convert_underscoresmallcaps($textwindow);
	html_convert_sidenotes($textwindow);
	html_convert_pageanchors( $textwindow, $main::lglobal{pageanch},
							  $main::lglobal{pagecmt} );
	html_convert_utf( $textwindow,
					  $main::lglobal{leave_utf},
					  $main::lglobal{keep_latin1} );
	html_wrapup( $textwindow, $headertext,
				 $main::lglobal{leave_utf},
				 $main::lglobal{autofraction},
				 $main::lglobal{classhash} );
	$textwindow->ResetUndo;
}

sub thumbnailbrowse {
	my $types =
	  [ [ 'Image Files', [ '.gif', '.jpg', '.png' ] ], [ 'All Files', ['*'] ],
	  ];
	my $name =
	  $main::lglobal{htmlimpop}->getOpenFile(
										   -filetypes  => $types,
										   -title      => 'File Load',
										   -initialdir => $main::globalimagepath
	  );
	return unless ($name);
	my $xythumb = 200;
	if ( $main::lglobal{ImageSize} ) {
		my ( $sizex, $sizey ) = Image::Size::imgsize($name);
		$main::lglobal{widthent}->delete( 0, 'end' );
		$main::lglobal{heightent}->delete( 0, 'end' );
		$main::lglobal{widthent}->insert( 'end', $sizex );
		$main::lglobal{heightent}->insert( 'end', $sizey );
		$main::lglobal{htmlimggeom}
		  ->configure( -text => "Actual image size: $sizex x $sizey pixels" );
	} else {
		$main::lglobal{htmlimggeom}
		  ->configure( -text => "Actual image size: unknown" );
	}
	$main::lglobal{htmlorig}->blank;
	$main::lglobal{htmlthumb}->blank;
	$main::lglobal{imgname}->delete( '0', 'end' );
	$main::lglobal{imgname}->insert( 'end', $name );
	my ( $fn, $ext );
	( $fn, $main::globalimagepath, $ext ) = fileparse( $name, '(?<=\.)[^\.]*$' );
	$main::globalimagepath = os_normal($main::globalimagepath);
	$ext =~ s/jpg/jpeg/;

	if ( lc($ext) eq 'gif' ) {
		$main::lglobal{htmlorig}->read( $name, -shrink );
	} else {
		$main::lglobal{htmlorig}->read( $name, -format => $ext, -shrink );
	}
	my $sw = int( ( $main::lglobal{htmlorig}->width ) / $xythumb );
	my $sh = int( ( $main::lglobal{htmlorig}->height ) / $xythumb );
	if ( $sh > $sw ) {
		$sw = $sh;
	}
	if ( $sw < 2 ) { $sw += 1 }
	$main::lglobal{htmlthumb}
	  ->copy( $main::lglobal{htmlorig}, -subsample => ($sw), -shrink )
	  ;    #hkm changed textcopy to copy
	$main::lglobal{imagelbl}->configure(
										 -image   => $main::lglobal{htmlthumb},
										 -text    => 'Thumbnail',
										 -justify => 'center',
	);
}

sub htmlpopup {
	my ( $textwindow, $top ) = @_;
	push @main::operations, ( localtime() . ' - HTML Markup' );
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	if ( defined( $main::lglobal{markpop} ) ) {
		$main::lglobal{markpop}->deiconify;
		$main::lglobal{markpop}->raise;
		$main::lglobal{markpop}->focus;
	} else {
		my $blockmarkup;
		$main::lglobal{markpop} = $top->Toplevel;
		$main::lglobal{markpop}->title('HTML Markup');
		my $tableformat;
		my $f0 =
		  $main::lglobal{markpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n' );
		$f0->Button(
					 -activebackground => $main::activecolor,
					 -command => sub { htmlautoconvert( $textwindow, $top ) },
					 -text    => 'Autogenerate HTML',
					 -width   => 16
		)->grid( -row => 1, -column => 1, -padx => 1, -pady => 1 );
		$f0->Button(
					 -text    => 'Custom Page Labels',
					 -command => sub { pageadjust() },
		)->grid( -row => 1, -column => 2, -padx => 1, -pady => 1 );
		$f0->Button(
					 -activebackground => $main::activecolor,
					 -command => sub { htmlimages( $textwindow, $top ); },
					 -text    => 'Auto Illus Search',
					 -width   => 16,
		)->grid( -row => 1, -column => 3, -padx => 1, -pady => 1 );
		$f0->Button(    #hkm added
			-activebackground => $main::activecolor,
			-command          => sub {
				&main::runner( &main::cmdinterp("$main::extops[0]{command}") );
			},
			-text  => 'View in Browser',
			-width => 16,
		)->grid( -row => 1, -column => 4, -padx => 1, -pady => 1 );
		my $pagecomments =
		  $f0->Checkbutton(
							-variable    => \$main::lglobal{pagecmt},
							-selectcolor => $main::lglobal{checkcolor},
							-text        => 'Pg #s as comments',
							-anchor      => 'w',
		  )->grid(
				   -row    => 2,
				   -column => 1,
				   -padx   => 1,
				   -pady   => 2,
				   -sticky => 'w'
		  );
		my $pageanchors =
		  $f0->Checkbutton(
							-variable    => \$main::lglobal{pageanch},
							-selectcolor => $main::lglobal{checkcolor},
							-text        => 'Insert Anchors at Pg #s',
							-anchor      => 'w',
		  )->grid(
				   -row    => 2,
				   -column => 2,
				   -padx   => 1,
				   -pady   => 2,
				   -sticky => 'w'
		  );
		$pageanchors->select;
		my $fractions =
		  $f0->Checkbutton(
							-variable    => \$main::lglobal{autofraction},
							-selectcolor => $main::lglobal{checkcolor},
							-text        => 'Convert Fractions',
							-anchor      => 'w',
		  )->grid(
				   -row    => 2,
				   -column => 3,
				   -padx   => 1,
				   -pady   => 2,
				   -sticky => 'w'
		  );
		my $utfconvert =
		  $f0->Checkbutton(
							-variable    => \$main::lglobal{leave_utf},
							-selectcolor => $main::lglobal{checkcolor},
							-text        => 'Keep UTF-8 Chars',
							-anchor      => 'w',
		  )->grid(
				   -row    => 3,
				   -column => 1,
				   -padx   => 1,
				   -pady   => 2,
				   -sticky => 'w'
		  );
		my $latin1_convert =
		  $f0->Checkbutton(
							-variable    => \$main::lglobal{keep_latin1},
							-selectcolor => $main::lglobal{checkcolor},
							-text        => 'Keep Latin-1 Chars',
							-anchor      => 'w',
		  )->grid(
				   -row    => 3,
				   -column => 2,
				   -padx   => 1,
				   -pady   => 2,
				   -sticky => 'w'
		  );
		$blockmarkup = $f0->Checkbutton(
			-variable    => \$main::lglobal{cssblockmarkup},
			-selectcolor => $main::lglobal{checkcolor},
			-command     => sub {
				if ( $main::lglobal{cssblockmarkup} ) {
					$blockmarkup->configure( '-text' => 'CSS blockquote' );
				} else {
					$blockmarkup->configure( '-text' => 'Std. <blockquote>' );
				}
			},
			-text   => 'CSS blockquote',
			-anchor => 'w',
		  )->grid(
				   -row    => 3,
				   -column => 3,
				   -padx   => 1,
				   -pady   => 2,
				   -sticky => 'w'
		  );
		my $f1 =
		  $main::lglobal{markpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n' );
		my ( $inc, $row, $col ) = ( 0, 0, 0 );

	   # Warning: if you add tags to the list below move nbsp and poetry buttons
		for (
			qw/i b h1 h2 h3 h4 h5 h6 p hr br big small ol ul li sup sub table tr td blockquote code /
		  )
		{
			$col = $inc % 5;
			$row = int $inc / 5;
			$f1->Button(
				-activebackground => $main::activecolor,
				-command          => [
					sub {
						markup( $textwindow, $top, $_[0] );
					},
					$_
				],
				-text  => "<$_>",
				-width => 10
			  )->grid(
					   -row    => $row,
					   -column => $col,
					   -padx   => 1,
					   -pady   => 2
			  );
			++$inc;
		}
		$f1->Button(
					 -activebackground => $main::activecolor,
					 -command => sub { markup( $textwindow, $top, '&nbsp;' ) },
					 -text    => 'nb space',
					 -width   => 10
		)->grid( -row => 4, -column => 3, -padx => 1, -pady => 2 );
		$f1->Button(
					 -activebackground => $main::activecolor,
					 -command          => \&main::poetryhtml,
					 -text             => 'Poetry',
					 -width            => 10
		)->grid( -row => 4, -column => 4, -padx => 1, -pady => 2 );
		my $f2 =
		  $main::lglobal{markpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n' );
		my %hbuttons = (
						 'anchor', 'Named anchor',  'img',   'Image',
						 'elink',  'External Link', 'ilink', 'Internal Link'
		);
		( $row, $col ) = ( 0, 0 );
		for ( keys %hbuttons ) {
			$f2->Button(
				-activebackground => $main::activecolor,
				-command          => [
					sub {
						markup( $textwindow, $top, $_[0] );
					},
					$_
				],
				-text  => "$hbuttons{$_}",
				-width => 13
			  )->grid(
					   -row    => $row,
					   -column => $col,
					   -padx   => 1,
					   -pady   => 2
			  );
			++$col;
		}
		my $f3 =
		  $main::lglobal{markpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n' );
		$f3->Button(
					 -activebackground => $main::activecolor,
					 -command => sub { markup( $textwindow, $top, 'del' ) },
					 -text    => 'Remove markup from selection',
					 -width   => 28
		)->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		$f3->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				for my $orphan (
								 'b',   'i',   'center', 'u',
								 'sub', 'sup', 'sc',     'h1',
								 'h2',  'h3',  'h4',     'h5',
								 'h6',  'p',   'span'
				  )
				{
					&main::working( 'Checking <' . $orphan . '>' );
					last if &main::orphans($orphan);
				}
				&main::working();
			},
			-text  => 'Find orphaned markup',
			-width => 28
		)->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
		my $f4 =
		  $main::lglobal{markpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n' );
		my $unorderselect =
		  $f4->Radiobutton(
							-text        => 'unordered',
							-selectcolor => $main::lglobal{checkcolor},
							-variable    => \$main::lglobal{liststyle},
							-value       => 'ul',
		  )->grid( -row => 1, -column => 1 );
		my $orderselect =
		  $f4->Radiobutton(
							-text        => 'ordered',
							-selectcolor => $main::lglobal{checkcolor},
							-variable    => \$main::lglobal{liststyle},
							-value       => 'ol',
		  )->grid( -row => 1, -column => 2 );
		my $autolbutton =
		  $f4->Button(
				  -activebackground => $main::activecolor,
				  -command => sub { autolist($textwindow); $textwindow->focus },
				  -text    => 'Auto List',
				  -width   => 16
		  )->grid( -row => 1, -column => 4, -padx => 1, -pady => 2 );
		$f4->Checkbutton(
						  -text     => 'ML',
						  -variable => \$main::lglobal{list_multiline},
						  -onvalue  => 1,
						  -offvalue => 0
		)->grid( -row => 1, -column => 5 );
		my $leftselect =
		  $f4->Radiobutton(
							-text        => 'left',
							-selectcolor => $main::lglobal{checkcolor},
							-variable    => \$main::lglobal{tablecellalign},
							-value       => ' align="left"',
		  )->grid( -row => 2, -column => 1 );
		my $censelect =
		  $f4->Radiobutton(
							-text        => 'center',
							-selectcolor => $main::lglobal{checkcolor},
							-variable    => \$main::lglobal{tablecellalign},
							-value       => ' align="center"',
		  )->grid( -row => 2, -column => 2 );
		my $rghtselect =
		  $f4->Radiobutton(
							-text        => 'right',
							-selectcolor => $main::lglobal{checkcolor},
							-variable    => \$main::lglobal{tablecellalign},
							-value       => ' align="right"',
		  )->grid( -row => 2, -column => 3 );
		$leftselect->select;
		$unorderselect->select;
		$f4->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				autotable( $textwindow, $tableformat->get );
				$textwindow->focus;
			},
			-text  => 'Auto Table',
			-width => 16
		)->grid( -row => 2, -column => 4, -padx => 1, -pady => 2 );
		$f4->Checkbutton(
						  -text     => 'ML',
						  -variable => \$main::lglobal{tbl_multiline},
						  -onvalue  => 1,
						  -offvalue => 0
		)->grid( -row => 2, -column => 5 );
		my $f5 =
		  $main::lglobal{markpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n' );
		$tableformat = $f5->Entry(
								   -width      => 40,
								   -background => $main::bkgcolor,
								   -relief     => 'sunken',
		)->grid( -row => 0, -column => 1, -pady => 2 );
		$f5->Label( -text => 'Column Fmt', )
		  ->grid( -row => 0, -column => 2, -padx => 2, -pady => 2 );
		my $diventry = $f5->Entry(
								   -width      => 40,
								   -background => $main::bkgcolor,
								   -relief     => 'sunken',
		)->grid( -row => 1, -column => 1, -pady => 2 );
		$f5->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				markup( $textwindow, $top, 'div', $diventry->get );
				$textwindow->focus;
			},
			-text  => 'div',
			-width => 8
		)->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
		my $f6 =
		  $main::lglobal{markpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n' );
		my $spanentry = $f6->Entry(
									-width      => 40,
									-background => $main::bkgcolor,
									-relief     => 'sunken',
		)->grid( -row => 1, -column => 1, -pady => 2 );
		$f6->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				markup( $textwindow, $top, 'span', $spanentry->get );
				$textwindow->focus;
			},
			-text  => 'span',
			-width => 8
		)->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
		my $f7 =
		  $main::lglobal{markpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n' );
		$f7->Checkbutton(
						  -variable    => \$main::lglobal{poetrynumbers},
						  -selectcolor => $main::lglobal{checkcolor},
						  -text        => 'Find and Format Poetry Line Numbers'
		)->grid( -row => 1, -column => 1, -pady => 2 );
		$f7->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				open my $infile, '<', 'header.txt'
				  or warn "Could not open header file. $!\n";
				my $headertext;
				while (<$infile>) {
					$_ =~ s/\cM\cJ|\cM|\cJ/\n/g;

					#$_ = eol_convert($_);
					$headertext .= $_;
				}
				$textwindow->insert( '1.0', $headertext );
				close $infile;
				$textwindow->insert( 'end', "<\/body>\n<\/html>" );
			},
			-text  => 'Header',
			-width => 16
		)->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
		my $f8 =
		  $main::lglobal{markpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n' );
		$f8->Button(
					 -activebackground => $main::activecolor,
					 -command          => \&main::hyperlinkpagenums,
					 -text             => 'Hyperlink Page Nums',
					 -width            => 16
		)->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		unless ( $main::useppwizardmenus and not $main::usemenutwo ) {
			$f8->Button(
				-activebackground => $main::activecolor,
				-command          => sub {
					&main::errorcheckpop_up('Link Check');
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'Link Check',
				-width => 16
			)->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $main::activecolor,
				-command          => sub {
					&main::errorcheckpop_up('HTML Tidy');
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'HTML Tidy',
				-width => 16
			)->grid( -row => 1, -column => 3, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $main::activecolor,
				-command          => sub {
					if ($main::w3cremote) {
						&main::errorcheckpop_up('W3C Validate Remote');
					} else {
						&main::errorcheckpop_up('W3C Validate');
					}
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'W3C Validate',
				-width => 16
			)->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $main::activecolor,
				-command          => sub {
					&main::errorcheckpop_up('W3C Validate CSS')
					  ;    #validatecssrun('');
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'W3C Validate CSS',
				-width => 16
			)->grid( -row => 2, -column => 2, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $main::activecolor,
				-command          => sub {
					&main::errorcheckpop_up('pphtml');
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'pphtml',
				-width => 16
			)->grid( -row => 2, -column => 3, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $main::activecolor,
				-command          => sub {
					&main::errorcheckpop_up('Image Check');
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'Image Check',
				-width => 16
			)->grid( -row => 3, -column => 1, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $main::activecolor,
				-command          => sub {
					&main::errorcheckpop_up('Epub Friendly');
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'Epub Friendly',
				-width => 16
			)->grid( -row => 3, -column => 2, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $main::activecolor,
				-command          => sub {
					&main::errorcheckpop_up('Check All');
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'Check All',
				-width => 16
			)->grid( -row => 3, -column => 3, -padx => 1, -pady => 2 );
		}
		$diventry->insert( 'end', ' class="i2"' );
		$spanentry->insert( 'end', ' class="i2"' );
		$main::lglobal{markpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$main::lglobal{markpop}->destroy;
				undef $main::lglobal{markpop};
			}
		);
		$main::lglobal{markpop}->Icon( -image => $main::icon );
		$main::lglobal{markpop}->transient($top) if $main::stayontop;
	}
}

sub markup {
	my $textwindow = shift;
	my $top        = shift;
	my $mark       = shift;
	my $mark1;
	$mark1 = shift if @_;
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	&main::savesettings();
	my @ranges = $textwindow->tagRanges('sel');

	unless (@ranges) {
		push @ranges, $textwindow->index('insert');
		push @ranges, $textwindow->index('insert');
	}
	my $range_total = @ranges;
	my $done        = '';
	my $open        = 0;
	my $close       = 0;
	my @intanchors;
	if ( $range_total == 0 ) {
		return;
	} else {
		my $end            = pop(@ranges);
		my $start          = pop(@ranges);
		my $thisblockstart = $start;
		my $thisblockend   = $end;
		my $selection;
		if ( $mark eq 'del' ) {
			my ( $lsr, $lsc, $ler, $lec, $step, $edited );
			( $lsr, $lsc ) = split /\./, $thisblockstart;
			( $ler, $lec ) = split /\./, $thisblockend;
			$step = $lsr;
			while ( $step <= $ler ) {
				$selection = $textwindow->get( "$step.0", "$step.end" );
				$edited++ if ( $selection =~ s/<\/td>/  /g );
				$edited++ if ( $selection =~ s/<\/?body>//g );
				$edited++ if ( $selection =~ s/<br.*?>//g );
				$edited++ if ( $selection =~ s/<\/?div[^>]*?>//g );
				$edited++
				  if ( $selection =~
					 s/<span.*?margin-left: (\d+\.?\d?)em.*?>/' ' x ($1 *2)/e );
				$edited++ if ( $selection =~ s/<\/?span[^>]*?>//g );
				$edited++ if ( $selection =~ s/<\/?[hscalupt].*?>//g );
				$edited++ if ( $selection =~ s/&nbsp;/ /g );
				$edited++ if ( $selection =~ s/<\/?blockquote>//g );
				$edited++ if ( $selection =~ s/\s+$// );
				$textwindow->delete( "$step.0", "$step.end" ) if $edited;
				$textwindow->insert( "$step.0", $selection ) if $edited;
				$step++;
				unless ( $step % 25 ) { $textwindow->update }
			}
			$textwindow->tagAdd( 'sel', $start, $end );
		} elsif ( $mark eq 'br' ) {
			my ( $lsr, $lsc, $ler, $lec, $step );
			( $lsr, $lsc ) = split /\./, $thisblockstart;
			( $ler, $lec ) = split /\./, $thisblockend;
			if ( $lsr eq $ler ) {
				$textwindow->insert( 'insert', '<br />' );
			} else {
				$step = $lsr;
				while ( $step <= $ler ) {
					$selection = $textwindow->get( "$step.0", "$step.end" );
					$selection =~ s/<br.*?>//g;
					$textwindow->insert( "$step.end", '<br />' );
					$step++;
				}
			}
		} elsif ( $mark eq 'hr' ) {
			$textwindow->insert( 'insert', '<hr class="full" />' );
		} elsif ( $mark eq '&nbsp;' ) {
			my ( $lsr, $lsc, $ler, $lec, $step );
			( $lsr, $lsc ) = split /\./, $thisblockstart;
			( $ler, $lec ) = split /\./, $thisblockend;
			if ( $lsr eq $ler ) {
				$textwindow->insert( 'insert', '&nbsp;' );
			} else {
				$step = $lsr;
				while ( $step <= $ler ) {
					$selection = $textwindow->get( "$step.0", "$step.end" );
					if ( $selection =~ /\s\s/ ) {
						$selection =~ s/^\s/&nbsp;/;
						$selection =~ s/  /&nbsp; /g;
						$selection =~ s/&nbsp; /&nbsp;&nbsp;/g;
						$textwindow->delete( "$step.0", "$step.end" );
						$textwindow->insert( "$step.0", $selection );
					}
					$step++;
				}
			}
		} elsif ( $mark eq 'img' ) {
			htmlimage( $textwindow, $top, $thisblockstart, $thisblockend );
		} elsif ( $mark eq 'elink' ) {
			my ( $name, $tempname );
			$name = '';
			if ( $main::lglobal{elinkpop} ) {
				$main::lglobal{elinkpop}->raise;
			} else {
				$main::lglobal{elinkpop} = $top->Toplevel;
				$main::lglobal{elinkpop}->title('Link Name');
				my $linkf1 =
				  $main::lglobal{elinkpop}
				  ->Frame->pack( -side => 'top', -anchor => 'n' );
				my $linklabel = $linkf1->Label( -text => 'Link name' )->pack;
				$main::lglobal{linkentry} =
				  $linkf1->Entry( -width => 60, -background => $main::bkgcolor )
				  ->pack;
				my $linkf2 =
				  $main::lglobal{elinkpop}
				  ->Frame->pack( -side => 'top', -anchor => 'n' );
				my $extbrowse = $linkf2->Button(
					-activebackground => $main::activecolor,
					-text             => 'Browse',
					-width            => 16,
					-command          => sub {
						$name =
						  $main::lglobal{elinkpop}
						  ->getOpenFile( -title => 'File Name?' );
						if ($name) {
							$main::lglobal{linkentry}->delete( 0, 'end' );
							$main::lglobal{linkentry}->insert( 'end', $name );
						}
					}
				)->pack( -side => 'left', -pady => 4 );
				my $linkf3 =
				  $main::lglobal{elinkpop}
				  ->Frame->pack( -side => 'top', -anchor => 'n' );
				my $okbut = $linkf3->Button(
					-activebackground => $main::activecolor,
					-text             => 'Ok',
					-width            => 16,
					-command          => sub {
						$name = $main::lglobal{linkentry}->get;
						if ($name) {
							$name =~ s/[\/\\]/;/g;
							$tempname = $main::globallastpath;
							$tempname =~ s/[\/\\]/;/g;
							$name     =~ s/$tempname//;
							$name     =~ s/;/\//g;
							$done = '</a>';
							$textwindow->insert( $thisblockend, $done );
							$done = '<a href="' . $name . "\">";
							$textwindow->insert( $thisblockstart, $done );
						}
						$main::lglobal{elinkpop}->destroy;
						undef $main::lglobal{elinkpop};
					}
				)->pack( -pady => 4 );
				$main::lglobal{elinkpop}->protocol(
					'WM_DELETE_WINDOW' => sub {
						$main::lglobal{elinkpop}->destroy;
						undef $main::lglobal{elinkpop};
					}
				);
				$main::lglobal{elinkpop}->Icon( -image => $main::icon );
				$main::lglobal{elinkpop}->transient( $main::lglobal{markpop} );
				$main::lglobal{linkentry}->focus;
			}
			$done = '';
		} elsif ( $mark eq 'ilink' ) {
			my ( $anchorname, $anchorstartindex, $anchorendindex, $length,
				 $srow, $scol, $string, $link, $match, $match2 );
			$length     = 0;
			@intanchors = ();
			my %inthash = ();
			$anchorstartindex = $anchorendindex = '1.0';
			while (
					$anchorstartindex =
					$textwindow->search(
								  '-regexp', '--', '<a (name|id)=[\'"].+?[\'"]',
								  $anchorendindex, 'end' )
			  )
			{
				$anchorendindex =
				  $textwindow->search( '-regexp', '--', '>', $anchorstartindex,
									   'end' );
				$string =
				  $textwindow->get( $anchorstartindex, $anchorendindex );
				$string =~ s/\n/ /g;
				$string =~ s/= /=/g;
				$string =~ m/=["'](.+?)['"]/;
				$match = $1;
				push @intanchors, '#' . $match;
				$match2 = $match;

				if ( exists $inthash{ '#' . ( lc($match) ) } ) {
					$textwindow->tagAdd( 'highlight', $anchorstartindex,
										 $anchorendindex );
					$textwindow->see($anchorstartindex);
					$textwindow->bell unless $main::nobell;
					$top->messageBox(
						-icon => 'error',
						-message =>
"More than one instance of the anchor $match2 in text.",
						-title => 'Duplicate anchor names.',
						-type  => 'Ok',
					);
					return;
				} else {
					$inthash{ '#' . ( lc($match) ) } = '#' . $match2;
				}
			}
			my ( $name, $tempname );
			$name = '';
			if ( $main::lglobal{linkpop} ) {
				$main::lglobal{linkpop}->deiconify;
			} else {
				my $linklistbox;
				$selection = $textwindow->get( $thisblockstart, $thisblockend );
				return unless length($selection);
				$main::lglobal{linkpop} = $top->Toplevel;
				$main::lglobal{linkpop}->title('Internal Links');
				$main::lglobal{linkpop}->geometry($main::geometry2) if $main::geometry2;
				$main::lglobal{linkpop}->transient($top)      if $main::stayontop;
				$main::lglobal{fnlinks} = 1;
				my $tframe = $main::lglobal{linkpop}->Frame->pack;
				$tframe->Checkbutton(
					-variable    => \$main::lglobal{ilinksrt},
					-selectcolor => $main::lglobal{checkcolor},
					-text        => 'Sort Alphabetically',
					-command     => sub {
						$linklistbox->delete( '0', 'end' );
						linkpopulate( $linklistbox, \@intanchors );
					},
				  )->pack(
						   -side   => 'left',
						   -pady   => 2,
						   -padx   => 2,
						   -anchor => 'n'
				  );
				$tframe->Checkbutton(
					-variable    => \$main::lglobal{fnlinks},
					-selectcolor => $main::lglobal{checkcolor},
					-text        => 'Hide Footnote Links',
					-command     => sub {
						$linklistbox->delete( '0', 'end' );
						linkpopulate( $linklistbox, \@intanchors );
					},
				  )->pack(
						   -side   => 'left',
						   -pady   => 2,
						   -padx   => 2,
						   -anchor => 'n'
				  );
				$tframe->Checkbutton(
					-variable    => \$main::lglobal{pglinks},
					-selectcolor => $main::lglobal{checkcolor},
					-text        => 'Hide Page Links',
					-command     => sub {
						$linklistbox->delete( '0', 'end' );
						linkpopulate( $linklistbox, \@intanchors );
					},
				  )->pack(
						   -side   => 'left',
						   -pady   => 2,
						   -padx   => 2,
						   -anchor => 'n'
				  );
				my $pframe =
				  $main::lglobal{linkpop}
				  ->Frame->pack( -fill => 'both', -expand => 'both' );
				$linklistbox =
				  $pframe->Scrolled(
									 'Listbox',
									 -scrollbars  => 'se',
									 -background  => $main::bkgcolor,
									 -selectmode  => 'single',
									 -activestyle => 'none',
				  )->pack(
						   -side   => 'top',
						   -anchor => 'nw',
						   -fill   => 'both',
						   -expand => 'both',
						   -padx   => 2,
						   -pady   => 2
				  );
				drag($linklistbox);
				$main::lglobal{linkpop}->protocol(
					'WM_DELETE_WINDOW' => sub {
						$main::lglobal{linkpop}->destroy;
						undef $main::lglobal{linkpop};
					}
				);
				$main::lglobal{linkpop}->Icon( -image => $main::icon );
				&main::BindMouseWheel($linklistbox);
				$linklistbox->eventAdd( '<<trans>>' => '<Double-Button-1>' );
				$linklistbox->bind(
					'<<trans>>',
					sub {
						$name      = $linklistbox->get('active');
						$main::geometry2 = $main::lglobal{linkpop}->geometry;
						$done      = '</a>';
						$textwindow->insert( $thisblockend, $done );
						$done = "<a href=\"" . $name . "\">";
						$textwindow->insert( $thisblockstart, $done );
						$main::lglobal{linkpop}->destroy;
						undef $main::lglobal{linkpop};
					}
				);
				my $tempvar   = lc( makeanchor( &main::deaccent($selection) ) );
				my $flag      = 0;
				my @entrarray = split( /_/, $tempvar );
				$entrarray[1] = '@' unless $entrarray[1];
				$entrarray[2] = '@' unless $entrarray[2];
				for ( sort (@intanchors) ) {
					last unless $tempvar;
					next
					  if ( ( ( $_ =~ /#Footnote/ ) || ( $_ =~ /#FNanchor/ ) )
						   && $main::lglobal{fnlinks} );
					next
					  if ( ( $_ =~ /#Page_\d+/ ) && $main::lglobal{pglinks} );
					next unless ( lc($_) eq '#' . $tempvar );
					$linklistbox->insert( 'end', $_ );
					$flag++;
				}
				$linklistbox->insert( 'end', '  ' );

				#print"$selection2\n";
				if ( $entrarray[1] && ( $entrarray[1] ne '@' ) ) {
					$entrarray[0] = '@'
					  if ( $entrarray[0] =~ /^to$|^a$|^the$|^and$/ );
					$entrarray[1] = '@'
					  if ( $entrarray[1] =~ /^to$|^a$|^the$|^and$/ );
					$entrarray[2] = '@'
					  if ( $entrarray[2] =~ /^to$|^a$|^the$|^and$/ );
				}
				for ( sort (@intanchors) ) {
					next
					  if ( ( ( $_ =~ /#Footnote/ ) || ( $_ =~ /#FNanchor/ ) )
						   && $main::lglobal{fnlinks} );
					next
					  if ( ( $_ =~ /#Page_\d+/ ) && $main::lglobal{pglinks} );
					next
					  unless (
						 lc($_) =~
						 /\Q$entrarray[0]\E|\Q$entrarray[1]\E|\Q$entrarray[2]\E/
					  );
					$linklistbox->insert( 'end', $_ );
					$flag++;
				}
				$linklistbox->insert( 'end', "  " );
				$flag = 0;
				&main::linkpopulate( $linklistbox, \@intanchors );
				$linklistbox->focus;
			}
		} elsif ( $mark eq 'anchor' ) {
			my $linkname;
			$selection = $textwindow->get( $thisblockstart, $thisblockend )
			  || '';
			$linkname = makeanchor( &main::deaccent($selection) );
			$done     = "<a id=\"" . $linkname . "\"></a>";
			$textwindow->insert( $thisblockstart, $done );
		} elsif ( $mark =~ /h\d/ ) {
			$selection = $textwindow->get( $thisblockstart, $thisblockend );
			if ( $selection =~ s/<\/?p>//g ) {
				$textwindow->delete( $thisblockstart, $thisblockend );
				$textwindow->tagRemove( 'sel', '1.0', 'end' );
				$textwindow->markSet( 'blkend', $thisblockstart );
				$textwindow->insert( $thisblockstart,
									 "<$mark>$selection<\/$mark>" );
				$textwindow->tagAdd( 'sel', $thisblockstart,
									 $textwindow->index('blkend') );
			} else {
				$textwindow->insert( $thisblockend,   "<\/$mark>" );
				$textwindow->insert( $thisblockstart, "<$mark>" );
			}
		} elsif ( ( $mark =~ /div/ ) || ( $mark =~ /span/ ) ) {
			$done = "<\/" . $mark . ">";
			$textwindow->insert( $thisblockend, $done );
			$mark .= $mark1;
			$done = '<' . $mark . '>';
			$textwindow->insert( $thisblockstart, $done );
		} else {
			$done = "<\/" . $mark . '>';
			$textwindow->insert( $thisblockend, $done );
			$done = '<' . $mark . '>';
			$textwindow->insert( $thisblockstart, $done );
		}
	}
	if ( $open != $close ) {
		$top->messageBox(
			-icon => 'error',
			-message =>
"Mismatching open and close markup removed.\nYou may have orphaned markup.",
			-title => 'Mismatching markup.',
			-type  => 'Ok',
		);
	}
	$textwindow->focus;
}

sub hyperlinkpagenums {
	&main::searchpopup();
	&main::searchoptset(qw/0 x x 1/);
	$main::lglobal{searchentry}->insert( 'end', "(?<!\\d)(\\d{1,3})" );
	$main::lglobal{replaceentry}
	  ->insert( 'end', "<a href=\"#Page_\$1\">\$1</a>" );
}

sub makeanchor {
	my $linkname = shift;
	return unless $linkname;
	$linkname =~ s/-/\x00/g;
	$linkname =~ s/&amp;|&mdash;/\xFF/;
	$linkname =~ s/<sup>.*?<\/sup>//g;
	$linkname =~ s/<\/?[^>]+>//g;
	$linkname =~ s/\p{Punct}//g;
	$linkname =~ s/\x00/-/g;
	$linkname =~ s/\s+/_/g;
	while ( $linkname =~ m/([\x{100}-\x{ffef}])/ ) {
		my $char     = "$1";
		my $ord      = ord($char);
		my $phrase   = charnames::viacode($ord);
		my $case     = 'lc';
		my $notlatin = 1;
		$phrase = '-X-' unless ( $phrase =~ /(LETTER|DIGIT|LIGATURE)/ );
		$case     = 'uc' if $phrase =~ /CAPITAL|^-X-$/;
		$notlatin = 0    if $phrase =~ /LATIN/;
		$phrase =~ s/.+(LETTER|DIGIT|LIGATURE) //;
		$phrase =~ s/ WITH.+//;
		$phrase = lc($phrase) if $case eq 'lc';
		$phrase =~ s/ /_/g;
		$phrase = "-$phrase-" if $notlatin;
		$linkname =~ s/$char/$phrase/g;
	}
	$linkname =~ s/--+/-/g;
	$linkname =~ s/[\x90-\xff\x20\x22]/_/g;
	$linkname =~ s/__+/_/g;
	$linkname =~ s/^[_-]+|[_-]+$//g;
	return $linkname;
}

sub autoindex {
	my $textwindow = shift;
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	my @ranges = $textwindow->tagRanges('sel');
	unless (@ranges) {
		push @ranges, $textwindow->index('insert');
		push @ranges, $textwindow->index('insert');
	}
	my $range_total = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		$textwindow->addGlobStart;
		my $end       = pop(@ranges);
		my $start     = pop(@ranges);
		my $paragraph = 0;
		my ( $lsr, $lsc ) = split /\./, $start;
		my ( $ler, $lec ) = split /\./, $end;
		my $step   = $lsr;
		my $blanks = 0;
		my $first  = 1;
		my $indent = 0;

		while ( $textwindow->get( "$step.0", "$step.end" ) eq '' ) {
			$step++;
		}
		while ( $step <= $ler ) {
			my $selection = $textwindow->get( "$step.0", "$step.end" );
			unless ($selection) { $step++; $blanks++; next }
			$selection = &main::addpagelinks($selection);
			if ( $first == 1 ) { $blanks = 2; $first = 0 }
			if ( $blanks == 2 ) {
				$selection = '<li class="ifrst">' . $selection . '</li>';
				$first     = 0;
			}
			if ( $blanks == 1 ) {
				$selection = '<li class="indx">' . $selection . '</li>';
			}
			if ( $selection =~ /^(\s+)/ ) {
				$indent = ( int( ( length($1) + 1 ) / 2 ) );
				$selection =~ s/^\s+//;
				$selection =
				  '<li class="isub' . $indent . '">' . $selection . '</li>';
			}
			$textwindow->delete( "$step.0", "$step.end" );
			$selection =~ s/<li<\/li>//;
			$textwindow->insert( "$step.0", $selection );
			$blanks = 0;
			$step++;
		}
		$textwindow->insert( "$ler.end", "</ul>\n" );
		$textwindow->insert( $start,     '<ul class="index">' );
		$textwindow->addGlobEnd;
	}
}

sub autolist {
	my $textwindow = shift;
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	my @ranges = $textwindow->tagRanges('sel');
	unless (@ranges) {
		push @ranges, $textwindow->index('insert');
		push @ranges, $textwindow->index('insert');
	}
	my $range_total = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		$textwindow->addGlobStart;
		my $end       = pop(@ranges);
		my $start     = pop(@ranges);
		my $paragraph = 0;
		if ( $main::lglobal{list_multiline} ) {
			my $selection = $textwindow->get( $start, $end );
			$selection =~ s/\n +/\n/g;
			$selection =~ s/\n\n+/\x{8A}/g;
			my @lrows = split( /\x{8A}/, $selection );
			for (@lrows) {
				$_ = '<li>' . $_ . "</li>\n\n";
			}
			$selection = "<$main::lglobal{liststyle}>\n";
			for my $lrow (@lrows) {
				$selection .= $lrow;
			}
			$selection =~ s/\n$//;
			$selection .= '</' . $main::lglobal{liststyle} . ">\n";

			#$selection =~ s/ </</g; # why is this necessary; reported as a bug
			$textwindow->delete( $start, $end );
			$textwindow->insert( $start, $selection );
		} else {
			my ( $lsr, $lsc ) = split /\./, $start;
			my ( $ler, $lec ) = split /\./, $end;
			my $step = $lsr;
			$step++ while ( $textwindow->get( "$step.0", "$step.end" ) eq '' );
			while ( $step <= $ler ) {
				my $selection = $textwindow->get( "$step.0", "$step.end" );
				unless ($selection) { $step++; next }
				if ( $selection =~ s/<br.*?>//g ) {
					$selection = '<li>' . $selection . '</li>';
				}
				if ( $selection =~ s/<p>/<li>/g )     { $paragraph = 1 }
				if ( $selection =~ s/<\/p>/<\/li>/g ) { $paragraph = 0 }
				$textwindow->delete( "$step.0", "$step.end" );
				unless ($paragraph) {
					unless ( $selection =~ /<li>/ ) {
						$selection = '<li>' . $selection . '</li>';
					}
				}
				$selection =~ s/<li><\/li>//;
				$textwindow->insert( "$step.0", $selection );
				$step++;
			}
			$textwindow->insert( "$ler.end", "</$main::lglobal{liststyle}>\n" );
			$textwindow->insert( $start,     "<$main::lglobal{liststyle}>" );
		}
		$textwindow->addGlobEnd;
	}
}

sub autotable {
	my ( $textwindow, $format ) = @_;
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	my @cformat;
	if ($format) {
		@cformat = split( //, $format );
	}
	my @ranges = $textwindow->tagRanges('sel');
	unless (@ranges) {
		push @ranges, $textwindow->index('insert');
		push @ranges, $textwindow->index('insert');
	}
	my $range_total = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		my $table = 1;
		my $end   = pop(@ranges);
		my $start = pop(@ranges);
		my ( @tbl, @trows, @tlines, @twords );
		my $row = 0;
		my $selection = $textwindow->get( $start, $end );
		$selection =~ s/<br.*?>//g;
		$selection =~ s/<\/?p>//g;
		$selection =~ s/\n[\s|]+\n/\n\n/g;
		$selection =~ s/^\n+//;
		$selection =~ s/\n\n+/\x{8A}/g if $main::lglobal{tbl_multiline};
		@trows = split( /\x{8A}/, $selection ) if $main::lglobal{tbl_multiline};
		$selection =~ s/\n[\s|]*\n/\n/g unless $main::lglobal{tbl_multiline};
		@trows = split( /\n/, $selection ) unless $main::lglobal{tbl_multiline};

		for my $trow (@trows) {
			@tlines = split( /\n/, $trow );
			for my $tline (@tlines) {
				if ( $selection =~ /\|/ ) {
					@twords = split( /\|/, $tline );
				} else {
					@twords = split( /\s\s+/, $tline );
				}
				for ( 0 .. $#twords ) {
					$tbl[$row][$_] .= "$twords[$_] ";
				}
			}
			$row++;
		}
		$selection = '';
		for my $row ( 0 .. $#tbl ) {
			$selection .= '<tr>';
			for ( $tbl[$row] ) {
				my $cellcnt = 0;
				my $cellalign;
				while (@$_) {
					if ( $cformat[$cellcnt] ) {
						if ( $cformat[$cellcnt] eq '>' ) {
							$cellalign = ' align="right"';
						} elsif ( $cformat[$cellcnt] eq '|' ) {
							$cellalign = ' align="center"';
						} else {
							$cellalign = ' align="left"';
						}
					} else {
						$cellalign = $main::lglobal{tablecellalign};
					}
					++$cellcnt;
					$selection .= '<td' . $cellalign . '>';
					$selection .= shift @$_;
					$selection .= '</td>';
				}
			}
			$selection .= "</tr>\n";
		}
		$selection .= '</table></div>';
		$selection =~ s/<td[^>]+><\/td>//g;
		$selection =~ s/ +<\//<\//g;
		$selection =~ s/d> +/d>/g;
		$selection =~ s/ +/ /g;
		$textwindow->delete( $start, $end );
		$textwindow->insert( $start, $selection );
		$textwindow->insert( $start,
			     "\n<div class=\"center\">\n"
			   . '<table border="0" cellpadding="4" cellspacing="0" summary="">'
			   . "\n" )
		  if $table;
		$table = 1;
	}
}
1;
