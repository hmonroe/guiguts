package Guiguts::MenuStructure;

BEGIN {
	use Exporter();
	@ISA=qw(Exporter);
	@EXPORT=qw(&menu_preferences &menu_bookmarks &menu_external &menubuildold &menubuild &menubuildtwo)
}

use strict;
use warnings;

sub menu_preferences {
	my $textwindow = $main::textwindow;
	[
	   [
		  Cascade  => 'File ~Paths',
		  -tearoff => 1,
		  -menuitems =>
			[  # FIXME: sub this and generalize for all occurences in menu code.
			  [
				 Button   => 'Locate Aspell Executable',
				 -command => sub {
					 my $types;
					 if ($main::OS_WIN) {
						 $types = [
									[ 'Executable', [ '.exe', ] ],
									[ 'All Files',  ['*'] ],
						 ];
					 } else {
						 $types = [ [ 'All Files', ['*'] ] ];
					 }
					 $main::lglobal{pathtemp} =
					   $textwindow->getOpenFile(
									-filetypes => $types,
									-title => 'Where is the Aspell executable?',
									-initialdir => &main::dirname($main::globalspellpath)
					   );
					 $main::globalspellpath = $main::lglobal{pathtemp}
					   if $main::lglobal{pathtemp};
					 return unless $main::globalspellpath;
					 $main::globalspellpath = &main::os_normal($main::globalspellpath);
					 &main::savesettings();
				   }
			  ],
			  [
				 Button   => 'Locate Image Viewer Executable',
				 -command => sub{&main::setviewerpath($textwindow)}
			  ],
			  [ 'separator', '' ],
			  [
				 Button   => 'Locate Gutcheck Executable',
				 -command => sub {
					 my $types;
					 if ($main::OS_WIN) {
						 $types = [
									[ 'Executable', [ '.exe', ] ],
									[ 'All Files',  ['*'] ],
						 ];
					 } else {
						 $types = [ [ 'All Files', ['*'] ] ];
					 }
					 $main::lglobal{pathtemp} =
					   $textwindow->getOpenFile(
								  -filetypes => $types,
								  -title => 'Where is the Gutcheck executable?',
								  -initialdir => &main::dirname($main::gutcommand)
					   );
					 $main::gutcommand = $main::lglobal{pathtemp}
					   if $main::lglobal{pathtemp};
					 return unless $main::gutcommand;
					 $main::gutcommand = &main::&main::os_normal($main::gutcommand);
					 &main::savesettings();
				   }
			  ],
			  [
				 Button   => 'Locate Jeebies Executable',
				 -command => sub {
					 my $types;
					 if ($main::OS_WIN) {
						 $types = [
									[ 'Executable', [ '.exe', ] ],
									[ 'All Files',  ['*'] ],
						 ];
					 } else {
						 $types = [ [ 'All Files', ['*'] ] ];
					 }
					 $main::lglobal{pathtemp} =
					   $textwindow->getOpenFile(
								   -filetypes => $types,
								   -title => 'Where is the Jeebies executable?',
								   -initialdir => &main::dirname($main::jeebiescommand)
					   );
					 $main::jeebiescommand = $main::lglobal{pathtemp}
					   if $main::lglobal{pathtemp};
					 return unless $main::jeebiescommand;
					 $main::jeebiescommand = &main::&main::os_normal($main::jeebiescommand);
					 &main::savesettings();
				   }
			  ],
			  [
				 Button   => 'Locate Tidy Executable',
				 -command => sub {
					 my $types;
					 if ($main::OS_WIN) {
						 $types = [
									[ 'Executable', [ '.exe', ] ],
									[ 'All Files',  ['*'] ],
						 ];
					 } else {
						 $types = [ [ 'All Files', ['*'] ] ];
					 }
					 $main::tidycommand =
					   $textwindow->getOpenFile(
									   -filetypes  => $types,
									   -initialdir => &main::dirname($main::tidycommand),
									   -title => 'Where is the Tidy executable?'
					   );
					 return unless $main::tidycommand;
					 $main::tidycommand = &main::&main::os_normal($main::tidycommand);
					 &main::savesettings();
				   }
			  ],
			  [
				 Button   => 'Locate W3C Validate (onsgmls) Executable',
				 -command => sub {
					 my $types;
					 if ($main::OS_WIN) {
						 $types = [
									[ 'Executable', [ '.exe', ] ],
									[ 'All Files',  ['*'] ],
						 ];
					 } else {
						 $types = [ [ 'All Files', ['*'] ] ];
					 }
					 $main::validatecommand =
					   $textwindow->getOpenFile(
						 -filetypes  => $types,
						 -initialdir => &main::dirname($main::validatecommand),
						 -title =>
'Where is the W3C Validate (onsgmls) executable (must be in tools\W3C)?'
					   );
					 return unless $main::validatecommand;
					 $main::validatecommand = &main::os_normal($main::validatecommand);
					 &main::savesettings();
				   }
			  ],
			  [
				 Button =>
				   'Locate W3C CSS Validator (css-validator.jar) Executable',
				 -command => sub {
					 my $types;
					 if ($main::OS_WIN) {
						 $types = [
									[ 'Executable', [ '.jar', ] ],
									[ 'All Files',  ['*'] ],
						 ];
					 } else {
						 $types = [ [ 'All Files', ['*'] ] ];
					 }
					 $main::validatecsscommand =
					   $textwindow->getOpenFile(
						 -filetypes  => $types,
						 -initialdir => &main::dirname($main::validatecsscommand),
						 -title =>
'Where is the W3C CSS Validator (css-validator.jar) executable?'
					   );
					 return unless $main::validatecsscommand;
					 $main::validatecsscommand = &main::os_normal($main::validatecsscommand);
					 &main::savesettings();
				   }
			  ],
			  [
				 Button   => 'Locate Gnutenberg Press (if self-installed)',
				 -command => sub {
					 my $types;
					 $types =
					   [ [ 'Perl file', [ '.pl', ] ], [ 'All Files', ['*'] ], ];
					 $main::gnutenbergdirectory =
					   $textwindow->getOpenFile(
							   -filetypes  => $types,
							   -initialdir => $main::gnutenbergdirectory,
							   -title =>
								 'Where is the Gnutenberg Press (transform.pl)?'
					   );
					 return unless $main::gnutenbergdirectory;
					 $main::gnutenbergdirectory = &main::os_normal($main::gnutenbergdirectory);
					 $main::gnutenbergdirectory = &main::dirname($main::gnutenbergdirectory);
					 &main::savesettings();
				   }
			  ],
			  [ 'separator', '' ],
			  [
				 Button   => 'Set Images Directory',
				 -command => \&main::setpngspath
			  ],
			]
	   ],
	   [
		  Cascade  => 'Appearance',
		  -tearoff => 0,
		  -menuitems =>
			[  # FIXME: sub this and generalize for all occurences in menu code.
			  [ Button => '~Font...', -command => \&fontsize ],
			  [
				 Checkbutton => 'Keep Pop-ups On Top',
				 -variable   => \$main::stayontop,
				 -onvalue    => 1,
				 -offvalue   => 0
			  ],
			  [
				 Checkbutton => 'Keep Word Frequency Pop-up On Top',
				 -variable   => \$main::wfstayontop,
				 -onvalue    => 1,
				 -offvalue   => 0
			  ],
			  [
				 Checkbutton => 'Enable Bell',
				 -variable   => \$main::nobell,
				 -onvalue    => 0,
				 -offvalue   => 1
			  ],
			  [
				 Button   => 'Set Background Color...',
				 -command => sub {
					 my $thiscolor = &main::setcolor($main::bkgcolor);
					 $main::bkgcolor = $thiscolor if $thiscolor;
					 &main::savesettings();
				   }
			  ],
			  [
				 Button   => 'Set Button Highlight Color...',
				 -command => sub {
					 my $thiscolor = &main::setcolor($main::activecolor);
					 $main::activecolor = $thiscolor if $thiscolor;
					 $main::OS_WIN
					   ? $main::lglobal{checkcolor} = 'white'
					   : $main::lglobal{checkcolor} = $main::activecolor;
					 &main::savesettings();
				   }
			  ],
			  [
				 Button   => 'Set Scanno Highlight Color...',
				 -command => sub {
					 my $thiscolor = setcolor($main::highlightcolor);
					 $main::highlightcolor = $thiscolor if $thiscolor;
					 $textwindow->tagConfigure( 'scannos',
											   -background => $main::highlightcolor );
					 &main::savesettings();
				   }
			  ],
			  [
				 Checkbutton => 'Auto Show Page Images',
				 -variable   => \$main::auto_show_images,
				 -onvalue    => 1,
				 -offvalue   => 0
			  ],
			  [ 'separator', '' ],
			  [
				 Checkbutton => 'Enable Quotes Highlighting',
				 -variable   => \$main::nohighlights,
				 -onvalue    => 1,
				 -offvalue   => 0
			  ],
			  [
				 Checkbutton => 'Enable Scanno Highlighting',
				 -variable   => \$main::scannos_highlighted,
				 -onvalue    => 1,
				 -offvalue   => 0,
				 -command    => \&highlight_scannos
			  ],
			  [
				 Checkbutton => 'Leave Bookmarks Highlighted',
				 -variable   => \$main::bkmkhl,
				 -onvalue    => 1,
				 -offvalue   => 0
			  ],
			]
	   ],
	   [
		  Cascade  => 'Menu structure',
		  -tearoff => 0,
		  -menuitems =>
			[  # FIXME: sub this and generalize for all occurences in menu code.
				[
					Checkbutton => 'New menus',
				  -variable   => \$main::useppwizardmenus,
				  -onvalue    => 1,
				  -offvalue   => 0,
				  -command    => \&main::menurebuild

			   ],
				[
				  Checkbutton => 'New menu v2 - requires New menus to be ticked',
				  -variable   => \$main::usemenutwo,
				  -onvalue    => 1,
				  -offvalue   => 0,
				  -command    => \&main::menurebuild

			   ],
			]
	   ],
	   [
		 Cascade    => 'Toolbar',
		 -tearoff   => 1,
		 -menuitems => [
			 [
				Checkbutton => 'Enable Toolbar',
				-variable   => \$main::notoolbar,
				-command    => [ \&main::toolbar_toggle ],
				-onvalue    => 0,
				-offvalue   => 1
			 ],
			 [
				Radiobutton => 'Toolbar on Top',
				-variable   => \$main::toolside,
				-command    => sub {
					$main::lglobal{toptool}->destroy
					  if $main::lglobal{toptool};
					undef $main::lglobal{toptool};
					&main::toolbar_toggle();
				},
				-value => 'top'
			 ],
			 [
				Radiobutton => 'Toolbar on Bottom',
				-variable   => \$main::toolside,
				-command    => sub {
					$main::lglobal{toptool}->destroy
					  if $main::lglobal{toptool};
					undef $main::lglobal{toptool};
					&main::toolbar_toggle();
				},
				-value => 'bottom'
			 ],
			 [
				Radiobutton => 'Toolbar on Left',
				-variable   => \$main::toolside,
				-command    => sub {
					$main::lglobal{toptool}->destroy
					  if $main::lglobal{toptool};
					undef $main::lglobal{toptool};
					&main::toolbar_toggle();
				},
				-value => 'left'
			 ],
			 [
				Radiobutton => 'Toolbar on Right',
				-variable   => \$main::toolside,
				-command    => sub {
					$main::lglobal{toptool}->destroy
					  if $main::lglobal{toptool};
					undef $main::lglobal{toptool};
					&main::toolbar_toggle();
				},
				-value => 'right'
			 ],
	   ],
		],
	   [
		  Cascade  => 'Backup',
		  -tearoff => 0,
		  -menuitems =>
			[  # FIXME: sub this and generalize for all occurences in menu code.
			  [
				 Checkbutton => 'Enable Auto Save',
				 -variable   => \$main::autosave,
				 -command    => sub {
					 &main::toggle_autosave();
					 &main::savesettings();
				   }
			  ],
			  [
				 Button   => 'Auto Save Interval...',
				 -command => sub {
					 &main::saveinterval();
					 &main::savesettings();
					 &main::set_autosave() if $main::autosave;
				   }
			  ],
			  [
				 Checkbutton => 'Enable Auto Backups',
				 -variable   => \$main::autobackup,
				 -onvalue    => 1,
				 -offvalue   => 0
			  ]
			]
	   ],
	   [
		  Cascade  => 'Processing',
		  -tearoff => 0,
		  -menuitems =>
			[  # FIXME: sub this and generalize for all occurences in menu code.
			  [
				 Checkbutton => 'Auto Set Page Markers On File Open',
				 -variable   => \$main::auto_page_marks,
				 -onvalue    => 1,
				 -offvalue   => 0
			  ],
			  [
				 Checkbutton => 'Do W3C Validation Remotely',
				 -variable   => \$main::w3cremote,
				 -onvalue    => 1,
				 -offvalue   => 0
			  ],
			  [
				 Checkbutton =>
				   'Leave Space After End-Of-Line Hyphens During Rewrap',
				 -variable => \$main::rwhyphenspace,
				 -onvalue  => 1,
				 -offvalue => 0
			  ],
			  [
				 Checkbutton => 'Filter Word Freqs Intelligently',
				 -variable   => \$main::intelligentWF,
				 -onvalue    => 1,
				 -offvalue   => 0
			  ],
			  [
				 Checkbutton => 'Return After Failed Search',
				 -variable   => \$main::failedsearch,
				 -onvalue    => 1,
				 -offvalue   => 0
			  ],
			  [ 'separator', '' ],
			  [
				 Button   => 'Spellcheck Dictionary Select...',
				 -command => sub { &main::spelloptions() }
			  ],
			  [
				 Button   => 'Search History Size...',
				 -command => sub {
					 &main::searchsize();
					 &main::savesettings();
				   }
			  ],
			  [ Button => 'Set Rewrap ~Margins...', -command => \&main::setmargins ],
			  [ 'separator', '' ],
			  [
				 Button   => 'Browser Start Command...',
				 -command => \&main::setbrowser
			  ],
			]
	   ]
	]

}

sub menu_bookmarks {
	[
	   map ( [
				Button       => "Set Bookmark $_",
				-command     => [ \&main::setbookmark, "$_" ],
				-accelerator => "Ctrl+Shift+$_"
			 ],
			 ( 1 .. 5 ) ),
	   [ 'separator', '' ],
	   map ( [
				Button       => "Go To Bookmark $_",
				-command     => [ \&main::gotobookmark, "$_" ],
				-accelerator => "Ctrl+$_"
			 ],
			 ( 1 .. 5 ) ),
	];
}

sub menu_external {
	[
	   [
		  Button   => 'Setup External Operations...',
		  -command => \&main::externalpopup
	   ],
	   [ 'separator', '' ],
	   map ( [
				Button   => "~$_ $main::extops[$_]{label}",
				-command => [ \&main::xtops, $_ ]
			 ],
			 ( 0 .. 9 ) ),
	];
}

sub menubuildold {
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	my $file = $main::menubar->cascade(
		-label     => '~File',
		-tearoff   => 1,
		-menuitems => [
			 [ 'command',   '~Open', -command => sub {&main::file_open($textwindow)} ],
			 [ 'separator', '' ],
			 map ( [
					 Button   => "$main::recentfile[$_]",
					 -command => [ \&main::openfile, $main::recentfile[$_] ]
				   ],
				   ( 0 .. scalar(@main::recentfile) - 1 ) ),
			 [ 'separator', '' ],
			 [
			   'command',
			   '~Save',
			   -accelerator => 'Ctrl+s',
			   -command     => \&main::savefile
			 ],
			 [ 'command', 'Save ~As', -command => sub{&main::file_saveas($textwindow)} ],
			 [
			   'command',
			   '~Include File',
			   -command => sub { &main::file_include($textwindow) }
			 ],
			 [ 'command',   '~Close', -command => sub {&main::file_close($textwindow)} ],
			 [ 'separator', '' ],
			 [ 'command', 'Import Prep Text Files', -command => sub{&main::file_import($textwindow,$top)} ],
			 [
			   'command',
			   'Export As Prep Text Files',
			   -command => sub{&main::file_export($textwindow,$top)}
			 ],
			 [ 'separator', '' ],
			 [
			   'command',
			   '~Guess Page Markers...',
			   -command => \&main::file_guess_page_marks
			 ],
			 [ 'command', 'Set Page ~Markers...', -command => \&main::file_mark_pages ],
			 [ 'command', '~Adjust Page Markers', -command => \&main::viewpagenums ],
			 [ 'separator', '' ],
			 [ 'command', 'E~xit', -command => \&main::_exit ],
		  ]

	);

	my $edit = $main::menubar->cascade(
		-label     => '~Edit',
		-tearoff   => 1,
		-menuitems => [
			[
			   'command', 'Undo',
			   -command     => sub { $textwindow->undo },
			   -accelerator => 'Ctrl+z'
			],

			[
			   'command', 'Redo',
			   -command     => sub { $textwindow->redo },
			   -accelerator => 'Ctrl+y'
			],
			[ 'separator', '' ],

			[
			   'command', 'Cut',
			   -command     => sub { &main::cut() },
			   -accelerator => 'Ctrl+x'
			],

			[ 'separator', '' ],
			[
			   'command', 'Copy',
			   -command     => sub { &main::textcopy() },
			   -accelerator => 'Ctrl+c'
			],
			[
			   'command', 'Paste',
			   -command     => sub { &main::paste() },
			   -accelerator => 'Ctrl+v'
			],
			[
			   'command',
			   'Col Paste',
			   -command => sub {    # FIXME: sub edit_column_paste
				   $textwindow->addGlobStart;
				   $textwindow->clipboardColumnPaste;
				   $textwindow->addGlobEnd;
			   },
			   -accelerator => 'Ctrl+`'
			],
			[ 'separator', '' ],
			[
			   'command',
			   'Select All',
			   -command => sub {
				   $textwindow->selectAll;
			   },
			   -accelerator => 'Ctrl+/'
			],
			[
			   'command',
			   'Unselect All',
			   -command => sub {
				   $textwindow->unselectAll;
			   },
			   -accelerator => 'Ctrl+\\'
			],
		  ]

	);
	my $search = $main::menubar->cascade(
		-label     => 'Search & ~Replace',
		-tearoff   => 1,
		-menuitems => [
			[ 'command', 'Search & ~Replace...', -command => \&main::searchpopup ],
			[ 'command', '~Stealth Scannos...',  -command => \&main::stealthscanno ],
			[ 'command', 'Spell ~Check...',      -command => \&main::spellchecker ],
			[
			   'command',
			   'Goto ~Line...',
			   -command => sub {
				   &main::gotoline();
				   &main::update_indicators();
				 }
			],
			[
			   'command',
			   'Goto ~Page...',
			   -command => sub {
				   &main::gotopage();
				   &main::update_indicators();
				 }
			],
			[
			   'command', '~Which Line?',
			   -command => sub { $textwindow->WhatLineNumberPopUp }
			],
			[ 'separator', '' ],
			[
			   'command',
			   'Find next /*..*/ block',
			   -command => [ \&main::nextblock, 'default', 'forward' ]
			],
			[
			   'command',
			   'Find previous /*..*/ block',
			   -command => [ \&main::nextblock, 'default', 'reverse' ]
			],
			[
			   'command',
			   'Find next /#..#/ block',
			   -command => [ \&main::nextblock, 'block', 'forward' ]
			],
			[
			   'command',
			   'Find previous /#..#/ block',
			   -command => [ \&main::nextblock, 'block', 'reverse' ]
			],
			[
			   'command',
			   'Find next /$..$/ block',
			   -command => [ \&main::nextblock, 'stet', 'forward' ]
			],
			[
			   'command',
			   'Find previous /$..$/ block',
			   -command => [ \&main::nextblock, 'stet', 'reverse' ]
			],
			[
			   'command',
			   'Find next /p..p/ block',
			   -command => [ \&main::nextblock, 'poetry', 'forward' ]
			],
			[
			   'command',
			   'Find previous /p..p/ block',
			   -command => [ \&main::nextblock, 'poetry', 'reverse' ]
			],
			[
			   'command',
			   'Find next indented block',
			   -command => [ \&main::nextblock, 'indent', 'forward' ]
			],
			[
			   'command',
			   'Find previous indented block',
			   -command => [ \&main::nextblock, 'indent', 'reverse' ]
			],
			[ 'separator', '' ],
			[
			   'command',
			   'Find ~Orphaned Brackets...',
			   -command => \&main::orphanedbrackets
			],
			[ 'command', 'Find Orphaned Markup...', -command => \&main::orphanedmarkup ],
			[
			   'command',
			   'Find Proofer Comments',
			   -command => \&main::find_proofer_comment
			],
			[
			   'command',
			   'Find Asterisks w/o slash',
			   -command => \&main::find_asterisks
			],
			[
			   'command',
			   'Find Transliterations...',
			   -command => \&main::find_transliterations
			],
			[ 'separator', '' ],
			[
			   'command', 'Highlight double quotes in selection',
			   -command     => [ \&main::hilite, '"' ],
			   -accelerator => 'Ctrl+Shift+"'
			],
			[
			   'command', 'Highlight single quotes in selection',
			   -command     => [ \&main::hilite, '\'' ],
			   -accelerator => 'Ctrl+\''
			],
			[
			   'command', 'Highlight arbitrary characters in selection...',
			   -command     => \&main::hilitepopup,
			   -accelerator => 'Ctrl+Alt+h'
			],
			[
			   'command',
			   'Remove Highlights',
			   -command => sub {    # FIXME: sub search_rm_hilites
				   $textwindow->tagRemove( 'highlight', '1.0', 'end' );
				   $textwindow->tagRemove( 'quotemark', '1.0', 'end' );
			   },
			   -accelerator => 'Ctrl+0'
			],
		]
	);

	my $bookmarks = $main::menubar->cascade(
									   -label     => '~Bookmarks',
									   -tearoff   => 1,
									   -menuitems => &main::menu_bookmarks,
	);

	my $selection = $main::menubar->cascade(
		-label     => '~Selection',
		-tearoff   => 1,
		-menuitems => [
			[
			   Button   => '~lowercase Selection',
			   -command => sub {
				   &main::case ( $textwindow, 'lc' );
				 }
			],
			[
			   Button   => '~Sentence case Selection',
			   -command => sub { &main::case ( $textwindow, 'sc' ); }
			],
			[
			   Button   => '~Title Case Selection',
			   -command => sub { &main::case ( $textwindow, 'tc' ); }
			],
			[
			   Button   => '~UPPERCASE Selection',
			   -command => sub { &main::case ( $textwindow, 'uc' ); }
			],
			[ 'separator', '' ],
			[
			   Button   => 'Surround Selection With...',
			   -command => sub {
				   if ( defined( $main::lglobal{surpop} ) ) {
					   $main::lglobal{surpop}->deiconify;
					   $main::lglobal{surpop}->raise;
					   $main::lglobal{surpop}->focus;
				   } else {
					   $main::lglobal{surpop} = $top->Toplevel;
					   $main::lglobal{surpop}->title('Surround text with:');

					   my $f =
						 $main::lglobal{surpop}
						 ->Frame->pack( -side => 'top', -anchor => 'n' );
					   $f->Label( -text =>
"Surround the selection with?\n\\n will be replaced with a newline.",
						 )->pack(
								  -side   => 'top',
								  -pady   => 5,
								  -padx   => 2,
								  -anchor => 'n'
						 );
					   my $f1 =
						 $main::lglobal{surpop}
						 ->Frame->pack( -side => 'top', -anchor => 'n' );
					   my $surstrt =
						 $f1->Entry(
									 -width      => 8,
									 -background => $main::bkgcolor,
									 -font       => $main::lglobal{font},
									 -relief     => 'sunken',
						 )->pack(
								  -side   => 'left',
								  -pady   => 5,
								  -padx   => 2,
								  -anchor => 'n'
						 );
					   my $surend =
						 $f1->Entry(
									 -width      => 8,
									 -background => $main::bkgcolor,
									 -font       => $main::lglobal{font},
									 -relief     => 'sunken',
						 )->pack(
								  -side   => 'left',
								  -pady   => 5,
								  -padx   => 2,
								  -anchor => 'n'
						 );
					   my $f2 =
						 $main::lglobal{surpop}
						 ->Frame->pack( -side => 'top', -anchor => 'n' );
					   my $gobut = $f2->Button(
						   -activebackground => $main::activecolor,
						   -command          => sub {
							   &main::surroundit( $surstrt->get, $surend->get,
										   $textwindow );
						   },
						   -text  => 'OK',
						   -width => 16
						 )->pack(
								  -side   => 'top',
								  -pady   => 5,
								  -padx   => 2,
								  -anchor => 'n'
						 );
					   $main::lglobal{surpop}->protocol(
						   'WM_DELETE_WINDOW' => sub {
							   $main::lglobal{surpop}->destroy;
							   undef $main::lglobal{surpop};
						   }
					   );
					   $surstrt->insert( 'end', '_' ) unless ( $surstrt->get );
					   $surend->insert( 'end', '_' ) unless ( $surend->get );
					   $main::lglobal{surpop}->Icon( -image => $main::icon );
				   }
				 }
			],
			[
			   Button   => 'Flood Fill Selection With...',
			   -command => sub {
				   $textwindow->addGlobStart;
				   $main::lglobal{floodpop} =
					 &main::flood( $textwindow, $top, $main::lglobal{floodpop},
							$main::lglobal{font}, $main::activecolor, $main::icon );
				   $textwindow->addGlobEnd;
				 }
			],
			[ 'separator', '' ],
			[
			   Button   => 'Indent Selection 1',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::indent( $textwindow, 'in' );
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Indent Selection -1',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::indent( $textwindow, 'out', $main::operationinterrupt );
				   $textwindow->addGlobEnd;
				 }
			],
			[ 'separator', '' ],
			[
			   Button   => '~Rewrap Selection',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::selectrewrap( $textwindow, $main::lglobal{seepagenums},
								 $main::scannos_highlighted, $main::rwhyphenspace );
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => '~Block Rewrap Selection',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::blockrewrap();
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Interrupt Rewrap',
			   -command => sub { $main::operationinterrupt = 1 }
			],
			[ 'separator', '' ],
			[ Button => 'ASCII ~Boxes...',          -command => \&main::asciipopup ],
			[ Button => '~Align text on string...', -command => \&main::alignpopup ],
			[ 'separator', '' ],
			[
			   Button   => 'Convert To Named/Numeric Entities',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::tonamed($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Convert From Named/Numeric Entities',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::fromnamed($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Convert Fractions',
			   -command => sub {
				   my @ranges = $textwindow->tagRanges('sel');
				   $textwindow->addGlobStart;
				   if (@ranges) {
					   while (@ranges) {
						   my $end   = pop @ranges;
						   my $start = pop @ranges;
						   &main::fracconv( $textwindow, $start, $end );
					   }
				   } else {
					   &main::fracconv( $textwindow, '1.0', 'end' );
				   }
				   $textwindow->addGlobEnd;
				 }
			],
		  ]

	);

	my $fixup = $main::menubar->cascade(
		-label     => 'Fi~xup',
		-tearoff   => 1,
		-menuitems => [
			[
			   Button   => 'Run ~Word Frequency Routine...',
			   -command => sub{&main::wordfrequency($textwindow, $top)}
			],
			[ 'separator', '' ],
			[ Button => 'Run ~Gutcheck...',    -command => \&main::gutcheck ],
			[ Button => 'Gutcheck options...', -command => \&main::gutopts ],
			[ Button => 'Run ~Jeebies...',     -command => \&main::jeebiespop_up ],
			[
			   Button   => 'pptxt...',
			   -command => sub {
				   &main::errorcheckpop_up($textwindow,$top,'pptxt');
				   unlink 'null' if ( -e 'null' );
			   },
			],
			[ 'separator', '' ],
			[
			   Button   => 'Remove End-of-line Spaces',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::endofline();
				   $textwindow->addGlobEnd;
				 }
			],
			[ Button => 'Run Fi~xup...', -command => \&main::fixpopup ],
			[ 'separator', '' ],
			[ Button => 'Fix ~Page Separators...', -command => \&main::separatorpopup ],
			[
			   Button   => 'Remove Blank Lines Before Page Separators',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::delblanklines();
				   $textwindow->addGlobEnd;
				 }
			],
			[ 'separator', '' ],
			[ Button => '~Footnote Fixup...', -command => \&main::footnotepop ],
			[ Button => '~HTML Fixup...',     -command => sub{&main::htmlpopup($textwindow,$top)} ],
			[ Button => '~Sidenote Fixup...', -command => \&main::sidenotes ],
			[
			   Button   => 'Reformat Poetry ~Line Numbers',
			   -command => \&main::poetrynumbers
			],
			[
			   Button   => 'Convert Windows CP 1252 characters to Unicode',
			   -command => \&main::cp1252toUni
			],
			[ Button => 'HTML Auto ~Index (List)', -command => sub{&main::autoindex($textwindow)} ],
			[
			   Cascade    => 'PGTEI Tools',
			   -tearoff   => 0,
			   -menuitems => [
				   [
					  Button   => 'W3C Validate PGTEI',
					  -command => sub {
						  &main::errorcheckpop_up($textwindow,$top,'W3C Validate');
						}
				   ],
				   [
					  Button   => 'Gnutenberg Press (HTML only)',
					  -command => sub { &main::gnutenberg('html') }
				   ],
				   [
					  Button   => 'Gnutenberg Press (Text only)',
					  -command => sub { &main::gnutenberg('txt') }
				   ],
				   [
					  Button   => 'Gnutenberg Press Online',
					  -command => sub {
						  &main::runner(
$main::globalbrowserstart, "http://pgtei.pglaf.org/marcello/0.4/tei-online" );
						}
				   ],
			   ]
			],
			[
			   Cascade    => 'RST Tools',
			   -tearoff   => 0,
			   -menuitems => [
				   [
					  Button   => 'EpubMaker Online',
					  -command => sub {
						  runner(
							   $main::globalbrowserstart, "http://epubmaker.pglaf.org/"
						  );
						}
				   ],
				   [
					  Button   => 'EpubMaker (all formats)',
					  -command => sub { &main::epubmaker() }
				   ],
				   [
					  Button   => 'EpubMaker (HTML only)',
					  -command => sub { &main::epubmaker('html') }
				   ],
				   [
					  Button   => 'dp2rst Conversion',
					  -command => sub {
						  &main::runner(
$main::globalbrowserstart, "http://www.pgdp.net/wiki/Dp2rst" );
						}
				   ],
			   ]
			],

			[ 'separator', '' ],
			[ Button => 'ASCII Table Special Effects...', -command => \&main::tablefx ],
			[ 'separator', '' ],
			[
			   Button   => 'Clean Up Rewrap ~Markers',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::cleanup();
				   $textwindow->addGlobEnd;
				 }
			],
			[ 'separator', '' ],
			[ Button => 'Find Greek...', -command => \&main::findandextractgreek ]
		]
	);

	my $text = $main::menubar->cascade(
		-label     => 'Text Processing',
		-tearoff   => 1,
		-menuitems => [
			[
			   Button   => "Convert Italics",
			   -command => sub {
				   &main::text_convert_italic( $textwindow, $main::italic_char );
				 }
			],
			[
			   Button   => "Convert Bold",
			   -command => sub { &main::text_convert_bold( $textwindow, $main::bold_char ) }
			],
			[
			   Button   => 'Convert <tb> to asterisk break',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::text_convert_tb($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'All of the above',
			   -command => sub {
				   &main::text_convert_italic( $textwindow, $main::italic_char );
				   &main::text_convert_bold( $textwindow, $main::bold_char );
				   $textwindow->addGlobStart;
				   &main::text_convert_tb($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => '~Add a Thought Break',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::text_thought_break($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Small caps to all caps',
			   -command => \&main::text_convert_smallcaps
			],
			[
			   Button   => 'Remove small caps markup',
			   -command => \&main::text_remove_smallcaps_markup
			],
			[ Button => "Options...", -command => sub{&main::text_convert_options($top)} ],
		  ]

	);

	my $external = $main::menubar->cascade(
									  -label     => 'External',
									  -tearoff   => 1,
									  -menuitems => &main::menu_external,
	);
	
	&main::unicodemenu();


	$main::menubar->Cascade(
					   -label     => '~Preferences',
					   -tearoff   => 1,
					   -menuitems => menu_preferences
	);

	$main::menubar->Cascade(
		-label     => '~Help',
		-tearoff   => 1,
		-menuitems => [
			[ Button => '~About',    -command => sub{&main::about_pop_up($top)} ],
			[ Button => '~Versions', -command => [ \&main::showversion, $top ] ],
			[
			   Button   => '~Manual',
			   -command => sub {        # FIXME: sub this out.
				   &main::runner(
$main::globalbrowserstart, "http://www.pgdp.net/wiki/PPTools/Guiguts"
				   );
				 }
			],


			# FIXME: Disable update check until it works
			[
			   Button   => 'Check For ~Updates',
			   -command => sub { &main::checkforupdates(0) }
			],
			[ Button => '~Hot keys',              -command => \&main::hotkeyshelp ],
			[ Button => '~Function History',      -command => \&main::opspop_up ],
			[ Button => '~Greek Transliteration', -command => \&main::greekpopup ],
			[ Button => '~Latin 1 Chart',         -command => \&main::latinpopup ],
			[ Button => '~Regex Quick Reference', -command => \&main::regexref ],
			[ Button => '~UTF Character entry',   -command => \&main::utford ],
			[ Button => '~UTF Character Search',  -command => \&main::uchar ],
		]
	);
}

sub menubuild {
	my $menubar = $main::menubar;
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	unless ($main::useppwizardmenus) {
		&main::menubuildold();
		return;
	}
	if ($main::usemenutwo) {
		menubuildtwo();
		return;
	}
	my $file = $menubar->cascade(
		-label     => '~File',
		-tearoff   => 1,
		-menuitems => [
			 [ 'command',   '~Open', -command => sub {&main::file_open($textwindow)} ],
			 [ 'separator', '' ],
			 map ( [
					 Button   => "$main::recentfile[$_]",
					 -command => [ \&main::openfile, $main::recentfile[$_] ]
				   ],
				   ( 0 .. scalar(@main::recentfile) - 1 ) ),
			 [ 'separator', '' ],
			 [
			   'command',
			   '~Save',
			   -accelerator => 'Ctrl+s',
			   -command     => \&main::savefile
			 ],
			 [ 'command', 'Save ~As', -command => sub{&main::file_saveas($textwindow)} ],
			 [
			   'command',
			   '~Include File',
			   -command => sub { &main::file_include($textwindow) }
			 ],
			 [ 'command', 'Import Prep Text Files', -command => sub{&main::file_import($textwindow,$top)}],
			 [
			   'command',
			   'Export As Prep Text Files',
			   -command => sub{&main::file_export($textwindow,$top)}
			 ],
			 [ 'separator', '' ],
			 [ 'command', '~Close', -command => sub {&main::file_close($textwindow)} ],
			 [ 'command', 'E~xit',  -command => \&main::_exit ],
		  ]

	);

	my $edit = $menubar->cascade(
		-label     => '~Edit',
		-tearoff   => 1,
		-menuitems => [
			[ 'command', 'Search & ~Replace...', -command => \&main::searchpopup ],
			[
			   'command', 'Cut',
			   -command     => sub { &main::cut() },
			   -accelerator => 'Ctrl+x'
			],
			[
			   'command', 'Copy',
			   -command     => sub { &main::textcopy() },
			   -accelerator => 'Ctrl+c'
			],
			[
			   'command', 'Paste',
			   -command     => sub { &main::paste() },
			   -accelerator => 'Ctrl+v'
			],
			[
			   'command',
			   'Col Paste',
			   -command => sub {    # FIXME: sub edit_column_paste
				   $textwindow->addGlobStart;
				   $textwindow->clipboardColumnPaste;
				   $textwindow->addGlobEnd;
			   },
			   -accelerator => 'Ctrl+`'
			],
			[
			   'command',
			   'Undo',
			   -command => sub {
				   $textwindow->undo;
			   },
			   -accelerator => 'Ctrl+z'
			],

			[
			   'command', 'Redo',
			   -command     => sub { $textwindow->redo },
			   -accelerator => 'Ctrl+y'
			],
			[ 'separator', '' ],
			[
			   'command',
			   'Select All',
			   -command => sub {
				   $textwindow->selectAll;
			   },
			   -accelerator => 'Ctrl+/'
			],
			[
			   'command',
			   'Unselect All',
			   -command => sub {
				   $textwindow->unselectAll;
			   },
			   -accelerator => 'Ctrl+\\'
			],
			[
			   'command',
			   'Goto ~Line...',
			   -command => sub {
				   &main::gotoline();
				   &main::update_indicators();
				 }
			],
			[
			   'command',
			   'Goto ~Page...',
			   -command => sub {
				   &main::gotopage();
				   &main::update_indicators();
				 }
			],
			[
			   'command', '~Which Line?',
			   -command => sub { $textwindow->WhatLineNumberPopUp }
			],
		  ]

	);

	my $selection = $menubar->cascade(
		-label     => '~Tools',
		-tearoff   => 1,
		-menuitems => [
			[
			   Button   => '~lowercase Selection',
			   -command => sub {
				   &main::case ( $textwindow, 'lc' );
				 }
			],
			[
			   Button   => '~Sentence case Selection',
			   -command => sub { &main::case ( $textwindow, 'sc' ); }
			],
			[
			   Button   => '~Title Case Selection',
			   -command => sub { &main::case ( $textwindow, 'tc' ); }
			],
			[
			   Button   => '~UPPERCASE Selection',
			   -command => sub { &main::case ( $textwindow, 'uc' ); }
			],
			[ 'separator', '' ],
			[
			   Button   => 'Surround Selection With...',
			   -command => sub {
				   if ( defined( $main::lglobal{surpop} ) ) {
					   $main::lglobal{surpop}->deiconify;
					   $main::lglobal{surpop}->raise;
					   $main::lglobal{surpop}->focus;
				   } else {
					   $main::lglobal{surpop} = $top->Toplevel;
					   $main::lglobal{surpop}->title('Surround text with:');

					   my $f =
						 $main::lglobal{surpop}
						 ->Frame->pack( -side => 'top', -anchor => 'n' );
					   $f->Label( -text =>
"Surround the selection with?\n\\n will be replaced with a newline.",
						 )->pack(
								  -side   => 'top',
								  -pady   => 5,
								  -padx   => 2,
								  -anchor => 'n'
						 );
					   my $f1 =
						 $main::lglobal{surpop}
						 ->Frame->pack( -side => 'top', -anchor => 'n' );
					   my $surstrt =
						 $f1->Entry(
									 -width      => 8,
									 -background => $main::bkgcolor,
									 -font       => $main::lglobal{font},
									 -relief     => 'sunken',
						 )->pack(
								  -side   => 'left',
								  -pady   => 5,
								  -padx   => 2,
								  -anchor => 'n'
						 );
					   my $surend =
						 $f1->Entry(
									 -width      => 8,
									 -background => $main::bkgcolor,
									 -font       => $main::lglobal{font},
									 -relief     => 'sunken',
						 )->pack(
								  -side   => 'left',
								  -pady   => 5,
								  -padx   => 2,
								  -anchor => 'n'
						 );
					   my $f2 =
						 $main::lglobal{surpop}
						 ->Frame->pack( -side => 'top', -anchor => 'n' );
					   my $gobut = $f2->Button(
						   -activebackground => $main::activecolor,
						   -command          => sub {
							   &main::surroundit( $surstrt->get, $surend->get,
										   $textwindow );
						   },
						   -text  => 'OK',
						   -width => 16
						 )->pack(
								  -side   => 'top',
								  -pady   => 5,
								  -padx   => 2,
								  -anchor => 'n'
						 );
					   $main::lglobal{surpop}->protocol(
						   'WM_DELETE_WINDOW' => sub {
							   $main::lglobal{surpop}->destroy;
							   undef $main::lglobal{surpop};
						   }
					   );
					   $surstrt->insert( 'end', '_' ) unless ( $surstrt->get );
					   $surend->insert( 'end', '_' ) unless ( $surend->get );
					   $main::lglobal{surpop}->Icon( -image => $main::icon );
				   }
				 }
			],
			[
			   Button   => 'Flood Fill Selection With...',
			   -command => sub {
				   $textwindow->addGlobStart;
				   $main::lglobal{floodpop} =
					 &main::flood( $textwindow, $top, $main::lglobal{floodpop},
							$main::lglobal{font}, $main::activecolor, $main::icon );
				   $textwindow->addGlobEnd;
				 }
			],
			[ 'separator', '' ],
			[
			   Button   => 'Indent Selection 1',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::indent( $textwindow, 'in' );
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Indent Selection -1',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::indent( $textwindow, 'out', $main::operationinterrupt );
				   $textwindow->addGlobEnd;
				 }
			],
			[ 'separator', '' ],
			[ Button => '~Align text on string...', -command => \&main::alignpopup ],
			[ 'separator', '' ],
			[
			   Button   => 'Convert To Named/Numeric Entities',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::tonamed($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Convert From Named/Numeric Entities',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::fromnamed($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Convert Fractions',
			   -command => sub {
				   my @ranges = $textwindow->tagRanges('sel');
				   $textwindow->addGlobStart;
				   if (@ranges) {
					   while (@ranges) {
						   my $end   = pop @ranges;
						   my $start = pop @ranges;
						   &main::fracconv( $textwindow, $start, $end );
					   }
				   } else {
					   &main::fracconv( $textwindow, '1.0', 'end' );
				   }
				   $textwindow->addGlobEnd;
				 }
			],
			[ 'separator', '' ],
			[
			   'command', 'Highlight double quotes in selection',
			   -command     => [ \&main::hilite, '"' ],
			   -accelerator => 'Ctrl+Shift+"'
			],
			[
			   'command', 'Highlight single quotes in selection',
			   -command     => [ \&main::hilite, '\'' ],
			   -accelerator => 'Ctrl+\''
			],
			[
			   'command', 'Highlight arbitrary characters in selection...',
			   -command     => \&main::hilitepopup,
			   -accelerator => 'Ctrl+Alt+h'
			],
			[
			   'command',
			   'Remove Highlights',
			   -command => sub {    # FIXME: sub search_rm_hilites
				   $textwindow->tagRemove( 'highlight', '1.0', 'end' );
				   $textwindow->tagRemove( 'quotemark', '1.0', 'end' );
			   },
			   -accelerator => 'Ctrl+0'
			],
			[
			   Cascade    => 'Bookmarks',
			   -tearoff   => 0,
			   -menuitems => &main::menu_bookmarks
			],
			[
			   Cascade    => 'External',
			   -tearoff   => 0,
			   -menuitems => &main::menu_external
			],
			[
			   Cascade    => 'Page Markers',
			   -tearoff   => 0,
			   -menuitems => [
				   [
					  'command',
					  '~Guess Page Markers...',
					  -command => \&main::file_guess_page_marks
				   ],
				   [
					  'command',
					  'Set Page ~Markers...',
					  -command => \&main::file_mark_pages
				   ],
				   [
					  'command',
					  '~Adjust Page Markers',
					  -command => \&main::viewpagenums
				   ],
				 ]
			],
			[ Button => '~Greek Transliteration', -command => \&main::greekpopup ],
			[ Button => '~UTF Character entry',   -command => \&main::utford ],
			[ Button => '~UTF Character Search',  -command => \&main::uchar ],
			
			
		  ]
	);

	my $source = $menubar->cascade(
		-label     => '~Source Cleanup',
		-tearoff   => 1,
		-menuitems => [
			[
			   'command',
			   'View Project Comments',
			   -command => sub {
				   my $defaulthandler = $main::extops[0]{command};
				   $defaulthandler =~ s/\$f\$e/project_comments.html/;
				   &main::runner( &main::cmdinterp($defaulthandler) );
				 }
			],
			[
			   'command',
			   'View Project Discussion',
			   -command => sub {
				   return if &main::nofileloadedwarning();
				   &main::runner(
$main::globalbrowserstart, "http://www.pgdp.net/c/tools/proofers/project_topic.php?project=$main::projectid"
				   ) if $main::projectid;
				 }
			],
			[ 'separator', '' ],
			[
			   'command',
			   'Find next /*..*/ block',
			   -command => [ \&main::nextblock, 'default', 'forward' ]
			],
			[
			   'command',
			   'Find previous /*..*/ block',
			   -command => [ \&main::nextblock, 'default', 'reverse' ]
			],
			[
			   'command',
			   'Find next /#..#/ block',
			   -command => [ \&main::nextblock, 'block', 'forward' ]
			],
			[
			   'command',
			   'Find previous /#..#/ block',
			   -command => [ \&main::nextblock, 'block', 'reverse' ]
			],
			[
			   'command',
			   'Find next /$..$/ block',
			   -command => [ \&main::nextblock, 'stet', 'forward' ]
			],
			[
			   'command',
			   'Find previous /$..$/ block',
			   -command => [ \&main::nextblock, 'stet', 'reverse' ]
			],
			[
			   'command',
			   'Find next /p..p/ block',
			   -command => [ \&main::nextblock, 'poetry', 'forward' ]
			],
			[
			   'command',
			   'Find previous /p..p/ block',
			   -command => [ \&main::nextblock, 'poetry', 'reverse' ]
			],
			[
			   'command',
			   'Find next indented block',
			   -command => [ \&main::nextblock, 'indent', 'forward' ]
			],
			[
			   'command',
			   'Find previous indented block',
			   -command => [ \&main::nextblock, 'indent', 'reverse' ]
			],
			[ 'separator', '' ],
			[
			   'command',
			   'Find ~Orphaned Brackets...',
			   -command => \&main::orphanedbrackets
			],
			[ 'command', 'Find Orphaned Markup...', -command => \&main::orphanedmarkup ],
			[
			   'command',
			   'Find Proofer Comments',
			   -command => \&main::find_proofer_comment
			],
			[
			   'command',
			   'Find Asterisks w/o slash',
			   -command => \&main::find_asterisks
			],
			[
			   'command',
			   'Find Transliterations...',
			   -command => \&main::find_transliterations
			],
			[ 'separator', '' ],
			[
			   Button   => 'Remove End-of-line Spaces',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::endofline();
				   $textwindow->addGlobEnd;
				 }
			],
			[ Button => 'Run Fi~xup...', -command => \&main::fixpopup ],
			[ Button => 'Find Greek...', -command => \&main::findandextractgreek ],
			[ Button => 'Fix ~Page Separators', -command => \&main::separatorpopup ],
			[
			   Button   => 'Remove Blank Lines Before Page Separators',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::delblanklines();
				   $textwindow->addGlobEnd;
				 }
			],
			[ Button => '~Sidenote Fixup...', -command => \&main::sidenotes ],
			[ Button => '~Footnote Fixup...', -command => \&main::footnotepop ],
			[
			   Button   => 'Reformat Poetry ~Line Numbers',
			   -command => \&main::poetrynumbers
			],
		]
	);

	my $sourcechecks = $menubar->cascade(
		-label     => 'Source ~Checks',
		-tearoff   => 1,
		-menuitems => [

			[
			   Button   => 'Run ~Word Frequency Routine...',
			   -command => sub{&main::wordfrequency($textwindow,$top)}
			],
			[ 'command',   '~Stealth Scannos...', -command => \&main::stealthscanno ],
			[ 'separator', '' ],
			[ Button => 'Run ~Gutcheck...',    -command => \&main::gutcheck ],
			[ Button => 'Gutcheck options...', -command => \&main::gutopts ],
			[ Button => 'Run ~Jeebies...',     -command => \&main::jeebiespop_up ],
			[ 'command', 'Spell ~Check...', -command => \&main::spellchecker ],
			[
			   Button   => 'pptxt...',
			   -command => sub {
				   &main::errorcheckpop_up($textwindow,$top,'pptxt');
				   unlink 'null' if ( -e 'null' );
			   },
			],
		]
	);

	my $txtcleanup = $menubar->cascade(
		-label     => 'Te~xt Version(s)',
		-tearoff   => 1,
		-menuitems => [
			[
			   Button   => "Convert Italics",
			   -command => sub {
				   &main::text_convert_italic( $textwindow, $main::italic_char );
				 }
			],
			[
			   Button   => "Convert Bold",
			   -command => sub { &main::text_convert_bold( $textwindow, $main::bold_char ) }
			],
			[
			   Button   => 'Convert <tb> to asterisk break',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::text_convert_tb($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'All of the above',
			   -command => sub {
				   &main::text_convert_italic( $textwindow, $main::italic_char );
				   &main::text_convert_bold( $textwindow, $main::bold_char );
				   $textwindow->addGlobStart;
				   &main::text_convert_tb($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => '~Add a Thought Break',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::text_thought_break($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Small caps to all caps',
			   -command => \&main::text_convert_smallcaps
			],
			[
			   Button   => 'Remove small caps markup',
			   -command => \&main::text_remove_smallcaps_markup
			],
			[ Button => "Options...", -command => sub{&main::text_convert_options($top)} ],
			[ 'separator', '' ],
			[ Button => 'ASCII ~Boxes...', -command => \&main::asciipopup ],
			[ Button => 'ASCII Table Special Effects...', -command => \&main::tablefx ],
			[
			   Button   => '~Rewrap Selection',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::selectrewrap( $textwindow, $main::lglobal{seepagenums},
								 $main::scannos_highlighted, $main::rwhyphenspace );
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => '~Block Rewrap Selection',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::blockrewrap();
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Interrupt Rewrap',
			   -command => sub { $main::operationinterrupt = 1 }
			],
			[
			   Button   => 'Clean Up Rewrap ~Markers',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::cleanup();
				   $textwindow->addGlobEnd;
				 }
			],
			[ 'separator', '' ],
			[
			   Button   => 'Convert Windows CP 1252 characters to Unicode',
			   -command => \&main::cp1252toUni
			],
		]
	);

	my $htmlversion = $menubar->cascade(
		-label     => '~HTML Version',
		-tearoff   => 1,
		-menuitems => [
			[ Button => '~HTML Fixup',             -command => sub{&main::htmlpopup($textwindow,$top)} ],
			[ Button => 'HTML Auto ~Index (List)', -command => sub{&main::autoindex($textwindow)}],
			[
			   Cascade    => 'HTML to Epub',
			   -tearoff   => 0,
			   -menuitems => [
				   [
					  Button   => 'EpubMaker Online',
					  -command => sub {
						  &main::runner(
							   $main::globalbrowserstart, "http://epubmaker.pglaf.org/"
						  );
						}
				   ],
				   [
					  Button   => 'EpubMaker',
					  -command => sub { &main::epubmaker('epub') }
				   ],
			   ],
			],
			[ Button => 'Link Check', -command => sub { &main::errorcheckpop_up($textwindow,$top,'Link Check') } ],
			[ Button => 'HTML Tidy', -command => sub { &main::errorcheckpop_up($textwindow,$top,'HTML Tidy') } ],
			[ Button => 'W3C Validate', -command => sub {
				if   ($main::w3cremote) { &main::errorcheckpop_up($textwindow,$top,'W3C Validate Remote') }
				else              { &main::errorcheckpop_up($textwindow,$top,'W3C Validate'); }
				unlink 'null' if ( -e 'null' );
			} ],
			[ Button => 'W3C Validate CSS', -command => sub {
				&main::errorcheckpop_up($textwindow,$top,'W3C Validate CSS');    #validatecssrun('');
				unlink 'null' if ( -e 'null' );
			} ],
			[ Button => 'pphtml', -command => sub {
				&main::errorcheckpop_up($textwindow,$top,'pphtml');
				unlink 'null' if ( -e 'null' );
			} ],
			[ Button => 'Image Check', -command => sub {
				&main::errorcheckpop_up($textwindow,$top,'Image Check');
				unlink 'null' if ( -e 'null' );
			} ],
			[ Button => 'Epub Friendly', -command => sub {
				&main::errorcheckpop_up($textwindow,$top,'Epub Friendly');
				unlink 'null' if ( -e 'null' );
			} ],
			[ Button => 'Check All', -command => sub {
				&main::errorcheckpop_up($textwindow,$top,'Check All');
				unlink 'null' if ( -e 'null' );
			} ],
		]
	);

	my $singlesource = $menubar->cascade(
		-label     => 'Sin~gle Source',
		-tearoff   => 1,
		-menuitems => [
			[
			   Cascade    => 'PGTEI Tools',
			   -tearoff   => 0,
			   -menuitems => [
				   [
					  Button   => 'W3C Validate PGTEI',
					  -command => sub {
						  &main::errorcheckpop_up($textwindow,$top,'W3C Validate');
						}
				   ],
				   [
					  Button   => 'Gnutenberg Press Online',
					  -command => sub {
						  &main::runner(
$main::globalbrowserstart, "http://pgtei.pglaf.org/marcello/0.4/tei-online" );
						}
				   ],
				   [
					  Button   => 'Gnutenberg Press (HTML only)',
					  -command => sub { &main::gnutenberg('html') }
				   ],
				   [
					  Button   => 'Gnutenberg Press (Text only)',
					  -command => sub { &main::gnutenberg('txt') }
				   ],

			   ]
			],
			[
			   Cascade    => 'RST Tools',
			   -tearoff   => 0,
			   -menuitems => [
				   [
					  Button   => 'dp2rst Conversion',
					  -command => sub {
						  &main::runner(
$main::globalbrowserstart, "http://www.pgdp.net/wiki/Dp2rst" );
						}
				   ],
				   [
					  Button   => 'EpubMaker (all formats)',
					  -command => sub { &main::epubmaker() }
				   ],
				   [
					  Button   => 'EpubMaker (HTML only)',
					  -command => sub { &main::epubmaker('html') }
				   ],
				   [
					  Button   => 'EpubMaker Online',
					  -command => sub {
						  &main::runner(
							   $main::globalbrowserstart, "http://epubmaker.pglaf.org/"
						  );
						}
				   ],
			   ],
			]

		]
	);
	
	&main::unicodemenu();


	$menubar->Cascade(
					   -label     => '~Preferences',
					   -tearoff   => 1,
					   -menuitems => menu_preferences
	);

	$menubar->Cascade(
		-label     => '~Help',
		-tearoff   => 1,
		-menuitems => [
			[ Button => '~About',    -command => sub{&main::about_pop_up($top)}],
			[ Button => '~Versions', -command => [ \&main::showversion, $top ] ],
			[
			   Button   => '~Manual',
			   -command => sub {        # FIXME: sub this out.
				   runner(
$main::globalbrowserstart, "http://www.pgdp.net/wiki/PPTools/Guiguts"
				   );
				 }
			],

			[
			   Button   => '~PP Process Checklist',
			   -command => sub {        # FIXME: sub this out.
				   runner(
$main::globalbrowserstart, "http://www.pgdp.net/wiki/Guiguts_PP_Process_Checklist"
				   );
				 }
			],

			# FIXME: Disable update check until it works
			[
			   Button   => 'Check For ~Updates',
			   -command => sub { &main::checkforupdates(0) }
			],
			[ Button => '~Hot keys',              -command => \&main::hotkeyshelp ],
			[ Button => '~Function History',      -command => \&main::opspop_up ],
			[ Button => '~Regex Quick Reference', -command => \&main::regexref ],
		]
	);
}

#another attempt at menus
sub menubuildtwo {
	my $menubar = $main::menubar;
	my $textwindow = $main::textwindow;
	my $top = $main::top;
	
	my $file = $menubar->cascade(
		-label     => '~File v2',
		-tearoff   => 1,
		-menuitems => [
			 [ 'command',   '~Open', -command => sub {&main::file_open($textwindow)} ],
			 [
			   'command',
			   '~Save',
			   -accelerator => 'Ctrl+s',
			   -command     => sub { main::savefile }
			 ],
			 [ 'command', 'Save ~As', -command => sub{&main::file_saveas($textwindow)} ],
			 [ 'separator', '' ],
			 map ( [
					 Button   => "$main::recentfile[$_]",
					 -command => [ \&main::openfile, $main::recentfile[$_] ]
				   ],
				   ( 0 .. scalar(@main::recentfile) - 1 ) ),
			 [ 'separator', '' ],
			 [
			   'command',
			   '~Include File',
			   -command => sub { &main::file_include($textwindow) }
			 ],
			 [ 'command', 'Import Prep Text Files', -command => sub{&main::file_import($textwindow,$top)}],
			 [
			   'command',
			   'Export As Prep Text Files',
			   -command => sub{&main::file_export($textwindow,$top)}
			 ],
			 [ 'separator', '' ],
			# include cascading page marker section
			 [
			   Cascade    => 'Page Markers',
			   -tearoff   => 0,
			   -menuitems => [
				   [
					  'command',
					  '~Guess Page Markers...',
					  -command => \&main::file_guess_page_marks
				   ],
				   [
					  'command',
					  'Set Page ~Markers...',
					  -command => \&main::file_mark_pages
				   ],
				   [
					  'command',
					  '~Adjust Page Markers',
					  -command => \&main::viewpagenums
				   ],
				 ]
			],
			[ 'separator', '' ],
			[
			   'command',
			   'View Project Comments',
			   -command => sub {
				   my $defaulthandler = $main::extops[0]{command};
				   $defaulthandler =~ s/\$f\$e/project_comments.html/;
				   runner( &main::cmdinterp($defaulthandler) );
				 }
			],
			[
			   'command',
			   'View Project Discussion',
			   -command => sub {
				   return if &main::nofileloadedwarning();
				   runner(
"$main::globalbrowserstart http://www.pgdp.net/c/tools/proofers/project_topic.php?project=$main::projectid"
				   ) if $main::projectid;
				 }
			],
			# end of copy
			 [ 'separator', '' ],
			 [ 'command', 'Debug', -command => sub { &main::debug_dump } ],
			 [ 'command',   '~Close', -command => sub { &main::file_close($textwindow) } ],
			 [ 'command', 'E~xit', -command => sub { &main::_exit } ],
		  ]

	);

	my $edit = $menubar->cascade(
		-label     => '~Edit',
		-tearoff   => 1,
		-menuitems => [
			[
			   'command', 'Undo',
			   -command     => sub { $textwindow->undo },
			   -accelerator => 'Ctrl+z'
			],

			[
			   'command', 'Redo',
			   -command     => sub { $textwindow->redo },
			   -accelerator => 'Ctrl+y'
			],
			[ 'separator', '' ],

			[
			   'command', 'Cut',
			   -command     => sub { &main::cut() },
			   -accelerator => 'Ctrl+x'
			],

			[ 'separator', '' ],
			[
			   'command', 'Copy',
			   -command     => sub { &main::textcopy() },
			   -accelerator => 'Ctrl+c'
			],
			[
			   'command', 'Paste',
			   -command     => sub { &main::paste() },
			   -accelerator => 'Ctrl+v'
			],
			[
			   'command',
			   'Col Paste',
			   -command => sub {    # FIXME: sub edit_column_paste
				   $textwindow->addGlobStart;
				   $textwindow->clipboardColumnPaste;
				   $textwindow->addGlobEnd;
			   },
			   -accelerator => 'Ctrl+`'
			],
			[ 'separator', '' ],
			[
			   'command',
			   'Select All',
			   -command => sub {
				   $textwindow->selectAll;
			   },
			   -accelerator => 'Ctrl+/'
			],
			[
			   'command',
			   'Unselect All',
			   -command => sub {
				   $textwindow->unselectAll;
			   },
			   -accelerator => 'Ctrl+\\'
			],
		  ]

	);
	my $search = $menubar->cascade(
		-label     => 'Search & ~Replace',
		-tearoff   => 1,
		-menuitems => [
			[ 'command', 'Search & ~Replace...', -command => \&main::searchpopup ],
			[ 'command', '~Stealth Scannos...',  -command => \&main::stealthscanno ],
			[ 'separator', '' ],
			[
			   'command',
			   'Goto ~Line...',
			   -command => sub {
				   main::gotoline();
				   main::update_indicators();
				 }
			],
			[
			   'command',
			   'Goto ~Page...',
			   -command => sub {
				   main::gotopage();
				   main::update_indicators();
				 }
			],
			[ 'separator', '' ],
			[
			   'command',
			   'Find Proofer Comments',
			   -command => \&main::find_proofer_comment
			],
			[
			   'command',
			   'Find ~Orphaned Brackets...',
			   -command => \&main::orphanedbrackets
			],
			[ 'command', 'Find Orphaned Markup...', -command => \&main::orphanedmarkup ],
			[ 'separator', '' ],
			[
			   'command',
			   'Find next /*..*/ block',
			   -command => [ \&main::nextblock, 'default', 'forward' ]
			],
			[
			   'command',
			   'Find previous /*..*/ block',
			   -command => [ \&main::nextblock, 'default', 'reverse' ]
			],
			[
			   'command',
			   'Find next /#..#/ block',
			   -command => [ \&main::nextblock, 'block', 'forward' ]
			],
			[
			   'command',
			   'Find previous /#..#/ block',
			   -command => [ \&main::nextblock, 'block', 'reverse' ]
			],
			[
			   'command',
			   'Find next /$..$/ block',
			   -command => [ \&main::nextblock, 'stet', 'forward' ]
			],
			[
			   'command',
			   'Find previous /$..$/ block',
			   -command => [ \&main::nextblock, 'stet', 'reverse' ]
			],
			[
			   'command',
			   'Find next /p..p/ block',
			   -command => [ \&main::nextblock, 'poetry', 'forward' ]
			],
			[
			   'command',
			   'Find previous /p..p/ block',
			   -command => [ \&main::nextblock, 'poetry', 'reverse' ]
			],
			[
			   'command',
			   'Find next indented block',
			   -command => [ \&main::nextblock, 'indent', 'forward' ]
			],
			[
			   'command',
			   'Find previous indented block',
			   -command => [ \&main::nextblock, 'indent', 'reverse' ]
			],
		]
	);

	my $bookmarks = $menubar->cascade(
									   -label     => '~Bookmark',
									   -tearoff   => 1,
									   -menuitems => menu_bookmarks,
	);

	my $selection = $menubar->cascade(
		-label     => '~Selection',
		-tearoff   => 1,
		-menuitems => [
			[
			   Button   => '~lowercase Selection',
			   -command => sub {
				   main::case ( $textwindow, 'lc' );
				 }
			],
			[
			   Button   => '~Sentence case Selection',
			   -command => sub { main::case ( $textwindow, 'sc' ); }
			],
			[
			   Button   => '~Title Case Selection',
			   -command => sub { main::case ( $textwindow, 'tc' ); }
			],
			[
			   Button   => '~UPPERCASE Selection',
			   -command => sub { main::case ( $textwindow, 'uc' ); }
			],
			[ 'separator', '' ],
			[
			   Button   => 'Surround Selection With...',
			   -command => sub {
				   if ( defined( $main::lglobal{surpop} ) ) {
					   $main::lglobal{surpop}->deiconify;
					   $main::lglobal{surpop}->raise;
					   $main::lglobal{surpop}->focus;
				   } else {
					   $main::lglobal{surpop} = $top->Toplevel;
					   $main::lglobal{surpop}->title('Surround text with:');

					   my $f =
						 $main::lglobal{surpop}
						 ->Frame->pack( -side => 'top', -anchor => 'n' );
					   $f->Label( -text =>
"Surround the selection with?\n\\n will be replaced with a newline.",
						 )->pack(
								  -side   => 'top',
								  -pady   => 5,
								  -padx   => 2,
								  -anchor => 'n'
						 );
					   my $f1 =
						 $main::lglobal{surpop}
						 ->Frame->pack( -side => 'top', -anchor => 'n' );
					   my $surstrt =
						 $f1->Entry(
									 -width      => 8,
									 -background => $main::bkgcolor,
									 -font       => $main::lglobal{font},
									 -relief     => 'sunken',
						 )->pack(
								  -side   => 'left',
								  -pady   => 5,
								  -padx   => 2,
								  -anchor => 'n'
						 );
					   my $surend =
						 $f1->Entry(
									 -width      => 8,
									 -background => $main::bkgcolor,
									 -font       => $main::lglobal{font},
									 -relief     => 'sunken',
						 )->pack(
								  -side   => 'left',
								  -pady   => 5,
								  -padx   => 2,
								  -anchor => 'n'
						 );
					   my $f2 =
						 $main::lglobal{surpop}
						 ->Frame->pack( -side => 'top', -anchor => 'n' );
					   my $gobut = $f2->Button(
						   -activebackground => $main::activecolor,
						   -command          => sub {
							   main::surroundit( $surstrt->get, $surend->get,
										   $textwindow );
						   },
						   -text  => 'OK',
						   -width => 16
						 )->pack(
								  -side   => 'top',
								  -pady   => 5,
								  -padx   => 2,
								  -anchor => 'n'
						 );
					   $main::lglobal{surpop}->protocol(
						   'WM_DELETE_WINDOW' => sub {
							   $main::lglobal{surpop}->destroy;
							   undef $main::lglobal{surpop};
						   }
					   );
					   $surstrt->insert( 'end', '_' ) unless ( $surstrt->get );
					   $surend->insert( 'end', '_' ) unless ( $surend->get );
					   $main::lglobal{surpop}->Icon( -image => $main::icon );
				   }
				 }
			],
			[
			   Button   => 'Flood Fill Selection With...',
			   -command => sub {
				   $textwindow->addGlobStart;
				   $main::lglobal{floodpop} =
					 main::flood( $textwindow, $top, $main::lglobal{floodpop},
							$main::lglobal{font}, $main::activecolor, $main::icon );
				   $textwindow->addGlobEnd;
				 }
			],
			[ 'separator', '' ],
			[
			   Button   => 'Indent Selection  1',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::indent( $textwindow, 'in' );
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Indent Selection -1',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::indent( $textwindow, 'out', $main::operationinterrupt );
				   $textwindow->addGlobEnd;
				 }
			],
			[ 'separator', '' ],
			[
			   Button   => '~Rewrap Selection',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::selectrewrap( $textwindow, $main::lglobal{seepagenums},
								 $main::scannos_highlighted, $main::rwhyphenspace );
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => '~Block Rewrap Selection',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::blockrewrap();
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Interrupt Rewrap',
			   -command => sub { $main::operationinterrupt = 1 }
			],
			[ 'separator', '' ],
			[ Button => '~Align text on string...', -command => \&main::alignpopup ],
			[ 'separator', '' ],
			[
			   Button   => 'Convert To Named/Numeric Entities',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::tonamed($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Convert From Named/Numeric Entities',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::fromnamed($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Convert Fractions',
			   -command => sub {
				   my @ranges = $textwindow->tagRanges('sel');
				   $textwindow->addGlobStart;
				   if (@ranges) {
					   while (@ranges) {
						   my $end   = pop @ranges;
						   my $start = pop @ranges;
						   &main::fracconv( $textwindow, $start, $end );
					   }
				   } else {
					   &main::fracconv( $textwindow, '1.0', 'end' );
				   }
				   $textwindow->addGlobEnd;
				 }
			],
			# highlighting moved here from search and replace
			[ 'separator', '' ],
			[
			   'command', 'Highlight double quotes in selection',
			   -command     => [ \&main::hilite, '"' ],
			   -accelerator => 'Ctrl+Shift+"'
			],
			[
			   'command', 'Highlight single quotes in selection',
			   -command     => [ \&main::hilite, '\'' ],
			   -accelerator => 'Ctrl+\''
			],
			[
			   'command', 'Highlight arbitrary characters in selection...',
			   -command     => \&main::hilitepopup,
			   -accelerator => 'Ctrl+Alt+h'
			],
			[
			   'command',
			   'Remove Highlights',
			   -command => sub {    # FIXME: sub search_rm_hilites
				   $textwindow->tagRemove( 'highlight', '1.0', 'end' );
				   $textwindow->tagRemove( 'quotemark', '1.0', 'end' );
			   },
			   -accelerator => 'Ctrl+0'
			],
			# end of moved section
		  ]

	);

	my $fixup = $menubar->cascade(
		-label     => 'Fi~xup',
		-tearoff   => 1,
		-menuitems => [
			[
			   Button   => 'Remove End-of-line Spaces',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::endofline();
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Remove Blank Lines Before Page Separators',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::delblanklines();
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'Convert Windows CP 1252 characters to Unicode',
			   -command => \&main::cp1252toUni
			],
			[ Button => 'Fix sidenotes', -command => \&main::sidenotes ],
			[ Button => 'Run Fi~xup...', -command => \&main::fixpopup ],
			[ Button => '~Footnote Fixup...', -command => \&main::footnotepop ],
			[ 'separator', '' ],
			[ Button => 'Fix ~Page Separators...', -command => \&main::separatorpopup ],
			[ 'separator', '' ],
			[
			   'command',
			   'Find Asterisks w/o slash',
			   -command => \&main::find_asterisks
			],
			[
			   'command',
			   'Find Transliterations...',
			   -command => \&main::find_transliterations
			],
			[ Button => 'Find Greek...', -command => \&main::findandextractgreek ],
			[ Button => '~Greek Transliteration', -command => \&main::greekpopup ],
			[ 'separator', '' ],
			[
			   Button   => 'Reformat Poetry ~Line Numbers',
			   -command => \&main::poetrynumbers
			],
			[ 'separator', '' ],
			[
			   Button   => 'Run ~Word Frequency Routine...',
			   -command => sub{&main::wordfrequency($textwindow,$top)}
			],
			[ Button => 'Spell in multiple languages', -command => sub{&main::spellmultiplelanguages($textwindow,$top)} ],
			[ 'command', 'Spell ~Check...',      -command => \&main::spellchecker ],
			[ 'separator', '' ],
			[ Button => 'Run ~Jeebies...',     -command => \&main::jeebiespop_up ],
			[ Button => 'Run ~Gutcheck...',    -command => \&main::gutcheck ],
			[ Button => 'Gutcheck options...', -command => \&main::gutopts ],
			[ Button   => 'pptxt...',
			   -command => sub {
				   &main::errorcheckpop_up($textwindow,$top,'pptxt');
				   unlink 'null' if ( -e 'null' );
			   },
			],
			[ 'separator', '' ],
			[ Button => '~HTML Fixup...',     -command => sub{&main::htmlpopup($textwindow,$top)} ],
			[ Button => 'View in Browser',
				-command          => sub {
					&main::runner( &main::cmdinterp("$main::extops[0]{command}") );
				},
			],
			[ Button => 'HTML Check All', -command => sub {
				&main::errorcheckpop_up($textwindow,$top,'Check All');
				unlink 'null' if ( -e 'null' );
			} ],
			[ 'separator', '' ],
			[ Button => 'HTML Auto ~Index (List)', -command => sub{&main::autoindex($textwindow)} ],
			[
			   Cascade    => 'HTML to Epub',
			   -tearoff   => 0,
			   -menuitems => [
				   [
					  Button   => 'EpubMaker Online',
					  -command => sub {
						  &main::runner(
							   "$main::globalbrowserstart http://epubmaker.pglaf.org/"
						  );
						}
				   ],
				   [
					  Button   => 'EpubMaker',
					  -command => sub { &main::epubmaker('epub') }
				   ],
			   ],
			],
			[
			   Cascade    => 'PGTEI Tools',
			   -tearoff   => 0,
			   -menuitems => [
				   [
					  Button   => 'W3C Validate PGTEI',
					  -command => sub {
						  &main::errorcheckpop_up($textwindow,$top,'W3C Validate');
						}
				   ],
				   [
					  Button   => 'Gnutenberg Press (HTML only)',
					  -command => sub { &main::gnutenberg('html') }
				   ],
				   [
					  Button   => 'Gnutenberg Press (Text only)',
					  -command => sub { &main::gnutenberg('txt') }
				   ],
				   [
					  Button   => 'Gnutenberg Press Online',
					  -command => sub {
						  &main::runner(
$main::globalbrowserstart, "http://pgtei.pglaf.org/marcello/0.4/tei-online" );
						}
				   ],
			   ],
			],
			[
			   Cascade    => 'RST Tools',
			   -tearoff   => 0,
			   -menuitems => [
				   [
					  Button   => 'EpubMaker Online',
					  -command => sub {
						  &main::runner(
							   $main::globalbrowserstart, "http://epubmaker.pglaf.org/"
						  );
						}
				   ],
				   [
					  Button   => 'EpubMaker (all formats)',
					  -command => sub { &main::epubmaker() }
				   ],
				   [
					  Button   => 'EpubMaker (HTML only)',
					  -command => sub { &main::epubmaker('html') }
				   ],
				   [
					  Button   => 'dp2rst Conversion',
					  -command => sub {
						  &main::runner(
$main::globalbrowserstart, "http://www.pgdp.net/wiki/Dp2rst" );
						}
				   ],
			   ]
			],
		]
	);

	my $text = $menubar->cascade(
		-label     => "Text",
		-tearoff   => 1,
		-menuitems => [
			[
			   Button   => "Convert Italics",
			   -command => sub {
				   &main::text_convert_italic( $textwindow, $main::italic_char );
				 }
			],
			[
			   Button   => "Convert Bold",
			   -command => sub { &main::text_convert_bold( $textwindow, $main::bold_char ) }
			],
			[
			   Button   => 'Convert <tb> to asterisk break',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::text_convert_tb($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[
			   Button   => 'All of the above',
			   -command => sub {
				   &main::text_convert_italic( $textwindow, $main::italic_char );
				   &main::text_convert_bold( $textwindow, $main::bold_char );
				   $textwindow->addGlobStart;
				   &main::text_convert_tb($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[ Button => "Options...", -command => sub{&main::text_convert_options($top)}],
			[ 'separator', '' ],
			[
			   Button   => 'Small caps to all caps',
			   -command => \&main::text_convert_smallcaps
			],
			[
			   Button   => 'Remove small caps markup',
			   -command => \&main::text_remove_smallcaps_markup
			],
			[ 'separator', '' ],
			[
			   Button   => '~Add a Thought Break',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::text_thought_break($textwindow);
				   $textwindow->addGlobEnd;
				 }
			],
			[ Button => 'ASCII Table Special Effects...', -command => \&main::tablefx ],
			[ Button => 'ASCII ~Boxes...',          -command => \&main::asciipopup ],
			[ 'separator', '' ],
			[
			   Button   => 'Clean Up Rewrap ~Markers',
			   -command => sub {
				   $textwindow->addGlobStart;
				   &main::cleanup();
				   $textwindow->addGlobEnd;
				 }
			],
		  ]

	);

	my $external = $menubar->cascade(
									  -label     => 'External',
									  -tearoff   => 1,
									  -menuitems => &menu_external,
	);
	
	&main::unicodemenu();

	$menubar->Cascade(
					   -label     => 'Options',
					   -tearoff   => 1,
					   -menuitems => &main::menu_preferences
	);

	$menubar->Cascade(
		-label     => '~Help',
		-tearoff   => 1,
		-menuitems => [
			[
			   Button   => '~Manual',
			   -command => sub {        # FIXME: sub this out.
				   &main::runner(
$main::globalbrowserstart, "http://www.pgdp.net/wiki/PPTools/Guiguts"
				   );
				 }
			],

			[
			   Button   => '~PP Process Checklist',
			   -command => sub {        # FIXME: sub this out.
				   &main::runner(
$main::globalbrowserstart, "http://www.pgdp.net/wiki/Guiguts_PP_Process_Checklist"
				   );
				 }
			],
			[ Button => '~Latin 1 Chart',         -command => \&main::latinpopup ],
			[ Button => '~Regex Quick Reference', -command => \&main::regexref ],
			[ Button => '~Hot keys',              -command => \&main::hotkeyshelp ],
			[ 'separator', '' ],
			[ Button => '~UTF Character entry',   -command => \&main::utford ],
			[ Button => '~UTF Character Search',  -command => \&main::uchar ],
			[ 'separator', '' ],
			[ Button => '~About',    -command => sub{&main::about_pop_up($top)}],
			[ Button => '~Versions', -command => [ \&main::showversion, $top ] ],

			# FIXME: Disable update check until it works
			[
			   Button   => 'Check For ~Updates',
			   -command => sub { &main::checkforupdates(0) }
			],
			[ 'separator', '' ],
			[ Button => '~Function History',      -command => \&main::opspop_up ],
		]
	);
}



1;