package Resmon::Module::SPARKTEMP;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $DEBUG=0;
  my $arg = shift;
  my $sensor = $arg->{'object'};
  print STDERR $sensor,"\n" if $DEBUG;
  my $command = "/usr/sbin/prtpicl -v -c temperature-sensor";
  print STDERR "command=$command\n" if $DEBUG;
  my $output = cache_command($command, 30);
 # my $output = `/usr/sbin/prtpicl -v -c temperature-sensor`;
  print STDERR $output if $DEBUG>1;
  my @lines = split(/\n/, $output);
  print STDERR join("\nlines", @lines) if $DEBUG>1;
  my ($temp,$warning, $critical,$name);
  for (@lines) {
    print STDERR "line: $_ \n" if $DEBUG;
    $temp=$1 if /:Temperature\s*(\d*)/; 
    $warning=$1 if /:HighWarningThreshold\s*(\d*)/i; 
    $critical=$1 if /:HighShutdownThreshold\s*(\d*)/i;
    $name=$1 if /:name\s*(\w*)/; 
    print STDERR "temp: $temp warn: $warning crit: $critical name: $name\n" if $DEBUG;
    last if $name =~ m/^$sensor/;
  }
  return "OK($temp)" if $temp <= $warning;
  return "WARNING($temp)" if $temp < $critical;
  return "BAD($temp)";
}
1;
