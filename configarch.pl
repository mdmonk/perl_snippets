#!/usr/local/bin/perl
########################################################################
# = configarch.pl  v1.01  2/26/2001 =       = Kris Drent, GTP          =
# = Configuration Archiving Utility =       = kdrent@greenwichtech.com =
#
# Currently supports: Juniper, F5, Cacheflow, MSFC2                    
#                                                                      
# Usage :                                                              
#  - Using hosts defined hosts file:                                       
#     "configarch.pl <host-type>"
#  - Using hosts defined on command line:  
#     "configarch.pl <host-type> <host-1> <host-2> <host-N>
########################################################################

use Net::SNMP;
use Expect;

# Explicitly declare a few globals.
%config;     # holds all configuration settings
%hosttype;   # host group aliases
@hosts;      # fqdn of hosts to operate on
%users;      # user hash, entry is 3 cell array [user,passwd,enablepasswd]
$host_type;

# Set this for stdout debugging info, expect output, SNMP reports , etc... 
# (0=no debugging output)
#  1: Print SNMP trap messages
#  2: Print SNMP msgs + all Expect output
$debugging = 2;

# Mute standard out for interactive "expect" sessions
if($debugging < 2){
 $Expect::Log_Stdout = 0;
}

# Notify NerveCenter that we've started
$starttime = localtime;
send_trap("configarch.pl", 0, "START: $starttime");

if(scalar(@ARGV)<1){  # If no arguments are given, print usage message to stdout
  print "Usage: \n"
       ." using hosts file:  configarch.pl <host-type>\n"
       ." manual hosts list: configarch.pl <host-type> <hostname-1> <hostname-2> <hostname-N>\n";
  snmp_die("configarch.pl", "EXIT: no command line arguments given.");
}

# Set specified host type
$host_type = shift(@ARGV);

# Load Configuration
load_config("./configarch.conf");     # reads config file, and creates host-type alias hash
# Load User Account Information
load_users($config{users_file});      # loads user name/pass per host type.

# Get host information from command line argument(s)
if(scalar(@ARGV)==0){           # Run by host group, read hosts from hosts file
  load_hosts($config{hosts_file}, $host_type); # searches host file for hosts of type $host_type
}
elsif(scalar(@ARGV)>=1) {       # Run from list of hosts given at command line
  while(@ARGV){                 # Load host array from remaining arguments
    push(@hosts,[shift(ARGV), $hosttype{$host_type}]);
  } 
}

# Setup Local Paths (set in configarch.conf file)
my $sshpath    = $config{ssh_path}; 
my $scppath    = $config{scp_path};   
my $telnetpath = $config{telnet_path}; 

# Host loop  (host array contains hostname, handler name )
foreach $host (@hosts) {
  $handler = @$host[1];
  &$handler(@$host[0], $host_type); # Equivilent to: "handler_name(host_name, $host_type);"
} # end foreach host

# Send end timestamp trap

my $endtime = localtime;
send_trap("configarch.pl", 0, "END: $endtime");

exit;

#======- END MAIN -===============================================================


#==== Host Archive Handlers =======================================================
#--      Note: hostgroup handler entries in the config file must match the       --
#--            names of these subroutines idendically (case sensitive too.)      --
#==================================================================================

#---------------------------------------------------------------------------
#--- Archive JUNIPER config ---   [ Completed: 3/28/2001  K. Drent]
#  Note: due to a TACACS issue with Juniper, we no longer can use scp to copy 
#  the /config/juniper.conf file from the box.  I've rewritten the handler to 
#  ssh in, then show config, capturing the screen output.
sub juniper_handler {

  # Set up host, login name, and password(s)
  my ($host, $htype) = @_;
  unless ($host) { snmp_die ("juniper_handler", "No host provided. (Sub Argument)\n"); }
  unless ($htype) { snmp_die ("juniper_handler", "No host type provided. (Sub Argument)\n"); }
  my ($user, $passwd, $enablepw) = @{$users{$htype}};
  unless ($user && $passwd) { snmp_die("juniper_handler","No user login/password supplied (Sub Argument.)\n"); }

  # Allow explicitly empty entries using special key phrase "<none>" in users file
  if($user     eq "<none>") { $user    = "";}  # Not to be used in production 
  if($passwd   eq "<none>") { $passwd  = "";}  # environment. (please)
  if($enablepw eq "<none>") { $enablepw= "";}
  
  # Set Expected prompt
  my $prompt = ">";
  
  # Create archive file name
  my $archivename = $host."_".timestamp().".cfa";

  # Make sure destination directory exists
  if (! -d "$htype"){
    if(! mkdir "$htype"){
      send_trap("juniper_handler", 1, "Failed: Could not create directory ./$htype");
      return;
    }
  }
  
  # SSH: start ssh process
  $ssh = Expect->spawn("$sshpath/ssh $host -l $user") || snmp_die("f5_handler","Failed: Couldn't spawn ssh: $!");

  # SSH: Wait for password prompt:
  $match = $ssh->expect(30, "Permission denied", "HOST IDENTIFICATION HAS CHANGED", "continue connecting (yes/no)", "ssword:");
  if    (!$match)   {send_trap("juniper_handler", 1,"SSH Failed: Could not access host $host via ssh. (".$ssh->exp_error().")"); goto JUNIPER_END;}
  elsif ($match==1) {send_trap("juniper_handler", 1,"SSH Failed: Permission denied for $user before giving password."); goto JUNIPER_END;}
  elsif ($match==2) {send_trap("juniper_handler", 1,"SSH Failed: Host key for $host has changed, not allowed to connect with ssh."); goto JUNIPER_END;}
  elsif ($match==3) {
     # When the server hasn't connected to this host before, it says it can't validate the
     # host key because it doesn't already have it stored.
     send_trap ("juniper_handler", 1,"SCP Notice: Automatically adding host key for $host.\n");
     print $ssh "yes\r";
  }
  
  # SSH: give password to ssh 
  $ssh->exp_stty('-echo');  # hide output text, (when debugging)
  print $ssh $passwd."\r";
  $ssh->exp_stty('echo');   # unhide
  
  ##--------------------------------------------------------------------
  ##----- With current TACACS configuration, we immediately get an enable prompt
  ##----- therefore we don't need this next section to do the enable.
  ##----- Un-comment if needed
  ##---------------------------------------------------------------------
  ## SSH: Expect basic prompt
  #$match = $ssh->expect(30, "Permission denied",">");
  #if    (!$match)   {send_trap("juniper_handler", 1,"Session Failed: Logged in, but did not receive root prompt ($user@$host.)"); goto JUNIPER_END;}
  #elsif ($match==1) {send_trap("juniper_handler", 1,"SSH Failed: Permission denied for user $user on host $host. Check password."); goto JUNIPER_END;}
  # 
  ## SSH: send enable command
  #print $ssh "enable\r";
  #
  ## SSH: Expect Password prompt:
  #$match = $ssh->expect(30, "ssword:");
  #if (!$match) {send_trap("juniper_handler", 1,"Session Failed: Did not receive enable password prompt. (".$ssh->exp_error().")"); goto JUNIPER_END;}
  ## SSH: send enable password
  #$ssh->exp_stty('-echo');
  #print $ssh $enablepw."\r";
  #$ssh->exp_stty('echo');
  ## Prompt should now be "#"
  #$prompt="#";
  #---------------------------------------------------------------------
  
  # SSH: Expect the prompt:
  $match = $ssh->expect(30, "Access denied", "Permission denied", $prompt);
  if (!$match) {send_trap("juniper_handler", 1,"Session Failed: Did not receive enabled prompt after enable command. (".$ssh->exp_error().")"); goto JUNIPER_END;}
  elsif($match==1 || $match==2){send_trap("juniper_handler", 1,"Session Enable Failed: Password rejected."); goto JUNIPER_END;}
 
  # We now need to detect the full prompt, (This allows us to be smarter and look
  # for more than just "#" for the prompt, avoiding problems when a "#" might occur
  # somewhere in the configuration.)
  
  # SSH: send \r, anthing that comes after the 
  print $ssh "\r";
  $match = $ssh->expect(30, "\r\n"); # Read in the echoed cr lf to clear expect buffer.
  $match = $ssh->expect(30, $prompt);    # The end of the prompt response
  if (!$match) {send_trap("juniper_handler", 1,"Session Failed: Did not receive enabled prompt after enable command. (".$ssh->exp_error().")"); goto JUNIPER_END;}
  my $full_prompt = $ssh->exp_before() . $prompt; # prompt is everything captured before the >, and append the >
 
  # SSH: send show configuration command
  print $ssh "show configuration | no-more\r";
  
  # SSH: Expect "show configuration\r\n" (note the \n")
  #    (The terminal echos back our command, read it in to clear the buffer.)
  
  $match = $ssh->expect(30, "\n");
  if (!$match) {send_trap("juniper_handler", 1,"Session Failed: Did not recieve echo of show command. (".$ssh->exp_error().")"); goto JUNIPER_END;}
 
  # SSH: Expect the full enable prompt, capturing text until then.
  $match = -2;         # Set to unimportant value
  my $config_file="";
  $match = $ssh->expect(30, $full_prompt);
  if (!$match) {send_trap("juniper_handler", 1,"Session Failed: Did not recieve prompt after show command. (".$ssh->exp_error().")"); goto JUNIPER_END;}
  
  # All text before prompt is the configuration text.
  $config_file = $ssh->exp_before() . "\r\n";
  
  # Strip unwanted characters
  $config_file =~ s/\r//g; # Strip the \r from the terminal \r\n line endings (create Unix endings)
                           # Optional, comment out if \r\n line ends are wanted.
  # Save config file
  my $CONFIG;
  open(CONFIG, ">$htype/$archivename")
      or send_trap("juniper_handler", 1, "Failed: could not create/open file $htype/$archivename. ($!)");
  print CONFIG $config_file;
  close CONFIG;
  
  send_trap($host, 0, "Configuration archived and stored successfully.(file: $htype/$archivename)");
 
  JUNIPER_END:
 
  if ($ssh) {
   print $ssh "exit\r"; 
   $ssh->hard_close(); 
  }
 
} # End juniper_handler

#---------------------------------------------------------------------------
#--- Archive CacheFlow config ---  [ Completed: 2/15/2001 ]
sub cacheflow_handler {

  # Set up host, login name, and password(s)
  my ($host, $htype) = @_;
  unless ($host) { snmp_die ("cacheflow_handler", "No host provided. (Sub Argument)\n"); }
  unless ($htype) { snmp_die ("cacheflow_handler", "No host type provided. (Sub Argument)\n"); }
  my ($user, $passwd, $enablepw) = @{$users{$htype}};
  unless ($user && $passwd) { snmp_die("cacheflow_handler","No user login/password supplied (Sub Argument.)\n"); }

  # Allow explicitly empty entries using special key phrase "<none>" in users file
  if($user     eq "<none>") { $user    = "";}  # Not to be used in production 
  if($passwd   eq "<none>") { $passwd  = "";}  # environment. (please)
  if($enablepw eq "<none>") { $enablepw= "";}
  
  # Define paths, file names
  my $telnetpath = "/usr/bin";  # local
  my $archivename = $host."_".timestamp().".cfa";

  # Make sure destination directory exists
  if (! -d "$htype"){
    if(! mkdir "$htype"){
      send_trap("cacheflow_handler", 1, "Failed: Could not create directory ./$htype");
      return;
    }
  }

  # Telnet: start telnet process
  $telnet = Expect->spawn("$telnetpath/telnet $host") || snmp_die("cacheflow_handler","Failed: Couldn't spawn telnet: $!");

  # Telnet: Expect Username prompt:
  $match = $telnet->expect(30, "Username:");
  if (!$match) {send_trap("f5_handler", 1,"Telnet Failed: Could not access host $host via telnet. (".$telnet->exp_error().")"); goto CACHEFLOW_END;}
  # Telnet: send username
  print $telnet $user."\r";
  
  # Telnet: Expect Password prompt:
  $match = $telnet->expect(30, "Password:");
  if (!$match) {send_trap("f5_handler", 1,"Telnet Failed: Did not receive password prompt. (".$telnet->exp_error().")"); goto CACHEFLOW_END;}
 
  # Telnet: send password
  $telnet->exp_stty('-echo');  # hide text output (When debugging)
  print $telnet $passwd."\r";
  $telnet->exp_stty('echo');   # unhide
  
  # Telnet: Expect standard ">" prompt:
  $match = $telnet->expect(30, ">", "Username");
  if    (!$match) {send_trap("f5_handler", 1,"Telnet Failed: Did not receive prompt after supplying password. (".$telnet->exp_error().")"); goto CACHEFLOW_END;}
  elsif ($match=1) {send_trap("f5_handler", 1,"Telnet Failed: Incorrect login/password for host $host."); goto CACHEFLOW_END;}
 
  # Telnet: send enable command
  print $telnet "enable\r";
  
  # Telnet: Expect Password prompt:
  $match = $telnet->expect(30, "Password:");
  if (!$match) {send_trap("f5_handler", 1,"Telnet Failed: Did not receive enable password prompt. (".$telnet->exp_error().")"); goto CACHEFLOW_END;}
  # Telnet: send enable password
  $telnet->exp_stty('-echo');
  print $telnet $enablepw."\r";
  $telnet->exp_stty('echo');
  
  # FIXME: should add catch for failed enable login (ie. incorrect passwd)!
  # Telnet: Expect the "#" enable prompt:
  $match = $telnet->expect(30, "#");
  if (!$match) {send_trap("f5_handler", 1,"Telnet Failed: Did not receive enable prompt after enable command. (".$telnet->exp_error().")"); goto CACHEFLOW_END;}
 
  # We need to detect the full enable prompt.
  # Telnet: send \r, anthing that comes after the 
  print $telnet "\r";
  $match = $telnet->expect(30, "\r\n"); # The echo;
  $match = $telnet->expect(30, "#");    # The end of the prompt response
  if (!$match) {send_trap("f5_handler", 1,"Telnet Failed: Did not receive enabled prompt after enable command. (".$telnet->exp_error().")"); goto CACHEFLOW_END;}
  my $en_prompt = $telnet->exp_before() . "#"; # prompt is everything before the #, and append the #
 
  
  # Telnet: send show configuration command
  print $telnet "show configuration\r";
  
  # Telnet: Expect "show configuration\r\n" (note the \n")
  #    (The terminal echos back our command, read it in to clear the buffer.)
  $match = $telnet->expect(30, "show configuration\r\n");
  if (!$match) {send_trap("f5_handler", 1,"Telnet Failed: Did not receive command echo. (".$telnet->exp_error().")"); goto CACHEFLOW_END;}
 
  # Telnet: Expect the full enable prompt OR "--More--", capturing test along the way.
  $match = -2;
  my $config_file="";
  while($match != 2){
    $match = $telnet->expect(30, "\r\n--More--", $en_prompt);
    if (!$match) {send_trap("f5_handler", 1,"Telnet Failed: Did not recieve prompt after show command. (".$telnet->exp_error().")"); goto CACHEFLOW_END;}
    elsif($match==1) { # Found "More" prompt, save text (not includeing more), and keep going."
      $config_file .= $telnet->exp_before() . "\r\n";
      print $telnet " "; # Keep going.
    }
    elsif( $match==2) { 
      $config_file .= $telnet->exp_before() . "\r\n";
      last; # Found enable prompt. We're done capturing 
    }
  }
  
  # Strip unwanted characters
  $config_file =~ s/\e\[2K\e\[120D//g;  # Strip escape characters left from --More-- prompt
  $config_file =~ s/\r//g; # Strip the \r from the terminal \r\n line endings (create Unix endings)
                           # Optional, comment out if \r\n are wanted.
  # Save config file
  my $CONFIG;
  open(CONFIG, ">$htype/$archivename")
      or send_trap("cacheflow_handler", 1, "Failed: could not create/open file $htype/$archivename. ($!)");
  print CONFIG $config_file;
  close CONFIG;
  
  # Send trap signifying "success" (value=0)
  send_trap($host, 0, "Configuration archived and stored successfully.(file: $htype/$archivename)");
 
  CACHEFLOW_END:
  if ($telnet) { 
    # Telnet: exit session, let CLI close connection.
     print $telnet "exit\r";
     $telnet->hard_close(); 
  }
 
} # End cacheflow_handler


#----------------------------------------------------------------------------
#---- Archive F5 config ----  [ Completed: 2/15/2001  K. Drent]
sub f5_handler {
  
  # Set up host, login name, and password(s)
  my ($host, $htype) = @_;
  unless ($host) { snmp_die ("f5_handler", "No host provided. (Sub Argument)\n"); }
  unless ($htype) { snmp_die ("f5_handler", "No host type provided. (Sub Argument)\n"); }
  my ($user, $passwd, $enable) = @{$users{$htype}};
  unless ($user && $passwd) { snmp_die("f5_handler","No user login/password supplied (Sub Argument.)\n"); }
  
  # Allow explicitly empty entries using special key phrase "<none>" in users file
  if($user     eq "<none>") { $user    = "";}  # Not to be used in production 
  if($passwd   eq "<none>") { $passwd  = "";}  # environment. (please)
  if($enablepw eq "<none>") { $enablepw= "";}
  
  # Define paths, file names
  my $archivename = "/var/tmp/".$host."_".timestamp().".tgz";
  my $f5_file_list = "/etc/bigd.conf " 
                ."/etc/bigip.conf " 
                ."/etc/bigip.interfaces " 
                ."/etc/bigd.conf "
                ."/etc/bigip.conf "
                ."/etc/bigip.interfaces "
                ."/etc/bigip.license "
                ."/etc/crontab "
                ."/etc/ethers "
                ."/etc/hosts.allow "
                ."/etc/hosts.deny "
                ."/etc/inetd.conf "
                ."/etc/ipf.conf "
                ."/etc/ipnat.conf "
                ."/etc/ipfw.conf "
                ."/etc/ipfw.filt "
                ."/etc/ipfwrate.conf "
                ."/etc/ipfwrate.filt "
                ."/etc/master.passwd "
                ."/etc/namedb "
                ."/etc/netstart "
                ."/etc/ntp.conf "
                ."/etc/passwd "
                ."/etc/rateclass.conf "
                ."/etc/snmpd.conf "
                ."/etc/rc "
                ."/etc/rc.local "
                ."/etc/rc.sysctl "
                ."/etc/resolv.conf "
                ."/etc/sendmail.cf "
                ."/etc/ssh_config "
                ."/etc/sshd_config "
                ."/etc/ttys.conf "
                ."/etc/ssh2/ssh2_config "
                ."/etc/ssh2/sshd2_config "
                ."/var/f5/bigdb/user.db "
                ."/var/f5/httpd/basicauth/users "
                ."/var/f5/www/seeit/.users "
                ."/var/asr/gateway/certs "
                ."/var/asr/gateway/private "
                ."/root/.ssh "
                ."/root/.ssh2 ";
                
  # Get filename of archive, (i.e. strip path off)
  $archivename =~ /.*\/(.+?)$/;
  $filename = $1;

  # Make sure destination directory exists
  if (! -d "$htype"){
    if(! mkdir "$htype"){
      send_trap("f5_handler", 1, "Failed: Could not create directory ./$htype");
      return;
    }
  }

  # SSH: start ssh process
  $ssh = Expect->spawn("$sshpath/ssh $host -l $user") || snmp_die("f5_handler","Failed: Couldn't spawn ssh: $!");

  # SSH: Wait for password prompt:
  $match = $ssh->expect(30, "Permission denied", "HOST IDENTIFICATION HAS CHANGED","continue connecting (yes/no)", "ssword:");
  if    (!$match)   {send_trap("f5_handler", 1,"SSH Failed: Could not access host $host via ssh. (".$ssh->exp_error().")"); goto F5_END;}
  elsif ($match==1) {send_trap("f5_handler", 1,"SSH Failed: Permission denied for $user before giving password."); goto F5_END;}
  elsif ($match==2) {send_trap("f5_handler", 1,"SSH Failed: Host key for $host has changed, not allowed to connect with ssh."); goto F5_END;}
  elsif ($match==3) {
     # When the server hasn't connected to this host before, it says it can't validate the
     # host key because it doesn't already have it stored.
     send_trap ("f5_handler", 1,"SCP Notice: Automatically adding host key for $host.\n");
     print $ssh "yes\r";
  }
  
  # SSH: give password to ssh 
  $ssh->exp_stty('-echo');
  print $ssh $passwd."\r";
  $ssh->exp_stty('echo');
  
  # SSH: look for pre-prompt information or prompts
  $match = $ssh->expect(30, "Terminal type?", "#", "Permission denied");
  if    (!$match)   {send_trap("f5_handler", 1,"SSH Failed: Could not access host $host via ssh. (".$ssh->exp_error().")"); goto F5_END;}
  elsif ($match==1) { print $ssh "vt100\r"; }
  elsif ($match==2) { print $ssh "\r"; }
  elsif ($match==3) { send_trap("f5_handler", 1, "SSH Failed: Password incorect for user $user on host $host.\n"); goto F5_END;}
 
  # SSH: Expect hash (#) prompt
  $match = $ssh->expect(30, "#");
  if    (!$match)   {send_trap("f5_handler", 1,"SSH Failed: Logged in, but did not receive root prompt ($user@$host.)"); goto F5_END;}
 
  # SSH: Archive files into /var/tmp/configarch_<datetimestamp>.tgz
  print $ssh "tar -zcf $archivename $f5_file_list\r";
            
  # SSH: Expect hash (#) prompt
  $match = $ssh->expect(30, "#");
  if    (!$match)   {send_trap("f5_handler", 1,"SSH Failed: After issuing remote archive command, did not receive root prompt.");  
                     goto F5_END;}
 
  #-- SCP: start scp process --
  $scp = Expect->spawn("$scppath/scp $user\@$host:$archivename $htype/") || die "Couldn't spawn scp: $!";

  # SCP: Wait for password prompt:
  $match = $scp->expect(30, "HOST IDENTIFICATION HAS CHANGED", "password:");
  if    (!$match)   {send_trap ("f5_handler", 1,"SCP Failed: Could not access host $host via scp. (".$scp->exp_error().")\n");
                     goto F5_END;}
  elsif ($match==1) {send_trap ("f5_handler", 1,"SCP Failed: Host key for $host has changed, not allowed to connect with scp.\n");
                     goto F5_END;}
  # SCP: Send paswsord to scp
  print $scp $passwd."\r";
 
  $match = $scp->expect(120, "Permission denied", "No such file or directory", "100%");
  if    (!$match)   {send_trap("f5_handler", 1,"SCP Failed: Could not access host $host via scp. (".$scp->exp_error().")\n"); 
                     goto F5_END;}
  elsif ($match==1) {send_trap("f5_handler", 1, "SCP Failed: Password incorect for $user@$host.\n"); goto F5_END;}
  elsif ($match==2) {send_trap("f5_handler", 1, "SCP Failed: File \"$archivename\" does not exist on host $host.\n"); 
                     goto F5_END;}
  elsif($match==3) {send_trap($host, 0, "Configuration archived and stored successfully.(file: $htype/$archivename)"); }# SUCCESS!
 
  # SSH: delete temp remote archive
  print $ssh "rm -f $archivename\r";
            
  # SSH: Expect hash (#) prompt
  $match = $ssh->expect(30, "#");
  if    (!$match)   {send_trap("f5_handler", 1,"SSH Failed: After issuing remote delete command, did not receive root prompt.");  
                     goto F5_END;}
 
  F5_END:
  if($ssh) { 
    print $ssh "exit\r";
    $ssh->hard_close(); 
  }
  if($scp) { $scp->hard_close(); }
  return;
} # End f5_handler()


#---------------------------------------------------------------------------
#--- Archive MSFC2 config ---   [ Completed: 2/19/2001  K. Drent]
sub msfc2_handler {

  # Set up host, login name, and password(s)
  my ($host, $htype) = @_;
  unless ($host) { snmp_die ("msfc2_handler", "No host provided. (Sub Argument)\n"); }
  unless ($htype) { snmp_die ("msfc2_handler", "No host type provided. (Sub Argument)\n"); }
  my ($user, $passwd, $enablepw) = @{$users{$htype}};
  unless ($user && $passwd) { snmp_die("msfc2_handler","No user login/password supplied (Sub Argument.)\n"); }

  # Allow explicitly empty entries using special key phrase "<none>" in users file
  if($user     eq "<none>") { $user    = "";}  # Not to be used in production 
  if($passwd   eq "<none>") { $passwd  = "";}  # environment. (please)
  if($enablepw eq "<none>") { $enablepw= "";}
  
  # Create archive file name
  my $archivename = $host."_".timestamp().".cfa";

  # Make sure destination directory exists
  if (! -d "$htype"){
    if(! mkdir "$htype"){
      send_trap("msfc2_handler", 1, "Failed: Could not create directory ./$htype");
      return;
    }
  }
  
  # SSH: start ssh process
  $ssh = Expect->spawn("$sshpath/ssh $host -l $user") || snmp_die("msfc2_handler","Failed: Couldn't spawn ssh: $!");

  # SSH: Wait for password prompt:
  $match = $ssh->expect(100, "Permission denied", "HOST IDENTIFICATION HAS CHANGED", "continue connecting (yes/no)", "ssword:");
  if    (!$match)   {send_trap("msfc2_handler", 1,"SSH Failed: Could not access host $host via ssh. (".$ssh->exp_error().")"); goto MSFC2_END;}
  elsif ($match==1) {send_trap("msfc2_handler", 1,"SSH Failed: Permission denied for $user before giving password."); goto MSFC2_END;}
  elsif ($match==2) {send_trap("msfc2_handler", 1,"SSH Failed: Host key for $host has changed, not allowed to connect with ssh."); goto MSFC2_END;}
  elsif ($match==3) {
     # When the server hasn't connected to this host before, it says it can't validate the
     # host key because it doesn't already have it stored.
     send_trap ("msfc2_handler", 1,"SCP Notice: Automatically adding host key for $host.\n");
     print $ssh "yes\r";
  }
  
  # SSH: give password to ssh 
  $ssh->exp_stty('-echo');  # hide output text, (when debugging)
  print $ssh $passwd."\r";
  $ssh->exp_stty('echo');   # unhide
  
  ##--------------------------------------------------------------------
  ##----- With current TACACS configuration, we immediately get an enable prompt
  ##----- therefore we don't need this next section to do the enable.
  ##----- Un-comment if needed
  ##---------------------------------------------------------------------
  ## SSH: Expect basic prompt
  #$match = $ssh->expect(30, "Permission denied",">");
  #if    (!$match)   {send_trap("msfc2_handler", 1,"Session Failed: Logged in, but did not receive root prompt ($user@$host.)"); goto MSFC2_END;}
  #elsif ($match==1) {send_trap("msfc2_handler", 1,"SSH Failed: Permission denied for user $user on host $host. Check password."); goto MSFC2_END;}
 # 
  ## SSH: send enable command
  #print $ssh "enable\r";
  
  ## SSH: Expect Password prompt:
  #$match = $ssh->expect(30, "ssword:");
  #if (!$match) {send_trap("msfc2_handler", 1,"Session Failed: Did not receive enable password prompt. (".$ssh->exp_error().")"); goto MSFC2_END;}
  ## SSH: send enable password
  #$ssh->exp_stty('-echo');
  #print $ssh $enablepw."\r";
  #$ssh->exp_stty('echo');
  #--------------------------------------------------------
  
  # SSH: Expect the "#" enable prompt:
  $match = $ssh->expect(30, "Access denied", "Permission denied", "#");
  if (!$match) {send_trap("msfc2_handler", 1,"Session Failed: Did not receive enabled prompt after enable command. (".$ssh->exp_error().")"); goto MSFC2_END;}
  elsif($match==1 || $match==2){send_trap("msfc2_handler", 1,"Session Enable Failed: Password rejected."); goto MSFC2_END;}
 
  # We now need to detect the full prompt, (This allows us to be smarter and look
  # for more than just "#" for the prompt, avoiding problems when a "#" might occur
  # somewhere in the configuration.)
  
  # SSH: send \r, anthing that comes after the 
  print $ssh "\r";
  $match = $ssh->expect(30, "\r\n"); # Read in the echoed cr lf to clear expect buffer.
  $match = $ssh->expect(30, "#");    # The end of the prompt response
  if (!$match) {send_trap("msfc2_handler", 1,"Session Failed: Did not receive enabled prompt after enable command. (".$ssh->exp_error().")"); goto MSFC2_END;}
  my $en_prompt = $ssh->exp_before() . "#"; # prompt is everything captured before the #, and append the #
 
  # SSH: set "term length 0" which will get rid of the "--More--" prompt when
  #      capturing the configuration from the terminal.
  print $ssh "term length 0\r";
  # SSH: Expect the "#" enable prompt:
  $match = $ssh->expect(30, $en_prompt);
  if (!$match) {send_trap("msfc2_handler", 1,"Session Failed: Did not receive enabled prompt after \"term length 0\" command. (".$ssh->exp_error().")"); goto MSFC2_END;}
  
  # SSH: send show configuration command
  print $ssh "show configuration\r";
  
  # SSH: Expect "show configuration\r\n" (note the \n")
  #    (The terminal echos back our command, read it in to clear the buffer.)
  
  $match = $ssh->expect(30, "show configuration\r\n");
  $match = $ssh->expect(30, "-re", 'Using \d+ out of \d+ bytes\r\n');
  if (!$match) {send_trap("msfc2_handler", 1,"Session Failed: Did not recieve Config line \"Using x out of x bytes\" after show command. (".$ssh->exp_error().")"); goto MSFC2_END;}
 
  # SSH: Expect the full enable prompt, capturing text until then.
  $match = -2;         # Set to unimportant value
  my $config_file="";
  $match = $ssh->expect(30, $en_prompt);
  if (!$match) {send_trap("msfc2_handler", 1,"Session Failed: Did not recieve prompt after show command. (".$ssh->exp_error().")"); goto MSFC2_END;}
  
  # All text before prompt is the configuration text.
  $config_file = $ssh->exp_before() . "\r\n";
  
  # Strip unwanted characters
  $config_file =~ s/\r//g; # Strip the \r from the terminal \r\n line endings (create Unix endings)
                           # Optional, comment out if \r\n line ends are wanted.
  # Save config file
  my $CONFIG;
  open(CONFIG, ">$htype/$archivename")
      or send_trap("msfc2_handler", 1, "Failed: could not create/open file $htype/$archivename. ($!)");
  print CONFIG $config_file;
  close CONFIG;
  
  send_trap($host, 0, "Configuration archived and stored successfully.(file: $htype/$archivename)");
 
  MSFC2_END:
 
  if ($ssh) {
   print $ssh "exit\r"; 
   $ssh->hard_close(); 
  }
 
} # End msfc2_handler


#---------------------------------------------------------------------------
#--- Archive cisco config ---   [ ongoing: 6/18/2001  K. Baumann]
sub cisco_handler {

  # Set up host, login name, and password(s)
  my ($host, $htype) = @_;
  unless ($host) { snmp_die ("cisco_handler", "No host provided. (Sub Argument)\n"); }
  unless ($htype) { snmp_die ("cisco_handler", "No host type provided. (Sub Argument)\n"); }
  my ($user, $passwd, $enablepw) = @{$users{$htype}};
  unless ($user && $passwd) { snmp_die("cisco_handler","No user login/password supplied (Sub Argument.)\n"); }

  # Allow explicitly empty entries using special key phrase "<none>" in users file
  if($user     eq "<none>") { $user    = "";}  # Not to be used in production 
  if($passwd   eq "<none>") { $passwd  = "";}  # environment. (please)
  if($enablepw eq "<none>") { $enablepw= "";}
  
  # Create archive file name
  my $archivename = $host."_".timestamp().".cfa";

  # Make sure destination directory exists
  if (! -d "$htype"){
    if(! mkdir "$htype"){
      send_trap("cisco_handler", 1, "Failed: $host: Could not create directory ./$htype");
      return;
    }
  }
  

  # SSH: start ssh process
  $ssh = Expect->spawn("$sshpath/ssh $host -l $user") || snmp_die("cisco_handler","Failed: Couldn't spawn ssh: $!");


  # SSH: Wait for prompt: Determine if ssh capable.  If not, try telnet.
  $match = $ssh->expect(100, "Permission denied", "HOST IDENTIFICATION HAS CHANGED", "continue connecting (yes/no)", "ssword:");
  if    (!$match)   {goto CISCO_TELNET;}
  elsif ($match==1) {send_trap("cisco_handler", 1,"SSH Failed: $host: Permission denied for $user before giving password."); goto CISCO_END;}
  elsif ($match==2) {send_trap("cisco_handler", 1,"SSH Failed: Host key for $host has changed, not allowed to connect with ssh."); goto CISCO_END;}
  elsif ($match==3) {
     # When the server hasn't connected to this host before, it says it can't validate the
     # host key because it doesn't already have it stored.
     send_trap ("cisco_handler", 1,"SCP Notice: Automatically adding host key for $host.\n");
     print $ssh "yes\r";
  elsif ($match==4) {
  }
  

  # SSH: give password to ssh 
  $ssh->exp_stty('-echo');  # hide output text, (when debugging)
  print $ssh $passwd."\r";
  $ssh->exp_stty('echo');   # unhide
  



  # Look to see if enabled or not - if not try to enable
  $match = $ssh->expect(30, "(enable)" , ">" , "#" );
  if (!$match) {send_trap("cisco_handler", 1,"Session Failed: $host: Enable not non-enable working. (".$ssh->exp_error().")"); goto CISCO_END;}





  
  # SSH: Expect the "(enable)" enable prompt:
  $match = $ssh->expect(30, "Access denied", "Permission denied", "(enable)" , ">" );
  if (!$match) {send_trap("cisco_handler", 1,"Session Failed: $host: Did not receive first enabled prompt after enable command. (".$ssh->exp_error().")"); goto CISCO_END;}
  elsif($match==1 || $match==2){send_trap("cisco_handler", 1,"Session Enable Failed: $host: Password rejected."); goto CISCO_END;}
  elsif($match==4)
	{ 
  	print $ssh "enable\r";
	$match = $ssh->expect(30, "ssword:");
	if (!$match) {send_trap("cisco_handler", 1,"Session Failed: Did not receive enable password prompt. (".$ssh->exp_error().")"); goto CISCO_END;}
	# SSH: send enable password
  	$ssh->exp_stty('-echo');
  	print $ssh $enablepw."\r";
  	$ssh->exp_stty('echo');
	}
	 
  # We now need to detect the full prompt, (This allows us to be smarter and look
  # for more than just "#" for the prompt, avoiding problems when a "#" might occur
  # somewhere in the configuration.)
  
  # SSH: send \r, anthing that comes after the 
  print $ssh "\r";
  print $ssh "\r";
  $match = $ssh->expect(30, "\r\n"); # Read in the echoed cr lf to clear expect buffer.
  $match = $ssh->expect(30, ")");    # The end of the prompt response
  if (!$match) {send_trap("cisco_handler", 1,"Session Failed: $host: Did not receive second enabled prompt after enable command. (".$ssh->exp_error().")"); goto CISCO_END;}
  my $en_prompt = $ssh->exp_before() . ")"; # prompt is everything captured before the #, and append the #
 
  # SSH: send show configuration command
  print $ssh "show config\r";
  
  # SSH: Expect "show configuration\r\n" (note the \n")
  #    (The terminal echos back our command, read it in to clear the buffer.)
  
#  $match = $ssh->expect(30, "show config\r\n");
#  $match = $ssh->expect(30, "-re", 'Using \d+ out of \d+ bytes\r\n');
#  if (!$match) {send_trap("cisco_handler", 1,"Session Failed: $host: Did not recieve Config line \"Using x out of x bytes\" after show command. (".$ssh->exp_error().")"); goto CISCO_END;}
 
  # SSH: Expect the full enable prompt, capturing text until then.
  $match = -2;         # Set to unimportant value
  my $config_file="";
#
# do the right thing when --More-- comes around
#
  while($match != 2){
    $match = $ssh->expect(30, "\r\n--More--", $en_prompt );
    if (!$match) {send_trap("cisco_handler", 1,"SSH Failed: $host: Did not recieve prompt after show command. (".$ssh->exp_error().")"); goto CISCO_END;}
    elsif($match==1) { # Found "More" prompt, save text (not includeing more), and keep going."
      $config_file .= $ssh->exp_before() . "\r\n";
      print $ssh " "; # Keep going.
    }
    elsif( $match==2) { 
      $config_file .= $ssh->exp_before() . "\r\n";
      last; # Found enable prompt. We're done capturing 
    }
  }
  
  # Strip unwanted characters
  $config_file =~ s/\e\[2K\e\[120D//g;  # Strip escape characters left from --More-- prompt
  $config_file =~ s/\r//g; # Strip the \r from the terminal \r\n line endings (create Unix endings)
                           # Optional, comment out if \r\n are wanted.
  # Save config file
  my $CONFIG;
  open(CONFIG, ">$htype/$archivename")
      or send_trap("cisco_handler", 1, "Failed: $host: could not create/open file $htype/$archivename. ($!)");
  print CONFIG $config_file;
  close CONFIG;
  
  # Send trap signifying "success" (value=0)
  send_trap($host, 0, "Configuration archived and stored successfully.(file: $htype/$archivename)");
 
#----------------------------------------------------
# Don't need this right now
#
#  $match = $ssh->expect(30, $en_prompt);
#  if (!$match) {send_trap("cisco_handler", 1,"Session Failed: Did not recieve prompt after show command. (".$ssh->exp_error().")"); goto CISCO_END;}
#  
#  # All text before prompt is the configuration text.
#  $config_file = $ssh->exp_before() . "\r\n";
#  
#  # Strip unwanted characters
#  $config_file =~ s/\r//g; # Strip the \r from the terminal \r\n line endings (create Unix endings)
#                           # Optional, comment out if \r\n line ends are wanted.
#  # Save config file
#  my $CONFIG;
#  open(CONFIG, ">$htype/$archivename")
#      or send_trap("cisco_handler", 1, "Failed: could not create/open file $htype/$archivename. ($!)");
#  print CONFIG $config_file;
#  close CONFIG;
#  
#  send_trap($host, 0, "Configuration archived and stored successfully.(file: $htype/$archivename)");
# 
#----------------------------------------------------

  CISCO_END:
 
  if ($ssh) {
   print $ssh "exit\r"; 
   $ssh->hard_close(); 
  }
 
} # End cisco_handler


###################












#---- Archive Quallaby config ----  [ Completed: 3/19/2001  K. Drent]
sub quallaby_handler {
  
  # Set up host, login name, and password(s)
  my ($host, $htype) = @_;
  unless ($host) { snmp_die ("quallaby_handler", "No host provided. (Sub Argument)\n"); }
  unless ($htype) { snmp_die ("quallaby_handler", "No host type provided. (Sub Argument)\n"); }
  my ($user, $passwd, $enable) = @{$users{$htype}};
  unless ($user && $passwd) { snmp_die("quallaby_handler","No user login/password supplied (Sub Argument.)\n"); }
  
  # Allow explicitly empty entries using special key phrase "<none>" in users file
  if($user     eq "<none>") { $user    = "";}  # Not to be used in production 
  if($passwd   eq "<none>") { $passwd  = "";}  # environment. (please)
  if($enablepw eq "<none>") { $enablepw= "";}
  
  # Define paths, file names
  my $archivename = $host."_".timestamp().".tgz";
  my $remotearchivename  = "/db01/app/autoprov/prov_backup.tgz"; 
  my $remotearchivescript= "/db01/app/autoprov/scripts/prov_backup.pl";
  my $prompt = '$';
  
  # Get filename of archive, (i.e. strip path off)
  $archivename =~ /.*\/(.+?)$/;
  $filename = $1;

  # Make sure destination directory exists
  if (! -d "$htype"){
    if(! mkdir "$htype"){
      send_trap("quallaby_handler", 1, "Failed: Could not create directory ./$htype");
      return;
    }
  }

  # SSH: start ssh process
  $ssh = Expect->spawn("$sshpath/ssh $host -l $user") || snmp_die("quallaby_handler","Failed: Couldn't spawn ssh: $!");

  # SSH: Wait for password prompt:
  $match = $ssh->expect(30, "Permission denied", "HOST IDENTIFICATION HAS CHANGED","continue connecting (yes/no)", "ssword:");
  if    (!$match)   {send_trap("quallaby_handler", 1,"SSH Failed: Could not access host $host via ssh. (".$ssh->exp_error().")"); goto QUALLABY_END;}
  elsif ($match==1) {send_trap("quallaby_handler", 1,"SSH Failed: Permission denied for $user before giving password."); goto QUALLABY_END;}
  elsif ($match==2) {send_trap("quallaby_handler", 1,"SSH Failed: Host key for $host has changed, not allowed to connect with ssh."); goto QUALLABY_END;}
  elsif ($match==3) {
     # When the server hasn't connected to this host before, it says it can't validate the
     # host key because it doesn't already have it stored.
     send_trap ("quallaby_handler", 1,"SSH Notice: Automatically adding host key for $host.\n");
     print $ssh "yes\r";
  }
  
  # SSH: give password to ssh 
  $ssh->exp_stty('-echo');
  print $ssh $passwd."\r";
  $ssh->exp_stty('echo');
  
  # SSH: look for pre-prompt information or prompts
  $match = $ssh->expect(30, "Terminal type?", "Permission denied", $prompt);
  if    (!$match)   {send_trap("quallaby_handler", 1,"SSH Failed: Could not access host $host via ssh. (".$ssh->exp_error().")"); goto QUALLABY_END;}
  elsif ($match==1) { print $ssh "vt100\r"; }
  elsif ($match==2) { send_trap("quallaby_handler", 1, "SSH Failed: Password incorect for user $user on host $host.\n"); goto QUALLABY_END;}
  elsif ($match==3) { print $ssh "\r"; }
  
  # SSH: Expect prompt
  $match = $ssh->expect(30, $prompt);
  if    (!$match)   {send_trap("quallaby_handler", 1,"SSH Failed: Logged in, but did not receive root prompt ($user@$host.)"); goto QUALLABY_END;}
 
  # SSH: Run configuration file script (creates config file)
  print $ssh $remotearchivescript . "\r";
            
  # SSH: Expect prompt
  $match = $ssh->expect(600, $prompt);
  if    (!$match)   {send_trap("quallaby_handler", 1,"SSH Failed: After issuing remote archive command, did not receive root prompt.");  
                     goto QUALLABY_END;}
 
  #-- SCP: start scp process --  (copy remote archive to local archive, renaming the file in the process)
  $scp = Expect->spawn("$scppath/scp $user\@$host:$remotearchivename $htype/$archivename") || die "Couldn't spawn scp: $!";

  # SCP: Wait for password prompt:
  $match = $scp->expect(30, "HOST IDENTIFICATION HAS CHANGED", "ssword:");
  if    (!$match)   {send_trap ("quallaby_handler", 1,"SCP Failed: Could not access host $host via scp. (".$scp->exp_error().")\n");
                     goto QUALLABY_END;}
  elsif ($match==1) {send_trap ("quallaby_handler", 1,"SCP Failed: Host key for $host has changed, not allowed to connect with scp.\n");
                     goto QUALLABY_END;}
  # SCP: Send paswsord to scp
  print $scp $passwd."\r";
 
  $match = $scp->expect(120, "Permission denied", "No such file or directory", "100%");
  if    (!$match)   {send_trap("quallaby_handler", 1,"SCP Failed: Could not access host $host via scp. (".$scp->exp_error().")\n"); 
                     goto QUALLABY_END;}
  elsif ($match==1) {send_trap("quallaby_handler", 1, "SCP Failed: Password incorect for $user@$host.\n"); goto QUALLABY_END;}
  elsif ($match==2) {send_trap("quallaby_handler", 1, "SCP Failed: File \"$archivename\" does not exist on host $host.\n"); 
                     goto QUALLABY_END;}
  elsif($match==3) {send_trap($host, 0, "Configuration archived and stored successfully.(file: $htype/$archivename)"); }# SUCCESS!
 
  # SSH: delete temp remote archive
  print $ssh "rm -f $remotearchivename\r";
            
  # SSH: Expect hash (#) prompt
  $match = $ssh->expect(30, $prompt);
  if(!$match){send_trap("quallaby_handler", 1,"SSH Failed: After issuing remote delete command, did not receive root prompt.");  
              goto QUALLABY_END;}
 
  QUALLABY_END:
  if($ssh) { 
    print $ssh "exit\r";
    $ssh->hard_close(); 
  }
  if($scp) { $scp->hard_close(); }
  return;
} # End quallaby_handler()


#----------------------------------------------------------------
#---- Configuration file loading subroutines ---------------------
#----------------------------------------------------------------

sub load_config{ # arg ($config_file_name)
  my $conffile = shift(@_);
  open(CONFIG, $conffile) or snmp_die("configarch.pl","Could not open script configuration file.");
  while (<CONFIG>) {
    chomp;                  # no newline
    s/^#.*//;                # no comments
    s/^\s+//;               # no leading white
    s/\s+$//;               # no trailing white
    next unless length;     # anything left?
    my ($var, $value) = split(/\s*=\s*/, $_, 2);
    $config{$var} = $value;
  } 
  # Create a hash of host type aliases
  create_hosttype_alias_hash($host_type);
}

sub load_users{ # arg ($user_file_name)
  my $userfile = shift(@_);
  open(USERS, $userfile) or snmp_die("configarch.pl","Could not open users file.");
  while (<USERS>) {
    chomp;                 
    s/^#.*//;              
    s/^\s+//;               
    s/\s+$//;              
    next unless length;     
    my ($group, $user, $passwd, $enablepasswd) = split(/\s+/, $_, 4);
    $users{$group} = [$user, $passwd, $enablepasswd];
  } 
}

sub load_hosts { #args ($hosts_file_name, $host_type)
  my $hostfile = shift(@_);
  open(IPS, $hostfile) or snmp_die("configarch.pl","Could not open remote hosts file.");
  my $host_type = $_[1];
  my $hostname,$htype;
  while (<IPS>) {
    # line format ip:hosttype - ex. "10.10.4.242:juniper"
    chomp;                 
    s/^#.*//;                
    s/^\s+//;             
    s/\s+$//;               
    next unless length;     
    ($hostname, $htype) = split(/\s*:\s*/, $_, 2); # fqdn|ip:hosttype
    # Add host to our host list, only if correct type.
    if($hosttype{$htype}) {
      push (@hosts, [ $hostname, $hosttype{$htype} ]);
    }
  } 
  # @hosts is now a 2 dimentional array containing: 
  #  index 0: fqdn of host
  #  index 1: handler key (name)
}

#------------ Create Host Type Alias Hash --------------------------------
sub create_hosttype_alias_hash { #arg ($hosttype)
  # Creates a hash of host type aliases, found in config file
  #   (Required after loading config file, but before 
  #    calling "load_hosts($file, $htype)")
  my $htype = shift(@_);
  
  # Check to see if specified type is defined in config file
  if(! $config{"hostgroup ". $htype}){
    snmp_die("Config Error: No host type \"$htype\" defined in config file.");
    return 0;
  }
  
  # line entry looks like this: "hostgroup f5 = f5_handler : f5_dedicated, f5_BigIP, f5_a"
  # Parse handler identifier. (result:  0, handler  1, aliases)
  @groupentry = split(/\s*:\s*/, $config{"hostgroup ". $htype}); 
  @hosttypes = split(/\s*,\s*/, $groupentry[1]); # split aliases 
  foreach $halias (@hosttypes) {
    $hosttype{$halias} = $groupentry[0]; # key=hostalias, value = handler keyword.
  }
  $hosttype{$htype} = $groupentry[0]; # set htype key as an alias for consistancy
  
  # At this point, %hosttype exists with a entry for each alias that exists
  # (when alias is used as the key).  We can now use this hash as a reference
  # for which host types we need when loading the hosts file.
}

# --------------- Send SNMP Trap  -------------------------------

sub send_trap { # args ($hostname/idname, $int_result, $message) 
  my ($hostname, $intresult, $message) = @_;
  
  # Useful for debugging at command line
  if($debugging > 0){
   print "\n## SNMPTRAP: $hostname \[$$\], result: $intresult - $message\n";
   #return; #for extensive tests only
  }
  
  # Create SNMP object  (pust hostname/community into config file.)
  my $snmp = Net::SNMP->session (
        -hostname => '66.51.32.27',
        -community => 'H0L1DAY',
        -port => 162); 
  # Send trap 
  my $endtime = time;
  #1.3.6.1.4.1.558 Generic 6 Specific 558
  @varbinds = ($config{snmp_enterprise}.'.1',OCTET_STRING,$hostname."\[$$\]",
               $config{snmp_enterprise}.'.2',INTEGER, $intresult, 
               $config{snmp_enterprise}.'.3',OCTET_STRING,$message,
              );
  # Need to put the agentaddr into the config file       
  $snmp->trap(  '-enterprise' => $config{snmp_enterprise}, #'1.3.6.1.4.1.558',
                '-agentaddr' => $config{snmp_agent_addr},
                '-generictrap' => $config{snmp_generic_trap},
                '-specifictrap' => $config{snmp_specific_trap},
                '-varbindlist' => \@varbinds); 
  $snmp->close;
}

# ------------------- Creates Timestamp for Filenames -----------------------------

sub timestamp {
  my $time_stamp;
  ($day, $month, $year, $hr, $min, $sec) = (localtime)[3,4,5,2,1,0];
  $time_stamp = sprintf("%04d%02d%02d-%02d%02d%02d", $year+1900, $month+1, $day, $hr, $min, $sec);
  return ($time_stamp);
}

# ------------------- Logging, exiting ----------------------------------------------

sub snmp_die{ # args ($process, $message) 
  my $process = shift(@_);
  my $message = shift(@_);
  # Send message trap
  send_trap ($process, -1, $message); 
  # Send end time trap, with -1 (failure) value
  $endtime = localtime;
  send_trap ("configarch.pl", -1, "END: $endtime");
  die ("$endtime: Critical! $process\[$$\], $message\n");
}



