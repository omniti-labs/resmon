package Core::Pgrep;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);

=pod

=head1 NAME

Core::Pgrep - Check for running processes using pgrep

=head1 SYNOPSIS

 Core::Pgrep {
     myproc : pattern => foo.sh -c foo, fullcmd => 1
 }

 Core::Pgrep {
     myproc : pgrep_path => /bin/pgrep, pattern => foo.sh

=head1 DESCRIPTION

This module is a sample resmon module that demonstrates how to write and use a
resmon module, as well as exposing some features modules can use.
Documentation for a module should be done using pod (see B<perldoc perlpod>).

To read the documenation, use B<perldoc Pgrep.pm>.

To verify the documentatioe, use B<podchecker Pgrep.pm>.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=item pattern

The name of the process (or command line if full is used) to match against.

=item full

Set this to 1 to match on the full command line. This passes the '-f' option
to pgrep.

=item pgrep_path

Specify an alternate path to pgrep. Optional.

=back

=head1 METRICS

=over

=item process_count

How many matching processes are running.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $pgrep_path = $config->{pgrep_path} || 'pgrep';
    my $full = $config->{full} ? "f" : "";

    my $count = run_command("$pgrep_path", "-c$full", "$config->{pattern}");
    die "Unable to run pgrep command\n" if (!defined($count));
    chomp $count;

    if ($count =~ /^\d+$/) {
        return {
            "process_count" => [$count, "i"]
        };
    } else {
        # We didn't get a count as expected. This can happen if you didn't
        # provide a pattern or something else went wrong.
        die "Pgrep gave unexpected output: $count\n";
    };
};

1;
