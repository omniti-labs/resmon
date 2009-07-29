package Resmon::Module::ALTQSTAT;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $unit = $arg->{'object'};
  my $status = cache_command("pfctl -sq 2>&1 | grep 'Bad file descriptor'", 500);
  chomp $status;
  if($status) {
    return $arg->set_status("BAD(ALTQ needs reloading - $status)\n");
  } else {
    return $arg->set_status("OK(ALTQ running fine)\n");
  }
};

1;
