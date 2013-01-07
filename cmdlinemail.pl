# This script sends a test mail to a mail server using a socket connection
# This is far from a full mail implementation but demonstrates perl socket
# Programming.

#!/usr/bin/perl
( $them, $port ) = @ARGV;

$port = 25 unless $port;
#$them = 'localhost' unless $them;
$them ='robinsc' unless $them;# Change to your smtp server
$AF_INET = 2;
$SOCK_STREAM = 1;

$SIG{'INT'} = 'dokill';
sub dokill {
    kill 9,$child if $child;
}

$sockaddr = 'S n a4 x8';

#chop($hostname = `hostname`);
#print $hostname;
($name,$aliases,$proto) = getprotobyname('tcp');
($name,$aliases,$port) = getservbyname($port,'tcp')
    unless $port =~ /^\d+$/;;
($name,$aliases,$type,$len,$thisaddr) =
        gethostbyname($hostname);
($name,$aliases,$type,$len,$thataddr) = gethostbyname($them);

$this = pack($sockaddr, $AF_INET, 0, $thisaddr);
$that = pack($sockaddr, $AF_INET, $port, $thataddr);

if (socket(S, $AF_INET, $SOCK_STREAM, $proto)) { 
    print "socket ok\n";
}
else {
    die $!;
}

if (bind(S, $this)) {
    print "bind ok\n";
}
else {
    die $!;
}

if (connect(S,$that)) {
    print "connect ok\n";
}
else { 
    die $!;
}

select(S); $| = 1; select(STDOUT);

#while( <STDIN> ) {
#    print S;
#}
$a=<S>;print "$a";
print S "HELO CHUCKSC\n";
$a=<S>;print "HELO CHUCKSC\n $a";
print S "MAIL FROM:<MONTYP>\n";
$a=<S>;print "MAIL FROM:<MONTYP>\n $a";
print S "RCPT TO:<CHUCK>\n";
$a=<S>;print "RCPT TO:<CHUCK>\n $a";# change to your mail id
print S "DATA \n";
$a=<S>;print "DATA \n $a";
print S "this is a test 1\n";
print "this is a test 1\n ";
print S ".\n";
$a=<S>;print ".\n $a";
print S "QUIT";
print "QUIT ";
exit 1 ;
