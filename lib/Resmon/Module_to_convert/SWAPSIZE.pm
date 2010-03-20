package Resmon::Module::SWAPSIZE;
use Resmon::Module;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $object = $arg->{'object'};
  my $output = cache_command("df -k /tmp", 30);
  my ($line) = grep(/^swap/, split(/\n/, $output));
  if($line =~ /(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%/) {
    if($1 >= $arg->{'limit'}) {
      return "OK($1 k size)";
    }
    return "BAD($1 k size)";
  }
  return "BAD(no data)";
};

