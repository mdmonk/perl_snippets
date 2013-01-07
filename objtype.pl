use Win32::OLE;

$File = $ARGV[0];
chomp($File);
if ( $Object = Win32::OLE->GetObject( $File ) ) {
  @TypeInfo = Win32::OLE->QueryObjectType( $Object );
  print "The object type for $File is '$TypeInfo[1]'\n";
  print "The type library is: '$TypeInfo[0]'.\n";
} else {
  print "Nothing happened.....what the heck????\n";
}
