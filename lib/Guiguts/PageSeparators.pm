package Guiguts::PageSeparators;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA=qw(Exporter);
	@EXPORT=qw( &pageseparatorhelppopup &findandhighlightpageseparator &processpageseparator 
	&redojoin &undojoin)
}

sub pageseparatorhelppopup {
	my $top = $::top;
	my $help_text = <<'EOM';
    Join Lines - join lines removing any spaces, asterisks and hyphens as necessary. - Hotkey j
    Join, Keep hyphen - join lines removing any spaces and asterisks as necessary. - Hotkey k
    Blank line - remove spaces as necessary. Keep one blank line. (paragraph break). - Hotkey l
    New Section - remove spaces as necessary. Keep two blank lines (section break). - Hotkey t
    New Chapter - remove spaces as necessary. Keep four blank lines (chapter break). - Hotkey h
    Refresh - search for and center next page separator. - Hotkey r
    Undo - undo the previous page separator edit. - Hotkey u
    Delete - delete the page separator. Make no other edits. - Hotkey d
    Full Auto - automatically search for and convert if possible the next page separator. - Toggle - a
    Semi Auto - automatically search for and center the next page separator after an edit. - Toggle - s
    View page image - Hotkey v
    View Page Separator help -Hotkey ?
EOM

	if ( defined( $::lglobal{phelppop} ) ) {
		$::lglobal{phelppop}->deiconify;
		$::lglobal{phelppop}->raise;
		$::lglobal{phelppop}->focus;
	} else {
		$::lglobal{phelppop} = $top->Toplevel;
		$::lglobal{phelppop}->title('Functions and Hotkeys');
		::initialize_popup_with_deletebinding('phelppop');
		$::lglobal{phelppop}->Label(
								   -justify => "left",
								   -text    => $help_text
		)->pack;
		my $button_ok = $::lglobal{phelppop}->Button(
			-activebackground => $::activecolor,
			-text             => 'OK',
			-command          => sub {
				$::lglobal{phelppop}->destroy;
				undef $::lglobal{phelppop};
			}
		)->pack;
		$::lglobal{phelppop}->resizable( 'no', 'no' );
	}
}


# Called by "Refresh" on Separator popup.
# Search for page separator. If automatic, then process it. 
sub findandhighlightpageseparator {
	my $textwindow = $::textwindow;
	::viewpagenums() if ( $::lglobal{seepagenums} );

	#$::lglobal{joinundo} = 0;
	my ( $filenum, $line, $rnd1, $rnd2, $page );
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	$::searchstartindex = '1.0';
	$::searchendindex   = '1.0';
	$::searchstartindex =
	  $textwindow->search( '-nocase', '-regexp', '--', '^-----*\s?File:',
						   $::searchendindex, 'end' );
	return unless $::searchstartindex;
	$::searchendindex = $textwindow->index("$::searchstartindex lineend");
	$line = $textwindow->get( $::searchstartindex, $::searchendindex );
	$textwindow->tagAdd( 'highlight', $::searchstartindex, $::searchendindex )
	  if $::searchstartindex;
	$textwindow->yview('end');
	$textwindow->see($::searchstartindex) if $::searchstartindex;

	if ( $::lglobal{jautomatic} && $::searchstartindex ) {
		my ($index);
		$textwindow->markSet( 'page',  $::searchstartindex );
		$textwindow->markSet( 'page1', "$::searchstartindex+1l" );
		while (1) {
			$index = $textwindow->index('page');
			$line  = $textwindow->get("$index-1c");
			if ( ( $line =~ /[\s\n]$/ ) || ( $line =~ /[\w-]\*$/ ) ) {
				$textwindow->delete("$index-1c");
				$::lglobal{joinundo}++;
			} else {
				last;
			}
		}
		$textwindow->insert( $index, "\n" );
		$::lglobal{joinundo}++;
		if ( $line =~ /[\w;,]/ ) {
			while (1) {
				$index = $textwindow->index('page1');
				$line  = $textwindow->get($index);
				if ( $line =~ /[\n\*]/ ) {
					$textwindow->delete($index);
					$::lglobal{joinundo}++;
					last if $textwindow->compare( 'page1 +1l', '>=', 'end' );
				} else {
					last;
				}
			}
		}
		if ( ( $line =~ /\p{IsLower}/ ) || ( $line =~ /^I / ) ) {
			::processpageseparator('j');
		}
		my ( $r, $c ) = split /\./, $textwindow->index('page-1c');
		my ($size) =
		  length( $textwindow->get( 'page+1l linestart', 'page+1l lineend' ) );
		if ( ( $line =~ /[\.\"\'\?]/ ) && ( $c < ( $size * 0.5 ) ) ) {
			::processpageseparator('l');
		}
	}
	$textwindow->xviewMoveto(.0);
	$textwindow->markSet( 'insert', "$::searchstartindex+2l" )
	  if $::searchstartindex;
}

sub processpageseparator {
	my $op = shift;
	my $textwindow = $::textwindow;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	my ( $line, $index, $r, $c );
	$::searchstartindex  = '1.0';
	$::searchendindex    = '1.0';
	$::lglobal{joinundo} = 0;
	$::searchstartindex =
	  $textwindow->search( '-regexp', '--', '^-----*\s?File:', $::searchendindex,
						   'end' );
	unless ($::searchstartindex) {
		$textwindow->bell unless $::nobell;
		return;
	}
	$::searchendindex = $textwindow->index("$::searchstartindex lineend");
	$textwindow->see($::searchstartindex) if $::searchstartindex;
	$textwindow->update;
	my $pagesep;
	$pagesep = $textwindow->get( $::searchstartindex, $::searchendindex )
	  if ( $::searchstartindex && $::searchendindex );
	my $pagemark = $pagesep;
	$pagesep =~ m/^-----*\s?File:\s?([^\.]+)/;   # m/^-----*\s?File:\s?(\S+)\./;
	return unless $1;
	$pagesep  = " <!--Pg$1-->";
	$pagemark = 'Pg' . $1;
	$textwindow->delete( $::searchstartindex, $::searchendindex )
	  if ( $::searchstartindex && $::searchendindex );
	$textwindow->markSet( 'page',    $::searchstartindex );
	$textwindow->markSet( $pagemark, "$::searchstartindex-1c" );
	$textwindow->markGravity( $pagemark, 'left' );
	$textwindow->markSet( 'insert', "$::searchstartindex+1c" );
	$index = $textwindow->index('page');

	unless ( $op eq 'd' ) {                      # if not deleting a line
		while (1) {
			$index = $textwindow->index('page');
			$line  = $textwindow->get($index);
			if ( $line =~ /[\n\*]/ ) {
				$textwindow->delete($index);
				$::lglobal{joinundo}++;
				last if ( $textwindow->compare( $index, '>=', 'end' ) );
			} else {
				last;
			}
		}
		while (1) {
			$index = $textwindow->index('page');
			last if ( $textwindow->compare( $index, '>=', 'end' ) );
			$line = $textwindow->get("$index-1c");
			if ( $line eq '*' ) {
				$line = $textwindow->get("$index-2c") . '*';
			}
			if ( ( $line =~ /[\s\n]$/ ) || ( $line =~ /[\w-]\*$/ ) ) {
				$textwindow->delete("$index-1c");
				$::lglobal{joinundo}++;
			} else {
				last;
			}
		}
	}

	# join lines
	# FIXME why is there a space after hyphens after a join?
	if ( $op eq 'j' ) {
		$index = $textwindow->index('page');

		# Note: $line here and in similar cases actually seems to contain the
		# last _character_ on the previous page.
		$line = $textwindow->get("$index-1c");
		my $hyphens = 0;
		if ( $line =~ /\// ) {
			my $match = $textwindow->get( "$index-3c", "$index+2c" );
			if ( $match =~ /(.)\/\/\1/ ) {
				$textwindow->delete( "$index-3c", "$index+3c" );
				$::lglobal{joinundo}++;
			} else {
				$textwindow->insert( "$index", "\n" );
			}
			$index = $textwindow->index('page');
			$line  = $textwindow->get("$index-1c");
			last if ( $textwindow->compare( $index, '>=', 'end' ) );
			while ( $line eq '*' ) {
				$textwindow->delete("$index-1c");
				$index = $textwindow->index('page');
				$line  = $textwindow->get("$index-1c");
			}
			$line = $textwindow->get("$index-1c");
		}

		if ( $line =~ />/ ) {
			my $markupl = $textwindow->get( "$index-4c", $index );
			my $markupn = $textwindow->get( $index,      "$index+3c" );
			if ( ( $markupl =~ /<\/([ib])>/i ) && ( $markupn =~ /<$1>/i ) ) {
				$textwindow->delete( $index, "$index+3c" );
				$::lglobal{joinundo}++;
				$textwindow->delete( "$index-4c", $index );
				$::lglobal{joinundo}++;
				$index = $textwindow->index('page');
				$line  = $textwindow->get("$index-1c");
				last if ( $textwindow->compare( $index, '>=', 'end' ) );
			}
			while ( $line eq '*' ) {
				$textwindow->delete("$index-1c");
				$index = $textwindow->index('page');
				$line  = $textwindow->get("$index-1c");
			}
			$line = $textwindow->get("$index-1c");
		}
		if ( $line =~ /\-/ ) {
			unless (
					 $textwindow->search(
									  '-regexp', '--', '-----*\s?File:', $index,
									  "$index lineend" )
			  )
			{
				while ( $line =~ /\-/ ) {
					$textwindow->delete("$index-1c");
					$::lglobal{joinundo}++;
					$index = $textwindow->index('page');
					$line  = $textwindow->get("$index-1c");
					last if ( $textwindow->compare( $index, '>=', 'end' ) );
				}
				$line = $textwindow->get($index);
				if ( $line =~ /\*/ ) {
					$textwindow->delete($index);
					$::lglobal{joinundo}++;
				}
				$index =
				  $textwindow->search( '-regexp', '--', '\s', $index, 'end' );
				$textwindow->delete($index);
				$::lglobal{joinundo}++;
			}
		}
		$textwindow->insert( $index, "\n" );
		$::lglobal{joinundo}++;
		$textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
		$::lglobal{joinundo}++ if $::lglobal{htmlpagenum};
	} elsif ( $op eq 'k' ) {    # join lines keep hyphen
		$index = $textwindow->index('page');
		$line  = $textwindow->get("$index-1c");
		if ( $line =~ />/ ) {
			my $markupl = $textwindow->get( "$index-4c", $index );
			my $markupn = $textwindow->get( $index,      "$index+3c" );
			if ( ( $markupl =~ /<\/[ib]>/i ) && ( $markupn =~ /<[ib]>/i ) ) {
				$textwindow->delete( $index, "$index+3c" );
				$::lglobal{joinundo}++;
				$textwindow->delete( "$index-4c", $index );
				$::lglobal{joinundo}++;
				$index = $textwindow->index('page');
				$line  = $textwindow->get("$index-1c");
				last if ( $textwindow->compare( $index, '>=', 'end' ) );
			}
			while ( $line eq '*' ) {
				$textwindow->delete("$index-1c");
				$index = $textwindow->index('page');
				$line  = $textwindow->get("$index-1c");
			}
			$line = $textwindow->get($index);
			while ( $line eq '*' ) {
				$textwindow->delete($index);
				$index = $textwindow->index('page');
				$line  = $textwindow->get($index);
			}
			$line = $textwindow->get("$index-1c");
		}
		if ( $line =~ /-/ ) {
			unless (
					 $textwindow->search(
									 '-regexp', '--', '^-----*\s?File:', $index,
									 "$index lineend" )
			  )
			{
				if ($::rwhyphenspace) {
					$textwindow->insert( "$index", " " );
					$index =
					  $textwindow->search( '-regexp', '--', '\s', "$index+1c",
										   'end' );

				} else {
					$index =
					  $textwindow->search( '-regexp', '--', '\s', "$index",
										   'end' );

				}
				$textwindow->insert( "$index", " " );
				$index =
				  $textwindow->search(
									   '-regexp', '--',
									   '\s',      "$index+1c",
									   'end'
				  );
				$textwindow->delete($index);
				if ($::rwhyphenspace) {
				}
				$::lglobal{joinundo}++;
			}
		}
		$line = $textwindow->get($index);
		if ( $line =~ /-/ ) {
			$::lglobal{joinundo}++;
			$index =
			  $textwindow->search( '-regexp', '--', '\s', $index, 'end' );
			$textwindow->delete($index);
			$::lglobal{joinundo}++;
		}
		$textwindow->insert( $index, "\n" );
		$::lglobal{joinundo}++;
		$textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
		$::lglobal{joinundo}++ if $::lglobal{htmlpagenum};
	} elsif ( $op eq 'l' ) {    # add a line
		$textwindow->insert( $index, "\n\n" );
		$::lglobal{joinundo}++;
		$textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
		$::lglobal{joinundo}++ if $::lglobal{htmlpagenum};
	} elsif ( $op eq 't' ) {    # new section
		$textwindow->insert( $index, "\n\n\n" );
		$::lglobal{joinundo}++;
		$textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
		$::lglobal{joinundo}++ if $::lglobal{htmlpagenum};
	} elsif ( $op eq 'h' ) {    # new chapter
		$textwindow->insert( $index, "\n\n\n\n\n" );
		$::lglobal{joinundo}++;
		$textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
		$::lglobal{joinundo}++ if $::lglobal{htmlpagenum};
	} elsif ( $op eq 'd' ) {    # delete
		$textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
		$::lglobal{joinundo}++ if $::lglobal{htmlpagenum};
		$textwindow->delete("$index-1c");
		$::lglobal{joinundo}++;
	}
	findandhighlightpageseparator() if ( $::lglobal{jautomatic} || $::lglobal{jsemiautomatic} );
	push @::joinundolist, $::lglobal{joinundo};
}

sub undojoin {
	my $textwindow = $::textwindow;
	if ( $::lglobal{jautomatic} ) {
		$textwindow->undo;
		$textwindow->tagRemove( 'highlight', '1.0', 'end' );
		return;
	}
	my $joinundo = pop @::joinundolist;
	push @::joinredolist, $joinundo;
	$textwindow->undo for ( 0 .. $joinundo );
	findandhighlightpageseparator();
}

sub redojoin {
	my $textwindow = $::textwindow;
	if ( $::lglobal{jautomatic} ) {
		$textwindow->redo;
		$textwindow->tagRemove( 'highlight', '1.0', 'end' );
		return;
	}
	my $joinredo = pop @::joinredolist;
	push @::joinundolist, $joinredo;
	$textwindow->redo for ( 0 .. $joinredo );

	#findandhighlightpageseparator();
}



1;