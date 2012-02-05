package Guiguts::MultiLingual;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&setmultiplelanguages)
}

=head1 NAME

Guiguts::MultiLingual - spellcheck in multiple languages

=head1 PLAN

Variables: base_lang eg 'en'
       additional_lang eg 'fr', 'la'
array wordlist => word, (distinct words in book)
  => frequency, (count of words in book)
  => language, (language spelt in, eg en, or user, or undef)

A: set languages
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

our $debug = 1; # debug set for now

sub clearmultilanguages {
	@main::multidicts = ();
	$main::multidicts[0] = $main::globalspelldictopt;
}

# set multiple languages
# and store in array with base language in [0]
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

1;