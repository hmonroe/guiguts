#$Id: TextConvert.pm 56 2008-09-27 17:37:26Z vlsimpson $

package Guiguts::HTMLConvert;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&html_convert_tb &htmlbackup &html_convert_subscripts &html_convert_superscripts
	&html_convert_ampersands &html_convert_emdashes &html_convert_latin1);
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


1;


