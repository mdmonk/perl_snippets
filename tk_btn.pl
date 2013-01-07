#!/usr/bin/perl -w

use Tk;
use Tk qw/:eventtypes/;
use strict;

my(@labels,$i);

my $MW = MainWindow->new();

my $fortype = shift;

if ($fortype eq "for") {
 build_buttons_w_for();
}
if ($fortype eq "foreach") {
 build_buttons_w_foreach();
}
my $tlabel = $MW->Label(-text => "")->pack;

while (1) {
 DoOneEvent(DONT_WAIT);
}

###
### this routine creates 6 buttons which each call
### pressed(<number>) where <number> is $i at time of
### creation.  button #3 calls pressed(3)
###
sub build_buttons_w_foreach {
 foreach $i (0 .. 5) {
  $labels[$i]  = $MW->Label(-text => "foreach groovy $i")->pack;
  $MW->Button(-text => "foreach funky $i", -command => sub
{pressed($i)})->pack;
 }
}

###
### this routine also makes buttons but all of them call pressed(6)
###
sub build_buttons_w_for {
 for ($i=0;$i<=5; $i++) {
  $labels[$i]  = $MW->Label(-text => "for groovy $i")->pack;
  $MW->Button(-text => "for funky $i", -command => sub
{pressed($i)})->pack;
 }

###
###    when called changes the ith label to the color red
###
}
sub pressed {
 $i = shift @_;
 $tlabel->configure(-text => "pressed() -- i = \[$i\]");
 $labels[$i]->configure(-foreground => 'red');
}
