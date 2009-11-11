package Resmon::Module::ZFSYNCHECK;
use strict;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
use Time::Local;
@ISA = qw/Resmon::Module/;
sub handler {
  my $arg=shift;
  my $zfs=$arg->{'object'};
  my $age=$arg->{'age'};
  my $recentsnap = cache_command("zfs list -tsnapshot -H -Screation -oname| grep '^$zfs\@' | head -1", 300);
  return "BAD(no snapshot of $zfs)" if not $recentsnap;
  my $snaptime = cache_command("zfs get -H -p -ovalue creation $recentsnap", 300);
  my $snapage=time()-$snaptime;
  if($snapage < $age) {
    return "OK($snapage < $age)";
  }elsif ($snapage >= $age){
    return "BAD($snapage >= $age)";
  }
  return "BAD(for snapshot $recentsnap we have unexpected creation $snaptime)";
};
1;

