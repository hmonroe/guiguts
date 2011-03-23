package Guiguts::SelectionMenu;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&case &surround &flood)
}

sub case {
	&main::saveset();
	my ($textwindow,$marker) = @_;
	#my $marker      = shift;
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	my $done        = '';
	if ( $range_total == 0 ) {
		return;
	} else {
		$textwindow->addGlobStart;
		while (@ranges) {
			my $end            = pop(@ranges);
			my $start          = pop(@ranges);
			my $thisblockstart = $start;
			my $thisblockend   = $end;
			my $selection = $textwindow->get( $thisblockstart, $thisblockend );
			my @words     = ();
			my $buildsentence = '';
			if ( $marker eq 'uc' ) {
				$done = uc($selection);
			} elsif ( $marker eq 'lc' ) {
				$done = lc($selection);
			} elsif ( $marker eq 'sc' ) {
				$done = lc($selection);
				$done =~ s/(^\W*\w)/\U$1\E/;
			} elsif ( $marker eq 'tc' ) {
				$done = lc($selection);
				$done =~ s/(^\W*\w)/\U$1\E/;
				$done =~ s/([\s\n]+\W*\w)/\U$1\E/g;
			}
			$textwindow->replacewith( $start, $end, $done );
		}
		$textwindow->addGlobEnd;
	}
}

sub surround {
	my ($textwindow,$surpop,$top,$font,$activecolor,$icon) = @_;
	if ( defined( $surpop ) ) {
		$surpop->deiconify;
		$surpop->raise;
		$surpop->focus;
	} else {
		$surpop = $top->Toplevel;
		$surpop->title('Surround text with:');
		my $f = $surpop->Frame->pack( -side => 'top', -anchor => 'n' );
		$f->Label( -text =>
"Surround the selection with?\n\\n will be replaced with a newline.",
		)->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
		my $f1 =
		  $surpop->Frame->pack( -side => 'top', -anchor => 'n' );
		my $surstrt = $f1->Entry(
								  -width      => 8,
								  -background => 'white',
								  -font       => $font,
								  -relief     => 'sunken',
		)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'n' );
		my $surend = $f1->Entry(
								 -width      => 8,
								 -background => 'white',
								 -font       => $font,
								 -relief     => 'sunken',
		)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'n' );
		my $f2 =
		  $surpop->Frame->pack( -side => 'top', -anchor => 'n' );
		my $gobut = $f2->Button(
			-activebackground => $activecolor,
			-command          => sub {
				surroundit( $surstrt->get, $surend->get ,$textwindow);
			},
			-text  => 'OK',
			-width => 16
		)->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
		$surpop->protocol(
			'WM_DELETE_WINDOW' => sub {
				$surpop->destroy;
				undef $surpop;
			}
		);
		$surstrt->insert( 'end', '_' ) unless ( $surstrt->get );
		$surend->insert( 'end', '_' ) unless ( $surend->get );
		$surpop->Icon( -image => $icon );
	}
	return $surpop
}

sub surroundit {
	my ( $pre, $post,$textwindow ) = @_;
	$pre  =~ s/\\n/\n/;
	$post =~ s/\\n/\n/;
	my @ranges = $textwindow->tagRanges('sel');
	unless (@ranges) {
		push @ranges, $textwindow->index('insert');
		push @ranges, $textwindow->index('insert');
	}
	$textwindow->addGlobStart;
	while (@ranges) {
		my $end   = pop(@ranges);
		my $start = pop(@ranges);
		$textwindow->replacewith( $start, $end,
							  $pre . $textwindow->get( $start, $end ) . $post );
	}
	$textwindow->addGlobEnd;
}

sub flood {
	my ($textwindow,$top,$floodpop,$font,$activecolor,$icon) = @_;
	my $ffchar;
	if ( defined( $floodpop ) ) {
		$floodpop->deiconify;
		$floodpop->raise;
		$floodpop->focus;
	} else {
		$floodpop = $top->Toplevel;
		$floodpop->title('Flood Fill String:');
		my $f =
		  $floodpop->Frame->pack( -side => 'top', -anchor => 'n' );
		$f->Label( -text =>
"Flood fill string.\n(Blank will default to spaces.)\nHotkey Control+w",
		)->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
		my $f1 =
		  $floodpop->Frame->pack(
										   -side   => 'top',
										   -anchor => 'n',
										   -expand => 'y',
										   -fill   => 'x'
		  );
		my $floodch = $f1->Entry(
								  -background   => 'white',
								  -font         => $font,
								  -relief       => 'sunken',
								  -textvariable => \$ffchar,
		  )->pack(
				   -side   => 'left',
				   -pady   => 5,
				   -padx   => 2,
				   -anchor => 'w',
				   -expand => 'y',
				   -fill   => 'x'
		  );
		my $f2 =
		  $floodpop->Frame->pack( -side => 'top', -anchor => 'n' );
		my $gobut = $f2->Button(
								 -activebackground => $activecolor,
								 -command          => sub { floodfill($textwindow,$ffchar) },
								 -text             => 'Flood Fill',
								 -width            => 16
		)->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
		$floodpop->protocol(
			'WM_DELETE_WINDOW' => sub {
				$floodpop->destroy;
				undef $floodpop;
			}
		);
		$floodpop->Icon( -image => $icon );
	}
	return $floodpop;
}

sub floodfill {
	my ($textwindow,$ffchar) = @_;
	my @ranges = $textwindow->tagRanges('sel');
	return unless @ranges;
	$ffchar = ' ' unless length $ffchar;
	$textwindow->addGlobStart;
	while (@ranges) {
		my $end       = pop(@ranges);
		my $start     = pop(@ranges);
		my $selection = $textwindow->get( $start, $end );
		my $temp = substr(
						   $ffchar x (
												(
												  ( length $selection ) /
													( length $ffchar )
												) + 1
						   ),
						   0,
						   ( length $selection )
		);
		chomp $selection;
		my @temparray = split( /\n/, $selection );
		my $replacement;
		for (@temparray) {
			$replacement .= substr( $temp, 0, ( length $_ ), '' );
			$replacement .= "\n";
		}
		chomp $replacement;
		$textwindow->replacewith( $start, $end, $replacement );
	}
	$textwindow->addGlobEnd;

}



1;


