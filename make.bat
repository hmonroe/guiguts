erase *.zip
7z a -x!.* -x!setting.rc -x!header.txt -x!*.bat -x!gg.ico -x!tools -x!samples -x!tests -x!perl -x!Python27 -x!Win*.* -r guiguts-1.0.1.zip *.* lib\Tk\Toolbar\tkIcons 
7z a -x!*.exe -r guiguts-1.0.1.zip tools\gutcheck tools\jeebies
7z a -x!.* -x!setting.rc -x!header.txt -x!make.bat -x!gg.ico -x!*.zip -r guiguts-win-epub-1.0.1.zip *.* lib\Tk\Toolbar\tkIcons
