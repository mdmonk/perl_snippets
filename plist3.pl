#!/usr/bin/perl

use Foundation;
use lib "/Users/mdmonk/bin/";
require "perlplist.pl"; # for perlValue

sub getPlistObject {
  my ( $object, @keysIndexes ) = ( @_ );
  if ( @keysIndexes ) {
    foreach my $keyIndex ( @keysIndexes ) {
      if ( $object and $$object ) {
        if ( $object->isKindOfClass_( NSArray->class ) ) {
          $object = $object->objectAtIndex_( $keyIndex );
        } elsif ( $object->isKindOfClass_( NSDictionary->class ) ) {
          $object = $object->objectForKey_( $keyIndex );
        } else {
          print STDERR "Unknown type (not an array or a dictionary):\n";
          return;
        }
      } else {
        print STDERR "Got nil or other error for $keyIndex.\n";
        return;
      }
    }
  }
  return $object;
}

$file = "/Library/Preferences/SystemConfiguration/preferences.plist";
$plist = NSDictionary->dictionaryWithContentsOfFile_( $file );
if ( $plist and $$plist) {

  $computerName = getPlistObject( $plist, "System", "System", "ComputerName" );
  if ( $computerName and $$computerName ) {

    print perlValue( $computerName ) . "\n";

  } else {
    die "Could not find the value.\n";
  }
} else {
  die "Error loading file.\n";
}

