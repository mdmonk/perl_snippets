#!/usr/bin/perl
#
# Script to remove duplicates from your iTunes Music Library folder as a result of
# consolidating a music library into a backup copy. This results in duplicating files
# with a postfix of " 1" to them. The script will remove the original file, after
# verifying that the duplicate matches the original via a MD5 Digest.
#
# You will need to modify the $start variable below to be the location of your music
# library. 
#
# Usage:
#		./weed_duplicates.pl
#
#
# Copyright(c) 2006 Peter A Royal JR. <peter.royal@pobox.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software 
# without restriction, including without limitation the rights to use, copy, modify, 
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to 
# permit persons to whom the Software is furnished to do so, subject to the following 
# conditions:
#
# The above copyright notice and this permission notice shall be included in all copies 
# or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
# FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
# DEALINGS IN THE SOFTWARE.
#

use strict;
use warnings;

use File::Find;  
use DirHandle;
use Digest::MD5;

my $start = "/Volumes/porsche/mp3s";
         
sub digest {
	my $file = shift;
	open( FILE, $file ) or die "Can't open '$file': $!\n";
	binmode( FILE );
	
	my $digest = Digest::MD5->new->addfile( *FILE )->hexdigest;
	
	close( FILE );
	
	return $digest;
}

sub process_file {
	return unless -d;
  
 	my $dh = DirHandle->new( $File::Find::name );

	my @files = sort 										# sort
					grep { -f }                      # files only
					map { "$File::Find::name/$_" }   # full paths
					grep { !/^\./ }						# no dot files
					grep { !/^Icon\r$/ }					# no icon
					$dh->read();							# read all entries
					
   return unless @files;

	my %mapped_files;
	
	for (@files) { $mapped_files{$_} = 1 };
                  
	for ( keys %mapped_files ) {
		if( /(.*) 1(\.[a-z0-9]{3})$/ ) {
			my ( $this, $dup ) = ( $_, "$1$2" );
			
			if( $mapped_files{$dup} ) {
				my ( $this_digest, $dup_digest ) = ( digest( $this ), digest( $dup ) );
				
				if( $this_digest eq $dup_digest ) {
					print "REMOVING -- duplicate: $dup\n";
					unlink( $dup ) or die "Can't delete $dup : $!\n";
				} else {
					print "NO MATCH -- $this and $dup do not match exactly\n"
				}
			}
		}
	}

	$File::Find::prune = 1;
}

find( \&process_file, ($start) );
