#!/usr/bin/perl

$/ = "";	# Blank lines are record separators

@questions = <DATA>;
chomp(@questions);
$howmany = grep($_ !~ /^=/, @questions);
$yes = 0;

$/ = "\n";	# Restore the value

%scores = (
	0   => 'deity',
	5   => 'wizard',
	10  => 'guru',
	20  => 'hacker',
	40  => 'expert',
	60  => 'power user',
	80  => 'user',
	90  => 'novice',
	100 => 'beginner',
);

$checker = qq# sub evaluate { print "Based on your score, you are a Perl ";#;

foreach $value (sort {$a <=> $b} keys %scores) {
	$checker .= << "EOB";
	
	if (\$purity <= $value) {
		print "$scores{$value}.\\n";
		return;
	}
EOB
}

$checker .= "}";


eval $checker;	# Define the subroutine

print <<"EOB";
The Perl Purity Test
Version 1.04, October 16, 1996
Written by Jeff Okamoto (okamoto\@corp.hp.com)
With Help from Tom Christiansen (tchrist\@convex.com)
Other Suggestions from Christopher Davis (ckd\@eff.org)

This is similar to other Purity Tests, of which perhaps the most famous is
the Unisex, Omnisexual Purity Test that can be found in soc.singles.

Additions are welcome.  Please send them to okamoto\@corp.hp.com.

Answer each question with a "yes" or "no".  The program will keep track of
your answers and at the end, tell you your Perl Purity Percentage, and also
a description of what kind of Perl person you are.

There are $howmany questions in this version.

EOB

for (@questions) {
	if (/^=/) {
		print "\n$'\n\n";
		next;
	}
	s/^\.\.\./Have you ever/;
	print "$_ ";
	$answer = <STDIN>;
	last if ($answer =~ /q/);
	$yes++ if ($answer =~ /^[yY]/);
}

print "You answered $yes out of $howmany questions with a yes answer.\n";
$purity = 100. * ($howmany - $yes) / $howmany;
printf("This means your perl purity is %5.2f%%.\n", $purity);

&evaluate;

exit 0;

__END__
=Usage

... rewritten a Unix command in perl?

... rewritten a DOS command in perl?

... emulated a kernel feature inside a program in perl?

... written a compressor/decompressor using pack?

... written scripts that generate other scripts?

... used undocumented features?

... relied on undocumented features?

=Variables

... used reserved keywords as variable names?

... used $x, @x, and %x in a script?

... used $x, @x, %x, and *x in a script?

... not gotten confused when you used $x, @x, %x, and *x all in that script?

... written a script with no alphabetic characters in it?

... wriiten a script with no alphanumeric characters in it?

... used variables with control-characters other than ones already defined?

... created variables at runtime?

=Lists

... used true multi-dimensional arrays?

... used lists of lists?

... used lists of hashes?

=Associative Arrays / Hashes

... used hashes of hashes?

... used hashes of lists?

... used associative array operators on the main symbol table?

=Complex Data Structures

... used more than two levels of lists and/or hashes?

=Functions

... created functions at runtime (with eval)?

... written a function that returns different types? (e.g., scalar, list, etc.)

... called a subroutine with the & operator and no arguments so that the
	child function inherited what remains of the caller's argument
	stack, @_?

... changed function definitions at runtime?

... used wantarray?

... returned a "0 but true" scalar?

=Loop Controls

... used do BLOCK inside an EXPR?

... used loop controls (e.g., last, next, etc.) from inside a signal handler?

... created a loop label at runtime?

=Operators

... used the scalar ".." operator?

... used it with things other than line numbers, array indices, or regexps?

... used syscall?

=Searching and Replacing

... used the /e switch?

... used the /ee switch?

... used more than two "e"'s in this kind of construct?

=Handles

... used arrays of file handles?

... used indirect file handles?

... used doubly indirect file handles?

... used a directory handle as a file handle?

... used a file handle as a directory handle?

... used a reference to a filehandle typeglob?

=Regexps

... used all nine sets of parentheses in a regexp?

... used more than nine sets of parentheses in a regexp?

... used nested parentheses in a regexp?

... wished for an equivalent to LISP's meta-close character "]",
	which closes all currently open parentheses?

=Grep

... used grep on non-arrays?

... nested grep within another grep (for a total of two greps)?

... nested up to five greps within one statement?

... nested more than five greps within one statement?

=Evals

... written self-modifying evals?

... used eval to test for features your brain-damaged version of Unix
	doesn't have?

... used eval/die to emulate setjmp/longjmp?

... nested an eval inside another eval (for a total of two nested evals)?

... used up to five nested evals?

... used more than five nested evals?

=References

... used references?

... used lists of references?

... used hashes of references?

... used references to create a constant literal?

... used references to create a variable at runtime?

... lost what your reference was pointing to and didn't care?

=I/O

... used stream sockets?

... used datagram sockets?

... used RPC?

=Debugging

... used the -D flag?

... used the -D1024 flag?

... figured out what all that debugging info meant?

... used the perl debugger?

... modified the perl debugger?

=Packages

... written your own package?

... used packages to emulate C structures?

... referenced a package's symbol table via %_packagename?

=Ties

... tied a hash to a *DBM class instead of using dbmopen?

... written a package to tie a hash to a scalar?

... written a package to tie a hash to an array?

... written a package to tie a hash to a hash?

=User Subroutines (Perl 4)

... gotten frustrated with the documentation of how to link in user
	subroutines?

... written a subroutine to be linked in with uperl.o so that your routine
	can be called from a perl script?

... replaced your version of perl with a version that has your subroutine(s)?

=Scoping

... abused dynamic scoping by fudging @ARGV?

... abused dynamic scoping and changed the names of functions?

=h2ph

... debugged the result of h2ph?

... hacked on h2ph?

=c2ph

... debugged the result of c2ph?

... hacked on c2ph?

... ported gcc to your platform just so you can use c2ph?

=Heavy Wizardry

... used autoloading functions in Perl 4?

=Extensions

... used an extension that ships with Perl?

... used an extension you downloaded from CPAN?

... written your own extension?

... translated a Perl 4 user subroutine into an extension?

... written a Dynamic Loader function?

... used the AutoLoader extension?

=The Source of Taintedness

... used taintperl?

... tried to subvert the TAINT checks?

... read the source to see what happens if you successfully subvert the TAINT
	checks?

... changed the source to change what happens if you successfully subvert the
	TAINT checks?

... tried to read the source?

... found the comment "/* Heavy wizardry */" other than by deliberately
	searching for it now that you know it exists?

... used suidperl?

=The Father, the Son, and the Holy Ghost

... sent mail to Larry asking for help?

... sent mail to Larry reporting a bug in perl?

... sent mail to Larry requesting a feature?

... gotten a reply from Larry (as opposed to his autoreplier)?

... gotten more than ten autoreplies from Larry within a 24-hour period?

... heard Larry play the violin?

... sent mail to Randal asking for help?

... sent mail to Randal reporting a bug in perl?

... sent mail to Randal with a JAPH script?

... heard that Randal is a convicted felon?

... read the home page detailing the circumstances of how Randal became
	a convicted felon?

... donated money to Randal's Legal Defense Fund?

... had trouble remembering how many l's there are in Randal's name?

... sent mail to Tom asking for help?

... sent mail to Tom reporting a bug in perl?

... attended any of Tom's perl tutorials at a USENIX conferences?

... attended any one of Tom's perl tutorials at a USENIX conference
	two or more times?

... sent mail to Tom pointing out an error in his slides?

... had a requested feature be included in a subsequent set of patches?

... had up to five requested features included?

... had more than five requested features included?

... met Larry, Randal, and Tom?

... met Larry, Randal, and Tom all at once or within a few hours of each other?

=Trivia

... written a "Just another Perl hacker" script?

... written up to five JAPH scripts?

... written more than five JAPH scripts?

... written any perl poems?

... run these perl poems?

=Miscellaneous Stuff

... used unquoted strings?

... used unquoted strings unintentionally?

... called seek on the __DATA__ file handle to reread your script?

... tried to use a bi-directional pipe?

... realized why this is a waste of time?

... used co-routines in a perl script?

... written a script that used command-line switches?

... used up to five command-line switches?

... more than five command-line switches?

... run into problems with how many characters after "#!" are allowed
	by your version of Unix?

... counted how many perl functions are overloaded?

... had a "JAPH" script placed on your business card?

=POD

... written a script with its own man page embedded in it?

... had a requested feature added to the Pod definition?

=Perl 5 Porters

... been a subscriber to the perl5-porters mailing list?

... submitted a patch to the p5p ML?

... held the patch pumpkin?

... wondered why it's called the "patch pumpkin"?

... found out who coined the phrase "patch pumpkin"?

=CPAN

... accessed CPAN?

... had your own directory under CPAN?

=Perl 3:16

... referred to the fuchsia Camel book?

... bought the fuchsia Camel book?

... bought multiple copies of the fuchsia Camel book because you wore out
	the previous copies?

... owned more than one edition of the fuchsia Camel book?

... owned more than one copy of every edition of the fuchsia Camel book?

... owned an autographed copy of the fuchsia Camel book?

... wondered why Larry and Randal chose a camel for the cover
	of the fuchsia Camel book?

... found out why Larry and Randal chose a camel for the cover
	of the fuchsia Camel book?

... referred to the blue Camel book?

... bought the blue Camel book?

... bought multiple copies of the blue Camel book because you wore out
	the previous copies?

... referred to the Llama book?

... bought the Llama book?

... bought multiple copies of the Llama book because you wore out the
	previous copies?

... owned more than one edition of the Llama book?

... owned more than one copy of every edition of the Llama book?

... owned an autographed copy of the Llama book?

... wondered why Larry and Randal chose a camel for the cover
	of the Llama book?

... found out why Larry and Randal chose a camel for the cover
	of the Llama book?

... written a book about Perl?

... owned an O'Reilly Camel T-shirt?

... owned more than one O'Reilly Camel T-shirt?

... owned an O'Reilly Llama T-shirt?

... owned more than one O'Reilly Llama T-shirt?

... owned an autographed O'Reilly Perl shirt (of any lineage)?

=USENET

... read any of the newsgroups in the comp.lang.perl.* hierarchy?

... posted to any of the newsgroups in the comp.lang.perl.* hierarchy?

... read the original comp.lang.perl newsgroup?

... posted to the original comp.lang.perl newsgroup?

... applied a kill file to either the comp.lang.perl newsgroup or any
	newsgroup in the comp.lang.perl.* hierarchy?

