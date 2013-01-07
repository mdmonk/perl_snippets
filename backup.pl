#	Backup.pl is just a simple perl script to backup stuff to a samba or
#	WindowsNT computer from a WindowsNT computer using Perl which
#	Perl/Tk in it. 

#    Copyright (C) January 1998  Mark Nielsen
#     Read the README file assocaited with this perl script.
#     To execute on a windowsNT system, type "perl backup.pl" assuming you
#     have perl installed.

#    You may copy this program and use it for whatever you want. You may
#    copy it for books, other programs, or anything free of charge. Just
#    mention where you got the program from, and if you make it better, 
#    please let me know at men2@auto.med.ohio-state.edu Mark Nielsen.

#    This program is distributed in the hope that it will be useful,  
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

### NOTE:: This is my second attempt at making a Perl/Tk script. It is done better,
###        but I still avoided doing any object-oriented stuff on my own. I plan to change that.
###        I plan to delve into 99% object-oriented programming soon and not just
###        using the modules. This program should be re-written to pur object-orientation. 

### Current things to do
### DONE -- 1. Make a pop message occur when all backing up is finished
### 2. Object -orient everything, not just the windows
### DONE -- 3. Add a "just connect" button.
### 4. Add an option to backup everything or just backup everything. 
### DONE -- 5. Fix the drive selection -- if it is not highlighted when saving configuration
###       it doesn't get saved.
### 6. Make a better method to search for configuration file. 
### 7. Make a selection list for the drive you want to restore stuff to.
### 8. Add the ability to choose directories or files through a nice GUI interface. 
### 9. Port this to Linux and get it to use NFS, TCFS, or smbumount, or even ftp
###     or scp (ssh).
### 10. Add more error reports in case you are unable to create "backup" directory on the
###     share. 
### 11. Add ability to change the directory "backup" on the share to something else. 

require 5.0004;
use Tk;
use Tk::Dialog;
use Tk::Listbox;
use File::Copy;

package Tk;

$Premw =  MainWindow->new;

$File = &FindFile;

if ($File eq "")  {&ChooseFile($Premw);}
else {&GetDefinitions ($Premw,$File, "destroy"); }

$mw =  MainWindow->new;
$mw -> title("Backingup your files to our backup computer");
$mw -> minsize(400,100);
$mw -> ModifyMainWindow;

MainLoop;	### This creates our main window.
#---------------------------------------------------------------------
sub ModifyMainWindow
{
my $self = shift;
$self->Button(
      -text => 'Backup Now', 
      -command =>  sub {&BackupNow ($mw); }
             )
      ->pack(-side => 'top');

$self->Button(
      -text => 'Configure settings', 
      -command =>  sub {&Configure ($mw); }
             )
      ->pack(-side => 'top');

$self->Button(
      -text => 'Restore files to backup directory', 
      -command =>  sub {&Restore ($mw); }
             )
      ->pack(-side => 'top');

$self->Button(
      -text => 'Just Connect to Backup', 
      -command =>  sub {&JustConnect ($mw); }
             )
      ->pack(-side => 'top');

$self->Button(
      -text => 'Quit Program', 
      -command =>  sub {destroy $mw; }
             )
      ->pack(-side => 'top');

}
#-----------------------------
sub JustConnect
{
my $self = shift;
local (@Error);
system "net use $To\: \/delete";
system "net use $To\: \\\\$Computer\\$From \"$Pass\" \/USER:$User";

$Error[0] = system "net use $To\: \/delete";
$Error[1] = system ("net use $To\: \\\\$Computer\\$From \"$Pass\" \/USER:$User");
if (!(-d "$To\:\\backup")) {$Error[2] = 1}

if (grep($_ > 0, @Error))  {&DialogIt("Couldn\'t connect. It might be MicroSoft's fault. Ask for assitance or change settings. $To\:\\backup, @Error ")}
else {&DialogIt("Successfully connected your backup directory to drive\n\"$To:\\\".\n");}

}

#------------------------------------------------------------------------
sub BackupNow
{
my $self = shift;
local (@Error);
system "net use $To\: \/delete";
system "net use $To\: \\\\$Computer\\$From \"$Pass\" \/USER:$User";

$Error[0] = system "net use $To\: \/delete";
$Error[1] = system ("net use $To\: \\\\$Computer\\$From \"$Pass\" \/USER:$User");
if (!(-d "$To\:\\backup")) {$Error[2] = 1}

my $Name;

if (grep ($_ =~ /unknown/, ($To, $Restore, $From, $Computer)))
  {&Configure($self);}
elsif (grep($_ > 0, @Error))  {&DialogIt("Couldn\'t make the backup. It might be MicroSoft's fault. Ask for assitance or change settings. $To\:\\backup, @Error ")}
else 
  {
  foreach $Dir (keys %Dirs)  
    {
    $Name = $Dirs{$Dir};
    if ($Dirs{$Dir} ne "")  
      {if (!(-d "$To\:\\backup\\$Name")) {system "mkdir $To\:\\backup\\$Name"}}
    &Verify("Really backup documents in $Dir to $To\:\\?", sub{system "xcopy $Dir $To\:\\backup\\$Name \/s"});
    }
  &DialogIt("Finished backing up any selections.");
  }
}

#------------------------------------------------------------------------
sub GetDefinitions
{
my $self = shift;
my $File = shift;
my $command = shift;

open (DAT,$File); @File = <DAT>; close DAT;

foreach $Info (@File)
  {
  chomp $Info;
  ($Command,$Value,$Value2) = split (/ /,$Info,3);
  
  if    ($Command eq "USER") { $User = $Value}
  elsif ($Command eq "PASS") { $Pass = $Value}
  elsif ($Command eq "TO")   { $To   = $Value}
  elsif ($Command eq "FROM") { $From = $Value}
  elsif ($Command eq "DIRS") { $Dirs{$Value} = $Value2;}
  elsif ($Command eq "REST") { $Restore = $Value}
  elsif ($Command eq "COMP") { $Computer = $Value}
  }
if ($Computer eq "")  {$Computer = "warning - unknown"}
if ($To eq "")  {$To = "warning - unknown"}
if ($From eq "")  {$From = "warning - unknown"}
if ($Rest eq "")  {$Rest = "warning - unknown"}

if (grep($_ =~ /warning \- unknown/, ($Computer, $To, $From, $Restore)))
  {$mw2 =  MainWindow->new; $mw2 ->Configure;}

if ($command eq "destroy") { destroy $self}
}

#-----------------------
sub FindFile
{
my $File;

use Win32;
my $name;
$name=Win32::LoginName();

if ($ARGV[0])  {$File = $ARGV[0]}
if (!(-T $File))  {$File = "c:\\$name\\Backup.dat"}
if (!(-T $File))  {$File = "c:\\dat\\Backup.dat"}
if (!(-T $File))  {$File = "c:\\Backup.dat"}
if (!(-T $File))  {$File = ""}

return ($File);
}

#------------------------------------------
sub Configure
{
my $self = shift;
my $TopMenu;

if ($self ne $mw)  {$TopMenu = $self;}
else {$TopMenu = $self->Toplevel;}

my $Temp, $U; $P; $T; $F;
my $RightFrame = $TopMenu->Frame;
$RightFrame->pack (-side => 'right');

my $LabelMessage = $TopMenu->
      Label(
           -height=>3, 
           -width=>40, 
           -relief=>flat,
           -text=>"Enter username and password.",)
   ->pack(-side => top);
my $LeftFrame = $TopMenu->Frame->pack (-side => 'left');
my @Entry = qw/-relief sunken/;
my @Pack = qw /-padx 10 -pady 5 -fill x/;

my $Message1 = $LeftFrame
    ->Label( 
         -height=>1, 
         -width=>40, 
         -relief=>flat, 
         -text=> "Enter Username.",)
   ->pack();
my $Entry1 = $LeftFrame -> Entry(@Entry) -> pack(@Pack, -side=>top); 
if ($User ne "")  {$Temp = $User}
else {$Temp = "unknown"}
$Entry1 -> insert(0, "$Temp");

my $Message2 = $LeftFrame
    ->Label( 
         -height=>1, 
         -width=>40, 
         -relief=>flat, 
         -text=>"Enter Password.")
   ->pack();
my $Entry2 = $LeftFrame -> Entry(@Entry, -show=>0) -> pack(@Pack, -side=>top); 
if ($Pass ne "")  {$Temp = $Pass}
else {$Temp = ""}
$Entry2 -> insert(0, "$Temp");


my $InsideFrame = $LeftFrame->Frame->pack (-side => 'top');

my $Label2 = $InsideFrame->Label(
         -height=>1, 
         -text=>"Drive letter only -- like \"g\"."
           )
-> pack(@Pack, -side=>left); 

my $Entry2_2 = $LeftFrame -> Entry(@Entry, -width=>3,) -> pack(@Pack, -side=>top); 
if ($To ne "")  {$Temp = $To; $Temp =~ s/[^a-zA-Z]//g;}
else {$Temp = ""}
$Entry2_2 -> insert(0, "$Temp");

my $Message4 = $LeftFrame
    ->Label( 
         -height=>1, 
         -width=>40, 
         -relief=>flat, 
         -text=>"Enter share name -- like \"MyShare\".")
   ->pack();
my $Entry4 = $LeftFrame -> Entry() -> pack(@Pack, -side=>top); 
if ($From ne "")  {$Temp = $From}
else {$Temp = ""}
$Entry4 -> insert(0, "$Temp");

my $Message5 = $LeftFrame
    ->Label( 
         -height=>1, 
         -width=>40, 
         -relief=>flat, 
         -text=>"Enter restoration directory -- like \"c:\\restore\".")
   ->pack();
my $Entry5 = $LeftFrame -> Entry() -> pack(@Pack, -side=>top); 
if ($Restore ne "")  {$Temp = $Restore}
else {$Temp = ""}
$Entry5 -> insert(0, "$Temp");

my $Message6 = $LeftFrame
    ->Label( 
         -height=>2, 
         -width=>40, 
         -relief=>flat, 
         -text=>"Enter computer to connect to -- like \"backup\"\n and not \"backup.somwhere.com\".")
   ->pack();
my $Entry6 = $LeftFrame -> Entry() -> pack(@Pack, -side=>top); 
if ($Computer ne "")  {$Temp = $Computer}
else {$Temp = ""}
$Entry6 -> insert(0, "$Temp");

my $Message7 = $LeftFrame
    ->Label( 
         -height=>1, 
         -width=>40, 
         -relief=>flat, 
         -text=>"Remove selected entries.   Add directory and name.")
   ->pack();

my $InsideFrame2 = $LeftFrame->Frame->pack (-side => 'bottom');

my $Entry7 = $InsideFrame2 -> Entry() -> pack(@Pack, -side=>right); 

my $ListBox2 = $InsideFrame2->Listbox(
    -width      => 10,
    -height     => 4, 
    -selectmode => multiple,
    );
@Drives = keys %Dirs;
$ListBox2->insert('0', @Drives);

my $scroll2 = $InsideFrame2->Scrollbar(-command => ['yview', $ListBox2]);
$ListBox2->pack(-side=>left);
$scroll2->pack(-side => 'left', -fill => 'y');

$RightFrame->Button(-text => 'Save Configuration', -command =>  sub {&SaveConfig($TopMenu, $Entry1 ->get, $Entry2 ->get, $Entry2_2->get, $Entry4 ->get, $Entry5 ->get, $Entry6 ->get, $ListBox2, $Entry7)})
    ->pack(-side => 'top');
$RightFrame->Button(-text => 'Done', -command => sub{destroy $TopMenu})
    ->pack(-side => 'top');
}


#-------------------
sub SaveConfig
{
my $self = shift;
my $User = shift;
my $Pass = shift;
my $To = shift;
my $From = shift;
my $Rest = shift;
my $Comp = shift;
my $List2 = shift;
my $Entry7 = shift;

my $Name; my $Add;
$Add = $Entry7 -> get;
$Entry7 -> delete(0,(length $Add));
$Add =~ s/  / /g;
($Add, $Name) = split(/ /,$Add,2);

if (($Add ne "") && ( -d $Add) && !($Dirs{$Add})) 
  {
  if ($Name eq "")  
    {
    if ($Add =~ /\\/)  {@Temp = split(/\\/,$Add); $Name = pop @Temp}
    if (!($Name =~ /[a-zA-Z0-9]/))  {$Name = $Add}
    }
  $Dirs{$Add} = $Name;
  }

$Length = keys %Dirs; $Length = $Length - 1;
my @Positions2 = $List2->curselection;
my $Temp2; my @Names2; @Temp3;
foreach $Temp (@Positions2)
  {$Name = $List2->get($Temp,$Temp);  delete $Dirs{$Name};}

$List2->delete(0,$Length);
@Names2 = sort keys %Dirs;
$List2->insert(0,@Names2);

if ($GlobalTo ne "")  {$To = $GlobalTo;}
else   {$GlobalTo = $To;}

if (-e $File)
  {
  open (FILE,$File); @File = <FILE>; close FILE;
  @File = grep (($_ =~ /[a-zA-Z0-9]/), @File);
  @File = grep (!($_ =~ /^TO/) && !($_ =~ /^FROM/) && !($_ =~ /^COMP/), @File);
  @File = grep (!($_ =~ /^USER/) && !($_ =~ /^PASS/) && !($_ =~ /^REST/), @File);

  open (FILE,">$File");
  print FILE "USER $User\n";
  print FILE "PASS $Pass\n";
  print FILE "TO $To\n";
  print FILE "FROM $From\n";
  print FILE "REST $Rest\n";
  print FILE "COMP $Comp\n";
#  print FILE @File;
  my $Name;
  foreach $Temp (keys %Dirs)  
    {if (-d $Temp)   {$Name = $Dirs{$Temp}; print FILE "DIRS $Temp $Name\n";}}
  close FILE;
  
  $File = &FindFile;
  &GetDefinitions ($self, $File);
  $GlobalTo = "";
 # destroy $self;
  }
else  {&ChooseFile ($self)}
}

#--------------------------------------------
sub Restore
{
my $self = shift;
if ($Restore eq "")  
  {
  my $Ok = "Ok";
  $DIALOG2 = $self->Dialog(
    -title          => 'Backup Message',
    -text           => 'Error, Restoration directory not defined.',
    -default_button => $Ok,
     -buttons        => [$Ok],
    );
  my $button = $DIALOG2->Show();
  if ($button eq $Ok) {destroy $DIALOG2}
  }
elsif (!(-d $Restore) && !(-e $Restore))
  {
  my $Path;
  my @Temp = split (/\\/,$Restore);
  $Path = shift @Temp; $Path = $Path."\\";
  if (!(-d $Path)) 
    {&DialogIt("Error 1 $Path, Unable to use \"$Restore\", choose another place in settings.");}
  else
    {
    foreach $Temp (@Temp)
      {
      $Path = $Path."$Temp\\";
      if (!(-d $Path) && !(-e $Path))  
       {
       system "mkdir \"$Path\"";
       if (!(-d $Path))   
        {&DialogIt("Error 2, Unable to use \"$Restore\", choose another place in settings."); @Temp = ();}
       }
      else   
        {
        &DialogIt("Error 3, Unable to use \"$Restore\", choose another place in settings.");
        @Temp = ();
        }
      }
    }
  } 

if (-d $Restore)  
  {
  $Error = system "net use $To\: \/delete";
  $Error = system ("net use $To\: \\\\$Computer\\$From \"$Pass\" \/USER:$User");
  if ($Error > 0) 
    {&DialogIt("Error 6, Unable to use \"$Restore\", choose another place in settings.");}
  else 
    {
    &Verify ("Restore files on $To\:\\ to $Restore?", sub {$Error = system "xcopy $To\:\\backup $Restore \/s";});
    }
  }
elsif (-e $Restore)
  {&DialogIt("Error 4, Unable to use \"$Restore\", choose another place in settings.");}
else 
  {&DialogIt("Error 5, Unable to use \"$Restore\", choose another place in settings.");}

}


#--------------------------
sub DialogIt
{
my $Text = shift;

my $self = $mw;
my $Ok = "Ok";
$DIALOG2 = $self->Dialog(
  -title          => 'Backup Message',
  -text           => "$Text",
  -default_button => $Ok,
   -buttons        => [$Ok],
  );
my $button = $DIALOG2->Show();
if ($button eq $Ok) {destroy $DIALOG2}
}

#--------------------------
sub Verify
{
my $Text = shift;
my $Sub = shift;

my $self = $mw;
my $Ok = "Ok";
my $Cancel = "Cancel/Done";

$DIALOG2 = $self->Dialog(
  -title          => 'Backup Message',
  -text           => "$Text",
  -default_button => $Cancel,
   -buttons        => [$Ok,$Cancel],
  );
my $button = $DIALOG2->Show();
if ($button eq $Ok)     {&$Sub; }
if ($button eq $Cancel) {destroy $DIALOG2}
}

#-----------------------
sub ChooseFile
{
my $self = shift;

use Win32;
my $name;
$name=Win32::LoginName();

$TopMenu = $self;
my (@Entries);

my @Temp = ("c:\\Backup.dat");
if (-d "c:\\$name")  {push (@Temp,"c:\\$name\\Backup.dat")}
if (-d "c:\\dat")  {push (@Temp,"c:\\dat\\Backup.dat", )}
if ($ARGV[0] =~ /[a-zA-Z0-9]/)  {push (@Temp,$ARGV[0])}

my $LeftFrame = $self->Frame->pack (-side => 'left');
my $RightFrame = $self->Frame->pack (-side => 'right');

$LeftFrame->Label(
         -height=>1, 
         -width=>40, 
         -text=>"Select file to save configurations to."
           )
-> pack(@Pack, -side=>top); 

my $List = $LeftFrame->Listbox(
    -width      => 40,
    -height     => 3, 
    );
$List->insert('0', @Temp);
$List->selectionSet(0,0);
$List->pack(-side=>bottom);

$RightFrame->Button(-text => 'Select File', -command =>  
   sub {$List->CreateFile($self)})
  ->pack(-side => 'top');
}

#------------------
sub CreateFile
{
my $L = shift;
my $self = shift;

my @Temp = $L->curselection; 
$File = $L->get($Temp[0],$Temp[0]);
$GlobalTo = $File;
open (FILE,">$File"); print FILE ""; close FILE;

&GetDefinitions ($Premw,$File); 

destroy $self;
}

