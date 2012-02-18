package Guiguts::CharacterTools;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA    = qw(Exporter);
	@EXPORT = qw(&pututf &latinpopup &doutfbuttons);
}

sub pututf {
	$::lglobal{utfpop} = shift;
	my @xy     = $::lglobal{utfpop}->pointerxy;
	my $widget = $::lglobal{utfpop}->containing(@xy);
	my $letter = $widget->cget( -text );
	return unless $letter;
	my $ord = ord($letter);
	$letter = "&#$ord;" if ( $::lglobal{uoutp} eq 'h' );
	insertit($letter);
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
						 [ 'Ò', 'Ó', 'Ô', 'Õ', 'Ö', 'Ø', 'Ñ',     'Ş' ],
						 [ 'ò', 'ó', 'ô', 'õ', 'ö', 'ø', 'ñ',     'ş' ],
						 [ 'Ù', 'Ú', 'Û', 'Ü', 'Ğ', 'ß', 'İ',     '×' ],
						 [ 'ù', 'ú', 'û', 'ü', 'ğ', 'ÿ', 'ı',     '÷' ],
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
			insertit($letter);
		}
		$::lglobal{latinpop}->resizable( 'no', 'no' );
		$::lglobal{latinpop}->raise;
		$::lglobal{latinpop}->focus;
	}
}

sub insertit {
	my $letter  = shift;
	my $isatext = 0;
	my $spot;
	$isatext = 1 if $::lglobal{hasfocus}->isa('Text');
	if ($isatext) {
		$spot = $::lglobal{hasfocus}->index('insert');
		my @ranges = $::lglobal{hasfocus}->tagRanges('sel');
		$::lglobal{hasfocus}->delete(@ranges) if @ranges;
	}
	$::lglobal{hasfocus}->insert( 'insert', $letter );
	$::lglobal{hasfocus}->markSet( 'insert', $spot . '+' . length($letter) . 'c' )
	  if $isatext;
}

sub doutfbuttons {
	my ( $start, $end ) = @_;
	my $textwindow = $::textwindow;
	
	my $rows = ( ( hex $end ) - ( hex $start ) + 1 ) / 16 - 1;
	my ( @buttons, $blln );
	$blln = $::lglobal{utfpop}->Balloon( -initwait => 750 );

	$::lglobal{pframe}->destroy if $::lglobal{pframe};
	undef $::lglobal{pframe};

	$::lglobal{pframe} =
	  $::lglobal{utfpop}->Frame( -background => $::bkgcolor )
	  ->pack( -expand => 'y', -fill => 'both' );
	$::lglobal{utfframe} =
	  $::lglobal{pframe}->Scrolled(
								  'Pane',
								  -background => $::bkgcolor,
								  -scrollbars => 'se',
								  -sticky     => 'nswe'
	  )->pack( -expand => 'y', -fill => 'both' );
	::drag( $::lglobal{utfframe} );

	for my $y ( 0 .. $rows ) {

		for my $x ( 0 .. 15 ) {
			my $name = hex($start) + ( $y * 16 ) + $x;
			my $hex   = sprintf "%04X", $name;
			my $msg   = "Dec. $name, Hex. $hex";
			my $cname = charnames::viacode($name);
			$msg .= ", $cname" if $cname;
			$name = 0 unless $cname;

			# FIXME: See Todo
			$buttons[ ( $y * 16 ) + $x ] = $::lglobal{utfframe}->Button(

				#    $buttons( ( $y * 16 ) + $x ) = $frame->Button(
				-activebackground   => $::activecolor,
				-text               => chr($name),
				-font               => $::lglobal{utffont},
				-relief             => 'flat',
				-borderwidth        => 0,
				-background         => $::bkgcolor,
				-command            => [ \&pututf, $::lglobal{utfpop} ],
				-highlightthickness => 0,
			)->grid( -row => $y, -column => $x );
			$buttons[ ( $y * 16 ) + $x ]->bind(
				'<ButtonPress-3>',
				sub {
					$textwindow->clipboardClear;
					$textwindow->clipboardAppend(
								  $buttons[ ( $y * 16 ) + $x ]->cget('-text') );
				}
			);
			$blln->attach( $buttons[ ( $y * 16 ) + $x ], -balloonmsg => $msg, );
			$::lglobal{utfpop}->update;
		}
	}

}


1;
