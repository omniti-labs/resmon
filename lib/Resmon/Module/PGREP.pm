package Resmon::Module::PGREP;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $proc = $arg->{'object'};
  my $args = join(' ',$arg->{'arg0'},$arg->{'arg1'},$arg->{'arg2'});
  $args =~s/\s+$//;
  my $output = cache_command("pgrep -f -l '$proc $args' | grep -v sh | head -1", 500);
  if($output) {
    chomp $output;
    return($arg->set_status("OK(pid:$output)"));
  }
  return($arg->set_status("BAD(no output)"));
};

