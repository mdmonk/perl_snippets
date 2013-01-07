#!/usr/bin/perl

# sigtrace v0.23, (c) Darxus@ChaosReigns.com, released under the GPL
# http://www.chaosreigns.com/code/
#
# Traces a gpg signature path from one ID to another.  All keys must have been
# imported into your keyring.  Usage works something like this:
#
# $ gpg --fast-list-mode --keyring mykeyring --list-sigs > mysigs
# $ cat mysigs | ./sigtrace.pl 449FA3AB 0E9FF879 mykeyring
# Loaded data, tracing....
# path: 449FA3AB 2BCBC621 93674C40 DC60654E 80675E65 0E9FF879
# pub  1024D/449FA3AB 1999-10-05 Linus Torvalds <torvalds@transmeta.com>
# pub  1024D/2BCBC621 1999-09-08 H. Peter Anvin (hpa) <hpa@zytor.com>
# pub  1024D/93674C40 1997-08-12 Theodore Y. Ts'o <tytso@mit.edu>
# pub  1024D/DC60654E 1998-08-17 Miro Jurisic <meeroh@mit.edu>
# pub  1024D/80675E65 1997-07-30 Leonard D. Rosenthol <leonardr@lazerware.com>
# pub  1024D/0E9FF879 2000-09-05 Darxus <Darxus@ChaosReigns.com>
#
# To download the keys of everyone who signed a key in the keyring "mysigs" to 
# the keyring "mysigs", do something like:
# gpg --no-default-keyring --keyring mykeyring --recv-keys `gpg --no-default-keyring --keyring mykeyring --list-sigs | grep 'User id not found' | cut -c12-20 | sort -u | tr "\012" " "`
#
# I had to run that command 5 times to get enough data to trace a path from
# Linus Torvalds to me.
#
# v0.8 Nov 21 21:29 EDT print # of hops while searching
# v0.9 Nov 21 21:49 EDT cleaned up output
# v0.10 Nov 21 21:57 EDT print # of keys checked
# v0.11 Nov 21 22:57 EDT a bunch of comments
# v0.12 Nov 22 16:44 EDT display # of keys at each level
# v0.17 Nov 27 18:14 EDT buncha stuff, including 25,000% speed increase (literally,
#                        hashes rock)
# v0.18 Nov 27 19:34 EDT modified to use MCTs .db
# v0.19 Nov 27 20:06 EDT stop if no more keys
# v0.20 Nov 27 20:30 EDT test children, not parents - speed up
# v0.21 Nov 29 20:59 EDT added path caching
# v0.22 Nov 29 21:37 EDT name lookups if keynames.db is present
# v0.23 Nov 30 06:27 EDT handle multiple destinations
# v0.24 Jul 31 15:02 EDT fixed delimiter in commented out import code
#                         - changed from "," to " ".
#
# BUGS
# * does not handle revoked signatures

use DB_File;

$alpha = shift @ARGV; # start at this key
for $end (@ARGV)
{
  $omega{$end}=1;
}

tie %path, "DB_File", "paths.db" or die "Could not tie to file: $!\n";

for $child (keys %omega)
{
if ($path{"$alpha $child"})
  {
    print "(cached $alpha to $child)\n$path{\"$alpha $child\"}\n";
    &namelookup;
    delete $omega{$child}
  }
}

untie %path;

#print join(' ',keys %omega);
exit 0 if (scalar(keys %omega) < 1);

#my (%signedby);
tie %signedby, "DB_File", "signed.db" or die "Could not tie to file: $!\n";

# don't line buffer
$pipe = $|;
$| = 1;

$keyring = $ARGV[2]; # use this keyring to print the names in the path
$level = 0;
$levelkeys = 0;

# Load all signature relationships into a hash of arrays, called %signedby.
# Each key is the ID of someone who signed keys, and its value is an array
# containing a list of the IDs he signed.

#while ($line = <STDIN>)
#{
#  ($type,$id) = split(' ',$line);
#  if ($type eq "pub")
#  {
#    $pub = (split('/',$id))[1];
#  } elsif ($type eq "sig")
#  {
#    next if ($id eq $pub);
#    #push (@{$signedby{$id}},$pub);
#    $signedby{$id} .= "$pub ";
#  }
#}

print "Data loaded, tracing....\n";

# Load the beginning key into the queue.
# The queue data is in pairs.  The 1st value is the ID to be tested, the 2nd
# value is the path to get from the origin to that ID.  
# The original path is null, because.. it's at the beginning.
# 
# A pair of nulls is used to delimit the boundaries between levels of recursion
# (# of hops).

push (@queue,$alpha,"","","");

# Loop through the queue till it's empty.
# This is a depth-first search.

print "level:0";

$lasttime = time;
while (@queue)
{
  $id = shift @queue;
  $path = shift @queue;

  # If a recursion level boundary is hit, report it.
  if ($id eq "")
  {
    $level++;
    if ($levelkeys == 0)
    {
      print " keys:$levelkeys seconds:". scalar(time - $lasttime) ."\nNo path found to: ". join(" ",keys(%omega)) ."\n";
      untie %signedby;
      tie %path, "DB_File", "paths.db" or die "Could not tie to file: $!\n";
      for $end (keys %omega)
      {
        $path{"$alpha $end"}="No path found";
      }
      exit 1;
    }
    print " keys:$levelkeys seconds:". scalar(time - $lasttime) ."\nlevel:$level";
    $lasttime = time;
    $levelkeys=0;
    # Mark the next recursion level boundary.
    push (@queue,"","");
    next;
  } else {
    $levelkeys++;
  }
  # Put this ID into the list to not check anymore.
  $checked{$id}=1;

  # If we've come to the end, report it.
  {
    # This ID we just checked was not the destination.
    # Add all its children (IDs this ID signed) to the queue.
    for $child (split(' ',$signedby{$id}))
    {
      unless ($queued{$child})
      {
        if ($omega{$child})
        {
          $| = $pipe;
          #print " keys:$levelkeys seconds:". scalar(time - $lasttime) ."\nlevel:". scalar($level+1) ."\n";
          print " keys:$levelkeys seconds:". scalar(time - $lasttime) ."\n";
          $output = scalar($level+1) ." hop path:$path $id $child";
          #untie %signedby;
          tie %path, "DB_File", "paths.db" or die "Could not tie to file: $!\n";
          $path{"$alpha $child"}=$output;
          print "$output\n";
          &namelookup;
          delete $omega{$child};
          untie %path;
          exit 0 if (scalar(keys %omega) < 1);
          print "level $level";
        }
        push (@queue,$child,"$path $id");
        $queued{$child}=1;
      }
    }
  }
}

sub namelookup
{
  if ( -e "keynames.db" )
  {
    tie %name, "DB_File", "keynames.db" or die "Could not tie to file: $!\n";
    $output = (split(":",$path{"$alpha $child"},2))[1];
    for $key (split(" ",$output))
    {
      print "$key $name{$key}\n" unless ($key eq " ");
    }
  }
}
