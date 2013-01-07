use IO::Socket;
use IO::Select;


  @{$PORTS{out}} = $SELECT{7000}->can_write(1);
  foreach my $PORT (@{$PORTS{out}})
  {
    if ($CHAT{$PORT}{stat} eq '')
    {
      $PORT->send("Welcome \cM\cJ");
      $PORT->send("Today is " . scalar localtime() . "\cM\cJ");
    }
  }


