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
  if($line =~ /(\d+)%/) {
    if($1 > $arg->{'limit'}) {
      return "BAD($1% full)";
    }
    if(exists $arg->{'warnat'} && $1 > $arg->{'warnat'}) {
      return "WARNING($1% full)";
    }
    return "OK($1% full)";
  }
  return "BAD(0 -- no data)";
}
1;
