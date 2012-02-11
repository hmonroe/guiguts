package Guiguts::Footnotes;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&footnotepop &footnoteshow &fninsertmarkers)
}

use strict;
use warnings;

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
						 -command          => sub { &main::fnjoin() },
						 -text             => 'Join With Previous',
						 -width            => 14
		)->grid( -row => 6, -column => 1, -padx => 2, -pady => 4 );
		$frame2->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { &main::footnoteadjust() },
						 -text             => 'Adjust Bounds',
						 -width            => 14
		)->grid( -row => 6, -column => 2, -padx => 2, -pady => 4 );
		$frame2->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { &main::setanchor() },
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
				&main::footnotefixup();
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
						 -command          => sub { &main::setlz() },
						 -text             => 'Set LZ @ cursor',
						 -width            => 14
		)->grid( -row => 1, -column => 1, -padx => 2, -pady => 4 );
		$frame1->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { &main::autochaptlz() },
						 -text             => 'Autoset Chap. LZ',
						 -width            => 14
		)->grid( -row => 1, -column => 2, -padx => 2, -pady => 4 );
		$frame1->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { &main::autoendlz() },
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
						   -command          => sub { &main::footnotemove() },
						   -text  => 'Move Footnotes To Landing Zone(s)',
						   -state => 'disabled',
						   -width => 30
		  )->grid( -row => 1, -column => 2, -padx => 3, -pady => 4 );
		my $frame4 =
		  $main::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$frame4->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { &main::footnotetidy() },
						 -text             => 'Tidy Up Footnotes',
						 -width            => 18
		)->grid( -row => 1, -column => 1, -padx => 6, -pady => 4 );
		$frame4->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { &main::fnview() },
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
	&main::footnoteadjust();
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
		&main::footnoteadjust();
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
		&main::footnoteadjust();
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
	&main::footnoteadjust();
	$textwindow->delete( "fns$main::lglobal{fnindex}",    "fne$main::lglobal{fnindex}" );
	$textwindow->delete( "fna$main::lglobal{fnindex}",    "fnb$main::lglobal{fnindex}" );
	$textwindow->delete( "fns$main::lglobal{fnindex}-1c", "fns$main::lglobal{fnindex}" )
	  if ( $textwindow->get("fns$main::lglobal{fnindex}-1c") eq '*' );
	$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][0] = '';
	$main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][1] = '';
	&main::footnoteadjust();
	$main::lglobal{fncount}-- if $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] eq 'n';
	$main::lglobal{fnalpha}-- if $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] eq 'a';
	$main::lglobal{fnroman}-- if $main::lglobal{fnarray}->[ $main::lglobal{fnindex} ][5] eq 'r';
	$main::lglobal{fnindex}--;
	&main::footnoteshow();
}



1;


	