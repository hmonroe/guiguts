erase *.zip
7z a -x!.* -x!setting.rc -x!header.txt -r WinGuts-0.3.10.zip *.*
7z a -x!.* -x!setting.rc -x!header.txt -x!WinGuts.exe -x!*.zip -r guiguts-0.3.10.zip *.*