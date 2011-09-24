package Guiguts::FileMenu;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&tester )
}

sub tester {
	print "sadf".$main::lglobal{global_filename}."\n";
	
}

1;


