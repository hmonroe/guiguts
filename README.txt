See http://www.pgdp.net/wiki/Guiguts_new_features_and_bug_fixes for a
description of new features and bug fixes in Version 1.0.0. Detailed
release notes for subsequent versions will be added below.

guiguts-win-epub-1.0.0.zip is the best download for Windows users. It includes
guiguts.pl and supporting files and helper applications including those
for working with RST and PGTEI files. It should work out of the box by running
guiguts.bat (it includes copies of perl and Python languages). guiguts-win-1.0.0.zip 
does not include support for RST and PGTEI or Python. guiguts-1.0.0.zip
is a stripped down version for those who have all the helper applications or
are upgrading or who use operating systems other than Windows.

Version 1.0.1 Got rid of undo on fix page separatorpopup which does not work properly.
Improved regexp to search for orphaned markup per RoryConnor. Cleared undo
cache after HTML autogenerate. Set command to open browser for non-Windows OS
and use it for external operations. Dictionary search on the external operations menu 
now passes the selection as a search argument. Made ASCII Boxes popup resizable.
Removed trailing space on last line of /# #/ block after rewrap.