package Guiguts::UnicodeTools;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA    = qw(Exporter);
	@EXPORT = qw(&pututf);
}

sub pututf {
	$::lglobal{utfpop} = shift;
	my @xy     = $::lglobal{utfpop}->pointerxy;
	my $widget = $::lglobal{utfpop}->containing(@xy);
	my $letter = $widget->cget( -text );
	return unless $letter;
	my $ord = ord($letter);
	$letter = "&#$ord;" if ( $::lglobal{uoutp} eq 'h' );
	::insertit($letter);
}


1;
