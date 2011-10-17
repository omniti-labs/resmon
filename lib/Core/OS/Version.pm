package Core::OS::Version;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::OS::Version - Report operating system version info

=head1 SYNOPSIS

 Core::OS::Version {
     local: noop
 }

 Core::OS::Version {
     local: uname_path => /usr/bin/uname
 }

=head1 DESCRIPTION

This module reports operating system name and version using the uname command.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=item uname_path

Provide an alternate path to uname (optional).

=back

=head1 METRICS

=over

=item uname_tuple

The string returned by uname which includes OS name, release level and version.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $uname_path = $config->{uname_path} || 'uname';

    my $output = run_command("$uname_path -srv");
    chomp $output;

    return {
        "uname_tuple" => [$output, "s"]
    };
};

1;
