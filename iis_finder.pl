#!/bin/perl
##
## This script test for most of the methods used by WebDAV
## If the server does not complain about the method its an indication
## that WebDAV is in use..
##
## Please see http://www.microsoft.com/technet/treeview/default.asp?url=/technet/security/bulletin/MS03-007.asp
## for info why this is interesting..
##
## SensePost Research
## research@sensepost.com
## 2003/3/17
## RT

$|=1;
use Socket;

@methods = ("PROPFIND","PROPPATCH","MCOL","PUT","DELETE","LOCK","UNLOCK");

if ($#ARGV<1){die "parameters: IP/dns_name port\n";}

$target=@ARGV[0];
$port=@ARGV[1];

print "Testing WebDAV methods [$target $port]\n-------------------------------------\n";

@results=sendraw2("HEAD / HTTP/1.0\r\n\r\n",$target,$port,15);
if ($#results < 1){die "15s timeout to $target on port $port\n";}

foreach $line (@results){
	if ($line =~ /Server:/){
		($left,$right)=split(/\:/,$line);
		$right =~ s/ //g; 
		print "$target : Server type is $right";
		if ($right !~ /Microsoft-IIS\/5.0/i){
			print "$target : Not a Microsoft IIS 5 box\n";
			exit(0);
		}
	}
}

foreach $method (@methods){
	
	@results=sendraw2("$method /test/nothere HTTP/1.0\r\n\r\n",$target,$port,15);
	if ($#results < 1){print "15s timeout to $target on port $port\n";}

	 $okflag=0;
	 foreach $line (@results){
	
		if ($line =~ /Method Not Supported/i){
			print "Method $method is not allowed\n";
			$okflag=1;
		}
		if (($line =~ /method/i) && ($line =~ /not allowed/i)){
			print "Method $method is not allowed\n";
			$okflag=1;
		}
	}
	if ($okflag==0){
		print "Method $method seems to be allowed - WebDAV possibly in use\n";
	}
}

########## Sendraw-2
sub sendraw2 {
        my ($pstr,$realip,$realport,$timeout)=@_;
        my $target2 = inet_aton($realip);
        my $flagexit=0;
        $SIG{ALRM}=\&ermm;
        socket(S,PF_INET,SOCK_STREAM,getprotobyname('tcp')||0) || die("Socket problems");
        alarm($timeout);
        if (connect(S,pack "SnA4x8",2,$realport,$target2)){
                alarm(0);
                my @in;
                select(S); $|=1;
                print $pstr;
                alarm($timeout);
                while(<S>){
                        if ($flagexit == 1){
                                close (S);
                                print STDOUT "Timeout\n";
                                return "Timeout";
                        }
                        push @in, $_;
                }
                alarm(0);
                select(STDOUT);
                close(S);
                return @in;
        } else {return "0";}
}
sub ermm{
        $flagexit=1;
        close (S);
}
