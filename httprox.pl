#!/usr/bin/perl
#########################################################################################
#DESCRIPTION:
#	Perl HTTP proxy that modifies or adds an HTTP header for all outgoing HTTP 
#	traffic. Listens on 127.0.0.1:8080 by default, and can handle multiple requests,
#	but HTTP only (no HTTPS).
#
#USAGE:
#	./httprox <Header Title> <Header Value> [-a]
#
#	*Header Title is the specific header you wish to modify/add, such as Cookie, 
#	 User-Agent, etc. Header keywords are case-sensitive.
#
#	*Header Value is the value to assign to that header.
#
#	*Specifying the -a argument will cause the header to be added at the end of the 
#	 existing HTTP request.
#
#EXAMPLES:
#	./httprox User-Agent "None of your business..."
#	./httprox Cookie SOMECOOKIEDATA
#	./httprox Test-Header "This is a test header" -a
#
#SCRIPT CUSTOMIZATION:
#	There are three main variables listed at the beginning of the script that may
#	come of interest to the user: $ip, $port and $host_port. 
#
#	$ip and $port specify which local socket will be used to listen for connections 
#	from the web browser, and are set to 127.0.0.1:8080 by default. 
#
#	$host_port specifies the port on the server to connect to; this is port 80 by 
#	default, but can be changed if you need to connect to a server that runs on a 
#	non-standard port.
#
#BUGS:
#	This script is meant to be used for testing purposes, not as a full-fleged proxy;
#	that being said, it has been tested and works with Firefox, IE and Opera, and 
#	should work with any other HTTP/1.1 compliant browser out there. 
#
#	When manually entering a web address in your web browser, it is best to include the 
#	'www' along with the domain you wish to navigate to (i.e., 'www.google.com' instead
#	of just 'google.com').
#
#	Please report any problems to heffnercj [at] gmail.com.
#
#AUTHOR:
#	Craig Heffner 
#	http://www.craigheffner.com
#	heffnercj [at] gmail.com
#	10/09/06
##########################################################################################

use IO::Socket;

#######Change these variables to specify different IP address and port values########

$ip = '127.0.0.1';
$port = '8080';
$host_port = '80';

#####################################################################################

#Check usage
if(!$ARGV[0] || !$ARGV[1]){
	print "\nUsage: ./httprox <Header Title> <Header Value> [-a]\n\nSee the script comments for more details.\n\n";
	exit;
}

#Header to replace
$header=$ARGV[0] .":";

#Value to subsitute
$substitute=$ARGV[1];

#Do we want to add the header instead of replacing it?
if($ARGV[2] eq "-a"){
	$add = 1;
} else {
	$add = 0;
}

#Create a socket listening on $ip:$port
my $sock = new IO::Socket::INET (
			LocalHost => $ip,
			LocalPort => $port,
			Proto => 'tcp',
			Listen => 65535,
			Reuse => 1,
			);
die "Failed to create socket: $!\n" unless $sock;
print "Socket created - listening for connections on $ip:$port\n\n";

#Loop to listen for connections and fork when one is established
do {
	my $conn = $sock->accept();

	#Fork the process
	my $pid = fork(); 
	print "Recieved request - ";

	#If this is a child process, process the request
	if($pid == 0){ 
		#Read the request into $request until CRLF is encountered
		while(<$conn>){
			if($_ eq "\r\n"){
				last;
			}
			$request .= $_;
		}
		
		#Get the destination host name and store it in $host
		($junk, $host1) = split('Host: ',$request);
		($host, $junk) = split("\r\n",$host1);
	
		if($add == 1){
			#Add the header to the end of the request sting
			$request .= $header . " " . $substitute . "\r\n";
		} else {
			#Replace the specified header with the appropriate substitute
			$request =~ s/^$header.+\r$/$header $substitute\r/m;
		}

		#Add the final CRLF to the HTTP request
		$request .= "\r\n";

		#Create connection to the host server
		print "request processed, connecting to $host - ";
		my $host_sock = IO::Socket::INET->new(
					Proto => 'tcp',
					PeerAddr => $host,
					PeerPort => $host_port,
					);
		die "Failed to connect to $host: $!\n" unless $host_sock;	
		
		#Retrieve requested data from host server
		$host_sock->autoflush(1);
		print $host_sock $request;
		while(<$host_sock>){
			$reply .= $_;
		}
		
		#Send data back to browser
		print $conn $reply;

		#Clean up
		print "transfer complete, closing socket.\n";
		close($host_sock);
		close($sock);

		#Kill the child process
		exit; 
	} 

} while(1);
exit;
