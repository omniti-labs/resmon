package Core::File;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::File - information about a single file

=head1 SYNOPSIS

 Core::File {
     /path/to/filename: noop
 }

=head1 DESCRIPTION

This module retrieves metrics on a single file such as file age and file size.

=head1 CONFIGURATION

=over

=item check_name

The check name specifies which file to monitor.

=back

=head1 METRICS

=over

=item present

Does the file exist? 1 for yes, 0 for no. If the file does not exist, the
other metrics will not be present.

=item permissions

The file's permissions in numeric format: e.g. 0777.

=item hardlinks

The number of hard links to the file.

=item uid, gid

The user and group ids of the file.

=item size

The file size in bytes.

=item atime, mtime, ctime

The file's access time, modification time, and inode change time respectively.
All of these are in seconds since the epoch.

=item aage, mage, cage

How long ago in seconds the file was accessed, modified, and changed
respectively.

The difference between mtime/mage and ctime/cage is that mtime only changes
when the file's contents change. Ctime changes when anything about the file
(permissions etc) change.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $file = $self->{check_name}; # The check name is in here
    my @statinfo = stat($file);

    if (!@statinfo) {
        # File is missing
        return {
            "present" => [0, "i"]
        }
    } else {
        my $now = time;
        return {
            "present" =>    [1, "i"],
            "permissions" => [sprintf("%04o", $statinfo[2] & 07777), "s"],
            "hardlinks" =>  [$statinfo[3], "i"],
            "uid" =>        [$statinfo[4], "s"],
            "gid" =>        [$statinfo[5], "s"],
            "size" =>       [$statinfo[7], "i"],
            "atime" =>      [$statinfo[8], "i"],
            "mtime" =>      [$statinfo[9], "i"],
            "ctime" =>      [$statinfo[10], "i"],
            "aage" =>       [$now - $statinfo[8], "i"],
            "mage" =>       [$now - $statinfo[9], "i"],
            "cage" =>       [$now - $statinfo[10], "i"]
        };
    };
};

1;
