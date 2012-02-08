package Guiguts::Utilities;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&openpng &setviewerpath &setdefaultpath)
}

# Routine to handle image viewer file requests
sub openpng {
	my ($textwindow,$pagenum) = @_;
	if ( $pagenum eq 'Pg' ) {
		return;
	}
	$main::lglobal{pageimageviewed} = $pagenum;
	if ( not $main::globalviewerpath ) {
		&main::setviewerpath($textwindow);
	}
	my $imagefile = &main::get_image_file($pagenum);
	if ( $imagefile && $main::globalviewerpath ) {
		&main::runner( $main::globalviewerpath, $imagefile );
	} else {
		&main::setpngspath($pagenum);
	}
	return;
}

sub setviewerpath {    #Find your image viewer
	my $textwindow = shift;
	my $types;
	if ($main::OS_WIN) {
		$types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
	} else {
		$types = [ [ 'All Files', ['*'] ] ];
	}
	print $main::globalviewerpath."aa\n";
	print &main::dirname($main::globalviewerpath)."aa\n";
	
	$main::lglobal{pathtemp} =
	  $textwindow->getOpenFile(
								-filetypes  => $types,
								-title      => 'Where is your image viewer?',
								-initialdir => &main::dirname($main::globalviewerpath)
	  );
	$main::globalviewerpath = $main::lglobal{pathtemp} if $main::lglobal{pathtemp};
	$main::globalviewerpath = &main::os_normal($main::globalviewerpath);
	&main::savesettings();
}
sub setdefaultpath {
	my ($pathname,$path) = @_;
	if ((!$pathname) && (-e $path)) {return $path;} else {
	return ''}
}

1;


