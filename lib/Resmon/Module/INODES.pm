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
                      $dfregex = '\d+\s+\d+\s+-?\d+\s+\d+%\s+()(\d+)\s+(\d+)\s+(\d+)%'}
    else            { $dfcmd = 'df -iP';
                      $dfregex = '(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%'}
}

sub handler {
  my $arg = shift;
  my $devorpart = $arg->{'object'};
  my $output = cache_command($dfcmd, 30);
  my ($line) = grep(/$devorpart\s*/, split(/\n/, $output));
  my $status = "BAD";
  my $metrics = {
    message => "no data"
  };
  if($line =~ /$dfregex/) {
    if($4 <= $arg->{'limit'}) {
      $status = "OK";
    }
    $metrics = {
      "message" => "$2 $4% full",
      "inodes_used" => "$2",
      "inodes_free" => "$3"
    };
    $metrics->{'inodes_total'} = $1 if ($1 ne "");
  };
  return $status, $metrics;
}

1;
