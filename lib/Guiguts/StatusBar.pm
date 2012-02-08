package Guiguts::StatusBar;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&_updatesel &_butbind &buildstatusbar &update_img_button)
}

## Bindings to make label in status bar act like buttons
sub _butbind {
	my $widget = shift;
	$widget->bind(
		'<Enter>',
		sub {
			$widget->configure( -background => $main::activecolor );
			$widget->configure( -relief     => 'raised' );
		}
	);
	$widget->bind(
		'<Leave>',
		sub {
			$widget->configure( -background => 'gray' );
			$widget->configure( -relief     => 'ridge' );
		}
	);
	$widget->bind( '<ButtonRelease-1>',
				   sub { $widget->configure( -relief => 'raised' ) } );
}



## Update Last Selection readout in status bar
sub _updatesel {
	my $textwindow = shift;
	my @ranges = $textwindow->tagRanges('sel');
	my $msg;
	if (@ranges) {
		if ( $main::lglobal{showblocksize} && ( @ranges > 2 ) ) {
			my ( $srow, $scol ) = split /\./, $ranges[0];
			my ( $erow, $ecol ) = split /\./, $ranges[-1];
			$msg = ' R:'
			  . abs( $erow - $srow + 1 ) . ' C:'
			  . abs( $ecol - $scol ) . ' ';
		} else {
			$msg = " $ranges[0]--$ranges[-1] ";
			if ( $main::lglobal{selectionpop} ) {
				$main::lglobal{selsentry}->delete( '0', 'end' );
				$main::lglobal{selsentry}->insert( 'end', $ranges[0] );
				$main::lglobal{seleentry}->delete( '0', 'end' );
				$main::lglobal{seleentry}->insert( 'end', $ranges[-1] );
			}
		}
	} else {
		$msg = ' No Selection ';
	}
	my $msgln = length($msg);

	no warnings 'uninitialized';
	$main::lglobal{selmaxlength} = $msgln if ( $msgln > $main::lglobal{selmaxlength} );
	$main::lglobal{selectionlabel}
	  ->configure( -text => $msg, -width => $main::lglobal{selmaxlength} );
	&main::update_indicators();
	$textwindow->_lineupdate;
}

## Status Bar
sub buildstatusbar {
	my ($textwindow,$top)=@_;
	
	$main::lglobal{current_line_label} =
	  $main::counter_frame->Label(
							 -text       => 'Ln: 1/1 - Col: 0',
							 -width      => 20,
							 -relief     => 'ridge',
							 -background => 'gray',
	  )->grid( -row => 1, -column => 0, -sticky => 'nw' );
	$main::lglobal{current_line_label}->bind(
		'<1>',
		sub {
			$main::lglobal{current_line_label}->configure( -relief => 'sunken' );
			&main::gotoline();
			&main::update_indicators();
		}
	);
	$main::lglobal{current_line_label}->bind(
		'<3>',
		sub {
			if   ($main::vislnnm) { $main::vislnnm = 0 }
			else            { $main::vislnnm = 1 }
			$textwindow->showlinenum if $main::vislnnm;
			$textwindow->hidelinenum unless $main::vislnnm;
			&main::savesettings();
		}
	);
	$main::lglobal{selectionlabel} =
	  $main::counter_frame->Label(
							 -text       => ' No Selection ',
							 -relief     => 'ridge',
							 -background => 'gray',
	  )->grid( -row => 1, -column => 10, -sticky => 'nw' );
	$main::lglobal{selectionlabel}->bind(
		'<1>',
		sub {
			if ( $main::lglobal{showblocksize} ) {
				$main::lglobal{showblocksize} = 0;
			} else {
				$main::lglobal{showblocksize} = 1;
			}
		}
	);
	$main::lglobal{selectionlabel}->bind( '<Double-1>', sub { &main::selection() } );
	$main::lglobal{selectionlabel}->bind(
		'<3>',
		sub {
			if ( $textwindow->markExists('selstart') ) {
				$textwindow->tagAdd( 'sel', 'selstart', 'selend' );
			}
		}
	);
	$main::lglobal{selectionlabel}->bind(
		'<Shift-3>',
		sub {
			$textwindow->tagRemove( 'sel', '1.0', 'end' );
			if ( $textwindow->markExists('selstart') ) {
				my ( $srow, $scol ) = split /\./,
				  $textwindow->index('selstart');
				my ( $erow, $ecol ) = split /\./, $textwindow->index('selend');
				for ( $srow .. $erow ) {
					$textwindow->tagAdd( 'sel', "$_.$scol", "$_.$ecol" );
				}
			}
		}
	);

	$main::lglobal{highlightlabel} =
	  $main::counter_frame->Label(
							 -text       => 'H',
							 -width      => 2,
							 -relief     => 'ridge',
							 -background => 'gray',
	  )->grid( -row => 1, -column => 1 );

	$main::lglobal{highlightlabel}->bind(
		'<1>',
		sub {
			if ( $main::scannos_highlighted ) {
				$main::scannos_highlighted          = 0;
				$main::lglobal{highlighttempcolor} = 'gray';
			} else {
				&main::scannosfile() unless $main::scannoslist;
				return unless $main::scannoslist;
				$main::scannos_highlighted          = 1;
				$main::lglobal{highlighttempcolor} = $main::highlightcolor;
			}
			&main::highlight_scannos();
		}
	);
	$main::lglobal{highlightlabel}->bind( '<3>', sub { &main::scannosfile() } );
	$main::lglobal{highlightlabel}->bind(
		'<Enter>',
		sub {
			$main::lglobal{highlighttempcolor} =
			  $main::lglobal{highlightlabel}->cget( -background );
			$main::lglobal{highlightlabel}->configure( -background => $main::activecolor );
			$main::lglobal{highlightlabel}->configure( -relief     => 'raised' );
		}
	);
	$main::lglobal{highlightlabel}->bind(
		'<Leave>',
		sub {
			$main::lglobal{highlightlabel}
			  ->configure( -background => $main::lglobal{highlighttempcolor} );
			$main::lglobal{highlightlabel}->configure( -relief => 'ridge' );
		}
	);
	$main::lglobal{highlightlabel}->bind(
		'<ButtonRelease-1>',
		sub {
			$main::lglobal{highlightlabel}->configure( -relief => 'raised' );
		}
	);
	$main::lglobal{insert_overstrike_mode_label} =
	  $main::counter_frame->Label(
							 -text       => '',
							 -relief     => 'ridge',
							 -background => 'gray',
							 -width      => 2,
	  )->grid( -row => 1, -column => 9, -sticky => 'nw' );
	$main::lglobal{insert_overstrike_mode_label}->bind(
		'<1>',
		sub {
			$main::lglobal{insert_overstrike_mode_label}
			  ->configure( -relief => 'sunken' );
			if ( $textwindow->OverstrikeMode ) {
				$textwindow->OverstrikeMode(0);
			} else {
				$textwindow->OverstrikeMode(1);
			}
		}
	);
	$main::lglobal{ordinallabel} =
	  $main::counter_frame->Label(
							 -text       => '',
							 -relief     => 'ridge',
							 -background => 'gray',
							 -anchor     => 'w',
	  )->grid( -row => 1, -column => 11 );

	$main::lglobal{ordinallabel}->bind(
		'<1>',
		sub {
			$main::lglobal{ordinallabel}->configure( -relief => 'sunken' );
			$main::lglobal{longordlabel} = $main::lglobal{longordlabel} ? 0 : 1;
			&main::update_indicators();
		}
	);
	_butbind($_)
	  for ( $main::lglobal{insert_overstrike_mode_label},
			$main::lglobal{current_line_label},
			$main::lglobal{selectionlabel},
			$main::lglobal{ordinallabel} );
	$main::lglobal{statushelp} = $top->Balloon( -initwait => 1000 );
	$main::lglobal{statushelp}->attach( $main::lglobal{current_line_label},
			 -balloonmsg =>
			   "Line number out of total lines\nand column number of cursor." );
	$main::lglobal{statushelp}->attach( $main::lglobal{insert_overstrike_mode_label},
						  -balloonmsg => 'Typeover Mode. (Insert/Overstrike)' );
	$main::lglobal{statushelp}->attach( $main::lglobal{ordinallabel},
		-balloonmsg =>
"Decimal & Hexadecimal ordinal of the\ncharacter to the right of the cursor."
	);
	$main::lglobal{statushelp}->attach( $main::lglobal{highlightlabel},
					-balloonmsg =>
					  "Highlight words from list. Right click to select list" );
	$main::lglobal{statushelp}->attach( $main::lglobal{selectionlabel},
		-balloonmsg =>
"Start and end points of selection -- Or, total lines.columns of selection"
	);
}

sub update_img_button {
	my $pnum = shift;
	unless ( defined( $main::lglobal{img_num_label} ) ) {
		$main::lglobal{img_num_label} =
		  $main::counter_frame->Label(
								 -text       => "Img:$pnum",
								 -width      => 7,
								 -background => 'gray',
								 -relief     => 'ridge',
		  )->grid( -row => 1, -column => 2, -sticky => 'nw' );
		$main::lglobal{img_num_label}->bind(
			'<1>',
			sub {
				$main::lglobal{img_num_label}->configure( -relief => 'sunken' );
				&main::gotopage();
				&main::update_indicators();
			}
		);
		$main::lglobal{img_num_label}->bind(
			'<3>',
			sub {
				$main::lglobal{img_num_label}->configure( -relief => 'sunken' );
				&main::viewpagenums();
				&main::update_indicators();
			}
		);
		_butbind( $main::lglobal{img_num_label} );
		$main::lglobal{statushelp}->attach( $main::lglobal{img_num_label},
						   -balloonmsg => "Image/Page name for current page." );
	}

	return ();
}



1;


