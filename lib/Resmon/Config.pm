package Resmon::Config;

use strict;
use warnings;

use Sys::Hostname;


sub split_ip_list {
# this code is taken from  Marcel Gruenauer's <marcel@cpan.org> CPAN module Net::IP::Match
    my $string = shift; 
    my $allow = shift;
    my (@result,$quad,$bits,$matchbits,$int,$mask);
    for (split (/\s*[,\s]\s*/, $string)) {
       ($quad, $bits) = m!^(\d+\.\d+\.\d+\.\d+)(?:/(\d+))?!g;
       $bits = 32 unless (defined($bits) && $bits ne '');
       $matchbits = 32 - $bits;
       $int = unpack("N", pack("C4", split(/\./,$quad)));
       $mask = $int >> $matchbits;
       push @result => {mask => $mask, bits => $matchbits, allow => $allow};
print STDERR "mask=$mask,bits=$matchbits,allow=$allow\n";
    }
    return \@result;
}
sub new {
    my $class = shift;
    my $filename = shift;
    my $self = shift; # Allows calling this recursively - you can pass in self
    $self ||= bless {
        configfile => $filename,
        modstatus => [],
        # Defaults
        timeout => 10,
        Module => {}
    }, $class;
    my $conf;
    open($conf, "<$filename") ||
        die "Unable to open configuration file $filename";

    my $current;
    my $line = 0;
    my $oldline = '';
    while(<$conf>) {
        chomp;
        $line++;
        next if /^\s*#/;
        next if /^\s*$/;

        # Line continuation
        if ($oldline) {
            $_ = $oldline . $_;
            $oldline = '';
        }
        if (/\\$/) {
            $_ =~ s/\\$//;
            $oldline = $_;
            next;
        }

        if($current) {
            if(/^\s*([^:\s](?:[^:]*[^:\s])?)\s*:\s*(.+)\s*$/) {
                next if $current eq "BAD_MODULE";
                my $kvs = {};
                my $check_name = $1;
                my @params = split(/,/, $2);
                grep { $kvs->{$1} = $2 if /^\s*(\S+)\s*=>\s*(\S(?:.*\S)?)\s*$/ }
                    @params;
                my $object;
                eval "\$object = $current->new(\$check_name, \$kvs);";
                if ($@) {
                    print STDERR "Problem with check $current\`$check_name:\n";
                    print STDERR "$@\n";
                    print STDERR "This check will not be available\n";
                    push @{$self->{modstatus}}, "$current`$check_name";
                    next;
                }
                if (!$object->isa("Resmon::Module")) {
                    print STDERR "Module $current isn't of type ";
                    print STDERR "Resmon::Module. Check $current`$check_name ";
                    print STDERR "will not be available\n";
                    push @{$self->{modstatus}}, "$current`$check_name";
                    next;
                }
                $self->{Module}->{$current}->{$check_name} = $object;
            } elsif (/^\s*\}\s*$/) {
                $current = undef;
            } else {
                die "Syntax Error in config file $filename on line $line\n";
            }
        } else {
            if(/\s*(\S+)\s*\{/) {
                $current = $1;

                # Delete the module from %INC if it exists. This will reload
                # any module if needed.
                my $mod_filename = "$current.pm";
                $mod_filename =~ s/::/\//g;
                delete $INC{$mod_filename};
                {
                    local($SIG{__WARN__}) = sub {
                        if($_[0] =~ /[Ss]ubroutine ([\w:]+) redefined/ ) {
                            return;
                        }
                        warn @_;
                    };
                    eval "use $current;";
                }
                if ($@) {
                    print STDERR "Problem loading monitor $current:\n";
                    print STDERR "$@\n";
                    print STDERR "This module will not be available\n";
                    push @{$self->{modstatus}}, $current;
                    $current = "BAD_MODULE";
                    next;
                }
                $self->{Module}->{$current} ||= {};
                next;
            }
            elsif(/\S*LIB\s+(\S+)\s*;\s*/) {
                eval "use lib '$1';";
                next;
            }
            elsif(/\S*PORT\s+(\d+)\s*;\s*/) {
                $self->{port} = $1;
                next;
            }
            elsif(/\S*INTERFACE\s+(\S+)\s*;\s*/) {
                $self->{interface} = $1;
                next;
            }
            elsif(/\s*INTERVAL\s+(\d+)\s*;\s*/) {
                $self->{interval} = $1;
                next;
            }
            elsif(/\s*STATUSFILE\s+(\S+)\s*;\s*/) {
                $self->{statusfile} = $1;
                next;
            }
            elsif(/\s*TIMEOUT\s+(\d+)\s*;\s*/) {
                $self->{timeout} = $1;
                next;
            }
            elsif(/\s*AUTHUSER\s+(\S+)\s*;\s*/) {
                $self->{authuser} = $1;
                next;
            }
            elsif(/\s*AUTHPASS\s+(\S+)\s*;\s*/) {
                $self->{authpass} = $1;
                next;
            }
            elsif(/\s*HOSTS\s+ALLOW\s+([^;]+)\s*;\s*/) {
                push (@{$self->{hostsallow}}, @{split_ip_list($1,1)});
                next;
            }
            elsif(/\s*HOSTS\s+DENY\s+([^;]+)\s*;\s*/) {
                push (@{$self->{hostsallow}}, @{split_ip_list($1,0)});
                next;
            } elsif(/\s*INCLUDE\s+(\S+)\s*;\s*/) {
                my $incglob = $1;

                # Apply percent substitutions
                my $HOSTNAME = hostname; # Uses Sys::Hostname
                $incglob =~ s/%h/$HOSTNAME/g;
                $incglob =~ s/%o/$^O/g;

                foreach my $incfilename (glob $incglob) {
                    new($class, $incfilename, $self);
                }
            } else {
                die "Syntax Error in config file $filename on line $line\n";
            }
        }
    }
    if($current) {
        die "unclosed stanza\n";
    }
    return $self;
}

1;
