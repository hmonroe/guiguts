package Guiguts::Utilities;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&openpng )
}

# Routine to handle image viewer file requests
sub openpng {
	my $pagenum = shift;
	if ( $pagenum eq 'Pg' ) {
		return;
	}
	$main::lglobal{pageimageviewed} = $pagenum;
	if ( not $main::globalviewerpath ) {
		&main::viewerpath();
	}
	my $imagefile = &main::get_image_file($pagenum);
	if ( $imagefile && $main::globalviewerpath ) {
		&main::runner( $main::globalviewerpath, $imagefile );
	} else {
		&main::setpngspath($pagenum);
	}
	return;
}


1;


