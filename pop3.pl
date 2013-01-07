#!D:/apps/perl/5.005/bin/perl.exe -ws

my ($login) = 'mdmonk';	# modify me
my ($password) = '4ut0m4t10n';	# modify me
my ($server) = 'mindresearch.cas.ilstu.edu';	# modify me

print <<EOH and exit 0 if $h or $help;

Usage: $0 [-d(ebug)] [-r(emove_msgs)]

EOH

$debug = 0;
$debug = 1 if $d;

$remove_msgs = 0;
$remove_msgs = 1 if $r;

1 if ($d or $r or $h or $help) and $^W;

binmode STDOUT; $| = 1; binmode STDERR;

use Socket qw (PF_INET SOCK_STREAM AF_INET);

my ($sockaddr) = 'S n a4 x8';
my ($port) = getservbyname ('pop3', 'tcp') || 110;
my ($addr, $host, $msgs, $i);

if ($server =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
        $addr = pack ('C4', $1, $2, $3, $4);
} else {
        $addr = gethostbyname ($server) or 
	  die "Could not gethostybyname: $server, $!\n";
}
$host = gethostbyaddr ($addr, AF_INET);
print STDERR "addr=$addr, host=$host\n" if $debug;

socket (SOCK, PF_INET, SOCK_STREAM, getprotobyname ("tcp") || 6) or
  die "Could not open socket: $!\n";

connect (SOCK, pack ($sockaddr, AF_INET, $port, $addr)) or
  die "Could not connect $host/$port: $!\n";

select ((select (SOCK), $| = 1)[0]);

print STDERR "about to read from socket\n" if $debug;

$_ = <SOCK> or die "Could not read from socket: $!\n";
print STDERR "rcvd $_\n" if $debug;

print STDERR "USER $login\r\n" if $debug;
print SOCK "USER $login\r\n";

$_ = <SOCK>; chop;
print STDERR "rcvd $_\n" if $debug;
/^\+/ or die "USER $login failed: $_\n";

print STDERR "PASS $password\r\n" if $debug;
print SOCK "PASS $password\r\n";

$_ = <SOCK>; chop;
print STDERR "rcvd $_\n" if $debug;
/^\+/ or die "PASS $password failed: $_\n";

print STDERR "RSET\r\n" if $debug;
print SOCK "RSET\r\n";

$_ = <SOCK>; chop;
print STDERR "rcvd $_\n" if $debug;
/^\+/ or die "RSET failed: $_\n";

print STDERR "STAT\r\n" if $debug;
print SOCK "STAT\r\n";

$_ = <SOCK>; chop;
print STDERR "rcvd $_\n" if $debug;
/^\+OK/ or die "STAT failed: $_\n";
/^\+OK\s*(\d+)/;

$msgs = $1;

if ($msgs > 0) {

        for ($ii = 1; $ii <= $msgs; $ii++) {

                print STDERR "RETR $ii\r\n" if $debug;
                print SOCK "RETR $ii\r\n";
                $_ = <SOCK>; chomp;
		print STDERR "rcvd $_\n" if $debug;
                /^\+OK/ or die "RETR of message $ii failed: $_\n";
                /^\+OK (\d+)/;
                while (<SOCK>) {
                        last if /^\.\s*$/;
                        print;
                }
		if ($remove_msgs) {
                	print SOCK "DELE $ii\r\n" if $debug;
                	$_ = <SOCK>; chop;
                	/^\+OK / or die "Could not DELE $ii: $_\n";
        	}
        }
}

print STDERR "QUIT\r\n" if $debug;
print SOCK "QUIT\r\n";

shutdown (SOCK, 2) or die "shutdown failed: $!\n";
close SOCK;

exit 0;
