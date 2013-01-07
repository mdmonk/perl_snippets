#!/usr/bin/perl

if ($pid1 = fork) {
   print "Child Process 1 Successfully Launched\n";
} elsif (defined $pid1) {
   print "I am Child Process 1\n";
   exit;
} else {
   die "Can't fork: $!\n";
}

if ($pid2 = fork) {
   print "Child Process 2 Successfully Launched\n";
} elsif (defined $pid2) {
   print "I am Child Process 2\n";
   exit;
} else {
   die "Can't fork: $!\n";
}

if ($pid3 = fork) {
   print "Child Process 3 Successfully Launched\n";
} elsif (defined $pid3) {
   print "I am Child Process 3\n";
   exit;
} else {
   die "Can't fork: $!\n";
}

print "Reaping Children...\n";
waitpid($pid1, 0);
print "Child 1 Reaped\n";
waitpid ($pid2, 0);
print "Child 2 Reaped\n";
waitpid ($pid3, 0);
print "Child 3 Reaped\n";
print "All Done\n";
