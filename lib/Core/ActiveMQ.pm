package Core::ActiveMQ;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::ActiveMQ - A resmon module that monitors ActiveMQ Queues

=head1 SYNOPSIS

 Core::ActiveMQ {
     check_name: noop
 }

 Core::ActiveMQ {
     check_name: view => 'item1,item2,item3,etc.'
 }

 Core::ActiveMQ {
            '*': noop
 }

 Core::ActiveMQ {
            '*': queue => 'name_of_queue'
 }

 Core::ActiveMQ {
            '*': queue => 'name_of_queue', view => 'item1,item2,item3,etc.'
 }

=head1 DESCRIPTION

This module monitors ActiveMQ Queues.  It supports using a wildcard to report
all queues on a broker or reporting only specific queues.  The most useful
metrics are enabled by default, but these can be trimmed down or expanded by
specifying so using the "view" parameter.

=head1 CONFIGURATION

=over

=item check_name

The check name is used to specify the name of the ActiveMQ Queue that you
wish to monitor.  It is also possible to use '*' as the check name which
will result in either all queues on the broker being returned (default) or
a subset of all queues on the broker being returned as specified in the
'queue' parameter.

=item queue

The queue parameter is only valid when the check_name is set to '*'.  This
can be used to return a subset of all of the queues by matching a pattern.

Example: Your ActiveMQ broker has 10 queues, but you only care about 3 of
them perhaps named 'Production.one', 'Production.two', and 'Production.three'.
Assuming that the other 7 queues do not begin with 'Production' then you could
specify the queue argument as 'Production.*' and you'd get results for just
those 3 queues.

=item view

The view parameter is not required by can be used to tailor the list of metrics
that are returned for each queue.  The format is a comma delimited list of valid
ActiveMQ stats such as 'Name,EnqueueCount,DequeueCount,QueueSize'.  Note that
'Name' is required.

If not specified, you will get the default view which is a pretty sane
set of the important data you would likely want.  Refer to the list of metrics
below to see all that is available and which are in the default view.

=item execpath

The execpath parameter lets you specify the full path to the activemq-admin
program which is part of an ActiveMQ install.  If you do not specify this
parameter, it will default to '/opt/activemq/bin/activemq-admin'.  If your
ActiveMQ installation is in a different location, you must specify this
parameter with the correct path.

=back

=head1 METRICS

=over

=item ActiveMQ Queue Statistics

Z<>
 Metric                                  DataType

 Name                                    [string]
 EnqueueCount                           [numeric]
 DequeueCount                           [numeric]
 ConsumerCount                          [numeric]
 DispatchCount                          [numeric]
 ProducerCount                          [numeric]
 ExpiredCount                           [numeric]
 InFlightCount                          [numeric]
 QueueSize                              [numeric]
 MinEnqueueTime                         [numeric]
 AverageEnqueueTime                     [numeric]
 MaxEnqueueTime                         [numeric]
 MemoryUsagePortion                     [numeric]
 MemoryPercentUsage                     [numeric]
 MaxPageSize                            [numeric]

 Also available but not in the default view are:

 CursorMemoryUsage                      [numeric]
 MaxAuditDepth                          [numeric]
 Destination                             [string]
 MemoryLimit                            [numeric]
 Type                                    [string]
 UseCache                               [boolean]
 AlwaysRetroactive                      [boolean]
 MaxProducersToAudit                    [numeric]
 PrioritizedMessages                    [boolean]
 CursorFull                             [boolean]
 BrokerName                              [string]
 ProducerFlowControl                    [boolean]
 Subscriptions                           [string]
 CacheEnabled                           [boolean]
 CursorPercentUsage                     [numeric]
 BlockedProducerWarningInterval         [numeric]

=back

=cut

sub wildcard_handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here

    my $execpath = $config->{'execpath'} || '/opt/activemq/bin/activemq-admin';
    my $queue = $config->{'queue'} || '*';
    my $view = $config->{'view'} || 'Name,EnqueueCount,DequeueCount,ConsumerCount,DispatchCount,ProducerCount,ExpiredCount,InFlightCount,QueueSize,MinEnqueueTime,AverageEnqueueTime,MaxEnqueueTime,MemoryUsagePortion,MemoryPercentUsage,MaxPageSize';

    my $output = run_command($execpath . ' query -QQueue=' . $queue . ' --view ' . $view);

    my $startparse = 0;
    my $item = {};
    my $metrics = {};
    foreach (split(/\n/, $output)) {
        if ($startparse == 1) {
            if (/^$/) {
                $metrics->{$item->{Name}} = $item;
                $item = {};
            } else {
                /(\S+)\s=\s(\S+)/;
                $item->{$1} = $2;
            }
        }
        if (/^Connecting to JMX.*/) {
             $startparse = 1;
        }
    }
    $metrics->{$item->{Name}} = $item;

    return $metrics;
};

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $check_name = $self->{check_name};

    $config->{'queue'} = $check_name;
    my $metrics = $self->wildcard_handler;

    return $metrics->{$check_name}; 
};

1;
