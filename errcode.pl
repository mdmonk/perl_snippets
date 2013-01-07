#!/usr/bin/perl
use warnings; use strict;

# usage: errcode num [num2]

my ($path,$file,$errn,$ferrn);

# set the path to the header file
$path = '/System/Library/Frameworks/'
.'CoreServices.framework/Versions/Current/Frameworks/'
.'CarbonCore.framework/Versions/Current/Headers/MacErrors.h';

# open it and search for each argument.
while($errn=shift){
    $ferrn=" "x(6-length($errn))."($errn): ";
    open $file, '<', $path;
    while(<$file>){
        print $1, $ferrn, $2||"[no description]", "\n"
            if (m!^\s*(\S*\s+)\s=\s$errn[,]?\s+(?:/\*\s?(.*?)\s?\*/\s*)?$!);
    } close $file;
} exit 0;
