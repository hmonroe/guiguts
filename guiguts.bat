echo off
PATH=%cd%\perl;%cd%\perl\lib;%cd%\python27;%cd%\python27\scripts;%cd%\tools\groff\bin;%cd%\tools\kindlegen;%cd%\tools\tidy;%PATH%
    set ENCFONTS=c:/guiguts/tools/gnutenbergproj/gnutenberg/0.4/pdf/fonts/generated 
    set TEXFONTS=c:/guiguts/tools/gnutenberg/0.4/pdf/fonts/generated
    set TEXFONTMAPS=c:/guiguts/tools/gnutenberg/0.4/pdf/fonts/generated
    set TFMFONTS=c:/guiguts/tools/gnutenberg/0.4/pdf/fonts/generated
    set TTFONTS=c:/guiguts/tools/gnutenberg/0.4/pdf/fonts/generated
    set TEXPSHEADERS=c:/guiguts/tools/gnutenberg/0.4/pdf/fonts/generated

%cd%\perl\perl.exe guiguts.pl %1