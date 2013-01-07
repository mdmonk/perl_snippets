#!/s/std/bin/perl

#
# (c) 1994-2000 Jeff Ballard.
#

open(F, "/u/b/a/ballard/public/html/bofh/excuses") || print "Content-type: text/html\n\nAck...can't read the excuse file! Don't expect the rest to work.\n"; 

srand(time);

$number=0;
@excuse = ();
while( $excuse[$number] = <F>) {
	$number++;
}

$thisexcuse = $excuse[ (rand(1000)*$$)%($number+1) ];

print "Content-type: text/html\n";
print "\n";
print "<title>\"Bastard Operator From Hell\"-Style Excuses</title>\n";

print "<center><font size = \"+2\">";
print "<a href = \"http://www.cs.wisc.edu/~ballard/bofh/\">";
print "\"The Bastard Operator From Hell\"-style excuse server.";
print "</a></font>";
print "<Hr><br>";
print "The cause of the problem is:<br>";
print "<font size = \"+2\">";
print "$thisexcuse</font>";
print "<BR><BR><HR>";
print "The BOFH-style excuse generator brought to you by";
print " <a href = \"http://www.cs.wisc.edu/~ballard/\">";
print "Jeff Ballard</a>.";

exit(0);


