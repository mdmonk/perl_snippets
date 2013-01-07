########################################################################
# @result = dnslookup($host, $querytype, @servers);
#
# $hostname is the name (or I.P. address in the case of a PTR request)
#      of the host to be looked up
# $querytype is one of:
#      "A"  (Address)
#      "AXFR" (All record transfer out)
#      "CNAME" (Canonical Name)
#      "MX" (Mail Exchange Record)
#      "NS" (Hardware information)
#      "PTR" (Reverse name lookup)
#      "SOA" (Start of Authority record)
#        default is "A".
# @servers is a list of name servers to be queried
#
# @result list containing the result of the request.
#
#   sucess:  value
#   errors:  -1 invalid query type
#            -2 query failed
########################################################################

sub dnslookup {
 use strict;
 my ($host, $querytype, @servers) = @_;
 my $mydebug = 0;
 my $lookup;
 my $query;
 my $record;
 my @results;
 my @xfer;

 if((!defined($querytype)) || ($querytype eq "")) {$querytype = "A";}

 $querytype = uc($querytype);
 if(($querytype ne "A") &&
  ($querytype ne "AXFR") &&
  ($querytype ne "CNAME") &&
  ($querytype ne "MX") &&
  ($querytype ne "NS") &&
  ($querytype ne "PTR") &&
  ($querytype ne "SOA")) {return -1;}

 use Net::DNS;

 if ($mydebug) { print "creating new Net::DNS:Resolver\n"; }
 if (not($lookup = new Net::DNS::Resolver)) { return(-2); }
 if ($mydebug) { $lookup->print; }

 if (@servers) {
  $lookup->searchlist($lookup->nameservers(@servers));
 }
 if ($mydebug) { $lookup->print; }

 if ($mydebug) { print "searching for \$host=!$host!, \$querytype=!$querytype!\n"; }

 if ($querytype eq "AXFR") {
  if (not(@xfer = $lookup->axfr($host))) { return(-2); }
  foreach $record (@xfer) {
    push(@results, $record->string);
  }
  return(@results);
 }
 if (not($query = $lookup->query($host, $querytype))) { return(-2); }
 foreach $record ($query->answer) {
   if (($record->type eq "A") && ($querytype eq "A" )) { push(@results, $record->address); }
   if (($record->type eq "CNAME") && ($querytype eq "CNAME" )) push(@results, $record->cname); }
   if (($record->type eq "MX") && ($querytype eq "MX" )) { push(@results, $record->exchange); }
   if (($record->type eq "NS") && ($querytype eq "NS" )) { push(@results, $record->nsdname); }
   if ($record->type eq "PTR") { push(@results, $record->ptrdname); }
   if (($record->type eq "SOA") && ($querytype eq "SOA" )) push(@results, $record->string); }
 }
 return(@results);
}
