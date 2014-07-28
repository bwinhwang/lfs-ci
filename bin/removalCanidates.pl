#!/usr/bin/perl

use strict;
use warnings;
use File::Basename qw( basename );
use Data::Dumper;

my %branches;

while( <> ) {
    chomp;
    my $base = basename( $_ );
    my $branch;

    if ( $base =~ m/^PS_LFS_OS_\d\d\d\d_\d\d_\d{2,4}/ 
         or $base =~ m/LBT.*/ ) {
        push @{ $branches{ "trunk" } }, { path => $_,
                                          base => $base };
    } elsif( $base =~ m/^(.*)_.*$/ ) {
        push @{ $branches{ $1 } }, { path => $_,
                                     base => $base };
    } else {
        die "fail $base";
    }

}

foreach my $branch ( keys %branches ) {
    my $c = 0;
    my @list = map  { $_->{path} }
               grep { $c++ > 10 }
               reverse
               sort @{ $branches{ $branch } };
    print join( "\n", @list ) . "\n" if scalar( @list ) > 0;
}

