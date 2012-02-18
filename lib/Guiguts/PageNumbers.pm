package Guiguts::PageNumbers;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw( &viewpagenums &gotolabel &pnumadjust)
}

## Toggle visible page markers. This is not line numbers but marks for pages.
sub viewpagenums {
	my $textwindow = $main::textwindow;
	if ( $::lglobal{seepagenums} ) {
		$::lglobal{seepagenums} = 0;
		my @marks = $textwindow->markNames;
		for ( sort @marks ) {
			if ( $_ =~ m{Pg(\S+)} ) {
				my $pagenum = " Pg$1 ";
				$textwindow->ntdelete( $_, "$_ +@{[length $pagenum]}c" );
			}
		}
		$textwindow->tagRemove( 'pagenum', '1.0', 'end' );
		if ( $::lglobal{pnumpop} ) {
			$main::geometryhash{pnumpop} = $::lglobal{pnumpop}->geometry;
			$::lglobal{pnumpop}->destroy;
			undef $::lglobal{pnumpop};
		}
	} else {
		$::lglobal{seepagenums} = 1;
		my @marks = $textwindow->markNames;
		for ( sort @marks ) {
			if ( $_ =~ m{Pg(\S+)} ) {
				my $pagenum = " Pg$1 ";
				$textwindow->ntinsert( $_, $pagenum );
				$textwindow->tagAdd( 'pagenum', $_,
									 "$_ +@{[length $pagenum]}c" );
			}
		}
		&main::pnumadjust();
	}
}

## Pop up a window which will allow jumping directly to a specified page
sub gotolabel {
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	unless ( defined( $::lglobal{gotolabpop} ) ) {
		return unless %main::pagenumbers;
		for ( keys(%main::pagenumbers) ) {
			$::lglobal{pagedigits} = ( length($_) - 2 );
			last;
		}
		$::lglobal{gotolabpop} = $top->DialogBox(
			-buttons => [qw[Ok Cancel]],
			-title   => 'Goto Page Label',
			-popover => $top,
			-command => sub {
				if ( $_[0] eq 'Ok' ) {
					my $mark;
					for ( keys %main::pagenumbers ) {
						if (    $main::pagenumbers{$_}{label}
							 && $main::pagenumbers{$_}{label} eq $::lglobal{lastlabel} )
						{
							$mark = $_;
							last;
						}
					}
					unless ($mark) {
						$::lglobal{gotolabpop}->bell;
						$::lglobal{gotolabpop}->destroy;
						undef $::lglobal{gotolabpop};
						return;
					}
					my $index = $textwindow->index($mark);
					$textwindow->markSet( 'insert', "$index +1l linestart" );
					$textwindow->see('insert');
					$textwindow->focus;
					update_indicators();
					$::lglobal{gotolabpop}->destroy;
					undef $::lglobal{gotolabpop};
				} else {
					$::lglobal{gotolabpop}->destroy;
					undef $::lglobal{gotolabpop};
				}
			}
		);
		$::lglobal{gotolabpop}->resizable( 'no', 'no' );
		my $frame = $::lglobal{gotolabpop}->Frame->pack( -fill => 'x' );
		$frame->Label( -text => 'Enter Label: ' )->pack( -side => 'left' );
		$::lglobal{lastlabel} = 'Pg ' unless $::lglobal{lastlabel};
		my $entry = $frame->Entry(
								   -background   => $main::bkgcolor,
								   -width        => 25,
								   -textvariable => \$::lglobal{lastlabel}
		)->pack( -side => 'left', -fill => 'x' );
		$::lglobal{gotolabpop}->Advertise( entry => $entry );
		$::lglobal{gotolabpop}->Popup;
		$::lglobal{gotolabpop}->Subwidget('entry')->focus;
		$::lglobal{gotolabpop}->Subwidget('entry')->selectionRange( 0, 'end' );
		$::lglobal{gotolabpop}->Wait;
	}
}

## Page Number Adjust
sub pnumadjust {
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	
	my $mark = $textwindow->index('current');
	while ( $mark = $textwindow->markPrevious($mark) ) {
		if ( $mark =~ /Pg(\S+)/ ) {
			last;
		}
	}
	if ( not defined $mark ) {
		$mark = $textwindow->index('current');
	}
	if ( not defined $mark ) {
		$mark = "1.0";
	}
	if ( not $mark =~ /Pg(\S+)/ ) {
		while ( $mark = $textwindow->markNext($mark) ) {
			if ( $mark =~ /Pg(\S+)/ ) {
				last;
			}
		}

	}
	$textwindow->markSet( 'insert', $mark || '1.0' );
	if ( $::lglobal{pnumpop} ) {
		$::lglobal{pnumpop}->deiconify;
		$::lglobal{pnumpop}->raise;
		$::lglobal{pagenumentry}->configure( -text => $mark );
	} else {
		$::lglobal{pnumpop} = $top->Toplevel;
		::initialize_popup_without_deletebinding('pnumpop');
		$::lglobal{pnumpop}->title('Adjust Page Markers');
		my $frame2 = $::lglobal{pnumpop}->Frame->pack( -pady => 5 );
		my $upbutton =
		  $frame2->Button(
						   -activebackground => $::activecolor,
						   -command          => \&::pmoveup,
						   -text             => 'Move Up',
						   -width            => 10
		  )->grid( -row => 1, -column => 2 );
		my $leftbutton =
		  $frame2->Button(
						   -activebackground => $::activecolor,
						   -command          => \&::pmoveleft,
						   -text             => 'Move Left',
						   -width            => 10
		  )->grid( -row => 2, -column => 1 );
		$::lglobal{pagenumentry} =
		  $frame2->Entry(
						  -background => 'yellow',
						  -relief     => 'sunken',
						  -text       => $mark,
						  -width      => 10,
						  -justify    => 'center',
		  )->grid( -row => 2, -column => 2 );
		my $rightbutton =
		  $frame2->Button(
						   -activebackground => $::activecolor,
						   -command          => \&::pmoveright,
						   -text             => 'Move Right',
						   -width            => 10
		  )->grid( -row => 2, -column => 3 );
		my $downbutton =
		  $frame2->Button(
						   -activebackground => $::activecolor,
						   -command          => \&::pmovedown,
						   -text             => 'Move Down',
						   -width            => 10
		  )->grid( -row => 3, -column => 2 );
		my $frame3 = $::lglobal{pnumpop}->Frame->pack( -pady => 4 );
		my $prevbutton =
		  $frame3->Button(
						   -activebackground => $::activecolor,
						   -command          => \&::pgprevious,
						   -text             => 'Previous Marker',
						   -width            => 14
		  )->grid( -row => 1, -column => 1 );
		my $nextbutton =
		  $frame3->Button(
						   -activebackground => $::activecolor,
						   -command          => \&::pgnext,
						   -text             => 'Next Marker',
						   -width            => 14
		  )->grid( -row => 1, -column => 2 );
		my $frame4 = $::lglobal{pnumpop}->Frame->pack( -pady => 5 );
		$frame4->Label( -text => 'Adjust Page Offset', )
		  ->grid( -row => 1, -column => 1 );
		$::lglobal{pagerenumoffset} =
		  $frame4->Spinbox(
							-textvariable => 0,
							-from         => -999,
							-to           => 999,
							-increment    => 1,
							-width        => 6,
		  )->grid( -row => 2, -column => 1 );
		$frame4->Button(
						 -activebackground => $::activecolor,
						 -command          => \&::pgrenum,
						 -text             => 'Renumber',
						 -width            => 12
		)->grid( -row => 3, -column => 1, -pady => 3 );
		my $frame5 = $::lglobal{pnumpop}->Frame->pack( -pady => 5 );
		$frame5->Button(
						 -activebackground => $::activecolor,
						 -command => sub { $textwindow->bell unless ::pageadd() },
						 -text    => 'Add',
						 -width   => 8
		)->grid( -row => 1, -column => 1 );
		$frame5->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				my $insert = $textwindow->index('insert');
				unless ( ::pageadd() ) {
					;
					$::lglobal{pagerenumoffset}
					  ->configure( -textvariable => '1' );
					$textwindow->markSet( 'insert', $insert );
					::pgrenum();
					$textwindow->markSet( 'insert', $insert );
					::pageadd();
				}
				$textwindow->markSet( 'insert', $insert );
			},
			-text  => 'Insert',
			-width => 8
		)->grid( -row => 1, -column => 2 );
		$frame5->Button(
						 -activebackground => $::activecolor,
						 -command          => \&::pageremove,
						 -text             => 'Remove',
						 -width            => 8
		)->grid( -row => 1, -column => 3 );
		my $frame6 = $::lglobal{pnumpop}->Frame->pack( -pady => 5 );
		$frame6->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				viewpagenums();
				$textwindow->addGlobStart;
				my @marks = $textwindow->markNames;
				for ( sort @marks ) {
					if ( $_ =~ /Pg(\S+)/ ) {
						my $pagenum = '[Pg ' . $1 . ']';
						$textwindow->insert( $_, $pagenum );
					}
				}
				$textwindow->addGlobEnd;
			},
			-text  => 'Insert Page Markers',
			-width => 20,
		)->grid( -row => 1, -column => 1 );

		$::lglobal{pnumpop}->bind( $::lglobal{pnumpop}, '<Up>'    => \&::pmoveup );
		$::lglobal{pnumpop}->bind( $::lglobal{pnumpop}, '<Left>'  => \&::pmoveleft );
		$::lglobal{pnumpop}->bind( $::lglobal{pnumpop}, '<Right>' => \&::pmoveright );
		$::lglobal{pnumpop}->bind( $::lglobal{pnumpop}, '<Down>'  => \&::pmovedown );
		$::lglobal{pnumpop}->bind( $::lglobal{pnumpop}, '<Prior>' => \&::pgprevious );
		$::lglobal{pnumpop}->bind( $::lglobal{pnumpop}, '<Next>'  => \&::pgnext );
		$::lglobal{pnumpop}
		  ->bind( $::lglobal{pnumpop}, '<Delete>' => \&::pageremove );
		$::lglobal{pnumpop}->protocol(
			'WM_DELETE_WINDOW' => sub {

				#$geometryhash{pnumpop} = $::lglobal{pnumpop}->geometry;
				$::lglobal{pnumpop}->destroy;
				undef $::lglobal{pnumpop};
				viewpagenums() if ( $::lglobal{seepagenums} );
			}
		);
		if ($::OS_WIN) {
			$::lglobal{pagerenumoffset}->bind(
				$::lglobal{pagerenumoffset},
				'<MouseWheel>' => [
					sub {
						( $_[1] > 0 )
						  ? $::lglobal{pagerenumoffset}->invoke('buttonup')
						  : $::lglobal{pagerenumoffset}->invoke('buttondown');
					},
					::Ev('D')
				]
			);
		}
	}
}



1;