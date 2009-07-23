package Resmon::Module::PGSHARED1BACKUPS;
use Resmon::Module;
use vars qw/@ISA/;
@ISA = qw/Resmon::Module/;

use lib qw(/www/CPAN/lib/site_perl);
use DBI;
use DBD::Pg;

sub handler {

	my $db_name= 'bacula';
	my $db_user = 'bacula';
	my $db_pass = '';
	
	my $dsn = "DBI:Pg:database=$db_name;host=127.0.0.1;port=5432";
	my $dbh = DBI->connect($dsn, $db_user, $db_pass, { PrintError => 1, AutoCommit => 1 });
	my $query = "SELECT j.* FROM job j WHERE j.name='Database_pgshared1' AND j.type='B' AND j.level='F' AND j.jobstatus='T' AND j.starttime > current_timestamp - 24 * interval '1 hour'";;
	my $sth = $dbh->prepare($query);
	$sth->execute || die $dbh->errstr;
	
	my $count = 0;
	my $message;
	while (my $result = $sth->fetchrow_hashref) {
		$count++;
	}
	
	if ($count > 0) {
		$status = 'OK';
	} else {
		$status = 'BAD';
	}
	
	$dbh->disconnect;

	return $status, "$count job(s) in the last 24 hours";
}

1;
