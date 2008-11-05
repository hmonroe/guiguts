#$Id: TextConvert.pm 56 2008-09-27 17:37:26Z vlsimpson $

package TextConvert;

use warnings;
use strict;

sub text_convert_italic {
    my $italic  = qr/<\/?i>/;
    my $replace = shift @_;
    $main::textwindow->FindAndReplaceAll( '-regexp', '-nocase', $italic, $replace );
}



1;


