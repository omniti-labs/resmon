package Resmon::Module::DISK;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

my $dfcmd = ($^O eq 'linux') ? 'df -kP' : 'df -k';

sub handler {
  my $arg = shift;
  my $devorpart = $arg->{'object'};
  my $output = cache_command("$dfcmd $devorpart", 120);
  my ($line) = grep(/$devorpart\s*/, split(/\n/, $output));
  if($line =~ /(\d+)\s+(\d+)%/) {
    $status = "OK";
    # Check free space for an exact value in KB
    if(exists $arg->{'minkbfree'} && $1 < $arg->{'minkbfree'}) {
        $status = "BAD";
    }
    if(exists $arg->{'warnkbfree'} && $1 < $arg->{'warnkbfree'}) {
        $status = "WARNING";
    }
    # Check for percentage used and alert over that value
    if(exists $arg->{'limit'} && $2 > $arg->{'limit'}) {
        $status = "BAD";
    }
    if(exists $arg->{'warnat'} && $2 > $arg->{'warnat'}) {
        $status = "WARNING"
    }
    return $status, "$2% full -- $1KB free";
  }
  return "BAD", "0 -- no data";
}
1;
