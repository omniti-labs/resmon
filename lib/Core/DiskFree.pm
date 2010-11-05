package Core::DiskFree;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::DiskFree - Monitor disk free space using df

=head1 SYNOPSIS

 Core::DiskFree {
     /    : noop
     /usr : noop
     /var : noop
 }

 Core::DiskFree {
     / : dfcmd => /bin/df -kP
 }

 Core::DiskFree {
    * : noop
 }

=head1 DESCRIPTION

This module monitors the used/free space for a filesystem using the df
command.

Note: For ZFS filesystems, you should use the ZpoolFree module instead of
this one to measure free space.

=head1 CONFIGURATION

=over

=item check_name

The name of the check refers to the filesystem to check the free space on. It
can specify either the mountpoint or the device for the filesystem. If * is
specified, fetch metrics for all mounted filesystems.

=item dfcmd

This specifies the df command (including arguments) to run in the event that
the default is not sufficient. It is optional and in most cases you do not
need to set this.

=item excludes

This is only used when * is specified for the check name. It contains a regex
of filesystems to exclude from the results. If this isn't specified, a default
regex is used that will exclude various common filesystems that aren't 'real'
such as /proc or swap.

=back

=head1 METRICS

=over

=item used_KB

The used disk space in KB.

=item free_KB

The free disk space in KB.

=item used_percent

The percentage of the disk that is full.

=back

=cut

sub new {
    # This is only needed if you have initialization code. Most of the time,
    # you can skip the new method and just implement a handler method.
    my ($class, $check_name, $config) = @_;
    my $self = $class->SUPER::new($check_name, $config);

    # Come up with a sensible default for the df command args
    $self->{default_dfcmd} = ($^O eq 'linux') ? 'df -kP' : 'df -k';

    bless($self, $class);
    return $self;
}

sub handler {
    my $self = shift;
    my $config = $self->{config};
    my $fs = $self->{check_name};
    my $dfcmd = $config->{dfcmd} || $self->{default_dfcmd};

    my $output = run_command("$dfcmd $fs");
    my ($line) = grep(/$fs\s*/, split(/\n/, $output));
    if($line =~ /(\d+)\s+(\d+)\s+(\d+)%/) {
        return {
            "used_KB" => [$1, "L"],
            "free_KB" => [$2, "L"],
            "used_percent" => [$3, "i"]
        };
    } else {
        # We couldn't get the free space
        die "Unable to get free space\n";
    }
};

sub wildcard_handler {
    my $self = shift;
    my $config = $self->{config};
    my $dfcmd = $config->{dfcmd} || $self->{default_dfcmd};
    my $excludes = $config->{excludes};
    if (!defined $excludes) {
        # Exclude some default 'fake' filesystems
        $excludes = "^(none|swap|proc|ctfs|mnttab|objfs|fd)\$";
    }
    my $metrics = {};

    my $output = run_command("$dfcmd");
    for my $line (split /\n/, $output) {
        if($line =~ /^(\S+)\s+\d+\s+(\d+)\s+(\d+)\s+(\d+)%/) {
            my ($fs, $used, $free, $percent) = ($1, $2, $3, $4);
            next if $fs =~ /$excludes/;
            $metrics->{$fs} = {
                "used_KB" => [$used, "L"],
                "free_KB" => [$free, "L"],
                "used_percent" => [$percent, "i"]
            };
        }
    }
    if (!%$metrics) {
        die "Unable to get free space\n";
    }
    return $metrics;
}

1;
