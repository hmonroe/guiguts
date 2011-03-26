package Guiguts::BookmarksMenu;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&setbookmark &gotobookmark)
}

sub gotobookmark {
	my ($textwindow,$bookmark) = @_;
	$textwindow->bell unless ( $main::bookmarks[$bookmark] || $nobell );
	$textwindow->see("bkmk$bookmark") if $bookmarks[$bookmark];
	$textwindow->markSet( 'insert', "bkmk$bookmark" )
	  if $main::bookmarks[$bookmark];
	&main::update_indicators();
	$textwindow->tagAdd( 'bkmk', "bkmk$bookmark", "bkmk$bookmark+1c" )
	  if $main::bookmarks[$bookmark];
}

sub setbookmark {
	my ($textwindow,$bookmark) = @_;
	my $index    = '';
	my $indexb   = '';
	if ( $main::bookmarks[$bookmark] ) {
		$indexb = $textwindow->index("bkmk$bookmark");
	}
	$index = $textwindow->index('insert');
	if ( $main::bookmarks[$bookmark] ) {
		$textwindow->tagRemove( 'bkmk', $indexb, "$indexb+1c" );
	}
	if ( $index ne $indexb ) {
		$textwindow->markSet( "bkmk$bookmark", $index );
	}
	$main::bookmarks[$bookmark] = $index;
	$textwindow->tagAdd( 'bkmk', $index, "$index+1c" );
}



1;


