@echo off

cd %~dp0

set PATH=%cd%\perl;%cd%\perl\lib;%cd%\python27;%cd%\python27\scripts;%cd%\tools\groff\bin;%cd%\tools\kindlegen;%cd%\tools\tidy;%PATH%

    set ENCFONTS=    %cd%/tools/gnutenberg/0.4/pdf/fonts/generated 
    set TEXFONTS=    %cd%/tools/gnutenberg/0.4/pdf/fonts/generated
    set TEXFONTMAPS= %cd%/tools/gnutenberg/0.4/pdf/fonts/generated
    set TFMFONTS=    %cd%/tools/gnutenberg/0.4/pdf/fonts/generated
    set TTFONTS=     %cd%/tools/gnutenberg/0.4/pdf/fonts/generated
    set TEXPSHEADERS=%cd%/tools/gnutenberg/0.4/pdf/fonts/generated

start /B "" "%cd%\perl\perl.exe" guiguts.pl %1
