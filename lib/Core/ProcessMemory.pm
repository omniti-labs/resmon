package Core::ProcessMemory;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command);

=pod

=head1 NAME

Core::ProcessMemory - Memmory usage of processes

=head1 SYNOPSIS

 Core::ProcessMemory {
     myproc : pattern => foo.sh -c foo
 }

 Core::ProcessMemory {
     myproc : pgrep_path => /bin/pgrep, pattern => foo.sh

=head1 DESCRIPTION

This module uses pgrep in full mode to obtain a list of process IDs, then totals several memory statistics for those processes.  The totals are then reported.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.

=item pattern

The patter to match against the command line (as used by pgrep -f)

=item pgrep_path

Specify an alternate path to pgrep. Optional.

=back

=head1 METRICS

=over

=item process_count

How many matching processes are running.

=item total_vsz_kbytes

The sum of the virtual memory usage (VSZ output of ps) for all matching processes.

=item total_rss_kbytes

The sum of the resident set size (RSS output of ps) for all matching processes.

=item total_pmem_pct

The sum of the percentage of physical memory used (PMEM output of ps) for all matching processes.

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $pgrep_path = $config->{pgrep_path} || 'pgrep';

    my $args;
    my $actual_count = 0;
    my $vsz_total = 0;
    my $rss_total = 0;
    my $pmem_total = 0;

    my @output_lines;
    my @pids;

    # Run pgrep to get process IDs
    if ( $^O eq "solaris" ) {
      my $zonename = `zonename`;
      chomp $zonename;
      $args .= "-z $zonename ";
    } 
    $args .= "-f";
    # This will contain a single blank at the end
    my $cmd = "$pgrep_path $args \'$config->{pattern}\'";
    #warn " Have pgrep command: $cmd\n";
    @output_lines = split(/\n/, (run_command($cmd)) );
    @output_lines = grep { $_ ne '' } @output_lines;
    @pids = @output_lines;
    my $apparent_count = @pids;


    # This is really stupid, but sometimes the shell that was used for pgrep will appear in the PID listing.
    # It won't be running at this point.
    if ($apparent_count) {
        my $pids = join(',', @pids);
        #warn " Have pids: $pids\n";

        my $ps;
        if ( $^O eq "solaris" ) {
            $ps = '/usr/bin/ps';
            $args = "-o vsz= -o rss= -o pmem=";
        } else {
            $ps = '/bin/ps';
            $args = "-o vsz,rss,pmem";
        }

        my $cmd = "$ps $args -p $pids";
        # warn " Have ps command: $cmd\n";
        @output_lines = split(/\n/, (run_command($cmd)) );
        @output_lines = grep { $_ ne '' } @output_lines;
        foreach my $line (@output_lines) {
            my ($vsz, $rss, $pmem) = $line =~ /(\d+)\s+(\d+)\s+(\d+\.\d+)/;
            next unless $vsz;
            $actual_count++;
            $vsz_total  += $vsz;
            $rss_total  += $rss;
            $pmem_total += $pmem;
        }
    }


    return {
            process_count    => [$actual_count, 'i'],
            total_vsz_kbytes => [$vsz_total, 'i'],
            total_rss_kbytes => [$rss_total, 'i'],
            total_pmem_pct   => [$pmem_total, 'n'],
           };
};

1;
