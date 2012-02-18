package Guiguts::TextProcessingMenu;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&text_convert_italic &text_convert_bold &text_thought_break &text_convert_tb 
	&text_convert_options &fixpopup)
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
							-background   => $main::bkgcolor,
							-relief       => 'sunken',
							-textvariable => \$main::italic_char,
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
						  -background   => $main::bkgcolor,
						  -relief       => 'sunken',
						  -textvariable => \$main::bold_char,
	  )->pack( -side => 'left' );
	$options->Show;
	&main::savesettings();
}

sub fixpopup {
	my $top = $::top;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	if ( defined( $::lglobal{fixpop} ) ) {
		$::lglobal{fixpop}->deiconify;
		$::lglobal{fixpop}->raise;
		$::lglobal{fixpop}->focus;
	} else {
		$::lglobal{fixpop} = $top->Toplevel;
		$::lglobal{fixpop}->title('Fixup Options');
		::initialize_popup_with_deletebinding('fixpop');
		my $tframe = $::lglobal{fixpop}->Frame->pack;
		$tframe->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$::lglobal{fixpop}->UnmapWindow;
				::fixup();
				$::lglobal{fixpop}->destroy;
				undef $::lglobal{fixpop};
			},
			-text  => 'Go!',
			-width => 14
		)->pack( -pady => 6 );
		my $pframe = $::lglobal{fixpop}->Frame->pack;
		$pframe->Label( -text => 'Select options for the fixup routine.', )
		  ->pack;
		my $pframe1 = $::lglobal{fixpop}->Frame->pack;
		${ $::lglobal{fixopt} }[15] = 1;
		my @rbuttons = (
			'Skip /* */, /$ $/, and /X X/ marked blocks.',
			'Fix up spaces around hyphens.',
			'Convert multiple spaces to single spaces.',
			'Remove spaces before periods.',
			'Remove spaces before exclamation marks.',
			'Remove spaces before question marks.',
			'Remove spaces before semicolons.',
			'Remove spaces before colons.',
			'Remove spaces before commas.',
			'Remove spaces after beginning and before ending double quote.',
'Remove spaces after opening and before closing brackets, () [], {}.',
'Mark up a line with 4 or more * and nothing else as <tb>.',
			'Fix obvious l<->1 problems, lst, llth, etc.',
			'Format ellipses correctly',
'Remove spaces after beginning and before ending angle quotes « ».',

		);
		my $row = 0;
		for (@rbuttons) {
			$pframe1->Checkbutton(
								   -variable    => \${ $::lglobal{fixopt} }[$row],
								   -selectcolor => $::lglobal{checkcolor},
								   -text        => $_,
			)->grid( -row => $row, -column => 1, -sticky => 'nw' );
			++$row;
		}
		$pframe1->Radiobutton(
							-variable    => \${ $::lglobal{fixopt} }[15],
							-selectcolor => $::lglobal{checkcolor},
							-value       => 1,
							-text => 'French style angle quotes «guillemots»',
		)->grid( -row => $row, -column => 1 );
		++$row;
		$pframe1->Radiobutton(
							-variable    => \${ $::lglobal{fixopt} }[15],
							-selectcolor => $::lglobal{checkcolor},
							-value       => 0,
							-text => 'German style angle quotes »guillemots«',
		)->grid( -row => $row, -column => 1 );
	}
}



1;


