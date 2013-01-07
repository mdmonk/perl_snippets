use Win32::Service;
# use Win32::Registry;

Win32::Service::GetServices ($ARGV[0],\%svclist );

  foreach $key (sort keys %svclist) {
    print "Service is: $service\n";
    undef %status;
    Win32::Service::GetStatus($hostname,${$service},\%status);
    print "Current Status: $status{'CurrentState'}\n";
    if($status{'CurrentState'} eq 4) {
      $started{$service}=$key."%%%".$services{$service};
      print "$service is started.\n";
    } else {
      $stopped{$service}=$key."%%%".$services{$service};
      print "$service is stopped.\n";
    }
  }

# Anyway, the array returned by GetStatus doesn't contain (apparently)
# useful informations. If you want to get for example the startup type
# for a service (auto, manual, disabled) you have to open the registry
# key:
#
#HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\(servicename)
#
#and then read the "Start" value, that equals to:
#0x2 == Automatic
#0x3 == Manual
#0x4 == Disabled


