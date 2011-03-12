#$Id: TextConvert.pm 56 2008-09-27 17:37:26Z vlsimpson $

package Guiguts::HTMLConvert;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&html_convert_tb &htmlbackup &html_convert_subscripts &html_convert_superscripts
	&html_convert_ampersands &html_convert_emdashes &html_convert_latin1 &html_convert_codepage &html_convert_utf
	&html_cleanup_markers &html_convert_footnotes)
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

sub htmlbackup {
	my ($textwindow ) = @_;
	$textwindow->Busy;
	my $savefn = $lglobal{global_filename};
	$lglobal{global_filename} =~ s/\.[^\.]*?$//;
	my $newfn = $lglobal{global_filename} . '-htmlbak.txt';
	&main::working("Saving backup of file\nto $newfn");
	$textwindow->SaveUTF($newfn);
	$lglobal{global_filename} = $newfn;
	&main::_bin_save();
	$lglobal{global_filename} = $savefn;
	$textwindow->FileName($savefn);
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

1;


