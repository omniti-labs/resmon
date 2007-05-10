package Resmon::Module::INODES;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $devorpart = $arg->{'object'};
  my $output = cache_command("df -i", 30);
  my ($line) = grep(/$devorpart\s*/, split(/\n/, $output));
  if($line =~ /(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%/) {
    if($4 <= $arg->{'limit'}) {
      return $arg->set_status("OK($2 $4% full)");
    }
    return $arg->set_status("BAD($2 $4% full)");
  }
  return $arg->set_status("BAD(no data)");
}

1;
