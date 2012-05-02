package Core::PostgresReplayLag;

use strict;
use warnings;

use base 'Resmon::Module';

use Time::Local;

=pod

=head1 NAME

Core::PostgresReplayLag - Monitor postgres replay lag

=head1 SYNOPSIS

 Core::PostgresReplayLag {
    pg : logdir => /data/set/foo/pgdata/82/pg_log
 }

=head1 DESCRIPTION

This module monitors how long it's been since a postgres replay log was
restored.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=item logdir

Postgres log directory

=back

=head1 METRICS

=over

=item lag

The number of seconds since the last restore.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here

    opendir(my $dh, $config->{logdir});
    my @files = sort grep /^postgresql-[\d-]+_?\d*\.log$/, readdir($dh);
    closedir($dh);
    my $wallog = $files[-1];

    open(my $fh, "<", "$config->{logdir}/$wallog");
    my @lines = grep(/LOG:  restored log file/, <$fh>);
    close($fh);

    if ($#lines < 0) {
        return { "error" => ["Nothing restored", "s"] }
    }

    my ($year,$month,$day,$hour,$min) = (
        $lines[-1] =~ /^(\d\d\d\d)-(\d\d)-(\d\d)\s(\d+):(\d+)/ );

    my $restoretime = timelocal(0,$min,$hour,$day,$month-1,$year);
    my $now = time();

    my $lag = $now - $restoretime;

    return {
        "lag" => [$lag, "i"]
    };
};

1;
