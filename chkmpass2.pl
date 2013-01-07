#!/usr/bin/perl
#######################################################
#
#######################################################
use Mail::POP3Client;
use Getopt::Std;

$|++;

getopts('vdu:p:s:i:o:');

$VERSION  = '0.1.0';
$VDATE    = '10/10/2000';

if ($opt_v) {
  print "\n\n  Mail Password Checker-Upper\n  written by: Chuck Little\n";
  die "  version: $VERSION, date: $VDATE\n\n";
} # end if

if ($opt_i) {
   chomp($opt_i);
   $EMAIL_FILE = $opt_i;
} else {
   # $EMAIL_FILE = "email_addrs.txt";
   $EMAIL_FILE = "email_out.csv";
} # end if

if ($opt_o) {
   chomp($opt_o);
   $OUT_FILE = $opt_o;
} else {
   $OUT_FILE = "tsk_tsk.cwl";
} # end if

$opt_s = 'popmail.rmi.net' unless ($opt_s);
$opt_u = 'z9563'           unless ($opt_u);
$opt_p = 'msh9TE'          unless ($opt_p);

if ($opt_d) {
   $opt_d = 1;
} else {
   $opt_d = 0;
} # end if-else

open (INFILE, "<$EMAIL_FILE") or die "Unable to open $EMAIL_FILE: $!\n";
open (OUTFILE, ">$OUT_FILE") or die "Unable to open $OUT_FILE: $!\n";

$pop = new Mail::POP3Client (HOST     => $opt_s,
                             PASSWORD => $opt_p,
                             DEBUG    => $opt_d,
                             TIMEOUT  => 5,
                            );

foreach (<INFILE>) {
   
   my ($user, $fullName) = split (/\,/, $_);
   chomp($user);
   chomp($fullName);

   $pop->User($user)

   $pop->Connect() || die $pop->Message();

   if ($pop->Connect()) {
      print OUTFILE "$user: $fullName: Still Default Password! Tsk! Tsk! Tsk!";
   } # end if

} # end foreach

close (OUTFILE);
close (INFILE);

#if ($pop) {
#   print "$opt_u: You are using the default password. Tsk, Tsk...\n";
#} else {
#   print "$opt_u: I was unable to log on to your account\n";
#} # end if

#for( $i = 1; $i <= $pop->Count(); $i++ ) {
#   foreach( $pop->Head( $i ) ) {
#      /^(From|Subject):\s+/i && print $_, "\n";
#   } # end foreach
#} # end for

$pop->Close();

# OR
#$pop2 = new Mail::POP3Client( HOST  => "pop3.otherdo.main" );
#$pop2->User( "somebody" );
#$pop2->Pass( "doublesecret" );
#$pop2->Connect() || die $pop2->Message();
#$pop2->Close();
