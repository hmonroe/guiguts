package Guiguts::TextProcessingMenu;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&text_convert_italic &text_convert_bold &text_thought_break &text_convert_tb &text_convert_options)
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

sub text_convert_options {
	my $top = shift;

	my $options = $top->DialogBox( -title   => "Text Processing Options",
								   -buttons => ["OK"], );

	my $italic_frame =
	  $options->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $italic_label =
	  $italic_frame->Label(
							-width => 25,
							-text  => "Italic Replace Character"
	  )->pack( -side => 'left' );
	my $italic_entry =
	  $italic_frame->Entry(
							-width        => 6,
							-background   => $::bkgcolor,
							-relief       => 'sunken',
							-textvariable => \$::italic_char,
	  )->pack( -side => 'left' );

	my $bold_frame =
	  $options->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $bold_label =
	  $bold_frame->Label(
						  -width => 25,
						  -text  => "Bold Replace Character"
	  )->pack( -side => 'left' );
	my $bold_entry =
	  $bold_frame->Entry(
						  -width        => 6,
						  -background   => $::bkgcolor,
						  -relief       => 'sunken',
						  -textvariable => \$::bold_char,
	  )->pack( -side => 'left' );
	$options->Show;
	&::savesettings();
}



1;


