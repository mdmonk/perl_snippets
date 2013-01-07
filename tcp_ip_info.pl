use Win32::Registry;

$Server=Win32::NodeName() unless( $Server = $ARGV[0] );

#Store an Array of the various TCP/IP Elements that are to be queried later.
@TCPIP_Values = qw (DHCPDomain
                    DHCPHostname
                    DHCPNameServer
                    Domain
                    Hostname
                    NameServer
                   );

#Store an Array of the various NetBios/WINS Elements that are to be queried later.
@NetBt = qw (DHCPNameServer
             DHCPNameServerBackup
             NameServer
             NameServerBackup
            );

if (Win32::IsWinNT()) {
  Workstat_Read_Nic_Config();
} else {
  die "This Script Requires Windows NT...  Sorry :(\nMaybe you should make a rewrite!?\n";
}

exit;

sub Workstat_Read_Nic_Config {

  #Used later for the Various Queried Services 
  $Services_Root="System\\CurrentControlSet\\Services";

  #TCPIP Service
  $TCPIP_Service_Sub_Key=$Services_Root."\\Tcpip\\Parameters";

  #NetBios Service Adapter Subkey
  $NetBtRegKey=$Services_Root."\\NetBt\\Adapters";
  #Used for getting Friendly names for the (Possibly Multiple Adapters)
  $HKLM_NT_NICS="Software\\Microsoft\\Windows NT\\CurrentVersion\\NetworkCards";

  #Has no meaning in a single-use running of this script, but if you were to run
  #this subroutine from a foreach @Machines, in which @Machines was an array of machine names, you'd need this line.
  undef (@NICNames);

  #Connect to the remote Server's Registry
  #$Remote_Registry=$HKLM->Win32::Registry::Connect($Server);
  $HKEY_LOCAL_MACHINE->Win32::Registry::Connect($Server,$Remote_Registry);

  #If connection was successful...
  if($Remote_Registry) {
    #print "Computer Name: $Server\n";

    #Open 'HKLM\System\CurrentControlSet\Services\TCPIP' and store the result later use.
    #$TCPIP_Key=$Remote_Registry->Open($TCPIP_Service_Sub_Key);
    $Remote_Registry->Open($TCPIP_Service_Sub_Key,$TCPIP_Key);

    #If Connection was made to the Remote PC's TCPIP Service...
    if ($TCPIP_Key) {

      foreach $data (@TCPIP_Values) {
        #Query the DHCP and non-DHCP TCP/IP Parameters
        $TCPIP_Key->QueryValueEx($data,$type,$value);
        if ($value) {
          #print "TCPIP HASH\t$data - $value\n";

          #If a value exists for the named Registry value, write it to the TCPIP Hash for use later. 
          $TCPIP{$data}=$value;
        }
      }
      $TCPIP_Key->Close();
    }
    #Open 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\NetwordCards' and store the result later use.
    #$HKLM_NT_CV_NetworkCards=$Remote_Registry->Open($HKLM_NT_NICS);
    $Remote_Registry->Open($HKLM_NT_NICS,$HKLM_NT_CV_NetworkCards);

    if ($HKLM_NT_CV_NetworkCards) {

      #Look for the Friendly Names of the (Possible Multiple) NICs in the system. 
      #@HKLM_NIC_Numbers=$HKLM_NT_CV_NetworkCards->GetKeys();
      $HKLM_NT_CV_NetworkCards->GetKeys(\@HKLM_NIC_Numbers);

      foreach $nic_number (@HKLM_NIC_Numbers) {
        #HKLM\Software\Windows NT\CurrentVersion\NetworkCards\NicNumber
        #Set this value for later use..
        $nic_num=$HKLM_NT_NICS."\\".$nic_number;

        #Query "Friendly" information about the specified NIC Card.
        #$Nic_Info=$Remote_Registry->Open($nic_num);
        $Remote_Registry->Open($nic_num,$Nic_Info);

        #If the Registry Key was opened successfully...
        if ($Nic_Info) {
          #Set this value for future use ..  This is a Service name for use in a later query. 
          $Nic_Info->QueryValueEx("ServiceName",$type,$Nic_Service_Desc);
          
          #Friendly Name of the NIC...
          $Nic_Info->QueryValueEx("Title",$type,$Nic_Title);

          #print "Nic Info: $Nic_Service_Desc - $Nic_Title\n";

          #Store the Friendly Name for later output.
          $Nic_Service_Name{$Nic_Service_Desc}{"Title"}=$Nic_Title;

          #Open the NetBios Service Adapter Subkey and store the value for later use.
          #$key=$Remote_Registry->Open($NetBtRegKey);
          $Remote_Registry->Open($NetBtRegKey,$key);

          #If the NetBios Service Adapter Subkey was successfully opened...
          if ($key) {

            #Add an entry to an array of NIC Cards for later use.
            push (@NICS,$Nic_Service_Desc);

            #Set a value equal to the NetBios Adapter Subkey for the specified NIC Card.
            $NetBtAdapterKeyname=$NetBtRegKey."\\".$Nic_Service_Desc;

            #Set a value equal to the specified NIC Card's Service 'Parameters\Tcpip' subkey.
            $NIC_Service_Sub_Key=$Services_Root."\\".$Nic_Service_Desc."\\Parameters\\Tcpip";

            #Open the NIC's Service 'Parameters\Tcpip' Subkey.
            #$NICNameServiceKey=$Remote_Registry->Open($NIC_Service_Sub_Key);
            $Remote_Registry->Open($NIC_Service_Sub_Key,$NICNameServiceKey);

            #If the Service's Subkey was opened successfully..
            if ($NICNameServiceKey) {
              #Check to see if DHCP is enabled on this computer.
              #$NICNameServiceKey->GetValue("EnableDHCP",$Enable_DHCP);
              $NICNameServiceKey->QueryValueEx("EnableDHCP",$type,$Enable_DHCP);
              
              #If DHCP Is Enabled...
              if ($Enable_DHCP) {
                #Set the NIC_Service Array to a listing of DHCP TCP/IP entries.
              
                @NIC_Service = qw (DHCPDefaultGateway
                                   DHCPIPAddress
                                   DHCPSubnetMask
                                   DHCPServer
                                  );
              } else {
                #Set the NIC_Service Array to a listing of static TCP/IP entries.
                @NIC_Service = qw (DefaultGateway
                                   IPAddress
                                   SubnetMask
                                  );
              }

              foreach $data (@NIC_Service) {
                #Query the various DHCP or static TCP/IP properties.
                $NICNameServiceKey->QueryValueEx($data,$type,$value);

                #If the query found a value
                if ($value) {
                  #print "Nic_Service_Name\t$data - $value\n";

                  #Store the value for later use.
                  $Nic_Service_Name{$Nic_Service_Desc}{$data}=$value;
                }
              }
            }
            
            #Open the NetBios Servies for the specified NIC Card.
            #$NetBtAdapterKey=$Remote_Registry->Open($NetBtAdapterKeyname);
            $Remote_Registry->Open($NetBtAdapterKeyname,$NetBtAdapterKey);
            
            #If the Registry key was opened successfully...
            if ($NetBtAdapterKey) {
              foreach $data (@NetBt) {
                #Query the various NetBios\WINS elements 
                $NetBtAdapterKey->QueryValueEx($data,$type,$value);

                #If there is a value for the queried element
                if ($value) {
                  #print "Nic_Service_Name\t$data - $value\n";

                  #Write the data for later use.
                  $Nic_Service_Name{$Nic_Service_Desc}{$data}=$value;
                }
              }
            }
          }
        }
      }
    }
  }

  #Print the Configuration info...
  print "DNS Config on Computer: $Server\n";
  foreach $item (sort keys %TCPIP) {
    print "\t$item - $TCPIP{$item}\n";
  }
  print "-----\n";
  print "Network Adapter Information on Computer: $Server\n";
  foreach $nic (keys %Nic_Service_Name) {
    print "\t$nic - $Nic_Service_Name{$nic}{Title}\n";
    foreach $item(sort keys % {$Nic_Service_Name{$nic}}) {
      if ($item ne "Title") {
        print "\t\t$item - $Nic_Service_Name{$nic}{$item}\n";
      }
    }
  }
}
