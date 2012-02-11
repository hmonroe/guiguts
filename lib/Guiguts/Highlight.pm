package Guiguts::Highlight;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw( &highlightscannos)
}

# Routine to find highlight word list
sub scannosfile {
	my $top = $main::top;
	if ($main::debug) {print "sub scannosfile\n";}
	if ($main::debug) {print "scannoslistpath=$main::scannoslistpath\n";}
	$main::scannoslistpath = &main::os_normal($main::scannoslistpath);
	if ($main::debug) {print "sub scannosfile1\n";}
	my $types = [ [ 'Text file', [ '.txt', ] ], [ 'All Files', ['*'] ], ];

	$main::scannoslist = $top->getOpenFile(
									  -title => 'List of words to highlight?',
									  -filetypes  => $types,
									  -initialdir => $main::scannoslistpath
	);
	if ($main::scannoslist) {
		my ( $name, $path, $extension ) =
		  &main::fileparse( $main::scannoslist, '\.[^\.]*$' );
		$main::scannoslistpath = $path;
		&main::highlight_scannos() if ( $main::scannos_highlighted );
		%{ $main::lglobal{wordlist} } = ();
		&main::highlight_scannos();
	}
	return;
}

##routine to automatically highlight words in the text
sub highlightscannos {
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	if ($main::debug) {print "sub highlightscannos\n";}
	return 0 unless $main::scannos_highlighted;
	unless (  $main::lglobal{wordlist}  ) {
		&main::scannosfile() unless ( defined $main::scannoslist && -e $main::scannoslist );
		return 0 unless $main::scannoslist;
		if ( open my $fh, '<', $main::scannoslist ) {
			while (<$fh>) {
				utf8::decode($_);
				if ( $_ =~ 'scannoslist' ) {
					my $dialog =
					  $top->Dialog(
						   -text =>
							 'Warning: File must contain only a list of words.',
						   -bitmap  => 'warning',
						   -title   => 'Warning!',
						   -buttons => ['OK'],
					  );
					my $answer = $dialog->Show;
					$main::scannos_highlighted = 0;
					undef $main::scannoslist;
					return;

				}
				$_ =~ s/^\x{FFEF}?// if ( $. < 2 );
				s/\cM\cJ|\cM|\cJ//g;
				next unless length $_;
				my @words = split /[\s \xA0]+/, $_;
				for my $word (@words) {
					next unless length $word;
					$word =~ s/^\p{Punct}*|\p{Punct}*$//g;
					$main::lglobal{wordlist}->{$word} = '';
				}
			}
		} else {
			warn "Cannot open $main::scannoslist: $!";
			return 0;
		}
	}
	my ( $fileend, undef ) = split /\./, $textwindow->index('end');
	if ( $main::lglobal{hl_index} < $fileend ) {
		for ( 0 .. 99 ) {
			my $textline = $textwindow->get( "$main::lglobal{hl_index}.0",
											 "$main::lglobal{hl_index}.end" );
			while ( $textline =~
				s/ [^\p{Alnum} ]|[^\p{Alnum} ] |[^\p{Alnum} ][^\p{Alnum} ]/  / )
			{
			}
			$textline =~ s/^'|[,']+$/"/;
			$textline =~ s/--/  /g;
			my @words = split( /[^'\p{Alnum},-]+/, $textline );
			for my $word (@words) {

				if ( defined $main::lglobal{wordlist}->{$word} ) {
					my $indx = 0;
					my $index;
					while (1) {
						$index = index( $textline, $word, $indx );
						last if ( $index < 0 );
						$indx = $index + length($word);
						if ( $index > 0 ) {
							next
							  if (
								   $textwindow->get(
										  "$main::lglobal{hl_index}.@{[$index-1]}") =~
								   m{\p{Alnum}}
							  );
						}
						next
						  if (
							 $textwindow->get(
								 "$main::lglobal{hl_index}.@{[$index + length $word]}"
							 ) =~ m{\p{Alnum}}
						  );
						$textwindow->tagAdd(
								 'scannos',
								 "$main::lglobal{hl_index}.$index",
								 "$main::lglobal{hl_index}.$index +@{[length $word]}c"
						);
					}
				}
			}
			$main::lglobal{hl_index}++;
			last if ( $main::lglobal{hl_index} > $fileend );
		}
	}
	my $idx1 = $textwindow->index('@0,0');   # First visible line in text widget

	$main::lglobal{visibleline} = $idx1;
	$textwindow->tagRemove(
							'scannos',
							$idx1,
							$textwindow->index(
												    '@'
												  . $textwindow->width . ','
												  . $textwindow->height
							)
	);
	my ( $dummy, $ypix ) = $textwindow->dlineinfo($idx1);
	my $theight = $textwindow->height;
	my $oldy = my $lastline = -99;
	while (1) {
		my $idx = $textwindow->index( '@0,' . "$ypix" );
		( my $realline ) = split( /\./, $idx );
		my ( $x, $y, $wi, $he ) = $textwindow->dlineinfo($idx);
		my $textline = $textwindow->get( "$realline.0", "$realline.end" );
		while ( $textline =~
				s/ [^\p{Alnum} ]|[^\p{Alnum} ] |[^\p{Alnum} ][^\p{Alnum} ]/  / )
		{
		}
		$textline =~ s/^'|[,']+$/"/;
		$textline =~ s/--/  /g;
		my @words = split( /[^'\p{Alnum},-]/, $textline );

		for my $word (@words) {
			if ( defined $main::lglobal{wordlist}->{$word} ) {
				my $indx = 0;
				my $index;
				while (1) {
					$index = index( $textline, $word, $indx );
					last if ( $index < 0 );
					$indx = $index + length($word);
					if ( $index > 0 ) {
						next
						  if ( $textwindow->get("$realline.@{[$index - 1]}") =~
							   m{\p{Alnum}} );
					}
					next
					  if (
						   $textwindow->get(
									  "$realline.@{[$index + length $word]}") =~
						   m{\p{Alnum}}
					  );
					$textwindow->tagAdd(
										 'scannos',
										 "$realline.$index",
										 "$realline.$index +@{[length $word]}c"
					);
				}
			}
		}
		last unless defined $he;
		last if ( $oldy == $y );    #line is the same as the last one
		$oldy = $y;
		$ypix += $he;
		last
		  if $ypix >= ( $theight - 1 );  #we have reached the end of the display
		last if ( $y == $ypix );
	}
	return;
}



1;