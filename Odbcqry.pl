#!perl.exe
#!/usr/bin/perl
# ODBC query - requires PERL 5.003_7 or higher and Win32::ODBC
# Author Alan Johnston

use CGI qw/:standard :html3 :netscape/;
use Win32::ODBC;

# Unpack parameters from form

$cmd=param('cmd');		#Command to processs
$DSN=param('DSN');		#Selected DSN
$table=param('table');		#Selected table from DSN
@cols=param('cols');		#Selected columns from table
$sort=param('sort');		#Column to sort on
$rows=param('rows');		#Max number of rows

# Off we go...
# If no command or DSN then get user to select one.

if ($cmd eq '' || $DSN eq ''){
  %DSN=Win32::ODBC::DataSources;	#Get list of datasources
  @keys=sort(keys(%DSN));		#put list of DSNs into array
  &screen_header;			#Start HTML response
  print start_form,
    hidden(-name=>'cmd',-value=>'table',-force=>1),
    table(
      Tr([
        td(['Data Source: ',
           popup_menu(-name=>'DSN',-value=>\@keys)."&nbsp&nbsp&nbsp".submit(-name=>'GO')])
      ])
    ),
  end_form,end_html;
  exit(0);
}

# If no table selected then get table name

if ($cmd eq 'table' || $table eq ''){
  $db=new Win32::ODBC($DSN);			#create new instance
  if (! $db){
    perror("Error opening data source $DSN");
    exit(0);
  }
  @tables=$db->TableList("","","","TABLE");	#Get list of tables
  $db->Close();					#Close ODBC connection
  &screen_header;
  print start_form,
    hidden(-name=>'cmd',-value=>'cols',-force=>1),
    hidden(-name=>'DSN',-value=>"$DSN"),
    table(
      Tr(td(['Data Source: ',$DSN])),
      Tr(td(['Table: ',
            popup_menu(-name=>'table',-value=>\@tables)."&nbsp&nbsp&nbsp".submit(-name=>'GO')])
      )
    ),
  end_form,end_html;
  exit(0);
}

# If no columns selected then get cols required

if ($cmd eq 'cols' || $cols[0] eq ''){
  $db=new Win32::ODBC($DSN);		#start mew instance
  if (! $db){
    perror("Error opening data source $DSN");
    exit(0);
  }

#Get column metadata by issuing a query which returns no rows

  $rc=$db->Sql("SELECT * FROM $table WHERE 1=0");	
  if ($rc){
    perror("Error $rc getting columns from table $table");
    exit(0);
  }
  @cols=sort($db->FieldNames());	#Pick up column names
  $db->Close();				#Close connection
  &screen_header;
  print start_form,
    hidden(-name=>'cmd',-value=>'sort',-force=>1),
    hidden(-name=>'DSN',-value=>"$DSN"),
    hidden(-name=>'table',-value=>"$table"),
    table(
      Tr(td(['Data Source: ',$DSN])),
      Tr(td(['Table: ',$table])),
      Tr({-valign=>'top'},
        td(['Columns: ',
             scrolling_list(-name=>'cols',-value=>\@cols,-multiple=>1,-size=>10).
             "&nbsp&nbsp&nbsp".submit(-name=>'GO')])
      )
    ),
    p('Use SHIFT and CTRL keys with mouse to select multiple columns'),
  end_form,end_html;
  exit(0);
}

# If no sort column selected then get sort col and max rows

if ($cmd eq 'sort' || $sort eq ''){
  @keys=("<none>",@cols);		#Construct picklist contents
  $COLS=join(', ',@cols);		#Construct string of columns
  &screen_header;
  print start_form,
    hidden(-name=>'cmd',-value=>'data',-force=>1),
    hidden(-name=>'DSN',-value=>"$DSN"),
    hidden(-name=>'table',-value=>"$table"),
    hidden(-name=>'cols',-value=>@cols),
    table(
      Tr(td(['Data Source: ',$DSN])),
      Tr(td(['Table: ',$table])),
      Tr(td({-valign=>top},['Columns: ',$COLS])),
      Tr(td(['Sort by: ',
             popup_menu(-name=>'sort',-value=>\@keys,-default=>'<none>')])),
      Tr(td(['Maximum no. of<br>rows to display: ',
             textfield(-name=>'rows',-value=>'100',-size=>5)."&nbsp&nbsp&nbsp".submit(-name=>'GO')])
      )
    ),
  end_form,end_html;
  exit(0);
}

# fetch and display data, ensure user has requested some rows

if ($cmd eq 'data'){
  if ($cols[0] eq '' || $rows==0){
    perror("Error: No columns selected or max rows is zero");
    exit(0);
  }
  $db=new Win32::ODBC($DSN);			#New instance
  if (! $db){
    perror("Error opening data source $DSN");
    exit(0);
  }
  $db->SetStmtOption($db->SQL_CURSOR_DYNAMIC);	#try and use ODBC driver options
  $db->SetStmtOption($db->SQL_MAX_ROWS,$rows);	#to limit row retrieval (may not work).
  $COLS=join(', ',@cols);
  $SQL="SELECT $COLS FROM $table";		#build SQL query
  $SQL=$SQL." order by $sort" if ($sort ne '<none>');
  $rc=$db->Sql($SQL);				#execute SQL query
  if ($rc){
    $db->Close();
    perror("Error $rc getting $COLS","from table $table");
    exit(0);
  }
  %coltype=$db->ColAttributes(SQL_COLUMN_TYPE_NAME);		#pickup column metadata
  %colprecision=$db->ColAttributes(SQL_COLUMN_PRECISION);	#so we can format the
  %colscale=$db->ColAttributes(SQL_COLUMN_SCALE);		#displayed output
  &screen_header;
  print '<table border=1>',caption("$DSN, $table"),Tr(th(\@cols));

#keep a count of the rows retrieved in case settings of MAXROWS failed

  $count=0;
  while ($db->FetchRow() && $count++<$rows){			#While rows to process
    @data=$db->Data();						#fetch row of data
    print '<tr>';						#and print in a table row
    for ($i=0;$i<=$#data;$i++){
      if ("$coltype{$cols[$i]}" eq 'N'){
        print '<td align=right>';
        printf "%$colprecision{$cols[$i]}.$colscale{$cols[$i]}f",$data[$i];
        print '</td>';
      }else{
        print '<td align=left>';
        print "$data[$i]";
        print '</td>';
      }
    }
    print '</tr>';
  }
  $db->Close();					#close connection
  print "</table>",end_html;
  exit(0);
}

##

sub screen_header{
  print header(-name=>'text/html',-expires=>'+5m'),
    start_html(-title=>'ODBC Table Query',-bgcolor=>'fuschia'),
    h1('ODBC Table Query');
}

sub perror{
  &screen_header;
  foreach (@_){
    print "$_<br>";
  }
  print end_html;
}

