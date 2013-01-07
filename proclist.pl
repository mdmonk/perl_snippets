#! perl.exe
###############################################################
# Program Name: proclist.pl
# Programmer:   CWL
# Desc:         Shows the process listing just like the 
#               task mgr but of any computer.
# Revision: 
#  - v0.0.1 (30 Jan 1999)
#    - Initial Coding. Still unable to attach to remote
#      system. But it works locally!
###############################################################
use Win32::PerfLib;

$|=1;

$toFile = 1;   # change this if you want the output to go to
               # STDOUT. I am redirecting STDOUT to an output
               # file by default. 
               # 0 = Send to STDOUT. 1 = Send to output file.
($server) = @ARGV;
if (!$server) {         # Looks to see if you passed in an
  $server = `hostname`; # argument to the script. If so, it
}                       # uses  that arg as the server name.
                        # If not, it gets the hostname of this
                        # machine and uses that in the script.
chomp($server);
print "Server name is: $server \n";
if ($toFile) {
  open (OUTFILE, ">proc.out") or die "Couldn't open output file: $!\n";
  $old_fh = select(OUTFILE);
}
print "Process Listing for: $server\n\n";
$process_obj = 230;
$process_id = 784;
$processor_time = 6;
$elapsed = 684;
$memory = 180;
$page_faults = 28;
$virtual_memory = 186;
$priority = 682;
$threads = 680;
####################################################
# Work on these variables. Don't quite work how I 
# want them to...not yet.
####################################################
Win32::PerfLib::GetCounterNames($server, \%counter);
%r_counter = map { $counter{$_} => $_ } keys %counter;
$process_obj = $r_counter{Process};
$process_id = $r_counter{'ID Process'};
$processor_time = $r_counter{'% Processor Time'};
####################################################
$perflib = new Win32::PerfLib($server);
$proc_ref0 = {};
$proc_ref1 = {};
$perflib->GetObjectList($process_obj, $proc_ref0);
sleep 5;
$perflib->GetObjectList($process_obj, $proc_ref1);
$perflib->Close();
$instance_ref0 = $proc_ref0->{Objects}->{$process_obj}->{Instances};
$instance_ref1 = $proc_ref1->{Objects}->{$process_obj}->{Instances};
foreach $p (keys %{$instance_ref0}) {
  $counter_ref0 = $instance_ref0->{$p}->{Counters};
  $counter_ref1 = $instance_ref1->{$p}->{Counters};
  foreach $i (keys %{$counter_ref0}) {
    next if $instance_ref0->{$p}->{Name} eq "_Total";
    if($counter_ref0->{$i}->{CounterNameTitleIndex} == $process_id) {
      $process{$counter_ref0->{$i}->{Counter}} =
      $instance_ref0->{$p}->{Name};
      $id{$counter_ref0->{$i}->{Counter}} = $p;
    }
    elsif($counter_ref0->{$i}->{CounterNameTitleIndex} == $processor_time) {
      $Numerator0 = $counter_ref0->{$i}->{Counter};
      $Denominator0 = $proc_ref0->{PerfTime100nSec};
      $Numerator1 = $counter_ref1->{$i}->{Counter};
      $Denominator1 = $proc_ref1->{PerfTime100nSec};
      $proc_time{$p} = ($Numerator1 - $Numerator0) /
        ($Denominator1 - $Denominator0 ) * 100;
      $cputime{$p} = int($counter_ref1->{$i}->{Counter} / 10000000);
    }
    elsif($counter_ref0->{$i}->{CounterNameTitleIndex} == $memory) {
       $memory{$p} = int($counter_ref0->{$i}->{Counter} / 1024);
    }
    elsif($counter_ref0->{$i}->{CounterNameTitleIndex} == $page_faults) {
      $page_faults{$p} = $counter_ref1->{$i}->{Counter};
    }
    elsif($counter_ref0->{$i}->{CounterNameTitleIndex} == $virtual_memory) {
      $virtual_memory{$p} = int($counter_ref0->{$i}->{Counter} / 1024);
    }
    elsif($counter_ref0->{$i}->{CounterNameTitleIndex} == $priority) {
      $priority{$p} = $counter_ref0->{$i}->{Counter};
    }
    elsif($counter_ref0->{$i}->{CounterNameTitleIndex} == $threads) {
      $threads{$p} = $counter_ref0->{$i}->{Counter};
    }
  }
}
print " PID Process         CPU   CPU-Time     Memory       PF   Virt.Mem Priority Thr\n";
#   0 Idle          93.73   20:51:40       16 K        1        0 K Unknown    1
foreach $p (sort { $a <=> $b } keys %process) {
  $id = $id{$p};
  $seconds = $cputime{$id};
  $hour = int($seconds / 3600);
  $seconds -= $hour * 3600;
  $minute = int($seconds / 60);
  $seconds -= $minute * 60;
  if ($priority{$id} > 15) {
    $prio = "Realtime";
  } elsif ($priority{$id} > 10 ) {
    $prio = "High";
  } elsif ($priority{$id} > 5 ) {
    $prio = "Normal";
  } elsif ($priority{$id} > 0 ) {
    $prio = "Low";
  } else {
    $prio = "Unknown";
  }
  printf("% 4d %-14s%5.2f  % 3d:%02d:%02d % 8d K % 8d % 8d K %8s % 3d\n",
    $p, $process{$p}, $proc_time{$id}, $hour, $minute, $seconds,
    $memory{$id}, $page_faults{$id}, $virtual_memory{$id},
    $prio, $threads{$id});
}
if ($toFile) {
  select($old_fh);
  close (OUTFILE);
}
