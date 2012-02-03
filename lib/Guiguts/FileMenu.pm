package Guiguts::FileMenu;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&file_open &file_include &_exit )
}

sub file_open {    # Find a text file to open
	my $textwindow = shift;
	my ($name);
	return if ( &main::confirmempty() =~ /cancel/i );
	my $types = [
				  [
					'Text Files',
					[qw/.txt .text .ggp .htm .html .rst .bk1 .bk2 .xml .tei/]
				  ],
				  [ 'All Files', ['*'] ],
	];
	$name = $textwindow->getOpenFile(
									  -filetypes  => $types,
									  -title      => 'Open File',
									  -initialdir => $main::globallastpath
	);
	if ( defined($name) and length($name) ) {
		&main::openfile($name);
	}
}



sub file_include {    # FIXME: Should include even if no file loaded.
	my $textwindow= shift;
	my ($name);
	my $types = [
				  [
					 'Text Files',
					 [ '.txt', '.text', '.ggp', '.htm', '.html', '.rst','.tei','.xml' ]
				  ],
				  [ 'All Files', ['*'] ],
	];
	return if $main::lglobal{global_filename} =~ m{No File Loaded};
	$name = $textwindow->getOpenFile(
									  -filetypes  => $types,
									  -title      => 'File Include',
									  -initialdir => $main::globallastpath
	);
	$textwindow->IncludeFile($name)
	  if defined($name)
		  and length($name);
	&main::update_indicators();
	return;
}

## Global Exit
sub _exit {
	if ( &main::confirmdiscard() =~ m{no}i ) {
		&main::aspellstop() if $main::lglobal{spellpid};
		exit;
	}
}



1;


