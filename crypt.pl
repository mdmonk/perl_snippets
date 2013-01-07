#!/usr/bin/perl
print "Enter your password: ";
chomp($password = <STDIN>);
$salt = sprintf("%02x",($$^time^rand)&0xFF);
print "Your encrypted password: ".crypt($password,$salt)."\n";
