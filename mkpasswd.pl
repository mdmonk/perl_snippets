#!/usr/bin/perl
srand(time() ^ ($$ + ($$ << 15)));
print "Content-type:text/html\n\n"; 
if ($ENV{'REQUEST_METHOD'} eq 'GET') { $buffer = $ENV{'QUERY_STRING'}; }else
{ read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'}); } @pairs = split(/&/,
$buffer); 
foreach $pair (@pairs) {
   ($name, $value) = split(/=/, $pair);
   $value =~ tr/+/ /;
   $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
   $FORM{$name} = $value;
}
print "$FORM{'username'}:"; 
print crypt($FORM{'password'},(chr(int(rand 94)+33) . chr(int(rand 94)+33) ));