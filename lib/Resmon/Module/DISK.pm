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
  if($line =~ /(\d+)\s+(\d+)\s+(\d+)%/) {
    $status = "OK";
    # Check free space for an exact value in KB
    if(exists $arg->{'minkbfree'} && $2 < $arg->{'minkbfree'}) {
        $status = "BAD";
    }
    if(exists $arg->{'warnkbfree'} && $2 < $arg->{'warnkbfree'}) {
        $status = "WARNING";
    }
    # Check for percentage used and alert over that value
    if(exists $arg->{'limit'} && $3 > $arg->{'limit'}) {
        $status = "BAD";
    }
    if(exists $arg->{'warnat'} && $3 > $arg->{'warnat'}) {
        $status = "WARNING"
    }
    return $status, {
        "message" => "$3% full -- $2KB free",
        "usedkb" => "$1",
        "freekb" => "$2",
        "usedpercent" => "$3"
    }
  }
  return "BAD", "0 -- no data";
}
1;
