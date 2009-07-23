package Resmon::Module::BACULAJOBS;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

use lib qw(/www/CPAN/lib/site_perl);
use DBI;
use DBD::Pg;

sub handler {
	my $arg = shift;
	my $jobname = $arg->{'object'};
	my $level = $arg->{'level'};
	my $age = $arg->{'age'};
	print "$jobname, $level, $age\n";

	my $db_name= 'bacula';
	my $db_user = 'bacula';
	my $db_pass = '';
	
	my $dsn = "DBI:Pg:database=$db_name;host=127.0.0.1;port=5432";
	my $dbh = DBI->connect($dsn, $db_user, $db_pass, { PrintError => 1, AutoCommit => 1 });
	my $query = "SELECT count(*) FROM job j WHERE j.name=? AND j.type='B' AND j.level=? AND j.jobstatus='T' AND j.starttime > current_timestamp - ? * interval '1 hours'";
	my $sth = $dbh->prepare($query);
	$sth->execute($jobname, $level, $age) || die $dbh->errstr;
	
	my $count = $sth->fetchrow_hashref->{'count'};
	my $status;
	
	if ($count > 0) {
		$status = 'OK';
	} else {
		$status = 'BAD';
	}
	
	$sth->finish;
	$dbh->disconnect;

	return $status, "$count job(s) in the last $age hours";
}

1;
