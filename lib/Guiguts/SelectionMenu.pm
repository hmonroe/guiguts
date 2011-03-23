package Guiguts::SelectionMenu;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&case &surround)
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
				&main::surroundit( $surstrt->get, $surend->get );
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



1;


