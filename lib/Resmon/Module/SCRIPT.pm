package Resmon::Module::SCRIPT;
use Resmon::ExtComm qw/cache_command/;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

# Runs a custom helper script, returning the output.
# Example config file:
# SCRIPT {
#   name : script => /path/to/perl_script.pl, cache => 30
#   name2 : script => /path/to/another_script.pl, cache => 30
# }

sub handler {
    my $arg = shift;
    my $os = $arg->fresh_status();
    return $os if $os;
    my $object = $arg->{'object'};
    my $script = $arg->{'script'} || return "BAD", "No script specified";
    my $timeout = $arg->{'timeout'} || 30;
    my $output = cache_command("$script", $timeout);
    if ($output) {
        chomp($output);
        return $arg->set_status($output);
    } else {
        return "BAD", "No output from command";
    }
}

1;
