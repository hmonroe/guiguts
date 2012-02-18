package Guiguts::SpellCheck;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA    = qw(Exporter);
	@EXPORT = qw(&spellcheckfirst);
}

# Initialize spellchecker
sub spellcheckfirst {
	my $textwindow = $::textwindow;
	my $top = $::top;
	@{ $::lglobal{misspelledlist} } = ();
	::viewpagenums() if ( $::lglobal{seepagenums} );
	::spellloadprojectdict();
	$::lglobal{lastmatchindex} = '1.0';

	# get list of misspelled words in selection (or file if nothing selected)
	::spellget_misspellings();
	my $term = $::lglobal{misspelledlist}[0];    # get first misspelled term
	$::lglobal{misspelledentry}->delete( '0', 'end' );
	$::lglobal{misspelledentry}->insert( 'end', $term )
	  ;    # put it in the appropriate text box
	$::lglobal{suggestionlabel}->configure( -text => 'Suggestions:' );
	return unless $term;    # no misspellings found, bail
	$::lglobal{matchlength} = '0';
	$::lglobal{matchindex} =
	  $textwindow->search(
						   -forwards,
						   -count => \$::lglobal{matchlength},
						   $term, $::lglobal{spellindexstart}, 'end'
	  );                    # search for the misspelled word in the text
	$::lglobal{lastmatchindex} =
	  ::spelladjust_index( $::lglobal{matchindex}, $term )
	  ;                     # find the index of the end of the match
	::spelladdtexttags();     # highlight the word in the text
	::update_indicators();    # update the status bar
	::aspellstart();          # initialize the guess function
	::spellguesses($term);    # get the guesses for the misspelling
	::spellshow_guesses();    # populate the listbox with guesses

	$::lglobal{hyphen_words} = ();    # hyphenated list of words
	if ( scalar( $::lglobal{seenwords} ) ) {
		$::lglobal{misspelledlabel}->configure( -text =>
			   "Not in Dictionary:  -  $::lglobal{seenwords}->{$term} in text." );

		# collect hyphenated words for faster, more accurate spell-check later
		foreach my $word ( keys %{ $::lglobal{seenwords} } ) {
			if ( $::lglobal{seenwords}->{$word} >= 1 && $word =~ /-/ ) {
				$::lglobal{hyphen_words}->{$word} = $::lglobal{seenwords}->{$word};
			}
		}
	}
	$::lglobal{nextmiss} = 0;
}



1;
