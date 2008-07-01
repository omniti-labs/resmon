package Resmon::Module::UPDATE;

use Switch;

use Resmon::Module;

use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
    my $arg = shift;

    # Set the default interval to 10 minutes
    $arg->{interval} ||= 600;

    my $output = `/opt/resmon/update/update.pl`;
    my $exitcode = $?;

    $status = "BAD";
    $msg = "Problem Updating";

    switch ($exitcode) {
        case 0 {
            $status = "OK";
            $msg = "No updates found";
        }
        case 1 {
            $status = "OK";
            $msg = "Updated successfully";
        }
        case 2 {
            $msg = "Unable to locate subversion binary"
        }
        case 3 {
            $msg = "Problem with the update. Reverted to previous revision";
        }
    }

    return $status, $msg;
}

1;
