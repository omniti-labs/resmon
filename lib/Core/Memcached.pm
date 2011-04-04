package Core::Memcached;

use strict;
use warnings;

use base 'Resmon::Module';

=pod

=head1 NAME

Core::Memcached - check MySQL global statistics

=head1 SYNOPSIS

Core::Memcached {
   127.0.0.1: memstat_path => /path/to/memstat
}

=head1 DESCRIPTION

=head1 CONFIGURATION

=over

=item check_name

=back

=head1 METRICS

=cut

sub handler {
    my $self         = shift;
    my $config       = $self->{'config'};

    my %results;

    my $output = `/usr/local/bin/memstat --servers=127.0.0.1 | grep :`;
    foreach (split(/\n/, $output)) {
        /(\S+):\s+(\w+)/;
        $results{$1} = $2;
    }

    my $total = $results{get_misses} + $results{get_hits};

    $results{hit_ratio}  = ( $results{get_hits} / $total ) * 100;
    $results{miss_ratio} = 100 - $results{hit_ratio};

    $results{fill_ratio} = ( $results{bytes} / $results{limit_maxbytes} ) * 100;

    return \%results;
};

1;
