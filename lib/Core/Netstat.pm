package Core::Netstat;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::Netstat - Count the number of connections using netstat

=head1 SYNOPSIS

 Core::Netstat {
     postgres: state => LISTEN, localport => 5432
 }

=head1 DESCRIPTION

This module counts the number of connections using netstat, filtered by
ip, port, or state (e.g. only listening sockets, only established connections)

=head1 CONFIGURATION

=over

=item state

Filter based on the state of the connection. Examples: ESTABLISHED, LISTEN,
TIME_WAIT.

=item localip

Filter based on the local ip of the connection.

=item localport

Filter based on the local port for the connection.

=item remoteip

Filter based on the remote ip of the connection.

=item remoteport

Filter based on the remote port for the connection.

=back

=head1 METRICS

=over

=item count

The count of matching sockets.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $check_name = $self->{check_name}; # The check name is in here

    my $output = cache_command("netstat -an", 30);
    my @lines = split(/\n/, $output);

    # Filter based on config
    @lines = grep(/\s$config->{state}\s*$/, @lines) if($config->{state});
    @lines = grep(/^$config->{localip}/, @lines) if($config->{localip});
    @lines = grep(/^\s*[\w\d\*\.]+.*[\.\:]+$config->{localport}/, @lines)
        if($config->{localport});
    @lines = grep(/[\d\*\.]+\d+\s+$config->{remoteip}/, @lines)
        if($config->{remoteip});
    @lines = grep(/[\d\*\.]+\s+[\d\*\.]+[\.\:]+$config->{remoteport}\s+/,
        @lines) if($config->{remoteport});

    print join('\n', @lines);

    return {
        "count" => [scalar(@lines), "i"]
    };
};

1;
