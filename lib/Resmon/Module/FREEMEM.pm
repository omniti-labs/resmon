package Resmon::Module::FREEMEM;

# Module to check free memory, optionally taking into account cache sizes
# Sample usage:
# FREEMEM {
#   memory : limit => 512, includecache => 1
# }
#
# - Limit is in Megabytes
# - Includecache is either 1 or 0, if 1, then cache sizes are included in the
#   free memory count.
#
# On Solaris, the ZFS ARC Cache is included if includecache is 1. This
# requires the Kstat perl module to be available. If it is not available, the
# module will fall back to an alternate method, but cache sizes can not be
# determined if the fallback method is used.

use strict;
use warnings;

use Resmon::Module;

use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;


sub handler {
    my $self = shift;

    my $limit = $self->{limit} || 512;
    my $includecache = $self->{includecache};


    my $free_mem = 0;
    my $total_mem = 0;
    my $cache_mem = 0;

    if ($^O eq 'linux') {
        open(MEMINFO, '/proc/meminfo');
        for (<MEMINFO>) {
            if (/^MemTotal:\s+(\d+)/) {
                $total_mem = $1 / 1024;
            } elsif (/^MemFree:\s+(\d+)/) {
                $free_mem = $1 / 1024;
            } elsif (/^(Buffers|Cached):\s+(\d+)/) {
                $cache_mem += $2 / 1024;
            }
        };
        close(MEMINFO);
    } elsif ($^O eq 'solaris') {
        eval "use Sun::Solaris::Kstat";
        if ($@) {
            # Kstat isn't available
            if ($includecache) {
                return "BAD", "Kstat not available - can't report on arc size";
            }
            # Get free memory using vmstat
            my @vmstat = `/usr/bin/vmstat 1 2`;
            my $line = $vmstat[-1];
            chomp($line);
            my @parts = split(/ /,$line);
            $free_mem = $parts[5] / 1024;

            # Get total memory using prtconf
            my @prtconf = `/usr/sbin/prtconf 2>/dev/null`;
            foreach (@prtconf) {
                if (/^Memory size: (\d+) Megabytes/) {
                    $total_mem = $1;
                }
            }
        } else {
            # We have kstat, use that for everything
            my $kstat = Sun::Solaris::Kstat->new();
            my $pagesize = `pagesize`;
            my $syspages = $kstat->{unix}->{0}->{system_pages};
            $total_mem = $syspages->{physmem} * $pagesize / 1024 / 1024;
            $free_mem  = $syspages->{freemem} * $pagesize / 1024 / 1024;
            $cache_mem = ${kstat}->{zfs}->{0}->{arcstats}->{size}
                / 1024 / 1024;
        }
    }

    # Round off the values
    $cache_mem = int($cache_mem);
    $free_mem = int($free_mem);
    $total_mem = int($total_mem);

    my $check_val = $free_mem;
    my $free_msg = "$free_mem MB free";
    if ($includecache) {
        $check_val += $cache_mem;
        $free_msg = "$check_val MB free+cache " .
            "($free_mem MB free, $cache_mem MB cache)";
    }

    my $status = "OK";
    if ($check_val < $limit) {
        $status = "BAD";
    }

    return $status, $free_msg . " ${total_mem} MB total";

}
1;
