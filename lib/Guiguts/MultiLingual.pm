package Guiguts::MultiLingual;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our ($VERSION, @ISA, @EXPORT);
	
	$VERSION = 0.1;
	
	@ISA=qw(Exporter);
	@EXPORT=qw(&spellmultiplelanguages);
}

our $debug = 1; # debug set for now

use Guiguts::WordFrequency;

our @seenwords = ();
our $distinctwordcount = 0;
our %seenwordslc = () ;
our %seenwordslang = ();

sub spellmultiplelanguages {
	my ($textwindow,$top) = @_;
	push @::operations, ( localtime() . ' - multilingual spelling' );
	&::viewpagenums() if ( $::lglobal{seepagenums} );
	&::oppopupdate()  if $::lglobal{oppop};
	# find Aspell and base language if necessary
	&::spelloptions() unless $::globalspellpath;
	return unless $::globalspellpath;
	return unless $::globalspelldictopt;
	setmultiplelanguages($textwindow,$top);
	my $wc = createseenwordslang($textwindow,$top);
#	if ($debug) { print "Total words: $wc\n"; };
	my $wordw = multilingualgetmisspelled();
#	if ($debug)
	{print "Mis-spelt words remaining: $wordw\n"; };
	if ($debug) { saveLangDebugFiles() ;};
}

# clear array of languages
sub clearmultilanguages {
	@::multidicts = ();
	$::multidicts[0] = $::globalspelldictopt;
}

# set multiple languages in array @multidicts
sub setmultiplelanguages {
	my ($textwindow,$top) = @_;
	if ($::globalspellpath) {
		::aspellstart() unless $::lglobal{spellpid};
	}
	my $dicts;
	$::multidicts[0] = $::globalspelldictopt;
	my $spellop = $top->DialogBox( -title   => 'Multiple language selection',
								   -buttons => ['Continue'] );
	my $baselanglabel = $spellop->add('Label', -text => 'Base language' ) ->pack;
	my $baselang = $spellop->add(
									 'ROText',
									 -width      => 40,
									 -height     => 1,
									 -background => $::bkgcolor
	)->pack( -pady => 4 );
	$baselang->delete( '1.0', 'end' );
	$baselang->insert( '1.0', $::globalspelldictopt );
	my $dictlabel = $spellop->add( 'Label', -text => 'Dictionary files' )->pack;
	my $dictlist = $spellop->add(
							   'ScrlListbox',
							   -scrollbars => 'oe',
							   -selectmode => 'browse',
							   -background => $::bkgcolor,
							   -height     => 10,
							   -width      => 40,
	)->pack( -pady => 4 );
	my $multidictlabel =
	  $spellop->add( 'Label', -text => 'Additional Dictionary (ies)' )->pack;
	my $multidictxt = $spellop->add(
									 'ROText',
									 -width      => 40,
									 -height     => 1,
									 -background => $::bkgcolor
	)->pack( -pady => 4 );
	$multidictxt->delete( '1.0', 'end' );
	for my $element (@::multidicts) {
		$multidictxt->insert( 'end', $element );
		$multidictxt->insert( 'end', ' ' );
	}
	

	if ($::globalspellpath) {
		my $runner = runner::tofile('aspell.tmp');
		$runner->run($::globalspellpath, 'dump', 'dicts');
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
			push @::multidicts, $selection;
			$multidictxt->delete( '1.0', 'end' );
			for my $element (@::multidicts) {
				$multidictxt->insert( 'end', $element );
				$multidictxt->insert( 'end', ' ' );
			}
			::savesettings();
		}
	);
	my $clearmulti = $spellop->add ('Button', -text => 'Clear dictionaries',
		-width   => 12,
		-command => sub {
			clearmultilanguages;
			$multidictxt->delete( '1.0', 'end' );
			for my $element (@::multidicts) {
				$multidictxt->insert( 'end', $element );
				$multidictxt->insert( 'end', ' ' );
			}
		}
	) ->pack;
	$spellop->Show;
};

# outputs various arrays to files
sub saveLangDebugFiles {
	my $section ;
	my $save ;
	my $i;

	print "\$globalspellpath ", $::globalspellpath, "\n";

	print "saving lglobal_seenwords.txt - distinct words and frequencies\n";	
	$section = "\%lglobal{seenwords}\n";
	open $save, '>:bytes', 'lglobal_seenwords.txt';
	for my $key (keys %{$::lglobal{seenwords}}){
		$section .= "$key => $::lglobal{seenwords}{$key}\n";
	};
	utf8::encode($section);
	print $save $section;
	close $save;

	print "saving lglobal_misspelledlist.txt - global misspelledlist\n";	
	$section = "\@lglobal{misspelledlist}\n";
	open $save, '>:bytes', 'lglobal_misspelledlist.txt';
	foreach ( sort @{ $::lglobal{misspelledlist} } ) {
		$section .= "$_\n";
	};
	utf8::encode($section);
	print $save $section;
	close $save;

	#debugging
#	$section = "\@seenwords\n";
#	open $save, '>:bytes', 'seenwords.txt';
#	for my $element (@seenwords) { $section .= "$element\n"; };
#	utf8::encode($section);
#	print $save $section;
#	close $save;

	#debugging
#	$section = "\%seenwordslc\n";
#	open $save, '>:bytes', 'seenwordslc.txt';
#	for my $key (keys %seenwordslc){
#		$section .= "$key => $seenwordslc{$key}\n";
#	};
#	utf8::encode($section);
#	print $save $section;
#	close $save;
	
	print "saving seenwordslang.txt - distinct words and spelt language\n";	
	$section = "\%seenwordslang\n";
	open $save, '>:bytes', 'seenwordslang.txt';
	for my $key (sort (keys %{$::lglobal{seenwords}})){
		if ($seenwordslang{$key}) {
			$section .= "$key => $seenwordslang{$key}\n";
		} else { $section .= "$key x=>\n"; }
	};
	utf8::encode($section);
	print $save $section;
	close $save;

	print "saving seenwordslang_unspelt.txt - distinct unspelt words\n";	
	$section = "\%seenwordslang unspelt\n";
	$i = 0;
	open $save, '>:bytes', 'seenwordslang_unspelt.txt';
	for my $key (sort (keys %{$::lglobal{seenwords}})){
		unless ($seenwordslang{$key}) {
			$section .= "$key x=>\n" unless ($seenwordslang{$key});
			$i++;
		}
	};
	utf8::encode($section);
	print $save $section;
	close $save;

	print "saving seenwordslang_spelt.txt - distinct spelt words\n";	
	$section = "\%seenwordslang spelt\n";
	$i = 0;
	open $save, '>:bytes', 'seenwordlang_spelt.txt';
	for my $key (sort (keys %{$::lglobal{seenwords}})){
		if ($seenwordslang{$key}) {
			$section .= "$key => $seenwordslang{$key}\n";
			$i++;
		}
	};
	utf8::encode($section);
	print $save $section;
	close $save;

}

# create hash %seenwordslang
# and hash lglobal{seenwords}
# and @seenwords
# and hash %seenwordslc
sub createseenwordslang {
	my ($textwindow,$top) = @_;
	my $wc    = 0;
	@seenwords = ();
	$distinctwordcount = 0;
	%seenwordslang = ();
	%seenwordslc = () ;
	$top->Busy( -recurse => 1 );
	$wc = buildwordlist($textwindow);
	
	for my $key (keys %{$::lglobal{seenwords}}){
		$seenwordslang{$key} = undef;
	};
	
	my $i = 0;
	# ordered list of all words
	foreach ( sort ( keys %{ $::lglobal{seenwords} } ) ) { $seenwords[$i++] = $_ ;	}
	$distinctwordcount = $i;
#	if ($debug)
	{ print "Total words: $wc, Distinct words: $distinctwordcount\n"; }

	# hash of all words -> lc (word)
	foreach ( keys %{ $::lglobal{seenwords} } ) { $seenwordslc{$_}  = lc($_) ;	}

	$top->Unbusy;
	return $wc;
}

#copied from main
#input $dict, $section
sub getmisspelledwordstwo {
    $::lglobal{misspelledlist}=();	
	my $dict = shift;
	my $section = shift;
	my $word;
	my @templist = ();

	open my $save, '>:bytes', 'checkfil.txt';
	utf8::encode($section);
	print $save $section;
	close $save;
	my @spellopt = ("list", "--encoding=utf-8");
	push @spellopt, "-d", $dict;

	my $runner = runner::withfiles('checkfil.txt', 'temp.txt');
	$runner->run($::globalspellpath, @spellopt);

	unlink 'checkfil.txt'  unless ($debug) ;  # input file for Aspell

	open my $infile,'<', 'temp.txt';
	my ( $ln, $tmp );
	while ( $ln = <$infile> ) {
		$ln =~ s/\r\n/\n/;
		chomp $ln;
		utf8::decode($ln);
		push( @templist, $ln );
	}
	close $infile;
	
	unlink 'temp.txt' unless ($debug) ;  # output file of unspelt words from Aspell

	processmisspelledwords ($dict, @templist);	
	
	foreach my $word (@templist) {
		next if ( exists( $::projectdict{$word} ) );
		push @{ $::lglobal{misspelledlist} },
		  $word;    # filter out project dictionary word list.
	}
}

#update lglobal{seenwordslang} depending on spelling
#update %seenwordslang depending on spelling
#input $dict, @templist
sub processmisspelledwords {
	my $dict = shift;
	my @templist = @_;
	my @startunspelt = ();
	my @endunspelt = ();
	my $j = 0;
	my $i = 0;
	my $compare;
	
	# ordered list of all unspelt words
	foreach ( sort (@templist)) { $startunspelt[$j++] = $_; }
	my $jmax = $j;

	if ($debug) {print "$jmax unspelt words, ";}

	#match words and update
	$i = 0; $j = 0;
	while ($i < $distinctwordcount) {   # $distinctwordcount
		while ($j < $jmax) {         # $jmax
			$compare = ($seenwords[$i] cmp $startunspelt[$j]);
			if ($compare == -1){  # spelt word
				$seenwordslang{$seenwords[$i]} = $dict unless ($seenwordslang{$seenwords[$i]});
				$i++;
			} elsif ($compare == 0){ # unspelt word
				$i++; $j++;
			} elsif ($compare == 1){ # new word not in seenwords
#				print "$startunspelt[$j] returned by Aspell but not in book!\n";
				$j++;
			} else { print "How did I get here!!! Multilingual failure\n"; };
		}
		$seenwordslang{$seenwords[$i]} = $dict;
		$i++;
	}
	
	$i = 0;
	for my $key (sort (keys %{$::lglobal{seenwords}})){
		if ($seenwordslang{$key}) { $i++; }
	};
	if ($debug) {print "Total words spelt: $i\n";}
}

#copied from wordfrequency
sub multilingualgetmisspelled {
	$::lglobal{misspelledlist}= ();
	my $words;
	my $wordw = 0;
	for my $dict (@::multidicts) {
		$words = '';
		my $i = 0;
		# only include words with undef language
		foreach ( sort ( keys %{ $::lglobal{seenwords} } ) ) { 
			unless ($seenwordslang{$_}) {
				$words .= "$_\n";
				$i++;
			}
		}
		if ($debug) {print "\$dict $dict, words to spell $i, ";}
		#spellcheck
		if ($words) { getmisspelledwordstwo($dict, $words); }
	}

	if ($::lglobal{misspelledlist}){
		foreach ( sort @{ $::lglobal{misspelledlist} } ) {
			$::lglobal{spellsort}->{$_} = $::lglobal{seenwords}->{$_} || '0';
			$wordw++;
		}
	}
	return $wordw;
}

#copied from wordfrequency
# build lists of words lower case and proper
sub buildwordlist {
	my $textwindow = shift;
	my ( @words, $match, @savesets );
	my $index = '1.0';
	my $wc    = 0;
	my $end   = $textwindow->index('end');
	$::lglobal{seenwordsdoublehyphen} = ();
	$::lglobal{seenwords} = ();
	$::lglobal{seenwordpairs} = ();
	my $filename = $textwindow->FileName;
	unless ($filename) {
		$filename = 'tempfile.tmp';
		open( my $file, ">", "$filename" );
		my ($lines) = $textwindow->index('end - 1 chars') =~ /^(\d+)\./;
		while ( $textwindow->compare( $index, '<', 'end' ) ) {
			my $end = $textwindow->index("$index  lineend +1c");
			my $line = $textwindow->get( $index, $end );
			print $file $line;
			$index = $end;
		}
	}
	&::savefile()
	  if (    ( $textwindow->FileName )
		   && ( $textwindow->numberChanges != 0 ) );
	open my $fh, '<', $filename;
	my $lastwordseen = '';
	
	# starts here
	while ( my $line = <$fh> ) {
		utf8::decode($line);
		next if $line =~ m/^-----*\s?File:\s?\S+\.(png|jpg)---/;
		$line =~ s/_/ /g;  # underscores to spaces
		$line =~ s/<!--//g; # remove comment starts
		$line =~ s/-->//g; # remove comment ends
#		$line =~ s/[^'\.,\p{Alnum}-\*]/ /g;    # get rid of nonalphanumeric
		$line =~ s/['^\.,\*-]/ /g;    # get rid of nonalphanumeric
		$line =~ s/\P{Alnum}/ /g;
		$line =~ s/--/ /g;                   # get rid of --
		$line =~ s/—/ /g;    # trying to catch words with real em-dashes, from dp2rst
		$line =~ s/(\D),/$1 /g;    # throw away comma after non-digit
		$line =~ s/,(\D)/ $1/g;    # and before
		@words = split( /\s+/, $line );
		for my $word (@words) {
			$word =~s/ //g;
			if (length($word)==0) {next;}
			$word =~ s/[\.',-]+$//;    # throw away punctuation at end
			$word =~ s/^[\.,'-]+//;    #and at the beginning
			next if ( $word eq '' );
			$wc++;
			$::lglobal{seenwords}->{$word}++;
		}
		$index++;
		$index .= '.0';
		$textwindow->update;
	}
	close $fh;
	unlink 'tempfile.tmp' if ( -e 'tempfile.tmp' );
	return $wc;
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
	  => language, (language spelt in, eg en, or user, or undef) - new hash %seenwordslang

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

