package Guiguts::MultiLingual;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&setmultiplelanguages)
}

our $debug = 1; # debug set for now

#explanation of WordFrequency
# called as wordfrequency($textwindow,$top);
#$main::lglobal{wfpop} = $top->Toplevel;
#		my $wordfreqseframe =  $main::lglobal{wfpop}->Frame->pack( -side => 'top', -anchor => 'n' ); # topline
#		my $wordfreqseframe1 = $main::lglobal{wfpop}->Frame->pack( -side => 'top', -anchor => 'n' ); # next
#		my @wfbuttons = ( # all buttons in $wordfreqseframe1
#		my $wcframe = $main::lglobal{wfpop}->Frame->pack( -fill => 'both', -expand => 'both', );
#		$main::lglobal{wclistbox} = $wcframe->Scrolled( # everything displayed here
#		&main::BindMouseWheel( $main::lglobal{wclistbox} ); # binds mouse to this window
#	$main::lglobal{saveheader} = "$wc total words. " .  # the topline in wclistbox
#	  keys( %{ $main::lglobal{seenwords} } ) . " distinct words in file."; # distinct words
#	sortwords( \%{ $main::lglobal{seenwords} } );
#sortwords( $main::lglobal{seenwords} ); displays 'seenwords'
#sortwords( \%{ $main::lglobal{seenwords} } ); is used more
#sortwords( \%display ); displays whatever
#$main::lglobal{seenwords} where all the words are
#$wc total words
#$index linenumber.position
#$wc = wordfrequencybuildwordlist($textwindow); build a word list and returns total word count
#in sub wordfrequencybuildwordlist
#  uses tempfile.tmp if no file loaded
#  utf8::decode($line); read stuff in UTF-8
#  $match = ( $main::lglobal{ignore_case} ) ? lc($word) : $word; # sets $match to $word
#  $main::lglobal{seenwordsdoublehyphen}->{$match}++; # updates emdash list
#  $main::lglobal{seenwords}->{$match}++; # updates seenwords after a lot of processing
#  print "the: $main::lglobal{seenwords}{'the'}\n"; # prints the number of 'the' found


sub clearmultilanguages {
	@main::multidicts = ();
	$main::multidicts[0] = $main::globalspelldictopt;
}

# set multiple languages in array @multidicts
sub setmultiplelanguages {
	my ($textwindow,$top) = @_;
	# find Aspell and base language if necessary
	&main::spelloptions() unless $main::globalspellpath;
	return unless $main::globalspellpath;
	return unless $main::globalspelldictopt;
	if ($globalspellpath) {
		aspellstart() unless $lglobal{spellpid};
	}
	my $dicts;
	$main::multidicts[0] = $main::globalspelldictopt;
	my $spellop = $top->DialogBox( -title   => 'Multiple language selection',
								   -buttons => ['Close'] );
	my $baselanglabel = $spellop->add('Label', -text => 'Base language' ) ->pack;
	my $baselang = $spellop->add(
									 'ROText',
									 -width      => 40,
									 -height     => 1,
									 -background => $main::bkgcolor
	)->pack( -pady => 4 );
	$baselang->delete( '1.0', 'end' );
	$baselang->insert( '1.0', $main::globalspelldictopt );
	my $dictlabel = $spellop->add( 'Label', -text => 'Dictionary files' )->pack;
	my $dictlist = $spellop->add(
							   'ScrlListbox',
							   -scrollbars => 'oe',
							   -selectmode => 'browse',
							   -background => $main::bkgcolor,
							   -height     => 10,
							   -width      => 40,
	)->pack( -pady => 4 );
	my $multidictlabel =
	  $spellop->add( 'Label', -text => 'Additional Dictionary (ies)' )->pack;
	my $multidictxt = $spellop->add(
									 'ROText',
									 -width      => 40,
									 -height     => 1,
									 -background => $main::bkgcolor
	)->pack( -pady => 4 );
	$multidictxt->delete( '1.0', 'end' );
	for my $element (@main::multidicts) {
		$multidictxt->insert( 'end', $element );
		$multidictxt->insert( 'end', ' ' );
	}
	

	if ($main::globalspellpath) {
		my $runner = runner::tofile('aspell.tmp');
		$runner->run($main::globalspellpath, 'dump', 'dicts');
		warn "Unable to access dictionaries.\n" if $?;

		open my $infile,'<', 'aspell.tmp';
		while ( $dicts = <$infile> ) {
			chomp $dicts;
			next if ( $dicts =~ m/-/ );
			$dictlist->insert( 'end', $dicts );
		}
		close $infile;
		unlink 'aspell.tmp';
	}
	$dictlist->eventAdd( '<<dictsel>>' => '<Double-Button-1>' );
	$dictlist->bind(
		'<<dictsel>>',
		sub {
			my $selection = $dictlist->get('active');
			push @main::multidicts, $selection;
			$multidictxt->delete( '1.0', 'end' );
			for my $element (@main::multidicts) {
				$multidictxt->insert( 'end', $element );
				$multidictxt->insert( 'end', ' ' );
			}
			main::savesettings();
		}
	);
	my $clearmulti = $spellop->add ('Button', -text => 'Clear dictionaries',
		-width   => 12,
		-command => sub {
			clearmultilanguages;
			$multidictxt->delete( '1.0', 'end' );
			for my $element (@main::multidicts) {
				$multidictxt->insert( 'end', $element );
				$multidictxt->insert( 'end', ' ' );
			}
		}
	) ->pack;
	$spellop->Show;
};

# get all words from book into array @bookwords
sub getbookwords {
}

1;
__END__

=head1 NAME

	Guiguts::MultiLingual - spellcheck in multiple languages

=head1 USAGE

=head2 setmultiplelanguages

	fills array @multidicts with languages to be used

=head1 PLAN

	Variables: base_lang eg 'en'
		   additional_lang eg 'fr', 'la'
	array wordlist => word, (distinct words in book)
	  => frequency, (count of words in book)
	  => language, (language spelt in, eg en, or user, or undef)

	A: set languages - DONE
	B: Process  file as per word frequency into array wordlist
		filling frequency and word
	C: Aspell wordlist where language undef using base_lang
	D: Diff Aspell output with wordlist and
		set language = base_lang for all words not in output
		ie correctly spelt
	E: Repeat (C) where language undef using additional_lang[1]
	F: Repeat (D) setting language = additional_lang[1] where spelt
	G: Repeat E/F for all additional_lang
	H: consider saving wordlist to file
	I: option to add non-base_lang spelt words to project.dic
	J: option to update wordlist language = user for all words in project.dic
	K: display outputs (wordlist) in word frequency window with (frequency)
		and ability to switch between - undef / user / base / spelt
		and ability to alter language values

=cut

