#!/usr/bin/perl

# 3 rotor German Enigma simulation
# by samy [CommPort5@LucidX.com]

@rotors = (
 [ split(//, "ABCDEFGHIJKLMNOPQRSTUVWXYZ") ],
 [ split(//, "EKMFLGDQVZNTOWYHXUSPAIBRCJ") ],
 [ split(//, "AJDKSIRUXBLHWTMCQGZNPYFVOE") ],
 [ split(//, "BDFHJLCPRTXVZNYEIWGAKMUSQO") ],
 [ split(//, "ESOVPZJAYQUIRHXLNFTGKDCMWB") ],
 [ split(//, "VZBRGITYUPSDNHLXAWMJQOFECK") ]
);
@ref = split(//, "YRUHQSLDPXNGOKMIEBFZCWVJAT");
$flag = 0;
$n = 0;
@order = (3, 1, 2);
@notch = (ints('Q'), ints('E'), ints('V'), ints('J'), ints('Z'));
@rings = (ints('W'), ints('X'), ints('T'));
@pos = (ints('A'), ints('W'), ints('E'));
@plug = (ints('A'), ints('M'), ints('T'), ints('E'));

sub ints {
 return unpack("C*", $_[0]);
}

while (<STDIN>) {
 if ($_ !~ /^\s*\n$/) {
  chomp($tmp = $_);
  foreach (split(//, $tmp)) {
   $ch = uc($_);
   if ($ch !~ /^\w+$/) {
    next;
   }
   $pos[0]++;
   if ($pos[0] > ints 'Z') {
    $pos[0] -= 26;
   }
   if ($flag) {
    $pos[1]++;
    if ($pos[1] > ints 'Z') {
     $pos[1] -= 26;
    }
    $pos[2]++;
    if ($pos[2] > ints 'Z') {
     $pos[2] -= 26;
    }
    $flag = 0;
   }
   if ($pos[0] eq $notch[$order[0] - 1]) {
    $pos[1]++;
    if ($pos[1] > ints 'Z') {
     $pos[1] -= 26;
    }
    if ($pos[1] eq $notch[$order[1] - 1]) {
     $flag = 1;
    }
   }
   for ($i = 0; $plug[$i]; $i += 2) {
    if ($ch eq $plug[$i]) {
     $ch = $plug[$i + 1];
    }
    elsif ($ch eq $plug[$i + 1]) {
     $ch = $plug[$i];
    }
   }
   for ($i = 0; $i < 3; $i++) {
    $ch += $pos[$i] - ints 'A';
    if ($ch > ints 'Z') {
     $ch -= 26;
    }
    $ch -= $rings[$i] - ints 'A';
    if ($ch < ints 'A') {
     $ch += 26;
    }
    $ch = $rotor[$order[$i] - 1][$ch - ints 'A'];
    $ch += $rings[$i] - ints 'A';
    if ($ch > ints 'Z') {
     $ch -= 26;
    }
    $ch -= $pos[$i] - ints 'A';
    if ($ch < ints 'A') {
     $ch += 26;
    }
   }
   $ch = $reg[$ch - ints 'A'];
   for ($i = 3; $i; $i--) {
    $ch += $pos[$i - 1] - ints 'A';
    if ($ch > ints 'Z') {
     $ch -= 26;
    }
    $ch -= $rings[$i - 1] - ints 'A';
    if ($ch < ints 'A') {
     $ch += 26;
    }
    for ($j = 0; $j < 26; $j++) {
     if ($rotor[$order[$i - 1] - 1][$j] eq $ch) {
      last;
     }
    }
    $ch = $j + ints 'A';
    $ch += $rings[$i - 1] - ints 'A';
    if ($ch > ints 'Z') {
     $ch -= 26;
    }
    $ch -= $pos[$i - 1] - ints 'A';
    if ($ch < ints 'A') {
     $ch += 26;
    }
   }
   for ($i = 0; $plug[$i]; $i += 2) {
    if ($ch eq $plug[$i]) {
     $ch = $plug[$i + 1];
    }
    elsif ($ch eq $plug[$i + 1]) {
     $ch = $plug[$i];
    }
   }
   $n++;
   print pack("C*", $ch);
   if ($n % 5 == 0) {
    if ($n % 55 == 0) {
     print "\n";
    }
    else {
     print " ";
    }
   }
  }
 }
}
