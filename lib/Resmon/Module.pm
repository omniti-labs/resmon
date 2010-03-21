package Resmon::Module;
use strict;
use warnings;

sub new {
    my ($class, $check_name, $config) = @_;
    my $self = {};
    $self->{config} = $config;
    $self->{check_name} = $check_name;
    bless ($self, $class);
    return $self;
}

sub handler {
    return {
        'error_message' => ["Monitor not implemented", "s"]
    }
}

sub cache_metrics {
    # Simple method to cache the results of a check
    my $self = shift;
    $self->{lastmetrics} = shift;
    $self->{lastupdate} = time;
}

sub get_cached_metrics {
    my $self = shift;
    return undef unless $self->{check_interval};
    my $now = time;
    if(($self->{lastupdate} + $self->{check_interval}) >= $now) {
        return $self->{lastmetrics};
    }
    return undef;
}

1;
