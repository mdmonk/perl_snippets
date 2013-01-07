#!/usr/bin/perl


use Getopt::Std;

getopts("S:r:");

my $SUBJECT = $opt_S if defined $opt_S;
my $RECIPIENT = $opt_r if defined $opt_r;

open OUTFILE, "|/usr/sbin/sendmail $RECIPIENT";

print OUTFILE "Subject: $SUBJECT\n\n";
while (<>) {
	print OUTFILE $_;
}

