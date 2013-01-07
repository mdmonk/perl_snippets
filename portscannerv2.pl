#!/usr/bin/perl
# Perl port scanner v2, with service ident for open web servers.
# author: Andy Leaning
# Version 1: Plain port scanner.
#         2: Added service identification and web server id, 
#            Additional error checking.

use IO::Socket;
my ( $openport,$reply, %services, $daddr, @reply1, $line, $htmlstring, $socket, $target, $original_port, $port, $maxport );
$htmlstring = "GET \/ HTTP\/1.0\n\n"; # No need for a full get as HEAD will return necessary data.

$maxport=1024; $port,$openport=0;

%services=(
        '7' => 'echo',
        '13' => 'daytime',
        '17' => 'quoted',
        '19' => 'chargen',
        '20'=>'ftp-data','21'=>'ftp','22'=>'ssh',
        '23' => 'telnet',
        '25' => 'smtp',
        '37' => 'time',
        '49' => 'tacacs',
        '53' => 'dns',
        '63' => 'whois','67'=>'bootps','69'=>'tftp',
        '70' => 'gopher',
        '80' => 'web',
        '111' => 'Sun RPC',
        '113' => 'ident',
        '123' => 'ntp',
        '137' => 'Netbios','138'=>'Netbios','139'=>'Netbios',
        '143' => 'IMAP',
        '179' => 'BGP',
        '443' => 'web-ssl',
        '445' => 'SMB',
        '513' => 'rlogin','514'=>'syslog','515'=>'lpr',
        '548' => 'AFP',
        '1433' => 'MS SQL',
        '5631' => 'PCAnywhere','5632'=>'PCAnywhere Data',
        '5800' => 'VNC',
        '5900' => 'VNC');

( $target = $ARGV[0] ) || &error;

$port=$ARGV[1] if $ARGV[1];
$maxport=$ARGV[2]  if $ARGV[2];
$original_port=$port;
&error if ($port>$maxport);


$daddr = inet_aton($target) || die("Can't reach destination: $target"); 

print "\nScanning ports $port to $maxport on '$target'.\n";
foreach (; $port<=$maxport; $port++) 
{
        $socket= new IO::Socket::INET (
                PeerAddr=>"$target:$port",
                Proto=>'tcp',
                Timeout=>'1' ); # Timeout.

        if ($socket) {  # Port listening.
                $openport++; 
                print "\tPort $port ";
                $services{$port} ? print "($services{$port}) OPEN " : print "OPEN ";
                if ( $port==80 ) { # If port 80 open, get http server name.
                        print $socket $htmlstring || die ("ERROR: Can't send reques to web server.\n"); # Send HTTP HEAD request.
                        read $socket, $reply, 500 || die ("ERROR: Can't get reply from web server $target.\n");  # Get reply. 
                        @reply1 = split(/\n/,$reply); # Get server ID string from reply.
                        foreach $line (@reply1) {
                            if ($line =~ /Server/o) { $_=$line; } 
                        }
                        s/Server: //o;  # Strip out unwanted characters on line.
                        s/ .*\r//;
                        print ();
                }
                print "\n"; 
        } 
        close $socket;
}


print "Complete: ", $maxport+1-$original_port," ports scanned, $openport open.\n"; 
exit(0); 

sub error 
{ 
        print "PSCAN\nPSCAN target [ start-port  end-port ]\n"; 
        exit (1); 
}


