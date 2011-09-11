This is a major version which will become 1.0 once the bugs are ironed 
out (see this discussion http://www.pgdp.net/phpBB2/viewtopic.php?t=48584).
Note: upgrading to this version requires a complete reinstall (save your
header.txt and setting.rc files). 

Relative to version 0.2.10 there are several major new features. First,
all the HTML checks can be run with a single click, and the output is
clickable in most cases. Second, HTML and CSS validation can now be done
on your own computer (and PGTEI as well) and there are checks for unused
CSS and image issues (using rfrank's pphtml, ppimage, and pptxt
scripts). Third, there is now an option to view text and images
side-by-side without having to click on "See Image" for each page. For
instance you move forward or back one page for both text and image with
the "<" and ">" buttons on the status bar. Also, the Auto Show Images option
let's you see the image for instance for the page you are spellchecking.
(See tips on viewer configuration below.) Fourth, with Winguts there is
no need to install Perl on Windows computers (for other platforms see
below).

Other new features are: a "View in Browser" and Hyperlink page numbers
buttons on the HTML palette, tearoff of the Unicode menu, listing small
caps in the Word Frequency popup, automatic checking for updates (which
can be turned off), horizontal rules as css, if nothing is found the
cursor returns to the starting point, better ability to find executables
automatically, GutWrench scanno files are included, inclusion of
rfrank's pphtml and pptxt scripts, a warning to use human readable
filenames, option to include goodwords in spellcheck project dictionary,
a text processing menu to ease conversion of bold/italics/small caps,
the label Image #nnn in Configure Page Labels is clickable, added Find
Transliterations and Find Orphaned Markup (before it only searched for
unmatched brackets) to Search menu, Adjust Page Markers menu is
accessible from the File menu. For developers, there are internal
improvements, including refactoring of functionality into perl modules
and a unit testing framework.

Bug fixes already included: less mangling of HTML page numbers (for
instance [Pg 42-44] instead of three overlapping page numbers),
superscripts are converted to HTML correctly (Philad^a) without curly
brackets, fixed regex editor for scannos, Ctrl-S saves the file.

The side by side image viewing works best if the window for the viewer
is sized to match the image (in XnView, choose View, Auto Image Size,
Fit Image to Window) and only one instance of the viewer is allowed to
avoid having one instance for every page viewed (in XnView, choose
Tools, Options, General, Only One Instance). To page through images, use
the "<" and ">" buttons on the status bar. To Auto Show Page Images, use the
"Auto Img" button on the status bar, use the option on the Prefs menu,
or checkboxes in the various search/spellcheck dialogs.

I would be happy to release Mac and Unix executables which only requires
someone to run tkpp following the instructions in COMPILING.txt. A Mac
or Unix distribution should also include the OpenJade/OpenSP onsgmls
executable for HTML/PGTEI validation.

Detailed release notes:

Version 0.3.7 Fixed problem with <blockquote><p><p> and more broadly only
inserts a </p> if there is an open <p> and only inserts a <p> if there is not
an open <p>. Dash in proofer's name no longer messes up display of proofers.

Version 0.3.6 There is a much higher likelihood that this version generates
valid HTML. Page anchors are no longer placed at the end of the previous paragraph
or before the horizontal rule. The default for word search from the Word Frequency menu
is now "Whole Word". Fixed Go To Bookmarks. There is only one file guiguts-0.3.6.zip
which includes the WinGuts.exe.

Version 0.3.5 Fixed multiple page markers at a single location so they do not overlap but stack vertically like 
[Pg 32]<br />[Pg 33]. Fixed problem with moving mark left (entry for initial page number 
was blank) or up (code was garbled). Removed splash screen. Fixed monthly update check to give user the option.
Fixed openpng so if the image viewer is not set the user is prompted to set it. 

Version 0.3.3 Fixed problem in WinGuts.exe with conflicting Tk library.

Version 0.3.2 Fixed pathname problem for non-Windows system for splash screen. 