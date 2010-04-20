package Core::DiskInodes;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::DiskInodes - Monitor disk inode usage using df

=head1 SYNOPSIS

 Core::DiskInodes {
     /    : noop
     /usr : noop
     /var : noop
 }

 Core::DiskInodes {
     / : dfcmd => /bin/df, dfregex => (\d+)\s+(\d+)\s+(\d+)\s+(\d+)%
 }

=head1 DESCRIPTION

This module monitors the used/free inodes for a filesystem using the df
command.

=head1 CONFIGURATION

=over

=item check_name

The name of the check refers to the filesystem to check the inodes on. It can
specify either the mountpoint or the device for the filesystem.

=item dfcmd

This specifies the df command (including arguments) to run in the event that
the default is not sufficient. It is optional and in most cases you do not
need to set this.

=item dfregex

This specifies the a regex to match the output of the df command against in
the event that the version of df used outputs a different format than is
expected by this module. In most cases it is not required and matches are
provided for Linux, OpenBSD and Solaris.

The regex should contain 3 matching groups. They should match the used inodes,
free inodes, and percent used respectively.

=back

=head1 METRICS

=over

=item inodes_used

A count of the used inodes on the filesystem.

=item inodes_free

A count of the free inodes on the filesystem.

=item used_percent

The percentage of the total inodes that are used.

=back

=cut

sub new {
    # This is only needed if you have initialization code. Most of the time,
    # you can skip the new method and just implement a handler method.
    my ($class, $check_name, $config) = @_;
    my $self = $class->SUPER::new($check_name, $config);

    # Come up with a sensible default for the df command args
    if ($^O eq 'solaris') {
        $self->{default_dfcmd} = 'df -Fufs -oi';
        $self->{default_dfregex} = '\d+\s+(\d+)\s+(\d+)\s+(\d+)%';
    } elsif ($^O eq 'openbsd') {
        $self->{default_dfcmd} = 'df -i';
        $self->{default_dfregex} = \
            '\d+\s+\d+\s+-?\d+\s+\d+%\s+(\d+)\s+(\d+)\s+(\d+)%';
    } else {
        $self->{default_dfcmd} = 'df -iP';
        $self->{default_dfregex} = '\d+\s+(\d+)\s+(\d+)\s+(\d+)%';
    }

    bless($self, $class);
    return $self;
}

sub handler {
    my $self = shift;
    my $config = $self->{config};
    my $fs = $self->{check_name};
    my $dfcmd = $config->{dfcmd} || $self->{default_dfcmd};
    my $dfregex = $config->{dfregex} || $self->{default_dfregex};

    my $output = run_command("$dfcmd $fs");
    my ($line) = grep(/$fs\s*/, split(/\n/, $output));
    if($line =~ /$dfregex/) {
        return {
            "used_inodes" => [$1, "i"],
            "free_inodes" => [$2, "i"],
            "used_percent" => [$3, "i"]
        };
    } else {
        # We couldn't match the output line
        return {
            "error" => ["Unable to get free inode count", "s"]
        }
    }
};

1;
