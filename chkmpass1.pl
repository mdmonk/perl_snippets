#!/usr/bin/perl
######################################################
#
######################################################

use Mail::IMAPClient;
use Getopt::Std;

getopts('ds:u:p:');

$opt_s = 'popmail.rmi.net' unless($opt_s);
$opt_u = 'z9563'           unless($opt_u);
$opt_p = '4ut0t34m'        unless($opt_p);

my $imap = Mail::IMAPClient->new(Server   => $opt_s, 
                                 User     => $opt_u,
                                 Password => $opt_p,
#                                 Debug    => 1,
);

#$imap->Debug($opt_d);

my @folders = $imap->folders;

foreach my $f (@folders) { 
   print "$f is a folder with ",
          $imap->message_count($f),
          " messages.\n";
}
