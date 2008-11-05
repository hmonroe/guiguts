$Id$

This directory contains some perl toys to play with. 

These are standalone, not intergrated with GuiGuts. They need to be run
from a command line interface. cmd.exe on Windows, your favorite shell
on Unix type systems.


gw2pd.pl:

Convert a Project goodwords.txt list to GuiGuts project dictionary file.

Usage:
    perl gw2pd.pl goodwords.txt [Project Name]
    
"Project Name" is the text file being processed minus file name
extensiong, e.g., herdingcats.txt: command line is

    perl gw2pd.pl goodwords.txt herdingcats

Outputs file herdingcats.dic.

