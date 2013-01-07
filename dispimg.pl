use strict;
use Tk;

my $main = new MainWindow;

$main ->Label(-text => 'Image Display')->pack;
$main -> Photo('imggif',
#         -file => "D:\\apps\\perl\\site\\5.005\\lib\\Tk\\demos\\images\\earth.gif");
         -file => "D:\\Tmp\\pengfly.gif");
my $l = $main->Label('-image' => 'imggif')->pack;

$main->Button(-text => 'close',
       -command => sub{destroy $main}
       )->pack(-side => 'left');
$main->Button(-text => 'exit',
       -command => [sub{exit}]
       )->pack(-side => 'right');
MainLoop;
