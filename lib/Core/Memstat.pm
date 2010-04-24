package Core::Memstat;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::Memstat - Monitor memory statistics using vmstat

=head1 SYNOPSIS

 Core::Memstat {
     local : noop
 }

 Core::Memstat {
     local : vmstat_path => /usr/sbin/vmstat
 }

=head1 DESCRIPTION

This module returns statistics on active and free memory.  The type and
number of metrics returned depend on the capabilities of each platform's
respective vmstat command.

=head1 CONFIGURATION

=over

=item check_name

The check name is used for descriptive purposes only.  It is not used
for anything functional.

=item actv_mem

Active virtual pages.

=item free_mem

Free real memory.

=back

=head1 METRICS

=over

=item read_sec

Reads per second.

=item write_sec

Writes per second.

=back

=cut

sub handler {
    my $self = shift;
    my $disk = $self->{'check_name'};
    my $config = $self->{'config'};
    my $vmstat_path = $config->{'vmstat_path'} || 'vmstat';
    my $osname = $^O;

    if ($osname eq 'openbsd') {
        my $output = run_command("$vmstat_path");
        if ($output =~ /.*cs\s+us\s+sy\s+id\n\s+\d+\s+\d+\s+\d+\s+(\d+)\s+(\d+).*/) {
            return {
                'actv_mem' => [$1, 'i'],
                'free_mem' => [$2, 'i']
            };
        } else {
            die "Unable to extract statistics\n";
        }
    } else {
        die "Unsupported platform: $osname\n";
    }
};

1;
