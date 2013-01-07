#!c:\perl\bin\perl.exe
#-----------------------------------------------------
# null.pl
# 
# Script to test enumeration via null sessions on NT
#   machines.  
# Requires Win32::Lanman, v1.05 
#
# Usage: null.pl <IP_ADDR> 
#        perl null.pl <IP_ADDR> > myfile
#
# copyright 1999, 2000 by H.Carvey
# email contact: wintermute2k@yahoo.com
#----------------------------------------------------- 
use strict;
use Win32::Lanman;
use Win32::TieRegistry(Delimiter=>"/");

my($server) = shift || die "No server entered.\n";

my($test) = "";
my(@shares,@modals,@users,$user,@global);
my($g_user,$l_user);

if (ConnectIPC($server, $test, $test, $test)) {
	print "Null Session to $server successful.\n";
# Now try getting some information
	print "\n[Registry]\n";
	print "Attempt to connect to the remote Registry.\n";
	\&RegConnect($server);
	
	print "\n[Logged on Users]\n";
	print "Enumerate logged on users.\n";
	my @users = WkstaUserEnum($server);
	if (@users) {
		printf "%-12s %-15s %-15s\n","User","Logon Server","Logon Domain";
		foreach (@users) {
			my ($user,$lserver,$ldomain) = split(/:/,$_);
			printf "%-12s %-15s %-15s\n","$user","$lserver","$ldomain";
		}
	}
	else {
		print "No logged on users.\n";
	}
	
	print "\n[Workstation Transports]\n";
	print "Enumerate Workstation (redirector) transports. The WAN column indicates \n";
	print "whether the protocol is a WAN protocol (1) or not (0).  The VCS column \n";
	print "indicates the number of clients communicating with the server using this \n";
	print "transport protocol.\n\n";
	my @transports = WkstaTransportEnum($server);
	if (@transports) {
		printf"%-15s %-25s %-5s %-5s\n","Transport Addr.","Transport Name","WAN","VCS";
		foreach (@transports) {
			my($taddress,$tname,$wan,$vcs) = split(/:/,$_,4);
			printf "%-15s %-25s %-5s %-5s\n",$taddress,$tname,$wan,$vcs;
		}
	}
	else {
		print "No Workstation Transports available.\n";
	}
	
	print "\n[Server Transports]\n";
	print "Enumerate Server transports.  As with the workstation transports, the \n";
	print "network address and the number of clients connecting to the server using the \n";
	print "transport protocol (vcs) is listed.\n\n";
	my @transports = SvrTransportEnum($server);
	if (@transports) {
		printf"%-15s %-25s %-3s %-15s %-10s\n","Network Addr.","Transport Name",
				  "VCS","Trans. Addr.","Domain";
		foreach (@transports) {
			my($na,$tn,$vcs,$ta,$dom) = split(/:/,$_,5);
			printf "%-15s %-25s %-3s %-15s %-10s\n",$na,$tn,$vcs,$ta,$dom;
		}
	}
	else {
		print "No Server Transports available.\n";
	}
	
  print "\n[Shares]\n";
  print "Enumerate available shares, to include administrative hidden shares.\n\n";
	@shares = GetShares($server);
	(@shares) ? (map{print "$_ \n";}@shares) : (print "No shares.\n");
	
	print "\n[Domain SID]\n";
	print "Enumerate the domain SID via the LsaQueryInformationPolicy() API leakage \n";
	print "issue.  If this SID is the same as the SID enumerated below in the User Modals \n";
	print "section, and the role is 2, then the system is a BDC; if role = 3, then the \n";
	print "system is a PDC.  If the SIDs are not equal, then the system is a member server.\n\n";
	my $sid = GetDomainSID($server);
	print "SID: $sid\n" if (defined $sid);
	
	print "\n[User Modals]\n";
	print "Enumerate the User Modals, or Domain Account Policy.\n";
	print "This information is available to administrators via the User Manager, and \n";
	print "is helpful in protecting the system.  The most important items listed are the \n";
	print "account lockout threshold and the password settings.  An account lockout threshold \n";
	print "of 0 means that the account will not be locked out by multiple failed logon \n";
	print "attempts.  An attack can use the usernames enumerated below to launch dictionary-\n";
	print "based brute force password guessing attacks against the server.  The password \n";
	print "settings will give an attacker an idea of the security posture of the system.\n\n";
	@modals = GetModals($server);
	(@modals) ? (map{print "$_ \n";}@modals) : (print "No modals.\n");
	
	print "\n[Global Users]\n";
	print "Enumerate global, or domain, users and information for each user.\n\n";
	@global = GetGlobalUsers($server);
	if (@global) {
		foreach (@global) {
			print "$_\n";
			$g_user = (split(/:/,$_))[1];
			\&GetUserInfo($server,$g_user);
			print "\n";
		} 
	}
	else {
		print "Did not retrieve global users.\n";
	}
	
	print "\n[Local Users]\n";
	print "Enumerate local users and information for each user.\n\n";
	@users = GetLocalUsers($server);
	if (@users) {
		foreach (@users) {
			print "$_\n";
			$user = (split(/:/,$_))[1];
			$l_user = (split(/\\/,$user))[1];
			\&GetUserInfo($server,$l_user);
			print "\n";
		} 
	}
	else {
		print "Did not retrieve local users.\n";
	}

	print "\n";
	if (Disconnect($server)) {
		print "Disconnected from $server.\n";
	}
	else {
		print "Could not disconnect.\n";
	}
}
else {
	print "Could not establish null session with $server.\n";
}

#-----------------------------------------------------
# Attempt a connection to IPC$; used for null session
# connections, as well as checking passwords
#-----------------------------------------------------
sub ConnectIPC {
	my($server,$passwd,$user,$domain) = @_;
	my(%Hash) = (remote => "\\\\$server\\ipc\$",
         			asg_type => &USE_IPC,
         			password => $passwd,
         			username => $user, 
         			domainname => $domain);

	(Win32::Lanman::NetUseAdd(\%Hash)) ? (return 1) : (return 0);
}

#-----------------------------------------------------
# Disconnect the IPC$ connection
#-----------------------------------------------------  
sub Disconnect {
  my(@server) = @_;
  (Win32::Lanman::NetUseDel("\\\\$server\\ipc\$",&USE_FORCE)) ?
    (return 1) : (return 0);
}

#-----------------------------------------------------
# Get the available shares
#-----------------------------------------------------
sub GetShares {
	my($server) = @_;
	my(@stuff,$str);
	my(@shares) = ();
	if (Win32::Lanman::NetShareEnum("\\\\$server",\@stuff)) {
    foreach (@stuff) {
    	$str = "${$_}{'netname'}";
    	push (@shares,$str);
    }
  }
  else {
#    $err = Win32::FormatMessage Win32::Lanman::GetLastError();
#    $err = Win32::Lanman::GetLastError() if ($err eq "");
#    print "Could not get shares.  $err\n";
  } 	
	return @shares;
}

#-----------------------------------------------------
# Get User Modals
#-----------------------------------------------------
sub GetModals {
	my($server) = @_;
	my(%info,$err);
	my(@modals) = ();
	if(Win32::Lanman::NetUserModalsGet("\\\\$server",\%info)) {
		foreach (sort keys %info) {
			$info{$_} = (unpack("H" . 2 * length($info{$_}), $info{$_})) if ($_ eq "domain_id");
			 push (@modals,"$_: $info{$_}") unless ($_ eq "primary");
		}
	}
	else {
		$err = Win32::FormatMessage Win32::Lanman::GetLastError();
		$err = Win32::Lanman::GetLastError() if ($err eq "");
    print "GetUserModalsGet Error:  $err\n";
  }
  return @modals;
}

#-----------------------------------------------------
# Get Local Groups/Users from the server
#-----------------------------------------------------
sub GetLocalUsers {
	my($server) = @_;
	my($err,$group,$member);
	my(@groups,@members,@users) = ();
	
	if(Win32::Lanman::NetLocalGroupEnum("\\\\$server", \@groups)) {
		foreach $group (@groups) {
			if(Win32::Lanman::NetLocalGroupGetMembers("\\\\$server", ${$group}{'name'}, \@members)) {
				foreach $member (@members) {
					push(@users, "${$group}{'name'}:${$member}{'domainandname'}");
				}
			}
			else {
				$err = Win32::FormatMessage Win32::Lanman::GetLastError();
				$err = Win32::Lanman::GetLastError() if ($err eq "");
				print "NetLocalGroupGetMembers error:  $err\n";	
			}	
		}	
	}
	else {
		$err = Win32::FormatMessage Win32::Lanman::GetLastError();
		$err = Win32::Lanman::GetLastError() if ($err eq "");
		print "NetLocalGroupEnum error:  $err\n";
	}
	return @users;
}

#-----------------------------------------------------
# Get User Info
#-----------------------------------------------------
sub GetUserInfo {
	my($server,$user) = @_;
	my($err);
	my(%info) = ();
	my($usr,$uid,$pwage,$pwbd,$logon,$logoff,$comment);
	
	if (Win32::Lanman::NetUserGetInfo("\\\\$server",$user,\%info)) {
		$pwage = (split(/\./,$info{'password_age'}))/(3600*24);
		print "\tName        => $info{'name'}\n";
		print "\tComment     => $info{'comment'}\n";
		print "\tUID         => $info{'user_id'}\n";
		print "\tPasswd Age  => $pwage\n";
		print "\tLast Logon  => ".localtime($info{'last_logon'})."\n";
		print "\tLast Logoff => ".localtime($info{'last_logoff'})."\n";
		print "\n";
		print "\tAccount does not expire.\n" if ($info{'acct_expires'} == -1);
		print "\tACCOUNT DISABLED.\n" if ($info{'flags'} & UF_ACCOUNTDISABLE);
		print "\tUser cannot change password.\n" if ($info{'flags'} & UF_PASSWD_CANT_CHANGE);
		print "\tAccount is locked out.\n" if ($info{'flags'} & UF_LOCKOUT);
		print "\tPassword does not expire.\n" if ($info{'flags'} & UF_DONT_EXPIRE_PASSWD);
		print "\tPassword not required.\n" if ($info{'flags'} & UF_PASSWD_NOTREQD);
	}
	else {
		$err = Win32::FormatMessage Win32::Lanman::GetLastError();
		$err = Win32::Lanman::GetLastError() if ($err eq "");
		$err = "Domain User account" if ($err == 2221);
    print "NetUserGetInfo Error:  $err\n";
  }
}

#-----------------------------------------------------
# Attempt to connect to the remote Registry
#-----------------------------------------------------
sub RegConnect {
	my($server) = @_;
	my($remote);
	if ($remote = $Registry->{"//$server/LMachine/SOFTWARE/Microsoft/Windows NT/CurrentVersion"}) {
# path "SOFTWARE/Microsoft/Windows NT/CurrentVersion" is usually
# in the AllowedPaths\Machine key		
		print "Connected to remote Registry.\n";
	}
  else {
  	print "Could not connect to remote Registry.\n";
  }
}

#-----------------------------------------------------
# Get Global Groups/Users from the server
#-----------------------------------------------------
sub GetGlobalUsers {
	my($server) = @_;
	my(@groups,@users,@global) = ();
	my($err,$group,$user);
	
	if(Win32::Lanman::NetGroupEnum("\\\\$server", \@groups)) {
		foreach $group (@groups) {
			next if (${$group}{'name'} eq "None");
			if(Win32::Lanman::NetGroupGetUsers("\\\\$server", ${$group}{'name'}, \@users)) {
				foreach $user (@users) {
					push(@global,"${$group}{'name'}:${$user}{'name'}");
				}	
			}
			else {
				$err = Win32::FormatMessage Win32::Lanman::GetLastError();
				$err = Win32::Lanman::GetLastError() if ($err eq "");
				print "NetGroupGetUsers Error:  $err\n";
			}			
		}
	}
	else {
		$err = Win32::FormatMessage Win32::Lanman::GetLastError();
		$err = Win32::Lanman::GetLastError() if ($err eq "");
		print "NetGroupEnum Error:  $err\n";
	}
	return @global;
}

#-----------------------------------------------------
# Get Domain SID from target machine
#-----------------------------------------------------
sub GetDomainSID {
	my($server) = @_;
	my($err, %info);
	
	if(Win32::Lanman::LsaQueryPrimaryDomainPolicy("\\\\$server", \%info)) {
# 		print "name=$info{name}\n";
# 		print "sid=", unpack("H" . 2 * length($info{sid}), $info{sid}), "\n";
			return (unpack("H" . 2 * length($info{sid}), $info{sid}));
 	}
 	else {
 		$err = Win32::FormatMessage Win32::Lanman::GetLastError();
		$err = Win32::Lanman::GetLastError() if ($err eq "");
		print "LsaQueryPrimaryDomainPolicy Error:  $err\n";
		return undef;
	}
}

#-----------------------------------------------------
# Get logged on users
#-----------------------------------------------------
sub WkstaUserEnum {
	my($server) = @_;
	my(@info,$user,$err);
	my(@users) = ();
	
	if(Win32::Lanman::NetWkstaUserEnum("\\\\$server", \@info)) {
  	foreach $user (@info) {
   		push (@users,"${$user}{username}:${$user}{logon_server}:${$user}{logon_server}");
		}
	}
	else { 
		$err = Win32::FormatMessage Win32::Lanman::GetLastError();
		$err = Win32::Lanman::GetLastError() if ($err eq "");
		print "NetWkstaUserEnum Error:  $err\n";
	}
	return(@users);
} 		

#-----------------------------------------------------
# Get workstation (redirector) transports
#-----------------------------------------------------
sub WkstaTransportEnum {
	my($server) = @_;
	my(@info,$transport,@keys,$key,$err);
	my(@transports) = ();
	
	if(Win32::Lanman::NetWkstaTransportEnum("\\\\$server", \@info)) {
  	foreach $transport (@info) {
  		push(@transports,"${$transport}{transport_address}:${$transport}{transport_name}".
  		     ":${$transport}{wan_ish}:${$transport}{number_of_vcs}");
		}	
	}
	else {
		$err = Win32::FormatMessage Win32::Lanman::GetLastError();
		$err = Win32::Lanman::GetLastError() if ($err eq "");
		print "NetWkstaTransportEnum Error:  $err\n";
	}
	return (@transports);
}

#-----------------------------------------------------
# Get server transports
#-----------------------------------------------------
sub SvrTransportEnum {
	my($server) = @_;
	my(@info,$transport,@keys,$key,$err);
	my(@transports) = ();
	
	if(Win32::Lanman::NetServerTransportEnum("\\\\$server", \@info)) {
  	foreach $transport (@info) {
  		push(@transports,"${$transport}{networkaddress}:${$transport}{transportname}".
  				 ":${$transport}{numberofvcs}:${$transport}{transportaddress}".
  				 ":${$transport}{domain}");
		}	
	}
	else {
		$err = Win32::FormatMessage Win32::Lanman::GetLastError();
		$err = Win32::Lanman::GetLastError() if ($err eq "");
		print "NetServerTransportEnum Error:  $err\n";
	}
	return (@transports);
}
