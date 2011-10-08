This is a major version which will become 1.0 once the bugs are ironed 
out (see this discussion http://www.pgdp.net/phpBB2/viewtopic.php?t=48584).
Note: upgrading to this version requires a complete reinstall (save your
header.txt and setting.rc files). 

Relative to version 0.2.10, the main changes are (1) one click installation
of binaries on Windows and Macintosh/OSX computers with no need to install 
perl (see winguts and macguts zip files); (2) several major new features, 
and (3) fixes to many long-standing bugs.  

Major new features include: First, all the HTML checks can be run with a 
single click, and the output is clickable in most cases. Second, HTML and CSS 
validation can now be done on your own computer (and PGTEI as well) and 
there are checks for unused CSS and image issues (using the pphtml, 
ppimage, and pptxt scripts). Third, there is now an option to view text and 
images side-by-side without having to click on "See Image" for each page. For
instance you move forward or back one page for both text and image with
the "<" and ">" buttons on the status bar. Also, the Auto Show Images option
lets you see the image for instance for the page you are spellchecking.
(See tips on viewer configuration below.) 

Other new features are: a "View in Browser" and Hyperlink page numbers
buttons on the HTML palette, tearoff of the Unicode menu, listing small
caps in the Word Frequency popup, automatic checking for updates (which
can be turned off), horizontal rules as css, an option if nothing is found to 
return to the starting point, better ability to find executables
automatically, GutWrench scanno files are included, , a warning to use human 
readable filenames, option to include goodwords in spellcheck project dictionary,
a text processing menu to ease conversion of bold/italics/small caps,
the label Image #nnn in Configure Page Labels is clickable, added Find
Transliterations and Find Orphaned Markup (before it only searched for
unmatched brackets) to Search menu, Adjust Page Markers menu is
accessible from the File menu. Most popups now remember if they have been moved 
or resized. Unless the user has previously set the size of the main
screen, it is maximized (nearly) on the first run. For developers, there 
are internal improvements, including partial refactoring of functionality into perl 
modules and a unit testing framework.

Bug fixes include: Dash or periods in the proofer's name no longer 
messes up display of proofers or removal of page separators. Fixed 
moving of page markers. The default for word search from the Word 
Frequency menu is now "Whole Word". Unicode menu is now broken into two 
pieces so it does not run off the screen where Mac users cannot see it. 
Also, the Unicode popup has a pulldown list to change UTF blocks. Replace 
All now replaces all and is a factor of 10 faster (but not for regexes). 
Double click in Word Frequency does whole word search 
by default. "--" on a line by itself gets converted to an emdash. Fixed regex 
editor for scannos, Ctrl-S saves the file. There is a much higher likelihood 
that this version generates valid HTML. Page anchors are no longer placed at 
the end of the previous paragraph or before the horizontal rule. Fixed 
misplacment/overlapping of HTML page numbers, superscripts are converted to 
HTML correctly (Philad^a) without curly brackets.

The side by side image viewing works best if the window for the viewer
is sized to match the image (in XnView, choose View, Auto Image Size,
Fit Image to Window) and only one instance of the viewer is allowed to
avoid having one instance for every page viewed (in XnView, choose
Tools, Options, General, Only One Instance). To page through images, use
the "<" and ">" buttons on the status bar. To Auto Show Page Images, use the
"Auto Img" button on the status bar, use the option on the Prefs menu,
or checkboxes in the various search/spellcheck dialogs.

Detailed release notes:

Version 0.3.12 Fixed page numbers when pngs begin with a letter such 
as "a001.png". When reopening a document, the cursor is returned to where
it was with focus. Leave out alt and title tags from <img if blank.

Version 0.3.11 Fixed WinGuts which could not run external programs such 
as an image viewer unless perl was installed. Fixed accelerators for 
bookmarks (Shift+Ctrl+1).

Version 0.3.10 Removed extraneous files from .zip by adding "make" file.
Alerted user if CSS Validate failed to run. Fixed poetry rewrap
margin. Fixed default gutcheck window size. Button highlight color is
now remembered. Default file handler from the External Operations 
menu is now used by the "View in Browser" button on the HTML palette.
Fixed behavior if user cancels without specifying tidy.exe or
other executables for checking HTML.

Version 0.3.9 All popups now remember if they have been moved or resized. 
Unless the user has previously set the size of the main
screen, it is maximized (nearly) on the first run. This version restores default 
behavior that failed searches send cursor to beginning rather than where it was
but added an option for the latter. Fixed bugs with 
small caps conversion; replace all with regex and
$1 backreferences, stripping markup from captions in HTML. Changing
the pngs path saves the .bin file immediately.  

Version 0.3.8 Unicode menu is now broken into two pieces so it does not 
run off the screen where Mac users cannot see it. Also, the Unicode popup
has a pulldown list to change UTF blocks. 

Version 0.3.7 Fixed problem with <blockquote><p><p> and more broadly only
inserts a </p> if there is an open <p> and only inserts a <p> if there is not
an open <p>. Dash in proofer's name no longer messes up display of proofers.
Replace All now replaces all. Double click in Word Frequency does whole word
search by default. "--" on a line by itself gets converted to an emdash.

Version 0.3.6 There is a much higher likelihood that this version generates
valid HTML. Page anchors are no longer placed at the end of the previous 
paragraph or before the horizontal rule. The default for word search from 
the Word Frequency menu is now "Whole Word". Fixed Go To Bookmarks. There 
is only one file guiguts-0.3.6.zip which includes the WinGuts.exe.

Version 0.3.5 Fixed multiple page markers at a single location so they do not 
overlap but stack vertically like [Pg 32]<br />[Pg 33]. Fixed problem with 
moving mark left (entry for initial page number was blank) or up (code was 
garbled). Removed splash screen. Fixed monthly update check to give user the 
option. Fixed openpng so if the image viewer is not set the user is prompted 
to set it. 

Version 0.3.3 Fixed problem in WinGuts.exe with conflicting Tk library.

Version 0.3.2 Fixed pathname problem for non-Windows system for splash screen. 