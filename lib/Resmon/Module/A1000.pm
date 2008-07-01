package Resmon::Module::A1000;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $unit = $arg->{'object'};
  my $output = cache_command("/usr/lib/osa/bin/healthck -a", 500);
  my ($line) = grep(/^$unit:/, split(/\n/, $output));
  if ($line =~ /:\s+(.+)/) {
    return "OK($1)") if($1 eq $arg->{'status'};
    return "BAD($1)";
  }
  return "BAD(no data)";
};
1;
