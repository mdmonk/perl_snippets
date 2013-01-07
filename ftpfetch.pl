#!/usr/bin/perl

use Net::FTP;
use Getopt::Long;

$opt_debug = undef;
$opt_firewall = undef;

GetOptions(qw(debug firewall=s));

@firewall = defined $opt_firewall ? (Firewall => $opt_firewall) : ();

if (scalar(@ARGV) < 4) {
	die "Usage: perl ftp {host} {username} {password} {file}\n";
}

($host, $user, $pass, $file) = @ARGV;

$ftp = Net::FTP->new($host, @firewall, Debug => $opt_debug ? 1 : 0);
print 'logging in, username=', $user, ' password=xxxxxxxx', "\n";
$ftp->login($user, $pass);
print 'pwd: ', $ftp->pwd,"\n";
print 'getting file: ', $file, "\n";
$ftp->get($file, $file);
$ftp->quit;
