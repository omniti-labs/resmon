package Extra::OmniPITR;

use strict;
use warnings;

use base 'Resmon::Module';
use File::Spec;

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Extra::OmniPITR - a sample/template resmon module

=head1 SYNOPSIS

 Extra::OmniPITR {
    archive-queue : omnipitr_path => /opt/omnipitr/bin, log_path => /var/log/postgresql/omnipitr-archive-^Y-^m-^d.log, state_path => /var/lib/postgresql/9.1/omnipitr/state -U postgres
    last-archive-age : omnipitr_path => /opt/omnipitr/bin, log_path => /var/log/postgresql/omnipitr-archive-^Y-^m-^d.log, state_path => /var/lib/postgresql/9.1/omnipitr/state 
 }

=head1 DESCRIPTION

This module is for monitoring the status of OmniPITR (https://github.com/omniti-labs) using its built in omnipitr-monitor module. All options that omnipitr-monitor has able to be passed as options in resmon.conf. For more details on the check arguments, see https://github.com/omniti-labs/omnipitr/blob/master/doc/omnipitr-monitor.pod

Note: The 'error' check is not currently supported since this resmon module can only return an integer value at this time.

=head1 CONFIGURATION

=over

=item check_name

The name of the CHECK as defined in omnipitr for the --check (-c) option.

=item omnipitr_path

Path to the omnipitr binary folder (ex. /opt/omnipitr/bin). Assumes binaries are in $PATH otherwise.

=item state_path

Same as --state (-s) option

=item log_path

Same as --log (-l) option

=item database

Same as --database (-d) option

=item host

Same as --host (-h) option

=item port

Same as --port (-p) option

=item username

Same as username (-U) option

=item psql_path

Same as --psql-path (-pp) option

=item temp_path

Same as --temp-dir (-t) option


=back

=head1 METRICS

=over

=item check_name

The name of the CHECK as defined in omnipitr for the --check (-c) option.

=item value

Value returned by the check. Will be an integer representing either time in seconds or a count depending on which check you ran.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $check = $self->{check_name}; # The check name is in here

    my $monitor_cmd = 'omnipitr-monitor';

    if (defined($config->{omnipitr_path})) {
        $monitor_cmd = File::Spec->catdir($config->{omnipitr_path}, $monitor_cmd);
    }
    
    $monitor_cmd .= ' -c ' . $check ;
    $monitor_cmd .= ' -s ' . $config->{state_path};
    if (defined($config->{log_path})) {
        $monitor_cmd .= ' -l ' . $config->{log_path};
    }
    if (defined($config->{database})) {
        $monitor_cmd .= ' -d ' . $config->{database};
    }
    if (defined($config->{host})) {
        $monitor_cmd .= ' -h ' . $config->{host};
    }
    if (defined($config->{port})) {
        $monitor_cmd .= ' -p ' . $config->{port};
    }
    if (defined($config->{username})) {
        $monitor_cmd .= ' -U ' . $config->{username};
    }
    if (defined($config->{psql_path})) {
        $monitor_cmd .= ' -pp ' . $config->{psql_path};
    }
    if (defined($config->{temp_path})) {
        $monitor_cmd .= ' -t ' . $config->{temp_path};
    }

    my $value = run_command($monitor_cmd);

    return {
        "check_name" => [$self->{check_name}, "s"],
        "value" => [$value, "i"]
    };
};

1;
