use Win32::OLE;
use Win32::OLE::Variant;
use Time::Local;

$username = $ARGV[0];

#Modify this list to include all of your Domain Controllers (PDC and all BDCs).
@DCs = ('MYPDC', 'MYBDC1', 'MYBDC2');

#Replace MYADSIMCHN with the appropriate machine name
$adsisrv = Win32::OLE->new(['MYADSIMCHN',
    '{233664B0-0367-11cf-abc4-02608c9e7553}']) or die "Unable to get object.\n";
$winnt = $adsisrv->GetObject('Namespace', 'WinNT:');

#Replace MYDOMAIN with the your domain name.
$domain = $winnt->GetObject('Domain', 'MYDOMAIN');

foreach $i (@DCs) {
  $computer = $domain->GetObject('Computer', $i);
  $user = $computer->GetObject('User', $username);
  $temp = $user->{LastLogin};
  $temp and $temp = &datestr2localtime($temp);
  $lastlogin = ($temp > $lastlogin) ? $temp : $lastlogin;
}

print "$username: ".&TimeToTimeStamp($lastlogin)."\n";


sub datestr2localtime {
  my($datestr) = @_;
  my $temp = Win32::OLE::Variant->new(VT_BSTR, $datestr);
  $temp->ChangeType(VT_DATE);
  $temp->ChangeType(VT_R8);
  return timelocal((gmtime(int(($temp - 25569)*86400+0.5)))[0..5]);
}

sub TimeToTimeStamp {
  local($time) = @_;

  local($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);

  return sprintf("%02d/%02d/%04d %02d:%02d:%02d", $mon+1, $mday, $year+1900, $hour, $min, $sec);
}
