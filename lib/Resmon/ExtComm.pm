package Resmon::ExtComm;

use strict;
require Exporter;
use vars qw/@ISA @EXPORT/;

@ISA = qw/Exporter/;
@EXPORT = qw/cache_command run_cmd/;

my %commhist;
my %commcache;
my %children;

sub cache_command($$;$) {
  my ($command, $expiry, $timeout) = @_;
  $timeout ||= $expiry;

  my $now = time;
  if($commhist{$command}>$now) {
    return $commcache{$command};
  }
  # TODO: timeouts
  $commcache{$command} = run_cmd($command);
  $commhist{$command} = $now + $expiry;
  return $commcache{$command};
}

sub clean_up {
    # Kill off any child processes started by run_cmd and close any pipes to
    # them. This is called when a check times out and we may have processes
    # left over.
    while (my ($pid, $handle) = each %children) {
        kill 9, $pid;
        close ($handle);
        delete $children{$pid};
    }
}

sub run_cmd {
    # Run a command just like `cmd`, but store the pid and stdout handles so
    # they can be cleaned up later. For use with alarm().
    my $cmd = shift;
    pipe(my ($r, $w));
    my $pid = fork();
    if($pid) {
        close($w);
        $children{$pid} = $r;
        my @lines = <$r>;
        waitpid($pid, 0);
        delete $children{$pid};
        return join("", @lines);
    } else {
        eval {
            open(STDOUT, ">&", $w);
            close($r);
            exec($cmd);
        };
        exit();
    }
}

1;
