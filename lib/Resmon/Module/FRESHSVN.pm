package Resmon::Module::FRESHSVN;
use strict;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $dir = $arg->{'object'};
  my $moutput = cache_command("/opt/omni/bin/svn info $dir", 60);
  my @mlines = split (/\n/,$moutput);
  my ($URL,$mr);
  for(@mlines) {
    if (/^URL:\s*(.*)$/) { $URL=$1; }
    elsif (/^Revision:\s*(\d+)/) { $mr = $1; }
  }
  return ($arg->set_status("BAD(wrong URL, in conf:".$arg->{'URL'}.", checked out: $URL)")) if ($URL ne $arg->{'URL'});
  my $uoutput = cache_command("/opt/omni/bin/svn info --username svnsync --password Athi3izo  --no-auth-cache --non-interactive $URL", 60);
  my @ulines = split (/\n/,$uoutput);
  my ($ur);
  for(@ulines) {
    if (/^Last Changed Rev:\s*(\d+)/) { $ur = $1; }
  }
  if($ur <= $mr){ return($arg->set_status("OK(rev:$ur)")); }
  else{
    my ($cY,$cM,$cD,$ch,$cm,$cs) = split (/ /, `date '+%Y %m %d %H %M %S'`);
    my $cTime=$cs+60*($cm+60*($ch+24*($cD+31*($cM+12*$cY))));
    my $dNow = "$cM/$cD/$cY $ch:$cm:$cs"; chomp $dNow;
    my ($uY,$uM,$uD,$uh,$um,$us);
    for(@ulines) {
      if (/^Last Changed Date:\s*(\d{4})-(\d{1,2})-(\d{1,2}) (\d{1,2}):(\d{2}):(\d{2})/) {
        ($uY,$uM,$uD,$uh,$um,$us) = ($1,$2,$3,$4,$5,$6);
      }
    }
    my $uTime = $us+60*($um+60*($uh+24*($uD+31*($uM+12*$uY))));
    my $dCommitted = "$uM/$uD/$uY $uh:$um:$us";
    my $lag=$cTime-$uTime;
    my $maxlag=$arg->{'maxlag'}*60 || 330;
    if ($lag <= $maxlag){
      return($arg->set_status("OK(delay = $lag < $maxlag)")); 
    }
    elsif ( ( ($us+60*($um+60*($uh+24*$uD))) < $maxlag ) 
         && ( ($cs+60*($cm+60*($ch+24*$cD))) < 2 * $maxlag )
          )
    {
      return($arg->set_status("WARNING(check unreliable, check later)"));
    }
    else {
      return($arg->set_status("BAD(now $dNow, my rev:$mr, repo rev:$ur, committed: $dCommitted)"));
    }
  }
}
