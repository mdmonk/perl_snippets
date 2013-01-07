## Microsoft Excel
use Win32::OLE;
use Win32::OLE::const 'Microsoft Excel';

# use existing instance of Excel if it exists
eval {$ExcelApp = Win32::OLE->GetActiveObject('Excel.Application')};
#If there is a system error die
die "Excel not installed" if $@;

$ExcelApp = Win32::OLE->new("Excel.Application", "Quit") or die "Unable to create the Excel object";

$ExcelApp->{'Visible'} = 1;

$ExcelApp->Workbooks->Open("D:\\Data\\My Documents\\Fall1998.xls") or warn("Could'nt open file: $!\n");
