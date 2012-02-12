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
	my $top = $::top;
	if ($::debug) {print "sub scannosfile\n";}
	if ($::debug) {print "scannoslistpath=$::scannoslistpath\n";}
	$::scannoslistpath = &::os_normal($::scannoslistpath);
	if ($::debug) {print "sub scannosfile1\n";}
	my $types = [ [ 'Text file', [ '.txt', ] ], [ 'All Files', ['*'] ], ];

	$::scannoslist = $top->getOpenFile(
									  -title => 'List of words to highlight?',
									  -filetypes  => $types,
									  -initialdir => $::scannoslistpath
	);
	if ($::scannoslist) {
		my ( $name, $path, $extension ) =
		  &::fileparse( $::scannoslist, '\.[^\.]*$' );
		$::scannoslistpath = $path;
		&::highlight_scannos() if ( $::scannos_highlighted );
		%{ $::lglobal{wordlist} } = ();
		&::highlight_scannos();
	}
	return;
}

##routine to automatically highlight words in the text
sub highlightscannos {
	my $textwindow = $::textwindow;
	my $top = $::top;
	if ($::debug) {print "sub highlightscannos\n";}
	return 0 unless $::scannos_highlighted;
	unless (  $::lglobal{wordlist}  ) {
		&::scannosfile() unless ( defined $::scannoslist && -e $::scannoslist );
		return 0 unless $::scannoslist;
		if ( open my $fh, '<', $::scannoslist ) {
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
					$::scannos_highlighted = 0;
					undef $::scannoslist;
					return;

				}
				$_ =~ s/^\x{FFEF}?// if ( $. < 2 );
				s/\cM\cJ|\cM|\cJ//g;
				next unless length $_;
				my @words = split /[\s \xA0]+/, $_;
				for my $word (@words) {
					next unless length $word;
					$word =~ s/^\p{Punct}*|\p{Punct}*$//g;
					$::lglobal{wordlist}->{$word} = '';
				}
			}
		} else {
			warn "Cannot open $::scannoslist: $!";
			return 0;
		}
	}
	my ( $fileend, undef ) = split /\./, $textwindow->index('end');
	if ( $::lglobal{hl_index} < $fileend ) {
		for ( 0 .. 99 ) {
			my $textline = $textwindow->get( "$::lglobal{hl_index}.0",
											 "$::lglobal{hl_index}.end" );
			while ( $textline =~
				s/ [^\p{Alnum} ]|[^\p{Alnum} ] |[^\p{Alnum} ][^\p{Alnum} ]/  / )
			{
			}
			$textline =~ s/^'|[,']+$/"/;
			$textline =~ s/--/  /g;
			my @words = split( /[^'\p{Alnum},-]+/, $textline );
			for my $word (@words) {

				if ( defined $::lglobal{wordlist}->{$word} ) {
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
										  "$::lglobal{hl_index}.@{[$index-1]}") =~
								   m{\p{Alnum}}
							  );
						}
						next
						  if (
							 $textwindow->get(
								 "$::lglobal{hl_index}.@{[$index + length $word]}"
							 ) =~ m{\p{Alnum}}
						  );
						$textwindow->tagAdd(
								 'scannos',
								 "$::lglobal{hl_index}.$index",
								 "$::lglobal{hl_index}.$index +@{[length $word]}c"
						);
					}
				}
			}
			$::lglobal{hl_index}++;
			last if ( $::lglobal{hl_index} > $fileend );
		}
	}
	my $idx1 = $textwindow->index('@0,0');   # First visible line in text widget

	$::lglobal{visibleline} = $idx1;
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
			if ( defined $::lglobal{wordlist}->{$word} ) {
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