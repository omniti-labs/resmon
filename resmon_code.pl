#!/usr/bin/perl

require 'ext_comm.pl';

my %coderefs;

my $rmloading = "Registering";

sub fetch_monitor {
  my $type = shift;
  my $coderef = $coderefs{$type};
  return $coderef if ($coderef);
  if ( -r "$type.pl" ) {
    require "$type.pl";
  }
  return $coderef = $coderefs{$type};
}

sub register_monitor {
  my ($type, $coderef) = @_;
  $coderefs{$type} = $coderef;
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
  $arg->{lastupdate} = time;
  return $arg->{laststatus};
}
#### Begin actual monitor functions ####

register_monitor('DATE', sub {
  my $arg = shift;
  my $os = fresh_status($arg);
  return set_status($arg, "OK(".time().")");
});

register_monitor('DISK', sub {
  my $arg = shift;
  my $os = fresh_status($arg);
  return $os if $os;
  my $devorpart = $arg->{'object'};
  my $output = cache_command("df -k", 120);
  my ($line) = grep(/$devorpart\s*/, split(/\n/, $output));
  if($line =~ /(\d+)%/) {
    if($1 <= $arg->{'limit'}) {
      return set_status($arg, "OK($1% full)");
    }
    return set_status($arg, "BAD($1% full)");
  }
  return set_status($arg, "BAD(no data)");
});

register_monitor('A1000', sub {
  my $arg = shift;
  my $os = fresh_status($arg);
  return $os if $os;
  my $unit = $arg->{'object'};
  my $output = cache_command("/usr/lib/osa/bin/healthck -a", 500);
  my ($line) = grep(/^$unit:/, split(/\n/, $output));
  if ($line =~ /:\s+(.+)/) {
    return set_status($arg, "OK($1)") if($1 eq $arg->{'status'});
    return set_status($arg, "BAD($1)");
  }
  return set_status($arg, "BAD(no data)");
});

my %logfile_stats;
register_monitor('LOGFILE', sub {
  my $arg = shift;
  my $os = fresh_status($arg);
  return $os if $os;
  my $file = $arg->{'object'};
  my $match = $arg->{'match'};
  my $errors;
  my $errorcount = 0;
  my $start = 0;
  my @statinfo = stat($filename);
  if($logfile_stats{$file}) {
    my($dev, $ino, $size, $errs) = split(/-/, $logfile_stats{$file});
    if(($dev == $statinfo[0]) && ($ino == $statinfo[1])) {
      if($size == $statinfo[7]) {
        return set_status($arg, "OK($errs)");
      }
      $start = $size;
      $errorcount = $errs;
    }
  }
  open(LOG, "<$file");
  seek(LOG, $size, 0);
  while(<LOG>) {
    chomp;
    if(/$match/) {
      $errors .= $_;
      $errorcount++;
    }
  }
  $logfile_stats{$file} = "$statinfo[0]-$statinfo[1]-$statinfo[7]-$errorcount";
  if($errors) {
    return set_status($arg, "BAD($errors)");
  }
  return set_status($arg, "OK($errorcount)");
});

register_monitor('NETSTAT', sub {
  my $arg = shift;
  my $os = fresh_status($arg);
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
  return set_status($arg, "BAD($count)")
	if($arg->{limit} && ($count > $arg->{limit}));
  return set_status($arg, "BAD($count)")
	if($arg->{atleast} && ($count < $arg->{atleast}));
  return set_status($arg, "OK($count)");
});

$rmloading = "Demand loading";
1;
