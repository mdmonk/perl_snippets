#!/bin/perl -w
#
# This is a Lotus Notes Client written in Perl
#

use strict;
use Win32::OLE;

my %count;
my $Buffer;
my $choice;
my $doc;
my $Document;
my %noteshash = ();
my $num;
my $userid = "x";
my $search;
my $server = "x/x";
my $val;
my $VERSION = '1.0';

my $Notes = Win32::OLE->new('Notes.NotesSession')or die "Cannot start 
+Lotus Notes Session object.\n";
my $Database = $Notes->GetDatabase("$server", "mail\$userid.nsf") or d
+ie "Could not open database.\n";
my $AllDocuments = $Database->AllDocuments;
my $Count = $AllDocuments->Count;
my @counted = (1 .. $Count);

print "\n\nPlease wait while the notes mail file is processed . . .\n\
+n";
foreach $doc (@counted) {
	$Document = $AllDocuments->GetNthDocument($doc);
	$val = sprintf "$doc. %s", $Document->GetFirstItem('Subject')-
	+>{Text};
	$noteshash{$doc}=$val;
}

while ($choice ne "Q"){
	print "\n\nWelcome to the Perl Notes client.\n";
	print "Press I to look at an index of email.\n";
	print "Press B to look at the body of a message.\n";
	print "Press Q to exit the program.\n";
	chomp($choice = <STDIN>);
	$choice =~ tr/a-z/A-Z/;
	
	if ($choice eq "I") {
		&idex;  
	}
	
	if ($choice eq "B") {
		&body;
	}
	
	if ($choice eq "Q") {
		exit;   
	}
}

sub idex {
	my $docnum;
	
	print "What is the first number you would like to see? ";
	chomp($docnum = <STDIN>);
	
	my $limit = $docnum + 5;
	for ($docnum; $docnum < $limit; $docnum++) {
		print "Number: $doc Subject: $noteshash{$docnum}\n";
	}
}

sub body {
	print "What document would you like to look at? ";
	chomp($doc = <STDIN>);
	$Document = $AllDocuments->GetNthDocument($doc);
	my @Attributes = $Buffer->info();
	printf "\n\n$doc. %s\n", $Document->GetFirstItem('Body')->{Text};
}

=head1 NAME

getnotes - This script gets all the documents in a notes database and 
+prints out a document by number.

=head1 DESCRIPTION

This is my first attempt at accessing notes databases from perl.  I ca
+n think of some interesting uses for notes and perl.
I would specifically like to pull an email and compare it with a list 
+from another file.  This script is still in beta.

=head1 README

This script gets all the documents in a notes database and prints out 
+a document by number.

=head1 PREREQUISITES

This script has a few requirements.  You will need the Win32::OLE modu
+le.
You will also need to change the values for nsf and server.

=head1 COREQUISITES

None

=pod OSNAMES

MSWin32

=pod SCRIPT CATEGORIES

Win32

=cut
		