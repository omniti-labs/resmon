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
  my @molines = split (/\n/,$moutput);
  my ($URL,$mr,$mY,$mM,$mD,$mh,$mm,$ms);
  for(@molines) {
    if (/^URL:\s*(.*)$/) { $URL=$1; }
    elsif (/^Last Changed Rev:\s*(\d+)/) { $mr = $1; }
    elsif (/^Last Changed Date:\s*(\d{4})-(\d{1,2})-(\d{1,2}) (\d{1,2}):(\d{2}):(\d{2})/) {
      ($mY,$mM,$mD,$mh,$mm,$ms) = ($1,$2,$3,$4,$5,$6);
    }
  }
  return ($arg->set_status("BAD(wrong URL, in conf:".$arg->{'URL'}.", checked out: $URL)")) if ($URL ne $arg->{'URL'});
  my $uoutput = cache_command("/opt/omni/bin/svn info --username svnsync --password Athi3izo  --no-auth-cache --non-interactive $arg->{'URL'} 2>&1 ", 60);
  my @ulines = split (/\n/,$uoutput);
  my ($ur,$uY,$uM,$uD,$uh,$um,$us);
  for(@ulines) {
    if (/^Last Changed Rev:\s*(\d+)/) { $ur = $1; }
    elsif (/^Last Changed Date:\s*(\d{4})-(\d{1,2})-(\d{1,2}) (\d{1,2}):(\d{2}):(\d{2})/) {
      ($uY,$uM,$uD,$uh,$um,$us) = ($1,$2,$3,$4,$5,$6);
    }
  }
  if($ur == $mr){ return($arg->set_status("OK(rev:$ur)")); }
  else{
    my ($mTime,$uTime,$lag,$maxlag);
    $mTime=$ms+60*($mm+60*($mh+24*($mD+31*($mM+12*$mY))));
    $uTime=$us+60*($um+60*($uh+24*($uD+31*($uM+12*$uY))));
    $lag=$uTime-$mTime;
    $maxlag=$arg->{'maxlag'}*60 || 330;
    if ($lag <= $maxlag){
      return($arg->set_status("OK(delay = $lag < $maxlag)")); 
    }
    elsif ($us+60*($um+60*($uh+24*($uD)))<$maxlag) {
      return($arg->set_status("WARNING(check unreliable, check later)"));
    }
    else {
      return($arg->set_status("BAD(my rev:$mr, repo rev:$ur)"));
    }
  }
}
