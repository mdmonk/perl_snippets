#!/usr/bin/perl
use warnings;
use strict;
$SIG{INT} = "CtlBreak";

if (! $ARGV[0]) {
	print ("Type a message and I will shift it 13 characters: ");
	chomp (my $Rot13Input = <STDIN>);
	&Decode ($Rot13Input);
}
elsif (lc$ARGV[0] =~ "-f") { &DecodeFile; exit 0; }
elsif (lc$ARGV[0] =~ "-h" or lc$ARGV[0] =~ "help") { print ("Just type $0 [enter] and you will be prompted. Or use -f <filename> to look at a file.\n"); }
else { &Decode ($ARGV[0]); exit 0;};
exit 0;

sub DecodeFile {
	if (! $ARGV[1]) { die ("You need to provide me with a filename.\n") }
	open (InFile, $ARGV[1]) || die ("Unable to open $ARGV[1]\n");
	my @RotArray = <InFile>;
	close (InFile);
	foreach (@RotArray) {
		&Decode ($_); 
	}
	return;
}
	
sub Decode {
print ("\nMessage: \n");
	my $Rot13 = $_[0]; 
        $Rot13 =~ (tr/a-zA-Z/n-za-mN-ZA-M/);
        print "\t\t$Rot13\n\n";
        return;
}

sub CtlBreak {
        die ("Someone doesn\'t love me anymore.\n");
}

