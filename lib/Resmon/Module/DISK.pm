package Resmon::Module::DISK;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

my $dfcmd = ($^O eq 'linux') ? 'df -kP' : 'df -k';

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $devorpart = $arg->{'object'};
  my $output = cache_command("$dfcmd", 120);
  my ($line) = grep(/$devorpart\s*/, split(/\n/, $output));
  if($line =~ /(\d+)%/) {
    if($1 > $arg->{'limit'}) {
      return $arg->set_status("BAD($1% full)");
    }
    if(exists $arg->{'warnat'} && $1 > $arg->{'warnat'}) {
      return $arg->set_status("WARNING($1% full)");
    }
    return $arg->set_status("OK($1% full)");
  }
  return $arg->set_status("BAD(0 -- no data)");
}
1;
