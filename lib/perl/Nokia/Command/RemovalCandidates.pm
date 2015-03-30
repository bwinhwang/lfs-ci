package Nokia::Command::RemovalCandidates; 
## @brief get the removal candidates baselines
use strict;
use warnings;

use Getopt::Std;
use Data::Dumper;
use File::Basename;

use parent qw( Nokia::Object );

sub init {
    my $self = shift;
    $self->{branches} = {};
    return;
}

sub prepare {
    my $self = shift;

    while( <STDIN> ) {
        chomp;
        my $base = basename( $_ );
        my $branch;

        if( $base =~ m/^PS_LFS_OS_\d\d\d\d_\d\d_\d{2,4}/ 
            or $base =~ m/LFS\d+/ 
            or $base =~ m/LBT\d+/ 
            or $base =~ m/LFSM\d+/ 
            or $base =~ m/UBOOT\d+/ 
            or $base =~ m/results/
        ) {
            push @{ $self->{branches}{ "trunk" } }, { path => $_,
                                                      base => $base };
        } elsif( $base =~ m/^(.*)_.*$/ ) {
            push @{ $self->{branches}{ $1 } }, { path => $_,
                                                 base => $base };
        } elsif ( $base eq "SAMPLEVERSION" or
                  $base eq "EMPTY" or
                  $base eq "DENSE" 
                ) {
            # ignore this baselines
        } else {
            die "fail $base";
        }

    }
    return;
}

sub execute {
    my $self = shift;

    foreach my $branch ( keys %{ $self->{branches} } ) {
        my $c = 0;
        my @list = grep { $c++ > 10 }
                   reverse
                   sort 
                   map  { $_->{base} }
                   @{ $self->{branches}{ $branch } };
        print join( "\n", @list ) . "\n" if scalar( @list ) > 0;
    }

    return;
}


1;
