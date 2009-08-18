#!/usr/bin/perl
use strict;
package Resmon::Module::CHECK_DISK_TEMP;
use Resmon::Module;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;
my $DEBUG=2;


sub handler {
  my $arg = shift; 
  my $disk=$arg->{'object'};
  print STDERR "disk: $disk\n" if $DEBUG>1;
  my $warning = $arg->{'warning'};
  print STDERR "warning: $warning\n" if $DEBUG>1;
  my $critical = $arg->{'critical'};
  print STDERR "critical: $critical\n" if $DEBUG>1;
  $warning = $critical if not $warning;
  my $output = cache_command("/usr/sbin/smartctl -a /dev/$disk", 30);
  print STDERR "output:$output\n" if $DEBUG>1;
  my ($line) = grep (/Current Drive Temperature/, split(/\n/, $output));
  print STDERR "line:$line\n" if $DEBUG>1;
  print STDERR "arr:",join("|",split(/\s+/,$line)),"\n" if $DEBUG>1;
  my $temp = (split(/\s+/,$line))[3];
  return "OK($temp $disk)" if ($temp && ($temp<$warning));
  return "WARNING($temp disk)" if ($temp && ($temp<$critical));
  return "BAD($temp $disk)";
};
1;
