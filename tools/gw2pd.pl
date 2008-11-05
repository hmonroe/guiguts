#!/usr/bin/perl

# $Id$

# Convert DP GoodWords list to a GG project.dic file.

use strict;
use warnings;
use FileHandle;

# GG project.dic format:
#  %projectdict = (
#  'word' => '',
#  'word\'s' => '',
#  );

usage() unless @ARGV == 2;

my ($gw, $dict) = @ARGV;

$gw = new FileHandle "< $gw";
$dict = new FileHandle "> $dict.dic";

{
    local $\ = "\n";

    print $dict '%projectdict = (';

    while (<$gw>) {
        $_ =~ s/(?:\cM\cJ|\cM|\cJ)$//g; # We have to handle eol's explicitly.
        $_ =~ s/'/\\'/g; # Escape single quote/apostrophe
        $_ =~ s/(^.+$)/'$1' => '',/;
        
        print $dict $_  unless $_ =~ /^$/;
    }
    print $dict ');';
}

$dict->close;

sub usage {
    print <<EOM;

    perl gw2pd.pl goodwords.txt [Project Name]
    
    "Project Name" is the text file being processed, e.g., herdingcats.txt: 
    command line is 'perl gw2pd.pl goodwords.txt herdingcats'

EOM
    exit 1;
}

