#!/usr/bin/perl
#################################################
#
#################################################
$| = 1;
$line = "Hello, World!\n";

$port = 2000;
print "Port is: $port\n";

while(getservbyport($port, "tcp")) {
#   print "Tmp is: $tmp\n";
  $port++;
}

($d1, $d2, $prototype) = getprotobyname("tcp");
($d1, $d2, $d3, $d4, $rawserver) = gethostbyname ("localhost");
$serveraddr = pack("Sna4x8", 2, $port, $rawserver);

socket (SSOCKET, 2, 1, $prototype) || die ("No socket: $!\n");

bind (SSOCKET, $serveraddr) || die ("Can't bind: $!\n");

listen (SSOCKET, 1) || die ("Can't listen: $!\n");

($clientaddr = accept (SOCKET, SSOCKET)) || die ("Can't accept: $!\n");

select (SOCKET);
$| = 1;
print SOCKET "$line\n";
close (SOCKET);
close (SSOCKET);
