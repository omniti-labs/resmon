package Core::Sample;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::Sample - a sample/template resmon module

=head1 SYNOPSIS

 Core::Sample {
     some_check_name: arg1 => foo, arg2 => bar
 }

=head1 DESCRIPTION

This module is a sample resmon module that demonstrates how to write and use a
resmon module, as well as exposing some features modules can use.
Documentation for a module should be done using pod (see B<perldoc perlpod>).

To read the documenation, use B<perldoc Sample.pm>.

To verify the documentation, use B<podchecker Sample.pm>.

=head1 CONFIGURATION

=over

=item check_name

The check name is descriptive only in this check. It is not used for anything.
Some checks use the check_name as part of the configuration, such as
free space checks that specify the filesystem to use.

=item arg1

A sample argument that is printed out in a metric

=item arg2

A sample argument that is printed out in a metric

=back

=head1 METRICS

=over

=item check_name

The name of the current check. You wouldn't normally return this, but it is
here to show how to access the check name, and for testing purposes.

=item arg1

The contents of what you put in the arg1 configuration variable.

=item arg2

The contents of what you put in the arg2 configuration variable.

=item date

Todays date. It only shows the actual date of the month as an example of an
integer (type "i") metric.

=back

=cut

sub new {
    # This is only needed if you have initialization code. Most of the time,
    # you can skip the new method and just implement a handler method.
    my ($class, $check_name, $config) = @_;
    my $self = $class->SUPER::new($check_name, $config);

    # Add initialization code here

    bless($self, $class);
    return $self;
}

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $check_name = $self->{check_name}; # The check name is in here

    # This is an example of running an external command. There are much better
    # ways to get the current date.
    my $date = run_command('date +%d');
    chomp $date;

    # Another example of running an external command:
    # This command caches the output for 600 seconds. You should probably
    # rely on the check interval rather than cache_command unless you have
    # the same command being run on multiple checks.

    # my $output = cache_command('some_command', 600);

    return {
        "check_name" => [$self->{check_name}, "s"],
        "arg1" => [$config->{arg1}, "s"],
        "arg2" => [$config->{arg2}, "s"],
        "date" => [$date, "i"]
    };
};

1;
