echo off
PATH=%PATH%;%cd%\perl;%cd%\perl\lib;%cd%\python27;%cd%\python27\scripts;%cd%\tools\groff\bin
    set ENCFONTS=c:/dp/gnutenbergproj/gnutenberg/0.4/pdf/fonts/generated 
    set TEXFONTS=c:/dp/gnutenbergproj/gnutenberg/0.4/pdf/fonts/generated
    set TEXFONTMAPS=c:/dp/gnutenbergproj/gnutenberg/0.4/pdf/fonts/generated
    set TFMFONTS=c:/dp/gnutenbergproj/gnutenberg/0.4/pdf/fonts/generated
    set TTFONTS=c:/dp/gnutenbergproj/gnutenberg/0.4/pdf/fonts/generated
    set TEXPSHEADERS=c:/dp/gnutenbergproj/gnutenberg/0.4/pdf/fonts/generated

perl guiguts.pl %1