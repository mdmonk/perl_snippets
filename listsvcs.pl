use Win32::Service;

$hostname = $ARGV[0];
print "Hostname is: $hostname\n";
#getServices();
listServices();
##################
# getServices
#  Get services
#  listing.
##################
sub getServices {
  Win32::Service::GetServices($hostname,\%services) || die "$!";
  foreach $key (sort keys %services) {
    print "Service is: $key\n";
    print "Value is:  $service->{$key}\n";
    undef %status;
    Win32::Service::GetStatus($hostname,$services{$key},\%status);
    if($status{'CurrentState'} eq 4) {
      $started{$key}=$key."%%%".$services{$key};
    } else {
      $stopped{$key}=$key."%%%".$services{$key};
    }
  }
} 
##################
# listServices
#  list services
##################
sub listServices {
  Win32::Service::GetServices($hostname,\%services) || die "$!";
  foreach $key (sort keys %services) {
    print "Service is: $key\n";
    undef %status;
    Win32::Service::GetStatus($hostname,$services{$key},\%status);
    print "Status is: $status{'CurrentState'}\n";
  }
} 
##################
# startService
#  Start a service
##################
sub startService {
  ($hostname,$service)=@_;
  print "Starting the $name service...\n";
  Win32::Service::StartService($hostname,$service);
}
##################
# stopService
#  Stop a service
##################
sub stopService {
  ($hostname,$service)=@_;
  print "Stopping the $name service...\n";
  Win32::Service::StopService($hostname,$service);
  $error=Win32::GetLastError();
}
