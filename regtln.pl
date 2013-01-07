#-----------------------------------------------------------
# regtln.pl
# Author: Don C. Weber
# Plugin for Registry Ripper; 
# regtln settings from all hives
# 
# Change history
#   12/23/2009: Updated to match TLN format
#               Added basename of the file provided as TLN Source
#               Added test for user name which should only work for
#                   NTUSER.dat Hives and default to "0" for others
#   1/31/2010:  Updated stripping characters that might break lines
#
# References
#   TLN Format: http://windowsir.blogspot.com/2009/02/timeline-analysis-pt-iii.html
#
# copyright 2008 H. Carvey
#-----------------------------------------------------------
package regtln;
use File::Basename;
use strict;

my %config = (hive          => "All",
              hasShortDescr => 1,
              hasDescr      => 0,
              hasRefs       => 0,
              osmask        => 22,
              version       => 20091122);

sub getConfig{return %config}
sub getShortDescr {
	return "Gets regtln settings from all hives";	
}
sub getDescr{}
sub getRefs {}
sub getHive {return $config{hive};}
sub getVersion {return $config{version};}

my $VERSION = getVersion();

sub pluginmain {
	my $class = shift;
	my $hive = shift;
	::logMsg("Launching regtln v.".$VERSION);
	my $reg = Parse::Win32Registry->new($hive);
	my $root_key = $reg->get_root_key;
    
    # Name of Registry File for TLN Source
    my $basename = "Registry Hive: ".basename($hive);
    
    # Grab username if available
    my $username = getuser($root_key);
    
	listkeys($root_key, $root_key->get_name, $basename, $username);
}

sub getuser{
    # Determine the owner of the NTUSER.dat Hive
    # Modeled after RR Plugin: logonusername.pl
    my $inkey = shift;
    my $user_logon_name = "0";
    my $userkey = 'Software\\Microsoft\\Windows\\CurrentVersion\\Explorer';
    my $logon_name = "Logon User Name";
    my $key;
    if ($key = $inkey->get_subkey($userkey)){
        my @vals = $key->get_list_of_values();
        if (scalar(@vals) > 0){
            foreach my $v (@vals){
                if ($v->get_name() eq $logon_name){
                    $user_logon_name = $v->get_data();
                }
            }
        }
    }

    return $user_logon_name
}

sub listkeys{
    my $inkey = shift;
    my $inkey_name = shift;
    my $basename = shift;
    my $username = shift;
	my @subkeys = $inkey->get_list_of_subkeys();
    if (scalar(@subkeys) > 0) {
        foreach my $sub_key (@subkeys){
            listkeys($sub_key, $inkey_name."/".$sub_key->get_name, $basename, $username);
        }
    } else {
        # Replace characters that might affect individual lines
        $inkey_name =~ s/[^\x00-\x7f]/?/g;
        $inkey_name =~ s/[\x00-\x1F]//g;
        
        # TLN Format: Time | Source | Host | User | Description
		::rptMsg($inkey->get_timestamp()."|".$basename."|HOSTNAME|".$username."|".$inkey_name);
		
    }
}

1;
