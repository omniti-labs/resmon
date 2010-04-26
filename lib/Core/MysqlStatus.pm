package Core::MysqlStatus;

use strict;
use warnings;

use base 'Resmon::Module';
use DBI;

=pod

=head1 NAME

Core::MysqlStatus - check MySQL global statistics

=head1 SYNOPSIS

Core::MysqlStatus {
   127.0.0.1 : port => 3306, user => foo, pass => bar
}

=head1 DESCRIPTION

This module retrieves the SHOW GLOBAL STATUS of a MySQL service.

=head1 CONFIGURATION

=over

=item check_name

The target of the MySQL service.  This can be represented as an IP 
address or FQDN.

=item port

The port that the target service listens on.  This defaults to 3306.

=item user

The username to connect as.  The user must have SELECT access to the
"mysql" database;

=item pass

The password to connect with.

=back

=head1 METRICS

This check returns a significant number of metrics.  There are too many to go
into detail here.  For more information, refer to the MySQL developer
documentation at http://dev.mysql.com/doc/.

=cut

sub handler {
    my $self = shift;
    my $config = $self->{'config'};
    my $target = $self->{'check_name'};
    my $port = $config->{'port'} || 3306;
    my $user = $config->{'user'};
    my $pass = $config->{'pass'};
    my $dbh = DBI->connect("DBI:mysql::$target;port=$port", $user, $pass);

    my $select_query = "SHOW GLOBAL STATUS";
    my $sth = $dbh->prepare($select_query);
    $sth->execute();

    my %metrics;
    while (my $result = $sth->fetchrow_hashref) {
        $metrics{$result->{'Variable_name'}} = $result->{'Value'};
    }

    return { %metrics };
};

1;
