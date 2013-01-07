use Foundation;

sub perlValue {
  my ( $object ) = @_;
  return $object->description()->UTF8String();
}

# more subroutines go here...

1;
