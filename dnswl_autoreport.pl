#!/usr/bin/perl

# (c) 2011 Darxus@ChaosReigns.com, released under the GPL.
#
# Reports a spam email to DNSWL.org.
#
# You must be sure you don't have any trusted IPs forwarding mail to
# you, like proxies or mailing lists.  That would require something like
# SpamAssassin's trusted_networks functionality, which this lacks.
#
# To use this you need to create an account here:
# http://www.dnswl.org/registerreporter.pl
#
# Usage: cat spam.txt | ./dnswl_autoreport.pl
# One email at a time.
# 
# You must have a config file $HOME/.dnswl_autoreportrc containing:
# $address = 'email@example.com';
# $password = 'password';
#
# Returns 0 on success, and 1 on failure.
#
# 2011-02-21 Initial release.

use warnings;
use strict;
use LWP::UserAgent;

my $user = '';
my $pass = '';

open CONF, "<$ENV{HOME}/.dnswl_autoreportrc" or die "Couldn't read config file ~/.dnswl_autoreportrc: $!";
while (my $line = <CONF>) {
  chomp $line;
  if ($line =~ m#address.*=.*['"](.+)['"].*;#) {
    $user = $1;
  } elsif ($line =~ m#password.*=.*['"](.+)['"].*;#) {
    $pass = $1;
  }
}
close CONF;

unless ($user ne '' and $pass ne '') {
  die "Username / address or password not properly defined.";
}

local $/;

my $email = <STDIN>;

my %form = (
  'action', 'save',
  'abuseReport',$email,
);

my $ua = LWP::UserAgent->new;

my $netloc = 'www.dnswl.org:80';
my $realm = 'dnswl.org Abuse Reporting';
$ua->credentials( $netloc, $realm, $user, $pass );

my $response = $ua->post('http://www.dnswl.org/abuse/report.pl', \%form);
 
# I've seen this form return "IP ... matches with DNSWL" but not "Thank
# you for your report", in which case the report doesn't get saved to
# the database.  So check for this case.

my $reportedip = '';
if ($response->is_success) {
  if ( $response->content =~ m#IP ([\d\.]+) matches with DNSWL# ) {
    my $reportedip = $1;
    print "DNSWL: Reported IP: $reportedip.\n";
  }
  if ( $response->content =~ m#Thank you for your report# ) {
    print "DNSWL: Successfully reported.\n";
    exit 0;
  } elsif ( $response->content =~ m#No matching entry found for IP ([\d\.]+)#) {
    my $reportedip = $1;
    print "DNSWL: Successfully reported $reportedip.  Current trust level is: Unlisted.\n";
    exit 0;
  } else {
    print "DNSWL: Failed to report, acknowledgement not received.\n";
    print "DNSWL: SUBMISSION FORM IS BROKEN.\n" if ($reportedip eq '');
    exit 1;
  }
} else {
  print "DNSWL: Failed to report: ". $response->status_line ."\n";
  exit 1;
}
