package Guiguts::SearchReplaceMenu;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&add_search_history)
}

sub add_search_history {
	if ($main::scannosearch) {
		return; # do not add to search history during a scannos check		
	} 
	my ( $term, $history_array_ref,$history_size ) = @_;
	my @temparray = @$history_array_ref;
	@$history_array_ref = ();
	push @$history_array_ref, $term;
	for (@temparray) {
		next if $_ eq $term;
		push @$history_array_ref, $_;
		last if @$history_array_ref >= $history_size;
	}
}



1;


