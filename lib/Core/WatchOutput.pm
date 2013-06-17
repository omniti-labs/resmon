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
     command: cmd => "/bin/ls"
 }

=head1 DESCRIPTION

This check will run a given command and return the output as the
"output" metric.

=head1 CONFIGURATION

=over

=item command

This is a string of the command name and any arguments.

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
    my $command = $self->{command};

    my $output = run_command($command);
    my $status = $? >> 8;
    chomp $output;

    return {
        "output" => [$self->{check_name}, "s"],
        "return_code" => [$status, "i"],
    };
};

1;
