package Resmon::Module::BACULATAPE;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $unit = $arg->{'object'};
  my $drives_up = cache_command("echo 'st st' | /opt/bacula/sbin/bconsole | /bin/grep Device | /bin/grep -c 'is mounted'", 500);
  chomp $drives_up;
  if($drives_up > 0) {
    return $arg->set_status("OK($drives_up UP)\n");
  } else {
    return $arg->set_status("BAD($drives_up UP)\n");
  }
};

1;
