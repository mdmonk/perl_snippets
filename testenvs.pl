#!/usr/bin/perl

# testenvs.pl - by CommPort5 [@LucidX.com]
# some of this code is a hacked up version of v9's getenv program
# for finding envs in binary programs

$SIG{INT} = \&data;
$SIG{'TSTP'} = \&data;

die "usage: $0 < /path/to/binary >\n" unless @ARGV == 1;

@ignore = split(/\s+/,
"TERM USER TTOU TTIN TSTP STOP CONT CHLD STKFLT ALRM PIPE USR2 SEGV USR1 KILL FPE BUS IOT ABRT TRAP ILL QUIT INT HUP _DYNAMIC _GLOBAL_OFFSET_TABLE_ --");

print "testenvs.pl :: tests environment variables in binary programs for buffer overflows\n";

open(BINARY, shift) || die "Can't open file: $!\n";
@read = <BINARY>;
close(BINARY);
$i = 0;
$tokens = @read;
while ($read[$i]) {
 @tmpread = split(chr(0), $read[$i]);
 $tokens = @tmpread;
 $j = -1;
 while ($j < $tokens) {
  $j++;
  $k = 0;
  while (isvalid(substr($tmpread[$j], $k, 1)) && length($tmpread[$j]) > 1) {
   if ($k + 1 == length($tmpread[$j])) {
    $m = 0;
    @s = @ignore;
    $l = 0;
    while ($s[$l]) {
     if ($s[$l] eq $tmpread[$j]) {
      $m++;
     }
     $l++;
    }
    @s = split(/,/, $result);
    $l = 0;
    while ($s[$l]) {
     if ($s[$l] eq $tmpread[$j] || $s[$l] eq " $tmpread[$j]") {
      $m++;
     }
     $l++;
    }
    if (!$m && substr($tmpread[$j], 0, 3) ne "SIG" && substr($tmpread[$j], 0, 2) ne "__" &&
    substr($tmpread[$j], length($tmpread[$j]) - 2, 2) ne "__") {
     if (!$result) {
      $result = $tmpread[$j];
     }
     else {
      $result = "$result, $tmpread[$j]";
     }
    }
   }
   $k++;
  }
 }
 $i++;
}

&data;

sub data {
 if ($result) {
  foreach (split(/,\s*/, $result)) {
   $ENV{$_} = "A" x 2500;
  }
  exec("$ARGV[0] " . "A" x 2500);
 }
 else {
  print "no typical ENV variables found.\nattempt arguement overflows manually [and environment, if any].\n";
 }
}

sub isvalid {
 $char = substr(shift, 0, 1);
 if (ord($char) > 64 && ord($char) < 91 || ord($char) > 47 && ord($char) < 58 || ord($char) == 45 || ord($char) == 95) {
  return 1;
 }
 return 0;
}

