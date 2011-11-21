erase *.zip
7z a -x!.* -x!setting.rc -x!header.txt -x!*.bat -x!gg.ico -x!perl -x!Python27 -x!Win*.* -r guiguts-0.3.18.zip *.* lib\Tk\Toolbar\tkIcons
7z a -x!.* -x!setting.rc -x!header.txt -x!make.bat -x!gg.ico -x!*.zip -x!Python27 -r guiguts-win-0.3.18.zip *.* lib\Tk\Toolbar\tkIcons
7z a -x!.* -x!setting.rc -x!header.txt -x!make.bat -x!gg.ico -x!*.zip -r guiguts-win-epub-0.3.18.zip *.* lib\Tk\Toolbar\tkIcons
