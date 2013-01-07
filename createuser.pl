######################################################################
#
# CreateUser($fullname, $comment, $user, $passwd)
#   $fullname, full name of user to be created (George Smith)
#   $comment, comment about the account (I just put user account created
May 19, 1998)
#   $user,  username of the account to be created (gsmith)
#   $password, initial password to be assigned to the account
(gsmithpasswd)
#
# return values:
#    1  success
#   -1  $user exists
#   -2  $user account create failed
#   -3  $user account set password failed
#
######################################################################
sub CreateUser {

 my ($full, $comment, $user, $passwd) = @_;

 use strict;
 use Win32::NetAdmin;
 use Win32::AdminMisc;

 my $flags = UF_NORMAL_ACCOUNT | UF_SCRIPT | UF_DONT_EXPIRE_PASSWD;
 my $home;
 my $oldpasswd;
 my $passwdAge;
 my $privilege;
 my $server = '';
 my $scriptPath;


 if (Win32::NetAdmin::UserGetAttributes($server, $user, $oldpasswd,
$passwdAge, $privilege, $home, $comment, $flags, $scriptPath))
 return(-1); }

 $home = '';
 $passwdAge = 0;
 $privilege = USER_PRIV_USER;
 $scriptPath = '';

 if (not Win32::NetAdmin::UserCreate($server, $user, $passwd,
$passwdAge, $privilege, $home, $comment, $flags, $scriptPath))
 return(-2); }
 if (not(Win32::AdminMisc::UserSetMiscAttributes($server, $user,
Win32::AdminMisc::USER_FULL_NAME => $full))) { return(-3); }
 return(1);
}
