#!/usr/bin/perl
use IO::Socket;

if ($#ARGV <= 0) {
  print STDERR "usage: getright <URL> <FILENAME>\n\n";
  print STDERR "     <URL>: eg. http://www.server.com:port/path/file.ext\n";
  print STDERR "<FILENAME>: eg. filename.ext\n";
  exit(0);
} else {
  open(FILE, "+>>".$ARGV[1]) or die "Cannot open $ARGV[1] for append: $!";
  ($length = sysseek(FILE,0,2)) =~ s!.*([0-9]+).*!$1!g;
  print STDERR "Attempting to resume $ARGV[1] from byte: $length\n";
}

if ($ARGV[0] =~ m!^ (?:http://)? (.*?) (?:\:([0-9]+))? (/.*)$!x)
  { ($server,$port,$path) = ($1, $2 || 80, $3); }

print "[$server] [$port] [$path]\n";

$socket = IO::Socket::INET->new(PeerAddr => $server,
                                PeerPort => $port,
                                Proto    => 'tcp',
                                Type     => SOCK_STREAM) or die "Cannot connect: $!";

print $socket "GET $path HTTP/1.0\n";
print $socket "Host: $server\n";
print $socket "Range: bytes=$length-\n";
print $socket "Connection: close\n\n";

if (!(($reply = <$socket>) =~ /HTTP\/1.[01] 206 Partial Content/)) {
  $reply =~ s!(.*)\r\n!$1!;
  print STDERR "Failed [$reply]\n";
  print STDERR "Invalid URL/Unrecognized Reply/Resume Not Supported.\n";
  close($socket); exit(0);
} else {
  print STDERR "Received valid HTTP reply.\n";
}

while (($mime = <$socket>) =~ /\w+: /) {
  if ($mime =~ /Content\-Range\:\sbytes\s([0-9]+)\-([0-9]+)\/([0-9]+)/)
    { ($start,$finish,$filesize) = ($1, $2, $3); }
  if ($mime =~ /Content\-Length\:\s([0-9]+)/) { $total = $1; }
}

print STDERR "Receiving data: ";
while ($data = <$socket>) {
  $recieved += length($data);
  $percentage= int((($start+$recieved) / $filesize) * 100);
  print STDERR $percentage."%"."\b"x(length($percentage)+1);
  print FILE $data;
}

print STDERR "100%\n";
close(FILE);
close($socket);

# Example HTTP return header:
#
#          HTTP/1.1 206 Partial content
#          Date: Wed, 15 Nov 1995 06:25:24 GMT
#          Last-modified: Wed, 15 Nov 1995 04:58:08 GMT
#          Content-Range: bytes 21010-47021/47022
#          Content-Length: 26012
#          Content-Type: image/gif
