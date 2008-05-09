package Resmon::Module::DNS;

use Resmon::Module;
use Resmon::ExtComm qw/cache_command/;

use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

# Checks the dns server status on onager

sub handler {
    my $self = shift;
    my $os = $self->fresh_status();
    return $os if $os;
    my $object = $self->{object};

    my $key = "-k $self->{key}" if $self->{key};

    my $output = cache_command("rndc $key status 2>&1", 600);
    if ($output) {
        foreach (split(/\n/, $output)) {
            if (/server is up and running/) {
                return "OK", "$_";
            } elsif (/^rndc: neither \S+ nor (\S+) was found$/) {
                return "BAD", "Key file $1 not found";
            } elsif (/connection refused/) {
                return "BAD", "$_";
            }
        }
    }
    return "BAD", "no data";
}

1;
