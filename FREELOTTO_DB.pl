#!/usr/bin/perl

use lib '/data/www/lib';
use strict;
use freelotto;

my %last_call;
my %last_output;
my %sql_queries = (
	sublotto_quickpicks =>
	q{
	select (case
	WHEN cnt < :min_cnt THEN 'BAD(' || cnt || ' new subs too low)'
	WHEN per < :min_per or per > :max_per THEN 'BAD(Quickpicks ' || per || ' out of balance)'
	ELSE 'OK('||cnt||' '||per||')' end) status
	from (
	select count(foo) cnt, trunc((sum(foo) / count(foo)),2) per
	from (select s.subscription_id, decode(sum(quickpick), 6, 1, 0) foo
		from tblsublotto_subscription s, tblsubscription_picks p
		where request_timestamp > sysdate-(:hours / 24)
			and p.subscription_id_type=1
			and s.subscription_id = p.subscription_id
		group by s.subscription_id
		)
	)},
);


register_monitor('FREELOTTO_DB', sub {
  my $arg = shift;
  my $os = fresh_status($arg);
  return $os if $os;
  my $query = $arg->{'object'};
  my $timeout = $arg->{'cache_seconds'} || 500;
  my $output;
  if($last_call{$query} > time + $timeout) {
    $output = $last_output{$query};
  } else {
    my $sql = $sql_queries{$query};
    eval {
      my $q = freelotto::prepare($sql);
      foreach my $bind (grep /^:/, keys %$arg) {
        $q->bind_param($bind, $arg->{$bind});
      }
      $q->execute;
      ($output) = $q->fetchrow;
      $q->finish
    };
    if($@) {
      $output = "BAD(SQL Error)";
    }
    $last_call{$query} = time;
    $last_output{$query} = $output;
  }
  return set_status($arg, $output);
});

