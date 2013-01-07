#  WMI_PS.pl
#  Example 9.14:
#  ----------------------------------------
#  Originally from "Win32 Perl Scripting: Administrators Handbook" by Dave Roth
#  http://www.roth.net/books/handbook/
#  Published by New Riders Publishing.
#  ISBN # 1-57870-215-1
#
#  This script uses WMI to generate a process list from remote machines.
#
#  Syntax:
#     WMI_PS.pl [\\machine]
#
#     \\machine.....Computer name of remote machine
#
print "Inspired from the book 'Win32 Perl Scripting: The Administrator's Handbook' by Dave Roth\n\n";

use Win32::OLE qw( in );
use vars qw( $VERSION $KILOBYTE $MEGABYTE $GIGABYTE );
use Getopt::Long;

$VERSION = 20060131;
$GIGABYTE = 1024 * ( $MEGABYTE = 1024 * ( $KILOBYTE = 1024 ) );
%SORT_PROPERTY = (
  m     =>  ['WorkingSetSize', 'Memory Size'],
  v     =>  ['VirtWorkingSetSize', 'Virutal Memory Size'],
  p     =>  ['PeakWorkingSetSize', 'Peak Memory Size'],
  pid   =>  ['PID', 'Process ID'],
  ppid  =>  ['ParentProcessId', 'Parent Process ID'],
  date  =>  ['CreationDate', 'Creation Date'],
  t     =>  ['ThreadCount', 'Thread Count'],
);

Configure( \%Config );

if( $Config{help} )
{
    Syntax();
    exit;
}

# This is the WMI moniker that will connect to a machine's 
# CIM (Common Information Model) repository
my $CONNECT_MONIKER = "WinMgmts:{impersonationLevel=impersonate}!//$Config{machine}";

# Get the WMI (Microsoft's implementation of WBEM) interface
my $WMI = Win32::OLE->GetObject( $CONNECT_MONIKER ) 
  || die "Unable to connect to \\$Machine:" . Win32::OLE->LastError();

# Get the collection of Win32_Process objects
$ProcList = $WMI->InstancesOf( "Win32_Process" );

$~ = PROCESS_HEADER;
write;
$~ = PROCESS_INFO;

# Cycle through each Win32_Process object 
# and write out its details...
foreach $Proc ( sort( SortProcs ( in( $ProcList ) ) ) )
{
    write;
    $Total{memory} += $Proc->{WorkingSetSize};
    $Total{virt_memory} += $Proc->{VirtualSize};
}

print "\n" . "-" x 40 . "\n";
print "Totals:\n";
print "\tMemory use:     " . FormatNumber( $Total{memory} ) . "\n";
print "\tVirtual memory: " . FormatNumber( $Total{virt_memory} ) . "\n";

sub SortProcs 
{
  my $First = $a;
  my $Second = $b;
  if( $Config{descending} )
  {
    $Second = $a;
    $First = $b;
  }
  if( defined $Config{sort} )
  {
    lc $First->{$SORT_PROPERTY{$Config{sort}}[0]} <=> $Second->{$SORT_PROPERTY{$Config{sort}}[0]}
  }
  else
  {
    return( lc $First->{Name} cmp lc $Second->{Name} );
  }
}

sub FormatNumber
{
    my( $Number ) = @_;
    my( $Suffix ) = "";
    my $K = 1024;
    my $M = 1024 * $K;

    if( $GIGABYTE <= $Number )
    {
      $Suffix = "G";
      $Number /= $GIGABYTE;
    }
    elsif( $MEGABYTE <= $Number )
    {
        $Suffix = "M";
        $Number /= $MEGABYTE;
    }
    elsif( $KILOBYTE <= $Number )
    {
        $Suffix = "K";
        $Number /= $KILOBYTE;
    }

    $Number =~ s/(\.\d{0,1})\d*$/$1/;

    {} while ($Number =~ s/^(-?\d+)(\d{3})/$1,$2/);

    return( $Number . $Suffix );
}

sub FormatDate
{
    my( $Date ) = @_;
    $Date =~ s/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2}).*/$1.$2.$3 $4:$5:$6/;
    return( $Date );
}

sub Configure
{
    my $Config = shift @_;
    my $Result;
    
    Getopt::Long::Configure( "prefix_pattern=-|\/" );
    $Result = GetOptions( $Config, 
                            qw( 
                                sort|s=s
                                descending|d
                                help|?|h
                            ));
    $Config->{sort} = lc $Config->{sort} if( "" ne $Config->{sort} );
    ($Config->{machine} = shift @ARGV || "." ) =~ s/[\\\/]+//;
#    $Config->{help} = 1 if( ! $Result || ( defined $Config->{sort} && ! defined $SORT_PROPERTY{$Config->{sort}} ) );
}

sub Syntax
{
    my( $Script ) = ( $0 =~ m#([^\\/]+)$# );
    my $Line = "-" x length( $Script );
    my $SortFields;
    foreach my $Key ( sort( keys( %SORT_PROPERTY ) ) )
    {
      $SortFields .= sprintf( "\n%s%-7s%s", " " x 25, $Key, $SORT_PROPERTY{$Key}[1] );
    }
      
    print << "EOT";

$Script
$Line
Displays process information.

    Version: $VERSION

    Syntax: $Script [-d] [-s SORTFIELD] [MACHINE]
        -d.............Sort list in decending order.
        -s SortField...Specifies what field to sort by. This can be
                       any of the following:
                         $SortFields
                        
                         Default is: Process Name
        MACHINE........Name of machine to query.               
                       Default is: "."

EOT

}

format PROCESS_HEADER =
@||||||||||                @|| @|||||||||||||||||||
"Process ID", "Thr"             "------ Memory ------"
@||| @|||| @|||||||||||||| @|| @||||| @||||| @||||| @||||||||||||||||||
PID, Parnt, "Process Name", "ead", "Memory", "Peak", "Virt", "Created"
---- ----- --------------- --- ------ ------ ------ -------------------
.

format PROCESS_INFO =
@>>> @>>>> @<<<<<<<<<<<<<< @>> @>>>>> @>>>>> @>>>>> @>>>>>>>>>>>>>>>>>>
$Proc->{'ProcessID'}, $Proc->{'ParentProcessID'}, $Proc->{Name}, $Proc->{'ThreadCount'}, FormatNumber( $Proc->{'WorkingSetSize'} ), FormatNumber( $Proc->{'PeakWorkingSetSize'} ), FormatNumber( $Proc->{'VirtualSize'} ), FormatDate( $Proc->{'CreationDate'} )
.                                                                                                                                                    
