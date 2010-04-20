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

=head1 DESCRIPTION

This module monitors the used/free space for a filesystem using the df
command.

Note: For ZFS filesystems, you should use the ZpoolFree module instead of
this one to measure free space.

=head1 CONFIGURATION

=over

=item check_name

The name of the check refers to the filesystem to check the free space on. It
can specify either the mountpoint or the device for the filesystem.

=item dfcmd

This specifies the df command (including arguments) to run in the event that
the default is not sufficient. It is optional and in most cases you do not
need to set this.

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
            "used_KB" => [$1, "i"],
            "free_KB" => [$2, "i"],
            "used_percent" => [$3, "i"]
        };
    } else {
        # We couldn't get the free space
        return {
            "error" => ["Unable to get free space", "s"]
        }
    }
};

1;
