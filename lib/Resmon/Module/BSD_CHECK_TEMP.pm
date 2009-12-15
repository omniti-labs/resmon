#!/usr/bin/perl
use strict;
package Resmon::Module::BSD_CHECK_TEMP;
use Resmon::Module;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;
my $DEBUG=1;


sub handler {
  my $arg = shift; 
  my ($sensor,$chip)=split('@', $arg->{'object'});
  print STDERR "sensor=$sensor; chip=$chip\n" if $DEBUG;
  $sensor =~s/\+/ /g;
  my $warning = $arg->{'warning'};
  my $critical = $arg->{'critical'};
  $warning = $critical if not $warning;
  my $output = cache_command("sysctl  -n hw.sensors.$chip.$sensor", 30);
  print STDERR $output if $DEBUG;
  my $temp;
  my $units;
  $output =~ m/(-?\d+\.?\d*)\s+(\w+)/;
  ($temp, $units) = ($1, $2);

  return "OK", {
    message => "$temp $units $sensor\@$chip",
    temp => $temp,
  } if ($temp && ($temp < $warning));

  return "WARNING", {
    message => "$temp $units $sensor\@$chip",
    temp => $temp,
  } if ($temp && ($temp < $critical));

  return "BAD", {
    message => "$temp $units $sensor@$chip",
    temp => $temp,
  };
};
1;
  
