package Resmon::Module::ZFSYNCHECK;
use strict;
use POSIX;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
use Time::Local;
@ISA = qw/Resmon::Module/;
sub handler {
  my $arg=shift;
  my $zfs=$arg->{'object'};
  my $age=$arg->{'age'};
  my $attempt=0;
  my $MAXATTEMPTS=5;
  my $ZFSQUERY="/usr/sbin/zfs list -tsnapshot -H -Screation -oname";
  while (`pgrep -f -l "^$ZFSQUERY"`) {
    if ($attempt++ < $MAXATTEMPTS) {
      sleep(1);
    }
    else {
      return "BAD($ZFSQUERY hanged)";
    }
  }
  my $recentsnap = cache_command("$ZFSQUERY| grep '^$zfs\@' | head -1", 120);
  return "BAD(no snapshot of $zfs)" if not $recentsnap;
  $ZFSQUERY="/usr/sbin/zfs get -H -p -ovalue creation $recentsnap";
  while (`pgrep -f "^$ZFSQUERY"`) {
    if ($attempt++ < $MAXATTEMPTS) {
      sleep(1);
    }
    else {
      return "BAD($ZFSQUERY hanged)";
    }
  }
  my $snaptime = cache_command($ZFSQUERY, 120);
  my $snapage=time()-$snaptime;
  if($snapage < $age) {
    return "OK($snapage < $age)";
  }elsif ($snapage >= $age){
    return "BAD($snapage >= $age)";
  }
  return "BAD($snaptime: for snapshot $recentsnap we have unexpected creation)";
};
1;

