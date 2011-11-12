########################################################################
# config.pl 
# config file for transform.pl
#
# this file tells transform.pl where your binaries are located
#

$config = {
# the directory the transform.pl executable is in
    install_dir        => 'c:/dp/gnutenbergproj/gnutenberg/0.4/',

# the xmlcatalog file
    catalog_file       => 'c:/dp/gnutenbergproj/gnutenberg/0.4/xmlcatalog',

#tei2html
    tidy               => 'C:/guiguts/giuguts/tools/tidy/tidy.exe',

# tei2txt
    nroff              => 'C:/guiguts/giuguts/tools/groff/bin/groff.exe',

# tei2pdf
    pdflatex           => 'c:/texlive/2011/bin/win32/pdflatex',

# convert <formula notation="tex"> to image
    latex              => '/usr/bin/latex',
    dvips              => '/usr/bin/dvips',
    convert            => '/usr/bin/convert',
    identify           => '/usr/bin/identify',
};

1;
