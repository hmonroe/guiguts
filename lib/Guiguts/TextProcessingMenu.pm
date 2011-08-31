package Guiguts::TextProcessingMenu;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&text_convert_italic &text_convert_bold &text_thought_break &text_convert_tb)
}


sub text_convert_italic {
	my ($textwindow ,$italic_char) = @_;
	
	my $italic  = qr/<\/?i>/;
	my $replace = $italic_char;
	$textwindow->FindAndReplaceAll( '-regexp', '-nocase', $italic, $replace );
}

sub text_convert_bold {
	my ($textwindow ,$bold_char) = @_;
	my $bold    = qr{</?b>};
	my $replace = "$bold_char";
	$textwindow->FindAndReplaceAll( '-regexp', '-nocase', $bold, $replace );
}

## Insert a "Thought break" (duh)
sub text_thought_break {
	my ($textwindow) = @_;
	$textwindow->insert( ( $textwindow->index('insert') ) . ' lineend',
						 '       *' x 5 );
}

sub text_convert_tb {
	my ($textwindow) = @_;
	my $tb = '       *       *       *       *       *';
	$textwindow->FindAndReplaceAll( '-exact', '-nocase', '<tb>', $tb );
}


1;


