#!/usr/bin/perl -w

use strict;
use File::Basename;
use Getopt::Long;

# pphtml.pl
# command line version of ppvhtml.pl
# author: Roger Frank (DP:rfrank)
# last edit: 03-Sep-2009 10:53 PM

my $vnum  = "1.14";

my @book = ();
my @css = ();
my %classes_used = ();

my $help     = 0;                   # set true if help requested
my $srctext = "book.html";          # default source file
my $outfile = "xxx";

my $filename;
my $frm_detail;
my $detailLevel;

usage()
    if (
    !GetOptions(
        'help|?'  => \$help,        # display help
        'i=s'     => \$srctext,     # requires input filename if used
        'o=s'     => \$outfile,     # output filename (optional)
    )                               
    or $help
    );
    
sub usage {
    print "Unknown option: @_\n" if (@_);
    print "usage: pphtml.pl [-i infile.txt] [-o pphtml.log]\n";
    exit;
}

sub runProgram {
  if ($outfile eq "xxx") {
    $outfile = dirname($srctext)."/pphtml.log";
  }
  open LOGFILE,"> $outfile" || die "output file error\n";
  print LOGFILE "program " . basename($0) . " version $vnum\n";
  print LOGFILE "processing $srctext\n  to $outfile\n\n";
  printf LOGFILE ("%s\n", "-" x 80);

  # read book a line at a time into the array @book
  open INFILE,$srctext || die "no source file\n";
  my $ln;
  while ($ln = <INFILE>) {
    $ln =~ s/\r\n/\n/;
    chomp $ln;
    push(@book, $ln);
  }
  close INFILE ;

  # run checks specified in the following call sequence
  &header_check;
  &specials;
  &css_check;

  # close out the program
  (my $sec, my $min, my $hour, my $mday, my $mon,
    my $year, my $wday, my $yday, my $isdst) = localtime(time);
  printf LOGFILE ("\n%s\n", "=" x 80);
  printf LOGFILE "run completed: %4d-%02d-%02d %02d:%02d:%02d\n",
    $year+1900,$mon+1,$mday,$hour,$min,$sec;

  sub header_check {
    print LOGFILE "header check\n";
    my $printing = 0;
    foreach my $line (@book) {
      if ($line =~ /<title>/) {
          $printing = 1;
      }
      if ($printing) {
        printf LOGFILE ("%s\n", $line);
      }
      if ($line =~ /<\/title>/) {
        $printing = 0;
      }
    }
    printf LOGFILE ("%s\n", "-" x 80);
  }

  sub specials {
    print LOGFILE "specials check\n";
    my($linenum);

    # Illustration markup
    # 
    my $count = 0;
    foreach my $line (@book) {
      if ($line =~ /\[Illustration/) {
        printf LOGFILE ("WARNING: unconverted illustration:  %s (line %d)\n", $line, $count);
        $count += 1;
      }
    }

    # check missing mdashes
    # need to use "--" in alt strings of images
    $count = 0;
    foreach my $line (@book) {
      if ($line =~ /--/ and ($line !~ /<!--/ and $line !~ /-->/ and $line !~ /alt=/)) {
        printf LOGFILE ("  %s\n", $line);
        $count += 1;
      }
    }
    printf LOGFILE ("  *** %d suspected missing mdashes\n", $count);

    # check table summaries
    $count = 0;
    foreach my $line (@book) {
      if ($line =~ /<table/ and $line !~ /summary/) {
        printf LOGFILE ("  %s\n", $line);
        $count += 1;
      }
    }
    printf LOGFILE ("  *** %d suspected missing table summaries\n", $count);

    # show lines containing left or right braces (will catch [oe] and [ae] also)
    # and exclude those used in page numbers (or footnotes)
    $count = 0;
    foreach my $line (@book) {
      next if ( $line =~ /XML/);
      my $savedline = $line;
      $line =~ s=["']>\[=XXX=g;
      $line =~ s=\]<\/=XXX=g;
      if ( $line =~ /[\[\]]/) {
        printf LOGFILE ("  %s\n", $savedline);
        $count += 1;
      }
      $line = $savedline;
    }
    printf LOGFILE ("  *** %d suspected lines containing left or right braces\n", $count);

    # check for double spaces in HTML source
    $count = 0;
    my $lastline = "trash";
    $linenum = 0;
    foreach my $line (@book) {
      $linenum += 1;
      if ($lastline =~ /^$/ and $line =~ /^$/) {
        $count += 1;
        if ($count < 5) {
          printf LOGFILE ("  double-blank near %d\n", $linenum);
        }
        if ($count == 5) {
          print LOGFILE ("  additional superfluous whitespace in HTML not itemized.\n")
        }
      }
      $lastline = $line;
    }
    printf LOGFILE ("  *** %d occurrences of superfluous blank lines in HTML\n", $count);

    # check for extraneous [Blank Page] lines.
    foreach $_ (@book) {
      if (/Blank Page/) {
        printf LOGFILE ("  BLANK PAGE: %s\n", $_);
      }
    }

    # check for unconverted [oe] or [ae]
    foreach $_ (@book) {
      if (/\[[o|a]e\]/) {
        printf LOGFILE ("  UNCONVERTED LIG: %s\n", $_);
      }
    }

    # check for sloppy equal sign placement
    foreach $_ (@book) {
      if (/(= )|( =)/) {
        printf LOGFILE ("  EQUAL SIGN: %s\n", $_);
      }
    }

    # check for leftover hr based on style not class
    foreach $_ (@book) {
      if (/hr style/) {
        printf LOGFILE ("  UNCONVERTED HR: %s\n", $_);
      }
    }

    # sloppy self-closed tag
    foreach $_ (@book) {
      if (/\S\/>/) {
        printf LOGFILE ("  CLOSING TAG: %s\n", $_);
      }
    }

    # sahlberg's ampersand check
    foreach $_ (@book) {
      if (/&amp;amp/) {
        printf LOGFILE ("    AMPERSAND: %s\n", $_);
      }
    }

    # sloppy self-closed tag and leftover quotes
    foreach $_ (@book) {
      if (/<p>\./) {
        printf LOGFILE ("  POSSIBLE PPG COMMAND: %s\n", $_);
      }
      if ($_ =~ /\`/) {
        printf LOGFILE "  TICK-MARK CHECK: %s\n", $_;
      }
      if ($_ =~ /[^=]''/) {
        printf LOGFILE "  QUOTE PROBLEM: %s\n", $_;
      }
    }

    # smart-quote construction errors
    foreach $_ (@book) {
         # left single quote followed by whitespace
         if (/\&#8216;\s/) { printf LOGFILE ("  SMART-QUOTE1: %s\n", $_); }
         # left double quote followed by whitespace
         if (/\&#8220;\s/) { printf LOGFILE ("  SMART-QUOTE2: %s\n", $_); }
         # right double quote at start of line
         if (/^\&#8221;/)  { printf LOGFILE ("  SMART-QUOTE3: %s\n", $_); }
         # right double quote at start of line
         if (/<p>\&#8221;/)  { printf LOGFILE ("  SMART-QUOTE3: %s\n", $_); }
         # left double quote at end of line
         if (/\&#8220;$/)  { printf LOGFILE ("  SMART-QUOTE4: %s\n", $_); }
         # left double quote at end of line
         if (/\&#8220;<\/p>/)  { printf LOGFILE ("  SMART-QUOTE4: %s\n", $_); }         
    }
    
    foreach $_ (@book) {
        if ( m{\*} && not m{XML} ) {
            printf LOGFILE ("  asterisk: %s\n", $_);
        } 
    }

    printf LOGFILE ("%s\n", "-" x 80);
  }


  sub css_check {
    &show_classes;
    &show_styles;
    &css_block;
    &css_crosscheck;
  }

  # show classes used in <body> of text.
  sub show_classes {
    print LOGFILE ("----- classes used -----\n");
    my $intextbody = 0;
    foreach $_ (@book) {
      if ( not $intextbody and not /<body>/) {
        next;
      }
      $intextbody = 1;
      # special case <h?>
      if (/<(h\d)/) {
        my $h = $1;
#        $h =~ s/<(h\d).*$/$1/;
        $classes_used{$h} += 1;
      }
      # special case <h?>
      if (/<table/) {
        $classes_used{"table"} += 1;
      }
      if (/<(block[a-z]*)/) {
        my $h = $1;
        $classes_used{$h} += 1;
      }
      if (/<ins/) {
        $classes_used{"ins"} += 1;
      }
      my $x = 0;
      while (/^.*? class=['"]([^'"]+)['"](.*)$/) {
        my $kew = $_;
        my $tmp = $2;
        my @sp = split(/ /, $1);
        foreach my $t (@sp) {
          $classes_used{$t} += 1;
        }
        $x = $x + 1;
        $_ = $tmp;
#        s/class/-----/;
      }
    }
    
    foreach my $key (sort { $a cmp $b } (keys %classes_used)) {
      printf LOGFILE ("%4d | %s\n", $classes_used{$key}, $key);
    }
  }

  # show styles used in <body> of text.
  sub show_styles {
    print LOGFILE ("----- styles used -----\n");
    my %hash = ();
    my $intextbody = 0;
    foreach $_ (@book) {
      if ( not $intextbody and not /<body>/) {
        next;
      }
      $intextbody = 1;
      while (/style=['"]/) {
        my $tmp = $_;
        s/^.*? style=['"](.*?)['"].*$/$1/;
        $hash{$_} += 1;
        $_ = $tmp;
        s/style/-----/;
      }
    }
    foreach my $key (keys %hash) {
      printf LOGFILE ("%4d | %s\n", $hash{$key}, $key);
    }
  }

  # Perl trim function to remove whitespace from the start and end of the string
  sub trim($)
  {
  	my $string = shift;
  	$string =~ s/^\s+//;
  	$string =~ s/\s+$//;
  	return $string;
  }

  sub css_block {
    print LOGFILE ("----- CSS block definitions -----\n");
    my @splitcss = ();
    my $incss = 0;
    foreach $_ (@book) {
      if ( /text\/css/ ) {
        $incss = 1;
      }
      if ($incss and /<\/style>/) {
        $incss = 0;
      }
      if ($incss and /{/) {
        @css = (@css, $_);
      }
    }
    # strip definition
    my $ccount = 0;
    foreach $_ (@css) {
      s/^(.*?){.*$/$1/;
      $_ = trim($_);
      my @sp = split(/,/, $_);
      foreach my $t (@sp) {
        printf LOGFILE (" %-19s", $t);
        $ccount++;
        if ($ccount % 4 == 3) {
          print LOGFILE ("\n");
        }
        unshift(@splitcss, $t);
      }
    }
    @css = @splitcss;
    printf LOGFILE ("\n");
  }

  sub css_crosscheck {
    print LOGFILE ("----- CSS crosscheck -----\n");
    foreach my $cssdef (@css) {
      $cssdef =~ s/^.*?\.?([^\. ]+)$/$1/;
      if ($cssdef =~ /\b(p|body)\b/) {
         next;
      }
      my $found = 0;
      foreach my $cssused (keys %classes_used) {
        if ( $cssused eq $cssdef ) {
           $found++;
        }
      }
      if (not $found) {
        print LOGFILE "  ***possibly not used: $cssdef\n";
      }
    }

    foreach my $cssused (keys %classes_used) {
      my $found = 0;
      foreach my $cssdef (@css) {
      $cssdef =~ s/^.*?\.?([^\. ]+)$/$1/;
#        $cssdef =~ s/^.*?\.(.*)$/$1/;
        if ($cssdef =~ /\b(p|body)\b/) {
           next;
        }
        if ( $cssused eq $cssdef ) {
           $found++;
        }
      }
      if (not $found) {
        print LOGFILE "  ***possibly not defined: $cssused\n";
      }
    }

  }
}

# main program
runProgram()
