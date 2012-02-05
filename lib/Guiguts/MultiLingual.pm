package Guiguts::MultiLingual;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&spellmultiplelanguages)
}

our $debug = 1; # debug set for now

use Guiguts::WordFrequency;

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
#sub wordfrequencyspellcheck
#	my $wordw = wordfrequencygetmisspelled(); # get misspellings
#	$main::lglobal{saveheader} = "$wordw words not recognised by the spellchecker.";
#	sortwords( \%{ $main::lglobal{spellsort} } ); # into spellsort
#	$main::lglobal{misspelledlist}= ();
#sub wordfrequencygetmisspelled {
#		my ( $words ); # gets checked
#		my $wordw = 0; misspelt words
#		foreach ( sort ( keys %{ $main::lglobal{seenwords} } ) ) { $words .= "$_\n";} # words sorted into $words
#		if ($words) {&main::getmisspelledwords($words);} # and spelt
#		if ($main::lglobal{misspelledlist}){ # misspellt words
#			foreach ( sort @{ $main::lglobal{misspelledlist} } ) {
#				$main::lglobal{spellsort}->{$_} = $main::lglobal{seenwords}->{$_} || '0'; # put here number of each word
#				$wordw++;	}		}		return $wordw; # number misspellings



sub spellmultiplelanguages {
	my ($textwindow,$top) = @_;
	print "\$main::debug $main::debug\n";
#	push @main::operations, ( localtime() . ' - multilingual spelling' );
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	&main::oppopupdate()  if $main::lglobal{oppop};
	# find Aspell and base language if necessary
	&main::spelloptions() unless $main::globalspellpath;
	return unless $main::globalspellpath;
	return unless $main::globalspelldictopt;
	setmultiplelanguages($textwindow,$top);
	my $wc = createseenwordslang($textwindow,$top);
	if ($debug) { print "Total words: $wc\n"; };
	my $wordw = multilingualgetmisspelled();
	if ($debug) {print "Mis-spelt words: $wordw\n"; };
}

# clear array of languages
sub clearmultilanguages {
	@main::multidicts = ();
	$main::multidicts[0] = $main::globalspelldictopt;
}

# set multiple languages in array @multidicts
sub setmultiplelanguages {
	my ($textwindow,$top) = @_;
	if ($globalspellpath) {
		aspellstart() unless $lglobal{spellpid};
	}
	my $dicts;
	$main::multidicts[0] = $main::globalspelldictopt;
	my $spellop = $top->DialogBox( -title   => 'Multiple language selection',
								   -buttons => ['Continue'] );
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

# create hash lglobal{seenwordslang}
sub createseenwordslang {
	my ($textwindow,$top) = @_;
	my $wc    = 0;
	$main::lglobal{seenwordslang} = ();
	$top->Busy( -recurse => 1 );
	$wc = wordfrequencybuildwordlist($textwindow);
	for my $key (keys %{$lglobal{seenwords}}){
		$lglobal{seenwordslang}{$key} = undef;
	};
	$top->Unbusy;
	return $wc;
}

#copied from main
#input $dict, $section
sub getmisspelledwordstwo {
    $main::lglobal{misspelledlist}=();	
	my $dict = shift;
	my $section = shift;
	my $word;

	open my $save, '>:bytes', 'checkfil.txt';
	utf8::encode($section);
	print $save $section;
	close $save;
	my @spellopt = ("list", "--encoding=utf-8");
	push @spellopt, "-d", $dict;

	my $runner = runner::withfiles('checkfil.txt', 'temp.txt');
	$runner->run($main::globalspellpath, @spellopt);

	if ($debug) {
#		print "\$globalspellpath ", $main::globalspellpath, "\n";
#		print "\@spellopt\n";
#		for my $element (@spellopt) {
#		print "$element\n";
#		};
#		print "checkfil.txt retained\n";
	} else {
	unlink 'checkfil.txt';
	};

	my @templist = ();
	open my $infile,'<', 'temp.txt';
	my ( $ln, $tmp );
	while ( $ln = <$infile> ) {
		$ln =~ s/\r\n/\n/;
		chomp $ln;
		utf8::decode($ln);
		push( @templist, $ln );
	}
	close $infile;
	
	if ($debug) {
#		print "temp.txt retained\n";
	} else {
	unlink 'temp.txt';
	}

	processmisspelledwords ($dict, @templist);	
	
	foreach my $word (@templist) {
		next if ( exists( $main::projectdict{$word} ) );
		push @{ $main::lglobal{misspelledlist} },
		  $word;    # filter out project dictionary word list.
	}
}

#update lglobal{seenwordslang} depending on spelling
#input $dict, @templist
sub processmisspelledwords {
	my $dict = shift;
	my @templist = @_;
	my @tempseenwords =();
	my @tempunspelt = ();
	my $i = 0;
	my $j = 0;
	# ordered list of all words
	foreach ( sort ( keys %{ $main::lglobal{seenwords} } ) ) { @tempseenwords[$i++] = $_ ;	}
	my $imax = $i;
	# ordered list of all unspelt words
	foreach ( sort (@templist)) { @tempunspelt[$j++] = $_; }
	my $jmax = $j;

	#debugging
	my $section = "\@tempseenwords\n";
	open my $save, '>:bytes', 'tempseenwords.txt';
	for my $element (@tempseenwords) { $section .= "$element\n"; };
	utf8::encode($section);
	print $save $section;
	close $save;

	#debugging
	$section = "\@tempunspelt\n";
	open $save, '>:bytes', 'tempunspelt.txt';
	for my $element (@tempunspelt) { $section .= "$element\n"; };
	utf8::encode($section);
	print $save $section;
	close $save;
	
	#match words and update
	$i = 0; $j = 0;
	while ($i < $imax) {
		while ($j < $jmax) {
			if ($tempseenwords[$i] != $tempunspelt[$j]) {
				$main::lglobal{seenwordslang}{$tempseenwords[$i]} = $dict unless ($main::lglobal{seenwordslang}{$tempseenwords[$i]});
				$i++;
			} else {
				if ($tempseenwords[$i] == $tempunspelt[$j]) {
					$i++; $j++;
				} else {
					print "error in processmisspelledwords\n";
					print "\$i $i, \$j $j\n";
					print "$tempseenwords[$i], $tempunspelt[$j]\n";
					$i = $imax;
				}
			}
		}
		$main::lglobal{seenwordslang}{$tempseenwords[$i]} = $dict;
		$i++;
	}
	
	#debugging
	$section = "\%lglobal{seenwordslang}\n";
	open my $save, '>:bytes', 'words2.txt';
	for my $key (keys %{$main::lglobal{seenwords}}){
		if ($main::lglobal{seenwordslang}{$key}) {
			$section .= "$key => $main::lglobal{seenwordslang}{$key}\n";
		} else {
			$section .= "$key x=>\n";
		}
	};
	utf8::encode($section);
	print $save $section;
	close $save;

	#debugging
	$section = "\%lglobal{seenwordslang} unspelt\n";
	open $save, '>:bytes', 'words3.txt';
	for my $key (keys %{$main::lglobal{seenwords}}){
		$section .= "$key x=>\n" unless ($main::lglobal{seenwordslang}{$key});
	};
	utf8::encode($section);
	print $save $section;
	close $save;
}

#copied from wordfrequency
sub multilingualgetmisspelled {
	$main::lglobal{misspelledlist}= ();
	my $words;
	my $wordw = 0;
	for my $dict (@main::multidicts) {
		my $i = 0;
		# only include words with undef language
		foreach ( sort ( keys %{ $main::lglobal{seenwords} } ) ) { 
			unless ($main::lglobal{seenwordslang}{$_}) {
				$words .= "$_\n";
				$i++;
			}
		}
		print "\$dict $dict, words $i\n";
		#spellcheck
		if ($words) { getmisspelledwordstwo($dict, $words); }
	}
	
	
	if ($main::lglobal{misspelledlist}){
		foreach ( sort @{ $main::lglobal{misspelledlist} } ) {
			$main::lglobal{spellsort}->{$_} = $main::lglobal{seenwords}->{$_} || '0';
			$wordw++;
		}
	}
	return $wordw;
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
	array wordlist => word, (distinct words in book) - already keys in hash lglobal{seenwords}
	  => frequency, (count of words in book) - already values in hash lglobal{seenwords}
	  => language, (language spelt in, eg en, or user, or undef) - new hash lglobal{seenwordslang}

	A: set languages - DONE
	B: Process  file as per word frequency into array wordlist
		filling frequency and word - DONE
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

