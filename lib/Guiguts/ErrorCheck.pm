package Guiguts::ErrorCheck;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA    = qw(Exporter);
	@EXPORT = qw(&errorcheckpop_up &errorcheckrun);
}

sub errorcheckpop_up {
	my ( $textwindow, $top, $errorchecktype ) = @_;
	my ( %errors,     @errorchecklines );
	my ( $line,       $lincol );
	&::viewpagenums() if ( $::lglobal{seepagenums} );
	if ( $::lglobal{errorcheckpop} ) {
		$::lglobal{errorcheckpop}->destroy;
		undef $::lglobal{errorcheckpop};
	}
	$::lglobal{errorcheckpop} = $top->Toplevel;
	$::lglobal{errorcheckpop}->title($errorchecktype);
	&::initialize_popup_with_deletebinding('errorcheckpop');
	$::lglobal{errorcheckpop}->transient($top) if $::stayontop;
	my $ptopframe = $::lglobal{errorcheckpop}->Frame->pack;
	my $opsbutton = $ptopframe->Button(
		-activebackground => $::activecolor,
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
								 -variable    => \$::verboseerrorchecks,
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
						 -background  => $::bkgcolor,
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
	&::drag( $::lglobal{errorchecklistbox} );
	&::BindMouseWheel( $::lglobal{errorchecklistbox} );
	$::lglobal{errorchecklistbox}
	  ->eventAdd( '<<view>>' => '<Button-1>', '<Return>' );
	$::lglobal{errorchecklistbox}->bind(
		'<<view>>',
		sub {         # FIXME: adapt for gutcheck
			$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			my $line = $::lglobal{errorchecklistbox}->get('active');
			if ( $line =~ /^line/ ) {
				$textwindow->see( $::errors{$line} );
				$textwindow->markSet( 'insert', $::errors{$line} );
				&::update_indicators();
			} else {
				if ( $line =~ /^\+(.*):/ ) {    # search on text between + and :
					my @savesets = @::sopt;
					&::searchoptset(qw/0 x x 0/);
					&::searchfromstartifnew($1);
					&::searchtext( $textwindow, $top, $1 );
					&::searchoptset(@savesets);
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
		&::working($thiserrorchecktype);
		push @errorchecklines, "Beginning check: " . $thiserrorchecktype;
		if ( &::errorcheckrun( $thiserrorchecktype ) ) {
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
					     ( not $::verboseerrorchecks )
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
				if (     ( not $::verboseerrorchecks )
					 and ( $thiserrorchecktype eq 'Link Check' )
					 and ( $line =~ /^Link statistics/i ) )
				{
					last;
				}
				if ( $thiserrorchecktype eq 'pphtml' ) {
					if ( $line =~ /^-/i ) {    # skip lines beginning with '-'
						next;
					}
					if ( ( not $::verboseerrorchecks )
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
						$::errors{$line} = '';
						$lincol = '';
						if ( $line =~ /^line (\d+) column (\d+)/i ) {
							$lincol = "$1.$2";
							$mark++;
							$textwindow->markSet( "t$mark", $lincol );
							$::errors{$line} = "t$mark";
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
					$::errors{$line} = '';
					$lincol = '';
					if ( $line =~ /line (\d+):(\d+)/ ) {
						push @errorchecklines, $line;
						$lincol = "$1.$2";
						$lincol =~ s/\.0/\.1/;  # change column zero to column 1
						$mark++;
						$textwindow->markSet( "t$mark", $lincol );
						$::errors{$line} = "t$mark";
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
					$::errors{$line} = '';
					$lincol = '';
					if ( $line =~ /line (\d+):(\d+)/ ) {
						my $plusone = $1 + 1;
						$lincol = "$plusone.$2";
						$mark++;
						$textwindow->markSet( "t$mark", $lincol );
						$::errors{$line} = "t$mark";
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
		&::working();
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
	my $textwindow = $::textwindow;
	my $top = $::top;
	if ( $errorchecktype eq 'W3C Validate Remote' ) {
		unless ( eval { require WebService::Validator::HTML::W3C } ) {
			print
"Install the module WebService::Validator::HTML::W3C to do W3C Validation remotely. Defaulting to local validation.\n";
			$errorchecktype = 'W3C Validate';
		}
	}
	push @::operations, ( localtime() . ' - $errorchecktype' );
	&::viewpagenums() if ( $::lglobal{seepagenums} );
	if ( $::lglobal{errorcheckpop} ) {
		$::lglobal{errorchecklistbox}->delete( '0', 'end' );
	}
	my ( $name, $fname, $path, $extension, @path );
	$textwindow->focus;
	&::update_indicators();
	my $title = $top->cget('title');
	if ( $title =~ /No File Loaded/ ) { &::savefile($textwindow,$top) }
	my $types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
	if ( $errorchecktype eq 'W3C Validate CSS' ) {
		$types = [ [ 'JAR file', [ '.jar', ] ], [ 'All Files', ['*'] ], ];
	}
	if ( $errorchecktype eq 'HTML Tidy' ) {
		unless ($::tidycommand) {
			$::tidycommand =
			  $textwindow->getOpenFile(
					-filetypes => $types,
					-title => "Where is the " . $errorchecktype . " executable?"
			  );
		}
		return 1 unless $::tidycommand;
		$::tidycommand = &::os_normal($::tidycommand);
	} elsif (     ( $errorchecktype eq "W3C Validate" )
			  and ( $::w3cremote == 0 ) )
	{
		unless ($::validatecommand) {
			$::validatecommand =
			  $textwindow->getOpenFile(
					 -filetypes => $types,
					 -title => 'Where is the W3C Validate (onsgmls) executable?'
			  );
		}
		return 1 unless $::validatecommand;
		$::validatecommand = &::os_normal($::validatecommand);
	} elsif ( $errorchecktype eq 'W3C CSS Validate' ) {
		unless ($::validatecsscommand) {
			$::validatecsscommand =
			  $textwindow->getOpenFile(
				-filetypes => $types,
				-title =>
				  'Where is the W3C Validate CSS (css-validate.jar) executable?'
			  );
		}
		return 1 unless $::validatecsscommand;
		$::validatecsscommand = &::os_normal($::validatecsscommand);
	}
	&::savesettings();
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
		&::run( $::tidycommand, "-f", "errors.err", "-o", "null",
					$name );
	} elsif ( $errorchecktype eq 'W3C Validate' ) {
		if ( $::w3cremote == 0 ) {
			my $validatepath = &::dirname($::validatecommand);
			&::run(
						$::validatecommand, "--directory=$validatepath",
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
		my $runner = &::runner::tofile("errors.err");
		$runner->run( "java", "-jar", $::validatecsscommand, "file:$name" );
	} elsif ( $errorchecktype eq 'pphtml' ) {
		&::run( "perl", "lib/ppvchecks/pphtml.pl", "-i", $name, "-o",
					"errors.err" );
	} elsif ( $errorchecktype eq 'Link Check' ) {
		&::linkcheckrun;
	}
	elsif ( $errorchecktype eq 'Image Check' ) {
		my ( $f, $d, $e ) =
		  &::fileparse( $::lglobal{global_filename}, qr{\.[^\.]*$} );
		&::run( "perl", "lib/ppvchecks/ppvimage.pl", $name, $d );
	} elsif ( $errorchecktype eq 'pptxt' ) {
		&::run( "perl", "lib/ppvchecks/pptxt.pl", "-i", $name, "-o",
					"errors.err" );
	} elsif ( $errorchecktype eq 'Epub Friendly' ) {
		&::run( "perl", "lib/ppvchecks/epubfriendly.pl",
					"-i", $name, "-o", "errors.err" );
	}
	$top->Unbusy;
	unlink $name;
	return;
}
1;
