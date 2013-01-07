    #   F u n c . p l
    #   -------------
    #   The Win32::ODBC API Function lister script.  This will list
    #   most of the practical ODBC API function support for a
    #   particular ODBC Driver.
    #   Syntax:
    #       perl Func.pl "My DSN"
    #
    #   By Dave Roth (c) 1997 by Dave Roth <rothd@roth.net>
    #   Courtesy of Roth Consulting (http://www.roth.net)
    #   Last Modified: 970701

    use Win32::ODBC;

    $Credit = "\t\t(c) 1997 by Dave Roth <rothd\@roth.net>\n\t\tCourtesy of Roth Consulting\n\t\thttp://www.roth.net/";

    if (! ($DSN = $ARGV[0])){
        print "Incorrect Syntax: You did not specify a DSN name.\n";
        Syntax();
        exit;
    }

    print "Connecting to \"$DSN\"\n";

    if ( $O = new Win32::ODBC($DSN)){
        Init();
        $~ = "Header";
        write;
        $~ = "Function";
        foreach $Temp (sort(keys(%Functions))){
            $iCount++;
            PrintSupport($Temp);
        }
        $O->Close();
    }else{
        print "Could not connect to \"$DSN\".\n";
        print "Error: " . Win32::ODBC::Error() . "\n";
    }


sub PrintSupport{
    local($Function) = @_;
    local($Result);

    $Result = ($O->GetFunctions($Functions{$Function}))[0];
    write;

}

format Header=
       Function                Supported   Not Supported
       ----------------------- ---------   -------------
.

format Function=
@>>>)  @<<<<<<<<<<<<<<<<<<<<<< @||||||||   @||||||||||||
$iCount, $Function, ($Result)? "X":"", ($Result)? "":"X"
.


sub Init{

    %Functions = (
        'BindColumn()'      =>  ODBC::SQL_API_SQLBINDCOL(),
        'BindParameter()'   =>  ODBC::SQL_API_SQLBINDPARAMETER(),
        'BrowseConnect()'   =>  ODBC::SQL_API_SQLBROWSECONNECT(),
        'Cancel()'          =>  ODBC::SQL_API_SQLCANCEL(),
        'ColAttributes()'   =>  ODBC::SQL_API_SQLCOLATTRIBUTES(),
        'ColumnPrivileges()'=>  ODBC::SQL_API_SQLCOLUMNPRIVILEGES(),
        'Columnns()'        =>  ODBC::SQL_API_SQLCOLUMNS(),
        'Connect()'         =>  ODBC::SQL_API_SQLCONNECT(),
        'DataSources()'     =>  ODBC::SQL_API_SQLDATASOURCES(),
        'DescribeCol()'     =>  ODBC::SQL_API_SQLDESCRIBECOL(),
        'DescribeParam()'   =>  ODBC::SQL_API_SQLDESCRIBEPARAM(),
        'Disconnect()'      =>  ODBC::SQL_API_SQLDISCONNECT(),
        'DriverConnect()'   =>  ODBC::SQL_API_SQLDRIVERCONNECT(),
        'Drivers()'         =>  ODBC::SQL_API_SQLDRIVERS(),
        'Error()'           =>  ODBC::SQL_API_SQLERROR(),
        'ExecDirect()'      =>  ODBC::SQL_API_SQLEXECDIRECT(),
        'Execute()'         =>  ODBC::SQL_API_SQLEXECUTE(),
        'ExtendedFetch()'   =>  ODBC::SQL_API_SQLEXTENDEDFETCH(),
        'Fetch()'           =>  ODBC::SQL_API_SQLFETCH(),
        'ForeignKeys()'     =>  ODBC::SQL_API_SQLFOREIGNKEYS(),
        'FreeConnect()'     =>  ODBC::SQL_API_SQLFREECONNECT(),
        'FreeEnv()'         =>  ODBC::SQL_API_SQLFREEENV(),
        'FreeStmt()'        =>  ODBC::SQL_API_SQLFREESTMT(),
        'GetConnectOption()'=>  ODBC::SQL_API_SQLGETCONNECTOPTION(),
        'GetCursorName()'   =>  ODBC::SQL_API_SQLGETCURSORNAME(),
        'GetData()'         =>  ODBC::SQL_API_SQLGETDATA(),
        'GetFuncions()'     =>  ODBC::SQL_API_SQLGETFUNCTIONS(),
        'GetInfo()'         =>  ODBC::SQL_API_SQLGETINFO(),
        'GetStmtOption()'   =>  ODBC::SQL_API_SQLGETSTMTOPTION(),
        'GetTypeInfo()'     =>  ODBC::SQL_API_SQLGETTYPEINFO(),
        'MoreResults()'     =>  ODBC::SQL_API_SQLMORERESULTS(),
        'NativeSQL()'       =>  ODBC::SQL_API_SQLNATIVESQL(),
        'NumParams()'       =>  ODBC::SQL_API_SQLNUMPARAMS(),
        'NumResultCols()'   =>  ODBC::SQL_API_SQLNUMRESULTCOLS(),
        'ParamData()'       =>  ODBC::SQL_API_SQLPARAMDATA(),
        'ParamOptions()'    =>  ODBC::SQL_API_SQLPARAMOPTIONS(),
        'Prepare()'         =>  ODBC::SQL_API_SQLPREPARE(),
        'PrimaryKeys()'     =>  ODBC::SQL_API_SQLPRIMARYKEYS(),
        'ProcedureColumns()'=>  ODBC::SQL_API_SQLPROCEDURECOLUMNS(),
        'Procedures()'      =>  ODBC::SQL_API_SQLPROCEDURES(),
        'PutData()'         =>  ODBC::SQL_API_SQLPUTDATA(),
        'RowCount()'        =>  ODBC::SQL_API_SQLROWCOUNT(),
        'SetConnectOption()'=>  ODBC::SQL_API_SQLSETCONNECTOPTION(),
        'SetCursorName()'   =>  ODBC::SQL_API_SQLSETCURSORNAME(),
        'SetParam()'        =>  ODBC::SQL_API_SQLSETPARAM(),
        'SetPos()'          =>  ODBC::SQL_API_SQLSETPOS(),
        'SetScrollOptions()'=>  ODBC::SQL_API_SQLSETSCROLLOPTIONS(),
        'SetStmtOption()'   =>  ODBC::SQL_API_SQLSETSTMTOPTION(),
        'SpecialColumns()'  =>  ODBC::SQL_API_SQLSPECIALCOLUMNS(),
        'Statistics()'      =>  ODBC::SQL_API_SQLSTATISTICS(),
        'TablePrivileges()' =>  ODBC::SQL_API_SQLTABLEPRIVILEGES(),
        'Tables()'          =>  ODBC::SQL_API_SQLTABLES(),
        'Transact()'        =>  ODBC::SQL_API_SQLTRANSACT(),

    );

    $Line = "-" x length($0);
    ($Temp, $Driver) = $O->DataSources($DSN);
    %Drivers = Win32::ODBC::Drivers();
    $Attribs = "\n\t\t" . join("\n\t\t", split(";", $Drivers{$Driver}));
    @Info = Win32::ODBC::Info();
    $ExtVersion = "$Info[1] $Info[2] ($Info[4] $Info[5])";

    print<<EOT;
    $0
    $Line
    The purpose of this script is to print what ODBC functions a particular
    ODBC driver supports.  This is not an exhaustive list of functions nor does
    it represent the limits and/or capabilites of the Win32::ODBC extension.
    This is used strictly for debugging purposes.

$Credit
    ---------------------------------------------

    Win32::ODBC Version:
        Extension: $ExtVersion
        Module:    $ODBCPackage::Version

    Examining the ODBC Driver: \n\t\t$Driver
        ---------------------
        Attributes: $Attribs

EOT

}

sub Syntax{

    $Line = "-" x length($0);

    print<<EOSyntax;

$0
$Line
    The Win32::ODBC API Function lister script.  This will list
    most of the practical ODBC API function support for a
    particular ODBC Driver.

    Syntax:
        perl $0 "My DSN"

    Available DSN's:
EOSyntax

    if (%DSNs = Win32::ODBC::DataSources()){
        foreach $Temp (keys(%DSNs)){
            if (($Temp eq $TempDSN) && ($DSNs{$Temp} eq $DriverType)){
                $iTempDSNExists++;
            }
            if ($DSN =~ /$Temp/i){
                $iTempDSN = 0;
                $DriverType = $DSNs{$Temp};
            }
            print "\tDSN=\"$Temp\" (\"$DSNs{$Temp}\")\n";
        }
    }
    print "\n$Credit";

}
