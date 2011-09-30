erase *.zip
7z a -x!.* -x!setting.rc -x!header.txt -x!make*.* -r WinGuts-0.3.10.zip *.*
7z a -x!.* -x!setting.rc -x!header.txt -x!WinGuts.exe -x!*.zip -x!make*.* -r guiguts-0.3.10.zip *.*