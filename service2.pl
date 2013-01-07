use Win32::Service;

Win32::Service::GetServices('', \%list) || die $!;
print "Display Name = Service Name\n";
foreach $key (keys %list)
{
    print $key, '=', $list{$key}, "\n";
}

print "\n\n";

Win32::Service::GetStatus('', 'Messenger', \%status) || die $!;
foreach $key (keys %status)
{
    print $key, '=', $status{$key}, "\n";
}

