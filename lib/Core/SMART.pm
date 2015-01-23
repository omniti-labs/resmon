package Core::SMART;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::SMART - pulls SMART values from disk drives

=head1 SYNOPSIS

 Core::SMART {
     sda : smartctl_cmd => /usr/sbin/smartctl , smartctl_args => -d sat\,12
 }

=head1 DESCRIPTION

Self-Monitoring, Analysis and Reporting Technology (SMART) allows for detecting
errors and reporting on reliability indicators on hard disk drives.

This module pulls the specified values from the output of the smartctl utility.
For more information on smartctl, see http://smartmontools.sourceforge.net/

=head1 CONFIGURATION

=over

=item check_name

This indicates the disk argument to be given to smartctl.  Expects the basename
of the device, not the full path, e.g. "sda" not "/dev/sda".

=item smartctl_cmd

The full path of the smartctl command.  Defaults to /usr/sbin/smartctl.

=item smartctl_args

Optional list of additional arguments that will be passed to smartctl.  
The default arguments are "-i -A".  Any arguments specified here will be 
added to this list.

If the argument contains a comma, it must be escaped with a backslash.

=back

=head1 METRICS

The SMART attribute data is highly vendor-specific.  Each attribute will produce
two metrics, one with the normalized value and one with the raw value.

Post-processing may be desirable in specific cases, such as when the value as
hex has special meaning.

=over

=item model

Device model as reported in the information section.

=item serial

Device serial number as reported in the information section.

=item fw

Device firmware version as reported in the information section.

=item (attribute)

The normalized value of the attribute, expected to be an integer.

=item (attribute)_raw

The raw value of the attribute, expected to be an integer.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config};
    my $disk;
    $disk = "/dev/$self->{check_name}" if ($^O eq "linux") || ($^O =~ /bsd/) ;
    $disk = "/dev/rdsk/$self->{check_name}" if $^O eq "solaris";
    my $smartctl_cmd = $config->{smartctl_cmd} || "/usr/sbin/smartctl";
    my $smartctl_args = "-i -A"; 
    $smartctl_args = "$smartctl_args $config->{smartctl_args}" if $config->{smartctl_args};
    my $smartdata = {};
    my $output = run_command("$smartctl_cmd $smartctl_args $disk");

    foreach my $line (split(/\n/, $output)) {
        if ($line =~ /^Device Model:\s+(.+)$/) {
            $smartdata->{"model"} = [$1, "s"];
        }
        elsif ($line =~ /^Serial Number:\s+(.+)$/) {
            $smartdata->{"serial"} = [$1, "s"];
        }
        elsif ($line =~ /^Firmware Version:\s+(.+)$/) {
            $smartdata->{"fw"} = [$1, "s"];
        }
	# Capture attribute_name, value, raw_value (columns 2,4,10)
        elsif ($line =~ /^\s*\d+\s(\S+)\s+\S+\s+(\S+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)/) {
            $smartdata->{"$1"} = [$2, "i"];
            $smartdata->{"$1_raw"} = [$3, "i"];
        }
    }

    return $smartdata;
};
1;
