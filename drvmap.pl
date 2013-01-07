###############################################################
# This script connects/disconnects a network drive.
###############################################################

ConnectDrive("R", "\\Server\\Share");
DeleteDrive("R");

sub ConnectDrive {
   use      Win32;
   use      Win32::NetResource;
   local    (@DriveConfig, $value);
   $DriveConfig->{'LocalName'} = "$_[0]:";
   $DriveConfig->{'RemoteName'} = "$_[1]";
   
   if (Win32::NetResource::AddConnection($DriveConfig, "", "", 0)) {
      print "  $_[0]   ->   $_[1]\n";
      }
   else {
      print Win32::FormatMessage(Win32::GetLastError);
      }
   }

sub DeleteDrive {
   use      Win32;
   use      Win32::NetResource;

   if (!Win32::NetResource::CancelConnection("$_[0]:", 1, 1)) {
      print Win32::FormatMessage(Win32::GetLastError);
      }
   }
