#
# Detect.pl Ver 1.01								 
# Last Modified: 3/26/2000                                         
# James Oryszczyn  jamesory@megsinet.net					 					
# 											 	
# Distributed under the terms of this General Public License       
# http://www.gnu.org/copyleft/gpl.html					 
#											 
# This perl script is designed to log and alert to FW1 user        	
# defined alerts.								     	 	
#											 
# Requires the perl module sender.pm					 	
#											 	
#################################################################
#               BEGIN CUSTOMIZING SCRIPT HERE                   #
################################################################# 

# Path and name of the Unqinue Alert file, This file keeps a log file of the people scanning you, but it will one
# have the IP address in it once.
$file = 'd:\logs\Alert.one';

#The address of the firewall sending the alert.
$FromAddress = 'Gatekeeper';

#The address to send the alert to 
$ToAddress = 'Your email address';
 
# Path and name of the Alert log file
$Alert  = 'd:\logs\Alert.log';

# This function blocks the source IP scanning/probing our network. 
# For more info type fw sam.

$block = 'c:\winnt\fw\bin\fw sam -t 3600 -i src ';	

# The Maxium Number of email Alerts, change to the number you want. 
$limit = 5;

#################################################################
#               FINISH CUSTOMIZING SCRIPT HERE                  #
################################################################# 

# Get the data from Standard input
 $line=<STDIN>;

# Spilt the alert into fields
eval {
($date, $time, $action, $Log, $Interface, $type, $proto1, $protocol, $src, $source, $dst,
 $destination, $srv, $service) =
   split (/[ ]+/, $line,16);

};



# Add to the Logfile   

open alertlog, ">>$Alert";  
print alertlog  "$source, $destination, $protocol, $service, $date, $time\n"; 
close alertlog;



# Subroutines

# Check to see if this Ip address has scanned us before. If not put it int the alert.one log.

open alertone, "<$file";

#Reorder the log file and take out the spaces and put it in an array.

 while (@alert1 = <alertone>){
chomp @alert1;

#Check to see if an entry for the source ip address exists

$times = grep {/$source/} @alert1;


close alertone;

open alert, ">>$file";

#If the number of times scanned is 0 then write it to the log file

 if ($times eq "0") {
 print alert "$source, $destination, $protocol, $service, $date, $time\n"; 
 close alert;

}

#Reorder the log file and take out the spaces and put it in an array.


  open file2, "<$Alert";

 while (@attack = <file2>){
chomp @attack;


#Match the number of times the source address has scanned the firewall

$number = grep {/$source/} @attack;






close file2;

 
 
 }
# If the scan is less then the defined limit, the script will email the Admin, otherwise it will exit
# make sure you put your mailserver address in the Mail server section
if ($number <=$limit) {

use Mail::Sender;
     ref ($sender = new Mail::Sender({from => "$FromAddress",smtp
 => 'Your Mail server'})) or die "$Mail::Sender::Error\n";

(ref ($sender->MailMsg({to =>"$ToAddress", subject => 'Gatekeeper', 
		msg => "You have received this message because someone is potentially scanning your systems.\n 
The information below is the packet that was denied and logged by the Firewall. 
This is email alert number $number, with a limit of 5 from $source\n. 
----- CRITICAL INFORMATION ----- 
Date: $date\n
Time: $time \n
Source: $source\n
Destination: $destination \n
Service: $service\n

-------ACTURAL FW-1 LOG ENTRY------
$line \n
"})) )
and print "Mail sent OK." 

}


}  
# When the scan equals the limit, than block the source address or else exit. If you don't
#want to block the address then comment this section out.

if ($number eq $limit) {

system "$block $source\n";
}




 
