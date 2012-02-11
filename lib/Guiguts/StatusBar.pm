package Guiguts::StatusBar;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&update_indicators &_updatesel &buildstatusbar)
}

# Routine to update the status bar when something has changed.
#
sub update_indicators {
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	my ( $last_line, $last_col ) = split( /\./, $textwindow->index('end') );
	my ( $line,      $column )   = split( /\./, $textwindow->index('insert') );
	$main::lglobal{current_line_label}
	  ->configure( -text => "Ln:$line/" . ( $last_line - 1 ) . " Col:$column" )
	  if ( $main::lglobal{current_line_label} );
	my $mode             = $textwindow->OverstrikeMode;
	my $overstrke_insert = ' I ';
	if ($mode) {
		$overstrke_insert = ' O ';
	}
	$main::lglobal{insert_overstrike_mode_label}
	  ->configure( -text => " $overstrke_insert " )
	  if ( $main::lglobal{insert_overstrike_mode_label} );
	my $filename = $textwindow->FileName;
	$filename = 'No File Loaded' unless ( defined($filename) );
	$main::lglobal{highlightlabel}->configure( -background => $main::highlightcolor )
	  if ( $main::scannos_highlighted );
	if ( $main::lglobal{highlightlabel} ) {
		$main::lglobal{highlightlabel}->configure( -background => 'gray' )
		  unless ( $main::scannos_highlighted );
	}
	$filename = &main::os_normal($filename);
	$main::lglobal{global_filename} = $filename;

	my $edit_flag = '';
	if ( $textwindow->numberChanges ) {
		$edit_flag = 'edited';
	}

	# window label format: GG-version - [edited] - [file name]
	if ($edit_flag) {
		$top->configure(
			 -title => $main::window_title . " - " . $edit_flag . " - " . $filename );
	} else {
		$top->configure( -title => $main::window_title . " - " . $filename );
	}

	update_ordinal_button();

	#FIXME: need some logic behind this
	$textwindow->idletasks;
	my ( $mark, $pnum );
	$pnum = &main::get_page_number();
	my $markindex = $textwindow->index('insert');
	if ( $filename ne 'No File Loaded' or defined $main::lglobal{prepfile} ) {
		$main::lglobal{img_num_label}->configure( -text => 'Img:001' )
		  if defined $main::lglobal{img_num_label};
		$main::lglobal{page_label}->configure( -text => ("Lbl: None ") )
		  if defined $main::lglobal{page_label};
		if (    $main::auto_show_images
			 && $pnum )
		{
			if (    ( not defined $main::lglobal{pageimageviewed} )
				 or ( $pnum ne "$main::lglobal{pageimageviewed}" ) )
			{
				$main::lglobal{pageimageviewed} = $pnum;
				&main::openpng($textwindow,$pnum);
			}
		}
		update_img_button($pnum);
		update_prev_img_button();
		update_see_img_button();
		update_next_img_button();
		update_auto_img_button();
		update_label_button();
		update_img_lbl_values($pnum);
		update_proofers_button($pnum);
	}
	$textwindow->tagRemove( 'bkmk', '1.0', 'end' ) unless $main::bkmkhl;
	if ( $main::lglobal{geometryupdate} ) {
		&main::savesettings();
		$main::lglobal{geometryupdate} = 0;
	}
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

	#FIXME
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
	my $textwindow = $main::textwindow;
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

sub update_label_button {
	my $textwindow = $main::textwindow;
	unless ( $main::lglobal{page_label} ) {
		$main::lglobal{page_label} =
		  $main::counter_frame->Label(
								 -text       => 'Lbl: None ',
								 -background => 'gray',
								 -relief     => 'ridge',
		  )->grid( -row => 1, -column => 7 );
		_butbind( $main::lglobal{page_label} );
		$main::lglobal{page_label}->bind(
			'<1>',
			sub {
				$main::lglobal{page_label}->configure( -relief => 'sunken' );
				&main::gotolabel();
			}
		);
		$main::lglobal{page_label}->bind(
			'<3>',
			sub {
				$main::lglobal{page_label}->configure( -relief => 'sunken' );
				&main::pageadjust();
			}
		);
		$main::lglobal{statushelp}->attach( $main::lglobal{page_label},
						-balloonmsg => "Page label assigned to current page." );
	}
	return ();
}

# New subroutine "update_ordinal_button" extracted - Mon Mar 21 22:53:33 2011.
#
sub update_ordinal_button {
	my $textwindow = $main::textwindow;
	my $ordinal = ord( $textwindow->get('insert') );
	my $hexi = uc sprintf( "%04x", $ordinal );
	if ( $main::lglobal{longordlabel} ) {
		my $msg = charnames::viacode($ordinal) || '';
		my $msgln = length(" Dec $ordinal : Hex $hexi : $msg ");

		no warnings 'uninitialized';
		$main::lglobal{ordmaxlength} = $msgln
		  if ( $msgln > $main::lglobal{ordmaxlength} );
		$main::lglobal{ordinallabel}->configure(
								   -text => " Dec $ordinal : Hex $hexi : $msg ",
								   -width   => $main::lglobal{ordmaxlength},
								   -justify => 'left'
		);

	} else {
		$main::lglobal{ordinallabel}->configure(
										  -text => " Dec $ordinal : Hex $hexi ",
										  -width => 18
		) if ( $main::lglobal{ordinallabel} );
	}
}

sub update_prev_img_button {
	my $textwindow = $main::textwindow;
	unless ( defined( $main::lglobal{previmagebutton} ) ) {
		$main::lglobal{previmagebutton} =
		  $main::counter_frame->Label(
								 -text       => '<',
								 -width      => 1,
								 -relief     => 'ridge',
								 -background => 'gray',
		  )->grid( -row => 1, -column => 3 );
		$main::lglobal{previmagebutton}->bind(
			'<1>',
			sub {
				$main::lglobal{previmagebutton}->configure( -relief => 'sunken' );
				$main::lglobal{showthispageimage} = 1;
				&main::viewpagenums() unless $main::lglobal{pnumpop};
				$textwindow->focus;
				&main::pgprevious();

			}
		);
		_butbind( $main::lglobal{previmagebutton} );
		$main::lglobal{statushelp}->attach( $main::lglobal{previmagebutton},
			-balloonmsg =>
"Move to previous page in text and open image corresponding to previous current page in an external viewer."
		);
	}
}

# New subroutine "update_see_img_button" extracted - Mon Mar 21 23:23:36 2011.
#
sub update_see_img_button {
	my $textwindow = $main::textwindow;
	unless ( defined( $main::lglobal{pagebutton} ) ) {
		$main::lglobal{pagebutton} =
		  $main::counter_frame->Label(
								 -text       => 'See Img',
								 -width      => 7,
								 -relief     => 'ridge',
								 -background => 'gray',
		  )->grid( -row => 1, -column => 4 );
		$main::lglobal{pagebutton}->bind(
			'<1>',
			sub {
				$main::lglobal{pagebutton}->configure( -relief => 'sunken' );
				my $pagenum = &main::get_page_number();
				if ( defined $main::lglobal{pnumpop} ) {
					$main::lglobal{pagenumentry}->delete( '0', 'end' );
					$main::lglobal{pagenumentry}->insert( 'end', "Pg" . $pagenum );
				}
				&main::openpng($textwindow,$pagenum);
			}
		);
		$main::lglobal{pagebutton}->bind( '<3>', sub { setpngspath() } );
		_butbind( $main::lglobal{pagebutton} );
		$main::lglobal{statushelp}->attach( $main::lglobal{pagebutton},
			 -balloonmsg =>
			   "Open Image corresponding to current page in an external viewer."
		);
	}
}

sub update_next_img_button {
	my $textwindow = $main::textwindow;
	unless ( defined( $main::lglobal{nextimagebutton} ) ) {
		$main::lglobal{nextimagebutton} =
		  $main::counter_frame->Label(
								 -text       => '>',
								 -width      => 1,
								 -relief     => 'ridge',
								 -background => 'gray',
		  )->grid( -row => 1, -column => 5 );
		$main::lglobal{nextimagebutton}->bind(
			'<1>',
			sub {
				$main::lglobal{nextimagebutton}->configure( -relief => 'sunken' );
				$main::lglobal{showthispageimage} = 1;
				&main::viewpagenums() unless $main::lglobal{pnumpop};
				$textwindow->focus;
				&main::pgnext();
			}
		);
		_butbind( $main::lglobal{nextimagebutton} );
		$main::lglobal{statushelp}->attach( $main::lglobal{nextimagebutton},
			-balloonmsg =>
"Move to next page in text and open image corresponding to next current page in an external viewer."
		);
	}
}

sub update_auto_img_button {
	my $textwindow = $main::textwindow;
	unless ( defined( $main::lglobal{autoimagebutton} ) ) {
		$main::lglobal{autoimagebutton} =
		  $main::counter_frame->Label(
								 -text       => 'Auto Img',
								 -width      => 9,
								 -relief     => 'ridge',
								 -background => 'gray',
		  )->grid( -row => 1, -column => 6 );
		if ($main::auto_show_images) {
			$main::lglobal{autoimagebutton}->configure( -text => 'No Img' );
		}
		$main::lglobal{autoimagebutton}->bind(
			'<1>',
			sub {
				$main::auto_show_images = 1 - $main::auto_show_images;
				if ($main::auto_show_images) {
					$main::lglobal{autoimagebutton}->configure( -relief => 'sunken' );
					$main::lglobal{autoimagebutton}->configure( -text   => 'No Img' );
					$main::lglobal{statushelp}->attach( $main::lglobal{autoimagebutton},
						-balloonmsg =>
"Stop automatically showing the image for the current page."
					);

				} else {
					$main::lglobal{autoimagebutton}->configure( -relief => 'sunken' );
					$main::lglobal{autoimagebutton}->configure( -text => 'Auto Img' );
					$main::lglobal{statushelp}->attach( $main::lglobal{autoimagebutton},
						-balloonmsg =>
"Automatically show the image for the current page (focus shifts to image window)."
					);
				}
			}
		);
		_butbind( $main::lglobal{autoimagebutton} );
		$main::lglobal{statushelp}->attach( $main::lglobal{autoimagebutton},
			-balloonmsg =>
"Automatically show the image for the current page (focus shifts to image window)."
		);
	}
}

# New subroutine "update_img_lbl_values" extracted - Tue Mar 22 00:08:26 2011.
#
sub update_img_lbl_values {
	my $pnum = shift;
	my $textwindow = $main::textwindow;
	if ( defined $main::lglobal{img_num_label} ) {
		$main::lglobal{img_num_label}->configure( -text  => "Img:$pnum" );
		$main::lglobal{img_num_label}->configure( -width => ( length($pnum) + 5 ) );
	}
	my $label = $main::pagenumbers{"Pg$pnum"}{label};
	if ( defined $label && length $label ) {
		$main::lglobal{page_label}->configure( -text => ("Lbl: $label ") );
	} else {
		$main::lglobal{page_label}->configure( -text => ("Lbl: None ") );
	}
}

#
# New subroutine "update_proofers_button" extracted - Tue Mar 22 00:13:24 2011.
#
sub update_proofers_button {
	my $pnum = shift;
	my $textwindow = $main::textwindow;
	if ( ( scalar %main::proofers ) && ( defined( $main::lglobal{pagebutton} ) ) ) {
		unless ( defined( $main::lglobal{proofbutton} ) ) {
			$main::lglobal{proofbutton} =
			  $main::counter_frame->Label(
									 -text       => 'See Proofers',
									 -width      => 11,
									 -relief     => 'ridge',
									 -background => 'gray',
			  )->grid( -row => 1, -column => 8 );
			$main::lglobal{proofbutton}->bind(
				'<1>',
				sub {
					$main::lglobal{proofbutton}->configure( -relief => 'sunken' );
					showproofers();
				}
			);
			$main::lglobal{proofbutton}->bind(
				'<3>',
				sub {
					$main::lglobal{proofbutton}->configure( -relief => 'sunken' );
					&main::tglprfbar();
				}
			);
			_butbind( $main::lglobal{proofbutton} );
			$main::lglobal{statushelp}->attach( $main::lglobal{proofbutton},
							  -balloonmsg => "Proofers for the current page." );
		}
		{

			no warnings 'uninitialized';
			my ( $pg, undef ) = each %main::proofers;
			for my $round ( 1 .. 8 ) {
				last unless defined $main::proofers{$pg}->[$round];
				$main::lglobal{numrounds} = $round;
				$main::lglobal{proofbar}[$round]->configure(
					   -text => "  Round $round  $main::proofers{$pnum}->[$round]  " )
				  if $main::lglobal{proofbarvisible};
			}
		}
	}
}

## Make toolbar visible if invisible and vice versa
sub tglprfbar {
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	if ( $main::lglobal{proofbarvisible} ) {
		for ( @{ $main::lglobal{proofbar} } ) {
			$_->gridForget if defined $_;
		}
		$main::proofer_frame->packForget;
		my @geom = split /[x+]/, $top->geometry;
		$geom[1] -= $main::counter_frame->height;
		$top->geometry("$geom[0]x$geom[1]+$geom[2]+$geom[3]");
		$main::lglobal{proofbarvisible} = 0;
	} else {
		my $pnum = $main::lglobal{img_num_label}->cget( -text );
		$pnum =~ s/\D+//g;
		$main::proofer_frame->pack(
							  -before => $main::counter_frame,
							  -side   => 'bottom',
							  -anchor => 'sw',
							  -expand => 0
		);
		my @geom = split /[x+]/, $top->geometry;
		$geom[1] += $main::counter_frame->height;
		$top->geometry("$geom[0]x$geom[1]+$geom[2]+$geom[3]");
		{

			no warnings 'uninitialized';
			my ( $pg, undef ) = each %main::proofers;
			for my $round ( 1 .. 8 ) {
				last unless defined $main::proofers{$pg}->[$round];
				$main::lglobal{numrounds} = $round;
				$main::lglobal{proofbar}[$round] =
				  $main::proofer_frame->Label(
										 -text       => '',
										 -relief     => 'ridge',
										 -background => 'gray',
				  )->grid( -row => 1, -column => $round, -sticky => 'nw' );
				_butbind( $main::lglobal{proofbar}[$round] );
				$main::lglobal{proofbar}[$round]->bind(
					'<1>' => sub {
						$main::lglobal{proofbar}[$round]
						  ->configure( -relief => 'sunken' );
						my $proofer = $main::lglobal{proofbar}[$round]->cget( -text );
						$proofer =~ s/\s+Round \d\s+|\s+$//g;
						$proofer =~ s/\s/%20/g;
						&main::prfrmessage($proofer);
					}
				);
			}
		}
		$main::lglobal{proofbarvisible} = 1;
	}
	return;
}

sub showproofers {
	my $top = $main::top;
	if ( defined( $main::lglobal{prooferpop} ) ) {
		$main::lglobal{prooferpop}->deiconify;
		$main::lglobal{prooferpop}->raise;
		$main::lglobal{prooferpop}->focus;
	} else {
		$main::lglobal{prooferpop} = $top->Toplevel;
		$main::lglobal{prooferpop}->title('Proofers For This File');
		&main::initialize_popup_with_deletebinding('prooferpop');
		my $bframe = $main::lglobal{prooferpop}->Frame->pack;

		$bframe->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				my @ranges      = $main::lglobal{prfrrotextbox}->tagRanges('sel');
				my $range_total = @ranges;
				my $proofer     = '';
				if ($range_total) {
					$proofer =
					  $main::lglobal{prfrrotextbox}->get( $ranges[0], $ranges[1] );
					$proofer =~ s/^\s+//;
					$proofer =~ s/\s\s.*//s;
					$proofer =~ s/\s/%20/g;
				}
				&main::prfrmessage($proofer);
			},
			-text  => 'Send Message',
			-width => 12
		)->grid( -row => 1, -column => 1, -padx => 3, -pady => 3 );
		$bframe->Button(
						 -activebackground => $main::activecolor,
						 -command          => \&prfrbypage,
						 -text             => 'Page',
						 -width            => 12
		)->grid( -row => 2, -column => 1, -padx => 3, -pady => 3 );
		$bframe->Button(
						 -activebackground => $main::activecolor,
						 -command          => \&prfrbyname,
						 -text             => 'Name',
						 -width            => 12
		)->grid( -row => 1, -column => 2, -padx => 3, -pady => 3 );
		$bframe->Button(
						 -activebackground => $main::activecolor,
						 -command          => sub { prfrby(0) },
						 -text             => 'Total',
						 -width            => 12
		)->grid( -row => 2, -column => 2, -padx => 3, -pady => 3 );
		for my $round ( 1 .. $main::lglobal{numrounds} ) {
			$bframe->Button(
							 -activebackground => $main::activecolor,
							 -command => [ sub { prfrby( $_[0] ) }, $round ],
							 -text    => "Round $round",
							 -width   => 12
			  )->grid(
					   -row => ( ( $round + 1 ) % 2 ) + 1,
					   -column => int( ( $round + 5 ) / 2 ),
					   -padx   => 3,
					   -pady   => 3
			  );
		}
		my $frame =
		  $main::lglobal{prooferpop}->Frame->pack(
											 -anchor => 'nw',
											 -expand => 'yes',
											 -fill   => 'both'
		  );
		$main::lglobal{prfrrotextbox} =
		  $frame->Scrolled(
							'ROText',
							-scrollbars => 'se',
							-background => $main::bkgcolor,
							-font       => '{Courier} 10',
							-width      => 80,
							-height     => 40,
							-wrap       => 'none',
		  )->pack( -anchor => 'nw', -expand => 'yes', -fill => 'both' );
		delete $main::proofers{''};
		&main::drag( $main::lglobal{prfrrotextbox} );
		prfrbypage();
	}
}

sub prfrmessage {
	my $proofer = shift;
	if ( $proofer eq '' ) {
		runner($main::globalbrowserstart, $main::no_proofer_url);
	} else {
		runner($main::globalbrowserstart, "$main::yes_proofer_url$proofer");
	}
}

sub prfrhdr {
	my ($max) = @_;
	$main::lglobal{prfrrotextbox}->insert(
									 'end',
									 sprintf(
											  "%*s     ", ( -$max ), '   Name'
									 )
	);
	for ( 1 .. $main::lglobal{numrounds} ) {
		$main::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( " %-8s", "Round $_" ) );
	}
	$main::lglobal{prfrrotextbox}->insert( 'end', sprintf( " %-8s\n", 'Total' ) );
}

sub prfrbypage {
	my @max = split //, ( '8' x ( $main::lglobal{numrounds} + 1 ) );
	for my $page ( keys %main::proofers ) {
		for my $round ( 1 .. $main::lglobal{numrounds} ) {
			my $name = $main::proofers{$page}->[$round];
			next unless defined $name;
			$max[$round] = length $name if length $name > $max[$round];
		}
	}
	$main::lglobal{prfrrotextbox}->delete( '1.0', 'end' );
	$main::lglobal{prfrrotextbox}->insert( 'end', sprintf( "%-8s", 'Page' ) );
	for my $round ( 1 .. $main::lglobal{numrounds} ) {
		$main::lglobal{prfrrotextbox}->insert( 'end',
					 sprintf( " %*s", ( -$max[$round] - 2 ), "Round $round" ) );
	}
	$main::lglobal{prfrrotextbox}->insert( 'end', "\n" );
	delete $main::proofers{''};
	for my $page ( sort keys %main::proofers ) {
		$main::lglobal{prfrrotextbox}->insert( 'end', sprintf( "%-8s", $page ) );
		for my $round ( 1 .. $main::lglobal{numrounds} ) {
			$main::lglobal{prfrrotextbox}->insert(
							   'end',
							   sprintf( " %*s",
										( -$max[$round] - 2 ),
										$main::proofers{$page}->[$round] || '<none>' )
			);
		}
		$main::lglobal{prfrrotextbox}->insert( 'end', "\n" );
	}
}

sub prfrbyname {
	my ( $page, $prfr, %proofersort );
	my $max = 8;
	for my $page ( keys %main::proofers ) {
		for ( 1 .. $main::lglobal{numrounds} ) {
			$max = length $main::proofers{$page}->[$_]
			  if ( $main::proofers{$page}->[$_]
				   and length $main::proofers{$page}->[$_] > $max );
		}
	}
	$main::lglobal{prfrrotextbox}->delete( '1.0', 'end' );
	foreach my $page ( keys %main::proofers ) {
		for ( 1 .. $main::lglobal{numrounds} ) {
			$proofersort{ $main::proofers{$page}->[$_] }[$_]++
			  if $main::proofers{$page}->[$_];
			$proofersort{ $main::proofers{$page}->[$_] }[0]++
			  if $main::proofers{$page}->[$_];
		}
	}
	prfrhdr($max);
	delete $proofersort{''};
	foreach my $prfr ( sort { deaccent( lc($a) ) cmp deaccent( lc($b) ) }
					   ( keys %proofersort ) )
	{
		for ( 1 .. $main::lglobal{numrounds} ) {
			$proofersort{$prfr}[$_] = "0" unless $proofersort{$prfr}[$_];
		}
		$main::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( "%*s", ( -$max - 2 ), $prfr ) );
		for ( 1 .. $main::lglobal{numrounds} ) {
			$main::lglobal{prfrrotextbox}
			  ->insert( 'end', sprintf( " %8s", $proofersort{$prfr}[$_] ) );
		}
		$main::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( " %8s\n", $proofersort{$prfr}[0] ) );
	}
}

sub prfrby {
	my $which = shift;
	my ( $page, $prfr, %proofersort, %ptemp );
	my $max = 8;
	for my $page ( keys %main::proofers ) {
		for ( 1 .. $main::lglobal{numrounds} ) {
			$max = length $main::proofers{$page}->[$_]
			  if ( $main::proofers{$page}->[$_]
				   and length $main::proofers{$page}->[$_] > $max );
		}
	}
	$main::lglobal{prfrrotextbox}->delete( '1.0', 'end' );
	foreach my $page ( keys %main::proofers ) {
		for ( 1 .. $main::lglobal{numrounds} ) {
			$proofersort{ $main::proofers{$page}->[$_] }[$_]++
			  if $main::proofers{$page}->[$_];
			$proofersort{ $main::proofers{$page}->[$_] }[0]++
			  if $main::proofers{$page}->[$_];
		}
	}
	foreach my $prfr ( keys(%proofersort) ) {
		$ptemp{$prfr} = ( $proofersort{$prfr}[$which] || '0' );
	}
	delete $ptemp{''};
	prfrhdr($max);
	foreach my $prfr (
		sort {
			$ptemp{$b} <=> $ptemp{$a}
			  || ( deaccent( lc($a) ) cmp deaccent( lc($b) ) )
		} keys %ptemp
	  )
	{
		$main::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( "%*s", ( -$max - 2 ), $prfr ) );
		for ( 1 .. $main::lglobal{numrounds} ) {
			$main::lglobal{prfrrotextbox}->insert( 'end',
							sprintf( " %8s", $proofersort{$prfr}[$_] || '0' ) );
		}
		$main::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( " %8s\n", $proofersort{$prfr}[0] ) );
	}
}

1;