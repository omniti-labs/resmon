package Resmon::Module::NAGIOS;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

# Runs a nagios check script as a resmon check
# Example config file:
# NAGIOS {
#   /path/to/check_something : args => -a my args
#   /path/to/check_something_else : args => -a my args -w 10 -c 20
# }

sub handler {
    my $arg = shift;
    my $script = $arg->{'object'} || return "BAD", "No script specified";
    my $scriptargs = $arg->{'args'};
    my $output = `$script $scriptargs`;
    my $retval = $?;
    if ($retval == -1) {
        return "BAD", "command returning -1";
    }
    $retval = $retval >> 8;
    my $status = "BAD";
    # 0 - OK, 1 - WARNING, 2 - CRITICAL, 3 - UNKNOWN
    # Treat UNKNOWN (and any other return code) as bad
    if ($retval == 0) {
        $status = "OK";
    } elsif ($retval == 1) {
        $status = "WARNING";
    } elsif ($retval == 3) {
        $output = "UNKNOWN: $output";
    }
    if ($output) {
        ($output, $perfdata) = split(/\s*\|\s*/, $output, 2);
        chomp($output);
        chomp($perfdata);
        # This will show up in the resmon status page
        if ($perfdata) {
            $arg->{'perfdata'} = $perfdata;
        }
        return $status, $output;
    } else {
        return "BAD", "No output from check";
    }
}

1;
