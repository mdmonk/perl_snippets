###################################################
# ChkSvc.pl
#
# Checks running services. Will be used primarily
#   for checking up on the RuleServer.
#
# DOES NOT WORK YET!!!
# 
# Programmer: Chuck Little
# Date:       12 Nov 1998
###################################################

use Win32::Service;
$host = $ARGV[0];
print "Hostname is: $host\n";
sleep(2);

  Win32::Service::GetServices($host,\%services) || die "$!";
  foreach $key (sort keys %services) {
#    print "Service is: $key\n";
    undef %status;
    Win32::Service::GetStatus($host,$services{$key},\%status);
    if ($status{'CurrentState'} == 4) {
       $stat = "Started";
    }
    if ($status{'CurrentState'} == 3) {
       $stat = "Starting";
    }
    if ($status{'CurrentState'} == 2) {
       $stat = "Stopping";
    }
    if ($status{'CurrentState'} == 1) {
       $stat = "Stopped";
    }

    print "Service is: $key \n    Status is: $stat\n";
    undef $stat;

#    if($status{'CurrentState'} eq 4) {
#      $started{$key}=$key."%%%".$services{$key};
#    } else {
#      $stopped{$key}=$key."%%%".$services{$key};
#    }
  }

#sub caseinsensitive { uc($a) cmp uc($b); }
#
#sub startService {
#  local($info1,$info2)=@_;
#  local($name,$service)=split(/%%%/,$info1,2);
#  $service=$info2 if $service eq undef;
# print "Starting the <B>$name</B> service...\n";
# Win32::Service::StartService("",$service);
# &printOpInfo($name,"starting");
#}

#sub stopService {
#  local($info1,$info2)=@_;
#  local($name,$service)=split(/%%%/,$info1,2);
#  $service=$info2 if $service eq undef;
#  print "Stopping the <B>$name</B> service...\n";
#  Win32::Service::StopService("",$service);
#  $error=Win32::GetLastError();
#  &printOpInfo($name,"stopping");
#}

#sub printOpInfo {
#  local($op)=@_;
#  local $error=Win32::GetLastError();
#  if($error ne 0) {
#    local $message=Win32::FormatMessage($error);
#    $message=~s/[\r\n]/ /g;
#    print "<SCRIPT> alert(\"Error $error $op $name: $message\"); </SCRIPT>\n";
#    print "<B>ERROR</B><BR>\n";
#    print "(<B>$error</B>) <B>$message</B><BR>\n";
#  } else {
#    print "<B>OK</B><BR>\n";
#  }
#} 
