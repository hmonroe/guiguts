package File::CheckTree;

use 5.006;
use Cwd;
use Exporter;
use File::Spec;
use warnings;
use strict;

our $VERSION = '4.3';
our @ISA     = qw(Exporter);
our @EXPORT  = qw(validate);

my $Warnings;

sub validate {
    my ($starting_dir, $file, $test, $cwd, $oldwarnings);

    $starting_dir = cwd;

    $cwd = "";
    $Warnings = 0;

    foreach my $check (split /\n/, $_[0]) {
        my ($testlist, @testlist);

        # skip blanks/comments
        next if $check =~ /^\s*#/ || $check =~ /^\s*$/;

        # Todo:
        # should probably check for invalid directives and die
        # but earlier versions of File::CheckTree did not do this either

        # split a line like "/foo -r || die"
        # so that $file is "/foo", $test is "-rwx || die"
        ($file, $test) = split(' ', $check, 2);   # special whitespace split

        # change a $test like "!-ug || die" to "!-Z || die",
        # capturing the bundled tests (e.g. "ug") in $2
        if ($test =~ s/ ^ (!?-) (\w{2,}) \b /$1Z/x) {
            $testlist = $2;
            # split bundled tests, e.g. "ug" to 'u', 'g'
            @testlist = split(//, $testlist);
        }
        else {
            # put in placeholder Z for stand-alone test
            @testlist = ('Z');
        }

        # will compare these two later to stop on 1st warning w/in a bundle
        $oldwarnings = $Warnings;

        foreach my $one (@testlist) {
            # examples of $test: "!-Z || die" or "-w || warn"
            my $this = $test;

            # expand relative $file to full pathname if preceded by cd directive
            $file = File::Spec->catfile($cwd, $file) 
                    if $cwd && !File::Spec->file_name_is_absolute($file);

            # put filename in after the test operator
            $this =~ s/(-\w\b)/$1 "\$file"/g;

            # change the "-Z" representing a bundle with the $one test
            $this =~ s/-Z/-$one/;

            # if it's a "cd" directive...
            if ($this =~ /^cd\b/) {
                # add "|| die ..."
                $this .= ' || die "cannot cd to $file\n"';
                # expand "cd" directive with directory name
                $this =~ s/\bcd\b/chdir(\$cwd = '$file')/;
            }
            else {
                # add "|| warn" as a default disposition
                $this .= ' || warn' unless $this =~ /\|\|/; 

                # change a generic ".. || die" or ".. || warn"
                # to call valmess instead of die/warn directly
                # valmess will look up the error message from %Val_Message
                $this =~ s/ ^ ( (\S+) \s+ \S+ ) \s* \|\| \s* (die|warn) \s* $
                          /$1 || valmess('$3', '$2', \$file)/x;
            }

            {
                # count warnings, either from valmess or '-r || warn "my msg"'
                # also, call any pre-existing signal handler for __WARN__
                my $orig_sigwarn = $SIG{__WARN__};
                local $SIG{__WARN__} = sub {
                    ++$Warnings;
                    if ( $orig_sigwarn ) {
                        $orig_sigwarn->(@_);
                    }
                    else {
                        warn "@_";
                    }
                };

                # do the test
                eval $this;

                # re-raise an exception caused by a "... || die" test 
                if ($@) {
                    # in case of any cd directives, return from whence we came
                    if ($starting_dir ne cwd) {
                        chdir($starting_dir) || die "$starting_dir: $!";
                    }
                    die $@ if $@;
                }
            }

            # stop on 1st warning within a bundle of tests
            last if $Warnings > $oldwarnings;
        }
    }

    # in case of any cd directives, return from whence we came
    if ($starting_dir ne cwd) {
        chdir($starting_dir) || die "chdir $starting_dir: $!";
    }

    return $Warnings;
}

my %Val_Message = (
    'r' => "is not readable by uid $>.",
    'w' => "is not writable by uid $>.",
    'x' => "is not executable by uid $>.",
    'o' => "is not owned by uid $>.",
    'R' => "is not readable by you.",
    'W' => "is not writable by you.",
    'X' => "is not executable by you.",
    'O' => "is not owned by you.",
    'e' => "does not exist.",
    'z' => "does not have zero size.",
    's' => "does not have non-zero size.",
    'f' => "is not a plain file.",
    'd' => "is not a directory.",
    'l' => "is not a symbolic link.",
    'p' => "is not a named pipe (FIFO).",
    'S' => "is not a socket.",
    'b' => "is not a block special file.",
    'c' => "is not a character special file.",
    'u' => "does not have the setuid bit set.",
    'g' => "does not have the setgid bit set.",
    'k' => "does not have the sticky bit set.",
    'T' => "is not a text file.",
    'B' => "is not a binary file."
);

sub valmess {
    my ($disposition, $test, $file) = @_;
    my $ferror;

    if ($test =~ / ^ (!?) -(\w) \s* $ /x) {
        my ($neg, $ftype) = ($1, $2);

        $ferror = "$file $Val_Message{$ftype}";

        if ($neg eq '!') {
            $ferror =~ s/ is not / should not be / ||
            $ferror =~ s/ does not / should not / ||
            $ferror =~ s/ not / /;
        }
    }
    else {
        $ferror = "Can't do $test $file.\n";
    }

    die "$ferror\n" if $disposition eq 'die';
    warn "$ferror\n";
}

1;
