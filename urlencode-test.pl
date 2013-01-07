#!/usr/bin/perl
 
use URI::Escape;
 
my $string = "http://www.newmont.com";
my $encode = uri_escape($string);
 
print "Original string: $string\n";
print "URL Encoded string: $encode\n";
