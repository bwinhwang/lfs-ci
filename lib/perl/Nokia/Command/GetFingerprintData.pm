package Nokia::Command::GetFingerprintData;

use strict;
use warnings;
use XML::Simple;
use Data::Dumper;
use parent qw( Nokia::Command );

sub prepare {
    my $self = shift;
    $self->{fileName} = shift;
    return;
}

sub execute {
    my $self = shift;
    my $xml = XMLin( $self->{fileName}, ForceArray => 1 );

    for my $entry ( @{ $xml->{usages}->[0]->{entry} || [] } ) {
        my $string = $entry->{string}->[0];
        my $range = $entry->{ranges}->[0];
        my @array = splitRange( $range );
        my $lastElement = $array[ scalar @array  - 1 ];
        print "$string:$lastElement\n";
    }

    return;
}

sub splitRange{
    my $range = shift;
    my @array;
    if( $range =~ m/,/ ) {
        foreach my $r ( split( /,/, $range ) ) {
            push @array, splitRange( $r );
        }
    } elsif( $range =~ m/(\d+)-(\d+)/ ) {
        foreach my $i ( $1..$2 ) {
            push @array, $i;
        }
    }
    else
    {
        push @array, int($range);
    }
    return sort { $a <=> $b } @array;
}

1;
