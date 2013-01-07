#!/usr/bin/perl

# 
# (c) 1994-2002 Jeff Ballard
#

#
# According to Ben Okopnik Perl >= 5.6 does worse with srand than without
# it.  If you need BETTER randomness than this... well it will be hard to
# tell if you are just evil or in serious need of a self-LART.
#

srand(time|$$) if $[ < 5.6;


open (EXCUSES, "/home/ballard/bofhserver/excuses") || die;
@excuses=();

$i=0;
while(<EXCUSES>) {
        $excuses[$i]=$_;
        $i++;
}       
close EXCUSES;

$j = (rand(10000)*$$)%$i;

print "=== The BOFH-style Excuse Server --- Feel The Power!\n";
print "=== By Jeff Ballard <ballard\@cs.wisc.edu>\n";
print "=== See http://www.cs.wisc.edu/~ballard/bofh/ for more info.\n";
print "Your excuse is: $excuses[$j]";
