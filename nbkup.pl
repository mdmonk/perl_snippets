#!/usr/bin/perl
use vars qw($SNMPSet $WriteNet $TFTPServer $TFTPDir $Structure $ChMod $SNMPGet $SysObjectID %CiscoSwitchMibs $CoreRouterFile $CoreSwitchFile $TestRouterFile $Touch %CiscoConfigCopy);
use strict;
use Getopt::Std;
use File::Copy;
use Fcntl ':flock';
use SF::MACDB2; # For LCU Query
use POSIX;


  my (%opts, $Hosts);
#########################################
# Set Up Environment                    #
#########################################
  $Structure = "/var/nbk/";
  $CoreRouterFile = "$Structure\FlatFiles/\CoreRouterList.txt";
  $TestRouterFile = "$Structure\FlatFiles/\TestRouterList.txt";
  $CoreSwitchFile = "$Structure\FlatFiles/\CoreSwitchList.txt";
  $SNMPSet = "/opt/OV/bin/snmpset";
  $SNMPGet = "/opt/OV/bin/snmpget";
  $WriteNet = ".1.3.6.1.4.1.9.2.1.55"; # Cisco Router Mib
  $TFTPServer = "10.34.114.80";
  $TFTPDir = "/usr/tftpdir/";
  $ChMod = "/usr/bin/chmod";
  $SysObjectID = "system.sysObjectID.0"; #System Object Identifier
  %CiscoSwitchMibs = (	"TFTPHost"   => ".1.3.6.1.4.1.9.5.1.5.1.0",
                  	"TFTPFile"   => ".1.3.6.1.4.1.9.5.1.5.2.0",
                  	"TFTPModule" => ".1.3.6.1.4.1.9.5.1.5.3.0",
                  	"TFTPAction" => ".1.3.6.1.4.1.9.5.1.5.4.0",
                  	"TFTPResult" => ".1.3.6.1.4.1.9.5.1.5.5.0", );
  %CiscoConfigCopy = (  "ccCopyProtocol"		=> ".1.3.6.1.4.1.9.9.96.1.1.1.1.2.0",
  			"ccCopySourceFileType"		=> ".1.3.6.1.4.1.9.9.96.1.1.1.1.3.0",
			"ccCopyDestFileType"		=> ".1.3.6.1.4.1.9.9.96.1.1.1.1.4.0",
			"ccCopyServerAddress"		=> ".1.3.6.1.4.1.9.9.96.1.1.1.1.5.0",
			"ccCopyFileName"		=> ".1.3.6.1.4.1.9.9.96.1.1.1.1.6.0",
			"ccCopyState"			=> ".1.3.6.1.4.1.9.9.96.1.1.1.1.10.0",
			"ccCopyEntryRowStatus"		=> ".1.3.6.1.4.1.9.9.96.1.1.1.1.14.0",
  									);
  $Touch = "/usr/bin/touch";
########################################
# Get options                          #
########################################
  getopt("r:R:s:S:V:W:v:c:",\%opts);
  # -S mass switch
  # -s single switch
  # -r single router, requires -V
  # -R mass router <type>
  # -v config viewer (requires -c)
  # -c type of config (old or new or diff(diff archived config with running config on router))
  # -W web based Mode

#######################################
# Main                                #
#######################################
if (%opts)
{
  if((defined $opts{V}) && (!defined $opts{W}))
  {
    if($opts{V} =~ /cisco/i)  # Cisco Portion of Decision
    {
      if(defined $opts{r}) # Single Router Mode (Cisco)
      {
        $opts{r} = uc ( $opts{r} );
        my $Outcome = SingleMode($opts{r},\&CiscoRouter);
	print $Outcome;
      }
      elsif(defined $opts{R}) # Mass Router Mode (Cisco) uses Mind
      {
	if($opts{R} =~ /core/i)
	{
 	  $Hosts = LoadFile($CoreRouterFile); #open comma delimited file and load array
          Spawn(\&CiscoRouter, $Hosts);
	}
	elsif($opts{R} =~ /egress/i)
	{
	  $Hosts = EgressRouterQuery();
          Spawn(\&CiscoRouter, $Hosts);
	}
	elsif($opts{R} =~ /test/i)
	{
	  $Hosts = LoadFile($TestRouterFile);
	  Spawn(\&CiscoRouter, $Hosts);
        }
      }
      elsif(defined $opts{s}) # Single Switch Mode (Cisco)
      {
        $opts{s} = uc ( $opts{s} );
        my $Outcome = SingleMode($opts{s},\&CiscoSwitch);
	print $Outcome;
      }
      elsif(defined $opts{S}) # Mass Switch Mode (Cisco) uses MAC Workflow
      {
	if($opts{S} =~ /lcu/i)
	{
	  $Hosts = LCUSwitchQuery();
          Spawn(\&CiscoSwitch, $Hosts);
        }
	elsif($opts{S} =~ /core/i)
	{
          $Hosts = LoadFile($CoreSwitchFile);
          Spawn(\&CiscoSwitch, $Hosts);
	}
      }
    }
  }
  elsif(defined $opts{W}) # Enter CGI Support
  {
    $Hosts = $ENV{list};
    my @Hosts = split /\,/, $Hosts;
    if ($opts{V} =~ /cisco/i)
    {
      if (defined $opts{R})
      {
	Spawn(\&CiscoRouter, \@Hosts);
      }
      elsif(defined $opts{S})
      {
	Spawn(\&CiscoSwitch, \@Hosts);
      }
    }
    elsif(defined $opts{v}) #for web based config viewing
    {
      if ($opts{c} !~/diff/i)
      {
        my $Config = ViewConfigNormalMode($opts{v}, $opts{c});
        print @$Config;
      }
      else
      {
         my $HTML = ViewConfigDiffMode($opts{v});
 
         print @$HTML; 
      }
    }
  }
}
else
{

  print "
	\nUsage\:\n
	 	\-r \<hostname\> single router
	 	\-V \<vendor\> (required field)(cisco for example)
	 	\-R \<type\> mass router \(egress|core\) 
	 	\-s \<hostname\> single switch
	 	\-S \<type\> mass switch \(core|lcu|test\)
         	\-W CGI Mode (+ Various Options)\n\n";
  exit(0); # exit if options aren't properly defined
}
########################################
# End Main                             #
########################################

##############################
#Ping the Host first         #
##############################
sub Oid 
{
  my $Host = shift;
  my ( @Pieces, $Output);

  $Output = `$SNMPGet $Host $SysObjectID 2>&1`;
  if ($Output !~ /not|fail|error|invalid/i)
  {
    @Pieces = split /\./,$Output;
    chomp($Pieces[11]);
    return($Pieces[11]);
  }
  else
  {
    return(1);
  }
}
##########################
# Touch a file in TFTPDir#
##########################
sub Touch
{
  my ($File) = shift;

  `$Touch $TFTPDir$File`;
  `$ChMod 666 $TFTPDir$File`;
}


##########################
# Move file to /var/nbk  #
##########################
sub MoveFile
{
  my ($File) = shift;
  my (@OldConfig, @NewConfig, $NewLine, $LineNumber,$Different,$FileDate, $CurrentDate, $FileHour, $FileDate, $CurrentHour
      ,$HourDifference);
  
  if (-e "$Structure$File")
  {
      open NEW, "$TFTPDir$File"; # open new config
      @NewConfig = <NEW>;
      open OLD, "$Structure$File";
      @OldConfig = <OLD>;
      $LineNumber = 0; #Initialize these guys
      $Different = 0; #Set Different Flag
      map{      $NewLine = $_; 
		if($NewLine !~ /ntp clock-period/i)
                { if ($NewLine ne $OldConfig[$LineNumber]) #Compare Lines
                  {
                    $Different = 1;
                  }
                }
                $LineNumber ++;
          }@NewConfig;
      #Date Protection 
      my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$Structure$File");
      my ($sec,$min,$hr,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($mtime);
      $FileDate = strftime("%D",$sec,$min,$hr,$mday,$mon,$year,$wday,$yday,$isdst);
      my ($sec,$min,$hr,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
      $CurrentDate = strftime("%D",$sec,$min,$hr,$mday,$mon,$year,$wday,$yday,$isdst);
      

      if (($CurrentDate eq $FileDate) && ($Different == 1))
      {
        #File exists in structure and it has already been backed up on the same calender date
        move("$TFTPDir$File", "$Structure$File");
	`$ChMod 600 $Structure$File`;
        unlink("$TFTPDir$File");
        return(0);
      }

      elsif (($Different == 1) && ($CurrentDate ne $FileDate)) # Files are MD different
      {
        move ("$Structure$File","$Structure\SecondCopy/$File");
        move ("$TFTPDir$File", "$Structure$File");
	`$ChMod 600 $Structure$File`;
	return(0);
      }
      else
      {
        unlink("$TFTPDir$File");
      }
  }
  else
  {
    #File doesnt exist in structure
    move ("$TFTPDir$File","$Structure$File");
    `$ChMod 600 $Structure$File`;
  }
  
}


##########################################################################
# This Module is in no way associated with the comic book vigelante spawn#
##########################################################################
sub Spawn
{
  my ($FunctionPtr, $Hosts) = @_;
  my (@things, $thing, $pid, $child_babble, $status_file);
  
  @things = @$Hosts;
  # Be aware of the impact of increasing this number
  my $maxkids   = 25;                 # Maximum number of processes to spawn
  my $offspring =  0;                 # Number of active processes
  my $debug     =  0;

  sub reaper
  {
    if ((my $child_pid = wait()) > -1) 
    {
      print "Child $child_pid returned " . $? / 256 . "\n" if ($debug);
      $offspring--;
      return 1;
    } 
    else 
    {
      return 0;                             # wait() returned -1, no children
    }
  }


  sub child_labor 
  {
    my $device = $_[0];
    my $stat_msg;

    print "Child PID $$, handling $device\n" if $debug;
    $device = uc($device);
    my $Outcome = SingleMode($device,  $FunctionPtr);
    #$stat_msg = "$device checks out OK";     # Sample status message

    return $Outcome;
  } # End of child_labor()
  
  
  for $thing (@things) 
  {
    $thing =~ s/\s+//g;                       # Strip whitespace
    next if ($thing eq "");                   # Skip if blank line

    # If max children are active, wait on one to die before spawning another.
    reaper() if ($offspring >= $maxkids);

    print "Spawning child for $thing\n" if $debug;

    if (! defined ($pid = fork() ) ) 
    {        # Can't fork
      die "ERROR: fork failed: $!\n";
    } 
    elsif ($pid) 
    {                          # Parent
      $offspring++;
    } 
    else 
    {                                  # Child.  Lower my priority then
      `/usr/bin/renice -n 10 $$`;             # call subroutine to do the
      $child_babble = child_labor($thing);    # real work.

      flock(STDOUT,LOCK_EX) or die "Child $$ ($thing): Lock failed: $!\n";
      print STDOUT "$child_babble\n";
      flock(STDOUT,LOCK_UN);

      exit 1;
    }
  }
  #--------------------------------------------------
  # Wait for all remaining children
  #--------------------------------------------------
  print "Waiting on remaining children...\n" if $debug;
  while (reaper()) {}

  exit 0;
}




##################################################
# Single Mode                                    #
##################################################
sub SingleMode
{
  my ($Host,$FunctionPtr) = @_;
  my ($Outcome, $Oid);

  $Oid = Oid($Host); #returns 1 or model number
  if ( $Oid != 1 )
  {
    Touch("$Host\.$Oid");
    $Outcome = &$FunctionPtr($Host,"$Host\.$Oid");
    if ( $Outcome == 0 )
    {
      MoveFile("$Host\.$Oid");
      return("(SUCCESS)$Host configuration backup created in /var/nbk/.\n");
    }
    elsif($Oid =~ /cisco|188|187/i) # Hey how about we try config copy
    {
      $Outcome = CiscoRouterConfigCopy($Host, "$Host\.$Oid");
      if ($Outcome == 0)
      {
        return("(SUCCESS)(ConfigCopy)$Host configuration backup created in /var/nbk/.\n");
      }
      else
      {
        return("(ERROR)(ConfigCopy)$Host configuration was not created in /var/nbk/.\n");
      }
    }
    elsif($Outcome != 0)
    {
      unlink("$TFTPDir$Host\.$Oid");
      return("(ERROR)$Host configuration was not created in /var/nbk!\n");
    }
  }
  else
  {
    unlink("$TFTPDir$Host\.$Oid");
    return("(ERROR)$Host is Unreachable(snmpget failed)!\n");
  }
}



##############################
#  Cisco Router SNMP
#  Configuration
#  Upload (Using WRITENET)
##############################
sub CiscoRouter
{
  my ($Host,$File) = @_;

  my ($Output);
  $Output = `$SNMPSet -t 40 $Host $WriteNet.$TFTPServer octetstring $File 2>&1`;
  if ( $Output !~ /failure|error/i)
  {
    return(0);
  }
  else
  {
    return(1);
  }
}

###########################
#  Cisco Router 
#  Config Upload 
#  Using ConfigCopy (The new mib-set)      
###########################
sub CiscoRouterConfigCopy
{
  my ($Host, $File) = @_;
  my ($Answer, $TimeToLeave);
  
  $Answer = `$SNMPSet $Host $CiscoConfigCopy{ccCopyProtocol} integer 1`; #Set Config Proto
  if($Answer =~ /failed|error/i){return(1)};
  $Answer = `$SNMPSet $Host $CiscoConfigCopy{ccCopySourceFileType} integer 4`; #Set Running Config
  if($Answer =~ /failed|error/i){return(1)};
  $Answer = `$SNMPSet $Host $CiscoConfigCopy{ccCopyDestFileType} integer 1`; #Set dest
  if($Answer =~ /failed|error/i){return(1)};
  $Answer = `$SNMPSet $Host $CiscoConfigCopy{ccCopyServerAddress} ipaddress $TFTPServer`;
  if($Answer =~ /failed|error/i){return(1)};
  $Answer = `$SNMPSet $Host $CiscoConfigCopy{ccCopyFileName} octetstringascii $File`;
  if($Answer =~ /failed|error/i){return(1)};
  $Answer = `$SNMPSet $Host $CiscoConfigCopy{ccCopyEntryRowStatus} integer 1`;
  if($Answer =~ /failed|error/i){return(1)};
  $Answer = `$SNMPGet $Host $CiscoConfigCopy{ccCopyState}`;
  $TimeToLeave = 0;
  while (($Answer !~ /success/) && ($TimeToLeave < 30))
  {
    $Answer = `$SNMPGet $Host $CiscoConfigCopy{ccCopyState}`;
    $TimeToLeave ++;
  }
  if ($Answer =~ /successful/)
  {
    return(0)
  }
  else
  {
    return(1)
  }
}



###########################
# Cisco Switch SNMP
# Configuration 
# Upload 
###########################
sub CiscoSwitch
{
  my ($Host, $File) = @_;
  my ($Output, $ImTired);

  $Output = `$SNMPSet $Host $CiscoSwitchMibs{TFTPHost} octetstring $TFTPServer`;  
  if ($Output !~ /$TFTPServer/i)
  { return(1); }
  $Output = `$SNMPSet $Host $CiscoSwitchMibs{TFTPFile} octetstring $File`;
  if ($Output !~ /$File/i)
  { return(1); }
  $Output = `$SNMPSet $Host $CiscoSwitchMibs{TFTPModule} integer 1`;
  if ($Output !~ /INTEGER: 1/i)
  { return(1); }
  $Output = `$SNMPSet $Host $CiscoSwitchMibs{TFTPAction} integer 3`;
  if ($Output !~ /uploadConfig/i)
  { return(1); }
  $Output = `$SNMPGet $Host $CiscoSwitchMibs{TFTPResult}`;
  $ImTired = 0;
  while ( ($Output !~/success/i) && ($ImTired<10) )
  {
    sleep(3);
    $Output = `$SNMPGet $Host $CiscoSwitchMibs{TFTPResult}`;
    $ImTired ++;
  }
  if ($Output !~/success/i)
  {
    return(1);
  }
  else
  {
    return(0);
  }
  
}



################################
# Query MAC for LCU Switches
################################
sub LCUSwitchQuery
{
  my (@LCUSwitches);
  MACDB_open_read();
  @LCUSwitches = MACDB_device_info( {PROCESS_ID=>2, RESULT=>'array'} );
  MACDB_close();
  return(\@LCUSwitches);
}


################################
# Query Mind For Egress Routers#
################################
sub EgressRouterQuery
{
  my $dbh;
  my $sql;
  my $q_hostname;
  my $q_ip;
  my $q_model;
  my @Hosts;
  my $count;

  $ENV{'DB2DIR'} = "/opt/IBMdb2/v5.0" unless $ENV{'DB2DIR'};
  $ENV{'DB2INSTANCE'} = "db2admn" unless $ENV{'DB2INSTANCE'};
  $dbh = DBI->connect('DBI:DB2(RaiseError=>1,ChopBlanks=>1):HOPDSN', 'enminq', 'browser');
  die "Cannot Connect to DB2\n" unless $dbh;

  $sql = "select G.MACH_NAME, K.IP_ADDR, H.MODEL ";
  $sql .= "from RU99.GA062 as G join RU99.GA065 as K ";
  $sql .= "on G.MACH_ID = K.MACH_ID ";
  $sql .= "join RU99.GA044 as D ";
  $sql .= "on G.MACH_ID = D.MACH_1_ID ";
  $sql .= "join RU99.GA062 as H ";
  $sql .= "on D.MACH_2_ID = H.MACH_ID ";
  $sql .= "where D.DATA_TYPE = 41 ";
  $sql .= "and K.FUNC_LKUP_CTGRY = 1 ";
  $sql .= "and K.FUNC = 0 ";
  $sql .= "and D.DATA_TYPE_CTGRY = 9";
eval {
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    $sth->bind_columns(\$q_hostname, \$q_ip, \$q_model);
    while ( $sth->fetch() )
    {
      $q_hostname =~ s/\s+$//;
      next if length($q_hostname) < 7;
      $q_ip =~ s/\s+$//;
      $q_model =~ s/\s+$//;
      push @Hosts, $q_hostname;
    }
  $sth->finish;
 };
  die "$@" if $@;
  $dbh->disconnect;
  return (\@Hosts);
}

####################################
# Load Array from Host file        #
####################################
sub LoadFile
{
  my $Path = shift;
  my (@Hosts);

  open HOSTS, "$Path";
  @Hosts = <HOSTS>;
  chomp( @Hosts );
  return (\@Hosts);
}

####################################
# View Config                      #
####################################
sub ViewConfigNormalMode
{
  my ($Host, $Version) = @_;
  my ($Oid, @Config);

  $Oid = Oid($Host);
      if ($Oid != 1)
      {
        $Host = uc ( $Host );
	if ($Version eq "Old")
	{
	  $Structure = "$Structure\SecondCopy/";
        }

        open CONFIG, "$Structure$Host.$Oid";
        
        my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat("$Structure$Host.$Oid");
        my ($sec,$min,$hr,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($mtime);
        push @Config, "File Created on $mon/$mday/$year \@ $hr:$min:$sec Size: $size\n\n";
        
        map{push @Config, $_;}<CONFIG>;
      }
      else
      {
        push @Config,"$Host is Unreachable by SNMP, Please Contact Automation.\n";
      }
  return(\@Config); 
}

#####################################
# View Config Diff Mode             #
#####################################
sub ViewConfigDiffMode
{
  my ($Host) = shift;
  my (@HTML, @IndexNBK, @IndexRun, $Oid,$Answer, $LineNumber, %NBKConfig, %RunningConfig, @NBKConfigHTML, @RunningConfigHTML, $LoopSize);
  $Host = uc ( $Host ); 
  $Oid = Oid($Host);
  if ($Oid =~ /cisco/i) #Im a router
  {
    Touch("$Host\.$Oid");
    $Answer = CiscoRouter($Host, "$Host\.$Oid");
  }
  else #Im a switch
  {
    Touch("$Host\.$Oid");
    $Answer = CiscoSwitch($Host, "$Host\.$Oid");
  }
  if (($Answer == 0) && ($Oid !=1))
  {
    open NBKCONFIG, "$Structure$Host\.$Oid" or die "cannot open nbk"; #open archived config from filesystem
    open TFTPCONFIG, "$TFTPDir$Host\.$Oid" or die "cannot open tftp"; #open config from tftp
    @IndexNBK = <NBKCONFIG>;
    @IndexRun = <TFTPCONFIG>;
    
    map{$NBKConfig{$_} = 1;}@IndexNBK; #load nbk hash
    map{$RunningConfig{$_} = 1;}@IndexRun; #load running hash
    

    unlink("$TFTPDir$Host\.$Oid"); #delete config from tftp (not needed anymore)
    
    push @HTML, "<TABLE BORDER=1>
                <TR>
                <TD><FONT FACE=ARIAL><B>Running Configuration</B></FONT></TD>
                <TD><FONT FACE=ARIAL><B>Archived Configuration</B></FONT></TD>
                </TR>";
    map{
         if (defined $RunningConfig{$_}) #is the line in both configs?
          {
            #push @NBKConfigHTML,"<TD><FONT FACE=ARIAL COLOR=BLACK>$_</TD>";
	    $NBKConfig{$_} = "<TD><FONT FACE=ARIAL COLOR=BLACK>$_</TD>";
          }
          else
          {
            #push @NBKConfigHTML,"<TD><FONT FACE=ARIAL COLOR=RED>$_</TD>";
	    $NBKConfig{$_} = "<TD><FONT FACE=ARIAL COLOR=RED>$_</TD>";
          }
       }keys %NBKConfig;
    
    map{
         if (defined $NBKConfig{$_})
         {
            #push @RunningConfigHTML,"<TD><FONT FACE=ARIAL COLOR=BLACK>$_</TD>";
	    $RunningConfig{$_} = "<TD><FONT FACE=ARIAL COLOR=BLACK>$_</TD>";
         }
         else
         {
            #push @RunningConfigHTML,"<TD><FONT FACE=ARIAL COLOR=RED>$_</TD>";
	    $RunningConfig{$_} = "<TD><FONT FACE=ARIAL COLOR=BLACK>$_</TD>";
         }
       }keys %RunningConfig;
 
   #
   # Which Array is Largest
   # 
    $LineNumber = 0;
    if ( $#RunningConfigHTML > $#NBKConfigHTML)
    {
      $LoopSize = $#IndexRun;
    }
    elsif($#RunningConfigHTML == $#NBKConfigHTML)
    {
      $LoopSize = $#IndexRun;
    }
    else
    {
      $LoopSize = $#IndexNBK;
    }
     
    while ($LineNumber <= $LoopSize)
    {
      
      push @HTML,"<TR>$RunningConfig{$IndexRun[$LineNumber]}$NBKConfig{$IndexNBK[$LineNumber]}</TR>"; 
      $LineNumber ++;
    }
  }
  else
  {
     push @HTML, "<H1>$Host is unreachable via SNMP, Contact the Automation Team.\n";
  }
  push @HTML, "</TABLE>";
  return(\@HTML); 
} 
