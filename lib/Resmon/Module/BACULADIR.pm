package Resmon::Module::BACULADIR;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $unit = $arg->{'object'};
  my $status = cache_command("echo 'st dir' | /opt/bacula/sbin/bconsole | grep '^Daemon'", 500);
  chomp $status;
  if($status) {
    return $arg->set_status("OK(UP $status)\n");
  } else {
    return $arg->set_status("BAD(BAD no status returned)\n");
  }
};

1;
