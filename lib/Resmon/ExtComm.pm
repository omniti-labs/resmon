package Resmon::ExtComm;

use strict;
require Exporter;
use vars qw/@ISA @EXPORT/;

@ISA = qw/Exporter/;
@EXPORT = qw/cache_command/;

my %commhist;
my %commcache;

sub cache_command($$;$) {
  my ($command, $expiry, $timeout) = @_;
  $timeout ||= $expiry;

  my $now = time;
  if($commhist{$command}>$now) {
    return $commcache{$command};
  }
  # TODO: timeouts
  $commcache{$command} = `$command`;
  $commhist{$command} = $now + $expiry;
  return $commcache{$command};
}

1;
