# #!\perl\bin\perl

use Tk;
use Tk::ProgressBar;

my $mw = MainWindow->new;
my $status_var = 0;
my $text = "Build " . $status_var . "% Complete";

my $lab = $mw->Label(-textvariable => \$text)
	->pack(-expand => 1, -fill => 'x');

my $progbar = $mw->ProgressBar(
	-borderwidth => 2,
	-relief => 'sunken',
	-width => 200,
	-length => 30,
	-padx => 2,
	-pady => 2,
	-variable => \$status_var,
	-colors => [0 => 'blue'],
	-resolution => 0,
	-blocks => 1,
	-anchor => 'e',
	-from => 0,
	-to => 100
	)->pack(-padx => 10, -pady => 10, -side => 'top',
		-fill => 'both', -expand => 1
   );
my $button = $mw->Button(-text => 'OK', -command => \&updateBar)->pack;
Tk::MainLoop;
###########################
# updateBar
#  - original version of 
#    the subroutine to 
#    update the progress
#    bar.
###########################
sub updateBar {
   for ($i = 0; $i <= 100; $i++) {
      $text = "Build " . $i . "% Complete";
      $lab->configure(-textvariable => \$text);
      $progbar->configure(-variable => \$i);
      $lab->update;
      $progbar->update;
   }
}
###########################
# newupdateBar
#  - updated version from 
#    the perl-win32 mailing
#    list
###########################
sub newupdateBar {
   my ($text, $i);
   $lab->configure(-textvariable => \$text);
   $progbar->configure(-variable => \$i);
   for ($i = 0; $i <= 100; $i++) {
      $text = "Build " . $i . "% Complete";
      #$progbar->idletasks;	#only update display
      $progbar->update;      #allow handle all pending events
   }
}
