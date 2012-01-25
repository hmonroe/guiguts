See http://www.pgdp.net/wiki/Guiguts_new_features_and_bug_fixes for a
description of new features and bug fixes in Version 1.0.0. Detailed
release notes for subsequent versions will be added below.

guiguts-win-1.0.nn.zip is the best download for Windows users. It
includes guiguts.pl and supporting files and helper applications
including those for working with RST and PGTEI files. It should work out
of the box by running guiguts.bat (it includes copies of perl and Python
languages). guiguts-mac-1.0.nn should also work out of the box for Mac users.
guiguts-1.0.nn.zip is a stripped down version for those who have all the helper
applications or are upgrading or who use operating systems other than Windows/Mac.

Version 1.0.5. Added a rudimentary check of whether HTML is "Epub friendly".
Changed <p> css in headerdefault.txt to work better on mobi devices: 
margin-top: .51em; margin-bottom: .49em;. Reorganized the Preference menu. 
Added Advanced Menu with RST and PGTEI tools. Fixed bug with Gutcheck
hanging on rerun. Added check for whether the string entered in the 
RegExp field in the Word Frequency popup is a valid regular expression. 
Added Source menu with View Project Comments item. Added PP Process Checklist
to Help menu.

Version 1.0.4. Hyphen check now also checks for "flash light" not only
"flash-light", "flash--light", and "flashlight". A regular expression search 
over line breaks now respects the ignore case flag. Fixed path and extension 
so EpubMaker will take .html files as input. PPV TXT and PP HTML labeled more 
accurately as pptxt and pphtml. Only README.TXT appears in the prepopulated 
recently used file list. Search can find the first word in the file. Word 
frequency rerun after typing words in empty file reports now works and bug with
unresponsive save as dialog fixed. Guiguts.bat calls perl in a way that should 
(may) ignore preexisting installations of perl.

Version 1.0.3. Relocated HTML page number outside an open <span> eg for a line
of poetry so page numbers align vertically. Auto List on HTML palette no
longer removes spaces before markup in multiline mode. HTML anchors for
chapter headings are no longer empty but surround the chapter title
text. Join Lines removes */ /* </i> <i> etc. markup only if it matches. Fixed
Undo button on Fix Page Separator popup and added Redo button. Fixed
Find Greek on the Fixup menu to find all [Greek: ] occurrences.
Unicode->beta no longer converts \x{1FA7} and certain other characters
into %{HASH(0x4f10ff8)}. Added beta code for Greek character stigma.
Fixed bug if user tries to highlight scannos using the scannos list in
the scannos directory rather than a a word list in the word list
directory.

Version 1.0.2. Fixed problem in which a regex replace with \G in the
found text led to characters being converted to Greek. Added message to
run final W3C markup validation at validator.w3.org. Improved conversion
of < and > characters when autogenerating HTML.

Version 1.0.1. Revamped spell checker including in Word Frequency popup
to handle UTF-8. Fixed "wide character in print" error by running
utf8::encode. Improved regexp to search for orphaned markup per
RoryConnor. Cleared undo cache after HTML autogenerate. Set command to
open browser for non-Windows OS and use it for external operations.
Dictionary search on the external operations menu now passes the
selection as a search argument. Made ASCII Boxes popup resizable.
Removed trailing space on last line of /# #/ block after rewrap. Respect 
preference to leave space after end of line hyphen during rewrap if Join
Lines Keep Hyphen is chosen. Removed period on "Set margins for rewrap."
Changed "Check Errors" box to "Run Checks". Run fixup ignores /X X/ (as
well as /* */ and /$ $/) blocks if the first option is checked. Fixed
ordering of page numbers anchored inside HTML <h1> or <h2> tags. Add gutcheck
and jeebies directories without the .exe files to the guiguts-n.n.n.zip
file.