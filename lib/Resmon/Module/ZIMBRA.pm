package Resmon::Module::ZIMBRA;
use Resmon::ExtComm qw/cache_command/;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

sub handler {
	my $arg = shift;
	my $os = $arg->fresh_status();
	return $os if $os;
	my $unit = $arg->{'object'};
	my $output = cache_command("su - zimbra -c 'zmcontrol status' | grep 'not running'", 500);
	if($output) {
		$output =~s /\n/:/gs;
		return $arg->set_status("BAD($output)");
	}
	return $arg->set_status("OK(All services running)");
};
