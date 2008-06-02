package Resmon::Module::SWAPSIZE;
use Resmon::Module;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $object = $arg->{'object'};
  my $output = cache_command("df -k /tmp", 30);
  my ($line) = grep(/^swap/, split(/\n/, $output));
  if($line =~ /(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%/) {
    if($1 >= $arg->{'limit'}) {
      return $arg->set_status("OK($1 k size)");
    }
    return $arg->set_status("BAD($1 k size)");
  }
  return $arg->set_status("BAD(no data)");
};

