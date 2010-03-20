package Resmon::Module::ROMOUNT;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $disk = $arg->{'object'};
  my $output = cache_command("mount | grep $disk", 180);
  if($output) {
    chomp $output;
    if($output =~ /read-only/) {
      return("OK($output)");
    } else {
      return("BAD(mounted read-write)");
    }
  }
  return("BAD(no output)");
};
1;
