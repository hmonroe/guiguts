package Guiguts::ErrorCheck;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA    = qw(Exporter);
	@EXPORT = qw(&errorcheckpop_up &errorcheckrun &gutcheckview &gutwindowpopulate);
}

sub errorcheckpop_up {
	my ( $textwindow, $top, $errorchecktype ) = @_;
	my ( %errors,     @errorchecklines );
	my ( $line,       $lincol );
	&main::viewpagenums() if ( $::lglobal{seepagenums} );
	if ( $::lglobal{errorcheckpop} ) {
		$::lglobal{errorcheckpop}->destroy;
		undef $::lglobal{errorcheckpop};
	}
	$::lglobal{errorcheckpop} = $top->Toplevel;
	$::lglobal{errorcheckpop}->title($errorchecktype);
	&main::initialize_popup_with_deletebinding('errorcheckpop');
	$::lglobal{errorcheckpop}->transient($top) if $main::stayontop;
	my $ptopframe = $::lglobal{errorcheckpop}->Frame->pack;
	my $opsbutton = $ptopframe->Button(
		-activebackground => $main::activecolor,
		-command          => sub {
			errorcheckpop_up( $textwindow, $top, $errorchecktype );
			unlink 'null' if ( -e 'null' );
		},
		-text  => 'Run Checks',
		-width => 16
	  )->pack(
			   -side   => 'left',
			   -pady   => 10,
			   -padx   => 2,
			   -anchor => 'n'
	  );

	# Add verbose checkbox only for certain error check types
	if (    ( $errorchecktype eq 'Check All' )
		 or ( $errorchecktype eq 'Link Check' )
		 or ( $errorchecktype eq 'W3C Validate CSS' )
		 or ( $errorchecktype eq 'pphtml' ) )
	{
		$ptopframe->Checkbutton(
								 -variable    => \$main::verboseerrorchecks,
								 -selectcolor => $::lglobal{checkcolor},
								 -text        => 'Verbose'
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 2,
				   -anchor => 'n'
		  );
	}
	my $pframe =
	  $::lglobal{errorcheckpop}
	  ->Frame->pack( -fill => 'both', -expand => 'both', );
	$::lglobal{errorchecklistbox} =
	  $pframe->Scrolled(
						 'Listbox',
						 -scrollbars  => 'se',
						 -background  => $main::bkgcolor,
						 -font        => $::lglobal{font},
						 -selectmode  => 'single',
						 -activestyle => 'none',
	  )->pack(
			   -anchor => 'nw',
			   -fill   => 'both',
			   -expand => 'both',
			   -padx   => 2,
			   -pady   => 2
	  );
	&main::drag( $::lglobal{errorchecklistbox} );
	&main::BindMouseWheel( $::lglobal{errorchecklistbox} );
	$::lglobal{errorchecklistbox}
	  ->eventAdd( '<<view>>' => '<Button-1>', '<Return>' );
	$::lglobal{errorchecklistbox}->bind(
		'<<view>>',
		sub {         # FIXME: adapt for gutcheck
			$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			my $line = $::lglobal{errorchecklistbox}->get('active');
			if ( $line =~ /^line/ ) {
				$textwindow->see( $main::errors{$line} );
				$textwindow->markSet( 'insert', $main::errors{$line} );
				&main::update_indicators();
			} else {
				if ( $line =~ /^\+(.*):/ ) {    # search on text between + and :
					my @savesets = @main::sopt;
					&main::searchoptset(qw/0 x x 0/);
					&main::searchfromstartifnew($1);
					&main::searchtext( $textwindow, $top, $1 );
					&main::searchoptset(@savesets);
					$top->raise;
				}
			}
			$textwindow->focus;
			$::lglobal{errorcheckpop}->raise;
		}
	);
	$::lglobal{errorchecklistbox}->eventAdd(
											'<<remove>>' => '<ButtonRelease-2>',
											'<ButtonRelease-3>' );
	$::lglobal{errorchecklistbox}->bind(
		'<<remove>>',
		sub {
			$::lglobal{errorchecklistbox}->activate(
						   $::lglobal{errorchecklistbox}->index(
							   '@'
								 . (
								   $::lglobal{errorchecklistbox}->pointerx -
									 $::lglobal{errorchecklistbox}->rootx
								 )
								 . ','
								 . (
								   $::lglobal{errorchecklistbox}->pointery -
									 $::lglobal{errorchecklistbox}->rooty
								 )
						   )
			);
			$::lglobal{errorchecklistbox}->selectionClear( 0, 'end' );
			$::lglobal{errorchecklistbox}->selectionSet(
						   $::lglobal{errorchecklistbox}->index('active') );
			$::lglobal{errorchecklistbox}->delete('active');
			$::lglobal{errorchecklistbox}->after( $::lglobal{delay} );
		}
	);
	$::lglobal{errorcheckpop}->update;

	# End presentation; begin logic
	my (@errorchecktypes);    # Multiple errorchecktypes in one popup
	if ( $errorchecktype eq 'Check All' ) {
		@errorchecktypes = (
							 'W3C Validate',
							 'HTML Tidy',
							 'Image Check',
							 'Link Check',
							 'W3C Validate CSS',
							 'Epub Friendly',
							 'pphtml'
		);
	} else {
		@errorchecktypes = ($errorchecktype);
	}
	%errors          = ();
	@errorchecklines = ();
	my $mark  = 0;
	my @marks = $textwindow->markNames;
	for (@marks) {
		if ( $_ =~ /^t\d+$/ ) {
			$textwindow->markUnset($_);
		}
	}
	foreach my $thiserrorchecktype (@errorchecktypes) {
		&main::working($thiserrorchecktype);
		push @errorchecklines, "Beginning check: " . $thiserrorchecktype;
		if ( &main::errorcheckrun( $thiserrorchecktype ) ) {
			push @errorchecklines, "Failed to run: " . $thiserrorchecktype;
		}
		my $fh = FileHandle->new("< errors.err");
		if ( not defined($fh) ) {
			my $dialog = $top->Dialog(
									   -text => 'Could not find '
										 . $thiserrorchecktype
										 . ' error file.',
									   -bitmap  => 'question',
									   -title   => 'File not found',
									   -buttons => [qw/OK/],
			);
			$dialog->Show;
		} else {
			while ( $line = <$fh> ) {
				$line =~ s/^\s//g;
				chomp $line;

				# Skip rest of CSS
				if (
					     ( not $main::verboseerrorchecks )
					 and ( $thiserrorchecktype eq 'W3C Validate CSS' )
					 and (    ( $line =~ /^To show your readers/i )
						   or ( $line =~ /^Valid CSS Information/i ) )
				  )
				{
					last;
				}
				if (
					( $line =~ /^\s*$/i
					)    # skip some unnecessary lines from W3C Validate CSS
					or ( $line =~ /^{output/i )
					or ( $line =~ /^W3C/i )
					or ( $line =~ /^URI/i )
				  )
				{
					next;
				}

				# skip some unnecessary lines from W3C Validate for PGTEI
				if ( $line =~ /^In entity TEI/ ) {
					next;
				}

				# Skip verbose informational warnngs in Link Check
				if (     ( not $main::verboseerrorchecks )
					 and ( $thiserrorchecktype eq 'Link Check' )
					 and ( $line =~ /^Link statistics/i ) )
				{
					last;
				}
				if ( $thiserrorchecktype eq 'pphtml' ) {
					if ( $line =~ /^-/i ) {    # skip lines beginning with '-'
						next;
					}
					if ( ( not $main::verboseerrorchecks )
						 and $line =~ /^Verbose checks/i )
					{    # stop with verbose specials check
						last;
					}
				}
				no warnings 'uninitialized';
				if ( $thiserrorchecktype eq 'HTML Tidy' ) {
					if (     ( $line =~ /^[lI\d]/ )
						 and ( $line ne $errorchecklines[-1] ) )
					{
						push @errorchecklines, $line;
						$main::errors{$line} = '';
						$lincol = '';
						if ( $line =~ /^line (\d+) column (\d+)/i ) {
							$lincol = "$1.$2";
							$mark++;
							$textwindow->markSet( "t$mark", $lincol );
							$main::errors{$line} = "t$mark";
						}
					}
				} elsif (    ( $thiserrorchecktype eq "W3C Validate" )
						  or ( $thiserrorchecktype eq "W3C Validate Remote" )
						  or ( $thiserrorchecktype eq "pphtml" )
						  or ( $thiserrorchecktype eq "Epub Friendly" )
						  or ( $thiserrorchecktype eq "Image Check" ) )
				{
					$line =~ s/^.*:(\d+:\d+)/line $1/;
					$line =~ s/^(\d+:\d+)/line $1/;
					$main::errors{$line} = '';
					$lincol = '';
					if ( $line =~ /line (\d+):(\d+)/ ) {
						push @errorchecklines, $line;
						$lincol = "$1.$2";
						$lincol =~ s/\.0/\.1/;  # change column zero to column 1
						$mark++;
						$textwindow->markSet( "t$mark", $lincol );
						$main::errors{$line} = "t$mark";
					}
					if ( $line =~ /^\+/ ) {
						push @errorchecklines, $line;
					}
				} elsif (    ( $thiserrorchecktype eq "W3C Validate CSS" )
						  or ( $thiserrorchecktype eq "Link Check" )
						  or ( $thiserrorchecktype eq "pptxt" ) )
				{
					$line =~ s/Line : (\d+)/line $1:1/;
					push @errorchecklines, $line;
					$main::errors{$line} = '';
					$lincol = '';
					if ( $line =~ /line (\d+):(\d+)/ ) {
						my $plusone = $1 + 1;
						$lincol = "$plusone.$2";
						$mark++;
						$textwindow->markSet( "t$mark", $lincol );
						$main::errors{$line} = "t$mark";
					}
				}
			}
		}
		$fh->close if $fh;
		unlink 'errors.err';
		my $size = @errorchecklines;
		if ( ( $thiserrorchecktype eq "W3C Validate CSS" ) and ( $size <= 1 ) )
		{    # handle errors.err file with zero lines
			push @errorchecklines,
"Could not perform validation: install java or use W3C CSS Validation web site.";
		} else {
			push @errorchecklines, "Check is complete: " . $thiserrorchecktype;
			if ( $thiserrorchecktype eq "W3C Validate" ) {
				push @errorchecklines,
				  "Do the final validation at validator.w3.org";
			}
			if ( $thiserrorchecktype eq "W3C Validate CSS" ) {
				push @errorchecklines,
"Do the final validation at http://jigsaw.w3.org/css-validator/";
			}
			push @errorchecklines, "";
		}
		&main::working();
	}
	$::lglobal{errorchecklistbox}->insert( 'end', @errorchecklines );
	$::lglobal{errorchecklistbox}->yview( 'scroll', 1, 'units' );
	$::lglobal{errorchecklistbox}->update;
	$::lglobal{errorchecklistbox}->yview( 'scroll', -1, 'units' );
	$::lglobal{errorchecklistbox}->focus;
}

sub errorcheckrun {    # Runs Tidy, W3C Validate, and other error checks
	#my ( $textwindow, $top, $errorchecktype ) = @_;
	my $errorchecktype  = shift;
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	if ( $errorchecktype eq 'W3C Validate Remote' ) {
		unless ( eval { require WebService::Validator::HTML::W3C } ) {
			print
"Install the module WebService::Validator::HTML::W3C to do W3C Validation remotely. Defaulting to local validation.\n";
			$errorchecktype = 'W3C Validate';
		}
	}
	push @main::operations, ( localtime() . ' - $errorchecktype' );
	&main::viewpagenums() if ( $::lglobal{seepagenums} );
	if ( $::lglobal{errorcheckpop} ) {
		$::lglobal{errorchecklistbox}->delete( '0', 'end' );
	}
	my ( $name, $fname, $path, $extension, @path );
	$textwindow->focus;
	&main::update_indicators();
	my $title = $top->cget('title');
	if ( $title =~ /No File Loaded/ ) { &main::savefile($textwindow,$top) }
	my $types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
	if ( $errorchecktype eq 'W3C Validate CSS' ) {
		$types = [ [ 'JAR file', [ '.jar', ] ], [ 'All Files', ['*'] ], ];
	}
	if ( $errorchecktype eq 'HTML Tidy' ) {
		unless ($main::tidycommand) {
			$main::tidycommand =
			  $textwindow->getOpenFile(
					-filetypes => $types,
					-title => "Where is the " . $errorchecktype . " executable?"
			  );
		}
		return 1 unless $main::tidycommand;
		$main::tidycommand = &main::os_normal($main::tidycommand);
	} elsif (     ( $errorchecktype eq "W3C Validate" )
			  and ( $main::w3cremote == 0 ) )
	{
		unless ($main::validatecommand) {
			$main::validatecommand =
			  $textwindow->getOpenFile(
					 -filetypes => $types,
					 -title => 'Where is the W3C Validate (onsgmls) executable?'
			  );
		}
		return 1 unless $main::validatecommand;
		$main::validatecommand = &main::os_normal($main::validatecommand);
	} elsif ( $errorchecktype eq 'W3C CSS Validate' ) {
		unless ($main::validatecsscommand) {
			$main::validatecsscommand =
			  $textwindow->getOpenFile(
				-filetypes => $types,
				-title =>
				  'Where is the W3C Validate CSS (css-validate.jar) executable?'
			  );
		}
		return 1 unless $main::validatecsscommand;
		$main::validatecsscommand = &main::os_normal($main::validatecsscommand);
	}
	&main::savesettings();
	$top->Busy( -recurse => 1 );
	if (    ( $errorchecktype eq 'W3C Validate Remote' )
		 or ( $errorchecktype eq 'W3C Validate CSS' ) )
	{
		$name = 'validate.html';
	} else {
		$name = 'errors.tmp';
	}
	if ( open my $td, '>', $name ) {
		my $count = 0;
		my $index = '1.0';
		my ($lines) = $textwindow->index('end - 1c') =~ /^(\d+)\./;
		while ( $textwindow->compare( $index, '<', 'end' ) ) {
			my $end = $textwindow->index("$index  lineend +1c");
			my $gettext = $textwindow->get( $index, $end );

			#utf8::encode($gettext);
			print $td $gettext;
			$index = $end;
		}
		close $td;
	} else {
		warn "Could not open temp file for writing. $!";
		my $dialog = $top->Dialog(
				-text => 'Could not write to the '
				  . cwd()
				  . ' directory. Check for write permission or space problems.',
				-bitmap  => 'question',
				-title   => '$errorchecktype problem',
				-buttons => [qw/OK/],
		);
		$dialog->Show;
		return;
	}
	if ( $::lglobal{errorcheckpop} ) {
		$::lglobal{errorchecklistbox}->delete( '0', 'end' );
	}
	if ( $errorchecktype eq 'HTML Tidy' ) {
		&main::run( $main::tidycommand, "-f", "errors.err", "-o", "null",
					$name );
	} elsif ( $errorchecktype eq 'W3C Validate' ) {
		if ( $main::w3cremote == 0 ) {
			my $validatepath = &main::dirname($main::validatecommand);
			&main::run(
						$main::validatecommand, "--directory=$validatepath",
						"--catalog=xhtml.soc",  "--no-output",
						"--open-entities",      "--error-file=errors.err",
						$name
			);
		}
	} elsif ( $errorchecktype eq 'W3C Validate Remote' ) {
		my $validator = WebService::Validator::HTML::W3C->new( detailed => 1 );
		if ( $validator->validate_file('./validate.html') ) {
			if ( open my $td, '>', "errors.err" ) {
				if ( $validator->is_valid ) {
				} else {
					foreach my $error ( @{ $validator->errors } ) {
						printf $td (
									 "W3C:validate.tmp:%s:%s:Eremote:%s\n",
									 $error->line, $error->col, $error->msg
						);
					}
					print $td "Remote response complete";
				}
				close $td;
			}
		} else {
			if ( open my $td, '>', "errors.err" ) {
				print $td
'Could not contact remote validator; try using local validator onsgmls.';
				close $td;
			}
		}
	} elsif ( $errorchecktype eq 'W3C Validate CSS' ) {
		my $runner = &main::runner::tofile("errors.err");
		$runner->run( "java", "-jar", $main::validatecsscommand, "file:$name" );
	} elsif ( $errorchecktype eq 'pphtml' ) {
		&main::run( "perl", "lib/ppvchecks/pphtml.pl", "-i", $name, "-o",
					"errors.err" );
	} elsif ( $errorchecktype eq 'Link Check' ) {
		linkcheckrun();
	}
	elsif ( $errorchecktype eq 'Image Check' ) {
		my ( $f, $d, $e ) =
		  &main::fileparse( $::lglobal{global_filename}, qr{\.[^\.]*$} );
		&main::run( "perl", "lib/ppvchecks/ppvimage.pl", $name, $d );
	} elsif ( $errorchecktype eq 'pptxt' ) {
		&main::run( "perl", "lib/ppvchecks/pptxt.pl", "-i", $name, "-o",
					"errors.err" );
	} elsif ( $errorchecktype eq 'Epub Friendly' ) {
		&main::run( "perl", "lib/ppvchecks/epubfriendly.pl",
					"-i", $name, "-o", "errors.err" );
	}
	$top->Unbusy;
	unlink $name;
	return;
}

sub linkcheckrun {
	my $textwindow = $::textwindow;
	open my $logfile, ">", "errors.err" || die "output file error\n";
	my ( %anchor,  %id,  %link,   %image,  %badlink, $length, $upper );
	my ( $anchors, $ids, $ilinks, $elinks, $images,  $count,  $css ) =
	  ( 0, 0, 0, 0, 0, 0, 0 );
	my @warning = ();
	my $fname   = $::lglobal{global_filename};
	if ( $fname =~ /(No File Loaded)/ ) {
		print $logfile "You need to save your file first.";
		return;
	}
	my ( $f, $d, $e ) = ::fileparse( $fname, qr{\.[^\.]*$} );
	my %imagefiles;
	my @ifiles   = ();
	my $imagedir = '';
	push @warning, '';
	my ( $fh, $filename );

	my @temp = split( /[\\\/]/, $textwindow->FileName );
	my $tempfilename = $temp[-1];
	if ( $tempfilename =~ /projectid/i ) {
		print $logfile "Choose a human readable filename: $tempfilename\n";
	}
	if ( $tempfilename =~ /[A-Z]/ ) {
		print $logfile "Use only lower case in filename: $tempfilename\n";
	}
	if ( $textwindow->numberChanges ) {
		$filename = 'tempfile.tmp';
		open( my $fh, ">", "$filename" );
		my ($lines) = $textwindow->index('end - 1 chars') =~ /^(\d+)\./;
		my $index = '1.0';
		while ( $textwindow->compare( $index, '<', 'end' ) ) {
			my $end = $textwindow->index("$index lineend +1c");
			my $line = $textwindow->get( $index, $end );
			print $fh $line;
			$index = $end;
		}
		$fname = $filename;
		close $fh;
	}
	my $parser = HTML::TokeParser->new($fname);
	while ( my $token = $parser->get_token ) {
		if ( $token->[0] eq 'S' and $token->[1] eq 'style' ) {
			$token = $parser->get_token;
			if ( $token->[0] eq 'T' and $token->[2] ) {
				my @urls = $token->[1] =~ m/\burl\(['"](.+?)['"]\)/gs;
				for my $img (@urls) {
					if ($img) {
						if ( !$imagedir ) {
							$imagedir = $img;
							$imagedir =~ s/\/.*?$/\//;
							@ifiles = glob( $d . $imagedir . '*.*' );
							for (@ifiles) { $_ =~ s/\Q$d\E// }
							for (@ifiles) { $imagefiles{$_} = '' }
						}
						$image{$img}++;
						$upper++ if ( $img ne lc($img) );
						delete $imagefiles{$img}
						  if (    ( defined $imagefiles{$img} )
							   || ( defined $link{$img} ) );
						push @warning, "+$img: contains uppercase characters!\n"
						  if ( $img ne lc($img) );
						push @warning, "+$img: not found!\n"
						  unless ( -e $d . $img );
						$css++;
					}
				}
			}
		}
		next unless $token->[0] eq 'S';
		my $url    = $token->[2]{href} || '';
		my $anchor = $token->[2]{name} || '';
		my $img    = $token->[2]{src}  || '';
		my $id     = $token->[2]{id}   || '';
		if ($anchor) {
			$anchor{ '#' . $anchor } = $anchor;
			$anchors++;
		} elsif ($id) {
			$id{ '#' . $id } = $id;
			$ids++;
		}
		if ( $url =~ m/^(#?)(.+)$/ ) {
			$link{ $1 . $2 } = $2;
			$ilinks++ if $1;
			$elinks++ unless $1;
		}
		if ($img) {
			if ( !$imagedir ) {
				$imagedir = $img;
				$imagedir =~ s/\/.*?$/\//;
				@ifiles = glob( $d . $imagedir . '*.*' );
				for (@ifiles) { $_ =~ s/\Q$d\E// }
				for (@ifiles) { $imagefiles{$_} = '' }
			}
			$image{$img}++;
			$upper++ if ( $img ne lc($img) );
			delete $imagefiles{$img}
			  if (    ( defined $imagefiles{$img} )
				   || ( defined $link{$img} ) );
			push @warning, "+$img: contains uppercase characters!\n"
			  if ( $img ne lc($img) );
			push @warning, "+$img: not found!\n"
			  unless ( -e $d . $img );
			$images++;
		}
	}
	for ( keys %link ) {
		$badlink{$_} = $_ if ( $_ =~ m/\\|\%5C|\s|\%20/ );
		delete $imagefiles{$_} if ( defined $imagefiles{$_} );
	}
	for ( ::natural_sort_alpha( keys %link ) ) {
		unless (    ( defined $anchor{$_} )
				 || ( defined $id{$_} )
				 || ( $link{$_} eq $_ ) )
		{
			print $logfile "+#$link{$_}: Internal link without anchor\n";
			$count++;
		}
	}
	my $externflag;
	for ( ::natural_sort_alpha( keys %link ) ) {
		if ( $link{$_} eq $_ ) {
			if ( $_ =~ /:\/\// ) {
				print $logfile "+$link{$_}: External link\n";
			} else {
				my $temp = $_;
				$temp =~ s/^([^#]+).*/$1/;
				unless ( -e $d . $temp ) {
					print $logfile "local file(s) not found!\n"
					  unless $externflag;
					print $logfile "+$link{$_}:\n";
					$externflag++;
				}
			}
		}
	}
	for ( ::natural_sort_alpha( keys %badlink ) ) {
		print $logfile "+$badlink{$_}: Link with bad characters\n";
	}
	print $logfile @warning if @warning;
	print $logfile "";
	if ( keys %imagefiles ) {
		for ( ::natural_sort_alpha( keys %imagefiles ) ) {
			print $logfile "+" . $_ . ": File not used!\n"
			  if ( $_ =~ /\.(png|jpg|gif|bmp)/ );
		}
		print $logfile "";
	}
	print $logfile "Link statistics:\n";
	print $logfile "$anchors named anchors\n";
	print $logfile "$ids unnamed anchors (tag with id attribute)\n";
	print $logfile "$ilinks internal links\n";
	print $logfile "$images image links\n";
	print $logfile "$css CSS style image links\n";
	print $logfile "$elinks external links\n";
	print $logfile "ANCHORS WITHOUT LINKS. - (INFORMATIONAL)\n";

	for ( ::natural_sort_alpha( keys %anchor ) ) {
		unless ( exists $link{$_} ) {
			print $logfile "$anchor{$_}\n";
			$count++;
		}
	}
	print $logfile "$count  anchors without links\n";
	unlink $filename if $filename;
	close $logfile;
}

sub gutcheckview {
	my $textwindow = $::textwindow;
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	my $line = $::lglobal{gclistbox}->get('active');
	if ( $line and $::gc{$line} and $line =~ /Line/ ) {
		$textwindow->see('end');
		$textwindow->see( $::gc{$line} );
		$textwindow->markSet( 'insert', $::gc{$line} );

# Highlight pretty close to GC error (2 chars before just in case error is at end of line)
		$textwindow->tagAdd( 'highlight',
							 $::gc{$line} . "- 2c",
							 $::gc{$line} . " lineend" );
		::update_indicators();
	}

	#don't focus    $textwindow->focus;
	#leave main text on top    $::lglobal{gcpop}->raise;
	$::geometry2 = $::lglobal{gcpop}->geometry;
}

sub gutwindowpopulate {
	my $linesref = shift;
	return unless defined $::lglobal{gcpop};
	my ( $line, $flag, $count, $start );
	$::lglobal{gclistbox}->delete( '0', 'end' );
	foreach my $line ( @{$linesref} ) {
		$flag = 0;
		$start++ unless ( index( $line, 'Line', 0 ) > 0 );
		next unless defined $::gc{$line};
		for ( 0 .. $#{ $::lglobal{gcarray} } ) {
			next unless ( index( $line, $::lglobal{gcarray}->[$_] ) > 0 );
			$::gsopt[$_] = 0 unless defined $::gsopt[$_];
			$flag = 1 if $::gsopt[$_];
			last;
		}
		next if $flag;
		$count++;
		$::lglobal{gclistbox}->insert( 'end', $line );
	}
	$count -= $start;
	$::lglobal{gclistbox}->insert( $start, '', "  --> $count queries.", '' );
	$::lglobal{gclistbox}->update;

	#$::lglobal{gclistbox}->yview( 'scroll', 1,  'units' );
	#    $::lglobal{gclistbox}->yview( 'scroll', -1, 'units' );
}



1;
