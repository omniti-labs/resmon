#!/usr/bin/perl

my %commhist;
my %commcache;

sub cache_command {
  my $command = shift;
  my $expiry = shift;
  my $now = time;
  if($commhist{$command}>$now) {
    return $commcache{$command};
  }
  $commcache{$command} = `$command`;
  $commhist{$command} = $now + $expiry;
  return $commcache{$command};
}

1;
