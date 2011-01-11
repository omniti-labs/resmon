package Core::PostgresMaster;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::PostgresMaster - a sample/template resmon module

=head1 SYNOPSIS

 Core::PostgresMaster {
     postgres_state: pgdata => /data/postgres/pgdata
 }

=head1 DESCRIPTION

This module detects whether a postgres database is master or slave by looking
for the presence or absence of a recovery.conf file in the pgdata directory.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.
Some checks use the check_name as part of the configuration, such as
free space checks that specify the filesystem to use.

=item pgdata

The path to the pgdata directory.

=back

=head1 METRICS

=over

=item state

The state of the database as a string - master or slave.

=back

=cut

sub handler {
    my $self = shift;
    unless (exists($self->{config}->{pgdata})) {
        return {
            "error" => ["Pgdata path is undefined", "s"]
        }
    };
    my $state;
    if (-e "$self->{config}->{pgdata}/recovery.conf") {
        $state = "slave";
    } else {
        $state = "master";
    };
    return {
        "state" => [$state, "s"],
    };
};

1;
