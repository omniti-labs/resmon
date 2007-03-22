package Resmon::Module;

use strict;
use Data::Dumper;

my %coderefs;

my $rmloading = "Registering";

sub fetch_monitor {
  my $type = shift;
  my $coderef = $coderefs{$type};
  return $coderef if ($coderef);
  eval "use $type;";
  eval "use Resmon::Module::$type;";
  return undef;
}

sub register_monitor {
  my ($type, $ref) = @_;
  if(ref $ref eq 'CODE') {
    $coderefs{$type} = $ref;
  }
  print STDERR "$rmloading $type monitor\n";
}
sub fresh_status {
  my $arg = shift;
  return undef unless $arg->{interval};
  my $now = time;
  if(($arg->{lastupdate} + $arg->{interval}) >= $now) {
    return $arg->{laststatus};
  }
  return undef;
}
sub set_status {
  my $arg = shift;
  $arg->{laststatus} = shift;
  $arg->{lastmessage} = shift;
  $arg->{lastupdate} = time;
  if($arg->{laststatus} =~ /^([A-Z]+)\(([^\)]+)\)$/s) {
    # This handles old-style modules that return just set status as
    #     STATE(message)
    $arg->{laststatus} = $1;
    $arg->{lastmessage} = $2;
  }
  return ($arg->{laststatus}, $arg->{lastmessage});
}
#### Begin actual monitor functions ####

package Resmon::Module::DATE;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $arg->set_status("OK(".time().")");
}

package Resmon::Module::DISK;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $devorpart = $arg->{'object'};
  my $output = cache_command("df -k", 120);
  my ($line) = grep(/$devorpart\s*/, split(/\n/, $output));
  if($line =~ /(\d+)%/) {
    if($1 <= $arg->{'limit'}) {
      return $arg->set_status("OK($1% full)");
    }
    return $arg->set_status("BAD($1% full)");
  }
  return $arg->set_status("BAD(no data)");
}

package Resmon::Module::LOGFILE;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

my %logfile_stats;
sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $file = $arg->{'object'};
  my $match = $arg->{'match'};
  my $errors;
  my $errorcount = 0;
  my $start = 0;
  my @statinfo = stat($file);
  if($logfile_stats{$file}) {
    my($dev, $ino, $size, $errs) = split(/-/, $logfile_stats{$file});
    if(($dev == $statinfo[0]) && ($ino == $statinfo[1])) {
      if($size == $statinfo[7]) {
        return $arg->set_status("OK($errs)");
      }
      $start = $size;
      $errorcount = $errs;
    }
  }
  $logfile_stats{$file} = "$statinfo[0]-$statinfo[1]-$statinfo[7]-$errorcount";
  if(!open(LOG, "<$file")) {
    return $arg->set_status("BAD(ENOFILE)");
  }
  seek(LOG, $statinfo[7], 0);
  while(<LOG>) {
    chomp;
    if(/$match/) {
      $errors .= $_;
      $errorcount++;
    }
  }
  if($errors) {
    return $arg->set_status("BAD($errors)");
  }
  return $arg->set_status("OK($errorcount)");
}

package Resmon::Module::FILEAGE;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $file = $arg->{'object'};
  my @statinfo = stat($file);
  my $age = time() - $statinfo[9];
  return $arg->set_status("BAD(to old $age seconds)")
        if($arg->{maximum} && ($age > $arg->{maximum}));
  return $arg->set_status("BAD(to new $age seconds)")
        if($arg->{minimum} && ($age > $arg->{minimum}));
  return $arg->set_status("OK($age)");
}

package Resmon::Module::NETSTAT;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
  my $arg = shift;
  my $os = $arg->fresh_status();
  return $os if $os;
  my $output = cache_command("netstat -an", 30);
  my @lines = split(/\n/, $output);
  @lines = grep(/\s$arg->{state}$/, @lines) if($arg->{state});
  @lines = grep(/^$arg->{localip}/, @lines) if($arg->{localip});
  @lines = grep(/^[\d\*\.]+\.$arg->{localport}/, @lines) if($arg->{localport});
  @lines = grep(/^[\d\*\.]+\d+\s+$arg->{remoteip}/, @lines)
	if($arg->{remoteip});
  @lines = grep(/^[\d\*\.]+\s+[\d\*\.+]\.$arg->{remoteport}/, @lines)
	if($arg->{remoteport});
  my $count = scalar(@lines);
  return $arg->set_status("BAD($count)")
	if($arg->{limit} && ($count > $arg->{limit}));
  return $arg->set_status("BAD($count)")
	if($arg->{atleast} && ($count < $arg->{atleast}));
  return $arg->set_status("OK($count)");
}

$rmloading = "Demand loading";
1;
