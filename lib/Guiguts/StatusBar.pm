package Guiguts::StatusBar;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&_updatesel &_butbind )
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



1;


