package Resmon::Module::FAULTS;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $proc = $arg->{'object'};
  my $output = cache_command("/usr/sbin/fmadm faulty | sed '1,2d'|grep -v -- '^----'", 500);
  if($output) {
    $output =~s /\n/:/gs;
    $output =~s /\s+/ /gs;
    return $arg->set_status("BAD($output)");
  }
  return $arg->set_status("OK(no faults)");
};

