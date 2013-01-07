>>>>> "JG" == Jeffrey Goldberg <J.Goldberg@Cranfield.ac.uk> writes:

JG> This will count the addresses in multiple lists multiple times, which
JG> may not be what you want.  To avoid that you have to actaully do some
JG> parsing of addresses to see if they are equivalant, for which perl
JG> would be the right tool.

Good point.  Call this 'countlist' and run 'countlist /path/to/lists'.  It
requires perl5 and MailTools.

#!/usr/local/bin/perl5 -w
use strict;
my(%addrs, $addr, $count, $dir, $file, $total);

use Mail::Address;

($dir, $count, $total) = ($ARGV[0], 0, 0);
opendir(DIR,$dir);

while (defined($file = readdir(DIR))) {
  next if $file =~ /\./;
  open(FILE,"$dir/$file");
  while (<FILE>) {
    chomp;
    $addr = Mail::Address::address(parse Mail::Address $_);
    $count++;
    $addrs{$addr}++;
  }
  printf("Count for %-20s %6s\n", "$file:", $count);
  $total += $count;
  $count = 0;
  close FILE;
}

closedir(DIR);
printf("Total count: %24s\n", $total);
printf("Total different addresses: %10s\n", scalar keys %addrs);

 - J<
