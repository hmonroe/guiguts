
require 5;
package Pod::Perldoc::ToMan;
use strict;
use warnings;

# This class is unlike ToText.pm et al, because we're NOT paging thru
# the output in our particular format -- we make the output and
# then we run nroff (or whatever) on it, and then page thru the
# (plaintext) output of THAT!

use base qw(Pod::Perldoc::BaseTo);
sub is_pageable        { 1 }
sub write_with_binmode { 0 }
sub output_extension   { 'txt' }

sub __filter_nroff  { shift->_perldoc_elem('__filter_nroff'  , @_) }
sub __nroffer       { shift->_perldoc_elem('__nroffer'       , @_) }
sub __bindir        { shift->_perldoc_elem('__bindir'        , @_) }
sub __pod2man       { shift->_perldoc_elem('__pod2man'       , @_) }
sub __output_file   { shift->_perldoc_elem('__output_file'   , @_) }

sub center          { shift->_perldoc_elem('center'         , @_) }
sub date            { shift->_perldoc_elem('date'           , @_) }
sub fixed           { shift->_perldoc_elem('fixed'          , @_) }
sub fixedbold       { shift->_perldoc_elem('fixedbold'      , @_) }
sub fixeditalic     { shift->_perldoc_elem('fixeditalic'    , @_) }
sub fixedbolditalic { shift->_perldoc_elem('fixedbolditalic', @_) }
sub quotes          { shift->_perldoc_elem('quotes'         , @_) }
sub release         { shift->_perldoc_elem('release'        , @_) }
sub section         { shift->_perldoc_elem('section'        , @_) }

sub new { return bless {}, ref($_[0]) || $_[0] }

use File::Spec::Functions qw(catfile);

sub parse_from_file {
  my $self = shift;
  my($file, $outfh) = @_;

  my $render = $self->{'__nroffer'} || die "no nroffer set!?";
  
  # turn the switches into CLIs
  my $switches = join ' ',
    map qq{"--$_=$self->{$_}"},
      grep !m/^_/s,
        keys %$self
  ;
  
  my $command =
    catfile(
      ($self->{'__bindir'}  || die "no bindir set?!"  ),
      ($self->{'__pod2man'} || die "no pod2man set?!" ),
    )
    . " $switches --lax $file | $render -man"
  ;               # no temp file, just a pipe!

  # Thanks to Brendan O'Dea for contributing the following block
  if(Pod::Perldoc::IS_Linux and -t STDOUT
    and my ($cols) = `stty -a` =~ m/\bcolumns\s+(\d+)/
  ) {
    my $c = $cols * 39 / 40;
    $cols = $c > $cols - 2 ? $c : $cols -2;
    $command .= ' -rLL=' . (int $c) . 'n' if $cols > 80;
  }

  # I hear persistent reports that adding a -c switch to $render
  # solves many people's problems.  But I also hear that some mans
  # don't have a -c switch, so that adding it here would presumably
  # be a Bad Thing   -- sburke@cpan.org

  $command .= " | col -x" if Pod::Perldoc::IS_HPUX;
  
  defined(&Pod::Perldoc::DEBUG)
   and Pod::Perldoc::DEBUG()
   and print "About to run $command\n";
  ;
  
  my $rslt = `$command`;

  my $err;

  if( $self->{'__filter_nroff'} ) {
    defined(&Pod::Perldoc::DEBUG)
     and &Pod::Perldoc::DEBUG()
     and print "filter_nroff is set, so filtering...\n";
    $rslt = $self->___Do_filter_nroff($rslt);
  } else {
    defined(&Pod::Perldoc::DEBUG)
     and Pod::Perldoc::DEBUG()
     and print "filter_nroff isn't set, so not filtering.\n";
  }

  if (($err = $?)) {
    defined(&Pod::Perldoc::DEBUG)
     and Pod::Perldoc::DEBUG()
     and print "Nonzero exit ($?) while running $command.\n",
               "Falling back to Pod::Perldoc::ToPod\n ",
    ;
    # A desperate fallthru:
    require Pod::Perldoc::ToPod;
    return  Pod::Perldoc::ToPod->new->parse_from_file(@_);
    
  } else {
    print $outfh $rslt
     or die "Can't print to $$self{__output_file}: $!";
  }
  
  return;
}


sub ___Do_filter_nroff {
  my $self = shift;
  my @data = split /\n{2,}/, shift;
  
  shift @data while @data and $data[0] !~ /\S/; # Go to header
  shift @data if @data and $data[0] =~ /Contributed\s+Perl/; # Skip header
  pop @data if @data and $data[-1] =~ /^\w/; # Skip footer, like
				# 28/Jan/99 perl 5.005, patch 53 1
  join "\n\n", @data;
}

1;

__END__

