######################################################################
# By Larry Mulcahy
# $Revision: 1.2 $
# $Date: 2000/09/06 22:55:08 $
# $Source: /netapp/home/lmulcahy/crash/usr/local/apache/cgi-bin-open/RCS/dblib.pl,v $
# 
# $Log: dblib.pl,v $
# Revision 1.2  2000/09/06 22:55:08  lmulcahy
# Code cleanup a couple of places I had some unnecessarily wordy logic
# to iterate through the results of an SQL query.
#
# Revision 1.1  2000/08/25 21:05:16  lmulcahy
# Initial revision
#
######################################################################

use Cwd;
use URI;

package Dblib;

######################################################################
# 
# Global variables
# 
######################################################################

$Max_scrolling_list_height = 10;

######################################################################
# 
# is_admin
# 
######################################################################

sub is_admin
{
    my($dbh, $userid) = @_;

    my($sql_query) = "select userid from administrators " . 
	"where userid = '$userid'";
    my($sth);
    my($ary_ref);
    my(@admins);

    # Prepare the query
    unless ( $sth = $dbh->prepare($sql_query) ) { &bail_out($dbh); }
    # Execute the query
    unless ( $sth->execute() ) { &bail_out($dbh); }
    # 0 or 1 matches
    $ary_ref = $sth->fetchall_arrayref;
    @admins = @{$ary_ref};
    my($result) = $#admins;
    # Transaction is done
    $rc = $sth->finish();

    $result;
}

######################################################################
# 
# get_row_columns_aa
# 
######################################################################

sub get_row_columns_aa
{
    my($dbh, 
       $key,			# primary key, like 'hostname' or 'userid'
       $value,			# value of above, like 'lmulcahy' or 'babylon5'
       $table,			# table name, like 'machines' or 'people'
       $rowref, 
       $columnsref, 
       $aaref
       ) = @_;

    my($i);
    my($rc);
    my($rv);
    my($sql_query);
    my($sth);

    # First query just to get the column headers
    $sql_query = "select * from $table";
    $sth = $dbh->prepare($sql_query);
    unless ( $sth ) { &bail_out($dbh); }

    # Execute the query
    $rv = $sth->execute();
    unless ( $rv ) { &bail_out($dbh); }

    my(@columns) = @{$sth->{NAME}}; # column headers
    # Strip out the "last_modified" column if it is present.
    @columns = grep ( !/^last_modified$/i, @columns );
    my($columns) = join(",", @columns);

    # Transaction is done
    $rc = $sth->finish();

    # Prepare the query
    $sql_query = "select $columns from $table where $key = '$value'";
    $sth = $dbh->prepare($sql_query);
    unless ( $sth ) { &bail_out($dbh); }

    # Execute the query
    $rv = $sth->execute();
    unless ( $rv ) { &bail_out($dbh); }

    @{$columnsref} = @{$sth->{NAME}}; # column headers
    # There better just be one row
    @{$rowref} = $sth->fetchrow_array;

    # Transaction is done
    $rc = $sth->finish();

    for ($i=$[; $i<=$#{$rowref}; $i++)
    {
	${$aaref}{${$columnsref}[$i]} = ${$rowref}[$i];
    }
}

######################################################################
# get_row_columns_aa_new
# 
# As above, for a new record.
# Retrieves the column names from the database.
# 
######################################################################

sub get_row_columns_aa_new
{
    my($dbh, 
       $table,			# table name, like 'machines' or 'people'
       $rowref, 
       $columnsref, 
       $aaref
       ) = @_;

    my($i);

    # Don't care about the values, but need to do a query just to
    # get the column headers.

    # Prepare the query
    my($sql_query) = "select * from $table";
    my($sth) = $dbh->prepare($sql_query);

    unless ( $sth )
    {
	&bail_out($dbh);
    }

    # Execute the query
    my($rv) = $sth->execute();

    unless ( $rv )
    {
	&bail_out($dbh);
    }

    @{$columnsref} = @{$sth->{NAME}}; # column headers

    # Get rid of the "last_modified" column, which is the last column
    @{$columnsref} = grep ( !/^last_modified$/i, @{$columnsref} );

    # Transaction is done
    my($rc) = $sth->finish();

    for ($i=$[; $i<=$#{$columnsref}; $i++)
    {
	${$rowref}[$i] = ${$aaref}{${$columnsref}[$i]};
    }
}

######################################################################
# 
# bail_out
# 
######################################################################

sub bail_out
{
    my($dbh) = @_;

    if ( $dbh )
    {
	printf ("Error: %s\n", $dbh->errstr);
	# Exit from the database
	$rc = $dbh->disconnect();
    }

    exit;
}

######################################################################
# 
# add_row
# 
######################################################################

sub add_row
{
    my($dbh, 
       $table,			# table name, like 'machines' or 'people'
       $pkey,			# primary key, like 'hostname' or 'userid'
       $pvalue,			# value of above, like 'lmulcahy' or 'babylon5'
       $rowref, 
       $columnsref, 
       $aaref) = @_;

    my($printerror);

    my($sqlquery) = "insert into $table (";

    $sqlquery .= join(',', @{$columnsref});
    $sqlquery .= ') values (';
    $sqlquery .= join(',', map { &oracle_quote($_) } @{$rowref});
    $sqlquery .= ')';

    # For debugging:
    # print "<br>SQLQUERY<br>$sqlquery<br>";

    my($rv) = $dbh->do($sqlquery);

    unless ( $rv )
    {
	&bail_out($dbh);
    }

    # Update "last modified" field

    $sqlquery = "update $table set last_modified = sysdate " .
	"where $pkey = '$pvalue'";

    # If there is an error, just ignore it and carry on.
    # Probably this table has no 'last modified' column.
    $printerror = $dbh->{PrintError}; $dbh->{PrintError} = 0;
    $rv = $dbh->do($sqlquery);
    $dbh->{PrintError} = $printerror;
    # Don't do the usual error handling:
    # unless ( $rv )
    # {
    #     &bail_out($dbh);
    # }
}

######################################################################
# remove_row
# 
# Remove the record with key = value
######################################################################

sub remove_row
{
    my($dbh, 
       $table,			# table name, like 'machines' or 'people'
       $pkey,			# primary key, like 'hostname' or 'userid'
       $pvalue			# value of above, like 'lmulcahy' or 'babylon5'
       ) = @_;

    my($sql_query) = "delete from $table where $pkey ='$pvalue'";

    # for debugging
    # print "<br>SQL_QUERY<br>$sql_query<br>";

    my($rv) = $dbh->do($sql_query);

    unless ( $rv )
    {
	&bail_out($dbh);
    }
}

######################################################################
# db_aa_dbh
# 
# Process a query resulting in 2 columns of output, return
# the result as an associative array.
# 
######################################################################

sub db_aa_dbh
{
    my($dbh,$query,$aaref) = @_;

    my($key);
    my($rc);
    my($sth);
    my($value);
    my(@ary);
    my(@stuff);

    %{$aaref} = ();

    # Prepare the query to be executed
    $sth = $dbh->prepare($query) || die $dbh->errstr;

    # Execute the query
    $rv = $sth->execute() || die $dbh->errstr;

    # Process each row
    while (@ary = $sth->fetchrow_array)
    {
	($key,$value,@stuff) = @ary;
	${$aaref}{$key} = $value;
    }

    # Transaction is done
    $rc = $sth->finish();
}

######################################################################
# 
# printfile
# 
######################################################################

sub printfile
{
    my($filename) = @_;

    open (IN, "<$filename")
	or die "Failed to open $filename for input: $!\n";
    while (<IN>)
    {
	print;
    }
    close(IN);
}

######################################################################
# 
# update_db
# 
######################################################################

sub update_db
{
    my($dbh,
       $table,			# table name, like 'machines' or 'people'
       $pkey,			# primary key, like 'hostname' or 'userid'
       $pvalue,			# value of above, like 'lmulcahy' or 'babylon5'
       $column,			# column to change
       $value			# new value
       ) = @_;

    my($statement) = "update $table set $column = " . 
	&oracle_quote($value) .
	" where $pkey = '$pvalue'";

    my($rv) = $dbh->do($statement);

    unless ( $rv )
    {
	&bail_out($dbh);
    }

    # Update "last modified" field

    $statement = "update $table set last_modified = sysdate " .
	"where $pkey = '$pvalue'";

    # If there is an error, just ignore it and carry on.
    # Probably this table has no 'last modified' column.
    $printerror = $dbh->{PrintError}; $dbh->{PrintError} = 0;
    $rv = $dbh->do($statement);
    $dbh->{PrintError} = $printerror;
    # Don't do the usual error handling:
    # unless ( $rv )
    # {
    #     &bail_out($dbh);
    # }
}

######################################################################
# 
# do_sql_query
# 
######################################################################

sub do_sql_query
{
    my($sql_query, $dbh, $query) = @_;

    my($e);
    my($rc);
    my($rv);
    my($sth);
    my($u);
    my(@ary);

    # Prepare the query to be executed
    $sth = $dbh->prepare($sql_query);
    if ( $sth )
    {
	# Execute the query
	$rv = $sth->execute();
	if ( $rv )
	{
	    # Looks nicer centered
	    print "<center>\n";
	    
	    # Start drawing a table.
	    print "<table border>\n";

	    # Do the column headers
	    foreach $e (@{$sth->{NAME}})
	    {
		printf "<th>%s</th>\n", $e;
	    }

	    # Process each row
	    while (@ary = $sth->fetchrow_array)
	    {
		print "<tr>\n"; # start row
		foreach $e (@ary)
		{
		    # Does it look like an HTTP URL?
		    $u = URI->new($e);
		    if ( $u && (($u->scheme || '') eq "http") )
		    {
			# Display as a clickable URL
			print '<td>';
			printf "<a href=\"%s\">%s</a>", $e, $e;
			print '</td>';
		    }
		    else
		    {
			printf "<td>%s</td>\n", ($e ? $e : '<br>');
		    }
		}
		print "</tr>\n"; # end row
	    }
	    print "</table>\n"; # end table
	    print "</center>\n"; # end center
	}

	# Transaction is done
	$rc = $sth->finish();
    }
}

######################################################################
# 
# get_column
# 
######################################################################

sub get_column
{
    my($dbh, $table, $key) = @_;
    my($sql_query) = "select $key from $table " . 
	"order by $key";
    my($ary_ref) = $dbh->selectcol_arrayref($sql_query);

    return(@{$ary_ref});
}

######################################################################
# 
# listener_ok
# 
# Make sure the Oracle listener is running on the local host
# 
######################################################################

sub listener_ok
{
    my($ps) = '/usr/ucb/ps';
    my($result) = 1;

    open ( PS, "$ps axw |" )
	or die "Can't open pipe: $!";
    unless ( grep(/tnslsnr/, <PS>))
    {
	$result = 0;
    }
    close(PS);

    $result;
}

######################################################################
# 
# oracle_quote
# 
######################################################################

sub oracle_quote
{
    my($string) = @_;

    # Double any single quotes

    $string =~ s/\'/\'\'/g;

    # Add single quotes

    $string = "'" . $string . "'";

    $string;
}

######################################################################
# 
# scrolling_list_height
# 
######################################################################

sub scrolling_list_height
{
    my(@list) = @_;

    my($big) = $#list - $[ + 1;	# actual number of elements in list

    ($big < $Dblib::Max_scrolling_list_height) ?
	$big : $Dblib::Max_scrolling_list_height;
}

1;
