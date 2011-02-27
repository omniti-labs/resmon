package Extra::EC2;

use strict;
use warnings;

use base 'Resmon::Module';

use Resmon::ExtComm qw(run_command cache_command);

use Net::Amazon::EC2;

=pod

=head1 NAME

Extra::EC2 - Returns the number of EC2 instances by type and cost

=head1 SYNOPSIS

 Extra::EC2 {
    account1: aws_key => KEY1, aws_secret => SECRET1
    account2: aws_key => KEY2, aws_secret => SECRET2
 }

=head1 DESCRIPTION

This module returns the number of instances running on EC2, their live, daily,
and monthly billing costs. It also returns cost by security group, which should
give some idea of how much each "service" costs in aggregate.

=head1 REQUIREMENTS

Extra::EC2 requires Net::Amazon::EC2.

=head1 CONFIGURATION

=over

=item check_name

The check name defines an AWS account to inspect.

=back

=cut

sub handler {
  my $self = shift;
  my $config = $self->{'config'};
  my $account = $self->{'check_name'};

  my $result = {};

  my %months;
  my $total;

  my $total_cost    = 0;
  my $total_running = 0;

  my %instances;

  $instances{type}{'cc1.4xlarge'}{cost} = 1.60;
  $instances{type}{'cg1.4xlarge'}{cost} = 2.10;

  $instances{type}{'m2.4xlarge'}{cost}  = 2.00;
  $instances{type}{'m2.2xlarge'}{cost}  = 1.00;
  $instances{type}{'m2.xlarge'}{cost}   = 0.50;

  $instances{type}{'m1.xlarge'}{cost}   = 0.50;
  $instances{type}{'m1.large'}{cost}    = 0.34;
  $instances{type}{'m1.small'}{cost}    = 0.085;

  $instances{type}{'c1.medium'}{cost}   = 0.17;
  $instances{type}{'c1.xlarge'}{cost}   = 0.68;

  $instances{type}{'t1.micro'}{cost}    = 0.02;

  my $m_mod = 31;
  my $month = `/bin/date +%b`;
  chomp $month;
  
  $months{'Feb'} = 28;
  $months{'Apr'} = 30;
  $months{'Jun'} = 30;
  $months{'Sep'} = 30;
  $months{'nov'} = 30;
  
  if ( $months{$month} ) { $m_mod = $months{$month} }

  my $ec2 = Net::Amazon::EC2->new(
    AWSAccessKeyId  => $config->{aws_key},
    SecretAccessKey => $config->{aws_secret},
  );

  my $running_instances = $ec2->describe_instances;

  # Net::Amazon::EC2 doesn't returns the error object... on eror. So we have to
  # to determine if what we're getting back is an object, and if so, if it's an
  # Error object.
  use Scalar::Util qw(blessed); sub is_error { return blessed($_[0]) and $_[0]->isa('Net::Amazon::EC2::Error') }

  if (is_error($running_instances)) {
    my $errors = $running_instances->errors;
    foreach my $error (@$errors) {
      die $error->message;
    }
  }

  foreach my $r ( @$running_instances ) {
    my $type;
  
    foreach my $i ( $r->instances_set ) {
      $type = $i->instance_type;
      $instances{type}{$i->instance_type}{running}++;
      $total_running++;
    }
  
    foreach my $g ( $r->group_set ) {
      $instances{group}{$g->group_id}{$type}++;
    }
  }
  
  foreach my $t ( sort keys %{$instances{type}} ) {
    my $type = "type_$t";

    unless ( $instances{type}{$t}{running} ) { $instances{type}{$t}{running} = 0 };

    my $hour_cost   = $instances{type}{$t}{running} * $instances{type}{$t}{cost};
    my $minute_cost = $hour_cost / 60;
    my $day_cost    = $hour_cost * 24;
    my $month_cost  = $day_cost * $m_mod;

    $result->{"${type}_hour_cost"}   = [ $hour_cost, "n" ];
    $result->{"${type}_minute_cost"} = [ $minute_cost, "n" ];
    $result->{"${type}_day_cost"}    = [ $day_cost, "n" ];
    $result->{"${type}_month_cost"}  = [ $month_cost, "n" ];
    $result->{"${type}_running"}     = [ $instances{type}{$t}{running}, "i" ];

    $total_cost = $total_cost + $result->{"${type}_month_cost"};
  }

  $result->{overview_total}    = [ $total_cost, "n" ];
  $result->{overview_running}  = [ $total_running, "i" ];

  foreach my $group ( sort keys %{$instances{group}} ) {
    next if $group eq "default";

    my $secgroup = "secgroup_$group";
    my $running = 0;

    my $group_hour_cost   = 0;
    my $group_minute_cost = 0;
    my $group_day_cost    = 0;
    my $group_month_cost  = 0;

    foreach my $i ( sort keys %{$instances{group}{$group}} ) {

      my $hour_cost   = $instances{group}{$group}{$i} * $instances{type}{$i}{cost};
      my $minute_cost = $hour_cost / 60;
      my $day_cost    = $hour_cost * 24;
      my $month_cost  = $day_cost * $m_mod;

      $group_hour_cost    = $group_hour_cost + $hour_cost;
      $group_minute_cost  = $group_minute_cost + $minute_cost;
      $group_day_cost     = $group_day_cost + $day_cost;
      $group_month_cost   = $group_month_cost + $month_cost;

      $running++;
    }

    $result->{"${secgroup}_hour_cost"}    = [ 0, "n" ] unless $result->{"${secgroup}_hour_cost"};
    $result->{"${secgroup}_minute_cost"}  = [ 0, "n" ] unless $result->{"${secgroup}_minute_cost"};
    $result->{"${secgroup}_day_cost"}     = [ 0, "n" ] unless $result->{"${secgroup}_day_cost"};
    $result->{"${secgroup}_month_cost"}   = [ 0, "n" ] unless $result->{"${secgroup}_month_cost"};
    $result->{"${secgroup}_running"}      = [ 0, "n" ] unless $result->{"${secgroup}_running"};

    $result->{"${secgroup}_hour_cost"}    = [ $group_hour_cost, "n" ];
    $result->{"${secgroup}_minute_cost"}  = [ $group_minute_cost, "n" ];
    $result->{"${secgroup}_day_cost"}     = [ $group_day_cost, "n" ];
    $result->{"${secgroup}_month_cost"}   = [ $group_month_cost, "n" ];
    $result->{"${secgroup}_running"}      = [ $running, "i" ];
  }

  return $result;
}

1;
