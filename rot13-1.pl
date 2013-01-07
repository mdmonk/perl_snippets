#!/usr/bin/perl
foreach ('a'..'m', 'A'..'M') {
    $q = chr(ord($_)+13);
    $p{$_} = $q; $p{$q} = $_;
}
while (<>) { s#(.)#$p{$1}#g; print; }

