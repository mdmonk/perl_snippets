########################################################################
# Program Name:  ShoutProxy2.pl
# Programmer(s): Ranger Rick and Maddog Monk
#
# Explanation:
#  - This script acts as a forwarding proxy. 
#########################################################################
require 5.002;
#use strict;
use IO::Socket;
use IO::Select;
use MIME::Base64;

$logname = "username";
$passwd = "password";
$loc = "http://www.loudfactory.com:8000/";
#$loc = "http://128.61.75.117:8000/"; # Coredump 128k
#$loc = "http://128.61.75.117:8010/"; # Coredump 32k
#$loc = "http://208.156.128.7:8000/"; # 200 Proof Techno
$host = "proxy.example.com";
$printit = 0;

$VERSION = "2.0b";
$mimeCode = MIME::Base64::encode("$logname:$passwd", '');

$handle = IO::Socket::INET->new(Proto => "tcp",
          PeerAddr => $host,
          PeerPort => 8000) or $res = 1;
$handle->autoflush(1);

print $handle <<END;
GET $loc HTTP/1.0
Connection: Close
User-Agent: Mozilla/4.0 (Compatible; Win95; IE 4.0 SP1)
Accept: image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, */*
Accept-Encoding: gzip
Accept-Language: en
Proxy-Authorization: Basic $mimeCode
Accept-Charset: iso-8859-1,*,utf-8

END

# create a socket to listen to a port
my $listen = IO::Socket::INET->new(Proto => 'tcp',
                                   LocalPort => 8080,
                                   Listen => 1,
                                   Reuse => 1) or die $!;

# to start with, $select contains only the socket we're listening on
my $select = IO::Select->new($listen);

my @ready;

MONKEY: while (<$handle>) {
  $temp = $_;
  $temp =~ s/\r\n/\n/g;
  last if ($temp eq "\n");
}

$temp = "freak";

WANKER: while($temp ne "") { # read some headers
  $temp = <$handle>;
  $temp =~ s/\r\n/\n/g;
  last if ($temp eq "\n");
  $temp =~ s/\s*?:\s*?/:/g;
  chomp($temp);
  @sort = split(/\:/,$temp);
#  print "\"$sort[0]\" = \"$sort[1]\"\n";
  if (uc($temp) =~ /ICY .*/) {
    @command = split(/ /, $temp);
  } elsif (uc($sort[0]) eq "ICY-NOTICE1") {
    $icyNotice1 = $sort[1];
  } elsif (uc($sort[0]) eq "ICY-NOTICE2") {
    $icyNotice2 = $sort[1];
  } elsif (uc($sort[0]) eq uc("icy-name")) {
    $icyName = $sort[1];
  } elsif (uc($sort[0]) eq uc("icy-genre")) {
    $icyGenre = $sort[1];
  } elsif (uc($sort[0]) eq uc("icy-url")) {
    $icyURL = $sort[1];
  } elsif (uc($sort[0]) eq uc("icy-pub")) {
    $icyPub = $sort[1];
  } elsif (uc($sort[0]) eq uc("icy-br")) {
    $icyBR = $sort[1];
  } else {
    last WANKER;
  }
}

#foreach $i ("icyName", "icyGenre", "icyURL", "icyPub", "icyBR") {
#  print "\$$i: ${$i}\n";
#}

print "waiting for connections...\n";

while(<$handle>) {
$line = $_;
  if (@ready = $select->can_read) {
    my $socket;
    # handle each socket that's ready
    for $socket (@ready) {
        # if the listening socket is ready, accept a new connection
        if($socket == $listen) {
            my $new = $listen->accept;
            $select->add($new);
            print $new->fileno . ": connected\n";
#            while ($socket->read) {
#              print "blah\n";
#            }
            $localtime = localtime;
            print $new <<END;
HTTP/1.0 200 Ok
Server: ShoutProxy/$VERSION
Date: $localtime
Content-type: audio/mpeg

ICY 200 Ok
icy-notice1: DFT Shoutcast Proxy
icy-notice2: $icyNotice2
icy-name: $icyName
icy-genre: $icyGenre
icy-url: $icyURL
icy-br: $icyBR
icy-pub: $icyPub

END
        } else {
            $printit++;
            # read a line of text.
            # close the connection if recv() fails.
#            my $line="";
#            $socket->recv($line,80);
            if($line eq "") {
                print $socket->fileno . ": disconnected\n";
                $select->remove($socket);
                $socket->close;
            };
            my $socket;
            # broadcast to everyone.  Close connections where send() fails.
            for $socket ($select->handles) {
                next if($socket==$listen);
                if ($socket->send($line)) {
                  $length{$socket->fileno} = ($length{$socket->fileno} + length($line));
                  if ($printit == 1000) {
                    print $socket->fileno . ": Sent " . $length{$socket->fileno} . " bytes.\n";
                    $printit = 0;
                  }
                } else {
                  print $socket->fileno . ": disconnected\n";         
                  $select->remove($socket);
                  $socket->close;
                };
            }
        }
    }
  }
}
1;
