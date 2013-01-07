#!/usr/bin/perl

# Ross Lonstein <rlonstein@pobox.com>
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

=head1 NAME

tunnel-auth.pl - traverse a HTTP proxy via SSL Connect with Basic or Digest authentication.

=head1 DESCRIPTION

Forking script can be used to traverse a HTTP proxy that supports the CONNECT 
command. It negotiates HTTP authentication, if necessary, then steps aside and 
acts as a simple port forwarder. It reports a User-Agent string so that nothing 
suspicious appears in the logs.

=cut
my $VERSION=0.03;
use IO::Socket::INET;
use IO::Select;
use Getopt::Std;
use POSIX qw(:sys_wait_h);
use strict;

if ($^O =~ /win32/i) {
    # forking under win32 reqs v5.6
    require 5.6.0;
}

my ( $dport,      $dhost,      $proxyhost, $proxyport );
my ( $remotehost, $remoteport, $auth,      $useragent );
my ( $fhin,       $fhout,      $server,    $proxy, $child );

# check for MD5 support
if ( eval { 'use Digest::MD5;' } ) {
    use Digest::MD5;
    print STDERR "Using MD5.\n";
}
my $md5avail = !$@;

#
# handle args
#
my %opts;
getopts( 'a:l:p:r:u:', \%opts );
usage('Missing remote host:port') unless $opts{'r'};
usage('Missing local host:port')  unless $opts{'l'};
usage('Missing proxy host:port')  unless $opts{'p'};

( $proxyhost,  $proxyport )  = split ( ':', $opts{'p'} );
( $remotehost, $remoteport ) = split ( ':', $opts{'r'} );

if ( $opts{'l'} =~ /:/ ) {

    # use specific interface & port
    ( $dhost, $dport ) = split ( ':', $opts{'l'} );
}
else {

    # use localhost and specified port
    $dport = $opts{'l'};
    $dhost = '127.0.0.1';
}

$auth = $opts{'a'};

# sample user agent identifiers:
#
#   Mozilla/4.0 (compatible; MSIE 5.01; Windows NT)
#   Mozilla/4.0 (compatible; MSIE 5.5; Windows NT 5.0)
#   Mozilla/4.73 [en] (Win98; U)
#   Mozilla/4.76 [en] (WinNT; U)
#   Mozilla/4.7 [en] (X11; I; Linux 2.2.12-20 i686)
#   Mozilla/4.5 (compatible; iCab Pre2.4; Macintosh; I; PPC)
#
# choose one appropriate for your environment so as not to
# arouse suspicion in the logs...
$useragent = $opts{'u'} || 'Mozilla/4.0 (compatible; MSIE 5.01; Windows NT)';

#
# Set up network communication
#

$server = IO::Socket::INET->new(
    Proto     => 'tcp',
    LocalAddr => $dhost,
    LocalPort => $dport,
    Listen    => SOMAXCONN,
    Type      => SOCK_STREAM,
    Reuse     => 1
) || die "Error creating daemon socket: $!";

my %socket_hash = (
    PeerAddr => $proxyhost,
    PeerPort => $proxyport,
    Proto    => 'tcp',
    Type     => SOCK_STREAM
);

while ( $fhin = $server->accept() ) {
    next if $child = fork();
    die "fork failed: $!" unless defined $child;
    $fhout = $fhin;

    # get a connect to proxy server ...
    $proxy = getPeerSocket( \%socket_hash );

    # Force flushing of socket buffers...
    # (not necessary >5.005 on sockets? --rl)
    foreach ( \*$proxy, $fhin, $fhout ) {
        select($_);
        $| = 1;
    }

    # Negotiate with Proxy
    print $proxy "CONNECT $remotehost:$remoteport HTTP/1.0\r\n";
    print $proxy "User-Agent: $useragent\r\n" if $useragent;
    print $proxy "\r\n";

    # Wait for HTTP status code
    my $status;
    ($status) = ( split ( /\s+/, <$proxy> ) )[1];

    # handle authenticating proxy
    if ( $status == 407 && $auth ) {

        # skip lines waiting for type of authentication
        $_ = <$proxy> while ( $_ = !/Proxy-authenticate: (\w+) / );
        print STDERR "Proxy authentication required...";

        # ignore rest, close connection and try again
        $proxy->close() || die ("Error closing proxy connection: $!");
        print STDERR "Closed proxy.\n Reconnecting...";
        $proxy = getPeerSocket( \%socket_hash );
        print $proxy "CONNECT $remotehost:$remoteport HTTP/1.0\r\n";
        print $proxy "User-Agent: $useragent\r\n" if $useragent;

        # determine type of authentication...
        CASE: {
            auth_basic(),  last CASE if $1 =~ /basic/i;
            auth_digest(), last CASE if $1 =~ /digest/i && $md5avail;

            # add support for other auth schemes here...
            auth_unsupt(), last CASE;
        }

        print $proxy "\r\n";

        # get new status
        ($status) = ( split ( /\s+/, <$proxy> ) )[1];
    }

    die "Bad status code \"$status\" from proxy server."
      if ( int( $status / 100 ) != 2 );

    # Skip through remaining part of HTTP header (until blank line)
    1 until ( <$proxy> =~ /^[\r\n]+$/ );

    # start hustling packets around...
    shuffle_packets(
        {
            input  => $fhin,
            output => $fhout,
            proxy  => $proxy,
        }
    );
    $proxy->close()  || die ("Error closing proxy socket: $!");
    $server->close() || die ("Error closing server socket: $!");
    exit;    # child ends
}
continue {
    close $fhin or die ("Error in parent closing accepted socket: $!");
}

# END MAIN

#
#
# SUBROUTINES
#
#

sub REAP {

    # Reaper for child processes, from the PCB

    1 until ( -1 == waitpid( -1, WNOHANG ) );
    $SIG{CHLD} = \&REAP;
}

sub shuffle_packets {

    # move packets between sockets

    my $href = shift || die ("Incomplete parameters: $!");

    my $in    = $$href{'input'};
    my $out   = $$href{'output'};
    my $proxy = $$href{'proxy'};

    my $s = IO::Select->new( $in, \*$proxy );
    my $num;
    LOOP: for ( ; ; ) {
        foreach my $fh ( $s->can_read(10) ) {
            last LOOP unless ( defined( $num = sysread( $fh, $_, 4096 ) ) );
            last LOOP if $num == 0;
            last LOOP
              unless (
                defined(
                syswrite( ( ( fileno($fh) == fileno($in) ) ? $proxy : $out ),
                      $_, $num ) ) );
        }
    }
}

sub auth_basic {

    # basic auth==base64(<uid>:<pw>)
    print STDERR "Using BASIC authentication.\n";
    print $proxy "Proxy-Authorization: Basic ", encode_base64($auth), "\r\n";
}

sub auth_digest {

    # digest auth==base64(md5(<uid>:<pw>:<nonce>))

    print STDERR "Using DIGEST authentication.\n";

    # wait for challenge
    $_ = <$proxy> while ( $_ =~ /digest/i );
    my ($challenge) = ( split ( ':', $_ ) )[1];

    # send response
    my ( $user, $pass ) = split ( ':', $auth );
    my $response = md5_base64("$user:$pass:$challenge");
    print $proxy "Proxy-Authorization:$response\r\n";
}

sub auth_unsupt {
    print STDERR "Unsupported authentication type '$1' requested!\n";
}

sub getPeerSocket {
    my $hr = shift || die ("No parameters: $!");
    my $socket = IO::Socket::INET->new(
        PeerAddr => $$hr{'PeerAddr'},
        PeerPort => $$hr{'PeerPort'},
        Proto    => $$hr{'Proto'} || 'tcp',
        Type     => $$hr{'Type'} || SOCK_STREAM
    ) || die "Socket setup failed: $!";
    return $socket;
}

sub encode_base64 {

    # stolen from MIME::Base64, thanks Gisle Aas
    # note we don't bother with requirement of line length < 76 chars

    use integer;
    my $res = "";
    pos( $_[0] ) = 0;
    while ( $_[0] =~ /(.{1,45})/gs ) {
        $res .= substr( pack( 'u', $1 ), 1 );
        chop($res);
    }
    $res =~ tr |` -_|AA-Za-z0-9+/|;
    my $padding = ( 3 - length( $_[0] ) % 3 ) % 3;
    $res =~ s/.{$padding}$/'=' x $padding/e if $padding;
    return $res;
}

sub usage {
    print "\n!! ", @_, " !!\n";
    print <<USAGE;

Usage $0 -p <proxy>:<port> -l [<local>:]<port> -r <remote>:<port> [-a <proxyid:password>] [-u <user-agent>]
 Connect to a remote host through a proxy supporting CONNECT.
   <proxy>:<port>       --  ip or hostname and port of your http proxy
   <local>:<port>       --  port to listen on. ip/hostname optional.
   <remote>:<port>      --  remote host and port (likely port 443/563)
   <proxyid>:<password> --  userid/password for authenticating proxies
   <user-agent>         --  header string send to proxy. Defaults to
                            'Mozilla/4.0 (compatible; MSIE 5.01; Windows NT)'
Example:
 $0 -p proxy.example.com:8080 -l 2222 -r myhost.nowhere.com:443 \
    -a joe:h4ckm3 -u 'Mozilla/4.76 [en] (WinNT; U)'

USAGE
    exit 1;
}

=head1 README

tunnel-auth.pl - traverse a HTTP proxy via SSL Connect with Basic or
Digest authentication.

This script can be used to traverse a HTTP proxy that supports the 
CONNECT command as is done for SSL. It negotiates HTTP authentication,
if necessary, then steps aside and acts as a simple port forwarder.
It reports a User-Agent string during negotiation so that nothing
suspicious appears in the proxy logs. Compatibility with Win32 was
retained by not forking, limiting it to a single connection per
instance.

Should work against any RFC-compliant proxy. Tested against:
    Netscape Enterprise/3.52
    Squid 2.2

Note: Properly configured proxies that allow CONNECT will only permit
connection to standard SSL ports (443 and 563 according to squid). You
can expect they will also have connection and idle timeout limits.

=head2 EXAMPLE

Assuming that you have a machine on the public internet accepting
connections you can do the following:
 tunnel-auth.pl -p proxy.example.com:8080 \
                -l 2222 -r myhost.nowhere.com:443 \
                -a joe:h4ckm3 \
                -u 'Mozilla/4.76 [en] (WinNT; U)'

And in another window:
 ssh -p 2222 blockhead@localhost

Which will, if all goes well, negotiate the proxy and connect to
the remote machine via secure shell.

=head1 PREREQUISITES

Requires the C<IO::Socket::INET>, C<IO::Select>, C<Getopt:Std> modules.

=head1 COREQUISITES

Digest Authentication support uses C<Digest::MD5>.

=head1 TODO

In no particular order:

- Logging. An ASCII/HEX dump would be nice for diagnosis.

- Support for NTLM authentication with Microsoft Proxy Server (that's a
hole with no bottom).

=head1 AUTHOR

Ross Lonstein <rlonstein@pobox.com>

based upon work by Urban Kaveus, Theo Van Dinter, Gisle Aas, 
Tom Christiansen and probably others but don't contact them 
because the bugs are all mine.

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

Networking

=cut

