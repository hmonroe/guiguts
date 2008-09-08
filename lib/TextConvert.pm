#$Id$

package TextConvert;

print "DEBUG: Loading TextConvert\n";

use warnings;
use strict;

sub text_convert_italic {
    my $italic  = qr/<\/?i>/;
    my $replace = shift @_;
    $main::textwindow->FindAndReplaceAll( '-regexp', '-nocase', $italic, $replace );
}



1;


