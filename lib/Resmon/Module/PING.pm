package Resmon::Module::PING;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use Switch;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $host = $arg->{'object'};
  # Limit in ms above which to go critical
  my $limit = $arg->{'limit'} || "200";
  switch ($^O) {
      case 'solaris' {
          $pingcmd = "ping -sn $host 56 1"}
      else {
          $pingcmd = "ping -c 1 $host"}
  }

  my $output = cache_command($pingcmd, 30);
  my ($line) = grep(/bytes from\s*/, split(/\n/, $output));
  if(my ($ms) = $line =~ /time= ?([0-9.]+) ?ms/) {
    if($ms <= $limit) {
      return "OK", "$ms ms";
    }
    return "BAD", "$ms ms";
  }
  return "BAD", "no data";
}

1;
