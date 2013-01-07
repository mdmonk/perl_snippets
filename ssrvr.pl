#!/usr/bin/perl
########################################################
# Program:     ssrvr.pl
# Programmer:  Chuck
# Description: 
#   This is a simple "server" script. Opens up a port,
#   and waits for a connection. Once a connection is
#   established, it prints "Hello, World!" to the
#   socket, then closes/exits.
########################################################
$| = 1;
$line = "Hello, World!\n";

$port = 2000;

while(getservbyport($port, "tcp")) {
  $port++;
}
print "Port is: $port\n";

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
