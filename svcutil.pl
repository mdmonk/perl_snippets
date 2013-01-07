################################################################
# Program: svcutil.pl
# Programmer: Chuck Little
# Desc: 
#
################################################################
use Win32::Service;

if ($#ARGV == 2) {
  $hostname = $ARGV[1];
  $service = $ARGV[2];
  if ($ARGV[0] eq "-stop") {
#    getServices();
    stopService($hostname, $service);
  }
  if ($ARGV[0] eq "-start") {
#    getServices();
    startService($hostname, $service);
  }
  if ($ARGV[0] eq "-check") {
    checkService($hostname, $service);
  }
  if ($ARGV[0] eq "-list") {
    getServices();
  }
} else {
  print "\nUSAGE: svcutil.pl < -start | -stop | -check | -list> hostname servicename\n";
  exit;
}
# getServices();
1;
##################
# getServices
#  Get services
#  listing.
##################
sub getServices {
#  Win32::Service::GetServices($hostname,\%services) || die "$!";
#  foreach $key (sort keys %services) {
    print "Service is: $service\n";
    undef %status;
    Win32::Service::GetStatus($hostname,$services{$service},\%status);
    print "Current Status: $status{'CurrentState'}\n";
    if($status{'CurrentState'} eq 4) {
      $started{$service}=$key."%%%".$services{$service};
      print "$service is started.\n";
    } else {
      $stopped{$service}=$key."%%%".$services{$service};
      print "$service is stopped.\n";
    }
#  }
} 
##################
# startService
#  Start a service
##################
sub startService {
  ($hostname,$name)=@_;
  print "Starting the $name service on $hostname...\n";
  Win32::Service::StartService($hostname,$name);
}
##################
# stopService
#  Stop a service
##################
sub stopService {
  ($hostname,$name)= @_;
  print "Stopping the $name service on $hostname...\n";
  Win32::Service::StopService($hostname,$name);
  $error=Win32::GetLastError();
}
##################
# checkService
#  check a service
##################
sub checkService {
#  Win32::Service::GetServices($hostname,\%services) || die "$!";
  print "Service is: $service\n";
  undef %status;
#  Win32::Service::GetStatus($hostname,$services{$service},\%status);
  Win32::Service::GetStatus($hostname,$service,\%status);
  print "Current Status: $status{'CurrentState'}\n";
} 
