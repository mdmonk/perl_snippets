#################################################################
# Description: Running SQL queries & store procedures using ADO #
#################################################################

use Win32::OLE;

$ConnStr = "DSN=DsnName;UID=UserName;PWD=pass;APP=PerlTest;WSID=MyComp;DATABASE=MyDB";

$Conn = Win32::OLE->new('ADODB.Connection');
$Conn->Open($ConnStr);

#-----------------------------------------------------
#Run SQL query	
my $Statement = "select XXX ,YYY from ZZZ where a=b ";
if(! ($RS = $Conn->Execute($Statement)))
{
	print Win32::OLE->LastError() ;
	exit;;
}
while (! $RS->EOF) 
{
	$XXX = $RS->Fields(0)->value;
	$YYY = $RS->Fields(1)->value;
	$RS->MoveNext;
}

#-----------------------------------------------------

#Get record set results from store procedure
$oSP = Win32::OLE->new("ADODB.Command");
$RS = Win32::OLE->new("ADODB.Recordset");
$oSP->{'CommandText'} = "sp_GetData";
$oSP->{'CommandType'} = 4;
$oSP->{'ActiveConnection'} = $Conn;
$oSP->{'CommandTimeout'} = 1200000;
$oSP->{'@Param1'} = $Param1;     
$oSP->{'@Param2'} = $Param2; 

$RS = $oSP->Execute();
while (! $RS->EOF) 
{
	$XXX = $RS->Fields(0)->value;
	$YYY = $RS->Fields(1)->value;
	$RS->MoveNext;
}

#-----------------------------------------------------
#Get return value from store procedure
$oSP = Win32::OLE->new("ADODB.Command");
$oSP->{'CommandText'} = "sp_GetUserID";
$oSP->{'CommandType'} = 4;
$oSP->{'ActiveConnection'} = $Conn;
$oSP->{'@Param1'} = $Param1;     
$oSP->{'@Param2'} = $Param2;                   
$oSP->Execute() ;

$Userid = $oSP->{'RETURN_VALUE'}->value;

#-----------------------------------------------------
#Get returned parameters from store procedure
$oSP = Win32::OLE->new("ADODB.Command");
$oSP->{'CommandText'} = "sp_GetUserID";
$oSP->{'CommandType'} = 4;
$oSP->{'ActiveConnection'} = $Conn;
$oSP->{'@Param1'} = $Param1;     
$oSP->{'@Param2'} = $Param2;                   
$oSP->Execute() ;

$Userid = $oSP->{'@UserId'}->value;
$UserName = $oSP->{'@UserName'}->value;

#-----------------------------------------------------
