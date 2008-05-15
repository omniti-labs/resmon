package Resmon::Module::INODES;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use Switch;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

my $dfcmd;
my $dfregex;

switch ($^O) {
    case 'solaris'  { $dfcmd = 'df -Fufs -oi';
                      $dfregex = '(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%'}
    case 'openbsd'  { $dfcmd = 'df -i';
                      $dfregex = '(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%\s+(\d+)\s+(\d+)\s+(\d+)%'}
    else            { $dfcmd = 'df -iP';
                      $dfregex = '(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%'}
}

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $devorpart = $arg->{'object'};
  my $output = cache_command($dfcmd, 30);
  my ($line) = grep(/$devorpart\s*/, split(/\n/, $output));
  if($line =~ /$dfregex/) {
    if($4 <= $arg->{'limit'}) {
      return $arg->set_status("OK($2 $4% full)");
    }
    return $arg->set_status("BAD($2 $4% full)");
  }
  return $arg->set_status("BAD(no data)");
}

1;
