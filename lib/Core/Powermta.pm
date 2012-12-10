package Core::Powermta;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);

=pod

=head1 NAME

Core::Powermta - Monitor powermta statistics using sysctl

=head1 SYNOPSIS

 Core::Powermta {
     local : 'show_status' => 'status.traffic.total.out.msg,status.queue.smtp.rcp'
 }

=head1 DESCRIPTION

This module uses the pmta command line tool and its DOM output format to check
on the status of the powermta mailer running on the local machine.

=head1 CONFIGURATION

=over

=item 'show status'

This configuration key takes a list of comma-separated MIB values to
look up with the `pmta show status` command, and will report their
values.

=back

=head1 METRICS

The metrics returned by this module vary by check used:

=head2 `SHOW STATUS` METRICS

This method can reference any check supported by the `pmta show status`
command.

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config};
    if(my $show_status_keys = $config->{show_status}) {
        my $raw_lines = run_command(qw/pmta --dom show status/);
        my @lines = split /\n/, $raw_lines;
        if(!@lines) {
            die "Error running `pmta --dom show status`!\n";
        }
        my $mib_map = parse_pmta_output(\@lines);
        my @show_status_keys = split /,/, $show_status_keys;
        my $wanted_pairs = { map { $_ => $mib_map->{$_} } @show_status_keys };
        return $wanted_pairs;
    }
};

sub parse_pmta_output {
    my ($raw_lines) = @_;
    chomp @$raw_lines;
    my $mib_map;
    for my $line (@$raw_lines) {
        my ($key, $value) = $line =~ /([^=]+)\s*=\s*"?([^"]+)"?/; 
        next unless defined $value;
        $mib_map->{$key} = $value;
    }
    return $mib_map;
}

1;
