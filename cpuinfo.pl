use Win32::CpuInfo;

my $obj= new Win32::CpuInfo;

$obj->GetCpuInfo(\$CpuInfo);
print "\n";
foreach $keys (sort keys %$CpuInfo)
{print $CpuInfo->{$keys}->{Description}.": ";
 print $CpuInfo->{$keys}->{Value}."\n";}

print "\n";
$obj->GetCpuFeatures(\$CpuFeatures);

foreach $keys (sort keys %$CpuFeatures)
{print $CpuFeatures->{$keys}->{Description}.": ";
 print $CpuFeatures->{$keys}->{Value}."\n";}

print "\nCPU speed is: ".$obj->GetCpuSpeed."MHz\n";
