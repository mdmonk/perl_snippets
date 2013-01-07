# NetUser.pl
# Retrieve user info
$Version = "NetUser v1.0 by linus\@corin.net\n";
use Win32;
use Win32::AdminMisc;



if ($ARGV[0] && $ARGV[0]=~ /^--help|^-h|\?/){&print_usage;exit}
if ($ARGV[0] && $ARGV[0]=~ /^--version|^-v/){&print_version;exit}

if ($ARGV[0]){$User = $ARGV[0]}
else {$User = Win32::LoginName()}
if ($ARGV[1]) {$Domain = $ARGV[1]}
else {$Domain = Win32::DomainName()}


if ( Win32::AdminMisc::UserGetMiscAttributes($Domain, $User, \%UserInfo)){
    print "Successfully retrieved user info for $User in domain $Domain.\n";
    &print_info;
}
else {
    print "Error retrieving user info for $User in domain $Domain.\n";
    print "Win32 Error message: ";
    print Win32::FormatMessage( Win32::GetLastError() ) ;
    print "\n";
}

exit;

### Sub routines
sub print_info {
print <<EOF;

User comment:     $UserInfo{USER_COMMENT}
Full name:        $UserInfo{USER_FULL_NAME}
Homedir:          $UserInfo{USER_HOME_DIR}
Profile:          $UserInfo{USER_PROFILE}
Logon script:     $UserInfo{USER_SCRIPT_PATH}
EOF

# This one is undocumented but existent. It seemed to complicated otherways.
if ($ARGV[2] && $ARGV[2]=~ /-a/i){
    print "\n\nFull info on user:\n";
    print "==================\n\n";
    while (($Key, $Value) = each %UserInfo){
        print "$Key:\t\t$Value\n";
    }
}


unless ($UserInfo{USER_PASSWORD_EXPIRED} == 0){print "\n\nWARNING!!!\nPassword expired for user!\n"}

}#print_info


sub print_usage {
    print "Usage: $0 [user] [domain | \\\\server]\n\n";
    print "If \"domain\" is ommited, current domain is used.\n";
    print "If info is to be retrieved for a local user, name of server must be preceeded\n";
    print "by two backward slashes (as in \\\\Server).\n\n";
    print "-h or --help shows help, -v or --version show version information\n";
}#print_usage

sub print_version {
    print "\n$Version\n";
    print "Released under the GPL (http://www.gnu.org/copyleft/gpl.html)\n";
}#print_version
