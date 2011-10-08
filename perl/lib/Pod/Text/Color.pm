# Pod::Text::Color -- Convert POD data to formatted color ASCII text
# $Id: Color.pm,v 1.4 2002/07/15 05:46:00 eagle Exp $
#
# Copyright 1999, 2001 by Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.
#
# This is just a basic proof of concept.  It should later be modified to make
# better use of color, take options changing what colors are used for what
# text, and the like.

##############################################################################
# Modules and declarations
##############################################################################

package Pod::Text::Color;

require 5.004;

use Pod::Text ();
use Term::ANSIColor qw(colored);

use strict;
use vars qw(@ISA $VERSION);

@ISA = qw(Pod::Text);

# Don't use the CVS revision as the version, since this module is also in Perl
# core and too many things could munge CVS magic revision strings.  This
# number should ideally be the same as the CVS revision in podlators, however.
$VERSION = 1.04;


##############################################################################
# Overrides
##############################################################################

# Make level one headings bold.
sub cmd_head1 {
    my $self = shift;
    local $_ = shift;
    s/\s+$//;
    $self->SUPER::cmd_head1 (colored ($_, 'bold'));
}

# Make level two headings bold.
sub cmd_head2 {
    my $self = shift;
    local $_ = shift;
    s/\s+$//;
    $self->SUPER::cmd_head2 (colored ($_, 'bold'));
}

# Fix the various formatting codes.
sub seq_b { return colored ($_[1], 'bold')   }
sub seq_f { return colored ($_[1], 'cyan')   }
sub seq_i { return colored ($_[1], 'yellow') }

# Output any included code in green.
sub output_code {
    my ($self, $code) = @_;
    $code = colored ($code, 'green');
    $self->output ($code);
}

# We unfortunately have to override the wrapping code here, since the normal
# wrapping code gets really confused by all the escape sequences.
sub wrap {
    my $self = shift;
    local $_ = shift;
    my $output = '';
    my $spaces = ' ' x $$self{MARGIN};
    my $width = $$self{width} - $$self{MARGIN};
    while (length > $width) {
        if (s/^((?:(?:\e\[[\d;]+m)?[^\n]){0,$width})\s+//
            || s/^((?:(?:\e\[[\d;]+m)?[^\n]){$width})//) {
            $output .= $spaces . $1 . "\n";
        } else {
            last;
        }
    }
    $output .= $spaces . $_;
    $output =~ s/\s+$/\n\n/;
    $output;
}

##############################################################################
# Module return value and documentation
##############################################################################

1;
__END__

