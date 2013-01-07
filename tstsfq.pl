use SF::SFQ;
# use SFQ;

my %sfqhash = (
   debug => 1,
   rule => "RS_AddCall",
   customercall => 'hc65',
   priority => 'Low',
   categorycall => 'SERVER',
   callstatus => 'New',
   wgcall => 'CORP-CC-COMCEN NETWORK AUTOMATION@C',
   problem => 'This really is just a test. Ignore me.',
   LT_problemtext => 'This is supposed to go in the long text field'
   );

my %tsthash = (
   debug => 1,
   rule => "RS_AddCall",
   customercall => 'hc65',
   priority => 'Low',
   categorycall => 'SERVER',
   callstatus => 'New',
   wgcall => 'CORP-CC-COMCEN NETWORK AUTOMATION@C',
   problem => 'This is a test sfq ticket to test updating functionality.',
   );

my %sfqhash2 = (
   customercall => 'hc65',
   server => 'NSBQBKV',
   priority => 'Low',
   categorycall => 'SERVER',
   callstatus => 'New',
   wgcall => 'CORP-CC-COMCEN NETWORK AUTOMATION@C',
   crepcall => 'hc65',
   srepwgcall => 'CORP-CC-COMCEN NETWORK AUTOMATION@C',
   srepcall => 'hc65',
   problem => 'This is from the SFQ Ticket Generation module',
   problemtext => 'Test Text --- Just to clarify I am running on Win98 with Apache and ActivePerl, but I have configured the http.conf all the different ways that I have found on the net (starting new each time as to prevent confusion). And yet it still does not work. I know for a fact that .pl does work with PWS but wont for some strange reason in Apache. Even with the line configured to point to the perl.exe... If possible could i see all the the lines you added to get your cgi scripts to work? I know you dont want to give the direct http.conf since that would give sensitive information about your system, but what all did you add to make it work..'
   ); 

my %statushash = (
   debug => 0,
   rule => 'CallStatus',
   sfqnum => '6712771',
   # sfqnum => '7095864',
   user => 'hc65',
);

my $sfq = initiateSFQ(%tsthash);
# my $sfq = initiateSFQ(%statushash);

if($statushash{sfqnum}) {
  print "Status returned for Sfq\# $statushash{sfqnum} is: $sfq\n";
} else {
  print "Returned from the SF::SFQ module is: $sfq\n";
}
################################################
# LT_ is the key for the Long Text field value.
# Currently this does not work. Will be fixed in
# later releases of this module.
# A sample of a long text line is below. 
#  - Chuck L.
################################################
# LT_ => 'This is just supposed to be a really long text field. I hope it works. Darn I sure have spent a lot of time on this module. It does rock though! The Network Automation Team is darn cool!'
################################################
