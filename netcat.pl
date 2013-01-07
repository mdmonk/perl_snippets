#!/usr/bin/perl -w
# @(#) netcat.pl	Sends to a nominated socket on remote server.
#			Can be used with HP Jetdirect and similar devices.
#
# Copyright (c) 2002 Graham Jenkins <grahjenk@au1.ibm.com>. All rights reserved.
# This program is free software; you can redistribute it and/or modify it under
# the same terms as Perl itself.

use strict;
use IO::Socket;
use File::Basename;
use vars qw($VERSION);
$VERSION = "1.0";
my (@ports,$debug,$invalid,$start,$sock,$buffer,$prev);
my $timeout=3600;

foreach my $j (@ARGV) {			# Untaint and validate the arguments.
  if ($j =~ /^([-:\@\w.]+)$/) { unshift(@ports,$1)                      }
  else                        { die "Bad data in $ARGV[$j]\n"           }
  if ( $ports[0]=~/^-/    )   { $debug=1; $ports[0]=~s/^-//             } 
  if ( $ports[0]=~/^\d+$/ )   { $timeout=$ports[0]; shift(@ports); next } 
  if ( $ports[0]!~/:\d+$/ )   { $invalid=1; last                        }
}
die "Usage: ".basename($0)." server1:port1 [server2:port2] .. [timeout]\n".
    "e.g.:  ".basename($0)." jetdirect01:9100\n".
    "Input is sent to whichever of the designated ports first becomes\n".
    "available. The value of 'timeout' may be negated for debug purposes;\n".
    "default value is 3600 seconds.\n" if ( ($invalid) or ($#ports < 0) );

$prev=$start=time;			# Open a port.
while ( (my $j=$start + $timeout - time) >=0 ) { 
  print STDERR "Timeout will occur in $j seconds.\n" if $debug;
  foreach my $k (reverse(@ports)) {
    print STDERR "Trying to open $k ..\n" if $debug;
    $sock = new IO::Socket::INET ( PeerAddr => $k ) or next;
    print STDERR "Succeeded! Sending data now ..\n" if $debug;
    my $bytes = 0;			# Send the data.
    while ( read(STDIN, $buffer, 1024) >0 ) {
      die "Failed whilst doing: $_[1]\n"
        if send($sock,$buffer,0) != length($buffer);
      $bytes+=length($buffer);
      do {
        $prev=time; print STDERR $bytes;
        for (my $l=0;$l<length($bytes);$l++) {print STDERR "\b"}
      } if ( ($debug) && (time - $prev) > 1 ) 
    }
    print STDERR "$bytes bytes sent!\n" if $debug;
    exit 0				# Exit.
  }
  sleep 15 if $timeout > 15
}
die "Timed out after $timeout seconds!\n"

__END__

=head1 NAME

netcat - sends byte stream to socket on remote server

=head1 README

netcat is a simple client program which 
sends a byte stream to a socket on a
remote server. It is intended for use
with print server devices.

=head1 DESCRIPTION

C<netcat> is a simple client which feeds jobs to a socket
on a remote server. It is intended for use with print
server devices.

Multiple destinations can be given on the command line,
and the input stream will be fed to the first of these
which becomes available.

=head1 USAGE

=over 4

=item netcat server1:port1 [server2:port2] .. [timeout]

=back

The 'timeout' parameter gives the maximum time in seconds
for which retry attempts will be made.

If a negative value is given for 'timeout', the absolute value
will be used, and progress messages will be written to STDERR.

Windows users may find it convenient to use a utility like
'redmon' <www.cs.wisc.edu/~ghost/redmon> for feeding print
jobs to this program.

=head1 SCRIPT CATEGORIES

Networking
UNIX/System_administration

=head1 AUTHOR

Graham Jenkins <grahjenk@au1.ibm.com>

=head1 COPYRIGHT

Copyright (c) 2002 Graham Jenkins. All rights reserved.
This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut
