#excel_ole.pl

use OLE;

#  -4100 is the value for the Excel constant xl3DColumn.

$ChartTypeVal = -4100;

# Creates OLE object to Excel
$ExcelApp = CreateObject OLE "excel.application" || die "Unable to create Excel Object: $!\n";

# Create and rotate the chart

$ExcelApp->{'Visible'} = 1;
$ExcelApp->Workbooks->Add();
$ExcelApp->Range("a1")->{'Value'} = 3;
$ExcelApp->Range("a2")->{'Value'} = 2;
$ExcelApp->Range("a3")->{'Value'} = 1;
$ExcelApp->Range("a1:a3")->Select();
$ExcelChart = $ExcelApp->Charts->Add();
$ExcelChart->{'Type'} = $ChartTypeVal;

for ($j=1;$j<3;$j++) {
  for ($i=30;$i<180;$i+=10) {
    $ExcelChart->{'Rotation'} = $i;
  }
}
for (;$i>0;$i-=10) {
  $ExcelChart->{'Rotation'} = $i;
}
