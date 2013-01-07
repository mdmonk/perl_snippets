#!/usr/bin/perl

########################################################
# telnet daemon check                 [November 9, 1998] 
#                 Packet Storm Security
#        http://www.Genocide2600.com/~tattooman/
#
# *Most of this code ripped directly from ftpcheck.pl
# *by David Weekly <dew@cs.stanford.edu>
# *http://david.weekly.org/code 
#
# Thanks to Shane Kerr for cleaning up the process code!
#
# This code is under the GPL. Use it freely. Enjoy.
#        Debug. Enhance. Email me the patches!
########################################################

use Socket;
use Net::Telnet ();

# timeouts in seconds for creating a socket and connecting
my $MAX_SOCKET_TIME = 2;
my $MAX_CONNECT_TIME = 3;

my $HELP=qq{Usage: telnetdcheck [-h | --help] [-p processes] [-d | --debug] host\n};


my @hosts;

# how many simultaneous processes are we allowed to use?
my $MAX_PROCESSES=10;
my $DEBUG=0;

while($_=shift){
    if(/^--(.*)/){
	$_=$1;
	if(/help/){
	    print $HELP;
	    exit(0);
	}
	if(/debug/){
	    $DEBUG=1;
	}
    }    
    elsif(/^-(.*)/){
	$_=$1;
	if(/^h/ or /^\?/){	    
	    print $HELP;
	    exit(0);
	}
	if(/^p/){
	    $MAX_PROCESSES=shift;
	}
	if(/^d/){
	    $DEBUG=1;
	}
    }else{
	push @hosts,$_;
    }
}

if(!$hosts[0]){
    print $HELP;
    exit(-1);
}

my $host;
$|=1;
print "\n\nTelnetd check by Ken Williams, Packet Storm Security.\n";
print " http:\/\/www.Genocide2600.com\/\~tattooman\/index.shtml\n\n";

# go through all of the hosts, replacing subnets with all contained IPs.
for $host (@hosts){
    $_=shift(@hosts);

    # scan a class C
    if(/^([^.]+)\.([^.]+)\.([^.]+)$/){
	my $i;
	print "Expanding class C $_\n" if($DEBUG);
	for($i=1;$i<255;$i++){
	    my $thost="$_.$i";
	    push @hosts,$thost;
	}
    }
    else{
	push @hosts,$_;
    }
}

my @pids;
my $npids=0;

for $host (@hosts){
    my $pid;
    $pid=fork();
    if($pid>0){
	$npids++;
	if($npids>=$MAX_PROCESSES){
	    for(1..($MAX_PROCESSES)){
		$wait_ret=wait();
		if($wait_ret>0){
		    $npids--;
		}
	    }
	}
	next;
    }elsif(undef $pid){
	print "fork error\n" if ($DEBUG);
	exit(0);
    }else{
	my($proto,$port,$sin,$ip);
	print "Trying $host\n" if ($DEBUG);
	$0="(checking $host)";

	# kill thread on timeout
	local $SIG{'ALRM'} = sub { exit(0); };

	alarm $MAX_SOCKET_TIME;
	$proto=getprotobyname('tcp');
	$port=23;
	$ip=inet_aton($host);
	if(!$ip){
	    print "couldn't find host $host\n" if($DEBUG);
	    exit(0);
	}
	$sin=sockaddr_in($port,$ip);
	socket(Sock, PF_INET, SOCK_STREAM, $proto);

	alarm $MAX_CONNECT_TIME;
	if(!connect(Sock,$sin)){
	    exit(0);
	}
	my $iaddr=(unpack_sockaddr_in(getpeername(Sock)))[1];
	close(Sock);       
	
	# SOMETHING is listening on the telnet daemon?
	
	print "listen $host!\n" if($DEBUG);
	alarm 0;
	$hostname=gethostbyaddr($iaddr,AF_INET);

	# create new telnet connection w/10 second timeout
	$telnet = new Net::Telnet (Timeout => 10, Prompt => '/bash\$ $/');
	if(!$telnet){
	    print "      <$host ($hostname) denied you>\n" if($DEBUG);
	    exit(0);
	}
	if(!$telnet->login("anonymous","just-checking")){
	    print "   Telnet Daemon on $host [$hostname]\n";
	    exit(0);
	}

	print "Telnet Daemon on $host [$hostname]\n";

	$telnet->quit;
	exit(0);
    }
}

print "done spawning, $npids children remain\n" if($DEBUG);

# wait for my children
for(1..$npids){
    my $wt=wait();
    if($wt==-1){
	print "hey $!\n" if($DEBUG);
	redo;
    }
}

print "\nDone\n\n";
