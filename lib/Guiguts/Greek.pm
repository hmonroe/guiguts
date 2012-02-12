package Guiguts::Greek;

use strict;
use warnings;

BEGIN {
	use Exporter();
	our (@ISA, @EXPORT);
	@ISA    = qw(Exporter);
	@EXPORT = qw(&fromgreektr);
}

sub fromgreektr {
	my $phrase = shift;
	$phrase =~ s/\x{03C2}($|\W)/s$1/g;
	$phrase =~ s/\x{03B8}/th/g;
	$phrase =~ s/\x{03B3}\x{03B3}/ng/g;
	$phrase =~ s/\x{03B3}\x{03BA}/nk/g;
	$phrase =~ s/\x{03B3}\x{03BE}/nx/g;
	$phrase =~ s/\x{1FE5}/rh/g;
	$phrase =~ s/\x{03C6}/ph/g;
	$phrase =~ s/\x{03B3}\x{03C7}/nch/g;
	$phrase =~ s/\x{03C7}/ch/g;
	$phrase =~ s/\x{03C8}/ps/g;
	$phrase =~ s/\x{1F01}/ha/g;
	$phrase =~ s/\x{1F11}/he/g;
	$phrase =~ s/\x{1F21}/hê/g;
	$phrase =~ s/\x{1F31}/hi/g;
	$phrase =~ s/\x{1F41}/ho/g;
	$phrase =~ s/\x{1F51}/hy/g;
	$phrase =~ s/\x{1F61}/hô/g;
	$phrase =~ s/\x{03A7}/Ch/g;
	$phrase =~ s/\x{0398}/Th/g;
	$phrase =~ s/\x{03A6}/Ph/g;
	$phrase =~ s/\x{03A8}/Ps/g;
	$phrase =~ s/\x{1F09}/Ha/g;
	$phrase =~ s/\x{1F19}/He/g;
	$phrase =~ s/\x{1F29}/Hê/g;
	$phrase =~ s/\x{1F39}/Hi/g;
	$phrase =~ s/\x{1F49}/Ho/g;
	$phrase =~ s/\x{1F59}/Hy/g;
	$phrase =~ s/\x{1F69}/Hô/g;
	$phrase =~ s/\x{0391}/A/g;
	$phrase =~ s/\x{03B1}/a/g;
	$phrase =~ s/\x{0392}/B/g;
	$phrase =~ s/\x{03B2}/b/g;
	$phrase =~ s/\x{0393}/G/g;
	$phrase =~ s/\x{03B3}/g/g;
	$phrase =~ s/\x{0394}/D/g;
	$phrase =~ s/\x{03B4}/d/g;
	$phrase =~ s/\x{0395}/E/g;
	$phrase =~ s/\x{03B5}/e/g;
	$phrase =~ s/\x{0396}/Z/g;
	$phrase =~ s/\x{03B6}/z/g;
	$phrase =~ s/\x{0397}/Ê/g;
	$phrase =~ s/\x{03B7}/ê/g;
	$phrase =~ s/\x{0399}/I/g;
	$phrase =~ s/\x{03B9}/i/g;
	$phrase =~ s/\x{039A}/K/g;
	$phrase =~ s/\x{03BA}/k/g;
	$phrase =~ s/\x{039B}/L/g;
	$phrase =~ s/\x{03BB}/l/g;
	$phrase =~ s/\x{039C}/M/g;
	$phrase =~ s/\x{03BC}/m/g;
	$phrase =~ s/\x{039D}/N/g;
	$phrase =~ s/\x{03BD}/n/g;
	$phrase =~ s/\x{039E}/X/g;
	$phrase =~ s/\x{03BE}/x/g;
	$phrase =~ s/\x{039F}/O/g;
	$phrase =~ s/\x{03BF}/o/g;
	$phrase =~ s/\x{03A0}/P/g;
	$phrase =~ s/\x{03C0}/p/g;
	$phrase =~ s/\x{03A1}/R/g;
	$phrase =~ s/\x{03C1}/r/g;
	$phrase =~ s/\x{03A3}/S/g;
	$phrase =~ s/\x{03C3}/s/g;
	$phrase =~ s/\x{03A4}/T/g;
	$phrase =~ s/\x{03C4}/t/g;
	$phrase =~ s/\x{03A9}/Ô/g;
	$phrase =~ s/\x{03C9}/ô/g;
	$phrase =~ s/\x{03A5}(?=\W)/Y/g;
	$phrase =~ s/\x{03C5}(?=\W)/y/g;
	$phrase =~ s/(?<=\W)\x{03A5}/U/g;
	$phrase =~ s/(?<=\W)\x{03C5}/u/g;
	$phrase =~ s/([AEIOU])\x{03A5}/$1U/g;
	$phrase =~ s/([AEIOUaeiou])\x{03C5}/$1u/g;
	$phrase =~ s/\x{03A5}/Y/g;
	$phrase =~ s/\x{03C5}/y/g;
	$phrase =~ s/\x{037E}/?/g;
	$phrase =~ s/\x{0387}/;/g;
	$phrase =~ s/(\p{Upper}\p{Lower}\p{Upper})/\U$1\E/g;
	$phrase =~ s/([AEIOUaeiou])y/$1u/g;
	return $phrase;
}


1;
