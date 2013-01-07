#############################################################
# Program Name: netsnd.pl
# 
# Desc: You can send to a list of workstation ID's 
#       or user ID's.
#############################################################

@user=split(/,/,"t003834,t00e741,blnq");
for( $i=0;$i<@user;$i++ ){
	system("net send $user[$i] Please logout of your PC from 12:00PM to 12:20PM.");
}


