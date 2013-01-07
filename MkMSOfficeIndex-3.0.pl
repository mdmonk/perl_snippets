#!/usr/local/bin/perl -w

=head1 NAME

MkMSOfficeIndex - creates an HTML-index containing informations on all MS-office (and others) files in a directory

=head1 SYNOPSIS

  MkMSOfficeIndex <RelativePathToDir>  # generates index for this path
  MkMSOfficeIndex [-h|-H|-help]       # get this help

=head1 DESCRIPTION

generates in <RelativePathToDir> a file MkMSOfficeIndex.html containing metainformations
of all Microsoft office (and others) files in <RelativePathToDir>.
It supports recursive index-trees (see EXAMPLE).

=head1 EXAMPLE

find . -type d -exec MkMSOfficeIndex '{}' \\;

=head1 AUTHOR

B.Weiler, Siemens AG, ICN TR ON E A, 2.99, Bernard.Weiler@icn.siemens.de

=head1 CAVEATS

void

=head1 PREREQUISITES

5.004;
Pod::Usage;
Config;
Cwd;
HTML::FormatText;
HTML::Parse;
file(1)
OLE-Storage-0.386

=head1 COREQUISITES

mswordview (http://www.gnu.org/~caolan/docs/MSWordView.html)

=head1 OSNAMES

This script is known to work on C<Solaris 2.5.1>

=head1 SCRIPT CATEGORIES

CPAN

=cut


use strict;
use 5.004;
use Pod::Usage;
use Config;
use Cwd;
use HTML::FormatText;
use HTML::Parse;


my $Lib="$Config{prefix}/bin";
my $LibMswordview="/usr/local/bin/mswordview";
my $MkWinwordIndex="MkMSOfficeIndex.html";

my ($File,$is);
my $Dir=shift;
chomp $Dir;
pod2usage(-verbose => 2) if((not defined $Dir)or($Dir =~/-h|^\//i));

open(INDEX,">$Dir/$MkWinwordIndex") or die $!;
my @MetaList=qw(Filename Application Title Authress Created);
my %Meta;
push(@MetaList,"Last saved");
push(@MetaList,"MetaInfos");
push(@MetaList,"DocumentContent");
print INDEX"<H1 ALIGN=\"center\">Directory Listing of Microsoft office Files</H1>\n";
print INDEX"Directory: ".cwd()."/$Dir<P>\b";
print INDEX"<TABLE BORDER=1><TR BGCOLOR=\"yellow\">";
foreach $is (@MetaList){print INDEX"<TH>$is</TH>\n"}
print INDEX"</TR>\n";
opendir(DH,$Dir) or die $!;
foreach $File (sort readdir(DH)){
  next if($File=~/^\./);
  next if($File eq $MkWinwordIndex);
  if($File=~/\.(doc|xls|ppt|mpp)$/i){
    #print STDERR "$Dir/$File\n";
    print INDEX "<TR>";
    my @il;
    foreach $is (@MetaList){$Meta{$is}='-'}
    $Meta{Filename}="<A HREF=\"./$File\">$File</A>";
    open(PIPE,"$Lib/ldat '$Dir/$File' |") or die $!;
    while(<PIPE>){
      chomp;
      foreach $is (@MetaList){
        next unless($_=~$is);
	$Meta{$is}=$_;
	$Meta{$is}=~s|^.*?:||;
      }
      push(@il,$_);
      $Meta{Filename}.="<BR><FONT COLOR=\"red\"><B>Error found in Document!</B></FONT>" if(/Error/);
    }
    close PIPE;
    $Meta{MetaInfos}="<PRE><FONT SIZE=-1>".join('<BR>',@il)."</FONT></PRE>";
    #if($File=~/\.doc/){
    if($Meta{Application} =~ /Microsoft\s+Word/){
      $Meta{"DocumentContent"}="<PRE><FONT SIZE=-1>";
      my $ii=0;
      my $is='';
      if($Meta{Application} !~ /8\./){
	open(PIPE,"$Lib/lhalw --to_stdout --column 70 '$Dir/$File' |") or die $!;
	while(<PIPE>){
          chomp;
	  next if($ii==10);
	  $ii++;
	  $Meta{"DocumentContent"}.="$_\n";
	}
	close(PIPE);
      }else{
        if(-e $LibMswordview){
	  open(PIPE,"$LibMswordview -n -t 2 -m -i $ENV{HOME}/tmp -o - '$Dir/$File' |") or die $!;
	  while(<PIPE>){
            chomp;
	    $is.="$_\n";
	  }
	  close(PIPE);
	  $is=HTML::FormatText->new->format(parse_html($is));
	  my @is=split("\n",$is);
	  $#is=10 if $#is >10;
	  $Meta{"DocumentContent"}.=join("\n",@is);
	}else{$Meta{"DocumentContent"}.="Glimpse on content not provided\n"}
      }
      $Meta{"DocumentContent"}.="\n(...truncated)</FONT></PRE>";
    }
    foreach $is (@MetaList){print INDEX"<TD>$Meta{$is}</TD>\n"}
    print INDEX"</TR>\n";
  }
  else{
    foreach $is (@MetaList){$Meta{$is}='-'}
    if(-l "$Dir/$File"){
      $Meta{Filename}="<A HREF=\"./".readlink("$Dir/$File")."/$MkWinwordIndex\">$File</A>";
      $Meta{Application}="Is a link";
    }
    elsif(-d "$Dir/$File"){
      $Meta{Filename}="<A HREF=\"./$File/$MkWinwordIndex\">$File</A>";
      $Meta{Application}="Is a directory";
    }
    else{
      $Meta{Filename}="<A HREF=\"./$File\">$File</A>";
      $Meta{Application}="not a MS-Office application";
      open(PH,"file '$Dir/$File' |") or die $!;
      while(<PH>){
        $Meta{Application}.=", is probably ".$1 if(/.*?:\s*(.*)/);
      }
      close PH;
      $Meta{"DocumentContent"}="<PRE><FONT SIZE=-1>";
      if($File =~/\.html?$/i){
        my $is='';
        open(FH,"$Dir/$File") or die $!;
        while(<FH>){
          chomp;
	  $is.="$_\n";
        }
        close FH;
        $is=HTML::FormatText->new->format(parse_html($is));
	my @is=split("\n",$is);
	$#is=10 if $#is >10;
	$Meta{"DocumentContent"}.=join("\n",@is);
      }elsif(-T "$Dir/$File"){
        my $ii=0;
        my $is='';
        open(FH,"$Dir/$File") or die $!;
        while(<FH>){
          chomp;
	  next if($ii==10);
	  $ii++;
	  $Meta{"DocumentContent"}.="$_\n";
        }
        close FH;
      }else{$Meta{"DocumentContent"}.="Glimpse on content not provided\n"}
      $Meta{"DocumentContent"}.="\n(...truncated)</FONT></PRE>";
    }
    print INDEX "<TR>";
    foreach $is (@MetaList){print INDEX"<TD>$Meta{$is}</TD>\n"}
    print INDEX"</TR>\n";
  }
}
closedir(DH);
print INDEX"</TABLE>";
print INDEX"Generated by $0 at ".scalar(localtime())."\n";
close INDEX;
