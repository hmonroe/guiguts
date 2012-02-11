package Guiguts::PageNumbers;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw( &viewpagenums)
}

## Toggle visible page markers. This is not line numbers but marks for pages.
sub viewpagenums {
	my $textwindow = $main::textwindow;
	if ( $main::lglobal{seepagenums} ) {
		$main::lglobal{seepagenums} = 0;
		my @marks = $textwindow->markNames;
		for ( sort @marks ) {
			if ( $_ =~ m{Pg(\S+)} ) {
				my $pagenum = " Pg$1 ";
				$textwindow->ntdelete( $_, "$_ +@{[length $pagenum]}c" );
			}
		}
		$textwindow->tagRemove( 'pagenum', '1.0', 'end' );
		if ( $main::lglobal{pnumpop} ) {
			$main::geometryhash{pnumpop} = $main::lglobal{pnumpop}->geometry;
			$main::lglobal{pnumpop}->destroy;
			undef $main::lglobal{pnumpop};
		}
	} else {
		$main::lglobal{seepagenums} = 1;
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
	unless ( defined( $main::lglobal{gotolabpop} ) ) {
		return unless %main::pagenumbers;
		for ( keys(%main::pagenumbers) ) {
			$main::lglobal{pagedigits} = ( length($_) - 2 );
			last;
		}
		$main::lglobal{gotolabpop} = $top->DialogBox(
			-buttons => [qw[Ok Cancel]],
			-title   => 'Goto Page Label',
			-popover => $top,
			-command => sub {
				if ( $_[0] eq 'Ok' ) {
					my $mark;
					for ( keys %main::pagenumbers ) {
						if (    $main::pagenumbers{$_}{label}
							 && $main::pagenumbers{$_}{label} eq $main::lglobal{lastlabel} )
						{
							$mark = $_;
							last;
						}
					}
					unless ($mark) {
						$main::lglobal{gotolabpop}->bell;
						$main::lglobal{gotolabpop}->destroy;
						undef $main::lglobal{gotolabpop};
						return;
					}
					my $index = $textwindow->index($mark);
					$textwindow->markSet( 'insert', "$index +1l linestart" );
					$textwindow->see('insert');
					$textwindow->focus;
					update_indicators();
					$main::lglobal{gotolabpop}->destroy;
					undef $main::lglobal{gotolabpop};
				} else {
					$main::lglobal{gotolabpop}->destroy;
					undef $main::lglobal{gotolabpop};
				}
			}
		);
		$main::lglobal{gotolabpop}->resizable( 'no', 'no' );
		my $frame = $main::lglobal{gotolabpop}->Frame->pack( -fill => 'x' );
		$frame->Label( -text => 'Enter Label: ' )->pack( -side => 'left' );
		$main::lglobal{lastlabel} = 'Pg ' unless $main::lglobal{lastlabel};
		my $entry = $frame->Entry(
								   -background   => $main::bkgcolor,
								   -width        => 25,
								   -textvariable => \$main::lglobal{lastlabel}
		)->pack( -side => 'left', -fill => 'x' );
		$main::lglobal{gotolabpop}->Advertise( entry => $entry );
		$main::lglobal{gotolabpop}->Popup;
		$main::lglobal{gotolabpop}->Subwidget('entry')->focus;
		$main::lglobal{gotolabpop}->Subwidget('entry')->selectionRange( 0, 'end' );
		$main::lglobal{gotolabpop}->Wait;
	}
}



1;