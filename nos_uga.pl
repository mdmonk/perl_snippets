################################################################
#  Get User Attributes.
#  Works on WinNT ONLY.
################################################################

use Win32::NetAdmin;

Win32::NetAdmin::UserGetAttributes (
  '',
  "hc65",
  $Password,
  $PasswdAge,
  $Privilege,
  $HomeDir,
  $Comment,
  $Flag,
  $Script )  || die "Unable to get user attributes: $!";

$result_1 = sprintf (
  "  Password: %s\n  Passwd Age: %x\n  Privilege: %s\n",
  $Password,
  $PasswdAge,
  $Privilege );

$result_2 = sprintf (
  "  Home Directory: %s\n  Comment: %s\n  Flag: %s\n  Script: %s\n",
  $HomeDir,
  $Comment,
  $Flag,
  $Script );

print $result_1 . $result_2;
