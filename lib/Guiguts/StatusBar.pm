package Guiguts::StatusBar;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw(&update_indicators &_updatesel &buildstatusbar &selection)
}

# Routine to update the status bar when something has changed.
#
sub update_indicators {
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	my ( $last_line, $last_col ) = split( /\./, $textwindow->index('end') );
	my ( $line,      $column )   = split( /\./, $textwindow->index('insert') );
	$::lglobal{current_line_label}
	  ->configure( -text => "Ln:$line/" . ( $last_line - 1 ) . " Col:$column" )
	  if ( $::lglobal{current_line_label} );
	my $mode             = $textwindow->OverstrikeMode;
	my $overstrke_insert = ' I ';
	if ($mode) {
		$overstrke_insert = ' O ';
	}
	$::lglobal{insert_overstrike_mode_label}
	  ->configure( -text => " $overstrke_insert " )
	  if ( $::lglobal{insert_overstrike_mode_label} );
	my $filename = $textwindow->FileName;
	$filename = 'No File Loaded' unless ( defined($filename) );
	$::lglobal{highlightlabel}->configure( -background => $main::highlightcolor )
	  if ( $main::scannos_highlighted );
	if ( $::lglobal{highlightlabel} ) {
		$::lglobal{highlightlabel}->configure( -background => 'gray' )
		  unless ( $main::scannos_highlighted );
	}
	$filename = &main::os_normal($filename);
	$::lglobal{global_filename} = $filename;

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
	if ( $filename ne 'No File Loaded' or defined $::lglobal{prepfile} ) {
		$::lglobal{img_num_label}->configure( -text => 'Img:001' )
		  if defined $::lglobal{img_num_label};
		$::lglobal{page_label}->configure( -text => ("Lbl: None ") )
		  if defined $::lglobal{page_label};
		if (    $main::auto_show_images
			 && $pnum )
		{
			if (    ( not defined $::lglobal{pageimageviewed} )
				 or ( $pnum ne "$::lglobal{pageimageviewed}" ) )
			{
				$::lglobal{pageimageviewed} = $pnum;
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
	if ( $::lglobal{geometryupdate} ) {
		&main::savesettings();
		$::lglobal{geometryupdate} = 0;
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
		if ( $::lglobal{showblocksize} && ( @ranges > 2 ) ) {
			my ( $srow, $scol ) = split /\./, $ranges[0];
			my ( $erow, $ecol ) = split /\./, $ranges[-1];
			$msg = ' R:'
			  . abs( $erow - $srow + 1 ) . ' C:'
			  . abs( $ecol - $scol ) . ' ';
		} else {
			$msg = " $ranges[0]--$ranges[-1] ";
			if ( $::lglobal{selectionpop} ) {
				$::lglobal{selsentry}->delete( '0', 'end' );
				$::lglobal{selsentry}->insert( 'end', $ranges[0] );
				$::lglobal{seleentry}->delete( '0', 'end' );
				$::lglobal{seleentry}->insert( 'end', $ranges[-1] );
			}
		}
	} else {
		$msg = ' No Selection ';
	}
	my $msgln = length($msg);

	#FIXME
	no warnings 'uninitialized';
	$::lglobal{selmaxlength} = $msgln if ( $msgln > $::lglobal{selmaxlength} );
	$::lglobal{selectionlabel}
	  ->configure( -text => $msg, -width => $::lglobal{selmaxlength} );
	&main::update_indicators();
	$textwindow->_lineupdate;
}

## Status Bar
sub buildstatusbar {
	my ($textwindow,$top)=@_;
	
	$::lglobal{current_line_label} =
	  $main::counter_frame->Label(
							 -text       => 'Ln: 1/1 - Col: 0',
							 -width      => 20,
							 -relief     => 'ridge',
							 -background => 'gray',
	  )->grid( -row => 1, -column => 0, -sticky => 'nw' );
	$::lglobal{current_line_label}->bind(
		'<1>',
		sub {
			$::lglobal{current_line_label}->configure( -relief => 'sunken' );
			&main::gotoline();
			&main::update_indicators();
		}
	);
	$::lglobal{current_line_label}->bind(
		'<3>',
		sub {
			if   ($main::vislnnm) { $main::vislnnm = 0 }
			else            { $main::vislnnm = 1 }
			$textwindow->showlinenum if $main::vislnnm;
			$textwindow->hidelinenum unless $main::vislnnm;
			&main::savesettings();
		}
	);
	$::lglobal{selectionlabel} =
	  $main::counter_frame->Label(
							 -text       => ' No Selection ',
							 -relief     => 'ridge',
							 -background => 'gray',
	  )->grid( -row => 1, -column => 10, -sticky => 'nw' );
	$::lglobal{selectionlabel}->bind(
		'<1>',
		sub {
			if ( $::lglobal{showblocksize} ) {
				$::lglobal{showblocksize} = 0;
			} else {
				$::lglobal{showblocksize} = 1;
			}
		}
	);
	$::lglobal{selectionlabel}->bind( '<Double-1>', sub { &main::selection() } );
	$::lglobal{selectionlabel}->bind(
		'<3>',
		sub {
			if ( $textwindow->markExists('selstart') ) {
				$textwindow->tagAdd( 'sel', 'selstart', 'selend' );
			}
		}
	);
	$::lglobal{selectionlabel}->bind(
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

	$::lglobal{highlightlabel} =
	  $main::counter_frame->Label(
							 -text       => 'H',
							 -width      => 2,
							 -relief     => 'ridge',
							 -background => 'gray',
	  )->grid( -row => 1, -column => 1 );

	$::lglobal{highlightlabel}->bind(
		'<1>',
		sub {
			if ( $main::scannos_highlighted ) {
				$main::scannos_highlighted          = 0;
				$::lglobal{highlighttempcolor} = 'gray';
			} else {
				&main::scannosfile() unless $main::scannoslist;
				return unless $main::scannoslist;
				$main::scannos_highlighted          = 1;
				$::lglobal{highlighttempcolor} = $main::highlightcolor;
			}
			&main::highlight_scannos();
		}
	);
	$::lglobal{highlightlabel}->bind( '<3>', sub { &main::scannosfile() } );
	$::lglobal{highlightlabel}->bind(
		'<Enter>',
		sub {
			$::lglobal{highlighttempcolor} =
			  $::lglobal{highlightlabel}->cget( -background );
			$::lglobal{highlightlabel}->configure( -background => $main::activecolor );
			$::lglobal{highlightlabel}->configure( -relief     => 'raised' );
		}
	);
	$::lglobal{highlightlabel}->bind(
		'<Leave>',
		sub {
			$::lglobal{highlightlabel}
			  ->configure( -background => $::lglobal{highlighttempcolor} );
			$::lglobal{highlightlabel}->configure( -relief => 'ridge' );
		}
	);
	$::lglobal{highlightlabel}->bind(
		'<ButtonRelease-1>',
		sub {
			$::lglobal{highlightlabel}->configure( -relief => 'raised' );
		}
	);
	$::lglobal{insert_overstrike_mode_label} =
	  $main::counter_frame->Label(
							 -text       => '',
							 -relief     => 'ridge',
							 -background => 'gray',
							 -width      => 2,
	  )->grid( -row => 1, -column => 9, -sticky => 'nw' );
	$::lglobal{insert_overstrike_mode_label}->bind(
		'<1>',
		sub {
			$::lglobal{insert_overstrike_mode_label}
			  ->configure( -relief => 'sunken' );
			if ( $textwindow->OverstrikeMode ) {
				$textwindow->OverstrikeMode(0);
			} else {
				$textwindow->OverstrikeMode(1);
			}
		}
	);
	$::lglobal{ordinallabel} =
	  $main::counter_frame->Label(
							 -text       => '',
							 -relief     => 'ridge',
							 -background => 'gray',
							 -anchor     => 'w',
	  )->grid( -row => 1, -column => 11 );

	$::lglobal{ordinallabel}->bind(
		'<1>',
		sub {
			$::lglobal{ordinallabel}->configure( -relief => 'sunken' );
			$::lglobal{longordlabel} = $::lglobal{longordlabel} ? 0 : 1;
			&main::update_indicators();
		}
	);
	_butbind($_)
	  for ( $::lglobal{insert_overstrike_mode_label},
			$::lglobal{current_line_label},
			$::lglobal{selectionlabel},
			$::lglobal{ordinallabel} );
	$::lglobal{statushelp} = $top->Balloon( -initwait => 1000 );
	$::lglobal{statushelp}->attach( $::lglobal{current_line_label},
			 -balloonmsg =>
			   "Line number out of total lines\nand column number of cursor." );
	$::lglobal{statushelp}->attach( $::lglobal{insert_overstrike_mode_label},
						  -balloonmsg => 'Typeover Mode. (Insert/Overstrike)' );
	$::lglobal{statushelp}->attach( $::lglobal{ordinallabel},
		-balloonmsg =>
"Decimal & Hexadecimal ordinal of the\ncharacter to the right of the cursor."
	);
	$::lglobal{statushelp}->attach( $::lglobal{highlightlabel},
					-balloonmsg =>
					  "Highlight words from list. Right click to select list" );
	$::lglobal{statushelp}->attach( $::lglobal{selectionlabel},
		-balloonmsg =>
"Start and end points of selection -- Or, total lines.columns of selection"
	);
}

sub update_img_button {
	my $pnum = shift;
	my $textwindow = $main::textwindow;
	unless ( defined( $::lglobal{img_num_label} ) ) {
		$::lglobal{img_num_label} =
		  $main::counter_frame->Label(
								 -text       => "Img:$pnum",
								 -width      => 7,
								 -background => 'gray',
								 -relief     => 'ridge',
		  )->grid( -row => 1, -column => 2, -sticky => 'nw' );
		$::lglobal{img_num_label}->bind(
			'<1>',
			sub {
				$::lglobal{img_num_label}->configure( -relief => 'sunken' );
				&main::gotopage();
				&main::update_indicators();
			}
		);
		$::lglobal{img_num_label}->bind(
			'<3>',
			sub {
				$::lglobal{img_num_label}->configure( -relief => 'sunken' );
				&main::viewpagenums();
				&main::update_indicators();
			}
		);
		_butbind( $::lglobal{img_num_label} );
		$::lglobal{statushelp}->attach( $::lglobal{img_num_label},
						   -balloonmsg => "Image/Page name for current page." );
	}

	return ();
}

sub update_label_button {
	my $textwindow = $main::textwindow;
	unless ( $::lglobal{page_label} ) {
		$::lglobal{page_label} =
		  $main::counter_frame->Label(
								 -text       => 'Lbl: None ',
								 -background => 'gray',
								 -relief     => 'ridge',
		  )->grid( -row => 1, -column => 7 );
		_butbind( $::lglobal{page_label} );
		$::lglobal{page_label}->bind(
			'<1>',
			sub {
				$::lglobal{page_label}->configure( -relief => 'sunken' );
				&main::gotolabel();
			}
		);
		$::lglobal{page_label}->bind(
			'<3>',
			sub {
				$::lglobal{page_label}->configure( -relief => 'sunken' );
				&main::pageadjust();
			}
		);
		$::lglobal{statushelp}->attach( $::lglobal{page_label},
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
	if ( $::lglobal{longordlabel} ) {
		my $msg = charnames::viacode($ordinal) || '';
		my $msgln = length(" Dec $ordinal : Hex $hexi : $msg ");

		no warnings 'uninitialized';
		$::lglobal{ordmaxlength} = $msgln
		  if ( $msgln > $::lglobal{ordmaxlength} );
		$::lglobal{ordinallabel}->configure(
								   -text => " Dec $ordinal : Hex $hexi : $msg ",
								   -width   => $::lglobal{ordmaxlength},
								   -justify => 'left'
		);

	} else {
		$::lglobal{ordinallabel}->configure(
										  -text => " Dec $ordinal : Hex $hexi ",
										  -width => 18
		) if ( $::lglobal{ordinallabel} );
	}
}

sub update_prev_img_button {
	my $textwindow = $main::textwindow;
	unless ( defined( $::lglobal{previmagebutton} ) ) {
		$::lglobal{previmagebutton} =
		  $main::counter_frame->Label(
								 -text       => '<',
								 -width      => 1,
								 -relief     => 'ridge',
								 -background => 'gray',
		  )->grid( -row => 1, -column => 3 );
		$::lglobal{previmagebutton}->bind(
			'<1>',
			sub {
				$::lglobal{previmagebutton}->configure( -relief => 'sunken' );
				$::lglobal{showthispageimage} = 1;
				&main::viewpagenums() unless $::lglobal{pnumpop};
				$textwindow->focus;
				&main::pgprevious();

			}
		);
		_butbind( $::lglobal{previmagebutton} );
		$::lglobal{statushelp}->attach( $::lglobal{previmagebutton},
			-balloonmsg =>
"Move to previous page in text and open image corresponding to previous current page in an external viewer."
		);
	}
}

# New subroutine "update_see_img_button" extracted - Mon Mar 21 23:23:36 2011.
#
sub update_see_img_button {
	my $textwindow = $main::textwindow;
	unless ( defined( $::lglobal{pagebutton} ) ) {
		$::lglobal{pagebutton} =
		  $main::counter_frame->Label(
								 -text       => 'See Img',
								 -width      => 7,
								 -relief     => 'ridge',
								 -background => 'gray',
		  )->grid( -row => 1, -column => 4 );
		$::lglobal{pagebutton}->bind(
			'<1>',
			sub {
				$::lglobal{pagebutton}->configure( -relief => 'sunken' );
				my $pagenum = &main::get_page_number();
				if ( defined $::lglobal{pnumpop} ) {
					$::lglobal{pagenumentry}->delete( '0', 'end' );
					$::lglobal{pagenumentry}->insert( 'end', "Pg" . $pagenum );
				}
				&main::openpng($textwindow,$pagenum);
			}
		);
		$::lglobal{pagebutton}->bind( '<3>', sub { &main::setpngspath() } );
		_butbind( $::lglobal{pagebutton} );
		$::lglobal{statushelp}->attach( $::lglobal{pagebutton},
			 -balloonmsg =>
			   "Open Image corresponding to current page in an external viewer."
		);
	}
}

sub update_next_img_button {
	my $textwindow = $main::textwindow;
	unless ( defined( $::lglobal{nextimagebutton} ) ) {
		$::lglobal{nextimagebutton} =
		  $main::counter_frame->Label(
								 -text       => '>',
								 -width      => 1,
								 -relief     => 'ridge',
								 -background => 'gray',
		  )->grid( -row => 1, -column => 5 );
		$::lglobal{nextimagebutton}->bind(
			'<1>',
			sub {
				$::lglobal{nextimagebutton}->configure( -relief => 'sunken' );
				$::lglobal{showthispageimage} = 1;
				&main::viewpagenums() unless $::lglobal{pnumpop};
				$textwindow->focus;
				&main::pgnext();
			}
		);
		_butbind( $::lglobal{nextimagebutton} );
		$::lglobal{statushelp}->attach( $::lglobal{nextimagebutton},
			-balloonmsg =>
"Move to next page in text and open image corresponding to next current page in an external viewer."
		);
	}
}

sub update_auto_img_button {
	my $textwindow = $main::textwindow;
	unless ( defined( $::lglobal{autoimagebutton} ) ) {
		$::lglobal{autoimagebutton} =
		  $main::counter_frame->Label(
								 -text       => 'Auto Img',
								 -width      => 9,
								 -relief     => 'ridge',
								 -background => 'gray',
		  )->grid( -row => 1, -column => 6 );
		if ($main::auto_show_images) {
			$::lglobal{autoimagebutton}->configure( -text => 'No Img' );
		}
		$::lglobal{autoimagebutton}->bind(
			'<1>',
			sub {
				$main::auto_show_images = 1 - $main::auto_show_images;
				if ($main::auto_show_images) {
					$::lglobal{autoimagebutton}->configure( -relief => 'sunken' );
					$::lglobal{autoimagebutton}->configure( -text   => 'No Img' );
					$::lglobal{statushelp}->attach( $::lglobal{autoimagebutton},
						-balloonmsg =>
"Stop automatically showing the image for the current page."
					);

				} else {
					$::lglobal{autoimagebutton}->configure( -relief => 'sunken' );
					$::lglobal{autoimagebutton}->configure( -text => 'Auto Img' );
					$::lglobal{statushelp}->attach( $::lglobal{autoimagebutton},
						-balloonmsg =>
"Automatically show the image for the current page (focus shifts to image window)."
					);
				}
			}
		);
		_butbind( $::lglobal{autoimagebutton} );
		$::lglobal{statushelp}->attach( $::lglobal{autoimagebutton},
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
	if ( defined $::lglobal{img_num_label} ) {
		$::lglobal{img_num_label}->configure( -text  => "Img:$pnum" );
		$::lglobal{img_num_label}->configure( -width => ( length($pnum) + 5 ) );
	}
	my $label = $main::pagenumbers{"Pg$pnum"}{label};
	if ( defined $label && length $label ) {
		$::lglobal{page_label}->configure( -text => ("Lbl: $label ") );
	} else {
		$::lglobal{page_label}->configure( -text => ("Lbl: None ") );
	}
}

#
# New subroutine "update_proofers_button" extracted - Tue Mar 22 00:13:24 2011.
#
sub update_proofers_button {
	my $pnum = shift;
	my $textwindow = $main::textwindow;
	if ( ( scalar %main::proofers ) && ( defined( $::lglobal{pagebutton} ) ) ) {
		unless ( defined( $::lglobal{proofbutton} ) ) {
			$::lglobal{proofbutton} =
			  $main::counter_frame->Label(
									 -text       => 'See Proofers',
									 -width      => 11,
									 -relief     => 'ridge',
									 -background => 'gray',
			  )->grid( -row => 1, -column => 8 );
			$::lglobal{proofbutton}->bind(
				'<1>',
				sub {
					$::lglobal{proofbutton}->configure( -relief => 'sunken' );
					showproofers();
				}
			);
			$::lglobal{proofbutton}->bind(
				'<3>',
				sub {
					$::lglobal{proofbutton}->configure( -relief => 'sunken' );
					&main::tglprfbar();
				}
			);
			_butbind( $::lglobal{proofbutton} );
			$::lglobal{statushelp}->attach( $::lglobal{proofbutton},
							  -balloonmsg => "Proofers for the current page." );
		}
		{

			no warnings 'uninitialized';
			my ( $pg, undef ) = each %main::proofers;
			for my $round ( 1 .. 8 ) {
				last unless defined $main::proofers{$pg}->[$round];
				$::lglobal{numrounds} = $round;
				$::lglobal{proofbar}[$round]->configure(
					   -text => "  Round $round  $main::proofers{$pnum}->[$round]  " )
				  if $::lglobal{proofbarvisible};
			}
		}
	}
}

## Make toolbar visible if invisible and vice versa
sub tglprfbar {
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	if ( $::lglobal{proofbarvisible} ) {
		for ( @{ $::lglobal{proofbar} } ) {
			$_->gridForget if defined $_;
		}
		$main::proofer_frame->packForget;
		my @geom = split /[x+]/, $top->geometry;
		$geom[1] -= $main::counter_frame->height;
		$top->geometry("$geom[0]x$geom[1]+$geom[2]+$geom[3]");
		$::lglobal{proofbarvisible} = 0;
	} else {
		my $pnum = $::lglobal{img_num_label}->cget( -text );
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
				$::lglobal{numrounds} = $round;
				$::lglobal{proofbar}[$round] =
				  $main::proofer_frame->Label(
										 -text       => '',
										 -relief     => 'ridge',
										 -background => 'gray',
				  )->grid( -row => 1, -column => $round, -sticky => 'nw' );
				_butbind( $::lglobal{proofbar}[$round] );
				$::lglobal{proofbar}[$round]->bind(
					'<1>' => sub {
						$::lglobal{proofbar}[$round]
						  ->configure( -relief => 'sunken' );
						my $proofer = $::lglobal{proofbar}[$round]->cget( -text );
						$proofer =~ s/\s+Round \d\s+|\s+$//g;
						$proofer =~ s/\s/%20/g;
						&main::prfrmessage($proofer);
					}
				);
			}
		}
		$::lglobal{proofbarvisible} = 1;
	}
	return;
}

sub showproofers {
	my $top = $main::top;
	if ( defined( $::lglobal{prooferpop} ) ) {
		$::lglobal{prooferpop}->deiconify;
		$::lglobal{prooferpop}->raise;
		$::lglobal{prooferpop}->focus;
	} else {
		$::lglobal{prooferpop} = $top->Toplevel;
		$::lglobal{prooferpop}->title('Proofers For This File');
		&main::initialize_popup_with_deletebinding('prooferpop');
		my $bframe = $::lglobal{prooferpop}->Frame->pack;

		$bframe->Button(
			-activebackground => $main::activecolor,
			-command          => sub {
				my @ranges      = $::lglobal{prfrrotextbox}->tagRanges('sel');
				my $range_total = @ranges;
				my $proofer     = '';
				if ($range_total) {
					$proofer =
					  $::lglobal{prfrrotextbox}->get( $ranges[0], $ranges[1] );
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
		for my $round ( 1 .. $::lglobal{numrounds} ) {
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
		  $::lglobal{prooferpop}->Frame->pack(
											 -anchor => 'nw',
											 -expand => 'yes',
											 -fill   => 'both'
		  );
		$::lglobal{prfrrotextbox} =
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
		&main::drag( $::lglobal{prfrrotextbox} );
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
	$::lglobal{prfrrotextbox}->insert(
									 'end',
									 sprintf(
											  "%*s     ", ( -$max ), '   Name'
									 )
	);
	for ( 1 .. $::lglobal{numrounds} ) {
		$::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( " %-8s", "Round $_" ) );
	}
	$::lglobal{prfrrotextbox}->insert( 'end', sprintf( " %-8s\n", 'Total' ) );
}

sub prfrbypage {
	my @max = split //, ( '8' x ( $::lglobal{numrounds} + 1 ) );
	for my $page ( keys %main::proofers ) {
		for my $round ( 1 .. $::lglobal{numrounds} ) {
			my $name = $main::proofers{$page}->[$round];
			next unless defined $name;
			$max[$round] = length $name if length $name > $max[$round];
		}
	}
	$::lglobal{prfrrotextbox}->delete( '1.0', 'end' );
	$::lglobal{prfrrotextbox}->insert( 'end', sprintf( "%-8s", 'Page' ) );
	for my $round ( 1 .. $::lglobal{numrounds} ) {
		$::lglobal{prfrrotextbox}->insert( 'end',
					 sprintf( " %*s", ( -$max[$round] - 2 ), "Round $round" ) );
	}
	$::lglobal{prfrrotextbox}->insert( 'end', "\n" );
	delete $main::proofers{''};
	for my $page ( sort keys %main::proofers ) {
		$::lglobal{prfrrotextbox}->insert( 'end', sprintf( "%-8s", $page ) );
		for my $round ( 1 .. $::lglobal{numrounds} ) {
			$::lglobal{prfrrotextbox}->insert(
							   'end',
							   sprintf( " %*s",
										( -$max[$round] - 2 ),
										$main::proofers{$page}->[$round] || '<none>' )
			);
		}
		$::lglobal{prfrrotextbox}->insert( 'end', "\n" );
	}
}

sub prfrbyname {
	my ( $page, $prfr, %proofersort );
	my $max = 8;
	for my $page ( keys %main::proofers ) {
		for ( 1 .. $::lglobal{numrounds} ) {
			$max = length $main::proofers{$page}->[$_]
			  if ( $main::proofers{$page}->[$_]
				   and length $main::proofers{$page}->[$_] > $max );
		}
	}
	$::lglobal{prfrrotextbox}->delete( '1.0', 'end' );
	foreach my $page ( keys %main::proofers ) {
		for ( 1 .. $::lglobal{numrounds} ) {
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
		for ( 1 .. $::lglobal{numrounds} ) {
			$proofersort{$prfr}[$_] = "0" unless $proofersort{$prfr}[$_];
		}
		$::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( "%*s", ( -$max - 2 ), $prfr ) );
		for ( 1 .. $::lglobal{numrounds} ) {
			$::lglobal{prfrrotextbox}
			  ->insert( 'end', sprintf( " %8s", $proofersort{$prfr}[$_] ) );
		}
		$::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( " %8s\n", $proofersort{$prfr}[0] ) );
	}
}

sub prfrby {
	my $which = shift;
	my ( $page, $prfr, %proofersort, %ptemp );
	my $max = 8;
	for my $page ( keys %main::proofers ) {
		for ( 1 .. $::lglobal{numrounds} ) {
			$max = length $main::proofers{$page}->[$_]
			  if ( $main::proofers{$page}->[$_]
				   and length $main::proofers{$page}->[$_] > $max );
		}
	}
	$::lglobal{prfrrotextbox}->delete( '1.0', 'end' );
	foreach my $page ( keys %main::proofers ) {
		for ( 1 .. $::lglobal{numrounds} ) {
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
		$::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( "%*s", ( -$max - 2 ), $prfr ) );
		for ( 1 .. $::lglobal{numrounds} ) {
			$::lglobal{prfrrotextbox}->insert( 'end',
							sprintf( " %8s", $proofersort{$prfr}[$_] || '0' ) );
		}
		$::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( " %8s\n", $proofersort{$prfr}[0] ) );
	}
}

# Pop up window allowing tracking and auto reselection of last selection
sub selection {
	my $top = $main::top;
	my $textwindow = $main::textwindow;
	my ( $start, $end );
	if ( $::lglobal{selectionpop} ) {
		$::lglobal{selectionpop}->deiconify;
		$::lglobal{selectionpop}->raise;
	} else {
		$::lglobal{selectionpop} = $top->Toplevel;
		$::lglobal{selectionpop}->title('Select Line.Col');
		&main::initialize_popup_without_deletebinding('selectionpop');

		$::lglobal{selectionpop}->resizable( 'no', 'no' );
		my $frame =
		  $::lglobal{selectionpop}
		  ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		$frame->Label( -text => 'Start Line.Col' )
		  ->grid( -row => 1, -column => 1 );
		$::lglobal{selsentry} = $frame->Entry(
			-background   => $main::bkgcolor,
			-width        => 15,
			-textvariable => \$start,
			-validate     => 'focusout',
			-vcmd         => sub {
				return 0 unless ( $_[0] =~ m{^\d+\.\d+$} );
				return 1;
			},
		)->grid( -row => 1, -column => 2 );
		$frame->Label( -text => 'End Line.Col' )
		  ->grid( -row => 2, -column => 1 );
		$::lglobal{seleentry} = $frame->Entry(
			-background   => $main::bkgcolor,
			-width        => 15,
			-textvariable => \$end,
			-validate     => 'focusout',
			-vcmd         => sub {
				return 0 unless ( $_[0] =~ m{^\d+\.\d+$} );
				return 1;
			},
		)->grid( -row => 2, -column => 2 );
		my $frame1 =
		  $::lglobal{selectionpop}
		  ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		my $button = $frame1->Button(
			-text    => 'OK',
			-width   => 8,
			-command => sub {
				return
				  unless (    ( $start =~ m{^\d+\.\d+$} )
						   && ( $end =~ m{^\d+\.\d+$} ) );
				$textwindow->tagRemove( 'sel', '1.0', 'end' );
				$textwindow->tagAdd( 'sel', $start, $end );
				$textwindow->markSet( 'selstart', $start );
				$textwindow->markSet( 'selend',   $end );
				$textwindow->focus;
			},
		)->grid( -row => 1, -column => 1 );
		$frame1->Button(
			-text    => 'Close',
			-width   => 8,
			-command => sub {
				$::lglobal{selectionpop}->destroy;
				undef $::lglobal{selectionpop};
				undef $::lglobal{selsentry};
				undef $::lglobal{seleentry};
			},
		)->grid( -row => 1, -column => 2 );
		$::lglobal{selectionpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$::lglobal{selectionpop}->destroy;
				undef $::lglobal{selectionpop};
				undef $::lglobal{selsentry};
				undef $::lglobal{seleentry};
			}
		);
	}
	my @ranges = $textwindow->tagRanges('sel');
	if (@ranges) {
		$::lglobal{selsentry}->delete( '0', 'end' );
		$::lglobal{selsentry}->insert( 'end', $ranges[0] );
		$::lglobal{seleentry}->delete( '0', 'end' );
		$::lglobal{seleentry}->insert( 'end', $ranges[-1] );
	} elsif ( $textwindow->markExists('selstart') ) {
		$::lglobal{selsentry}->delete( '0', 'end' );
		$::lglobal{selsentry}->insert( 'end', $textwindow->index('selstart') );
		$::lglobal{seleentry}->delete( '0', 'end' );
		$::lglobal{seleentry}->insert( 'end', $textwindow->index('selend') );
	}
	$::lglobal{selsentry}->selectionRange( 0, 'end' );
	return
}



1;