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
     sda : smartctl_cmd => /usr/sbin/smartctl , smartctl_args => -d sat
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

=back

=head1 METRICS

Each of the following metric names will be prefixed with the disk name.

The SMART attribute data is highly vendor-specific.  Post-processing may be
desirable in specific cases, such as when the value as hex has special meaning.

=over

=item model

Device model as reported in the information section.

=item serial

Device serial number as reported in the information section.

=item fw

Device firmware version as reported in the information section.

=item (attribute)

Each attribute reported in the data section will be returned by name.  The value
will be the normalized value and is expected to be an integer.

=item (attribute)_raw

The raw value of the attribute, expected to be an integer.

=back

=cut

sub new {
    # This is only needed if you have initialization code. Most of the time,
    # you can skip the new method and just implement a handler method.
    my ($class, $check_name, $config) = @_;
    my $self = $class->SUPER::new($check_name, $config);

    # Add initialization code here

    bless($self, $class);
    return $self;
}

sub handler {
    my $self = shift;
    my $config = $self->{config};
    my $disk;
    $disk = "/dev/$self->{check_name}" if $^O eq "linux";
    $disk = "/dev/r$self->{check_name}" if $^O =~ /bsd/;
    $disk = "/dev/rdsk/$self->{check_name}" if $^O eq "solaris";
    my $smartctl_cmd = $config->{smartctl_cmd} || "/usr/sbin/smartctl";
    my $smartctl_args = "-i -A"; 
    $smartctl_args = "$smartctl_args $config->{smartctl_args}" if $config->{smartctl_args};
    my $smartdata = {};
    my $output = run_command("$smartctl_cmd $smartctl_args $disk");

    foreach my $line (split(/\n/, $output)) {
        if ($line =~ /^Device Model:\s+(.+)$/) {
            $smartdata->{"$self->{check_name}_model"} = [$1, "s"];
        }
        elsif ($line =~ /^Serial Number:\s+(.+)$/) {
            $smartdata->{"$self->{check_name}_serial"} = [$1, "s"];
        }
        elsif ($line =~ /^Firmware Version:\s+(.+)$/) {
            $smartdata->{"$self->{check_name}_fw"} = [$1, "s"];
        }
	# Capture attribute_name, value, raw_value (columns 2,4,10)
        elsif ($line =~ /^\s*\d+\s(\S+)\s+\S+\s+(\S+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+(\S+)/) {
            $smartdata->{"$self->{check_name}_$1"} = [$2, "i"];
            $smartdata->{"$self->{check_name}_$1_raw"} = [$3, "i"];
        }
    }

    return $smartdata;
};
1;
