package Core::Log;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

=pod

=head1 NAME

Core::Log - Monitor a log file for errors matching a certain pattern

=head1 SYNOPSIS

 Core::Log {
     /var/log/foo: match => ^ERROR:
 }

=head1 DESCRIPTION

This module will tail a log file and count the number of errors it finds. An
error is determined by the match parameter to the check, which is a regular
expression.

When a log file rotates or is moved aside, the error count is reset. This
can be used to clear an alert for the error count being greater than 0.

=head1 CONFIGURATION

=over

=item check_name

The name of the file to monitor

=item match

Regular expression for matching error lines

=back

=head1 METRICS

=over

=item errs

The number of errors

=item errstring

A string showing the errors

=back

=cut

sub handler {
    my $self = shift;
    my $config = $self->{config}; # All configuration is in here
    my $file = $self->{check_name}; # The check name is in here

    my @statinfo = stat($file);

    if (!exists($self->{file_dev}) ||
            $self->{file_dev} != $statinfo[0] ||
            $self->{file_ino} != $statinfo[1]) {
        # New file, reset stats
        $self->{lastsize} = 0;
        $self->{errs} = 0;
        $self->{errstring} = '';
    }

    if ($self->{lastsize} == 0 || $self->{lastsize} != $statinfo[7]) {
        # If the logfile has grown
        my $log;
        if (!open($log, "<$file")) {
            die("Unable to open log file $file");
        }
        seek($log, $self->{lastsize}, 0);

        while(<$log>) {
            chomp;
            if (/$config->{match}/) {
                $self->{errstring} .= " " if (length($self->{errstring}));
                $self->{errstring} .= $_;
                $self->{errs}++;
            }
        }

        close($log);
    }

    # Remember where we were
    $self->{file_dev} = $statinfo[0];
    $self->{file_ino} = $statinfo[1];
    $self->{lastsize} = $statinfo[7];

    return {
        "errs" => [$self->{errs}, "i"],
        "errstring" => [$self->{errstring}, "s"],
    };
};

1;
