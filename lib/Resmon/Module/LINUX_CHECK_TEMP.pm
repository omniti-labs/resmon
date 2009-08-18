#!/usr/bin/perl
use strict;
package Resmon::Module::LINUX_CHECK_TEMP;
use Resmon::Module;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;
my $DEBUG=0;


sub handler {
  my $arg = shift; 
  my ($sensor,$chip)=split('@', $arg->{'object'});
  print STDERR "sensor=$sensor; chip=$chip\n" if $DEBUG;
  $sensor =~s/\+/ /g;
  my $warning = $arg->{'warning'};
  my $critical = $arg->{'critical'};
  $warning = $critical if not $warning;
  my $output = cache_command("/usr/bin/sensors $chip", 30);
  print STDERR $output if $DEBUG;
  my @lines = split(/\n/, $output);
  my ($temp,$continues);
  for my $line (@lines) {
    if ($line =~ /^$sensor:\s*[+-]?([\d.]+)/) {
	  $temp=$1;
	  ## print "case 1 temp:$temp line $line\n" if $DEBUG>1;
	  last;
	}
	elsif($line =~ /^$sensor:/){
	  $continues = 1;
	  ## print "case 2 continues: $line\n" if $DEBUG>1;
	}elsif ($line =~ /^\S/) {
      $continues = 0;
	  ## print "case 3 discontinues: $line\n" if $DEBUG>1;
	}
    if($continues && $line =~ /^\s*[+-]?([\d.]*)°C/){
      $temp=$1;
	  ## print "case 4  temp:$temp line $line\n" if $DEBUG>1;
      last; 
    }
	## print "case 5 continues=$continues  and line $line\n" if $DEBUG>1;
  }
  return "OK($temp $sensor\@$chip)" if ($temp && ($temp<$warning));
  return "WARNING($temp $sensor\@$chip)" if ($temp && ($temp<$critical));
  return "BAD($temp $sensor@$chip)";
};
1;
