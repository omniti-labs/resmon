#!/usr/bin/perl

use Time::HiRes qw( gettimeofday tv_interval sleep );
my @conflist;
my $rmseconds;
my $rmlast = undef;

sub set_interval {
  $rmseconds = shift;
}  

sub wait_interval {
  $rmlast = [gettimeofday] unless defined($rmlast);
  my $elapsed = $rmseconds - tv_interval($rmlast);
  if($elapsed > 0) {
    sleep($elapsed);
  }
  $rmlast = [gettimeofday];
}

my $statusfile;
my $sfopened = 0;
sub set_statusfile {
  $statusfile = shift;
  $statusfile = undef if($statusfile eq '-');
}

sub open_statusfile {
  return 0 unless $statusfile;
  if(open(STAT, ">$statusfile.swap")) {
    $sfopened = 1;
    chmod 0644, "$statusfile.swap";
    return 1;
  }
  return 0;
}
sub print_statusfile {
  my $line = shift;
  if($sfopened) {
    print STAT $line;
  } else {
    print $line;
  }
}
sub close_statusfile {
  if($sfopened) {
    close(STAT);
    unlink("$statusfile");
    link("$statusfile.swap", "$statusfile");
    unlink("$statusfile.swap");
    $sfopened = 0;
  }
}
sub parse_config {
  my $filename = shift;
  open(CONF, "<$filename");
  undef(@conflist);
  while(<CONF>) {
    next if /^\s*#/;
    if(/\s*INTERVAL\s+(\d+)\s*;\s*/) {
      set_interval($1);
      next;
    }
    if(/\s*STATUSFILE\s+(\S+)\s*;\s*/) {
      set_statusfile($1);
      next;
    }
    if($current) {
      if(/^\s*(\S+)\s*:\s*(.+)\s*$/) {
	my %kvs;
	$kvs{'type'} = $current;
        $kvs{'object'} = $1;
	my @params = split(/,/, $2);
	grep { $kvs{$1} = $2 if /^\s*(\S+)\s*=>\s*(\S+)\s*$/ } @params;
        push(@conflist, \%kvs);
      } elsif (/^\s*\}\s*$/) {
	$current = undef;
      }
    } else {
      if(/\s*(\S+)\s*\{/) {
	$current = $1;
	next;
      }
    }
  }
  if($current) {
    die "Error while parsing configuration file. $current clause unfinished";
  }
  return \@conflist;
}

1;
