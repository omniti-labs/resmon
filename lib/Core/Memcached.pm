package Core::Memcached;

use strict;
use warnings;

use base 'Resmon::Module';

=pod

=head1 NAME

Core::Memcached - check MySQL global statistics

=head1 SYNOPSIS

Core::Memcached {
   one : memstat_path => /path/to/memstat, host => 127.0.0.1, port => 11211
   two : memstat_path => /path/to/memstat, host => 127.0.0.1, port => 11212
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
    my $name         = $self->{'check_name'};
    my $config       = $self->{'config'};
    my $host         = $config->{'host'};
    my $port         = $config->{'port'};
    my $memstat_path = $config->{'memstat_path'};

    my %results;

    my $output = `$memstat_path --servers=$host:$port | grep :`;
    foreach (split(/\n/, $output)) {
        /(\S+):\s+(\w+)/;
        $results{"${name}_$1"} = $2;
    }

    my $total = $results{ "${name}_get_misses" } + $results{ "${name}_get_hits" };

    if ( $total eq 0 ) {
      $results{ "${name}_hit_ratio"  } = 0;
      $results{ "${name}_miss_ratio" } = 100;
    }
    else {
      $results{ "${name}_hit_ratio"  } = ( $results{ "${name}_get_hits"} / $total ) * 100;
      $results{ "${name}_miss_ratio" } = 100 - $results{ "${name}_hit_ratio" };
    }

    $results{ "${name}_fill_ratio" } = ( $results{ "${name}_bytes" } / $results{ "${name}_limit_maxbytes"} ) * 100;

    return \%results;
};

1;
