package Core::Postgres;

use strict;
use warnings;

use base 'Resmon::Module';
use DBI;

=pod

=head1 NAME

Core::Postgres - check Postgres

=head1 SYNOPSIS

Core::Postgres {
   check_name: host => 'localhost', port => 5432, user => 'someuser', pass => 'somepass', params => ['10 seconds']
}

=head1 DESCRIPTION

This module checks Postgres.

=head1 CONFIGURATION

=over

=item check_name

The check to run.

=item host

The host to connect to

=item port

The port that the service listens on.  This defaults to 5432.

=item user

The username to connect as.

=item pass

The password to connect with.

=item params

An array ref of params to pass to the query.

=back

=head1 METRICS

This check returns the metrics from the selected check.

=cut

=head1 NOTES

None.

=cut

my %checks = (
    slave_lag => {
        query => q[select
    extract(epoch from lag) as slave_lag,
    extract(epoch from max_lag) as max_slave_lag,
    coalesce(lag <= max_lag + coalesce($1::interval,'0 seconds'::interval),true) as ok
from
    (select
        now() - pg_last_xact_replay_timestamp() as lag,
        greatest((nullif(current_setting('max_standby_streaming_delay'),'-1'))::interval,(nullif(current_setting('max_standby_archive_delay'),'-1'))::interval) as max_lag)],
        param_count => 1
    },
);

sub handler
{
    my $self = shift;
    my $config = $self->{'config'};

    my $query = $checks{ $self->{'check_name'} }{'query'};
    my $param_count = $checks{ $self->{'check_name'} }{'param_count'};
    my $host = $self->{'host'} || 'localhost';
    my $port = $config->{'port'} || 5432;
    my $user = $config->{'user'} || 'postgres';
    my $pass = $config->{'pass'};
    my @params = ();

    if (defined($config->{'params'}) and ref($config->{'params'}) eq "ARRAY")
    {
        @params = @{ $config->{'params'} };
    }

    if (scalar(@params) < $param_count)
    {
        push @params, (undef) x ($param_count - scalar(@params));
    }

    my $dbh = DBI->connect("DBI:Pg:host=$host;port=$port", $user, $pass);

    my $sth = $dbh->prepare($query);
    $sth->execute(@params);

    my $metrics = $sth->fetchrow_hashref();

    return $metrics;
};

1;
