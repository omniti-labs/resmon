use strict;
use warnings;

# Hack to mark modules we provide here as already loaded
$INC{"Resmon/Module.pm"} = $0;
$INC{"Resmon/ExtComm.pm"} = $0;

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
    die "Monitor not implemented. Perhaps this is a wilcard only module?\n";
}

sub wildcard_handler {
    die "Monitor not implemented. Perhaps this is a non-wildcard module?\n";
}

1;

1;

package Resmon::ExtComm;
use strict;
use warnings;

use base "Exporter";
our @EXPORT_OK = qw/cache_command run_command/;

sub cache_command($$) {
    my $command = shift;
    run_command($command);
}

sub run_command {
    my @cmd = @_;
    pipe(my ($r, $w));
    my $pid = fork();
    if($pid) {
        close($w);
        my @lines = <$r>;
        waitpid($pid, 0);
        return join("", @lines);
    } else {
        eval {
            open(STDOUT, ">&", $w);
            close($r);
            exec(@cmd);
        };
        exit();
    }
}

1;

package ResmonTest;

use lib '../../lib';

sub load_module {
    my $module = shift;
    my $check_name = shift;
    my $kvs = {@_};

    eval "use $module;";
    if ($@) {
        print "$@\n";
        exit 1;
    }
    my $obj = $module->new($check_name, $kvs);
    return $obj;
}
