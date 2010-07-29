package Resmon::Module::SIMPLESVN;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

# A 'simple' subversion checkout freshness check. Unlike FRESHSVN, this check
# doesn't have a grace period, nor does it check for the correct URL being
# checked out. Because of this, this module can be used with an older version
# of subversion that doesn't have support for 'svn info' on remote URLs.
#
# Example config:
#
# SIMPLESVN {
#   /path/to/working/copy : noop
# }

sub handler {
    my $arg = shift;
    my $wc = $arg->{'object'};
    my $output = cache_command("svn st -u -q $wc", 60);
    my @lines = grep { $_ !~ /^\?/ } split(/\n/, $output);
    my $status = scalar(@lines)>1 ? "BAD" : "OK";
    my $revision = 0;
    if($lines[-1] =~ /^Status against revision:\s+(\d+)/) {
      $revision = $1;
    }
    return $status, "$revision";
}

1;
