package Guiguts::PageSeparators;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw( &viewpagenums &gotolabel)
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



1;