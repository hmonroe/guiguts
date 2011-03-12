#$Id: TextConvert.pm 56 2008-09-27 17:37:26Z vlsimpson $

package Guiguts::HTMLConvert;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&html_convert_tb &htmlbackup);
}

sub html_convert_tb {
	no warnings;    # FIXME: Warning-- Exiting subroutine via next
	my ($textwindow, $selection, $step ) = @_;

	if ( $selection =~ s/\s{7}(\*\s{7}){4}\*/<hr style="width: 45%;" \/>/ ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
		$next;
	}

	if ( $selection =~ s/<tb>/<hr style="width: 45%;" \/>/ ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
		next;
	}

}

sub htmlbackup {
	my ($textwindow ) = @_;
	$textwindow->Busy;
	my $savefn = $lglobal{global_filename};
	$lglobal{global_filename} =~ s/\.[^\.]*?$//;
	my $newfn = $lglobal{global_filename} . '-htmlbak.txt';
	&main::working("Saving backup of file\nto $newfn");
	$textwindow->SaveUTF($newfn);
	$lglobal{global_filename} = $newfn;
	&main::_bin_save();
	$lglobal{global_filename} = $savefn;
	$textwindow->FileName($savefn);
}



1;


