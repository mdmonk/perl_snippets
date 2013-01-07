use Win32::ODBC;

$DSN = "Test" unless $DSN = $ARGV[0];

$db = new Win32::ODBC( $DSN ) 
    || die "Error: Could not connect to \"$DSN\".\n" . Win32::ODBC::Error() . "\n";

@Types = qw(
            BIGINT
            BINARY
            BIT
            CHAR
            DATE
            DECIMAL
            DOUBLE
            FLOAT
            INTEGER
            LONGVARBINARY
            LONGVARCHAR
            NUMERIC
            REAL
            SMALLINT
            TIME
            TIMESTAMP
            TINYINT
            VARBINARY
            VARCHAR
);

%Attributes = (
                "Position" => {
                    Desc => "Postioned operations",
                    Value   =>  'SQL_POS_OPERATIONS',
                    Function =>  GetInfo,
                    Position => 'SQL_POS_POSITION',
                    Refresh =>  'SQL_POS_REFRESH',
                    Update  =>  'SQL_POS_UPDATE',
                    Delete  =>  'SQL_POS_DELETE',
                    Add     =>  'SQL_POS_ADD'
                    },
                "Position Statements" => {
                    Desc    =>  "Positioned Statements",
                    Value   =>  'SQL_POSITIONED_STATEMENTS',
                    Function =>  GetInfo,
                    Delete  =>  'SQL_PS_POSITIONED_DELETE',
                    Update  =>  'SQL_PS_POSITIONED_UPDATE',
                    "Select Update" => 'SQL_PS_SELECT_FOR_UPDATE'
                    },
                "Row Updates"       =>  {
                    Desc    =>  "Can detect changes made by other users",
                    Value   =>  'SQL_ROW_UPDATES',
                    Function =>  GetInfo
                    },
                "Server Name"       =>  {
                    Desc    =>  "Name of database server",
                    Value   =>  'SQL_SERVER_NAME',
                    Function =>  GetInfo
                    },
                "Special Characters"=>  {
                    Desc    =>  "Non letter chars that can be used legally",
                    Value   =>  'SQL_SPECIAL_CHARACTERS',
                    Function =>  GetInfo
                    },
                "Driver Name"   =>  {
                    Desc    =>  "ODBC Driver Name",
                    Value   =>  'SQL_DRIVER_NAME',
                    Function =>  GetInfo
                    },
                "Driver Version"    =>  {
                    Desc    =>  "ODBC Driver Version",
                    Value   =>  'SQL_DRIVER_VER',
                    Function =>  GetInfo
                    },
                "Driver ODBC Version"   =>  {
                    Desc    =>  "ODBC Version this driver supports",
                    Value   =>  'SQL_DRIVER_ODBC_VER',
                    Function =>  GetInfo
                    },
                "Order by expression"   =>  {
                    Desc    =>  "Can this driver expressions in the ORDER BY list",
                    Value   =>  'SQL_EXPRESSIONS_IN_ORDERBY',
                    Function =>  GetInfo
                    },
                "Maximum active statements" =>  {
                    Desc    =>  "Max number of active statements connection (0 if no limit)",
                    Value   =>  'SQL_ACTIVE_STATEMENTS',
                    Function =>  GetInfo
                    },
                "DSN"           =>  {
                    Desc    =>  "Data Source Name",
                    Value   =>  'SQL_DATA_SOURCE_NAME',
                    Function =>  GetInfo
                    },
                "DSN Read Only" =>  {
                    Desc    =>  "Is this DSN read only?",
                    Value   =>  'SQL_DATA_SOURCE_READ_ONLY',
                    Function =>  GetInfo
                    },
                "Database Name" =>  {
                    Desc    =>  "Name of this database",
                    Value   =>  'SQL_DATABASE_NAME',
                    Function =>  GetInfo
                    },
                "Cursor Rollback"   =>  {
                    Desc    =>  "Behavior of a Cursor Rollback",
                    Value   =>  'SQL_CURSOR_ROLLBACK_BEHAVIOR',
                    Function =>  GetInfo,
                    Delete  =>  'SQL_CB_DELETE',
                    Close   =>  'SQL_CB_CLOSE',
                    Preserve=>  'SQL_CB_PRESERVE'
                    },
                "Cursor Commit"     =>  {
                    Desc    =>  "Behavior of a Cursor Commit",
                    Value   =>  'SQL_CURSOR_COMMIT_BEHAVIOR',
                    Function =>  GetInfo,
                    Delete  =>  'SQL_CB_DELETE',
                    Close   =>  'SQL_CB_CLOSE',
                    Preserve=>  'SQL_CB_PRESERVE'
                    },
                "Fetch Direction"   =>  {
                    Desc    =>  "Directions that Fetch Supports",
                    Value   =>  'SQL_FETCH_DIRECTION',
                    Function =>  GetInfo,
                    Next    =>  'SQL_FD_FETCH_NEXT',
                    First   =>  'SQL_FD_FETCH_FIRST',
                    Last    =>  'SQL_FD_FETCH_LAST',
                    Prior   =>  'SQL_FD_FETCH_PRIOR',
                    Absolute=>  'SQL_FD_FETCH_ABSOLUTE',
                    Relative=>  'SQL_FD_FETCH_RELATIVE',
#                        Resume  =>  'SQL_FD_FETCH_RESUME',
                    Bookmark=>  'SQL_FD_FETCH_BOOKMARK'
                    },
                "File Usage"    =>  {
                    Desc    =>  "How driver treats files in a data source (if driver is single tier)",
                    Value   =>  'SQL_FILE_USAGE',
                    Function =>  GetInfo,
                    "Not Supported" =>  'SQL_FILE_NOT_SUPPORTED',
                    Table   =>  'SQL_FILE_TABLE',
                    Qualifier   =>  'SQL_FILE_QUALIFIER'
                    },
                "Case sensitivity"      =>  {
                    Desc    =>  "How case affects SQL identifers",
                    Value   =>  'SQL_IDENTIFIER_CASE',
                    Function =>  GetInfo,
                    Upper   =>  'SQL_IC_UPPER',
                    Lower   =>  'SQL_IC_LOWER',
                    Sensitive   =>  'SQL_IC_SENSITIVE',
                    Mixed   =>  'SQL_IC_MIXED'
                    },
                "Quote Character"   =>  {
                    Desc    =>  "Character string used as starting & ending deliminator for quoting",
                    Value   =>  'SQL_IDENTIFIER_QUOTE_CHAR',
                    Function =>  GetInfo
                    },
                "SQL Reserved Keywords" =>  {
                    Desc    =>  "Keywords reserved for SQL use",
                    Value   =>  'SQL_KEYWORDS',
                    Function =>  GetInfo
                    },
                "Time/Date SQL functions"   =>  {
                    Desc    =>  "SQL Time/Date Functions that are supported by this ODBC driver",
                    Value   =>  'SQL_TIMEDATE_FUNCTIONS',
                    Function =>  GetInfo,
                    "Current Date"  =>  'SQL_FN_TD_CURDATE',
                    "Current Time"  =>  'SQL_FN_TD_CURTIME',
                    "Day Name"  =>  'SQL_FN_TD_DAYNAME',
                    "Day of Month"  =>  'SQL_FN_TD_DAYOFMONTH',
                    "Day of Week"   =>  'SQL_FN_TD_DAYOFWEEK',
                    "Day of Year"   =>  'SQL_FN_TD_DAYOFYEAR',
                    Hour    =>  'SQL_FN_TD_HOUR',
                    Minute  =>  'SQL_FN_TD_MINUTE',
                    Month   =>  'SQL_FN_TD_MONTH',
                    "Month Name"    =>  'SQL_FN_TD_MONTHNAME',
                    Now     =>  'SQL_FN_TD_NOW',
                    Quarter =>  'SQL_FN_TD_QUARTER',
                    Second  =>  'SQL_FN_TD_SECOND',
                    "TimeStamp Add"         =>  'SQL_FN_TD_TIMESTAMPADD',
                    "TimeStamp Difference"  =>  'SQL_FN_TD_TIMESTAMPDIFF',
                    Week    =>  'SQL_FN_TD_WEEK',
                    Year    =>  'SQL_FN_TD_YEAR'
                    },
                "User Name" =>  {
                    Desc    =>  "Userid of current user",
                    Value   =>  'SQL_USER_NAME',
                    Function =>  GetInfo
                    },
                "SQL Union support" =>  {
                    Desc    =>  "Does this ODBC Driver support the UNION clause?",
                    Value   =>  'SQL_UNION',
                    Function =>  GetInfo,
                    "Union Support" =>  'SQL_U_UNION',
                    "Union 'ALL' Keyword Support"   =>  'SQL_U_UNION_ALL'
                    },
                "SQL String Functions"  =>  {
                    Desc    =>  "SQL String Functions that are supported",
                    Value   =>  'SQL_STRING_FUNCTIONS',
                    Function =>  GetInfo,
                    Ascii =>  'SQL_FN_STR_ASCII',
                    Char =>  'SQL_FN_STR_CHAR' ,
                    Concat =>  'SQL_FN_STR_CONCAT',
                    Difference =>  'SQL_FN_STR_DIFFERENCE',
                    Insert =>  'SQL_FN_STR_INSERT',
                    LCase =>  'SQL_FN_STR_LCASE',
                    Left =>  'SQL_FN_STR_LEFT',
                    Length =>  'SQL_FN_STR_LENGTH',
                    Locate =>  'SQL_FN_STR_LOCATE',
                    Locate_2 =>  'SQL_FN_STR_LOCATE_2',
                    LTrim =>  'SQL_FN_STR_LTRIM',
                    Repeat =>  'SQL_FN_STR_REPEAT',
                    Replace =>  'SQL_FN_STR_REPLACE',
                    Right =>  'SQL_FN_STR_RIGHT',
                    RTrim =>  'SQL_FN_STR_RTRIM',
                    Soundex =>  'SQL_FN_STR_SOUNDEX',
                    Space =>  'SQL_FN_STR_SPACE',
                    Substring =>  'SQL_FN_STR_SUBSTRING',
                    UCase =>  'SQL_FN_STR_UCASE'
                    },
                "SQL Numeric Functions" =>  {
                    Desc    =>  "SQL Numeric Functions that are supported",
                    Value   =>  'SQL_NUMERIC_FUNCTIONS',
                    Function =>  GetInfo,
                    Abs     =>  'SQL_FN_NUM_ABS',
                    ACos    =>  'SQL_FN_NUM_ACOS',
                    ASin    =>  'SQL_FN_NUM_ASIN',
                    ATan    =>  'SQL_FN_NUM_ATAN',
                    ATan2   =>  'SQL_FN_NUM_ATAN2',
                    Ceiling =>  'SQL_FN_NUM_CEILING',
                    Cos     =>  'SQL_FN_NUM_COS',
                    Cot     =>  'SQL_FN_NUM_COT',
                    Degrees =>  'SQL_FN_NUM_DEGREES',
                    Exp     =>  'SQL_FN_NUM_EXP',
                    Floor   =>  'SQL_FN_NUM_FLOOR',
                    Log     =>  'SQL_FN_NUM_LOG',
                    Log10   =>  'SQL_FN_NUM_LOG10',
                    Mod     =>  'SQL_FN_NUM_MOD',
                    Pi      =>  'SQL_FN_NUM_PI',
                    Power   =>  'SQL_FN_NUM_POWER',
                    Radians =>  'SQL_FN_NUM_RADIANS',
                    Rand    =>  'SQL_FN_NUM_RAND',
                    Round   =>  'SQL_FN_NUM_ROUND',
                    Sign    =>  'SQL_FN_NUM_SIGN',
                    Sin     =>  'SQL_FN_NUM_SIN',
                    Sqrt    =>  'SQL_FN_NUM_SQRT',
                    Tan     =>  'SQL_FN_NUM_TAN',
                    Truncate    =>  'SQL_FN_NUM_TRUNCATE'
                    },
                "Cursor Scroll Concurrency"    =>  {
                    Desc    =>  "Concurrency control options for scrollable cursors",
                    Value   =>  'SQL_SCROLL_CONCURRENCY',
                    Function =>  GetInfo,
                    "Read Only" =>  'SQL_SCCO_READ_ONLY',
                    Lock    =>  'SQL_SCCO_LOCK',
                    "Optimistic via row versions"   =>  'SQL_SCCO_OPT_ROWVER',
                    "Optimistic values" =>  'SQL_SCCO_OPT_VALUES'
                    },
                "Cursor Scroll Options"    =>  {
                    Desc    =>  "Scrolling options supported for cursors",
                    Value   =>  'SQL_SCROLL_OPTIONS',
                    Function =>  GetInfo,
                    "Forward Only"  =>  'SQL_SO_FORWARD_ONLY',
                    Static          =>  'SQL_SO_STATIC',
                    "Keyset Driven" =>  'SQL_SO_KEYSET_DRIVEN',
                    Dynamic         =>  'SQL_SO_DYNAMIC',
                    Mixed           =>  'SQL_SO_MIXED'
                    }
                );

$~ = "REPORT";
foreach $Attrib ( sort( keys( %Attributes ) ) )
{
    $Desc  = $Attributes{$Attrib}->{Desc};
    $Function = $Attributes{$Attrib}->{Function};
    $Value = eval("\$db->$Function(\$db->$Attributes{$Attrib}->{Value})");
    print "\n$Attrib  [$Attributes{$Attrib}->{Value}] = \"$Value\"\n";
    print "   $Desc.\n";

    foreach $Type ( sort( keys( %{$Attributes{$Attrib}} ) ) )
    {
        if( $Type eq "Desc" || $Type eq "Value" || $Type eq "Function" )
        {
            next;
        }

        undef $Const;
        undef $Supported;

        $Const = eval( "\$db->$Attributes{$Attrib}->{$Type}" );
        $Supported = ( $Value & $Const );
        if( $Supported > 0 )
        {
            $Supported = "Yes";
        }
        else
        {
            $Supported = "No";
        }
        write();
    }
}

print<<EOText;


Show how this ODBC Driver maps SQL Data Types:
----------------------------------------------
    The following table shows how this ODBC driver will map common
    SQL Data Types to it's ODBC Driver specific data type.
    it will also show the literal syntax, that is, how you deal with
    the data in an SQL statement. For example, if the literal syntax
    for the data type CHAR is 'DATA' then you would surround your
    CHAR data with single quotes as in :
        SELECT * FROM FOO WHERE Field1 = 'jello'

EOText

$~ = "Type_Header";
write();
$~ = "Type_Info";
foreach $Type ( ( @Types ) )
{
    if( $db->GetTypeInfo( eval( "\$db->SQL_$Type" ) ) )
    {
        undef %Data;
        if( $db->FetchRow() )
        {
            %Data = $db->DataHash();
            $Data{data_example} = $Data{LITERAL_PREFIX} . "DATA" . $Data{LITERAL_SUFFIX};
        }
        else
        {
            $Data{TYPE_NAME} = "---not supported---";
        }
        write();
    }
}

print "\n--== End Of Report ==--\n";
$db->Close();


format REPORT =
      @<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
      $Supported, $Attributes{$Attrib}->{$Type}, $Type
.

format Type_Header =
    SQL Data Type     ODBC Driver Name    Literal Syntax
    ----------------- ------------------- --------------
.

format Type_Info =
    @<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<< @<<<<<<<<
    $Type, $Data{TYPE_NAME}, $Data{data_example}
.


