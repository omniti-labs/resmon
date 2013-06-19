package Core::WatchOutput;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::WatchOutout - watch a command's output, reporting it

=head1 SYNOPSIS

 Core::WatchOutput {
     ls: command => "/bin/ls", cache => 3600
 }

=head1 DESCRIPTION

This check will run a given command and return the output as the
"output" metric.

=head1 CONFIGURATION

=over

=item command

This is a string of the command name and any arguments.

=item cache

The duration, in seconds, to cache the output of the command. If this
value is missing, there is no caching.

=back

=head1 METRICS

=over

=item output

The STDOUT of the command.

=item return_code

The exit code of the command.

=back

=cut

sub new {
    my ($class, $check_name, $config) = @_;
    my $self = $class->SUPER::new($check_name, $config);

    bless($self, $class);
    return $self;
}

sub handler {
    my $self = shift;
    my $config = $self->{config};
    my $command = $config->{command};
    my $cache = exists $config->{cache} ? $config->{cache} : 0;

    my $output;
    if($cache) {
        $output = cache_command($command, $cache);
    } else {
        my $output = run_command($command);
    }
    chomp $output;
    my $status = $? >> 8;

    return {
        "output" => [$output, "s"],
        "return_code" => [$status, "i"],
    };
};

1;
