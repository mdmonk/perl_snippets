#!/local/bin/perl
#
# Quote spewer
#
# File: spew
# Author: Nem (Ryun) Schlecht
# Creation Date: Jun 27, 1995
# Last Modification: Jun 27, 1995
#
#

use Fcntl;
use DB_File;
use strict;

my($database)=$ARGV[0];
my(@in);my(%d_file);my(@quotes);my($key);my($spam);
my($count);my(@rand);my($rnum);

srand($$^time);

my($SPEWRC) = $ENV{SPEWRCFILE} || "$ENV{HOME}/.spewrc";

open(RCFILE, "$SPEWRC");
while(<RCFILE>) {
    chop;
    next if /^#/;
    @in=split(/:/,$_);
    $d_file{$in[0]}=$in[1];
    ++$count;
    push(@rand,$in[0]);
}
close(RCFILE);

if ($database eq "rand") {
    $rnum=int(rand($count));
    $database=$rand[$rnum];
}

if (! defined($d_file{$database})) {
    print "No database entry\n"; exit;
}

if (! -e $d_file{$database}) {
    print "File doesn't exist.\n"; exit;
}

my($db)=tie(@quotes, 'DB_File', "$d_file{$database}", O_RDONLY, 0600,
	    $DB_RECNO);

$key=int(rand($db->length));
$spam=$quotes[$key];
$spam =~ s/ ( )?/$1\n/go;
print "$spam\n";
