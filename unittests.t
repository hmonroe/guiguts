use strict;
use Test::More tests => 1;

use FindBin;
use lib $FindBin::Bin . "/lib";

BEGIN {
    use_ok('Guiguts::HTMLConvert');
}

