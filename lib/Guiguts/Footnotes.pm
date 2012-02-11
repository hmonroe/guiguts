package Guiguts::Footnotes;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&footnotepop &footnotefixup &getlz)
}

## Pop up a window where footnotes can be found, fixed and formatted. (heh)
sub footnotepop {
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	push @main::operations, ( localtime() . ' - Footnote Fixup' );
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	&main::oppopupdate()  if $main::lglobal{oppop};
	if ( defined( $main::lglobal{footpop} ) ) {
		$main::lglobal{footpop}->deiconify;
		$main::lglobal{footpop}->raise;
		$main::lglobal{footpop}->focus;
	} else {
		$main::lglobal{fncount} = '1' unless $main::lglobal{fncount};
		$main::lglobal{fnalpha} = '1' unless $main::lglobal{fnalpha};
		$main::lglobal{fnroman} = '1' unless $main::lglobal{fnroman};
		$main::lglobal{fnindex} = '0' unless $main::lglobal{fnindex};
		$main::lglobal{fntotal} = '0' unless $main::lglobal{fntotal};
		$main::lglobal{footpop} = $top->Toplevel;
		&main::initialize_popup_without_deletebinding('footpop');
		my ( $checkn, $checka, $checkr );
		$main::lglobal{footpop}->title('Footnote Fixup');
		my $frame2 =
		  $main::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$frame2->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				$textwindow->yview('end');
				$textwindow->see( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] )
				  if $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2];
			},
			-text  => 'See Anchor',
			-width => 14
		)->grid( -row => 1, -column => 1, -padx => 2, -pady => 4 );
		$main::lglobal{footnotetotal} =
		  $frame2->Label->grid( -row => 1, -column => 2 );
		$frame2->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				footnoteshow();
			},
			-text  => 'See Footnote',
			-width => 14
		)->grid( -row => 1, -column => 3, -padx => 2, -pady => 4 );
		$frame2->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				$main::lglobal{fnindex}--;
				footnoteshow();
			},
			-text  => '<--- Last FN',
			-width => 14
		)->grid( -row => 2, -column => 1 );
		$main::lglobal{fnindexbrowse} = $frame2->BrowseEntry(
			-label     => 'Go to - #',
			-variable  => \$main::lglobal{fnindex},
			-state     => 'readonly',
			-width     => 8,
			-listwidth => 22,
			-browsecmd => sub {
				$main::lglobal{fnindex} = $main::lglobal{fntotal}
				  if ( $main::lglobal{fnindex} > $main::lglobal{fntotal} );
				$main::lglobal{fnindex} = 1 if ( $main::lglobal{fnindex} < 1 );
				footnoteshow();
			}
		)->grid( -row => 2, -column => 2 );
		$frame2->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				$main::lglobal{fnindex}++;
				footnoteshow();
			},
			-text  => 'Next FN --->',
			-width => 14
		)->grid( -row => 2, -column => 3 );
		$main::lglobal{footnotenumber} =
		  $frame2->Label(
						  -background => $main::bkgcolor,
						  -relief     => 'sunken',
						  -justify    => 'center',
						  -font       => '{Times} 10',
						  -width      => 10,
		  )->grid( -row => 3, -column => 1, -padx => 2, -pady => 4 );
		$main::lglobal{footnoteletter} =
		  $frame2->Label(
						  -background => $main::bkgcolor,
						  -relief     => 'sunken',
						  -justify    => 'center',
						  -font       => '{Times} 10',
						  -width      => 10,
		  )->grid( -row => 3, -column => 2, -padx => 2, -pady => 4 );
		$main::lglobal{footnoteroman} =
		  $frame2->Label(
						  -background => $main::bkgcolor,
						  -relief     => 'sunken',
						  -justify    => 'center',
						  -font       => '{Times} 10',
						  -width      => 10,
		  )->grid( -row => 3, -column => 3, -padx => 2, -pady => 4 );
		$checkn = $frame2->Checkbutton(
			-variable => \$main::lglobal{fntypen},
			-command  => sub {
				return if ( $main::lglobal{footstyle} eq 'inline' );
				$checka->deselect;
				$checkr->deselect;
			},
			-text  => 'All to Number',
			-width => 14
		)->grid( -row => 4, -column => 1, -padx => 2, -pady => 4 );
		$checka = $frame2->Checkbutton(
			-variable => \$main::lglobal{fntypea},
			-command  => sub {
				return if ( $main::lglobal{footstyle} eq 'inline' );
				$checkn->deselect;
				$checkr->deselect;
			},
			-text  => 'All to Letter',
			-width => 14
		)->grid( -row => 4, -column => 2, -padx => 2, -pady => 4 );
		$checkr = $frame2->Checkbutton(
			-variable => \$main::lglobal{fntyper},
			-command  => sub {
				return if ( $main::lglobal{footstyle} eq 'inline' );
				$checka->deselect;
				$checkn->deselect;
			},
			-text  => 'All to Roman',
			-width => 14
		)->grid( -row => 4, -column => 3, -padx => 2, -pady => 4 );
		$frame2->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				return if ( $main::lglobal{footstyle} eq 'inline' );
				fninsertmarkers('n');
				footnoteshow();
			},
			-text  => 'Number',
			-width => 14
		)->grid( -row => 5, -column => 1, -padx => 2, -pady => 4 );
		$frame2->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				return if ( $main::lglobal{footstyle} eq 'inline' );
				fninsertmarkers('a');
				footnoteshow();
			},
			-text  => 'Letter',
			-width => 14
		)->grid( -row => 5, -column => 2, -padx => 2, -pady => 4 );
		$frame2->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				return if ( $main::lglobal{footstyle} eq 'inline' );
				fninsertmarkers('r');
				footnoteshow();
			},
			-text  => 'Roman',
			-width => 14
		)->grid( -row => 5, -column => 3, -padx => 2, -pady => 4 );
		$frame2->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { fnjoin() },
						 -text             => 'Join With Previous',
						 -width            => 14
		)->grid( -row => 6, -column => 1, -padx => 2, -pady => 4 );
		$frame2->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { footnoteadjust() },
						 -text             => 'Adjust Bounds',
						 -width            => 14
		)->grid( -row => 6, -column => 2, -padx => 2, -pady => 4 );
		$frame2->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { setanchor() },
						 -text             => 'Set Anchor',
						 -width            => 14
		)->grid( -row => 6, -column => 3, -padx => 2, -pady => 4 );
		$frame2->Checkbutton(
							  -variable => \$main::lglobal{fncenter},
							  -text     => 'Center on Search'
		)->grid( -row => 7, -column => 1, -padx => 3, -pady => 4 );
		$frame2->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				$main::lglobal{fnsecondpass} = 0;
				footnotefixup();
			},
			-text  => 'First Pass',
			-width => 14
		)->grid( -row => 7, -column => 2, -padx => 2, -pady => 4 );
		my $fnrb1 = $frame2->Radiobutton(
			-text        => 'Inline',
			-variable    => \$main::lglobal{footstyle},
			-selectcolor => $main::lglobal{checkcolor},
			-value       => 'inline',
			-command     => sub {
				$main::lglobal{fnindex} = 1;
				footnoteshow();
				$main::lglobal{fnmvbutton}->configure( -state => 'disabled' );
			},
		)->grid( -row => 8, -column => 1 );
		$main::lglobal{fnfpbutton} =
		  $frame2->Button(
						   -activebackground => $main::activecolor,
						   -command          => sub { &main::footnotefixup() },
						   -text             => 'Re Index',
						   -state            => 'disabled',
						   -width            => 14
		  )->grid( -row => 8, -column => 2, -padx => 2, -pady => 4 );
		my $fnrb2 = $frame2->Radiobutton(
			-text        => 'Out-of-Line',
			-variable    => \$main::lglobal{footstyle},
			-selectcolor => $main::lglobal{checkcolor},
			-value       => 'end',
			-command     => sub {
				$main::lglobal{fnindex} = 1;
				footnoteshow();
				$main::lglobal{fnmvbutton}->configure( -state => 'normal' )
				  if ( $main::lglobal{fnsecondpass}
					  && ( defined $main::lglobal{fnlzs} and @{ $main::lglobal{fnlzs} } ) );
			},
		)->grid( -row => 8, -column => 3 );
		my $frame1 =
		  $main::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$frame1->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { setlz() },
						 -text             => 'Set LZ @ cursor',
						 -width            => 14
		)->grid( -row => 1, -column => 1, -padx => 2, -pady => 4 );
		$frame1->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { autochaptlz() },
						 -text             => 'Autoset Chap. LZ',
						 -width            => 14
		)->grid( -row => 1, -column => 2, -padx => 2, -pady => 4 );
		$frame1->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { autoendlz() },
						 -text             => 'Autoset End LZ',
						 -width            => 14
		)->grid( -row => 1, -column => 3, -padx => 2, -pady => 4 );
		$frame1->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				getlz();
				return unless $main::lglobal{fnlzs} and @{ $main::lglobal{fnlzs} };
				$main::lglobal{zoneindex}-- unless $main::lglobal{zoneindex} < 1;
				if ( $main::lglobal{fnlzs}[ $main::lglobal{zoneindex} ] ) {
					$textwindow->see( 'LZ' . $main::lglobal{zoneindex} );
					$textwindow->tagRemove( 'highlight', '1.0', 'end' );
					$textwindow->tagAdd(
										 'highlight',
										 'LZ' . $main::lglobal{zoneindex},
										 'LZ' . $main::lglobal{zoneindex} . '+10c'
					);
				}
			},
			-text  => '<--- Last LZ',
			-width => 12
		)->grid( -row => 2, -column => 1, -padx => 2, -pady => 4 );

		$frame1->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				getlz();
				return unless $main::lglobal{fnlzs} and @{ $main::lglobal{fnlzs} };
				$main::lglobal{zoneindex}++
				  unless $main::lglobal{zoneindex} >
					  ( ( scalar( @{ $main::lglobal{fnlzs} } ) ) - 2 );
				if ( $main::lglobal{fnlzs}[ $main::lglobal{zoneindex} ] ) {
					$textwindow->see( 'LZ' . $main::lglobal{zoneindex} );
					$textwindow->tagRemove( 'highlight', '1.0', 'end' );
					$textwindow->tagAdd(
										 'highlight',
										 'LZ' . $main::lglobal{zoneindex},
										 'LZ' . $main::lglobal{zoneindex} . '+10c'
					);
				}
			},
			-text  => 'Next LZ --->',
			-width => 12
		)->grid( -row => 2, -column => 3, -padx => 6, -pady => 4 );
		my $frame3 =
		  $main::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$frame3->Checkbutton(
							  -variable => \$main::lglobal{fnsearchlimit},
							  -text     => 'Unlimited Anchor Search'
		)->grid( -row => 1, -column => 1, -padx => 3, -pady => 4 );
		$main::lglobal{fnmvbutton} =
		  $frame3->Button(
						   -activebackground => $main::activecolor,
						   -command          => sub { footnotemove() },
						   -text  => 'Move Footnotes To Landing Zone(s)',
						   -state => 'disabled',
						   -width => 30
		  )->grid( -row => 1, -column => 2, -padx => 3, -pady => 4 );
		my $frame4 =
		  $main::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$frame4->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub {footnotetidy() },
						 -text             => 'Tidy Up Footnotes',
						 -width            => 18
		)->grid( -row => 1, -column => 1, -padx => 6, -pady => 4 );
		$frame4->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { fnview() },
						 -text             => 'Check Footnotes',
						 -width            => 14
		)->grid( -row => 1, -column => 2, -padx => 6, -pady => 4 );
		$main::lglobal{footpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$main::lglobal{footpop}->destroy;
				undef $main::lglobal{footpop};
				$textwindow->tagRemove( 'footnote', '1.0', 'end' );
			}
		);
		$fnrb2->select;
		my ( $start, $end );
		$start = '1.0';
		while (1) {
			$start = $textwindow->markNext($start);
			last unless $start;
			next unless ( $start =~ /^fns/ );
			$end = $start;
			$end =~ s/^fns/fne/;
			$textwindow->tagAdd( 'footnote', $start, $end );
		}
		$main::lglobal{footnotenumber}->configure( -text => $main::lglobal{fncount} );
		$main::lglobal{footnoteletter}
		  ->configure( -text => &main::alpha( $main::lglobal{fnalpha} ) );
		$main::lglobal{footnoteroman}
		  ->configure( -text => &main::roman( $main::lglobal{fnroman} ) );
		$main::lglobal{footnotetotal}->configure(
				   -text => "# $main::lglobal{fnindex}" . "/" . "$main::lglobal{fntotal}" );
		$main::lglobal{fnsecondpass} = 0;
	}
}

sub footnoteshow {
	my $textwindow = $main::textwindow;
	if ( $main::lglobal{fnindex} < 1 ) {
		$main::lglobal{fnindex} = 1;
		return;
	}
	if ( $main::lglobal{fnindex} > $main::lglobal{fntotal} ) {
		$main::lglobal{fnindex} = $main::lglobal{fntotal};
		return;
	}
	$textwindow->tagRemove( 'footnote',  '1.0', 'end' );
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	footnoteadjust();
	my $start     = $textwindow->index("fns$main::lglobal{fnindex}");
	my $end       = $textwindow->index("fne$main::lglobal{fnindex}");
	my $anchor    = $textwindow->index("fna$main::lglobal{fnindex}");
	my $anchorend = $textwindow->index("fnb$main::lglobal{fnindex}");
	my $line      = $textwindow->index('end -1l');
	$textwindow->yview('end');

	if ( $main::lglobal{fncenter} ) {
		$textwindow->see($start) if $start;
	} else {
		my $widget = $textwindow->{rtext};
		my ( $lx, $ly, $lw, $lh ) = $widget->dlineinfo($line);
		my $bottom = int(
						  (
							$widget->height -
							  2 * $widget->cget( -bd ) -
							  2 * $widget->cget( -highlightthickness )
						  ) / $lh / 2
		) - 1;
		$textwindow->see("$end-${bottom}l") if $start;
	}
	$textwindow->tagAdd( 'footnote', $start, $end ) if $start;
	$textwindow->markSet( 'insert', $start ) if $start;
	$textwindow->tagAdd( 'highlight', $anchor, $anchorend )
	  if ( ( $anchor ne $start ) && $anchorend );
	$main::lglobal{footnotetotal}
	  ->configure( -text => "# $main::lglobal{fnindex}/$main::lglobal{fntotal}" )
	  if $main::lglobal{footpop};
	&main::update_indicators();
}

sub fninsertmarkers {
	my $style = shift;
	my $textwindow = $main::textwindow;
	my $offset = $textwindow->search(
									'--',
									':',
									$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0],
									$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][1]
	);
	if ( $main::lglobal{footstyle} eq 'end' ) {
		$textwindow->delete(
							$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0] . '+9c',
							$offset )
		  if $offset;
		if ( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] ne
			 $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] )
		{
			$textwindow->delete( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2],
								 $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] );
		}
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][6] = $main::lglobal{fncount}
		  if $style eq 'n';
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][6] = $main::lglobal{fnalpha}
		  if $style eq 'a';
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][6] = $main::lglobal{fnroman}
		  if $style eq 'r';
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] = $style;
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] = $main::lglobal{fncount}
		  if $style eq 'n';
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] = &main::alpha( $main::lglobal{fnalpha} )
		  if $style eq 'a';
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] = &main::roman( $main::lglobal{fnroman} )
		  if $style eq 'r';
		$main::lglobal{fncount}++ if $style eq 'n';
		$main::lglobal{fnalpha}++ if $style eq 'a';
		$main::lglobal{fnroman}++ if $style eq 'r';
		footnoteadjust();
		$textwindow->insert(
							$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0] . '+9c',
							' ' . $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] );
		$textwindow->insert( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2],
					  '[' . $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] . ']' );
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] =
		  $textwindow->index( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] . ' +'
				 . ( length( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] ) + 2 )
				 . 'c' );
		$textwindow->markSet( "fna$main::lglobal{fnindex}",
							  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] );
		$textwindow->markSet( "fnb$main::lglobal{fnindex}",
							  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] );
		footnoteadjust();
		$main::lglobal{footnotenumber}->configure( -text => $main::lglobal{fncount} );
	}
}

sub fnjoin {
	my $textwindow = $main::textwindow;
	$textwindow->tagRemove( 'footnote',  '1.0', 'end' );
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	my $start = $textwindow->search(
									'--',
									':',
									$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0],
									$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][1]
	);
	my $end = $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][1] . '-1c';
	$textwindow->delete( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} - 1 ][1] )
	  if (
		  $textwindow->get( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} - 1 ][1] ) eq
		  '*' );
	$textwindow->insert(
						$main::lglobal{fnarray}->[ $main::lglobal{fnindex} - 1 ][1] . '-1c',
						"\n" . $textwindow->get( "$start+2c", $end ) );
	footnoteadjust();
	$textwindow->delete( "fns$main::lglobal{fnindex}",    "fne$main::lglobal{fnindex}" );
	$textwindow->delete( "fna$main::lglobal{fnindex}",    "fnb$main::lglobal{fnindex}" );
	$textwindow->delete( "fns$main::lglobal{fnindex}-1c", "fns$main::lglobal{fnindex}" )
	  if ( $textwindow->get("fns$main::lglobal{fnindex}-1c") eq '*' );
	$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0] = '';
	$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][1] = '';
	footnoteadjust();
	$main::lglobal{fncount}-- if $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] eq 'n';
	$main::lglobal{fnalpha}-- if $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] eq 'a';
	$main::lglobal{fnroman}-- if $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] eq 'r';
	$main::lglobal{fnindex}--;
	&main::footnoteshow();
}

# Pop up a window showing all the footnote addresses with potential
# problems highlighted
sub fnview {
	my $top = $main::top;
	my $textwindow = $main::textwindow;
	my ( %fnotes, %anchors, $ftext );
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	if ( defined( $main::lglobal{footviewpop} ) ) {
		$main::lglobal{footviewpop}->deiconify;
		$main::lglobal{footviewpop}->raise;
		$main::lglobal{footviewpop}->focus;
	} else {
		$main::lglobal{footviewpop} = $top->Toplevel( -background => $main::bkgcolor );
		&main::initialize_popup_with_deletebinding('footviewpop');
		$main::lglobal{footviewpop}->title('Footnotes');
		my $frame1 =
		  $main::lglobal{footviewpop}->Frame( -background => $main::bkgcolor )
		  ->pack( -side => 'top', -anchor => 'n' );
		$frame1->Label(
			  -text =>
				"Duplicate anchors.\nmore than one fn\npointing to same anchor",
			  -background => 'yellow',
		)->grid( -row => 1, -column => 1 );
		$frame1->Label(
			-text =>
"No anchor found.\npossibly missing anchor,\nmissing colon, incorrect #",
			-background => 'pink',
		)->grid( -row => 1, -column => 2 );
		$frame1->Label(
				-text => "Out of sequence.\nfn's not in same\norder as anchors",
				-background => 'cyan',
		)->grid( -row => 1, -column => 3 );
		$frame1->Label(
			-text =>
"Very long.\nfn missing its' end bracket?\n(may just be a long fn.)",
			-background => 'tan',
		)->grid( -row => 1, -column => 4 );

		my $frame2 =
		  $main::lglobal{footviewpop}->Frame->pack(
											  -side   => 'top',
											  -anchor => 'n',
											  -fill   => 'both',
											  -expand => 'both'
		  );
		$ftext = $frame2->Scrolled(
									'ROText',
									-scrollbars => 'se',
									-background => $main::bkgcolor,
									-font       => $main::lglobal{font},
		  )->pack(
				   -anchor => 'nw',
				   -fill   => 'both',
				   -expand => 'both',
				   -padx   => 2,
				   -pady   => 2
		  );
		&main::drag($ftext);
		$ftext->tagConfigure( 'seq',    background => 'cyan' );
		$ftext->tagConfigure( 'dup',    background => 'yellow' );
		$ftext->tagConfigure( 'noanch', background => 'pink' );
		$ftext->tagConfigure( 'long',   background => 'tan' );

		for my $findex ( 1 .. $main::lglobal{fntotal} ) {
			$ftext->insert(
							'end',
							'footnote #' 
							  . $findex
							  . '  line.column - '
							  . $main::lglobal{fnarray}->[$findex][0]
							  . ",\tanchor line.column - "
							  . $main::lglobal{fnarray}->[$findex][2] . "\n"
			);
			if ( $main::lglobal{fnarray}->[$findex][0] eq
				 $main::lglobal{fnarray}->[$findex][2] )
			{
				$ftext->tagAdd( 'noanch', 'end -2l', 'end -1l' );
				$ftext->update;
			}
			if (
				 ( $findex > 1 )
				 && (
					  $textwindow->compare($main::lglobal{fnarray}->[$findex][0], '<',
										   $main::lglobal{fnarray}->[ $findex - 1 ][0]
					  )
					  || $textwindow->compare(
										   $main::lglobal{fnarray}->[$findex][2], '<',
										   $main::lglobal{fnarray}->[ $findex - 1 ][2]
					  )
				 )
			  )
			{
				$ftext->tagAdd( 'seq', 'end -2l', 'end -1l' );
				$ftext->update;
			}
			if ( exists $fnotes{ $main::lglobal{fnarray}->[$findex][2] } ) {
				$ftext->tagAdd( 'dup', 'end -2l', 'end -1l' );
				$ftext->update;
			}
			if ( $main::lglobal{fnarray}->[$findex][1] -
				 $main::lglobal{fnarray}->[$findex][0] > 40 )
			{
				$ftext->tagAdd( 'long', 'end -2l', 'end -1l' );
				$ftext->update;
			}
			$fnotes{ $main::lglobal{fnarray}->[$findex][2] } = $findex;
		}
		&main::BindMouseWheel($ftext);
	}
}

# @{$main::lglobal{fnarray}} is an array of arrays
#
# $main::lglobal{fnarray}->[$main::lglobal{fnindex}][0] = starting index of footnote.
# $main::lglobal{fnarray}->[$main::lglobal{fnindex}][1] = ending index of footnote.
# $main::lglobal{fnarray}->[$main::lglobal{fnindex}][2] = index of footnote anchor.
# $main::lglobal{fnarray}->[$main::lglobal{fnindex}][3] = index of footnote anchor end.
# $main::lglobal{fnarray}->[$main::lglobal{fnindex}][4] = anchor label.
# $main::lglobal{fnarray}->[$main::lglobal{fnindex}][5] = anchor type n a r (numeric, alphabet, roman)
# $main::lglobal{fnarray}->[$main::lglobal{fnindex}][6] = type index

sub footnotefixup {
	my $top = $main::top;
	my $textwindow = $main::textwindow;
	&main::viewpagenums() if ( $main::lglobal{seepagenums} );
	my ( $start, $end, $anchor, $pointer );
	$start            = 1;
	$main::lglobal{fncount} = '1';
	$main::lglobal{fnalpha} = '1';
	$main::lglobal{fnroman} = '1';
	$main::lglobal{fnindexbrowse}->delete( '0', 'end' ) if $main::lglobal{footpop};
	$main::lglobal{footnotenumber}->configure( -text => $main::lglobal{fncount} )
	  if $main::lglobal{footpop};
	$main::lglobal{footnoteletter}->configure( -text => &main::alpha( $main::lglobal{fnalpha} ) )
	  if $main::lglobal{footpop};
	$main::lglobal{footnoteroman}->configure( -text => &main::roman( $main::lglobal{fnroman} ) )
	  if $main::lglobal{footpop};
	$main::lglobal{ftnoteindexstart} = '1.0';
	$textwindow->markSet( 'fnindex', $main::lglobal{ftnoteindexstart} );
	$main::lglobal{fntotal} = 0;
	$textwindow->tagRemove( 'footnote',  '1.0', 'end' );
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );

	while (1) {
		$main::lglobal{ftnoteindexstart} =
		  $textwindow->search( '-exact', '--', '[ Footnote', '1.0', 'end' );
		last unless $main::lglobal{ftnoteindexstart};
		$textwindow->delete( "$main::lglobal{ftnoteindexstart}+1c",
							 "$main::lglobal{ftnoteindexstart}+2c" );
	}
	while (1) {
		$main::lglobal{ftnoteindexstart} =
		  $textwindow->search( '-exact', '--', '{Footnote', '1.0', 'end' );
		last unless $main::lglobal{ftnoteindexstart};
		$textwindow->delete( $main::lglobal{ftnoteindexstart},
							 "$main::lglobal{ftnoteindexstart}+1c" );
		$textwindow->insert( $main::lglobal{ftnoteindexstart}, '[' );
	}
	while (1) {
		$main::lglobal{ftnoteindexstart} =
		  $textwindow->search( '-exact', '--', '[Fotonote', '1.0', 'end' );
		last unless $main::lglobal{ftnoteindexstart};
		$textwindow->delete( "$main::lglobal{ftnoteindexstart}+1c",
							 "$main::lglobal{ftnoteindexstart}+9c" );
		$textwindow->insert( "$main::lglobal{ftnoteindexstart}+1c", 'Footnote' );
	}
	while (1) {
		$main::lglobal{ftnoteindexstart} =
		  $textwindow->search( '-exact', '--', '[Footnoto', '1.0', 'end' );
		last unless $main::lglobal{ftnoteindexstart};
		$textwindow->delete( "$main::lglobal{ftnoteindexstart}+1c",
							 "$main::lglobal{ftnoteindexstart}+9c" );
		$textwindow->insert( "$main::lglobal{ftnoteindexstart}+1c", 'Footnote' );
	}
	while (1) {
		$main::lglobal{ftnoteindexstart} =
		  $textwindow->search( '-exact', '--', '[footnote', '1.0', 'end' );
		last unless $main::lglobal{ftnoteindexstart};
		$textwindow->delete( "$main::lglobal{ftnoteindexstart}+1c",
							 "$main::lglobal{ftnoteindexstart}+2c" );
		$textwindow->insert( "$main::lglobal{ftnoteindexstart}+1c", 'F' );
	}
	$main::lglobal{ftnoteindexstart} = '1.0';
	while (1) {
		( $start, $end ) = footnotefind();
		last unless $start;
		$main::lglobal{fntotal}++;
		$main::lglobal{fnindex} = $main::lglobal{fntotal};
		( $start, $end ) = (
							 $textwindow->index("fns$main::lglobal{fnindex}"),
							 $textwindow->index("fne$main::lglobal{fnindex}")
		) if $main::lglobal{fnsecondpass};
		$pointer = '';
		$anchor  = '';
		$textwindow->yview('end');
		$textwindow->see($start) if $start;
		$textwindow->tagAdd( 'footnote', $start, $end );
		$textwindow->markSet( 'insert', $start );
		$main::lglobal{fnindexbrowse}->insert( 'end', $main::lglobal{fnindex} )
		  if $main::lglobal{footpop};
		$main::lglobal{footnotetotal}
		  ->configure( -text => "# $main::lglobal{fnindex}/$main::lglobal{fntotal}" )
		  if $main::lglobal{footpop};
		$pointer =
		  $textwindow->get(
							$start,
							(
							   $textwindow->search(
											 '--', ':', $start, "$start lineend"
							   )
							)
		  );
		$pointer =~ s/\[Footnote\s*//i;
		$pointer =~ s/\s*:$//;

		if ( length($pointer) > 20 ) {
			$pointer = '';
			$textwindow->insert( "$start+9c", ':' );
		}
		if ( $main::lglobal{fnsearchlimit} ) {
			$anchor =
			  $textwindow->search(
								   '-backwards', '--', "[$pointer]", $start,
								   '1.0'
			  ) if $pointer;
		} else {
			$anchor =
			  $textwindow->search(
								   '-backwards', '--', "[$pointer]", $start,
								   "$start-80l"
			  ) if $pointer;
		}
		$textwindow->tagAdd( 'highlight', $anchor,
							 $anchor . '+' . ( length($pointer) + 2 ) . 'c' )
		  if $anchor;
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0] = $start if $start;
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][1] = $end   if $end;
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] = $start
		  unless ( $pointer && $anchor );
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] = $anchor if $anchor;
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] = $start
		  unless ( $pointer && $anchor );
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] =
		  $textwindow->index( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] . '+'
							  . ( length($pointer) + 2 )
							  . 'c' )
		  if $anchor;
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] = $pointer if $pointer;

		if ($pointer) {
			$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] = 'n';
			if ( $pointer =~ /\p{IsAlpha}+/ ) {
				$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] = 'a';
				$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] = uc($pointer);
			}
			if ( $pointer =~ /[ivxlcdm]+\./i ) {
				$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] = 'r';
				$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] = uc($pointer);
			}
		} else {
			$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] = '';
		}
		$textwindow->markSet( "fns$main::lglobal{fnindex}", $start );
		$textwindow->markSet( "fne$main::lglobal{fnindex}", $end );
		$textwindow->markSet( "fna$main::lglobal{fnindex}",
							  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] );
		$textwindow->markSet( "fnb$main::lglobal{fnindex}",
							  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] );
		&main::update_indicators();
		$textwindow->focus;
		$main::lglobal{footpop}->raise if $main::lglobal{footpop};

		if ( $main::lglobal{fnsecondpass} ) {
			if ( $main::lglobal{footstyle} eq 'end' ) {
				$main::lglobal{fnsearchlimit} = 1;
				&main::fninsertmarkers('n')
				  if (    ( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] eq 'n' )
					   || ( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] eq '' )
					   || ( $main::lglobal{fntypen} ) );
				&main::fninsertmarkers('a')
				  if (    ( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] eq 'a' )
					   || ( $main::lglobal{fntypea} ) );
				&main::fninsertmarkers('r')
				  if (    ( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] eq 'r' )
					   || ( $main::lglobal{fntyper} ) );
				$main::lglobal{fnmvbutton}->configure( '-state' => 'normal' )
				  if ( defined $main::lglobal{fnlzs} and @{ $main::lglobal{fnlzs} } );
			} else {
				$textwindow->markSet( 'insert', 'fna' . $main::lglobal{fnindex} );
				$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] = '';
				&main::setanchor();
			}
		}
	}
	$main::lglobal{fnindex}      = 1;
	$main::lglobal{fnsecondpass} = 1;
	$main::lglobal{fnfpbutton}->configure( '-state' => 'normal' )
	  if $main::lglobal{footpop};
	footnoteshow();
}

sub getlz {
	my $textwindow = $main::textwindow;
	my $index = '1.0';
	my $zone  = 0;
	$main::lglobal{fnlzs} = ();
	my @marks = grep( /^LZ/, $textwindow->markNames );
	for my $mark (@marks) {
		$textwindow->markUnset($mark);
	}
	while (1) {
		$index =
		  $textwindow->search( '-regex', '--', '^FOOTNOTES:$', $index, 'end' );
		last unless $index;
		push @{ $main::lglobal{fnlzs} }, $index;
		$textwindow->markSet( "LZ$zone", $index );
		$index = $textwindow->index("$index +10c");
		$zone++;
	}
}

sub autochaptlz {
	my $textwindow = $main::textwindow;
	$main::lglobal{zoneindex} = 0;
	$main::lglobal{fnlzs}     = ();
	my $char;
	while (1) {
		$char = $textwindow->get('end-2c');
		last if ( $char =~ /\S/ );
		$textwindow->delete('end-2c');
		$textwindow->update;
	}
	$textwindow->insert( 'end', "\n\n" );
	my $index = '200.0';
	while (1) {
		$index = $textwindow->search( '-regex', '--', '^$', $index, 'end' );
		last unless ($index);
		last if ( $index < '100.0' );
		if ( ( $textwindow->index("$index+1l") ) eq
			    ( $textwindow->index("$index+1c") )
			 && ( $textwindow->index("$index+2l") ) eq
			 ( $textwindow->index("$index+2c") )
			 && ( $textwindow->index("$index+3l") ) eq
			 ( $textwindow->index("$index+3c") ) )
		{
			$textwindow->markSet( 'insert', "$index+1l" );
			setlz();
			$index .= '+4l';
		} else {
			$index .= '+1l';
			next;
		}
	}
	$textwindow->see('1.0');
}

sub autoendlz {
	my $textwindow = $main::textwindow;
	$textwindow->markSet( 'insert', 'end -1c' );
	setlz();
}

sub setlz {
	my $textwindow = $main::textwindow;
	$textwindow->insert( 'insert', "FOOTNOTES:\n\n" );
	$main::lglobal{fnmvbutton}->configure( '-state' => 'normal' )
	  if ( ( $main::lglobal{fnsecondpass} ) && ( $main::lglobal{footstyle} eq 'end' ) );
}

sub footnotemove {
	my $textwindow = $main::textwindow;
	my ( $lz, %footnotes, $zone, $index, $r, $c, $marker );
	$main::lglobal{fnsecondpass} = 0;
	footnotefixup();
	autoendlz();
	getlz();
	$main::lglobal{fnindex} = 1;
	foreach my $lz ( @{ $main::lglobal{fnlzs} } ) {
		if ( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0] ) {
			while (
					$textwindow->compare(
									$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0],
									'<=', $lz
					)
			  )
			{
				$footnotes{$lz} .= "\n\n"
				  . $textwindow->get( "fns$main::lglobal{fnindex}",
									  "fne$main::lglobal{fnindex}" );
				$main::lglobal{fnindex}++;
				last if $main::lglobal{fnindex} > $main::lglobal{fntotal};
			}
		}
	}
	$main::lglobal{fnindex} = $main::lglobal{fntotal};
	while ( $main::lglobal{fnindex} ) {
		$textwindow->delete("fne$main::lglobal{fnindex} +1c")
		  if ( $textwindow->get("fne$main::lglobal{fnindex} +1c") eq "\n" );
		$textwindow->delete("fns$main::lglobal{fnindex} -1c")
		  if ( $textwindow->get("fns$main::lglobal{fnindex} -1c") eq "\n" );
		$textwindow->delete( "fns$main::lglobal{fnindex}", "fne$main::lglobal{fnindex}" );
		$main::lglobal{fnindex}--;
	}
	$zone = 0;
	foreach my $lz ( @{ $main::lglobal{fnlzs} } ) {
		$textwindow->insert( $textwindow->index("LZ$zone +10c"),
							 $footnotes{$lz} )
		  if $footnotes{$lz};
		$footnotes{$lz} = '';
		$zone++;
	}
	$zone = 1;
	while ( $main::lglobal{fnarray}->[$zone][4] ) {
		my $fna = $textwindow->index("fna$zone");
		my $fnb = $textwindow->index("fnb$zone");
		if ( $textwindow->get( "$fna -1c", $fna ) eq ' ' ) {
			$textwindow->delete( "$fna -1c", $fna );
			$fna = $textwindow->index("fna$zone -1c");
			$fnb = $textwindow->index("fnb$zone -1c");
			$textwindow->markSet( "fna$zone", $fna );
			$textwindow->markSet( "fnb$zone", $fnb );
		}
		( $r, $c ) = split /\./, $fna;
		while ( $c eq '0' ) {
			$marker = $textwindow->get( $fna, $fnb );
			$textwindow->delete( $fna, $fnb );
			$r--;
			$textwindow->insert( "$r.end", $marker );
			( $r, $c ) = split /\./, ( $textwindow->index("$r.end") );
		}
		$zone++;
	}
	@{ $main::lglobal{fnlzs} }   = ();
	@{ $main::lglobal{fnarray} } = ();
	$index            = '1.0';
	$main::lglobal{fnindex} = 0;
	$main::lglobal{fntotal} = 0;
	while (1) {
		$index =
		  $textwindow->search( '-regex', '--', 'FOOTNOTES:', $index, 'end' );
		last unless ($index);
		unless ( $textwindow->get("$index +2l") =~ /^\[/ ) {
			$textwindow->delete( $index, "$index+12c" );
		}
		$index .= '+4l';
	}
	$textwindow->markSet( 'insert', '1.0' );
	$textwindow->see('1.0');
}

sub footnoteadjust {
	my $textwindow = $main::textwindow;
	my $end      = $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][1];
	my $start    = $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0];
	my $tempsave = $main::lglobal{ftnoteindexstart};
	my $label;
	unless ( $start and $main::lglobal{fnindex} ) {
		$tempsave = $main::lglobal{fnindex};
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ] = ();
		my $type = $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5];
		$main::lglobal{fncount}-- if $type and $type eq 'n';
		$main::lglobal{fnalpha}-- if $type and $type eq 'a';
		$main::lglobal{fnroman}-- if $type and $type eq 'r';
		while ( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} + 1 ][0] ) {
			$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0] =
			  $textwindow->index( 'fns' . ( $main::lglobal{fnindex} + 1 ) );
			$textwindow->markSet( "fns$main::lglobal{fnindex}",
								  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0] );
			$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][1] =
			  $textwindow->index( 'fne' . ( $main::lglobal{fnindex} + 1 ) );
			$textwindow->markSet( "fne$main::lglobal{fnindex}",
								  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][1] );
			$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] =
			  $textwindow->index( 'fna' . ( $main::lglobal{fnindex} + 1 ) );
			$textwindow->markSet( "fna$main::lglobal{fnindex}",
								  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] );
			$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] = '';
			$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] =
			  $textwindow->index( 'fnb' . ( $main::lglobal{fnindex} + 1 ) )
			  if $main::lglobal{fnarray}->[ $main::lglobal{fnindex} + 1 ][3];
			$textwindow->markSet( "fnb$main::lglobal{fnindex}",
								  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] )
			  if $main::lglobal{fnarray}->[ $main::lglobal{fnindex} + 1 ][3];
			$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] =
			  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} + 1 ][4];
			$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] =
			  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} + 1 ][5];
			$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][6] =
			  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} + 1 ][6];
			$main::lglobal{fnindex}++;
		}
		$main::lglobal{footnotenumber}->configure( -text => $main::lglobal{fncount} );
		$main::lglobal{footnoteletter}
		  ->configure( -text => alpha( $main::lglobal{fnalpha} ) );
		$main::lglobal{footnoteroman}
		  ->configure( -text => roman( $main::lglobal{fnroman} ) );
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ] = ();
		$main::lglobal{fnindex} = $tempsave;
		$main::lglobal{fntotal}--;
		$main::lglobal{footnotetotal}
		  ->configure( -text => "# $main::lglobal{fnindex}/$main::lglobal{fntotal}" );
		return;
	}
	$textwindow->tagRemove( 'footnote', $start, $end );
	if ( $main::lglobal{fnindex} > 1 ) {
		$main::lglobal{ftnoteindexstart} =
		  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} - 1 ][1];
		$textwindow->markSet( 'fnindex', $main::lglobal{ftnoteindexstart} );
	} else {
		$main::lglobal{ftnoteindexstart} = '1.0';
		$textwindow->markSet( 'fnindex', $main::lglobal{ftnoteindexstart} );
	}

	#print "\n$start|$end|$main::lglobal{fnindex}, $main::lglobal{ftnoteindexstart}\n";
	( $start, $end ) = footnotefind();
	$textwindow->markSet( "fns$main::lglobal{fnindex}", $start );
	$textwindow->markSet( "fne$main::lglobal{fnindex}", $end );
	$main::lglobal{ftnoteindexstart} = $tempsave;
	$textwindow->markSet( 'fnindex', $main::lglobal{ftnoteindexstart} );
	$textwindow->tagAdd( 'footnote', $start, $end );
	$textwindow->markSet( 'insert', $start );
	$main::lglobal{footnotenumber}->configure( -text => $main::lglobal{fncount} )
	  if $main::lglobal{footpop};
	$main::lglobal{footnoteletter}->configure( -text => &main::alpha( $main::lglobal{fnalpha} ) )
	  if $main::lglobal{footpop};
	$main::lglobal{footnoteroman}->configure( -text => &main::roman( $main::lglobal{fnroman} ) )
	  if $main::lglobal{footpop};

	if ( $end eq "$start+10c" ) {
		$textwindow->bell unless $nobell;
		return;
	}
	$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0] = $start if $start;
	$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][1] = $end   if $end;
	$textwindow->focus;
	$main::lglobal{footpop}->raise if $main::lglobal{footpop};
	return ( $start, $end );
}

## Footnote Operations
# Clean up footnotes in ASCII version of text. Note: destructive. Use only
# at end of editing.
sub footnotetidy {
	my $textwindow = $main::textwindow;
	my ( $begin, $end, $colon );
	$main::lglobal{fnsecondpass} = 0;
	footnotefixup();
	return unless $main::lglobal{fntotal} > 0;
	$main::lglobal{fnindex} = 1;
	while (1) {
		$begin = $textwindow->index( 'fns' . $main::lglobal{fnindex} );
		$textwindow->delete( "$begin+1c", "$begin+10c" );
		$colon =
		  $textwindow->search( '--', ':', $begin,
							  $textwindow->index( 'fne' . $main::lglobal{fnindex} ) );
		$textwindow->delete($colon) if $colon;
		$textwindow->insert( $colon, ']' ) if $colon;
		$end = $textwindow->index( 'fne' . $main::lglobal{fnindex} );
		$textwindow->delete("$end-1c");
		$textwindow->tagAdd( 'sel', 'fns' . $main::lglobal{fnindex}, "$end+1c" );
		&main::selectrewrap( $textwindow, $main::lglobal{seepagenums}, $scannos_highlighted,
					  $rwhyphenspace );
		$main::lglobal{fnindex}++;
		last if $main::lglobal{fnindex} > $main::lglobal{fntotal};
	}
}

sub setanchor {
	my $textwindow = $main::textwindow;
	my ( $index, $insert );
	$insert = $textwindow->index('insert');
	if ( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0] ne
		 $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] )
	{
		$textwindow->delete( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2],
							 $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] )
		  if $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3];
	} else {
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] = $insert;
	}
	footnoteadjust();
	if ( $main::lglobal{footstyle} eq 'inline' ) {
		$index = $textwindow->search(
									  ':',
									  "fns$main::lglobal{fnindex}",
									  "fne$main::lglobal{fnindex}"
		);
		$textwindow->delete( "fns$main::lglobal{fnindex}+9c", $index ) if $index;
		footnoteadjust();
		my $fn = $textwindow->get(
								   $textwindow->index(
													   'fns' . $main::lglobal{fnindex}
								   ),
								   $textwindow->index(
													   'fne' . $main::lglobal{fnindex}
								   )
		);
		$textwindow->insert( $textwindow->index("fna$main::lglobal{fnindex}"), $fn )
		  if $textwindow->compare(
								   $textwindow->index("fna$main::lglobal{fnindex}"),
								   '>',
								   $textwindow->index("fns$main::lglobal{fnindex}")
		  );
		$textwindow->delete( $textwindow->index("fns$main::lglobal{fnindex}"),
							 $textwindow->index("fne$main::lglobal{fnindex}") );
		$textwindow->insert( $textwindow->index("fna$main::lglobal{fnindex}"), $fn )
		  if $textwindow->compare(
								   $textwindow->index("fna$main::lglobal{fnindex}"),
								   '<=',
								   $textwindow->index("fns$main::lglobal{fnindex}")
		  );
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0] =
		  $textwindow->index( 'fns' . $main::lglobal{fnindex} );
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] = '';
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] = '';
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][6] = '';
		footnoteadjust();
	} else {
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] = $insert;
		if (
			 $textwindow->compare(
								   $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2],
								   '>',
								   $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0]
			 )
		  )
		{
			$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] =
			  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0];
		}
		$textwindow->insert( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2],
					  '[' . $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] . ']' );
		$textwindow->update;
		$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] =
		  $textwindow->index( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] . '+'
				 . ( length( $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][4] ) + 2 )
				 . 'c' );
		$textwindow->markSet( "fna$main::lglobal{fnindex}",
							  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][2] );
		$textwindow->markSet( "fnb$main::lglobal{fnindex}",
							  $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][3] );
		footnoteadjust();
		footnoteshow();
	}
}

sub footnotefind {
	my $textwindow = $main::textwindow;
	my ( $bracketndx, $nextbracketndx, $bracketstartndx, $bracketendndx );
	$main::lglobal{ftnoteindexstart} = $textwindow->index('fnindex');
	$bracketstartndx =
	  $textwindow->search( '-regexp', '--', '\[[Ff][Oo][Oo][Tt]',
						   $main::lglobal{ftnoteindexstart}, 'end' );
	return ( 0, 0 ) unless $bracketstartndx;
	$bracketndx = "$bracketstartndx+1c";
	while (1) {
		$bracketendndx = $textwindow->search( '--', ']', $bracketndx, 'end' );
		$bracketendndx = $textwindow->index("$bracketstartndx+9c")
		  unless $bracketendndx;
		$bracketendndx = $textwindow->index("$bracketendndx+1c")
		  if $bracketendndx;
		$nextbracketndx = $textwindow->search( '--', '[', $bracketndx, 'end' );
		if (    ($nextbracketndx)
			 && ( $textwindow->compare( $nextbracketndx, '<', $bracketendndx ) )
		  )
		{
			$bracketndx = $bracketendndx;
			next;
		}
		last;
	}
	$main::lglobal{ftnoteindexstart} = "$bracketstartndx+10c";
	$textwindow->markSet( 'fnindex', $main::lglobal{ftnoteindexstart} );
	return ( $bracketstartndx, $bracketendndx );
}

sub alpha {
	my $label = shift;
	$label--;
	my ( $single, $double, $triple );
	$single = $label % 26;
	$double = ( int( $label / 26 ) % 26 );
	$triple = ( $label - $single - ( $double * 26 ) % 26 );
	$single = chr( 65 + $single );
	$double = chr( 65 + $double - 1 );
	$triple = chr( 65 + $triple - 1 );
	$double = '' if ( $label < 26 );
	$triple = '' if ( $label < 676 );
	return ( $triple . $double . $single );
}

1;