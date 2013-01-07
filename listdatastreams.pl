#  ListDataStreams.pl
#  ------------------
#  Displays all data streams in an NTFS file.
#
#  Copyright (c) 2006 by Dave Roth
#  rothd@roth.net
#  Courtesy of Roth Consulting
#  http://www.roth.net/
#
#  Syntax:
#     ListDataStreams.pl file1 [file2 ...]
#     File names can contain masks like: MyFile.*
#

use Win32::API::Prototype;

$VERSION = 20060412;

$GENERIC_READ = 0x80000000;                                     
$OPEN_EXISTING = 3;
$BACKUP_DATA = 0x00000001;
$BACKUP_ALTERNATE_DATA = 0x00000004;
                        
#Code Block A             
ApiLink( 'kernel32.dll', 'HANDLE CreateFile( LPCTSTR pszPath, DWORD dwAccess,
                                             DWORD dwShareMode, PVOID SecurityAttributs,
                                             DWORD dwCreationDist, DWORD dwFlags,
                                             HANDLE hTemplate )' ) || die "Can not load the CreateFile() function";
ApiLink( 'kernel32.dll', 'BOOL CloseHandle( HANDLE hFile )' ) || die "Can not create CloseHandle()";                                             
ApiLink( 'kernel32.dll', 'BOOL BackupRead( HANDLE hFile, 
                                           LPBYTE pBuffer, 
                                           DWORD dwBytesToRead, 
                                           LPDWORD pdwBytesRead, 
                                           BOOL bAbort, 
                                           BOOL bProcessSecurity, 
                                           LPVOID *ppContext)' ) || die "Can not create BackupRead()";
ApiLink( 'kernel32.dll', 'BOOL BackupSeek( HANDLE hFile, 
                                           DWORD dwLowBytesToSeek,
                                           DWORD dwHighBytesToSeek,
                                           LPDWORD pdwLowByteSeeked,
                                           LPDWORD pdwHighByteSeeked,
                                           LPVOID *pContext )' ) || die "Can not create BackupSeek()";

foreach my $Mask ( @ARGV )
{
    foreach my $Path ( glob( $Mask ) )
    {
        push( @Files, $Path ) if( -f $Path );
    }
}

foreach my $File ( @Files ) 
{
    print "$File\n";
    
#Code Block B
    $hFile = CreateFile( $File, $GENERIC_READ, 0, undef, $OPEN_EXISTING, 0, 0 ) || die "Can not open the file '$File'\n";

    # If CreateFile() failed $hFile is a negative value
    if( 0 < $hFile )
    {


#Code Block C
        my $iStreamCount = 0;
        my $pBytesRead = pack( "L", 0 );
        my $pContext = pack( "L", 0 );
        my $pStreamIDStruct = pack( "L5", 0,0,0,0,0 );
        

#Code Block D
        while( BackupRead( $hFile, $pStreamIDStruct, length( $pStreamIDStruct ), $pBytesRead, 0, 0, $pContext ) )
        {
            my $BytesRead = unpack( "L", $pBytesRead );
            my $Context = unpack( "L", $pContext );
            my %Stream;
            my( $pSeekedBytesLow, $pSeekedBytesHigh ) = ( pack( "L", 0 ), pack( "L", 0 ) );
            my $StreamName = "";
            
            # No more data to read
            last if( 0 == $BytesRead );

            @Stream{ id, attributes, size_low, size_high, name_size } = unpack( "L5", $pStreamIDStruct );

#Code Block E

            if( $BACKUP_ALTERNATE_DATA == $Stream{id} )
            {
                $StreamName = NewString( $Stream{name_size} );
                if( BackupRead( $hFile, $StreamName, $Stream{name_size}, $pBytesRead, 0, 0, $pContext ) )
                {
                    my $String = CleanString( $StreamName, 1 );
                    $String =~ s/^:(.*?):.*$/$1/;
                    $StreamName = $String;
                }
            }
            elsif( $BACKUP_DATA == $Stream{id} )
            {
                $StreamName = "<Main Data Stream>";
            }
            printf( "  % 3d) %s\n", ++$iStreamCount, $StreamName ) if( "" ne $StreamName );

#Code Block F
            
            # Move to next stream...
            if( ! BackupSeek( $hFile, $Stream{size_low}, $Stream{size_high}, $pSeekedBytesLow, $pSeekedBytesHigh, $pContext ) )
            {
                last;
            }
            $pBytesRead = pack( "L2", 0 );
            $pStreamIDStruct = pack( "L5", 0,0,0,0,0 );

        } 
#Code Block G
        # Abort the backup reading. Win32 API claims we MUST do this.
        BackupRead( $hFile, undef, 0, 0, 1, 0, $pContext );
        CloseHandle( $hFile );

    }
    print "\n";
}



