#!/usr/bin/perl

register_monitor('INODES', sub {
  my $arg = shift;
  my $os = fresh_status($arg);
  return $os if $os;
  my $devorpart = $arg->{'object'};
  my $output = cache_command("df -i", 30);
  my ($line) = grep(/$devorpart\s*/, split(/\n/, $output));
  if($line =~ /(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%/) {
    if($4 <= $arg->{'limit'}) {
      return set_status($arg, "OK($2 $4% full)");
    }
    return set_status($arg, "BAD($2 $4% full)");
  }
  return set_status($arg, "BAD(no data)");
});

