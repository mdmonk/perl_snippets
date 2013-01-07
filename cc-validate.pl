#==============================================================
# Name   : cc-valid-lib.pl  Credit Cards Validation Library
# Author : Mike Blazer      blazer@mail.nevalink.ru
# Version: 1.0              Last Modified: Mar 12, 1998  3:02:27
# Tested : on ActiveWare's Perl port, build 110; Win'95,
#           Win NT+IIS 3.0 on Perl 5.001, NSCA/1.5.2, NetBSD
#==============================================================
#
# Sorry, almost non-commented code. If you know the algorythm you'll
# understand the script too, if not - just use it.
# I know, I know - lots of them, but I'm a bit tired of using 10-20KB
# scripts doing nothing. :)
#
# This script validates Visa, Mastercard, American Express and Discover
# cards, year 2000 proof.
#
# Usage: ($code, $message, $rest) = cc_validate($number, $exp_date);
#   $code     - return code, 0 if OK.
#   $message  - eR-R-Ror message or one of the AmEx, VISA, MasterCard,
#		Discover (if $code == 0). So we are not checking what
#		the user typed in the 'Type of Card' field.
#   $rest     - how long this card will be alive. This is an important one
#		because on the May 31 you'll have not enough time to charge
#		card that expires 0598, and may be even 5 days will be
#		not enough. Or if you know that processing the order
#		will take 2-3 weeks and you don't want to charge before
#		actual shipping... Well, lots of cases.
#		$rest is in form nnx, nn- 1-2 digits, x - d(days)
#		or m(months). 11m - means 11 months etc.
#		You can check it later in your prog. $rest is valuable
#		if $code==0 only.
#   $number   - CC number with all [ \-] garbage or without
#   $exp_date - expiration date in any of these formats:
#		mmyy, mm.yy, mm-yy, mm yy, mm/yy, mm,yy (mm - exp.month,
#		one or two digits; yy - exp.year, two or four digits);
#		yyyymm, yyyy.mm, yyyy-mm, yyyy/mm, yyyy mm, yyyy,mm
#		or even
#		Aug 98, August/1998, 1998-Sep, 98/March, 1998.May,
#		May98, September1998, June 1998, june,98, 1998,May
#		- almost any human-readable form (case insensitive).
#		Additional blanks are OK in any place.
# !! Note that yy.mm and other yymm formats are not allowed be cause they
# are undistinguishable from mmyy. Any xx.xx mean mm.yy
#
# You can switch off expiration date checking by issuing 
#   $cc_valid::check_exp = 'no';
# somewhere after 'require "cc-valid-lib.pl"' but before
# using &cc_validate()
#
# Few "commercial" details: I did not want to hardcode that AmEx has to
# start with '37' or '34' because things are changing fast. There already
# is some "Amoco Oil Company MultiCard" that works like AmEx and starts
# with '3047'. For the same reason '601100' for Novus/Discover is not
# hardcoded too. If you want to check this, do it yourself, it's easy.
#
# Credits: MPI Development Labs guys for incredible CreditMaster 4.0!

$cc_valid::check_exp = 'yes';

sub cc_validate {
  my ($num, $exp, $sum, $n, $c, $r) = (shift, shift);
  my @d = split//,($num=~s/[ \-]//g,$num)[1];$n = @d;

  if ($num=~/\D/) { return 1, cc_err(1) }

  if ($d[0]!~/^[3456]/) { return 2, cc_err(2) }

  if (($d[0]==3 && $n!=15) || ($d[0]==4 && $n!=16 && $n!=13) ||
      (($d[0]==5 || $d[0]==6) && $n!=16)) { return 3, cc_err(3) }

  $n=$n==16?1:0; $sum=$d[$#d];
  map $sum+=$n++%2?2*$_-($_>4?9:0):$_,@d[0..$#d-1];

#  ($sum%10)?(4, cc_err(4)):(0, (qw(AmEx VISA MasterCard Discover))[$d[0]-3])
  if ($sum%10) { return 4, cc_err(4) }

  if ($cc_valid::check_exp eq 'yes') {
     ($c,$r) = cc_expire($exp);
     if ($c==1)   { return 5, cc_err(5) }
     if ($c==2)   { return 6, cc_err(6) }
  }
  (0, (qw(AmEx VISA MasterCard Discover))[$d[0]-3], $r);
}

sub cc_err {
('',"Non-numeric values.",
"Card must start with a 3 (AmEx), 4 (VISA), 5 (MasterCard), or 6 (Discover).",
"Invalid number of digits in card.",
"Card does not fit any known algorithm.",
"Bad formatted expiration date.",
"Expired Card.")[shift]
}

sub cc_expire {
  my ($e, $i, $m, $y) = shift;
  my @m  = ('January','February','March','April','May','June','July',
	    'August','September','October','November','December');
  my %lm = map {uc($_),++$i} @m; $i=0;
  my %sm = map {uc(substr($_,0,3)),++$i} @m;
  # current
  my @m_days = qw(31 28 31 30 31 30 31 31 30 31 30 31);
  my ($mday,$mon,$year) =(localtime(time))[3..5]; $year+=1900;
  if ($year%4 == 0 && $year%100 > 0){ $m_days[1]=29 }

  $e =~ s/[ ,\-\.\/]//g;

  if (($y,$m)=$e=~/^((?:19|20)\d\d)(\d\d?)$/) {
  } elsif (($m,$y)=$e=~/^(\d\d?)((?:19|20)?\d\d)$/){
  } elsif (($m,$y)=$e=~/^([a-z]+)((?:19|20)?\d\d)$/i){
  } elsif (($y,$m)=$e=~/^((?:19|20)?\d\d)([a-z]+)$/i){
  } else { return 1 }

  $y = substr($y,-2); $y += $y<95?2000:1900;
  if ($m !~/\d/) { $m = $lm{uc $m} || $sm{uc $m} }
  if (!$m--) { return 1 }

  if (($i=$y-$year)<0)		    { return 2 }
  elsif ($i>0)			    { return 0, (12*$i-$mon+$m).'m'}
  elsif (($i=$m-$mon)<0)	    { return 2 }
  elsif ($i>0)			    { return 0, "${i}m"}
  elsif (($i=$m_days[$m]-$mday)==0) { return 2 }
  else				    { return 0, "${i}d"}

}

1;
