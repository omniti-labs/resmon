package Resmon::Module::WALCHECK;
use Resmon::Module;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;
use Time::Local;

# Sample config for resmon.conf
# WALCHECK {
#   check_pg_replay_mode  : logdir => /data/set/pgdb2/pgdata/82/pg_log
# }
#
# The logdir may also be in /data/postgres/82/pg_log. Check for a pg_log dir
# with postgresql-yyyy-mm-dd.log files in.

#########################
sub splittime {
  my ($val,@list) = @_;
  my @rv;

  $val = abs($val);
  foreach my $factor (@list){
    push @rv,$val%$factor;
    $val/=$factor;
  }
  push @rv,int($val);
  return @rv;
}
#########################

sub handler {
  my $arg = shift;
  my $logdir = $arg->{'logdir'};
  my $limit = $arg->{'limit'} || 3600;
  opendir(D, $logdir);
  my @files = sort grep /^postgresql-[\d-]+_?\d*\.log$/, readdir(D);
  closedir(D);
  my $wallog = $files[-1];

  open(F, "<", "$logdir/$wallog");
  # Manual split here to work around strange bug where <F> doesn't work
  # when a machine is under load
  local $/; # Make <F> read the whole file
  my @lines = grep(/LOG:  restored log file/, split('\n', <F>));
  ($year,$month,$day,$hour,$min) = (
      $lines[-1] =~ /^(\d\d\d\d)-(\d\d)-(\d\d)\s(\d+):(\d+)/ );
  close(F);

  # subtract 1 to compensate for perl stupidity 
  my $proc = timegm(0,$min,$hour,$day,$month-1,$year);

  my $now = time();
  my @nn = localtime($now);
  my $lnow = timegm(@nn);

  my $diff =  $lnow - $proc;
  my @tsplit = splittime((0 - $diff),60,60,24,7);

  if ($diff > $limit)
  {
    return  "BAD($diff seconds behind)";
  } else {
    return  "OK($diff seconds behind)";
  }
}
1;
