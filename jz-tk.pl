#!/usr/bin/perl -w

use Tk;
use File::Copy;

my $srcFile =  "d:\\data\\\"my documents\"\\\"implementation stewards\"\\iswebpage\\iswebpage.htm";
my $destFile = "w:\\\"implementation stewards\"\\iswebpage\\iswebpage.htm";

my $mw = MainWindow->new;

if (copy($srcFile, $destFile)) {

   $mw->Button(-text => "********** FILE COPY WAS SUCCESSFUL **********", -command =>sub{exit})->pack;

} else {

   $mw->Button(-text => "FILE COPY FAILED  \nPlease call Jeff Zissman at 5-7593 or
   page him at (888) 581-1922 or (888) 758-1922", -command =>sub{exit})->pack;

} # end if-else

MainLoop;
