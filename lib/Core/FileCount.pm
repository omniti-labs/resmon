package Core::FileCount;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::FileCount - count files matching specified criteria

=head1 SYNOPSIS

 Core::FileCount {
     /path/to/directory: noop
 }

 Core::FileCount {
     /var/log : max_age => 86400, max_size => 1048576
 }

=head1 DESCRIPTION

This module will return the number of files in a directory that match
specified criteria. For example, the module can be configured to return how
many files are over 1MB in size, or were modified more than 2 days ago.

If no filter criteria are specified, then the module will simply return a
count of all files in the directory.

=head1 CONFIGURATION

=over

=item check_name

The check name specified which directory to look for files in.

=item real_files

Optional. Should only real files (as determined by perl's '-f' test) be
considered? 1 for yes, 0 or absent for no.

=item filename

Optional. A regular expression to match filenames on. A file is only included
in the count if the filename (not including any pathname) matches the pattern.

=item min_size, max_size

Optional. Limit the file count to files that have a minimum or maximum size as
specified. The size is in bytes.

=item min_modified, max_modified

Optional. Limit the file count to files that were modified at least
(min_modified) or at most (max_modified) N seconds ago.

=item min_accessed, max_accessed

Optional. Limit the file count to files that were accessed at least
(min_accessed) or at most (max_accessed) N seconds ago.

=item min_changed, max_changed

Optional. Limit the file count to files that were changed (uses a file's
ctime) at least (min_changed) or at most (max_changed) N seconds ago.

=item uid, gid

Optional. Limit the file count to files that are owned by the specified user
or group.

=item not_uid, not_gid

Optional. Simile to uid, gid, but only count files that are not owned by the
specified user or group.

=item permissions

Optional. Limit the file count to files that have the specified permissions.
This is a regular expression, so you can do things like "0[67][45]0" as well
as a simple string: "0755".

=back

=head1 METRICS

=over

=item count

The count of files matching the criteria.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $dirname = $self->{check_name}; # The check name is in here

    opendir(my $dir, $dirname) || die "Unable to access directory $dirname\n";
    my $now = time;
    my $count = 0;
    while (my $file = readdir($dir)) {
        # Make sure we're actually counting files if desired
        next if ($config->{real_files} && ! -f "$dirname/$file");
        # Ignore . and ..
        next if ($file =~ /^\.\.?$/);
        # Filename pattern
        next if ($config->{filename} && $file !~ /$config->{filename}/);
        my @fileinfo = stat "$dirname/$file";
        # Access time
        next if ($config->{min_accessed} &&
            ($now - $fileinfo[8]) < $config->{min_accessed});
        next if ($config->{max_accessed} &&
            ($now - $fileinfo[8]) > $config->{max_accessed});
        # Modification time
        next if ($config->{min_modified} &&
            ($now - $fileinfo[9]) < $config->{min_modified});
        next if ($config->{max_modified} &&
            ($now - $fileinfo[9]) > $config->{max_modified});
        # Change time
        next if ($config->{min_changed} &&
            ($now - $fileinfo[10]) < $config->{min_changed});
        next if ($config->{max_changed} &&
            ($now - $fileinfo[10]) > $config->{max_changed});
        # File size
        next if ($config->{min_size} && $fileinfo[7] < $config->{min_size});
        next if ($config->{max_size} && $fileinfo[7] > $config->{max_size});
        # UID/GID
        next if ($config->{uid} && $fileinfo[4] ne $config->{uid});
        next if ($config->{gid} && $fileinfo[5] ne $config->{gid});
        # UID/GID inverse
        next if ($config->{not_uid} && $fileinfo[4] eq $config->{not_uid});
        next if ($config->{not_gid} && $fileinfo[5] eq $config->{not_gid});
        # Permissions
        next if ($config->{permissions} &&
            sprintf("%04o", $fileinfo[2] & 07777) !~ /$config->{permissions}/);
        # We passed all filters, yay!
        $count++;
    }
    closedir($dir);

    return {
        "count" => [$count, "i"],
    };
};

1;
