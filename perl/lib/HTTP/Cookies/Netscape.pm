package HTTP::Cookies::Netscape;

use strict;
use vars qw(@ISA $VERSION);

$VERSION = sprintf("%d.%02d", q$Revision: 1.26 $ =~ /(\d+)\.(\d+)/);

require HTTP::Cookies;
@ISA=qw(HTTP::Cookies);

sub load
{
    my($self, $file) = @_;
    $file ||= $self->{'file'} || return;
    local(*FILE, $_);
    local $/ = "\n";  # make sure we got standard record separator
    my @cookies;
    open(FILE, $file) || return;
    my $magic = <FILE>;
    unless ($magic =~ /^\#(?: Netscape)? HTTP Cookie File/) {
	warn "$file does not look like a netscape cookies file" if $^W;
	LWP::Debug::debug("$file doesn't look like a netscape cookies file. Skipping.");
	close(FILE);
	return;
    }
    LWP::Debug::debug("Okay, $file is a netscape cookies file.  Parsing.");
    my $now = time() - $HTTP::Cookies::EPOCH_OFFSET;
    while (<FILE>) {
	next if /^\s*\#/;
	next if /^\s*$/;
	tr/\n\r//d;
	my($domain,$bool1,$path,$secure, $expires,$key,$val) = split(/\t/, $_);
	LWP::Debug::debug(join '', "-Reading NS cookie: ",
	  map(" <$_>", split(/\t/, $_)));
	$secure = ($secure eq "TRUE");
	$self->set_cookie(undef,$key,$val,$path,$domain,undef,
			  0,$secure,$expires-$now, 0);
    }
    close(FILE);
    1;
}

sub save
{
    my($self, $file) = @_;
    $file ||= $self->{'file'} || return;
    local(*FILE, $_);
    open(FILE, ">$file") || return;

    print FILE <<EOT;
# Netscape HTTP Cookie File
# http://www.netscape.com/newsref/std/cookie_spec.html
# This is a generated file!  Do not edit.

EOT

    my $now = time - $HTTP::Cookies::EPOCH_OFFSET;
    $self->scan(sub {
	my($version,$key,$val,$path,$domain,$port,
	   $path_spec,$secure,$expires,$discard,$rest) = @_;
	return if $discard && !$self->{ignore_discard};
	$expires = $expires ? $expires - $HTTP::Cookies::EPOCH_OFFSET : 0;
	return if $now > $expires;
	$secure = $secure ? "TRUE" : "FALSE";
	my $bool = $domain =~ /^\./ ? "TRUE" : "FALSE";
	print FILE join("\t", $domain, $bool, $path, $secure, $expires, $key, $val), "\n";
    });
    close(FILE);
    1;
}

1;
__END__

