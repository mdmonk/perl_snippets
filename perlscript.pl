# Subject: Making PerlCOM do evil things . . . :)
# From: "Everett, Toby" <TEverett@ALASCOM.ATT.com>
# Date: Thu, 17 Jun 1999 16:57:02 -0800
#
# A quick little bit of code that lets you use PerlCOM on a remote machine
# to execute commands as a specified user.
# 
# It requires:
# 
# * The remote machine have ActivePerl and AdminMisc installed
# 
# * PerlCOM installed on the remote machine with the default security
# options
# 
# * That the local machine Administrators group on the remote machine have
# the SeTcbPrivilege and SeAssignPrimaryToken privileges
# 
# * That you be a Domain Admin (or a member of the remote machines
# Administrators group)
# 
# Anyway, it should be pretty self explanatory.  It could also use a lot
# of error checking - this is more a demonstration of possibilities than
# an example of beautiful code.  Just thought I'd toss it up here as an
# example of the ugly twists and turns one must put up with given the
# _lame_ security model that exists in NT 4.0 (in particular, the lack of
# Delegation as an Impersonation option).  In a nutshell, when you use
# DCOM to access a COM object on a remote machine, you have your privs on
# that machine but no others (the Impersonation Level known as Identity -
# do a ? click on the Default Impersonation Level drop-down on the Default
# Properties tab of DCOMCNFG).  I could, of course, simply specify that
# PerlCOM run as a specified user and give no-one except me access to it,
# but then I couldn't write Access applications that use PerlCOM (which I
# plan on doing:).
# 
# --Toby Everett
# 
##################################################################
###################### Script Starts Now #########################
##################################################################
sub ExecuteRemoteCommand {
  my($machine, $domain, $username, $password, $command, $workdir) = @_;

  my $PerlCOM = Win32::OLE->new([$machine, '{B5863EF3-7B28-11D1-8106-0000B4234391}']);

  print $PerlCOM->EvalScript(<<ENDSCRIPT);

use Win32::AdminMisc;
use Win32::Process;

sub logon {
  return Win32::AdminMisc::LogonAsUser("$domain", "$username", "$password", LOGON32_LOGON_SERVICE);
}

sub execproc {
  &logon;
  return Win32::AdminMisc::CreateProcessAsUser(\$_[0], \$_[1], "Flags" => CREATE_NO_WINDOW);
}
ENDSCRIPT

  print $PerlCOM->execproc($command, $workdir);
}
