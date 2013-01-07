#!/usr/bin/perl -w
#
#   smtm --- A global stock ticker for X11 and Windoze
#
#   Copyright (C) 1999 - 2003  Dirk Eddelbuettel <edd@debian.org>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

#   $Id: smtm.pl,v 1.95 2003/01/07 03:46:54 edd Exp $

use strict;			# be careful out there, my friend
use English;			# explicit variable names
use Date::Manip;		# for date calculations
use File::Spec;			# portable filename operations
use Finance::YahooQuote;	# fetch quotes from Yahoo!
use Getopt::Long;		# parse command-line arguments
use HTTP::Request::Common;	# still needed to get charts
use IO::File;			# needed for new_tmpfile or Tk complains
use POSIX qw(strftime tmpnam);	# strftime and tmpnam functions
use Text::ParseWords;		# parse .csv files more reliably
use Tk;				# who needs gates in a world full o'windows?
use Tk::Balloon;		# widget for context-sensitive help
use Tk::FileSelect;		# widget for selecting files
use vars qw{%options %chart};	# need to define here for SUB {} below

my				# seperate for Makefile.PL
$VERSION = "1.5.2";		# updated from the debian/rules Makefile
my $date =			# inner expression updated by RCS
  sprintf("%s", q$Date: 2003/01/07 03:46:54 $ =~ /\w*: (\d*\/\d*\/\d*)/);

my (@Labels,			# labels which carry the stock info
    @Buttons,			# buttons which contain the labels, 
    $BFrame,			# frame containing the buttons
    $BFont,			# font used for display on buttons + details
    $Header,			# frame for column headings
    $headertext,		# string for column headings display
    %coldisp,			# hash of selected columns
    %Dat);			# hash of hashes and lists for global data

my $Main = new MainWindow;	# create main window

if ($OSNAME =~ m/MSWin32/) {	# branch out for OS 
  $Main->setPalette("gray95");	# light gray background
  $BFont = $Main->fontCreate(-family => 'courier', -size => 8);
  $ENV{HOME} = "C:/TEMP" unless $ENV{HOME};
  $ENV{TZ} = "GMT" unless $ENV{TZ}; # Date::Time needs timezone info
} else {
#  $BFont = $Main->fontCreate(-family => 'lucidasanstypewriter', -size => 10);
  $BFont = $Main->fontCreate(-family => 'fixed', -size => 10);
#  $BFont = $Main->fontCreate(-family => 'courier', -size => 10);
}

# general options for user interface and behaviour, sort-of ugly global
$options{file} = File::Spec->catfile($ENV{HOME}, ".smtmrc");  # default rc file
$options{sort} = 'n';		# sort by name
$options{timeout} = 180;	# default timeout used in LWP code
$options{columns} = 'nrla';	# default colums: name, last, rel.chg, abs. chg
$options{percent} = 0;		# default to percentage display, not bps
$options{delay} = 5;		# wait this many minutes
($options{firewall}, $options{proxy}, $options{wide}) = (undef,undef,undef);

# global hash for chart options
$chart{length} = '1';		# one-year chart is default chart
$chart{log_scale} = 1;		# plot on logarithmic scale
$chart{volume} = 1;		# show volume on seperate pane
$chart{size} = 'm';		# plot size, default small  (m medium, l large)
$chart{style} = 'l';		# plot type, line ('c' candle, 'b' for bar)
$chart{ma} = ();		# placeholder hash for mov.avg. options
$chart{ema} = ();		# placeholder hash for exp.mov.avg. options
$chart{technical} = ();		# placeholder hash for tech. analysis options
$chart{bollinger} = 0;		# show bollinger bands
$chart{parabolic_sar} = 0;	# show parabolic sar
$chart{comparison} = "";	# compare to this symbol (eg stock)

my $today = ParseDate("today");	# current time and date for return calculations
my $symbolcounter = 0;		# needed for several pos. in same stock

my %commandline_options = ("file=s"    => \$options{file}, 
			   "time=i"    => \$options{delay}, 
			   "fwall:s"   => \$options{firewall}, 
			   "proxy=s"   => \$options{proxy},
			   "wide"      => \$options{wide},
			   "percent"   => \$options{percent},
			   "columns=s" => \$options{columns},
			   "sort=s"    => \$options{sort},
			   "nookbutton"=> \$options{nookbutton},
			   "timeout=i" => \$options{timeout},
			   "chart=s"   => \$chart{length},
			   "gallery"   => \$options{gallery},
			   "verbose"   => \$options{verbose},
			   "help"      => \$options{help});
# exit with helpful message if unknown command-line option, or help request
help_exit() if (!GetOptions(%commandline_options) or $options{help});

if ($#ARGV==-1) {		# if no argument given
  if (-f $options{file}) {	#    if file exists
    read_config();		#       load from file
    init_data(undef);		#       this indirectly calls buttons()
  } else {			#    else use default penguin portfolio
    warn("No arguments given, and no file found. Using example portfolio.\n");
    init_data(("RY.TO::50::48:20000104",
	       "C::50:USDCAD:50.50:20000103",
	       "DBKGn.DE::50:EURCAD:86.5:20010102",
	       "HSBA.L::50:GBPCAD:967.02:20010101"))
  }
} else {			# else 
  init_data(@ARGV);		#    use the given arguments
}
MainLoop;			# and launch event loop under X11

#----- Functions ------------------------------------------------------------

sub menus {			# create the menus

  # copy selected colums from string into hash
  for my $i (0..length($options{columns})-1) {
    $coldisp{substr($options{columns}, $i, 1)} = 1;
  }

  $Main->optionAdd("*tearOff", "false");
  my $MF = $Main->Frame()->pack(-side => 'top', 
				-anchor => 'n', 
				-expand => 1, 
				-fill => 'x');
  my @M;
  $M[0] = $MF->Menubutton(-text => 'File', -underline => 0,
			 )->pack(-side => 'left');
  $M[0]->AddItems(["command" => "~Open",   -command => \&select_file_and_open],
		  ["command" => "~Save",   -command => \&file_save],
		  ["command" => "Save ~As",-command => \&select_file_and_save],
		  ["command" => "E~xit",   -command => sub { exit }]);

  $M[1] = $MF->Menubutton(-text => 'Edit', -underline => 0,
			 )->pack(-side => 'left');
  $M[1]->AddItems(["command" => "~Add Stock",       -command => \&add_stock]);
  $M[1]->AddItems(["command" => "~Delete Stock(s)", -command => \&del_stock]);
  my $CasX = $M[1]->cascade(-label => '~Columns');
  my %colbutton_text = ('s' => '~Symbol',
			'n' => '~Name',
			'l' => '~Last Price',
			'a' => '~Absolute Change',
			'r' => '~Relative Change',
			'V' => '~Volume traded',
			'p' => 'Position ~Change',
			'v' => '~Position Value',
			'h' => '~Holding Period',
			'R' => 'Annual Re~turn',
		        'd' => '~Drawdown',
			'e' => '~Earnings per Share',
			'P' => 'P~rice Earnings Ratio',
			'D' => 'Di~vidend Yield',
			'm' => '~Market Captialization',
			'f' => '~FilePosition'
		       );
  foreach (qw/s n l a  r V p v h R d e P D m f/) {
    $CasX->checkbutton(-label => $colbutton_text{$ARG},
		       -variable => \$coldisp{$ARG},
		       -command => \&update_display);
  }
  my $CasS = $M[1]->cascade(-label => '~Sort');
  my %sortbutton_text = ('n' => '~Name',
			 'r' => '~Relative Change',
			 'a' => '~Absolute Change',
			 'p' => 'Position ~Change',
			 'v' => '~Position Value',
			 'V' => '~Volume Traded',
			 'h' => '~Holding Period',
			 'R' => 'Annual Re~turn',
			 'd' => '~Drawdown',
			 'e' => '~Earnings per Share',
			 'P' => 'P~rice Earnings Ratio',
			 'D' => 'Di~vidend Yield',
			 'm' => '~Market Captialization',
			 'f' => '~FilePosition');
  foreach (qw/n r a p v V h R d e P D m f/) {
    $CasS->radiobutton(-label => $sortbutton_text{$ARG},
		       -command => \&update_display,
		       -variable => \$options{sort},
		       -value => $ARG);
  }
  $M[1]->AddItems(["command" => "Change ~Update Delay", 
		   -command => \&chg_delay]);
  $M[1]->AddItems(["command" => "Update ~Now", 
		   -command => \&update_display_variables]);
  $M[1]->checkbutton(-label => "~Wide window title",
		     -variable => \$options{wide},
		     -command =>  \&update_display);
  $M[1]->checkbutton(-label => "~Percent instead of bps",
		     -variable => \$options{percent},
		     -command =>  \&update_display);

  $M[2] = $MF->Menubutton(-text => 'Charts', -underline => 0,
			 )->pack(-side => 'left');
  my $CasC = $M[2]->cascade(-label => "~Timeframe");
  my %radiobutton_text = ('b'  => '~Intraday',
			  'w'  => '~Weekly',
			  '3' => '~Three months',
			  '6' => '~Six months',
			  '1' => '~One year',
			  '2' => 'Two ~years',
			  '5' => '~Five years',
			  'm' => '~Max years');
  foreach (qw/b w 3 6 1 2 5 m/) {
    $CasC->radiobutton(-label => $radiobutton_text{$ARG},
		       -variable => \$chart{length}, -value => $ARG);
  }
  my $CasPS = $M[2]->cascade(-label => "Plot ~Size");
  my %radiobutton_ps = ('s'  => '~Small',
			'm'  => '~Medium',
			'l'  => '~Large');
  foreach (qw/s m l/) {
    $CasPS->radiobutton(-label => $radiobutton_ps{$ARG},
			-variable => \$chart{size}, -value => $ARG);
  }
  my $CasPT = $M[2]->cascade(-label => "Plot T~ype");
  my %radiobutton_pt = ('l'  => '~Line chart',
 			'b'  => '~Bar chart',
 			'c'  => '~Candle chart');
  foreach (qw/l b c/) {
    $CasPT->radiobutton(-label => $radiobutton_pt{$ARG},
 			-variable => \$chart{style}, -value => $ARG);
  }
  my $CasMA = $M[2]->cascade(-label => '~Moving Averages');
  my %mabutton_text = ('5'   => '5 days',
		       '10'  => '10 days',
		       '20'  => '20 days',
		       '50'  => '50 days',
		       '100' => '100 days',
		       '200' => '200 days');
  foreach (qw/5 10 20 50 100 200/) {
    $CasMA->checkbutton(-label => $mabutton_text{$ARG},
		        -variable => \$chart{ma}{$ARG});
  }
  my $CasEMA = $M[2]->cascade(-label => '~Exp. Moving Avg.');
  foreach (qw/5 10 20 50 100 200/) {
    $CasEMA->checkbutton(-label => $mabutton_text{$ARG},
			 -variable => \$chart{ema}{$ARG});
  }
  my $CasTA = $M[2]->cascade(-label => 'Te~chnical Analysis');
  # see http://help.yahoo.com/help/us/fin/chart/chart-12.html
  my %ta_text = ('m26-12-9'   => 'MACD (MA Conv./Divergence)', 
		 'f14'        => 'MFI (Money Flow)',
		 'p12'        => 'ROC (Rate of Change)',
		 'r14'        => 'RSI (Relative Strength Index)',
		 'ss'         => 'Stochastic (slow)',
		 'fs'         => 'Stochastic (fast)',
		 'w14'        => 'Williams %R');
  foreach (sort {$ta_text{$a} cmp $ta_text{$b}} keys %ta_text) {
    $CasTA->checkbutton(-label => $ta_text{$ARG},
		        -variable => \$chart{technical}{$ARG});
  }
  $M[2]->checkbutton(-label => "~Logarithmic scale", 
		     -variable => \$chart{log_scale});
  $M[2]->checkbutton(-label => "~Volume and its MA", 
		     -variable => \$chart{volume});
  $M[2]->checkbutton(-label => "~Bollinger Bands", 
		     -variable => \$chart{bollinger});
  $M[2]->checkbutton(-label => "~Parabolic SAR", 
		     -variable => \$chart{parabolic_sar});
  $M[2]->AddItems(["command" => "Enter ~Comparison Symbol(s)", 
		   -command => \&get_comparison_symbol]);
  $M[2]->AddItems(["command" => "Chart ~Gallery", 
		   -command => \&show_gallery]);

  $M[3] = $MF->Menubutton(-text => 'Help', -underline => 0,
			 )->pack(-side => 'right');
  $M[3]->AddItems(["command" => "~Manual",  -command => \&help_about]);
  $M[3]->AddItems(["command" => "~License", -command => \&help_license]);

  $Main->configure(-title => "smtm"); # this will be overridden later
  $Main->iconname("smtm");	
}

sub buttons {			# create all display buttons

  @{$Dat{NA}} = sort @{$Dat{Arg}};
  $BFrame->destroy() if Tk::Exists($BFrame);
  $BFrame = $Main->Frame()->pack(-side=>'top',
				 -fill=>'x');
  $BFrame->Label->repeat($options{delay}*1000*60, \&update_display_variables);
  my $balloon = $BFrame->Balloon();

  $Header = $BFrame->Label(-anchor => 'w',
 			   -font => $BFont,
			   -borderwidth => 3,
 			   -relief => 'groove',
 			   -textvariable => \$headertext,
			  )->pack(-side => 'top', -fill => 'x');

  foreach (0..$#{$Dat{Arg}}) {		 # set up the buttons
    $Buttons[$ARG]->destroy() if Tk::Exists($Buttons[$ARG]);
    $Buttons[$ARG] = $BFrame->Button(-command => [\&show_details, $ARG],
				     -font => $BFont,
				     -relief => 'flat',
				     -borderwidth => -4,
				     -textvariable => \$Labels[$ARG]
				    )->pack(-side => 'top', 
					    -fill => 'x');
    $Buttons[$ARG]->bind("<Button-2>", [\&edit_stock, $ARG]);
    $Buttons[$ARG]->bind("<Button-3>", [\&view_image, $ARG]);
    $balloon->attach($Buttons[$ARG], 
		     -balloonmsg => "Mouse-1 for details, " .
		     		    "Mouse-2 to edit, ".
		                    "Mouse-3 for chart");
  }

  # are we dealing with firewalls, and do we need to get the info ?
  if (defined($options{firewall}) and 
      ($options{firewall} eq "" or $options{firewall} !~ m/.*:.*/)) {
    get_firewall_id();		# need to get firewall account + password
  } else {			
    update_display_variables();	# else populate those buttons
  }
}

sub sort_func {			# sort shares for display
  my @a = split /;/, $a;
  my @b = split /;/, $b;

  if ($options{sort} eq 'r') {	# do we sort by returns (relative change)
    my $achg = $Dat{Bps}{$a[0]} || 0;
    my $bchg = $Dat{Bps}{$b[0]} || 0;
    if (defined($achg) and defined($bchg)) {
      return $bchg <=> $achg 	# apply descending (!!) numerical comparison
      || $a[1] cmp $b[1]	# with textual sort on names to break ties
    } else {
      return $a[1] cmp $b[1];	# or default to textual sort on names
    }
  } elsif ($options{sort} eq 'a') {	# do we sort by absolute change
    return $b[5] <=> $a[5]
      || $a[1] cmp $b[1]	# or default to textual sort on names
  } elsif ($options{sort} eq 'p') {	# do we sort by profit/loss amount 
    return $Dat{PLContr}{$b[0]} <=> $Dat{PLContr}{$a[0]}
      || $a[1] cmp $b[1]	# or default to textual sort on names
  } elsif ($options{sort} eq 'v') {	# do we sort by profit/loss amount 
    return $Dat{Value}{$b[0]} <=> $Dat{Value}{$a[0]}
      || $a[1] cmp $b[1]	# or default to textual sort on names
  } elsif ($options{sort} eq 'V') {	# do we sort by volume traded
    return $b[7] <=> $a[7]
      || $a[1] cmp $b[1]	# or default to textual sort on names
  } elsif ($options{sort} eq 'h') {	# do we sort by days held
    return $Dat{DaysHeld}{$b[0]} <=> $Dat{DaysHeld}{$a[0]}
      || $a[1] cmp $b[1]	# or default to textual sort on names
  } elsif ($options{sort} eq 'R') {	# do we sort by annual return
    return $Dat{Return}{$b[0]} <=> $Dat{Return}{$a[0]}
      || $a[1] cmp $b[1]	# or default to textual sort on names
  } elsif ($options{sort} eq 'd') {	# sort by drawdown
    my $a = defined($Dat{Drawdown}{$a[0]}) ? $Dat{Drawdown}{$a[0]} : 0;
    my $b = defined($Dat{Drawdown}{$b[0]}) ? $Dat{Drawdown}{$b[0]} : 0;
    return $b <=> $a || $a[1] cmp $b[1]	# or default to textual sort on names
  } elsif ($options{sort} eq 'e') {
    return $Dat{EPS}{$b[0]} <=> $Dat{EPS}{$a[0]}
      || $a[1] cmp $b[1]	# or default to textual sort on names
  } elsif ($options{sort} eq 'P') {
    return $Dat{PE}{$b[0]} <=> $Dat{PE}{$a[0]}
      || $a[1] cmp $b[1]	# or default to textual sort on names
  } elsif ($options{sort} eq 'D') {
    return $Dat{DivYield}{$b[0]} <=> $Dat{DivYield}{$a[0]}
      || $a[1] cmp $b[1]	# or default to textual sort on names
  } elsif ($options{sort} eq 'm') {
    my $a = $Dat{MarketCap}{$a[0]} ne "N/A" ? $Dat{MarketCap}{$a[0]} : 0;
    my $b = $Dat{MarketCap}{$b[0]} ne "N/A" ? $Dat{MarketCap}{$b[0]} : 0;
    return $b <=> $a || $a[1] cmp $b[1]	# or default to textual sort on names
  } elsif ($options{sort} eq 'f') {	# ordered by file position
    return $Dat{ID}{$a[0]} <=> $Dat{ID}{$b[0]}
  } else {			# alphabetical sort
    return $a[1] cmp $b[1];
  }

}

sub update_display_variables {  # gather data, and update display strings
  update_data();		# fetch the data from the public servers
  compute_positions();		# update position hashes
  update_display();		# and update the ticker display
}

sub update_data {		# gather data from Yahoo! servers

  $today = ParseDate("today");	# current time and date for return calculations

  if ($#{@{$Dat{FXarr}}}>-1) {# if there are cross-currencies
    my $array = getquote(@{$Dat{FXarr}});	# get FX crosses
    foreach my $ra (@$array) {	
      next unless $ra->[0];
      $ra->[0] =~ s/\=X//;	# reduce back to pure cross symbol
      $Dat{FX}{uc $ra->[0]} = $ra->[2]; # and store value in FX hash
    } 
  }
  undef $Dat{Data};

  # NA: name,symbol,price,last date (m/d/y),time,change,percent,volume,avg vol,
  #     bid, ask, previous,open,day range,52 week range,eps,p/e,div,divyld, cap
  if ($#{@{$Dat{NA}}}>-1) {	# if there are stocks for Yahoo! North America
    fill_with_dummies(@{$Dat{NA}});
    ## call just as the symbol, i.e. without the number key past ':'
    my @syms = map { (split(/:/, $ARG))[0]} @{$Dat{NA}};
    my $array = getquote(@syms);	# get North American quotes
    my $i=0;
    foreach my $ra (@$array) {
      $ra->[0] = @{$Dat{NA}}[$i++]; # store with supplied symbol + key
      $Dat{Data}{uc $ra->[0]} = join(";", @$ra); # store all info
    } 
  }
} 

# As getquote() may return empty, we have to intialize the %Dat hash 
# so that later queries don't hit a void
sub fill_with_dummies {
  my (@arr) = @_;
  foreach $ARG (@arr) {
    $Dat{Data}{uc $ARG} = join(";", (uc $ARG, "-- N/A --", 
				       0, "1/1/1970", "00:00", 0, "0.00%", 
				       0, "-", "-", "-", "-", "-",
				       "-", "-", "-", "-", "-", "-", "-"));
  }
}

# Use the name supplied from Yahoo!, unless there is a user-supplied 
# GivenName in the rc file. In case we have data problems, return N/A
sub get_pretty_name {
  my ($pretty, $default) = @_;
  if (not defined($pretty) or $pretty eq "" or $default eq "-- N/A --") {
      return $default;
  } else {
      return $pretty;
  }
}

sub compute_positions {

  undef %{$Dat{Price}};
  undef %{$Dat{Change}};
  undef %{$Dat{Bps}};
  undef %{$Dat{PLContr}};
  undef %{$Dat{Value}};
  undef %{$Dat{Volume}};
  undef %{$Dat{Return}};
  undef %{$Dat{DaysHeld}};

  # We have to loop through once to compute all column entries, and to store
  # them so that we can find the largest each to compute optimal col. width
  foreach (values %{$Dat{Data}}) {
    my @arr = split (';', $ARG);
    my $symbol = uc $arr[0];
    $Dat{Name}{$symbol} = $arr[1] || "-- No connection";
    $Dat{Price}{$symbol} = $arr[2] || 0;
    $Dat{Change}{$symbol} = $arr[5] || 0;
    $Dat{Change}{$symbol} = 0 if $Dat{Change}{$symbol} eq "N/A";
    my $pc = $arr[6] || "0.00%";
    $pc  =~ s/\%//;	# extract percent change
    $pc = 0 if $pc eq "N/A";
    my $fx = $Dat{FX}{ $Dat{Cross}{$symbol} } || 1;
    my $shares = $Dat{Shares}{$symbol} || 0;
    $Dat{Bps}{$symbol} = 100*$pc * ($shares < 0 ? -1 : 1);
    my $plcontr =  $shares *  $Dat{Change}{$symbol} * $fx;
    $Dat{PLContr}{$symbol} = $plcontr;
    my $value = $Dat{Shares}{$symbol} * $Dat{Price}{$symbol} * $fx;
    $Dat{Value}{$symbol} = $value;
    $Dat{Volume}{$symbol} = $arr[7] || 0;
    ($Dat{YearLow}{$symbol}, $Dat{YearHigh}{$symbol}) = (undef, undef);
    ($Dat{YearLow}{$symbol}, $Dat{YearHigh}{$symbol}) = split / - /, $arr[14];
    if (defined($Dat{YearHigh}{$symbol})
	and $Dat{YearHigh}{$symbol} ne "N/A"
	and $Dat{YearHigh}{$symbol} != 0) {
      $Dat{Drawdown}{$symbol} 
	= 100.0*($Dat{Price}{$symbol}/$Dat{YearHigh}{$symbol}-1.0);
    } else {
      $Dat{Drawdown}{$symbol} = undef;
    }
    if ($Dat{PurchPrice}{$symbol} and $Dat{PurchDate}{$symbol}) {
      $Dat{DaysHeld}{$symbol} =
	Delta_Format(DateCalc($Dat{PurchDate}{$symbol},
			      $today, undef, 2), 0, "%dt");
      $Dat{Return}{$symbol} = ($Dat{Price}{$symbol} /
				 $Dat{PurchPrice}{$symbol} - 1) * 100
				 * 365 / $Dat{DaysHeld}{$symbol}
				   * ($shares < 0 ? -1 : 1);
    } else {
      $Dat{DaysHeld}{$symbol} = undef;
      $Dat{Return}{$symbol} = undef;
    }
    $Dat{EPS}{$symbol} = $arr[15] || 0;
    $Dat{PE}{$symbol} = $arr[16] || 0;
    $Dat{DivYield}{$symbol} = $arr[18] || 0;
    $Dat{MarketCap}{$symbol} = $arr[19] || 0;
    foreach ("EPS","PE", "DivYield") {
      $Dat{$ARG}{$symbol} = 0 if $Dat{$ARG}{$symbol} eq "N/A";
    }
  }
}

sub update_display {
  my $pl = 0;			# profit/loss counter
  my $nw = 0;			# networth counter
  my $shares = 0;		# net shares positions

  my $max_sym = 0;
  foreach my $key (keys %{$Dat{Symbol}}) {
    $max_sym = length($key) if (length($key) > $max_sym);
  }

  my $max_len = 0;
  foreach my $key (keys %{$Dat{Name}}) {
    my $txt = get_pretty_name($Dat{GivenName}{$key}, $Dat{Name}{$key})
	|| "-- No connection";
    $txt =~ s/\s*$//;		# eat trailing white space, if any
    my $len = length($txt) > 16 ? 16 : length($txt);
    $max_len =  $len if ($len > $max_len);
  }

  my $max_price = 0;
  foreach my $val (values %{$Dat{Price}}) {
    $max_price = $val if ($val > $max_price);
  }

  my $max_change = 0.01;	# can't take log of zero below
  my $min_change = 0.01;
  foreach my $val (values %{$Dat{Change}}) {
    $max_change = $val if ($val > $max_change);
    $min_change = $val if ($val < $min_change);
  }

  my $max_bps = 1;		# can't take log of zero below
  my $min_bps = 1;
  foreach my $val (values %{$Dat{Bps}}) {
    $max_bps = $val if ($val > $max_bps);
    $min_bps = $val if ($val < $min_bps);
  }

  my $max_plc = 1;		# can't take log of zero below
  my $min_plc = 1;
  foreach my $val (values %{$Dat{PLContr}}) {
    $max_plc = $val if ($val > $max_plc);
    $min_plc = $val if ($val < $min_plc);
  }

  my $max_value = 1;		# can't take log of zero below
  foreach my $val (values %{$Dat{Value}}) {
    $max_value = $val if ($val > $max_value);
  }

  my $max_volume = 1;		# can't take log of zero below
  foreach my $val (values %{$Dat{Volume}}) {
    $max_volume = $val if (($val ne "N/A") and ($val > $max_volume));
  }

  my $max_held = 0;		# 
  foreach my $val (values %{$Dat{DaysHeld}}) {
    $max_held = $val if (defined($val) and $val > $max_held);
  }

  my $max_ret = 0;		# 
  my $min_ret = 0;		# 
  foreach my $val (values %{$Dat{Return}}) {
    $max_ret = $val if (defined($val) and $val > $max_ret);
    $min_ret = $val if (defined($val) and $val < $min_ret);
  }

  my $max_ddown = 0;
  foreach my $val (values %{$Dat{Drawdown}}) {
    $max_ddown = $val if (defined($val) and $val < $max_ddown);
  }

  my $max_eps = 0;
  my $min_eps = 0;		# 
  foreach my $val (values %{$Dat{EPS}}) {
    $max_eps = $val if (defined($val) and $val ne "-"
			and $val ne "N/A" and $val > $max_eps);
    $min_eps = $val if (defined($val) and $val ne "-"
			and $val ne "N/A" and $val < $min_eps);
  }
  my $max_pe = 0;
  foreach my $val (values %{$Dat{PE}}) {
    $max_pe = $val if (defined($val) and $val ne "-"
		       and $val ne "N/A" and $val > $max_pe);
  }
  my $max_divyld = 0;
  foreach my $val (values %{$Dat{DivYield}}) {
    $max_divyld = $val if (defined($val) and $val ne "-" and $val ne "N/A" 
			   and $val > $max_divyld);
  }
  my $max_mktcap = 0;
  foreach my $val (values %{$Dat{MarketCap}}) {
    $max_mktcap = $val if (defined($val) and $val ne "N/A" and $val ne "-"
			   and $val > $max_mktcap);
  }

  my $max_fpos = 0;
  foreach my $val (values %{$Dat{ID}}) {
    $max_fpos = $val if (defined($val) and $val > $max_fpos);
  }

  # transform as necessary
  $max_price = 3 + digits($max_price);  # dot and two digits
  $max_change = 3 + max(digits($max_change), digits($min_change));
  $max_bps = max(3+$options{percent}, max(digits($max_bps),digits($min_bps)));
  $max_plc = max(3, max(digits($max_plc),digits($min_plc)));
  $max_value = max(3, digits($max_value));
  $max_volume = digits($max_volume);
  $max_ret = 2 + max(digits($max_ret),digits($min_ret));
  $max_held = max(3, digits($max_held));
  $max_ddown = 2 + max(2, 1+digits(-$max_ddown)); # 1 decimals,dot,minus,digitb
  $max_eps = 2 + max(digits($max_eps),digits($min_eps));
  $max_pe = 2 + digits($max_pe);
  $max_divyld = 2 + digits($max_divyld);
  $max_mktcap = 3 + digits($max_mktcap);
  $max_fpos = max(2, digits($max_fpos));

  $headertext = "";
  $headertext .= "Sym "  . " " x ($max_sym-3) if $coldisp{s};
  $headertext .= "Name " . " " x ($max_len-4) if $coldisp{n};
#  $headertext .= " ";		# transition from leftflush to rightflush
  $headertext .= " " x ($max_price-4) . "Last " if $coldisp{l};
  $headertext .= " " x ($max_change-3) . "Chg " if $coldisp{a};  
  $headertext .= " " x ($max_bps-4) . "%Chg "
    if $coldisp{r} and $options{percent};
  $headertext .= " " x ($max_bps-3) . "Bps "
    if $coldisp{r} and not $options{percent};
  $headertext .= " " x ($max_volume-3) . "Vol " if $coldisp{V};
  $headertext .= " " x ($max_plc-3) . "P/L " if $coldisp{p};
  $headertext .= " " x ($max_value-3) . "Net " if $coldisp{v};
  $headertext .= " " x ($max_held-3) . "Len " if $coldisp{h};
  $headertext .= " " x ($max_ret-3) . "Ret " if $coldisp{R};
  $headertext .= " " x ($max_ddown - 4) . "Ddwn " if $coldisp{d};
  $headertext .= " " x ($max_eps - 3) . "EPS " if $coldisp{e};
  $headertext .= " " x ($max_pe - 2) . "PE " if $coldisp{P};
  $headertext .= " " x ($max_divyld - 3) . "Yld " if $coldisp{D};
  $headertext .= " " x ($max_mktcap - 3) . "Cap " if $coldisp{m};
  $headertext .= "FP " if $coldisp{f};
  chop $headertext;		# get trailing ' '
  print "|$headertext|\n" if $options{verbose};

  # Now apply all that information to the display
  my $i = 0;
  foreach (sort sort_func values %{$Dat{Data}}) {
    my @arr = split (';', $ARG);
    my $symbol = uc $arr[0];
    my $name = get_pretty_name($Dat{GivenName}{$symbol}, 
			       $Dat{Name}{$symbol}) || "-- No connection";
    if (not defined $Dat{Bps}{$symbol}) {
      $Buttons[$i]->configure(-foreground => 'white',
 			      -activeforeground => 'white');
   } elsif ($Dat{Bps}{$symbol} < 0) { # if we're losing money on this one
      $Buttons[$i]->configure(-foreground => 'red', 
			      -activeforeground => 'red');
    } else {
      $Buttons[$i]->configure(-foreground => 'black',
			      -activeforeground => 'black');
    }

    $Labels[$i] = "";

    $Labels[$i] .= sprintf("%*s ", -$max_sym, $Dat{Symbol}{$symbol})
      if $coldisp{s};

    $Labels[$i] .= sprintf("%*s ", -$max_len, substr($name,0,$max_len)) 
      if $coldisp{n};
    $Labels[$i] .= sprintf("%$max_price.2f ", $Dat{Price}{$symbol}) 
      if $coldisp{l};
    $Labels[$i] .= sprintf("%$max_change.2f ", $Dat{Change}{$symbol}) 
      if $coldisp{a};
    $Labels[$i] .= sprintf("%$max_bps.0f ", $Dat{Bps}{$symbol})
      if $coldisp{r} and not $options{percent};
    $Labels[$i] .= sprintf("%" . ($max_bps + 1) . ".2f ", 
			   ($Dat{Bps}{$symbol}) / 100) 
      if $coldisp{r} and $options{percent};

    $Labels[$i] .= sprintf("%$max_volume.0d ", 
			   ($Dat{Volume}{$symbol} ne "N/A" 
			    ? $Dat{Volume}{$symbol} : 0))
	if $coldisp{V};
    $Labels[$i] .= sprintf("%$max_plc.0f ", $Dat{PLContr}{$symbol})
	if $coldisp{p};
    $Labels[$i] .= sprintf("%$max_value.0f ", $Dat{Value}{$symbol})
	if $coldisp{v};
    if ($coldisp{h}) {
      if (defined($Dat{DaysHeld}{$symbol})) {
	$Labels[$i] .= sprintf("%$max_held.0f ", $Dat{DaysHeld}{$symbol});
      } else {
	$Labels[$i] .= sprintf("%*s ", $max_held, "NA");
      }
    }
    if ($coldisp{R}) {
      if (defined($Dat{Return}{$symbol})) {
	$Labels[$i] .= sprintf("%$max_ret.1f ", $Dat{Return}{$symbol});
      } else {
	$Labels[$i] .= sprintf("%*s ", $max_ret, "NA");
      }
    }
    if ($coldisp{d}) {		# drawdown
      if (defined($Dat{Drawdown}{$symbol})) {
	$Labels[$i] .= sprintf("%$max_ddown.1f ", $Dat{Drawdown}{$symbol});
      } else {
	$Labels[$i] .= sprintf("%*s ", $max_ddown, "NA");
      }
    }

    $Labels[$i] .= sprintf("%$max_eps.1f ", $Dat{EPS}{$symbol})
      if $coldisp{e};
    $Labels[$i] .= sprintf("%$max_pe.1f ", $Dat{PE}{$symbol})
      if $coldisp{P};
    $Labels[$i] .= sprintf("%$max_divyld.1f ", $Dat{DivYield}{$symbol})
      if $coldisp{D};
    if ($coldisp{m}) {
      if ($Dat{MarketCap}{$symbol} ne "N/A") {
	$Labels[$i] .= sprintf("%$max_mktcap.2f ", $Dat{MarketCap}{$symbol})
      } else {
	$Labels[$i] .= sprintf("%*s ", $max_mktcap, "NA");
      }
    }

    $Labels[$i] .= sprintf("%$max_fpos.0f ", $Dat{ID}{$symbol})
       if $coldisp{f};

    chop $Labels[$i];
    print "|$Labels[$i]|\n" if $options{verbose};
    $nw += $Dat{Value}{$symbol};
    $pl += $Dat{PLContr}{$symbol};
    $Dat{Map}[$i++] = $symbol;
  }

  my $bps = $nw - $pl != 0 ? 100*100*($pl/($nw-$pl)) : 0; 
  my $txt = ($options{percent} ?
             sprintf("%.2f%%", $bps / 100) : sprintf("%.0f Bps", $bps))
    . " at " . POSIX::strftime("%H:%M", localtime);
  $txt = $txt . sprintf(" p/l %.0f net %.0f", $pl, $nw) if ($options{wide});
  $Main->configure(-title => $txt);
  $Main->iconname($txt);	# also set the icon name
}

sub digits {			# calculate nb of digits sprintf will need
  my $x = shift;

  # rounded(log10(0.5) gives 0 even though this has 1 leading decimal
  $x *= 10 if (abs($x) > 0 and abs($x) < 1); 
  $x *= 10 if ($x<0);		# add one for minus sign
  $x = abs($x) if ($x < 0);	# need absolute value of neg. values
  if ($x != 0) {
    return int(log($x)/log(10)+1);# this gives the rounded log10 of x
  } else {
    return 1;
  }
}

sub max {
  my ($a,$b) = @_;
  $a > $b ? return $a : $b;
}

sub show_details {		# display per-share details
  my $key = shift;
  my $TL = $Main->Toplevel;	# new toplevel widget ...
  my $Text = $TL->Text(-height => 26, 
		       -width => 39,
		       -font => $BFont,
		      )->pack();
  my @arr = split (';', $Dat{Data}{ $Dat{Map}[$key]  });
  my $symbol = $arr[0];
  $arr[0] = $Dat{Symbol}{$arr[0]};
  $arr[1] = substr(get_pretty_name($Dat{GivenName}{$symbol}, 
				   $Dat{Name}{$symbol}) || "-- No connection",
				   0, 22);
  $TL->title("Details for $arr[1]");
  my @text = ("Symbol", "Name", "Price", "Date", "Time", "Change",
	      "Percent. Change", "Volume", "Average Volume", 
	      "Bid", "Ask", "Previous", "Open", "Day Range",
	      "52 Week Range", "Earnings/Share", "Price/Earnings", "Dividend",
	      "Dividend Yield", "Market Capital");
  foreach (0..$#text) {
    $Text->insert('end',  sprintf("%-16s %s\n", $text[$ARG], $arr[$ARG]));
  }
  my $fx = $Dat{FX}{ $Dat{Cross}{$symbol} } || 1;
  my $shares = $Dat{Shares}{$symbol} || 0;
  $Text->insert('end',  
		sprintf("%-16s %d\n%-16s %.2f\n%-16s %.2f\n",
			"Shares Held", $shares,
			"Value Change", $shares * $Dat{Change}{$symbol} * $fx,
			"Total Value", $shares * $Dat{Price}{$symbol} * $fx));
  $Text->insert('end', sprintf("%-16s %s\n", "Days Held",
		defined($Dat{DaysHeld}{$symbol}) ? 
		sprintf("%d years and %d days",
 			$Dat{DaysHeld}{$symbol}/365,
			$Dat{DaysHeld}{$symbol} % 365)  : "NA"));
  $Text->insert('end', sprintf("%-16s %s\n", "Purchase Price",
		$Dat{PurchPrice}{$symbol} ? 
		sprintf("%.2f",$Dat{PurchPrice}{$symbol}) : "NA"));
  $Text->insert('end', sprintf("%-16s %s\n", "Annual. Return", 
		defined($Dat{Return}{$symbol}) ?
		sprintf("%.2f%%", $Dat{Return}{$symbol}) : "NA"));
  button_or_mouseclick_close($TL,$Text);
}

sub button_or_mouseclick_close {
  my ($A,$B) = @_;
  if ($options{nookbutton}) {
    $B->bind("<Button-1>", sub { $A->destroy}); # also close on Button-1
  } else {
    $A->Button(-text => 'Ok',
	       -command => sub { $A->destroy(); } )->pack(-side => 'bottom');
  }
}

sub view_image {
  my ($widget,$arg) = @_;
  my @arr = split (';', $Dat{Data}{ $Dat{Map}[$arg]  });

  my $url = charturl(lc( $Dat{Symbol}{$arr[0]} ));
  my $ua = RequestAgent->new;	
  $ua->env_proxy;
  $ua->proxy('http', $options{proxy}) if $options{proxy};
  $ua->timeout($options{timeout});	# time out after this many secs
  my $resp = $ua->request(GET $url);
  if ($resp->is_error) {		# error in retrieving the chart;
    my $TL = $Main->Toplevel;		# most likely 404 (not found);
    $TL->title ("Error");		# Yahoo returns HTML, not a NULL,
    my $Text = $TL->Label(-padx =>5,	# so need to check return code
		-pady =>5,
		-text =>"The chart for $arr[1] is not available.")->pack;
    button_or_mouseclick_close($TL,$Text);
  } else {
    my $tmpnam = POSIX::tmpnam();  
    open FILE, "> $tmpnam";
    binmode FILE;;
    print FILE $resp->content;
    close FILE;
    my $TL = $Main->Toplevel;		# new toplevel widget ...
    $TL->title ("Graph for $arr[1]");
    my $PH = $TL->Photo(-file => $tmpnam);
    my $LB = $TL->Label(-image => $PH)->pack();
    unlink($tmpnam);
    button_or_mouseclick_close($TL,$LB);
  }
}

sub charturl {			# initially (almost) verbatim from Dj's 
  my $symbol = shift;		# YahooChart, now completely rewritten 
  my $url;			# and very significantly extended

  my $len = $chart{length};
  if ($len =~ m/(b|w)/o) {	# if 'b' or 'w' for intra-day or 5 day
    $len = 'b' if $len eq 'i';	# intraday chart uses Yahoo! code 'b'
    $url = "http://ichart.yahoo.com/$len?s=$symbol";
  } else {			# everything else, ie three month onwards
    $len .= 'y' if $len=~ m/(1|2|5|m)/o;# code for year is '1y' ... 'my'
    $len .= 'm' if $len =~ m/(3|6)/o;	# code for month is '3m' or '6m'
    my $params = "s";			# always set splits
    foreach (keys %{$chart{ma}}) {	# for all possible moving avg options
      $params .= ",m$ARG" if $chart{ma}{$ARG};
    }
    foreach (keys %{$chart{ema}}){	# for all possible exp. mov avg options
      $params .= ",e$ARG" if $chart{ema}{$ARG};
    }
    $params .= ",b" if $chart{bollinger};	# maybe set Bollinger Bands
    $params .= ",p" if $chart{parabolic_sar}; 	# maybe set Parabolic SAR
    my $log = $chart{log_scale} ? "on" : "off"; # maybe switch to log scale
    my $pane = $chart{volume} ? "vm" : ""; 	# maybe add volume on new pane
    foreach (keys %{$chart{technical}}) {	# for all tech. analysis opt.
      $pane .= ",$ARG" if $chart{technical}{$ARG};# add on new pane if selected
    }
    $url = "http://cchart.yimg.com/z?" . 
      "&s=$symbol&p=$params&t=$len&c=$chart{comparison}" .
      "&l=$log&z=$chart{size}&q=$chart{style}&a=$pane";
  }
  print "URL $url\n" if $options{verbose};
  return $url;
}

sub default_directory {
  my $directory = File::Spec->catfile($ENV{HOME}, ".smtm");
  unless (-d $directory) {
    warn("Default directory $directory not found, creating it.\n");
    mkdir($directory, 0750) or die "Could not create $directory: $!";
  }
  return $directory;
}

sub select_file_and_open {
  my $selfile = $Main->getOpenFile(-defaultextension => ".smtm",
				   -initialdir => default_directory(),
				   -filetypes        => [
							 ['SMTM', '.smtm'  ],
							 ['All Files', '*',],
							 ],
				   -title => "Load an SMTM file");
  if (defined($selfile)) {	# if user has hit Accept, do nothing on Cancel
    $options{file} = $selfile;
    read_config();
    init_fx();
  } 
}

sub select_file_and_save {
  my $selfile = $Main->getSaveFile(-defaultextension => ".smtm",
				   -initialdir => default_directory(),
				   -title => "Save an SMTM file");
  if (defined($selfile)) {	# if user has hit Accept, do nothing on Cancel
    $options{file} = $selfile;
    file_save();
  } 
}

sub read_config {		# get the data from the resource file
  undef $Dat{ID};		# make sure we delete the old symbols, if any
  undef $Dat{Arg};		# make sure we delete the old symbols, if any
  undef $Dat{Map};		# make sure we delete the old symbols, if any
  undef $Dat{Name};		# make sure we delete the old symbols, if any
  undef $Dat{Symbol};		# make sure we delete the old symbols, if any
  undef $Dat{GivenName};	# make sure we delete the old symbols, if any
  undef $Dat{Shares};		# make sure we delete the old symbols, if any
  undef $Dat{Cross};		# make sure we delete the old symbols, if any
  undef $Dat{PurchPrice};	# make sure we delete the old symbols, if any
  undef $Dat{PurchDate};	# make sure we delete the old symbols, if any

  open (FILE, "<$options{file}") or die "Cannot open $options{file}: $!\n";
  while (<FILE>) {		# loop over all lines in the file
    next if (m/(\#|%)/);	# ignore comments, if any
    next if (m/^\s*$/);		# ignore empty lines, if any
    next if (m/.*=$/);		# ignore non-assignments
    if (m/^\s*\$?(\S+)=(\S+)\s*$/) { # if assignment, then it must be an option
      my ($arg,$val) = ($1,$2);
      if ($arg eq "retsort") {	# test for one legacy option
	$options{sort}='r' if $val;	# old option $retsort was always = 1
      } elsif ($arg =~ m/chart::(\w*)/){# test for chart option
	my $key = $1;
	warn "No chart option $key known\n" unless exists($chart{$key});
	if (index($val, ":") > -1) {
	  foreach (split /:/, $val) {
	    my $cmd = "\$chart{$key}{$ARG}=1\n";
	    print "Setting from rcfile: $cmd" if $options{verbose};
	    eval $cmd;		# store option
	  }
	} else {
	  my $cmd = "\$chart{$key}='$val'\n";
	  print "Setting from rcfile: $cmd" if $options{verbose};
	  eval $cmd;		# store option
	}
      } else {			# else normal option
	warn "No option $arg known\n" unless exists($options{$arg});
	my $cmd = "\$options{$arg}='$val'\n";
	print "Setting from rcfile: $cmd" if $options{verbose};
	eval $cmd;		# store option
      }
    } else {			# or else it is stock information
      insert_stock($ARG);
    }
  }
  close(FILE);
  for my $i (0..length($options{columns})-1) {
    $coldisp{substr($options{columns}, $i, 1)} = 1;
  }
}

sub insert_stock {		# insert one stock into main data structure
  my $arg = shift;
  chomp $arg;
  my @arr = split ':', $arg;	# split along ':'
  $arr[0] = uc $arr[0];		# uppercase the symbol
  my $key = $arr[0] . ':' . $symbolcounter++;
  push @{$Dat{Arg}}, $key;	# store symbol 
  $Dat{ID}{$key} = $symbolcounter;
  $Dat{Symbol}{$key} = defined($arr[0]) ? $arr[0] : "";
  $Dat{GivenName}{$key} = defined($arr[1]) ? $arr[1] : "";
  $Dat{Shares}{$key} = defined($arr[2]) ? $arr[2] : 0;
  $Dat{Cross}{$key} = defined($arr[3]) ? $arr[3] : "";
  $Dat{PurchPrice}{$key} = defined($arr[4]) ? $arr[4] : 0;
  $Dat{PurchDate}{$key} = defined($arr[5]) ? $arr[5] : 0;
}

sub edit_stock {
  my ($widget,$arg) = @_;
  my $key = $Dat{Map}[$arg];
  my $TL = $Main->Toplevel;	# new toplevel widget ...
  $TL->title ("Edit Stock");
  my $FR = $TL->Frame->pack(fill => 'both');
  my $row = 0;
  my @data = ( $Dat{Symbol}{$key},
	       $Dat{GivenName}{$key} || $Dat{Name}{$key}, 
	       $Dat{Shares}{$key}, 
	       $Dat{Cross}{$key}, 
	       $Dat{PurchPrice}{$key},
	       $Dat{PurchDate}{$key} );
  foreach ('Symbol', 'Name', 'Nb of Shares', 'Cross-currency', 
	   'Purchase Price', 'Purchase Date') {
    my $E = $FR->Entry(-textvariable => \$data[$row],
		       -relief => 'sunken', -width => 20);
    my $L = $FR->Label(-text => $ARG, -anchor => 'e', -justify => 'right');
    Tk::grid($L, -row => $row,   -column => 0, -sticky => 'e');
    Tk::grid($E, -row => $row++, -column => 1, -sticky => 'ew');
    $FR->gridRowconfigure(1, -weight => 1);
    $E->focus if $ARG eq 'Symbol (required)';
  }
  $TL->Button(-text => 'Ok',  -command => sub {	# 0 is the symbol, not stored
		$Dat{GivenName}{$key}  = defined($data[1]) ? $data[1] : "";
		$Dat{Shares}{$key}     = defined($data[2]) ? $data[2] : 0;
		$Dat{Cross}{$key}      = defined($data[3]) ? $data[3] : "";
		$Dat{PurchPrice}{$key} = defined($data[4]) ? $data[4] : 0;
		$Dat{PurchDate}{$key}  = defined($data[5]) ? $data[5] : 0;
		$TL->destroy();
		init_fx(); 
	    }   
	      )->pack(-side => 'bottom');
}

sub init_fx {			# find unique crosscurrencies
  undef $Dat{FXarr};
  my %hash;			# to compute a unique subset of the FX crosses
  foreach my $key (keys %{$Dat{Cross}}) {
    my $val = $Dat{Cross}{uc $key}; # the actual cross-currency
    if ($val ne "" and not $hash{$val}) {
      push @{$Dat{FXarr}}, $val."=X"; # store this as Yahoo's symbol
      $hash{$val} = 1;		# store that's we processed it
    }
  }
  buttons();
}

sub show_gallery {
  view_image($Main, $ARG) foreach (0..$#{$Dat{Arg}});
}

sub init_data {			# fill all arguments into main data structure
  my @args = @_;

  if (defined($main::options{proxy})) {
    $Finance::YahooQuote::PROXY = $options{proxy};
  }
  if (defined($options{firewall}) and
      $options{firewall} ne "" and 
      $options{firewall} =~ m/.*:.*/) {
    my @q = split(':', $main::options{firewall}, 2);
    $Finance::YahooQuote::PROXYUSER = $q[0];
    $Finance::YahooQuote::PROXYPASSWD = $q[1];
  }

  menus();			# create frame, and populate with menus

  if (defined $args[0]) {	# if we had arguments
    undef $Dat{Arg};		# unset previous ones
    foreach $ARG (@args) {	# and fill
      insert_stock($ARG);	# new ones
    }
  }

  init_fx();

  show_gallery() if $options{gallery};
}

sub file_save {			# store in resource file
  my $file = $options{file};
  open (FILE, ">$file") or die "Cannot open $file: $!\n";
  print FILE "\#\n\# smtm version $VERSION resource file saved on ", 
     strftime("%c", localtime);
  print FILE "\n\#\n";
  foreach my $key (keys %options) {
    print FILE "$key=", eval("\$options{$key}"),"\n" 
      if eval("defined(\$options{$key})");
  }
  foreach my $key (keys %chart) {
    # hash args get unrolled into a string joined by ':'
    if (ref($chart{$key}) and ref($chart{$key}) eq "HASH") {
       print FILE "chart::$key=";
       foreach my $chart (keys %{$chart{$key}}) {
	 print FILE "$chart:" if $chart{$key}{$chart};
       }
       print FILE "\n";
    } else {
      print FILE "chart::$key=", eval("\$chart{$key}"),"\n" 
	if eval("defined(\$chart{$key})");
    }
  }
  foreach (0..$#{$Dat{Arg}}) {
    my $key = @{$Dat{Arg}}[$ARG];
    print FILE join(':', ($Dat{Symbol}{$key}, $Dat{GivenName}{$key}, 
			  $Dat{Shares}{$key}, $Dat{Cross}{$key},
			  $Dat{PurchPrice}{$key},
			  $Dat{PurchDate}{$key})), "\n";
  }
  close(FILE);
}

sub add_stock {
  my $TL = $Main->Toplevel;	# new toplevel widget ...
  $TL->title ("Add Stock");
  my $FR = $TL->Frame->pack(fill => 'both');
  my $row = 0;
  my @data = ("", "", "", "", "", "" );
  foreach ('Symbol', 'Name', 'Nb of Shares', 'Cross-currency', 
	   'Purchase Price', 'Purchase Date') {
    my $E = $FR->Entry(-textvariable => \$data[$row],
		       -relief => 'sunken', -width => 20);
    my $L = $FR->Label(-text => $ARG, -anchor => 'e', -justify => 'right');
    Tk::grid($L, -row => $row,   -column => 0, -sticky => 'e');
    Tk::grid($E, -row => $row++, -column => 1, -sticky => 'ew');
    $FR->gridRowconfigure(1, -weight => 1);
    $E->focus if $ARG eq 'Symbol (required)';
  }
  $TL->Button(-text => 'Ok',
	      -command => sub { 
				$ARG = join(':', @data);
				$TL->destroy();
				insert_stock($ARG);
				init_fx();
			    }   
	      )->pack(-side => 'bottom');
}

sub del_stock {			# delete one or several stocks
  my $TL = $Main->Toplevel;	# new toplevel widget ...
  $TL->title ("Delete Stock(s)");
  my $LB = $TL->Scrolled("Listbox", 
			 -selectmode => "multiple",
			 -scrollbars => "e",
			 -font => $BFont,
			 -width => 16
			)->pack();
  my (@data);			# array of symbols in displayed order
  my $prefsort = $options{sort};
  $options{sort} = 'n';
  foreach (sort sort_func values %{$Dat{Data}}) {
    my @arr = split (';', $ARG);
    $LB->insert('end',  $arr[1]);
    push @data, $arr[0];
  }
  $options{sort} = $prefsort;
  $TL->Label(-text => 'Select stocks to be deleted')->pack();
  $TL->Button(-text => 'Delete',
	      -command => sub { 
		my @A;		# temp. array 
		foreach (0..$#data) {
		  push @A, $data[$ARG] 
		    unless $LB->selectionIncludes($ARG);
		}
		@{$Dat{Arg}} = @A;
		$TL->destroy();	
		buttons();
	      }
 	     )->pack(-side => 'bottom');
}

sub chg_delay {			# window to modify delay for update
  my $TL = $Main->Toplevel;	# new toplevel widget ...
  $TL->title ("Modify Delay");
  my $SC = $TL->Scale(-from => 1,
		      -to => 60,
		      -orient => 'horizontal',
		      -sliderlength => 15,
		      -variable => \$options{delay})->pack();
  $TL->Label(-text => 'Select update delay in minutes')->pack();
  $TL->Button(-text => 'Ok',
	      -command => sub {	$TL->destroy(); 
				buttons();
	      }  )->pack(-side => 'bottom');
}

sub get_comparison_symbol {	# window to modify delay for update
  my $TL = $Main->Toplevel;	# new toplevel widget ...
  $TL->title ("Enter Comparison Symbol");

  my $FR = $TL->Frame->pack(fill => 'both');
  my $data = $chart{comparison};
  my $label = 'Comparison Symbol';
  my $E = $FR->Entry(-textvariable => \$data,
		     -relief => 'sunken',
		     -width => 20);
  my $L = $FR->Label(-text => 'Comparison Symbol', 
		     -anchor => 'e', 
		     -justify => 'right');
  Tk::grid($L, -row => 0, -column => 0, -sticky => 'e');
  Tk::grid($E, -row => 0, -column => 1, -sticky => 'ew');
  $FR->gridRowconfigure(1, -weight => 1);
  $E->focus;
  $TL->Button(-text => 'Ok',
 	      -command => sub { $chart{comparison} = "$data";
 				$TL->destroy(); 
			    } 
	     )->pack(-side => 'bottom');
}

sub help_about {		# show a help window
  my $TL = $Main->Toplevel;	# uses pod2text on this very file :->
  $TL->title("Help about smtm");
  my $Text = $TL->Scrolled("Text", 
			   -width => 80, 
			   -scrollbars => 'e')->pack();
  button_or_mouseclick_close($TL,$Text);
  open (FILE, "pod2text $PROGRAM_NAME | ");
  while (<FILE>) {
    $Text->insert('end', $ARG);	# insert what pod2text show when applied
  }				# to this file, the pod stuff is below
  close(FILE);
}

sub help_license {		# show a license window
  my $TL = $Main->Toplevel;	# uses pod2text on this very file :->
  $TL->title("Copying smtm");
  my $Text = $TL->Text(-width => 77, 
		       -height => 21)->pack();
  button_or_mouseclick_close($TL,$Text);
  open (FILE, "< $PROGRAM_NAME");
  while (<FILE>) {		# show header
    last if m/^$/;
    next unless (m/^\#/ and not m/^\#\!/);
    $ARG =~ s/^\#//;		# minus the leading '#'
    $Text->insert('end', $ARG);
  }
  $Text->insert('end', "\n   smtm version $VERSION as of $date");
  close(FILE);
}

sub get_firewall_id {
  my ($user,$passwd);
  my $TL = $Main->Toplevel;	# new toplevel widget ...
  $TL->title ("Specify Firewall ID");
  my $FR = $TL->Frame->pack(fill => 'both');
  my $row = 0;
  my @data = ( "", "" );
  foreach ('Firewall Account', 'Firewall Password') {
    my $E = $FR->Entry(-textvariable => \$data[$row],
		       -relief => 'sunken',    
		       -width => 20) if $row eq 0;
    $E = $FR->Entry(-textvariable => \$data[$row],
		    -relief => 'sunken',    
		    -show => '*',
		    -width => 20) if $row eq 1;
    my $L = $FR->Label(-text => $ARG, 
		       -anchor => 'e', 
		       -justify => 'right');
    Tk::grid($L, -row => $row,  -column => 0, -sticky => 'e');
    Tk::grid($E, -row => $row, -column => 1, -sticky => 'ew');
    $FR->gridRowconfigure(1, -weight => 1);
    $E->focus if $row++ eq 0;
  }
  $TL->Button(-text => 'Ok',
 	      -command => sub { $options{firewall} = "$data[0]:$data[1]";
 				$TL->destroy();
				update_display_variables();
			    } 
	      )->pack(-side => 'bottom');
}

sub help_exit {			# command-line help
  print STDERR "
smtm -- Display/update a global stock ticker, profit/loss counter and charts

smtm version $VERSION of $date
Copyright (C) 1999 - 2002 by Dirk Eddelbuettel <edd\@debian.org>
smtm comes with ABSOLUTELY NO WARRANTY. This is free software, 
and you are welcome to redistribute it under certain conditions. 
For details, select Help->License or type Alt-h l once smtm runs.

Usage:   
   smtm [options] [symbol1 symbol2 symbol3 ....]

Options: 
   --time minutes    minutes to wait before update of display
                     (default value: $options{delay})
   --file rcfile     file to store and/or retrieve selected shares
                     (default value: $options{file})
   --proxy proxyadr  network address and port of firewall proxy 
                     (default value: none, i.e. no proxy) 
   --fwall [id:pw]   account and password for firewall, if the --fwall option
                     is used but not firewall id or passwd are give, a window
                     will prompt for them
                     (default value: none, i.e. no firewall)
   --columns set     select the displayed columns by adding the respective 
		     letter to the variable set; choose from 's' for
		     stock symbol, 'n' for the name, 'l' for last
		     price. 'a' for absolute price change, 'r' for
		     relative price change, 'V' for the volume traded,
		     'p' for the profit or loss in the position, 'v'
		     for the value of the position, 'h' for the length
		     of the holding period, 'R' or the annualised return
		     'd' for the drawdown from the 52-week high,
                     'e' for earnings per share, 'P' for the price/earnings
 		     ratio, 'D' for the dividend yield, 'm' for market
		     capitalization and lastly, 'f' for the 'file position' 
		     (i.e. the position in which the stock were specified)
   --chart len       select length of data interval shown in chart, choose
		     one of 'b' (intra-day), 'w' (1 week), '3' (3 months),
		     '6' (6 months), '1' (1 year), '2' (2 year), '5' 
                     (5 year) or 'm' (max years) (default: $chart{length})
   --gallery	     show charts of all available symbols
   --timeout len     timeout value in seconds for libwww-perl UserAgent
                     (default value: $options{timeout})
   --wide	     display the holdings value and change in the window title
   --percent         show relative performance in percent instead of bps
   --sort style      sort display of shares by specified style, choose
                     'r' for relative change, 'a' for absolute change
                     'p' for position change, 'v' for position value,
 		     'V' for trading volume, 'h' for holding period,
		     'R' for annual return, 'd' for drawdown, 'e' for 
		     earnings, 'P' for price/earnings, 'D' for 
		     dividend yield, 'm' for market capitalization,
		     'f' for the 'file position' and 'n' for name.
                     (default value: $options{sort})
   --nookbutton      close other windows via left mouseclick, suppress button
   --verbose         more output on stdout (not used much currently)
   --help            print this help and version message

Examples:
   smtm T::10:USDCAD BCE.TO::10 
   smtm --time 15 \"T:Ma Bell:200:USDCAD:62:19960520\"
   smtm --file ~/.telcos --columns nlarV
   smtm --proxy http://192.168.100.100:80 --fwall foobar:secret

\n";
  exit 0;
}

__END__				# that's it, folks!  Documentation below

#---- Documentation ---------------------------------------------------------

=head1 NAME

smtm - Display and update a configurable ticker of global stock quotes

=head1 SYNOPSYS

 smtm [options] [stock_symbol ...]

=head1 OPTIONS

 --time min	 minutes to wait before update 
 --file smtmrc   to store/retrieve stocks selected 
 --proxy pr      network address and port of firewall proxy 
 --fwall [id:pw] account and password for firewall 
 --chart len     select length of data interval shown in chart
                 (must be one of b, w, 3, 6, 1, 2, 5 or m)
 --timeout len   timeout in seconds for libwww-perl UserAgent
 --wide		 also display value changes and holdings
 --percent       show relative performance in percent instead of bps
 --sort style    sort display by specified style
                 (must be one r, a, p, v, n, v, V or h)
 --columns set   choose the columns to display (can be any combination
		 of s, n, l, a, r, v, p, V, R, h)
 --nookbutton    close other windows via left mouseclick, suppress button
 --help          print a short help message


=head1 DESCRIPTION

B<smtm>, which is a not overly clever acronym for B<Show Me The
Money>, is a financial ticker and portfolio application for quotes
from exchanges around the world (provided they are carried on
Yahoo!). It creates and automatically updates a window with quotes
from Yahoo! Finance. It can also display the entire variety of charts
available at Yahoo! Finance. When called with one or several symbols,
it displays these selected stocks. When B<smtm> is called without
arguments, it reads the symbols tickers from a file, by default
F<~/.smtmrc>. This file can be created explicitly by calling the Save
option from the File menu. Beyond stocks, B<smtm> can also display
currencies (from the Philadephia exchange), US mutual funds, options
on US stocks, several precious metals and quite possibly more; see the
Yahoo! Finance website for full information.

B<smtm> can also aggregate the change in value for both individual
positions and the the entire portfolio.  For this, the number of
shares is needed, as well as the cross-currency expression pair. The
standard ISO notation is used. As an example, GBPUSD translates from
Pounds into US Dollars. To compute annualised returns, the purchase
date and purchase price can also be entered.

B<smtm> displays the full name of the company, the absolute price
change and the relative percentage change in basispoints (i.e.,
hundreds of a percent) or in percentages if the corresponding option
has been selected.  Other information that can be displayed are the
traded volume, the profit/loss, the aggregate positon value, the
holding period length, the annualised return, the drawdown, the
earnings per share, the price/earnings ratio, the dividend yield, and
the market capitalization. Note that the return calculation ignores
such fine points as dividends, and foreign exchange appreciation or
depreciation for foreigns stocks.  All display columns can be
selected, or deselected, individually.

Losers are flagged in red.  B<smtm> can be used for stocks from the
USA, Canada, various European exchanges, various Asian exchanges
(Singapore, Taiwan, HongKong, Kuala Lumpur, ...) Australia and New
Zealand. It should work for other markets supported by Yahoo. US
mutual funds are also available, but less relevant as their net asset
value is only computed after the market close. Some fields might be
empty if Yahoo! does not supply the full set of fields; the number of
supported fields varies even among US exchanges. The sorting order can
be chosen among eight different options.

The quotes and charts are delayed, typically 15 minutes for NASDAQ and
20 minutes otherwise, see F<http://finance.yahoo.com> for details. New
Zealand is rumoured to be somewhat slower with a delay of one
hour. However, it is worth pointing out that (at least some) US)
indices are updated in real time at Yahoo!, and therefore available in
real time to B<smtm>.  Intra-day and five-day charts are updated
during market hours by Yahoo!, other charts with longer timeframes are
updated only once a week by Yahoo!.

B<smtm> supports both simple proxy firewalls (via the I<--proxy> option) 
and full-blown firewalls with account and password authorization (via the 
I<--fwall> option). Firewall account name and password can be specified as 
command line arguments after I<--fwall>, or else in a pop-up window. This 
setup has been in a few different environments. 

B<smtm> can display two more views of a share position. Clicking mouse
button 1 launches a detailed view with price, date, change, volume,
bid, ask, high, low, year range, price/earnings, dividend, dividend
yield, market capital information, number of shares held and
annualised return. However, not all of that information is available
at all exchanges.  Clicking the right mouse button display a chart of
the corresponding stock; this only works for US and Canadian stocks.
The type of chart can be specified either on the command-line, or via
the Chart menu. Choices are intraday, five day, three months, six
months, one year, two years, five years or max years. The default chart
is a five day chart. The middle mouse button opens an edit window to
modify and augment the information stored per stock.

See F<http://help.yahoo.com/help/us/fin/chart/> for help on Yahoo!
Finance charts.

B<smtm> has been written and tested under Linux. It should run under
any standard Unix, success with Solaris, HP-UX and FreeBSD is
confirmed (but problems are reported under Solaris when a threaded
version of Perl is used). It also runs under that other OS from
Seattle using the B<ActivePerl> implementation from
F<http://www.activestate.com>.  In either case, it requires the
F<Perl/Tk> module for windowing, and the F<LWP> module (also known as
F<libwww-perl>) for data retrieval over the web. The excellent
F<Date::Manip> modules is also required for the date parsing and
calculations. With recent versions of ActivePerl, only Date::Manip
needs to be installed on top of the already provided modules.

=head1 EXAMPLES

  smtm CSCO NT

creates a window following the Cisco and Nortel stocks.

  smtm MSFT:Bill SUNW:Scott ORCL:Larry

follows three other tech companies and uses the override feature for
the displayed name. [ Historical note: We once needed that for
European stocks as Yahoo! did not supply the company name way back in
1999 or so. This example just documents a now ancient feature. ]

  smtm  BT.A.L::10:GBPCAD   T::10:USDCAD \
        BCE.TO::10   13330.PA::10:EURCAD \
        "555750.F:DT TELECOM:10:EURCAD"

creates a window with prices for a handful of telecom companies on
stock exchanges in London, New York, Toronto, Paris and
Frankfurt. Note how a names is specified to override the verbose
default for the German telco.  Also determined are the number of
shares, here 10 for each of the companies. Lastly, this example
assumes a Canadian perspective: returns are converted from British
pounds, US dollars and Euros into Canadian dollars. Quotation marks
have to be used to prevent the shell from splitting the argument
containing spaces. [ Historical note: The Deutsche Telecom stock can
now also be referenced as DTEGn.DE; similarly other stock previously
available only under their share number are now accessible using an
acronym reflecting their company name.]

=head1 MENUS

Four menus are supported: I<File>, I<Edit>, I<Chart> and I<Help>.  The
I<File> menu offers to load or save to the default file, or to 'save
as' a new file.  I<Exit> is also available.

The I<Edit> menu can launch windows to either add a new stock or
delete one or several from a list box. Submenus for column selection
based on various criteria are available. Similarly, the I<Sort> menu
allows to select one of eight different sort options.  Further, one
can modify the delay time between updates and choose between the
default title display or the wide display with changes in the position
and total position value.

The I<Charts> menu allows to select the default chart among the eight
choices intraday, five day, three months, six months, one year, two
years, five years or 'max' years. Chart sizes can be selected among
three choices. Plot types can be selected among line chart, bar chart
and the so-called candlestick display. For both moving averages and
exponential moving averages, six choices are avilable (5, 10, 20, 50,
100 and 200 days, respectively) which can all be selected (or
deselected) individually. Similarly, any one of seven popular
technical analysis charts can be added. Logarithmic scale can be
turned on/off. Volume bar charts as also be selected or
deselected. Similarly, Bollinger bands and the parabolic SAR can be
selected. A selection box can be loaded to enter another symbol (or
several of these, separated by comma) for performance
comparison. Lastly, the gallery command can launch the display of a
chart for each and every stock symbol currenly loaded in the smtm
display.  Note that intra-day and intra-week charts do not offer all
the various charting options longer-dated charts have available.

Lastly, the I<Help> menu can display either the text from the manual
page, or the copyright information in a new window.

=head1 DISPLAY

The main window is very straightforward. For each of the stocks, up to
eleven items can be displayed: its symbol, its name, its most recent
price, the change from the previous close in absolute terms, the
change in relative terms, the volume, the profit or loss, the total
position value, the holding period, the annualised return (bar F/X
effects or dividends) and the drawdown relative to the 52-week high.
The relative change is either expressed in basispoints (bps), which
are 1/100s of a percent, or in percent; this can be controlled via a
checkbutton as well as an command-line option.  Further display
options are earnings per share, price/earnings ratio, dividend yield
and market capitalization.  This display window is updated in regular
intervals; the update interval can be specified via a menu or a
command-line option.

The window title displays the relative portfolio profit or loss for
the current day in basispoints, i.e., hundreds of a percent, or in
percent if the corresponding option is chosen, as well as the date of
the most recent update. If the I<--wide> options is used, the net
change and ney value of the portfolio (both in local currency) are
also displayed.

Clicking on any of the stocks with the left mouse button opens a new
window with all available details for a stock. Unfortunately, the
amount of available information varies. Non-North American stocks only
have a limited subset of information made available via the csv
interface of Yahoo!. For North American stocks, not all fields all
provided by all exchanges. Clicking on the details display window
itself closes this window. Clicking on any of the stocks with the
right mouse button opens a new window with a chart of the given stock
in the default chart format. This option was initially available only
for North American stocks but now works across most if not all
markets, thanks to expanded support by Yahoo!.  Clicking on the chart
window itself closes this window. Finally, the middle mouse button
opens an edit window.

=head1 BUGS

Closing the stock addition or deletion windows have been reported to
cause random segmentation violation under Linux. This appears to be a
bug in Perl/Tk which will hopefully be solved, or circumvented, soon.
This bug does not bite under Solaris, FreeBSD or NT or other Linux
distributions. Update: This problem appears to have disappeared with
Perl 5.6.*.

Problems with undefined symbols have been reported under Solaris 2.6
when Perl has been compiled with thread support. Using an unthreaded
Perl binary under Solaris works. How this problem can be circumvented
is presently unclear.

It is not clear whether the market capitalization information is 
comparable across exchange. Some differences could be attributable to
'total float' versus 'free float' calculations.

=head1 SEE ALSO

F<Finance::YahooQuote.3pm>, F<Finance::YahooChart.3pm>, F<LWP.3pm>,
F<lwpcook.1>, F<Tk::UserGuide.3pm>

See F<http://help.yahoo.com/help/us/fin/chart/> for help on Yahoo!
Finance charts.

=head1 COPYRIGHT

smtm is (c) 1999 - 2002 by Dirk Eddelbuettel <edd@debian.org>

Updates to this program might appear at
F<http://dirk.eddelbuettel.com/code/smtm.html>. If you enjoy this
program, you might also want to look at my beancounter program
F<http://dirk.eddelbuettel.com/code/beancounter.html>.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.  There is NO warranty whatsoever.

The information that you obtain with this program may be copyrighted
by Yahoo! Inc., and is governed by their usage license.  See
F<http://www.yahoo.com/docs/info/gen_disclaimer.html> for more
information.

=head1 ACKNOWLEDGEMENTS

The Perl code by Dj Padzensky, in particular his B<Finance::YahooQuote>
module (on the web at F<http://www.padz.net/~djpadz/YahooQuote/> as well 
as at F<http://dirk.eddelbuettel.com/code/yahooquote.html/>) and
his Finance::YahooChart module (on the web at
F<http://www.padz.net/~djpadz/YahooChart/>) were most helpful. They
provided the initial routines for downloading stock data and
determining the Yahoo! Chart url. Earlier version of B<smtm> use
a somewhat rewrittem variant (which still reflected their heritage), 
newer version rely directly on B<Finance::YahooQuote> now that Yahoo!
uses a similar backend across the globe. Dj's code contribution is most
gratefully acknowledged.

=head1 CPAN 

The remaining sections pertain to the CPAN registration of
B<smtm>. The script category is a little mismatched but as there is no
Finance section, F<Networking> was as good as the other choices.

=head1 SCRIPT CATEGORIES

Networking

=head1 PREREQUISITES

F<smtm> uses F<http://www.activestate.com>.  In either case, it
requires the C<Tk> module for windowing, the C<LWP> module for data
retrieval over the web, and the excellent C<Date::Manip> module for
the date parsing and calculations.

=head1 COREQUISITES

None

=head1 OSNAMES

F<smtm> is not OS dependent. It is known to run under Linux, several
commercial Unix variants and Windows

=head1 README

B<smtm>, which is a not overly clever acronym for B<Show Me The
Money>, is a financial ticker and portfolio application for quotes
from exchanges around the world (provided they are carried on
Yahoo!). It creates and automatically updates a window with quotes
from Yahoo! Finance. It can also display the entire variety of charts
available at Yahoo! Finance. Fairly extensive documentation for
B<smtm> is available at F<http://dirk.eddelbuettel.com/code/smtm.html>.

=cut

