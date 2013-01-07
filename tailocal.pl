#!/usr/bin/perl

use POSIX qw(strftime);

while (<>) {
   if (m/(\d+)\s(.*)/) {
       print strftime("%Y-%m-%d %T ", localtime($1)), "$2\n";
   }
}
exit (0);
