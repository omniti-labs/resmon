#!/usr/bin/perl

use lib '/data/www/lib';
use strict;
use freelotto;

my $ccdriver_run_interval = q{
((case when to_char(sysdate, 'hh24') < 15 then
		decode(to_char(sysdate, 'D'),
			1, 12,
			2, 15, 3, 15, 4, 15, 5, 15, 6, 15,
			7, 12)
	else
		decode(to_char(sysdate, 'D'),
			1, 12,
			2, 9, 3, 9, 4, 9, 5, 9, 6, 9,
			7, 12)
	end) + 1)/24};

my %last_call;
my %last_output;
my %sql_queries = (
	fast_subs_processed =>
	qq{
	select /*+ use_nl(tb,ttl) */ (case when count(1) > 0 THEN 'OK('||count(1)||' FAST)'
                ELSE 'BAD(0 FAST)' end) cnt
	FROM tblcc_transaction_log ttl, tblcc_batch tb 
        where tb.cc_batch_id = ttl.cc_batch_id 
                and tb.BATCH_TIMESTAMP > sysdate - $ccdriver_run_interval
                and ttl.external_id_type = 0
	},
	wcl_subs_processed =>
	qq{
	select /*+ use_nl(tb,ttl) */ (case when count(1) > 0 THEN 'OK('||count(1)||' WCL)'
                ELSE 'BAD(0 WCL)' end) cnt
	FROM tblcc_transaction_log ttl, tblcc_batch tb 
        where tb.cc_batch_id = ttl.cc_batch_id 
                and tb.BATCH_TIMESTAMP > sysdate - $ccdriver_run_interval
                and ttl.external_id_type = 6
	},
	flezwin_subs_processed =>
	qq{
	select /*+ use_nl(tb,ttl) */ (case when count(1) > 0 THEN 'OK('||count(1)||' FLEZ)'
                ELSE 'BAD(0 FLEZ)' end) cnt
	FROM tblcc_transaction_log ttl, tblcc_batch tb 
        where tb.cc_batch_id = ttl.cc_batch_id 
                and tb.BATCH_TIMESTAMP > sysdate - $ccdriver_run_interval
                and ttl.external_id_type = 12
	},
	incomplete_batches =>
	q{
	SELECT /*+ use_nl(tb,ttl) */ (case when count(1) > 0 THEN 'BAD('||count(1)||' incomplete batches)'
		ELSE 'OK(0)' end) cnt
	from tblcc_batch tb, tblcc_transaction_log ttl
        WHERE ttl.cc_batch_id = tb.cc_batch_id
                AND tb.batch_timestamp between sysdate - 1 and sysdate - 3/24
                AND cc_response_code = 0
	},
	outstanding_batches =>
	q{
	SELECT /*+ use_nl(tb,ttl) */ (case when count(1) > 0 THEN 'BAD('||count(1)||' outstanding batches)'
		ELSE 'OK(0)' end) cnt
	from tblcc_batch tb, tblcc_transaction_log ttl
        WHERE ttl.cc_batch_id = tb.cc_batch_id
                AND tb.batch_timestamp between sysdate - 1 and sysdate - 3/24
                AND cc_response_code = 0
	},
	auth_queue_backlog =>
	q{
	SELECT (case when count(*) > 10 then 'BAD('||count(1)||' backlog)'
		else 'OK('||count(1)||' backlog)' end)
        FROM tblauth_queue 
        WHERE processed = 0 AND external_id_type in (0, 6, 13)
	},
	auth_queue_fast_malfunction =>
	q{
        select decode(total-good, 0, 'OK(0 bad subs)', 'BAD('||total-good||' bad subs)')
	from (
	select sum(decode(subscription_status, 0, 1, 5, 1, 10, 1, 3, 1, 4, 1, 6, 1, 8, 1, 0)) good, count(1) total 
        from tblsublotto_subscription 
        where REQUEST_TIMESTAMP between sysdate - 1.1/24 and sysdate - 0.1/24
	)
	},
	fast_3hour_subs =>
	q{
	select decode(count(1), 0, 'BAD(0)', 'OK('||count(1)||')') status 
        from tblsublotto_subscription 
        where REQUEST_TIMESTAMP > sysdate - 3/24
	},
	draws_current =>
	q{
	select (case WHEN count(1) > 0 THEN 'OK('||count(1)||')'
		ELSE 'BAD('||count(1)||')' end) num_games
	from tbldraw where drawdate = trunc(sysdate+12/24)
	},
	sublotto_quickpicks =>
	q{
	select (case
	WHEN cnt < :min_cnt THEN 'BAD(' || cnt || ' new subs too low)'
	WHEN per < :min_per or per > :max_per THEN 'BAD(Quickpicks ' || per || ' out of balance)'
	ELSE 'OK('||cnt||' '||per||')' end) status
	from (
	select count(foo) cnt, trunc((sum(foo) / count(foo)),2) per
	from (select /*+ use_hash(s,p) index(p IDX_SUBPICKS_SUBSCRIPTION_ID) */ s.subscription_id, decode(sum(quickpick), 6, 1, 0) foo
		from tblsublotto_subscription s, tblsubscription_picks p
		where request_timestamp > sysdate-(:hours / 24)
			and p.subscription_id_type=1
			and s.subscription_id = p.subscription_id
		group by s.subscription_id
		)
	)},
	results_mail =>
	q{
	select
	CASE WHEN
	24*(trunc(sysdate, 'hh24') - trunc(sysdate)) > 15 
	or 24*(trunc(sysdate, 'hh24') - trunc(sysdate)) < 9 
	or NVL(SUM(m.MAILS_SENT), 0) > 2900000 
	THEN 'OK()' ELSE 'BAD(' || NVL(SUM(m.MAILS_SENT), 0) || ')' end 
	FROM
	tblemailtosendarchive b,
	tblemailsendresults m
	WHERE m.PARAMSETID = 'ResultsMail'
	AND m.DAY = TRUNC(sysdate-1)
	AND m.EMAILTEXTID = b.EMAILTEXTID (+)
	AND m.EMAILTEXTVERSION = b.EMAILTEXTVERSION (+)
	},
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
      my $error = $@;
      $error =~ s/\n/ /g;
      $output = "BAD(SQL Error: $error)";
    }
    $last_call{$query} = time;
    $last_output{$query} = $output;
  }
  return set_status($arg, $output);
});

