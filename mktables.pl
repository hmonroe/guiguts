#!/usr/bin/perl
## !!!!!!!!!!!!!!       IF YOU MODIFY THIS FILE       !!!!!!!!!!!!!!!!!!!!!!!!!
## Any files created or read by this program should be listed in 'mktables.lst'


# $Id$
require 5.008;    # Needs pack "U". Probably safest to run on 5.8.x
use strict;
use warnings;
use Carp;
use File::Spec;

##
## mktables -- create the runtime Perl Unicode files (lib/unicore/**/*.pl)
## from the Unicode database files (lib/unicore/*.txt).
##

## "Fuzzy" means this section in Unicode TR18:
##
##    The recommended names for UCD properties and property values are in
##    PropertyAliases.txt [Prop] and PropertyValueAliases.txt
##    [PropValue]. There are both abbreviated names and longer, more
##    descriptive names. It is strongly recommended that both names be
##    recognized, and that loose matching of property names be used,
##    whereby the case distinctions, whitespace, hyphens, and underbar
##    are ignored.

## Base names already used in lib/gc_sc (for avoiding 8.3 conflicts)
my %BaseNames;

##
## Process any args.
##
my $Verbose        = 0;
my $MakeTestScript = 0;
my $AlwaysWrite    = 0;
my $UseDir         = "";
my $FileList       = "$0.lst";
my $MakeList       = 0;

while (@ARGV) {
    my $arg = shift @ARGV;
    if ( $arg eq '-v' ) {
        $Verbose = 1;
    }
    elsif ( $arg eq '-q' ) {
        $Verbose = 0;
    }
    elsif ( $arg eq '-w' ) {
        $AlwaysWrite = 1;    # update the files even if they havent changed
        $FileList    = "";
    }
    elsif ( $arg eq '-check' ) {
        my $this = shift @ARGV;
        my $ok   = shift @ARGV;
        if ( $this ne $ok ) {
            print "Skipping as check params are not the same.\n";
            exit(0);
        }
    }
    elsif ( $arg eq '-maketest' ) {
        $MakeTestScript = 1;
    }
    elsif ( $arg eq '-makelist' ) {
        $MakeList = 1;
    }
    elsif ( $arg eq '-C' && defined( $UseDir = shift ) ) {
        -d $UseDir or die "Unknown directory '$UseDir'";
    }
    elsif ( $arg eq '-L' && defined( $FileList = shift ) ) {
        -e $FileList or die "Filelist '$FileList' doesn't appear to exist!";
    }
    else {
        die
            "usage: $0 [-v|-q|-w|-C dir|-L filelist] [-maketest] [-makelist]\n",
            "  -v          : Verbose Mode\n",
            "  -q          : Quiet Mode\n",
            "  -w          : Write files regardless\n",
            "  -maketest   : Make test script\n",
            "  -makelist   : Rewrite the file list based on current setup\n",
            "  -L filelist : Use this file list, (defaults to $0)\n",
            "  -C dir      : Change to this directory before proceeding\n",
            "  -check A B  : Executes only if A and B are the same\n";
    }
}

if ($FileList) {
    print "Reading file list '$FileList'\n"
        if $Verbose;
    open my $fh, "<", $FileList or die "Failed to read '$FileList':$!";
    my @input;
    my @output;
    for my $list ( \@input, \@output ) {
        while (<$fh>) {
            s/^ \s+ | \s+ $//xg;
            next if /^ \s* (?: \# .* )? $/x;
            last if /^ =+ $/x;
            my ($file) = split /\t/, $_;
            push @$list, $file;
        }
        my %dupe;
        @$list = grep !$dupe{$_}++, @$list;
    }
    close $fh;
    die "No input or output files in '$FileList'!"
        if !@input or !@output;
    if ($MakeList) {
        foreach my $file (@output) {
            unlink $file;
        }
    }
    if ($Verbose) {
        print "Expecting " . scalar(@input) . " input files. ",
            "Checking " . scalar(@output) . " output files.\n";
    }

    # we set maxtime to be the youngest input file, including $0 itself.
    my $maxtime = -M $0;    # do this before the chdir!
    if ($UseDir) {
        chdir $UseDir or die "Failed to chdir to '$UseDir':$!";
    }
    foreach my $in (@input) {
        my $time = -M $in;
        die "Missing input file '$in'" unless defined $time;
        $maxtime = $time if $maxtime < $time;
    }

    # now we check to see if any output files are older than maxtime, if
    # they are we need to continue on, otherwise we can presumably bail.
    my $ok = 1;
    foreach my $out (@output) {
        if ( !-e $out ) {
            print "'$out' is missing.\n"
                if $Verbose;
            $ok = 0;
            last;
        }
        if ( -M $out > $maxtime ) {
            print "'$out' is too old.\n"
                if $Verbose;
            $ok = 0;
            last;
        }
    }
    if ($ok) {
        print "Files seem to be ok, not bothering to rebuild.\n";
        exit(0);
    }
    print "Must rebuild tables.\n"
        if $Verbose;
}
else {
    if ($Verbose) {
        print "Not checking filelist.\n";
    }
    if ($UseDir) {
        chdir $UseDir or die "Failed to chdir to '$UseDir':$!";
    }
}

foreach my $lib ( 'To', 'lib',
    map { File::Spec->catdir( "lib", $_ ) }
    qw(gc_sc dt bc hst ea jt lb nt ccc) )
{
    next if -d $lib;
    mkdir $lib, 0755 or die "mkdir '$lib': $!";
}

my $LastUnicodeCodepoint = 0x10FFFF;    # As of Unicode 3.1.1.

my $HEADER = <<"EOF";
# !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!! 
# This file is built by $0 from e.g. UnicodeData.txt.
# Any changes made here will be lost!

EOF

sub force_unlink {
    my $filename = shift;
    return unless -e $filename;
    return if CORE::unlink($filename);

    # We might need write permission
    chmod 0777, $filename;
    CORE::unlink($filename) or die "Couldn't unlink $filename: $!\n";
}

##
## Given a filename and a reference to an array of lines,
## write the lines to the file only if the contents have not changed.
## Filename can be given as an arrayref of directory names
##
sub WriteIfChanged($\@) {
    my $file  = shift;
    my $lines = shift;

    $file = File::Spec->catfile(@$file) if ref $file;

    my $TextToWrite = join '', @$lines;
    if ( open IN, $file ) {
        local ($/) = undef;
        my $PreviousText = <IN>;
        close IN;
        if ( $PreviousText eq $TextToWrite ) {
            print "$file unchanged.\n" if $Verbose;
            return unless $AlwaysWrite;
        }
    }
    force_unlink($file);
    if ( not open OUT, ">$file" ) {
        die "$0: can't open $file for output: $!\n";
    }
    print "$file written.\n" if $Verbose;

    print OUT $TextToWrite;
    close OUT;
}

##
## The main datastructure (a "Table") represents a set of code points that
## are part of a particular quality (that are part of \pL, \p{InGreek},
## etc.). They are kept as ranges of code points (starting and ending of
## each range).
##
## For example, a range ASCII LETTERS would be represented as:
##   [ [ 0x41 => 0x5A, 'UPPER' ],
##     [ 0x61 => 0x7A, 'LOWER, ] ]
##
sub RANGE_START() {0}    ## index into range element
sub RANGE_END()   {1}    ## index into range element
sub RANGE_NAME()  {2}    ## index into range element

## Conceptually, these should really be folded into the 'Table' objects
my %TableInfo;
my %TableDesc;
my %FuzzyNames;
my %AliasInfo;
my %CanonicalToOrig;

##
## Turn something like
##    OLD-ITALIC
## into
##    OldItalic
##
sub CanonicalName($) {
    my $orig = shift;
    my $name = lc $orig;
    $name =~ s/(?<![a-z])(\w)/\u$1/g;
    $name =~ s/[-_\s]+//g;

    $CanonicalToOrig{$name} = $orig if not $CanonicalToOrig{$name};
    return $name;
}

##
## Store the alias definitions for later use.
##
my %PropertyAlias;
my %PropValueAlias;

my %PA_reverse;
my %PVA_reverse;

sub Build_Aliases() {
    ##
    ## Most of the work with aliases doesn't occur here,
    ## but rather in utf8_heavy.pl, which uses PVA.pl,

    # Placate the warnings about used only once. (They are used again, but
    # via a typeglob lookup)
    %utf8::PropertyAlias  = ();
    %utf8::PA_reverse     = ();
    %utf8::PropValueAlias = ();
    %utf8::PVA_reverse    = ();
    %utf8::PVA_abbr_map   = ();

    open PA, "< PropertyAliases.txt"
        or confess "Can't open PropertyAliases.txt: $!";
    while (<PA>) {
        s/#.*//;
        s/\s+$//;
        next if /^$/;

        my ( $abbrev, $name ) = split /\s*;\s*/;
        next if $abbrev eq "n/a";
        $PropertyAlias{$abbrev} = $name;
        $PA_reverse{$name}      = $abbrev;

        # The %utf8::... versions use japhy's code originally from utf8_pva.pl
        # However, it's moved here so that we build the tables at runtime.
        tr/ _-//d for $abbrev, $name;
        $utf8::PropertyAlias{ lc $abbrev } = $name;
        $utf8::PA_reverse{ lc $name }      = $abbrev;
    }
    close PA;

    open PVA, "< PropValueAliases.txt"
        or confess "Can't open PropValueAliases.txt: $!";
    while (<PVA>) {
        s/#.*//;
        s/\s+$//;
        next if /^$/;

        my ( $prop, @data ) = split /\s*;\s*/;

        if ( $prop eq 'ccc' ) {
            $PropValueAlias{$prop}{ $data[1] } = [ @data[ 0, 2 ] ];
            $PVA_reverse{$prop}{ $data[2] }    = [ @data[ 0, 1 ] ];
        }
        else {
            next if $data[0] eq "n/a";
            $PropValueAlias{$prop}{ $data[0] } = $data[1];
            $PVA_reverse{$prop}{ $data[1] }    = $data[0];
        }

        shift @data if $prop eq 'ccc';
        next if $data[0] eq "n/a";

        $data[1] =~ tr/ _-//d;
        $utf8::PropValueAlias{$prop}{ lc $data[0] } = $data[1];
        $utf8::PVA_reverse{$prop}{ lc $data[1] }    = $data[0];

        my $abbr_class = ( $prop eq 'gc' or $prop eq 'sc' ) ? 'gc_sc' : $prop;
        $utf8::PVA_abbr_map{$abbr_class}{ lc $data[0] } = $data[0];
    }
    close PVA;

    # backwards compatibility for L& -> LC
    $utf8::PropValueAlias{gc}{'l&'}  = $utf8::PropValueAlias{gc}{lc};
    $utf8::PVA_abbr_map{gc_sc}{'l&'} = $utf8::PVA_abbr_map{gc_sc}{lc};

}

##
## Associates a property ("Greek", "Lu", "Assigned",...) with a Table.
##
## Called like:
##       New_Prop(In => 'Greek', $Table, Desc => 'Greek Block', Fuzzy => 1);
##
## Normally, these parameters are set when the Table is created (when the
## Table->New constructor is called), but there are times when it needs to
## be done after-the-fact...)
##
sub New_Prop($$$@) {
    my $Type  = shift;    ## "Is" or "In";
    my $Name  = shift;
    my $Table = shift;

    ## remaining args are optional key/val
    my %Args = @_;

    my $Fuzzy = delete $Args{Fuzzy};
    my $Desc  = delete $Args{Desc};    # description

    $Name = CanonicalName($Name) if $Fuzzy;

    ## sanity check a few args
    if ( %Args or ( $Type ne 'Is' and $Type ne 'In' ) or not ref $Table ) {
        confess "$0: bad args to New_Prop";
    }

    if ( not $TableInfo{$Type}->{$Name} ) {
        $TableInfo{$Type}->{$Name} = $Table;
        $TableDesc{$Type}->{$Name} = $Desc;
        if ($Fuzzy) {
            $FuzzyNames{$Type}->{$Name} = $Name;
        }
    }
}

##
## Creates a new Table object.
##
## Args are key/value pairs:
##    In => Name         -- Name of "In" property to be associated with
##    Is => Name         -- Name of "Is" property to be associated with
##    Fuzzy => Boolean   -- True if name can be accessed "fuzzily"
##    Desc  => String    -- Description of the property
##
## No args are required.
##
sub Table::New {
    my $class = shift;
    my %Args  = @_;

    my $Table = bless [], $class;

    my $Fuzzy = delete $Args{Fuzzy};
    my $Desc  = delete $Args{Desc};

    for my $Type ( 'Is', 'In' ) {
        if ( my $Name = delete $Args{$Type} ) {
            New_Prop(
                $Type => $Name,
                $Table,
                Desc  => $Desc,
                Fuzzy => $Fuzzy
            );
        }
    }

    ## shouldn't have any left over
    if (%Args) {
        confess "$0: bad args to Table->New";
    }

    return $Table;
}

##
## Returns the maximum code point currently in the table.
##
sub Table::Max {
    my $last = $_[0]->[-1];    ## last code point
    confess "oops" unless $last;    ## must have code points to have a max
    return $last->[RANGE_END];
}

##
## Replaces the codepoints in the Table with those in the Table given
## as an arg. (NOTE: this is not a "deep copy").
##
sub Table::Replace($$) {
    my $Table = shift;              #self
    my $New   = shift;

    @$Table = @$New;
}

##
## Given a new code point, make the last range of the Table extend to
## include the new (and all intervening) code points.
##
## Takes the time to make sure that the extension is valid.
##
sub Table::Extend {
    my $Table     = shift;    #self
    my $codepoint = shift;

    my $PrevMax = $Table->Max;

    confess "oops ($codepoint <= $PrevMax)" if $codepoint <= $PrevMax;

    $Table->ExtendNoCheck($codepoint);
}

##
## Given a new code point, make the last range of the Table extend to
## include the new (and all intervening) code points.
##
## Does NOT check that the extension is valid.  Assumes that the caller
## has already made this check.
##
sub Table::ExtendNoCheck {
    ## Optmized adding: Assumes $Table and $codepoint as parms
    $_[0]->[-1]->[RANGE_END] = $_[1];
}

##
## Given a code point range start and end (and optional name), blindly
## append them to the list of ranges for the Table.
##
## NOTE: Code points must be added in strictly ascending numeric order.
##
sub Table::RawAppendRange {
    my $Table = shift;    #self
    my $start = shift;
    my $end   = shift;
    my $name  = shift;
    $name = "" if not defined $name;    ## warning: $name can be "0"

    push @$Table, [
        $start,                         # RANGE_START
        $end,                           # RANGE_END
        $name
    ];                                  # RANGE_NAME
}

##
## Given a code point (and optional name), add it to the Table.
##
## NOTE: Code points must be added in strictly ascending numeric order.
##
sub Table::Append {
    my $Table     = shift;              #self
    my $codepoint = shift;
    my $name      = shift;
    $name = "" if not defined $name;    ## warning: $name can be "0"

    ##
    ## If we've already got a range working, and this code point is the next
    ## one in line, and if the name is the same, just extend the current range.
    ##
    my $last = $Table->[-1];
    if (    $last
        and $last->[RANGE_END] == $codepoint - 1
        and $last->[RANGE_NAME] eq $name )
    {
        $Table->ExtendNoCheck($codepoint);
    }
    else {
        $Table->RawAppendRange( $codepoint, $codepoint, $name );
    }
}

##
## Given a code point range starting value and ending value (and name),
## Add the range to teh Table.
##
## NOTE: Code points must be added in strictly ascending numeric order.
##
sub Table::AppendRange {
    my $Table = shift;    #self
    my $start = shift;
    my $end   = shift;
    my $name  = shift;
    $name = "" if not defined $name;    ## warning: $name can be "0"

    $Table->Append( $start, $name );
    $Table->Extend($end) if $end > $start;
}

##
## Return a new Table that represents all code points not in the Table.
##
sub Table::Invert {
    my $Table = shift;                  #self

    my $New = Table->New();
    my $max = -1;
    for my $range (@$Table) {
        my $start = $range->[RANGE_START];
        my $end   = $range->[RANGE_END];
        if ( $start - 1 >= $max + 1 ) {
            $New->AppendRange( $max + 1, $start - 1, "" );
        }
        $max = $end;
    }
    if ( $max + 1 < $LastUnicodeCodepoint ) {
        $New->AppendRange( $max + 1, $LastUnicodeCodepoint );
    }
    return $New;
}

##
## Merges any number of other tables with $self, returning the new table.
## (existing tables are not modified)
##
##
## Args may be Tables, or individual code points (as integers).
##
## Can be called as either a constructor or a method.
##
sub Table::Merge {
    shift(@_) if not ref $_[0];  ## if called as a constructor, lose the class
    my @Tables = @_;

    ## Accumulate all records from all tables
    my @Records;
    for my $Arg (@Tables) {
        if ( ref $Arg ) {
            ## arg is a table -- get its ranges
            push @Records, @$Arg;
        }
        else {
            ## arg is a codepoint, make a range
            push @Records, [ $Arg, $Arg ];
        }
    }

    ## sort by range start, with longer ranges coming first.
    my ( $first, @Rest ) = sort {
               ( $a->[RANGE_START] <=> $b->[RANGE_START] )
            or ( $b->[RANGE_END] <=> $b->[RANGE_END] )
    } @Records;

    my $New = Table->New();

    ## Ensuring the first range is there makes the subsequent loop easier
    $New->AppendRange( $first->[RANGE_START], $first->[RANGE_END] );

    ## Fold in records so long as they add new information.
    for my $set (@Rest) {
        my $start = $set->[RANGE_START];
        my $end   = $set->[RANGE_END];
        if ( $start > $New->Max ) {
            $New->AppendRange( $start, $end );
        }
        elsif ( $end > $New->Max ) {
            $New->ExtendNoCheck($end);
        }
    }

    return $New;
}

##
## Given a filename, write a representation of the Table to a file.
## May have an optional comment as a 2nd arg.
## Filename may actually be an arrayref of directories
##
sub Table::Write {
    my $Table    = shift;    #self
    my $filename = shift;
    my $comment  = shift;

    my @OUT = $HEADER;
    if ( defined $comment ) {
        $comment =~ s/\s+\Z//;
        $comment =~ s/^/# /gm;
        push @OUT, "#\n$comment\n#\n";
    }
    push @OUT, "return <<'END';\n";

    for my $set (@$Table) {
        my $start = $set->[RANGE_START];
        my $end   = $set->[RANGE_END];
        my $name  = $set->[RANGE_NAME];

        if ( $start == $end ) {
            push @OUT, sprintf "%04X\t\t%s\n", $start, $name;
        }
        else {
            push @OUT, sprintf "%04X\t%04X\t%s\n", $start, $end, $name;
        }
    }

    push @OUT, "END\n";

    WriteIfChanged( $filename, @OUT );
}

## This used only for making the test script.
## helper function
sub IsUsable($) {
    my $code = shift;
    return 0 if $code <= 0x0000;                            ## don't use null
    return 0 if $code >= $LastUnicodeCodepoint;             ## keep in range
    return 0 if ( $code >= 0xD800 and $code <= 0xDFFF );    ## no surrogates
    return 0
        if ( $code >= 0xFDD0 and $code <= 0xFDEF );    ## utf8.c says no good
    return 0 if ( ( $code & 0xFFFF ) == 0xFFFE );      ## utf8.c says no good
    return 0 if ( ( $code & 0xFFFF ) == 0xFFFF );      ## utf8.c says no good
    return 1;
}

## Return a code point that's part of the table.
## Returns nothing if the table is empty (or covers only surrogates).
## This used only for making the test script.
sub Table::ValidCode {
    my $Table = shift;                                 #self
    for my $set (@$Table) {
        return $set->[RANGE_END] if IsUsable( $set->[RANGE_END] );
    }
    return ();
}

## Return a code point that's not part of the table
## Returns nothing if the table covers all code points.
## This used only for making the test script.
sub Table::InvalidCode {
    my $Table = shift;                                 #self

    return 0x1234 if not @$Table;

    for my $set (@$Table) {
        if ( IsUsable( $set->[RANGE_END] + 1 ) ) {
            return $set->[RANGE_END] + 1;
        }

        if ( IsUsable( $set->[RANGE_START] - 1 ) ) {
            return $set->[RANGE_START] - 1;
        }
    }
    return ();
}

###########################################################################
###########################################################################
###########################################################################

##
## Called like:
##     New_Alias(Is => 'All', SameAs => 'Any', Fuzzy => 1);
##
## The args must be in that order, although the Fuzzy pair may be omitted.
##
## This creates 'IsAll' as an alias for 'IsAny'
##
sub New_Alias($$$@) {
    my $Type   = shift;    ## "Is" or "In"
    my $Alias  = shift;
    my $SameAs = shift;    # expecting "SameAs" -- just ignored
    my $Name   = shift;

    ## remaining args are optional key/val
    my %Args = @_;

    my $Fuzzy = delete $Args{Fuzzy};

    ## sanity check a few args
    if ( %Args or ( $Type ne 'Is' and $Type ne 'In' ) or $SameAs ne 'SameAs' )
    {
        confess "$0: bad args to New_Alias";
    }

    $Alias = CanonicalName($Alias) if $Fuzzy;

    if ( not $TableInfo{$Type}->{$Name} ) {
        my $CName = CanonicalName($Name);
        if ( $TableInfo{$Type}->{$CName} ) {
            confess
                "$0: Use canonical form '$CName' instead of '$Name' for alias.";
        }
        else {
            confess "$0: don't have original $Type => $Name to make alias\n";
        }
    }
    if ( $TableInfo{$Alias} ) {
        confess "$0: already have original $Type => $Alias; can't make alias";
    }
    $AliasInfo{$Type}->{$Name} = $Alias;
    if ($Fuzzy) {
        $FuzzyNames{$Type}->{$Alias} = $Name;
    }

}

## All assigned code points
my $Assigned = Table->New(
    Is    => 'Assigned',
    Desc  => "All assigned code points",
    Fuzzy => 0
);

my $Name    = Table->New();    ## all characters, individually by name
my $General = Table->New();    ## all characters, grouped by category
my %General;
my %Cat;

## Simple Data::Dumper alike. Good enough for our needs. We can't use the real
## thing as we have to run under miniperl
sub simple_dumper {
    my @lines;
    my $item;
    foreach $item (@_) {
        if ( ref $item ) {
            if ( ref $item eq 'ARRAY' ) {
                push @lines, "[\n", simple_dumper(@$item), "],\n";
            }
            elsif ( ref $item eq 'HASH' ) {
                push @lines, "{\n", simple_dumper(%$item), "},\n";
            }
            else {
                die "Can't cope with $item";
            }
        }
        else {
            if ( defined $item ) {
                my $copy = $item;
                $copy =~ s/([\'\\])/\\$1/gs;
                push @lines, "'$copy',\n";
            }
            else {
                push @lines, "undef,\n";
            }
        }
    }
    @lines;
}

##
## Process UnicodeData.txt (Categories, etc.)
##
sub UnicodeData_Txt() {
    my $Bidi     = Table->New();
    my $Deco     = Table->New();
    my $Comb     = Table->New();
    my $Number   = Table->New();
    my $Mirrored = Table->New();   #Is    => 'Mirrored',
                                   #Desc  => "Mirrored in bidirectional text",
                                   #Fuzzy => 0);

    my %DC;
    my %Bidi;
    my %Number;
    $DC{can} = Table->New();
    $DC{com} = Table->New();

    ## Initialize Perl-generated categories
    ## (Categories from UnicodeData.txt are auto-initialized in gencat)
    $Cat{Alnum}
        = Table->New( Is => 'Alnum', Desc => "[[:Alnum:]]", Fuzzy => 0 );
    $Cat{Alpha}
        = Table->New( Is => 'Alpha', Desc => "[[:Alpha:]]", Fuzzy => 0 );
    $Cat{ASCII}
        = Table->New( Is => 'ASCII', Desc => "[[:ASCII:]]", Fuzzy => 0 );
    $Cat{Blank}
        = Table->New( Is => 'Blank', Desc => "[[:Blank:]]", Fuzzy => 0 );
    $Cat{Cntrl}
        = Table->New( Is => 'Cntrl', Desc => "[[:Cntrl:]]", Fuzzy => 0 );
    $Cat{Digit}
        = Table->New( Is => 'Digit', Desc => "[[:Digit:]]", Fuzzy => 0 );
    $Cat{Graph}
        = Table->New( Is => 'Graph', Desc => "[[:Graph:]]", Fuzzy => 0 );
    $Cat{Lower}
        = Table->New( Is => 'Lower', Desc => "[[:Lower:]]", Fuzzy => 0 );
    $Cat{Print}
        = Table->New( Is => 'Print', Desc => "[[:Print:]]", Fuzzy => 0 );
    $Cat{Punct}
        = Table->New( Is => 'Punct', Desc => "[[:Punct:]]", Fuzzy => 0 );
    $Cat{Space}
        = Table->New( Is => 'Space', Desc => "[[:Space:]]", Fuzzy => 0 );
    $Cat{Title}
        = Table->New( Is => 'Title', Desc => "[[:Title:]]", Fuzzy => 0 );
    $Cat{Upper}
        = Table->New( Is => 'Upper', Desc => "[[:Upper:]]", Fuzzy => 0 );
    $Cat{XDigit}
        = Table->New( Is => 'XDigit', Desc => "[[:XDigit:]]", Fuzzy => 0 );
    $Cat{Word} = Table->New( Is => 'Word', Desc => "[[:Word:]]", Fuzzy => 0 );
    $Cat{SpacePerl}
        = Table->New( Is => 'SpacePerl', Desc => '\s', Fuzzy => 0 );
    $Cat{VertSpace}
        = Table->New( Is => 'VertSpace', Desc => '\v', Fuzzy => 0 );
    $Cat{HorizSpace}
        = Table->New( Is => 'HorizSpace', Desc => '\h', Fuzzy => 0 );
    my %To;
    $To{Upper} = Table->New();
    $To{Lower} = Table->New();
    $To{Title} = Table->New();
    $To{Digit} = Table->New();

    sub gencat($$$$) {
        my ($name,    ## Name ("LATIN CAPITAL LETTER A")
            $cat,     ## Category ("Lu", "Zp", "Nd", etc.)
            $code,    ## Code point (as an integer)
            $op
        ) = @_;

        my $MajorCat = substr( $cat, 0, 1 );    ## L, M, Z, S, etc

        $Assigned->$op($code);
        $Name->$op( $code, $name );
        $General->$op( $code, $cat );

        ## add to the sub category (e.g. "Lu", "Nd", "Cf", ..)
        $Cat{$cat} ||= Table->New(
            Is    => $cat,
            Desc  => "General Category '$cat'",
            Fuzzy => 0
        );
        $Cat{$cat}->$op($code);

        ## add to the major category (e.g. "L", "N", "C", ...)
        $Cat{$MajorCat} ||= Table->New(
            Is    => $MajorCat,
            Desc  => "Major Category '$MajorCat'",
            Fuzzy => 0
        );
        $Cat{$MajorCat}->$op($code);

        ( $General{$name} ||= Table->New )->$op( $code, $name );

        # 005F: SPACING UNDERSCORE
        $Cat{Word}->$op($code)  if $cat =~ /^[LMN]|Pc/;
        $Cat{Alnum}->$op($code) if $cat =~ /^[LM]|Nd/;
        $Cat{Alpha}->$op($code) if $cat =~ /^[LM]/;

        my $isspace
            = (    $cat =~ /Zs|Zl|Zp/
                && $code
                != 0x200B )    # 200B is ZWSP which is for line break control
              # and therefore it is not part of "space" even while it is "Zs".
            || $code == 0x0009    # 0009: HORIZONTAL TAB
            || $code == 0x000A    # 000A: LINE FEED
            || $code == 0x000B    # 000B: VERTICAL TAB
            || $code == 0x000C    # 000C: FORM FEED
            || $code == 0x000D    # 000D: CARRIAGE RETURN
            || $code == 0x0085    # 0085: NEL

            ;

        $Cat{Space}->$op($code) if $isspace;

        $Cat{SpacePerl}->$op($code)
            if $isspace
                && $code != 0x000B;    # Backward compat.

        $Cat{VertSpace}->$op($code)
            if grep { $code == $_ } ( 0x0A .. 0x0D, 0x85, 0x2028, 0x2029 );

        $Cat{HorizSpace}->$op($code)
            if grep { $code == $_ } (
            0x09,   0x20,   0xa0,   0x1680, 0x180e, 0x2000, 0x2001, 0x2002,
            0x2003, 0x2004, 0x2005, 0x2006, 0x2007, 0x2008, 0x2009, 0x200a,
            0x202f, 0x205f, 0x3000
            );

        $Cat{Blank}->$op($code)
            if $isspace
                && !(
                       $code == 0x000A
                    || $code == 0x000B
                    || $code == 0x000C
                    || $code == 0x000D
                    || $code == 0x0085
                    || $cat =~ /^Z[lp]/
                );

        $Cat{Digit}->$op($code) if $cat eq "Nd";
        $Cat{Upper}->$op($code) if $cat eq "Lu";
        $Cat{Lower}->$op($code) if $cat eq "Ll";
        $Cat{Title}->$op($code) if $cat eq "Lt";
        $Cat{ASCII}->$op($code) if $code <= 0x007F;
        $Cat{Cntrl}->$op($code) if $cat =~ /^C/;
        my $isgraph = !$isspace && $cat !~ /Cc|Cs|Cn/;
        $Cat{Graph}->$op($code) if $isgraph;
        $Cat{Print}->$op($code) if $isgraph || $isspace;
        $Cat{Punct}->$op($code) if $cat =~ /^P/;

        $Cat{XDigit}->$op($code) if ( $code >= 0x30 && $code <= 0x39 ) ## 0..9
            || ( $code >= 0x41 && $code <= 0x46 )                      ## A..F
            || ( $code >= 0x61 && $code <= 0x66 );                     ## a..f
    }

    ## open ane read file.....
    if ( not open IN, "UnicodeData.txt" ) {
        die "$0: UnicodeData.txt: $!\n";
    }

    ##
    ## For building \p{_CombAbove} and \p{_CanonDCIJ}
    ##
    my %_Above_HexCodes;    ## Hexcodes for chars with $comb == 230 ("ABOVE")

    my %CodeToDeco;         ## Maps code to decomp. list for chars with first
    ## decomp. char an "i" or "j" (for \p{_CanonDCIJ})

    ## This is filled in as we go....
    my $CombAbove = Table->New(
        Is    => '_CombAbove',
        Desc  => '(for internal casefolding use)',
        Fuzzy => 0
    );

    while (<IN>) {
        next unless /^[0-9A-Fa-f]+;/;
        s/\s+$//;

        my ($hexcode,      ## code point in hex (e.g. "0041")
            $name,         ## character name (e.g. "LATIN CAPITAL LETTER A")
            $cat,          ## category (e.g. "Lu")
            $comb,         ## Canonical combining class (e.t. "230")
            $bidi,         ## directional category (e.g. "L")
            $deco,         ## decomposition mapping
            $decimal,      ## decimal digit value
            $digit,        ## digit value
            $number,       ## numeric value
            $mirrored,     ## mirrored
            $unicode10,    ## name in Unicode 1.0
            $comment,      ## comment field
            $upper,        ## uppercase mapping
            $lower,        ## lowercase mapping
            $title,        ## titlecase mapping
        ) = split(/\s*;\s*/);

        # Note that in Unicode 3.2 there will be names like
        # LINE FEED (LF), which probably means that \N{} needs
        # to cope also with LINE FEED and LF.
        $name = $unicode10 if $name eq '<control>' && $unicode10 ne '';

        my $code = hex($hexcode);

        if ( $comb and $comb == 230 ) {
            $CombAbove->Append($code);
            $_Above_HexCodes{$hexcode} = 1;
        }

        ## Used in building \p{_CanonDCIJ}
        if ( $deco and $deco =~ m/^006[9A]\b/ ) {
            $CodeToDeco{$code} = $deco;
        }

        ##
        ## There are a few pairs of lines like:
        ##   AC00;<Hangul Syllable, First>;Lo;0;L;;;;;N;;;;;
        ##   D7A3;<Hangul Syllable, Last>;Lo;0;L;;;;;N;;;;;
        ## that define ranges.
        ##
        if ( $name =~ /^<(.+), (First|Last)>$/ ) {
            $name = $1;
            gencat( $name, $cat, $code, $2 eq 'First' ? 'Append' : 'Extend' );

            #New_Prop(In => $name, $General{$name}, Fuzzy => 1);
        }
        else {
            ## normal (single-character) lines
            gencat( $name, $cat, $code, 'Append' );

            # No Append() here since since several codes may map into one.
            $To{Upper}->RawAppendRange( $code, $code, $upper ) if $upper;
            $To{Lower}->RawAppendRange( $code, $code, $lower ) if $lower;
            $To{Title}->RawAppendRange( $code, $code, $title ) if $title;
            $To{Digit}->Append( $code, $decimal ) if length $decimal;

            $Bidi->Append( $code, $bidi );
            $Comb->Append( $code, $comb ) if $comb;
            $Number->Append( $code, $number ) if length $number;

            length($decimal)
                and ( $Number{De} ||= Table->New() )->Append($code)
                or length($digit)
                and ( $Number{Di} ||= Table->New() )->Append($code)
                or length($number)
                and ( $Number{Nu} ||= Table->New() )->Append($code);

            $Mirrored->Append($code) if $mirrored eq "Y";

            $Bidi{$bidi} ||= Table->New();    #Is    => "bt/$bidi",
                 #Desc  => "Bi-directional category '$bidi'",
                 #Fuzzy => 0);
            $Bidi{$bidi}->Append($code);

            if ($deco) {
                $Deco->Append( $code, $deco );
                if ( $deco =~ /^<(\w+)>/ ) {
                    my $dshort = $PVA_reverse{dt}{ ucfirst lc $1 };
                    $DC{com}->Append($code);

                    $DC{$dshort} ||= Table->New();
                    $DC{$dshort}->Append($code);
                }
                else {
                    $DC{can}->Append($code);
                }
            }
        }
    }
    close IN;

    ##
    ## Tidy up a few special cases....
    ##

    $Cat{Cn} = $Assigned->Invert;    ## Cn is everything that doesn't exist
    New_Prop(
        Is => 'Cn',
        $Cat{Cn},
        Desc  => "General Category 'Cn' [not functional in Perl]",
        Fuzzy => 0
    );

    ## Unassigned is the same as 'Cn'
    New_Alias( Is => 'Unassigned', SameAs => 'Cn', Fuzzy => 0 );

    $Cat{C}->Replace( $Cat{C}->Merge( $Cat{Cn} ) );  ## Now merge in Cn into C

    # LC is Ll, Lu, and Lt.
    # (used to be L& or L_, but PropValueAliases.txt defines it as LC)
    New_Prop(
        Is => 'LC',
        Table->Merge( @Cat{qw[Ll Lu Lt]} ),
        Desc  => '[\p{Ll}\p{Lu}\p{Lt}]',
        Fuzzy => 0
    );

    ## Any and All are all code points.
    my $Any = Table->New(
        Is    => 'Any',
        Desc  => sprintf( "[\\x{0000}-\\x{%X}]", $LastUnicodeCodepoint ),
        Fuzzy => 0
    );
    $Any->RawAppendRange( 0, $LastUnicodeCodepoint );

    New_Alias( Is => 'All', SameAs => 'Any', Fuzzy => 0 );

    ##
    ## Build special properties for Perl's internal case-folding needs:
    ##    \p{_CaseIgnorable}
    ##    \p{_CanonDCIJ}
    ##    \p{_CombAbove}
    ## _CombAbove was built above. Others are built here....
    ##

    ## \p{_CaseIgnorable} is [\p{Mn}\0x00AD\x2010]
    New_Prop(
        Is => '_CaseIgnorable',
        Table->Merge(
            $Cat{Mn},
            0x00AD,    #SOFT HYPHEN
            0x2010
        ),             #HYPHEN
        Desc  => '(for internal casefolding use)',
        Fuzzy => 0
    );

    ## \p{_CanonDCIJ} is fairly complex...
    my $CanonCDIJ = Table->New(
        Is    => '_CanonDCIJ',
        Desc  => '(for internal casefolding use)',
        Fuzzy => 0
    );
    ## It contains the ASCII 'i' and 'j'....
    $CanonCDIJ->Append(0x0069);    # ASCII ord("i")
    $CanonCDIJ->Append(0x006A);    # ASCII ord("j")
    ## ...and any character with a decomposition that starts with either of
    ## those code points, but only if the decomposition does not have any
    ## combining character with the "ABOVE" canonical combining class.
    for my $code ( sort { $a <=> $b } keys %CodeToDeco ) {
        ## Need to ensure that all decomposition characters do not have
        ## a %HexCodeToComb in %AboveCombClasses.
        my $want = 1;
        for my $deco_hexcode ( split / /, $CodeToDeco{$code} ) {
            if ( exists $_Above_HexCodes{$deco_hexcode} ) {
                ## one of the decmposition chars has an ABOVE combination
                ## class, so we're not interested in this one
                $want = 0;
                last;
            }
        }
        if ($want) {
            $CanonCDIJ->Append($code);
        }
    }

    ##
    ## Now dump the files.
    ##
    $Name->Write("Name.pl");

    {
        my @PVA = $HEADER;
        foreach my $name (
            qw (PropertyAlias PA_reverse PropValueAlias
            PVA_reverse PVA_abbr_map)
            )
        {

            # Should I really jump through typeglob hoops just to avoid a
            # symbolic reference? (%{"utf8::$name})
            push @PVA, "\n", "\%utf8::$name = (\n",
                simple_dumper( %{ $utf8::{$name} } ), ");\n";
        }
        push @PVA, "1;\n";
        WriteIfChanged( "PVA.pl", @PVA );
    }

    # $Bidi->Write("Bidirectional.pl");
    for ( keys %Bidi ) {
        $Bidi{$_}->Write( [ "lib", "bc", "$_.pl" ],
            "BidiClass category '$PropValueAlias{bc}{$_}'" );
    }

    $Comb->Write("CombiningClass.pl");
    for ( keys %{ $PropValueAlias{ccc} } ) {
        my ( $code, $name ) = @{ $PropValueAlias{ccc}{$_} };
        ( my $c = Table->New() )->Append($code);
        $c->Write( [ "lib", "ccc", "$_.pl" ],
            "CombiningClass category '$name'" );
    }

    $Deco->Write("Decomposition.pl");
    for ( keys %DC ) {
        $DC{$_}->Write( [ "lib", "dt", "$_.pl" ],
            "DecompositionType category '$PropValueAlias{dt}{$_}'" );
    }

    # $Number->Write("Number.pl");
    for ( keys %Number ) {
        $Number{$_}->Write( [ "lib", "nt", "$_.pl" ],
            "NumericType category '$PropValueAlias{nt}{$_}'" );
    }

    # $General->Write("Category.pl");

    for my $to ( sort keys %To ) {
        $To{$to}->Write( [ "To", "$to.pl" ] );
    }

    for ( keys %{ $PropValueAlias{gc} } ) {
        New_Alias( Is => $PropValueAlias{gc}{$_}, SameAs => $_, Fuzzy => 1 );
    }
}

##
## Process LineBreak.txt
##
sub LineBreak_Txt() {
    if ( not open IN, "LineBreak.txt" ) {
        die "$0: LineBreak.txt: $!\n";
    }

    my $Lbrk = Table->New();
    my %Lbrk;

    while (<IN>) {
        next unless /^([0-9A-Fa-f]+)(?:\.\.([0-9A-Fa-f]+))?\s*;\s*(\w+)/;

        my ( $first, $last, $lbrk ) = ( hex($1), hex( $2 || "" ), $3 );

        $Lbrk->Append( $first, $lbrk );

        $Lbrk{$lbrk} ||= Table->New();
        $Lbrk{$lbrk}->Append($first);

        if ($last) {
            $Lbrk->Extend($last);
            $Lbrk{$lbrk}->Extend($last);
        }
    }
    close IN;

    # $Lbrk->Write("Lbrk.pl");

    for ( keys %Lbrk ) {
        $Lbrk{$_}->Write( [ "lib", "lb", "$_.pl" ],
            "Linebreak category '$PropValueAlias{lb}{$_}'" );
    }
}

##
## Process ArabicShaping.txt.
##
sub ArabicShaping_txt() {
    if ( not open IN, "ArabicShaping.txt" ) {
        die "$0: ArabicShaping.txt: $!\n";
    }

    my $ArabLink      = Table->New();
    my $ArabLinkGroup = Table->New();

    my %JoinType;

    while (<IN>) {
        next unless /^[0-9A-Fa-f]+;/;
        s/\s+$//;

        my ( $hexcode, $name, $link, $linkgroup ) = split(/\s*;\s*/);
        my $code = hex($hexcode);
        $ArabLink->Append( $code, $link );
        $ArabLinkGroup->Append( $code, $linkgroup );

        $JoinType{$link} ||= Table->New( Is => "JoinType$link" );
        $JoinType{$link}->Append($code);
    }
    close IN;

    # $ArabLink->Write("ArabLink.pl");
    # $ArabLinkGroup->Write("ArabLnkGrp.pl");

    for ( keys %JoinType ) {
        $JoinType{$_}->Write( [ "lib", "jt", "$_.pl" ],
            "JoiningType category '$PropValueAlias{jt}{$_}'" );
    }
}

##
## Process EastAsianWidth.txt.
##
sub EastAsianWidth_txt() {
    if ( not open IN, "EastAsianWidth.txt" ) {
        die "$0: EastAsianWidth.txt: $!\n";
    }

    my %EAW;

    while (<IN>) {
        next unless /^[0-9A-Fa-f]+(\.\.[0-9A-Fa-f]+)?;/;
        s/#.*//;
        s/\s+$//;

        my ( $hexcodes, $pv ) = split(/\s*;\s*/);
        $EAW{$pv} ||= Table->New( Is => "EastAsianWidth$pv" );
        my ( $start, $end ) = split( /\.\./, $hexcodes );
        if ( defined $end ) {
            $EAW{$pv}->AppendRange( hex($start), hex($end) );
        }
        else {
            $EAW{$pv}->Append( hex($start) );
        }
    }
    close IN;

    for ( keys %EAW ) {
        $EAW{$_}->Write( [ "lib", "ea", "$_.pl" ],
            "EastAsianWidth category '$PropValueAlias{ea}{$_}'" );
    }
}

##
## Process HangulSyllableType.txt.
##
sub HangulSyllableType_txt() {
    if ( not open IN, "HangulSyllableType.txt" ) {
        die "$0: HangulSyllableType.txt: $!\n";
    }

    my %HST;

    while (<IN>) {
        next unless /^([0-9A-Fa-f]+)(?:\.\.([0-9A-Fa-f]+))?\s*;\s*(\w+)/;
        my ( $first, $last, $pv ) = ( hex($1), hex( $2 || "" ), $3 );

        $HST{$pv} ||= Table->New( Is => "HangulSyllableType$pv" );
        $HST{$pv}->Append($first);

        if ($last) { $HST{$pv}->Extend($last) }
    }
    close IN;

    for ( keys %HST ) {
        $HST{$_}->Write( [ "lib", "hst", "$_.pl" ],
            "HangulSyllableType category '$PropValueAlias{hst}{$_}'" );
    }
}

##
## Process Jamo.txt.
##
sub Jamo_txt() {
    if ( not open IN, "Jamo.txt" ) {
        die "$0: Jamo.txt: $!\n";
    }
    my $Short = Table->New();

    while (<IN>) {
        next unless /^([0-9A-Fa-f]+)\s*;\s*(\w*)/;
        my ( $code, $short ) = ( hex($1), $2 );

        $Short->Append( $code, $short );
    }
    close IN;

    # $Short->Write("JamoShort.pl");
}

##
## Process Scripts.txt.
##
sub Scripts_txt() {
    my @ScriptInfo;

    if ( not open( IN, "Scripts.txt" ) ) {
        die "$0: Scripts.txt: $!\n";
    }
    while (<IN>) {
        next unless /^([0-9A-Fa-f]+)(?:\.\.([0-9A-Fa-f]+))?\s*;\s*(.+?)\s*\#/;

        # Wait until all the scripts have been read since
        # they are not listed in numeric order.
        push @ScriptInfo, [ hex($1), hex( $2 || "" ), $3 ];
    }
    close IN;

    # Now append the scripts properties in their code point order.

    my %Script;
    my $Scripts = Table->New();

    for my $script ( sort { $a->[0] <=> $b->[0] } @ScriptInfo ) {
        my ( $first, $last, $name ) = @$script;
        $Scripts->Append( $first, $name );

        $Script{$name} ||= Table->New(
            Is    => $name,
            Desc  => "Script '$name'",
            Fuzzy => 1
        );
        $Script{$name}->Append( $first, $name );

        if ($last) {
            $Scripts->Extend($last);
            $Script{$name}->Extend($last);
        }
    }

    # $Scripts->Write("Scripts.pl");

    ## Common is everything not explicitly assigned to a Script
    ##
    ##    ***shouldn't this be intersected with \p{Assigned}? ******
    ##
    New_Prop(
        Is => 'Common',
        $Scripts->Invert,
        Desc  => 'Pseudo-Script of codepoints not in other Unicode scripts',
        Fuzzy => 1
    );
}

##
## Given a name like "Close Punctuation", return a regex (that when applied
## with /i) matches any valid form of that name (e.g. "ClosePunctuation",
## "Close-Punctuation", etc.)
##
## Accept any space, dash, or underbar where in the official name there is
## space or a dash (or underbar, but there never is).
##
##
sub NameToRegex($) {
    my $Name = shift;
    $Name =~ s/[- _]/(?:[-_]|\\s+)?/g;
    return $Name;
}

##
## Process Blocks.txt.
##
sub Blocks_txt() {
    my $Blocks = Table->New();
    my %Blocks;

    if ( not open IN, "Blocks.txt" ) {
        die "$0: Blocks.txt: $!\n";
    }

    while (<IN>) {

        #next if not /Private Use$/;
        next if not /^([0-9A-Fa-f]+)\.\.([0-9A-Fa-f]+)\s*;\s*(.+?)\s*$/;

        my ( $first, $last, $name ) = ( hex($1), hex($2), $3 );

        $Blocks->Append( $first, $name );

        $Blocks{$name} ||= Table->New(
            In    => $name,
            Desc  => "Block '$name'",
            Fuzzy => 1
        );
        $Blocks{$name}->Append( $first, $name );

        if ( $last and $last != $first ) {
            $Blocks->Extend($last);
            $Blocks{$name}->Extend($last);
        }
    }
    close IN;

    $Blocks->Write("Blocks.pl");
}

##
## Read in the PropList.txt.  It contains extended properties not
## listed in the UnicodeData.txt, such as 'Other_Alphabetic':
## alphabetic but not of the general category L; many modifiers
## belong to this extended property category: while they are not
## alphabets, they are alphabetic in nature.
##
sub PropList_txt() {
    my @PropInfo;

    if ( not open IN, "PropList.txt" ) {
        die "$0: PropList.txt: $!\n";
    }

    while (<IN>) {
        next unless /^([0-9A-Fa-f]+)(?:\.\.([0-9A-Fa-f]+))?\s*;\s*(.+?)\s*\#/;

        # Wait until all the extended properties have been read since
        # they are not listed in numeric order.
        push @PropInfo, [ hex($1), hex( $2 || "" ), $3 ];
    }
    close IN;

    # Now append the extended properties in their code point order.
    my $Props = Table->New();
    my %Prop;

    for my $prop ( sort { $a->[0] <=> $b->[0] } @PropInfo ) {
        my ( $first, $last, $name ) = @$prop;
        $Props->Append( $first, $name );

        $Prop{$name} ||= Table->New(
            Is    => $name,
            Desc  => "Extended property '$name'",
            Fuzzy => 1
        );
        $Prop{$name}->Append( $first, $name );

        if ($last) {
            $Props->Extend($last);
            $Prop{$name}->Extend($last);
        }
    }

    for ( keys %Prop ) {
        ( my $file = $PA_reverse{$_} ) =~ tr/_//d;

        # XXX I'm assuming that the names from %Prop don't suffer 8.3 clashes.
        $BaseNames{ lc $file }++;
        $Prop{$_}
            ->Write( [ "lib", "gc_sc", "$file.pl" ], "Binary property '$_'" );
    }

    # Alphabetic is L, Nl, and Other_Alphabetic.
    New_Prop(
        Is => 'Alphabetic',
        Table->Merge( $Cat{L}, $Cat{Nl}, $Prop{Other_Alphabetic} ),
        Desc  => '[\p{L}\p{Nl}\p{OtherAlphabetic}]',    # canonical names
        Fuzzy => 1
    );

    # Lowercase is Ll and Other_Lowercase.
    New_Prop(
        Is => 'Lowercase',
        Table->Merge( $Cat{Ll}, $Prop{Other_Lowercase} ),
        Desc  => '[\p{Ll}\p{OtherLowercase}]',          # canonical names
        Fuzzy => 1
    );

    # Uppercase is Lu and Other_Uppercase.
    New_Prop(
        Is => 'Uppercase',
        Table->Merge( $Cat{Lu}, $Prop{Other_Uppercase} ),
        Desc  => '[\p{Lu}\p{OtherUppercase}]',          # canonical names
        Fuzzy => 1
    );

    # Math is Sm and Other_Math.
    New_Prop(
        Is => 'Math',
        Table->Merge( $Cat{Sm}, $Prop{Other_Math} ),
        Desc  => '[\p{Sm}\p{OtherMath}]',               # canonical names
        Fuzzy => 1
    );

    # ID_Start is Ll, Lu, Lt, Lm, Lo, Nl, and Other_ID_Start.
    New_Prop(
        Is => 'ID_Start',
        Table->Merge( @Cat{qw[Ll Lu Lt Lm Lo Nl]}, $Prop{Other_ID_Start} ),
        Desc  => '[\p{Ll}\p{Lu}\p{Lt}\p{Lm}\p{Lo}\p{Nl}\p{OtherIDStart}]',
        Fuzzy => 1
    );

    # ID_Continue is ID_Start, Mn, Mc, Nd, Pc, and Other_ID_Continue.
    New_Prop(
        Is => 'ID_Continue',
        Table->Merge(
            @Cat{qw[Ll Lu Lt Lm Lo Nl Mn Mc Nd Pc ]},
            @Prop{qw[Other_ID_Start Other_ID_Continue]}
        ),
        Desc  => '[\p{ID_Start}\p{Mn}\p{Mc}\p{Nd}\p{Pc}\p{OtherIDContinue}]',
        Fuzzy => 1
    );

    # Default_Ignorable_Code_Point = Other_Default_Ignorable_Code_Point
    #                     + Cf + Cc + Cs + Noncharacter + Variation_Selector
    #                     - WhiteSpace - FFF9..FFFB (Annotation Characters)

    my $Annotation = Table->New();
    $Annotation->RawAppendRange( 0xFFF9, 0xFFFB );

    New_Prop(
        Is => 'Default_Ignorable_Code_Point',
        Table->Merge(
            @Cat{qw[Cf Cc Cs]},
            $Prop{Noncharacter_Code_Point},
            $Prop{Variation_Selector},
            $Prop{Other_Default_Ignorable_Code_Point}
            )->Invert->Merge( $Prop{White_Space}, $Annotation )->Invert,
        Desc => '(?![\p{WhiteSpace}\x{FFF9}-\x{FFFB}])[\p{Cf}\p{Cc}'
            . '\p{Cs}\p{NoncharacterCodePoint}\p{VariationSelector}'
            . '\p{OtherDefaultIgnorableCodePoint}]',
        Fuzzy => 1
    );

}

##
## These are used in:
##   MakePropTestScript()
##   WriteAllMappings()
## for making the test script.
##
my %FuzzyNameToTest;
my %ExactNameToTest;

## This used only for making the test script
sub GenTests($$$$) {
    my $FH        = shift;
    my $Prop      = shift;
    my $MatchCode = shift;
    my $FailCode  = shift;

    if ( defined $MatchCode ) {
        printf $FH qq/Expect(1, "\\x{%04X}", '\\p{$Prop}' );\n/, $MatchCode;
        printf $FH qq/Expect(0, "\\x{%04X}", '\\p{^$Prop}');\n/, $MatchCode;
        printf $FH qq/Expect(0, "\\x{%04X}", '\\P{$Prop}' );\n/, $MatchCode;
        printf $FH qq/Expect(1, "\\x{%04X}", '\\P{^$Prop}');\n/, $MatchCode;
    }
    if ( defined $FailCode ) {
        printf $FH qq/Expect(0, "\\x{%04X}", '\\p{$Prop}' );\n/, $FailCode;
        printf $FH qq/Expect(1, "\\x{%04X}", '\\p{^$Prop}');\n/, $FailCode;
        printf $FH qq/Expect(1, "\\x{%04X}", '\\P{$Prop}' );\n/, $FailCode;
        printf $FH qq/Expect(0, "\\x{%04X}", '\\P{^$Prop}');\n/, $FailCode;
    }
}

## This used only for making the test script
sub ExpectError($$) {
    my $FH   = shift;
    my $prop = shift;

    print $FH qq/Error('\\p{$prop}');\n/;
    print $FH qq/Error('\\P{$prop}');\n/;
}

## This used only for making the test script
my @GoodSeps = ( " ", "-", " \t ", "", "", "_", );
my @BadSeps = ( "--", "__", " _", "/" );

## This used only for making the test script
sub RandomlyFuzzifyName($;$) {
    my $Name      = shift;
    my $WantError = shift;    ## if true, make an error

    my @parts;
    for my $part ( split /[-\s_]+/, $Name ) {
        if (@parts) {
            if ( $WantError and rand() < 0.3 ) {
                push @parts, $BadSeps[ rand(@BadSeps) ];
                $WantError = 0;
            }
            else {
                push @parts, $GoodSeps[ rand(@GoodSeps) ];
            }
        }
        my $switch = int rand(4);
        if ( $switch == 0 ) {
            push @parts, uc $part;
        }
        elsif ( $switch == 1 ) {
            push @parts, lc $part;
        }
        elsif ( $switch == 2 ) {
            push @parts, ucfirst $part;
        }
        else {
            push @parts, $part;
        }
    }
    my $new = join( '', @parts );

    if ($WantError) {
        if ( rand() >= 0.5 ) {
            $new .= $BadSeps[ rand(@BadSeps) ];
        }
        else {
            $new = $BadSeps[ rand(@BadSeps) ] . $new;
        }
    }
    return $new;
}

## This used only for making the test script
sub MakePropTestScript() {
    ## this written directly -- it's huge.
    force_unlink("TestProp.pl");
    if ( not open OUT, ">TestProp.pl" ) {
        die "$0: TestProp.pl: $!\n";
    }
    print OUT <DATA>;

    while ( my ( $Name, $Table ) = each %ExactNameToTest ) {
        GenTests( *OUT, $Name, $Table->ValidCode, $Table->InvalidCode );
        ExpectError( *OUT, uc $Name ) if uc $Name ne $Name;
        ExpectError( *OUT, lc $Name ) if lc $Name ne $Name;
    }

    while ( my ( $Name, $Table ) = each %FuzzyNameToTest ) {
        my $Orig  = $CanonicalToOrig{$Name};
        my %Names = (
            $Name                      => 1,
            $Orig                      => 1,
            RandomlyFuzzifyName($Orig) => 1
        );

        for my $N ( keys %Names ) {
            GenTests( *OUT, $N, $Table->ValidCode, $Table->InvalidCode );
        }

        ExpectError( *OUT, RandomlyFuzzifyName( $Orig, 'ERROR' ) );
    }

    print OUT "Finished();\n";
    close OUT;
}

##
## These are used only in:
##   RegisterFileForName()
##   WriteAllMappings()
##
my %Exact;        ## will become %utf8::Exact;
my %Canonical;    ## will become %utf8::Canonical;
my %CaComment;    ## Comment for %Canonical entry of same key

##
## Given info about a name and a datafile that it should be associated with,
## register that assocation in %Exact and %Canonical.
sub RegisterFileForName($$$$) {
    my $Type     = shift;
    my $Name     = shift;
    my $IsFuzzy  = shift;
    my $filename = shift;

    ##
    ## Now in details for the mapping. $Type eq 'Is' has the
    ## Is removed, as it will be removed in utf8_heavy when this
    ## data is being checked. In keeps its "In", but a second
    ## sans-In record is written if it doesn't conflict with
    ## anything already there.
    ##
    if ( not $IsFuzzy ) {
        if ( $Type eq 'Is' ) {
            die "oops[$Name]" if $Exact{$Name};
            $Exact{$Name} = $filename;
        }
        else {
            die "oops[$Type$Name]" if $Exact{"$Type$Name"};
            $Exact{"$Type$Name"} = $filename;
            $Exact{$Name} = $filename if not $Exact{$Name};
        }
    }
    else {
        my $CName = lc $Name;
        if ( $Type eq 'Is' ) {
            die "oops[$CName]" if $Canonical{$CName};
            $Canonical{$CName} = $filename;
            $CaComment{$CName} = $Name if $Name =~ tr/A-Z// >= 2;
        }
        else {
            die "oops[$Type$CName]" if $Canonical{ lc "$Type$CName" };
            $Canonical{ lc "$Type$CName" } = $filename;
            $CaComment{ lc "$Type$CName" } = "$Type$Name";
            if ( not $Canonical{$CName} ) {
                $Canonical{$CName} = $filename;
                $CaComment{$CName} = "$Type$Name";
            }
        }
    }
}

##
## Writes the info accumulated in
##
##       %TableInfo;
##       %FuzzyNames;
##       %AliasInfo;
##
##
sub WriteAllMappings() {
    my @MAP;

    ## 'Is' *MUST* come first, so its names have precidence over 'In's
    for my $Type ( 'Is', 'In' ) {
        my %RawNameToFile;    ## a per-$Type cache

        for my $Name ( sort { length $a <=> length $b }
            keys %{ $TableInfo{$Type} } )
        {
            ## Note: $Name is already canonical
            my $Table   = $TableInfo{$Type}->{$Name};
            my $IsFuzzy = $FuzzyNames{$Type}->{$Name};

            ## Need an 8.3 safe filename (which means "an 8 safe" $filename)
            my $filename;
            {
                ## 'Is' items lose 'Is' from the basename.
                $filename
                    = $Type eq 'Is'
                    ? ( $PVA_reverse{sc}{$Name} || $Name )
                    : "$Type$Name";

                $filename =~ s/[^\w_]+/_/g;    # "L&" -> "L_"
                substr( $filename, 8 ) = '' if length($filename) > 8;

                ##
                ## Make sure the basename doesn't conflict with something we
                ## might have already written. If we have, say,
                ##     InGreekExtended1
                ##     InGreekExtended2
                ## they become
                ##     InGreekE
                ##     InGreek2
                ##
                while ( my $num = $BaseNames{ lc $filename }++ ) {
                    $num++; ## so basenames with numbers start with '2', which
                    ## just looks more natural.
                    ## Want to append $num, but if it'll make the basename longer
                    ## than 8 characters, pre-truncate $filename so that the result
                    ## is acceptable.
                    my $delta = length($filename) + length($num) - 8;
                    if ( $delta > 0 ) {
                        substr( $filename, -$delta ) = $num;
                    }
                    else {
                        $filename .= $num;
                    }
                }
            };

            ##
            ## Construct a nice comment to add to the file, and build data
            ## for the "./Properties" file along the way.
            ##
            my $Comment;
            {
                my $Desc = $TableDesc{$Type}->{$Name} || "";
                ## get list of names this table is reference by
                my @Supported = $Name;
                while ( my ( $Orig, $Alias ) = each %{ $AliasInfo{$Type} } ) {
                    if ( $Orig eq $Name ) {
                        push @Supported, $Alias;
                    }
                }

                my $TypeToShow = $Type eq 'Is' ? "" : $Type;
                my $OrigProp;

                $Comment = "This file supports:\n";
                for my $N (@Supported) {
                    my $IsFuzzy = $FuzzyNames{$Type}->{$N};
                    my $Prop    = "\\p{$TypeToShow$Name}";
                    $OrigProp = $Prop if not $OrigProp;    #cache for aliases
                    if ($IsFuzzy) {
                        $Comment .= "\t$Prop (and fuzzy permutations)\n";
                    }
                    else {
                        $Comment .= "\t$Prop\n";
                    }
                    my $MyDesc
                        = ( $N eq $Name )
                        ? $Desc
                        : "Alias for $OrigProp ($Desc)";

                    push @MAP,
                        sprintf( "%s %-42s %s\n",
                        $IsFuzzy ? '*' : ' ',
                        $Prop, $MyDesc );
                }
                if ($Desc) {
                    $Comment .= "\nMeaning: $Desc\n";
                }

            }
            ##
            ## Okay, write the file...
            ##
            $Table->Write( [ "lib", "gc_sc", "$filename.pl" ], $Comment );

            ## and register it
            $RawNameToFile{$Name} = $filename;
            RegisterFileForName( $Type => $Name, $IsFuzzy, $filename );

            if ($IsFuzzy) {
                my $CName = CanonicalName( $Type . '_' . $Name );
                $FuzzyNameToTest{$Name} = $Table if !$FuzzyNameToTest{$Name};
                $FuzzyNameToTest{$CName} = $Table
                    if !$FuzzyNameToTest{$CName};
            }
            else {
                $ExactNameToTest{$Name} = $Table;
            }

        }

        ## Register aliase info
        for my $Name ( sort { length $a <=> length $b }
            keys %{ $AliasInfo{$Type} } )
        {
            my $Alias    = $AliasInfo{$Type}->{$Name};
            my $IsFuzzy  = $FuzzyNames{$Type}->{$Alias};
            my $filename = $RawNameToFile{$Name};
            die "oops [$Alias]->[$Name]" if not $filename;
            RegisterFileForName( $Type => $Alias, $IsFuzzy, $filename );

            my $Table = $TableInfo{$Type}->{$Name};
            die "oops" if not $Table;
            if ($IsFuzzy) {
                my $CName = CanonicalName( $Type . '_' . $Alias );
                $FuzzyNameToTest{$Alias} = $Table
                    if !$FuzzyNameToTest{$Alias};
                $FuzzyNameToTest{$CName} = $Table
                    if !$FuzzyNameToTest{$CName};
            }
            else {
                $ExactNameToTest{$Alias} = $Table;
            }
        }
    }

    ##
    ## Write out the property list
    ##
    {
        my @OUT = (
            "##\n",
            "## This file created by $0\n",
            "## List of built-in \\p{...}/\\P{...} properties.\n",
            "##\n",
            "## '*' means name may be 'fuzzy'\n",
            "##\n\n",
            sort { substr( $a, 2 ) cmp substr( $b, 2 ) } @MAP,
        );
        WriteIfChanged( 'Properties', @OUT );
    }

    use Text::Tabs ();    ## using this makes the files about half the size

    ## Write Exact.pl
    {
        my @OUT = (
            $HEADER,
            "##\n",
            "## Data in this file used by ../utf8_heavy.pl\n",
            "##\n\n",
            "## Mapping from name to filename in ./lib/gc_sc\n",
            "%utf8::Exact = (\n",
        );

        $Exact{InGreek} = 'InGreekA';    # this is evil kludge
        for my $Name ( sort keys %Exact ) {
            my $File = $Exact{$Name};
            $Name = $Name =~ m/\W/ ? qq/'$Name'/ : " $Name ";
            my $Text = sprintf( "%-15s => %s,\n", $Name, qq/'$File'/ );
            push @OUT, Text::Tabs::unexpand($Text);
        }
        push @OUT, ");\n1;\n";

        WriteIfChanged( 'Exact.pl', @OUT );
    }

    ## Write Canonical.pl
    {
        my @OUT = (
            $HEADER,
            "##\n",
            "## Data in this file used by ../utf8_heavy.pl\n",
            "##\n\n",
            "## Mapping from lc(canonical name) to filename in ./lib\n",
            "%utf8::Canonical = (\n",
        );
        my $Trail = "";    ## used just to keep the spacing pretty
        for my $Name ( sort keys %Canonical ) {
            my $File = $Canonical{$Name};
            if ( $CaComment{$Name} ) {
                push @OUT, "\n" if not $Trail;
                push @OUT, " # $CaComment{$Name}\n";
                $Trail = "\n";
            }
            else {
                $Trail = "";
            }
            $Name = $Name =~ m/\W/ ? qq/'$Name'/ : " $Name ";
            my $Text
                = sprintf( "  %-41s => %s,\n$Trail", $Name, qq/'$File'/ );
            push @OUT, Text::Tabs::unexpand($Text);
        }
        push @OUT, ");\n1\n";
        WriteIfChanged( 'Canonical.pl', @OUT );
    }

    MakePropTestScript() if $MakeTestScript;
}

sub SpecialCasing_txt() {

    #
    # Read in the special cases.
    #

    my %CaseInfo;

    if ( not open IN, "SpecialCasing.txt" ) {
        die "$0: SpecialCasing.txt: $!\n";
    }
    while (<IN>) {
        next unless /^[0-9A-Fa-f]+;/;
        s/\#.*//;
        s/\s+$//;

        my ( $code, $lower, $title, $upper, $condition ) = split(/\s*;\s*/);

        if ($condition) {    # not implemented yet
            print "# SKIPPING $_\n" if $Verbose;
            next;
        }

        # Wait until all the special cases have been read since
        # they are not listed in numeric order.
        my $ix = hex($code);
        push @{ $CaseInfo{Lower} }, [ $ix, $code, $lower ]
            unless $code eq $lower;
        push @{ $CaseInfo{Title} }, [ $ix, $code, $title ]
            unless $code eq $title;
        push @{ $CaseInfo{Upper} }, [ $ix, $code, $upper ]
            unless $code eq $upper;
    }
    close IN;

    # Now write out the special cases properties in their code point order.
    # Prepend them to the To/{Upper,Lower,Title}.pl.

    for my $case (qw(Lower Title Upper)) {
        my $NormalCase = do "To/$case.pl" || die "$0: $@\n";

        my @OUT = (
            $HEADER, "\n",
            "# The key UTF-8 _bytes_, the value UTF-8 (speed hack)\n",
            "%utf8::ToSpec$case =\n(\n",
        );

        for my $prop ( sort { $a->[0] <=> $b->[0] } @{ $CaseInfo{$case} } ) {
            my ( $ix, $code, $to ) = @$prop;
            my $tostr = join "", map { sprintf "\\x{%s}", $_ } split ' ', $to;
            push @OUT, sprintf qq["%s" => "$tostr",\n],
                join( "",
                map { sprintf "\\x%02X", $_ }
                    unpack( "U0C*", pack( "U", $ix ) ) );

            # Remove any single-character mappings for
            # the same character since we are going for
            # the special casing rules.
            $NormalCase =~ s/^$code\t\t\w+\n//m;
        }
        push @OUT, ( ");\n\n", "return <<'END';\n", $NormalCase, "END\n" );
        WriteIfChanged( [ "To", "$case.pl" ], @OUT );
    }
}

#
# Read in the case foldings.
#
# We will do full case folding, C + F + I (see CaseFolding.txt).
#
sub CaseFolding_txt() {
    if ( not open IN, "CaseFolding.txt" ) {
        die "$0: CaseFolding.txt: $!\n";
    }

    my $Fold = Table->New();
    my %Fold;

    while (<IN>) {

        # Skip status 'S', simple case folding
        next
            unless
            /^([0-9A-Fa-f]+)\s*;\s*([CFI])\s*;\s*([0-9A-Fa-f]+(?: [0-9A-Fa-f]+)*)\s*;/;

        my ( $code, $status, $fold ) = ( hex($1), $2, $3 );

        if ( $status eq 'C' ) {    # Common: one-to-one folding
                # No append() since several codes may fold into one.
            $Fold->RawAppendRange( $code, $code, $fold );
        }
        else {    # F: full, or I: dotted uppercase I -> dotless lowercase I
            $Fold{$code} = $fold;
        }
    }
    close IN;

    $Fold->Write("To/Fold.pl");

    #
    # Prepend the special foldings to the common foldings.
    #
    my $CommonFold = do "To/Fold.pl" || die "$0: To/Fold.pl: $!\n";

    my @OUT = (
        $HEADER, "\n",
        "#  The ke UTF-8 _bytes_, the value UTF-8 (speed hack)\n",
        "%utf8::ToSpecFold =\n(\n",
    );
    for my $code ( sort { $a <=> $b } keys %Fold ) {
        my $foldstr = join "", map { sprintf "\\x{%s}", $_ } split ' ',
            $Fold{$code};
        push @OUT, sprintf qq["%s" => "$foldstr",\n],
            join( "",
            map { sprintf "\\x%02X", $_ }
                unpack( "U0C*", pack( "U", $code ) ) );
    }
    push @OUT, ( ");\n\n", "return <<'END';\n", $CommonFold, "END\n", );

    WriteIfChanged( [ "To", "Fold.pl" ], @OUT );
}

## Do it....

Build_Aliases();
UnicodeData_Txt();
PropList_txt();

Scripts_txt();
Blocks_txt();

WriteAllMappings();

LineBreak_Txt();
ArabicShaping_txt();
EastAsianWidth_txt();
HangulSyllableType_txt();
Jamo_txt();
SpecialCasing_txt();
CaseFolding_txt();

if ( $FileList and $MakeList ) {

    print "Updating '$FileList'\n"
        if ($Verbose);

    open my $ofh, ">", $FileList
        or die "Can't write to '$FileList':$!";
    print $ofh <<"EOFHEADER";
#
# mktables.lst -- File list for mktables.
#
#   Autogenerated on @{[scalar localtime]}
#
# - First section is input files
#   (mktables itself is automatically included)
# - Section seperator is /^=+\$/
# - Second section is a list of output files.
# - Lines matching /^\\s*#/ are treated as comments
#   which along with blank lines are ignored.
#

# Input files:

EOFHEADER
    my @input = ( "version", glob('*.txt') );
    print $ofh "$_\n"
        for
        @input,
        "\n=================================\n",
        "# Output files:\n",

        # special files
        "Properties";

    require File::Find;
    my $count = 0;
    File::Find::find(
        {   no_chdir => 1,
            wanted   => sub {
                if (/\.pl$/) {
                    s!^\./!!;
                    print $ofh "$_\n";
                    $count++;
                }
            },
        },
        "."
    );

    print $ofh "\n# ", scalar(@input), " input files\n",
        "# ", scalar( $count + 1 ), " output files\n\n",
        "# End list\n";
    close $ofh
        or warn "Failed to close $ofh: $!";

    print "Filelist has ", scalar(@input), " input files and ",
        scalar( $count + 1 ), " output files\n"
        if $Verbose;
}
print "All done\n" if $Verbose;
exit(0);

## TRAILING CODE IS USED BY MakePropTestScript()
__DATA__
use strict;
use warnings;

my $Tests = 0;
my $Fails = 0;

sub Expect($$$)
{
    my $Expect = shift;
    my $String = shift;
    my $Regex  = shift;
    my $Line   = (caller)[2];

    $Tests++;
    my $RegObj;
    my $result = eval {
        $RegObj = qr/$Regex/;
        $String =~ $RegObj ? 1 : 0
    };
    
    if (not defined $result) {
        print "couldn't compile /$Regex/ on $0 line $Line: $@\n";
        $Fails++;
    } elsif ($result ^ $Expect) {
        print "bad result (expected $Expect) on $0 line $Line: $@\n";
        $Fails++;
    }
}

sub Error($)
{
    my $Regex  = shift;
    $Tests++;
    if (eval { 'x' =~ qr/$Regex/; 1 }) {
        $Fails++;
        my $Line = (caller)[2];
        print "expected error for /$Regex/ on $0 line $Line: $@\n";
    }
}

sub Finished()
{
   if ($Fails == 0) {
      print "All $Tests tests passed.\n";
      exit(0);
   } else {
      print "$Tests tests, $Fails failed!\n";
      exit(-1);
   }
}
