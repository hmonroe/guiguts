########################################################################
# config.pl 
# config file for transform.pl
#
# this file tells transform.pl where your binaries are located
#

use File::Spec;
use File::Basename;
my $config_dir = dirname(File::Spec->rel2abs($0));

$config = {
# the directory the transform.pl executable is in
    install_dir        => $config_dir,

# the xmlcatalog file
    catalog_file       => $config_dir . '/xmlcatalog',

#tei2html
    tidy               => $config_dir . '/../../../tools/tidy/tidy.exe',

# tei2txt
    nroff              => $config_dir . '/../../../tools/groff/bin/groff.exe',

# tei2pdf
    pdflatex           => 'c:/texlive/2011/bin/win32/pdflatex',

# convert <formula notation="tex"> to image
    latex              => '/usr/bin/latex',
    dvips              => '/usr/bin/dvips',
    convert            => '/usr/bin/convert',
    identify           => '/usr/bin/identify',
};

1;
