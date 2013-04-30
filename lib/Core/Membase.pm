package Core::Membase;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);

=pod

=head1 NAME

Core::Membase - A resmon module for gathering Membase statistics

=head1 SYNOPSIS

 Core::Membase {
     127.0.0.1: user => foo, pass => bar
 }

=head1 DESCRIPTION

This module gathers Membase statistics

=head1 CONFIGURATION

=over

=item check_name

The IP or FQDN of the Membase server.

=item mbstats

The location of the mbstats command. Defaults to /opt/membase/bin/mbstats.

=item port

The port that the target service listens on.  This defaults to 11210.

=item user

The username to connect with.

=item pass

The password to connect with.

=back

=head1 METRICS

This check returns a significant number of metrics. See the following for
explanations:

  https://github.com/membase/ep-engine/blob/master/docs/stats.org

=cut

sub handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $host = $self->{'check_name'};
    my $port = $config->{'port'} || "11210";
    my $user = $config->{'user'} || "";
    my $pass = $config->{'pass'} || "";
    my $mbstats = $config->{'mbstats'} || "/opt/membase/bin/mbstats";
    my $mbstats_path = "$mbstats -a $host:$port all $user $pass";

    my $output = run_command($mbstats_path);
    chomp $output;
    my @arr = split("\n", $output);

    my $line;
    my $bucket = "";
    my $get_name = 0;
    my %metrics;
    foreach $line (@arr) {
        if ($line =~ /\*/) {
            $get_name = 1;
            next;
        }
        if ($get_name == 1) {
            $line =~ s/\s+// ;
            $bucket = $line;
            $get_name = 0;
            next;
        }
        if ($line ne "") {
            $line =~ s/\s+//g;
            my ($key, $val) = split(":", $line);
            $metrics{"$bucket|$key"} = $val;
        }
    }

    return \%metrics

};

1;
