package Guiguts::CharacterTools;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA    = qw(Exporter);
	@EXPORT = qw(&pututf &latinpopup);
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

sub latinpopup {
	my $top = $::top;
	if ( defined( $::lglobal{latinpop} ) ) {
		$::lglobal{latinpop}->deiconify;
		$::lglobal{latinpop}->raise;
		$::lglobal{latinpop}->focus;
	} else {
		my @lbuttons;
		$::lglobal{latinpop} = $top->Toplevel;
		$::lglobal{latinpop}->title('Latin-1 ISO 8859-1');
		::initialize_popup_with_deletebinding('latinpop');

		my $b = $::lglobal{latinpop}->Balloon( -initwait => 750 );
		my $tframe = $::lglobal{latinpop}->Frame->pack;
		my $default =
		  $tframe->Radiobutton(
								-variable    => \$::lglobal{latoutp},
								-selectcolor => $::lglobal{checkcolor},
								-value       => 'l',
								-text        => 'Latin-1 Character',
		  )->grid( -row => 1, -column => 1 );
		$tframe->Radiobutton(
							  -variable    => \$::lglobal{latoutp},
							  -selectcolor => $::lglobal{checkcolor},
							  -value       => 'h',
							  -text        => 'HTML Named Entity',
		)->grid( -row => 1, -column => 2 );
		my $frame = $::lglobal{latinpop}->Frame( -background => $::bkgcolor )->pack;
		my @latinchars = (
						 [ 'À', 'Á', 'Â', 'Ã', 'Ä', 'Å', 'Æ',     'Ç' ],
						 [ 'à', 'á', 'â', 'ã', 'ä', 'å', 'æ',     'ç' ],
						 [ 'È', 'É', 'Ê', 'Ë', 'Ì', 'Í', 'Î',     'Ï' ],
						 [ 'è', 'é', 'ê', 'ë', 'ì', 'í', 'î',     'ï' ],
						 [ 'Ò', 'Ó', 'Ô', 'Õ', 'Ö', 'Ø', 'Ñ',     'Þ' ],
						 [ 'ò', 'ó', 'ô', 'õ', 'ö', 'ø', 'ñ',     'þ' ],
						 [ 'Ù', 'Ú', 'Û', 'Ü', 'Ð', 'ß', 'Ý',     '×' ],
						 [ 'ù', 'ú', 'û', 'ü', 'ð', 'ÿ', 'ý',     '÷' ],
						 [ '¡', '¿', '«', '»', '¼', '½', '¾',     '¬' ],
						 [ '°', 'µ', '©', '®', '¹', '²', '³',     '±' ],
						 [ '£', '¢', '¦', '§', '¶', 'º', 'ª',     '·' ],
						 [ '¤', '¥', '¯', '¸', '¨', '´', "\x{A0}", '' ],
		);

		for my $y ( 0 .. 11 ) {
			for my $x ( 0 .. 7 ) {
				$lbuttons[ ( $y * 16 ) + $x ] =
				  $frame->Button(
								  -activebackground   => $::activecolor,
								  -text               => $latinchars[$y][$x],
								  -font               => '{Times} 18',
								  -relief             => 'flat',
								  -borderwidth        => 0,
								  -background         => $::bkgcolor,
								  -command            => \&putlatin,
								  -highlightthickness => 0,
				  )->grid( -row => $y, -column => $x, -padx => 2 );
				my $name  = ord( $latinchars[$y][$x] );
				my $hex   = uc sprintf( "%04x", $name );
				my $msg   = "Dec. $name, Hex. $hex";
				my $cname = charnames::viacode($name);
				$msg .= ", $cname" if $cname;
				$b->attach( $lbuttons[ ( $y * 16 ) + $x ],
							-balloonmsg => $msg, );
			}
		}
		$default->select;

		sub putlatin {
			my @xy     = $::lglobal{latinpop}->pointerxy;
			my $widget = $::lglobal{latinpop}->containing(@xy);
			my $letter = $widget->cget( -text );
			return unless $letter;
			my $hex = sprintf( "%x", ord($letter) );
			$letter = ::entity( '\x' . $hex ) if ( $::lglobal{latoutp} eq 'h' );
			::insertit($letter);
		}
		$::lglobal{latinpop}->resizable( 'no', 'no' );
		$::lglobal{latinpop}->raise;
		$::lglobal{latinpop}->focus;
	}
}


1;
