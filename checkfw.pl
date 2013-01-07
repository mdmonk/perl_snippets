#!/usr/bin/perl -w

use strict;
use warnings;

my %connections;

while ( my $line = <> ) {
  next unless $line =~ m/ ipfw: /;

  $line =~ s/.* ipfw: //g;

  my ( $action, $from, $to, $direction ) 
    = ( split( ' ', $line, 7 ) )[ 1, 3, 4, 5 ];

  if ( check_address($from) and check_address($to) ) {
    my $key = ( $direction eq 'out' ) ? 
      "$from $to" : "$to $from";
    $connections{$action}->{$key}->{$direction}++;
  }
}

foreach my $action ( sort keys %connections ) {
  report( $action, %{ $connections{$action} } );
}

sub report {
  my ( $action, %data ) = @_;

  print "$action\n";
  printf( "%21s Dir %21s : %8s : %8s\n",
    'Inside IP', 'Outside IP', 'In', 'Out' );
  print '-' x 69 . "\n";

  foreach my $k ( sort keys %data ) {
    my ( $inside, $outside ) = split( ' ', $k );

    my $direction = '-->';
    if ( $data{$k}->{in} ) {
      $direction = ( $data{$k}->{out} ) ? '<->' : '<--';
    }
    printf( "%21s %s %21s : %8d : %8d\n", 
      $inside, 
      $direction, 
      $outside, 
      $data{$k}->{in} || 0, 
      $data{$k}->{out} || 0 );
  }
  print "\n";
}

##
## Filter the broken lines in the log
##

sub check_address {
  my $text = shift;

  # There should only be 1 colon
  my $count = $text =~ tr/://;
  return undef if $count != 1;

  # There should only be three .s
  $count = $text =~ tr/.//;
  return undef if $count != 3;

  my ( $ip, $port ) = split( ':', $text );

  # Is the port number sensible
  return undef if $port < 1 or $port > 65535;

  # Are the address digits sensible
  foreach my $x ( split( '\.', $ip ) ) {
    return undef if $x < 0 or $x > 255;
  }

  # All is fine
  return 1;
}