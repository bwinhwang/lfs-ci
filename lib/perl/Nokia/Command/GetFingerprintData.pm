## @file GetFingerprintData.pm
#  @brief get the job information out of the fingerprint xml file
package Nokia::Command::GetFingerprintData;

use strict;
use warnings;
use XML::Simple;
use Data::Dumper;

use parent qw( Nokia::Command );

## @fn      prepare()
#  @brief   prepare the command
#  @details parses the input parameters from the command line
#  @param   {ARGV}    arguments from command line
#  @return  <none>
sub prepare {
    my $self = shift;
    $self->{fileName} = shift;
    return;
}

## @fn      execute()
#  @brief   execute the command
#  @details see brief at the beginning
#  @param   <none>
#  @return  <none>
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

## @fn      splitRange()
#  @brief   converts the given range from fingerprint file into a list of
#           numbers
#  @details jenkins fingerprint files contains something like this:
#           1,3-6,9,10
#           but we want a list of numbers:
#           qw( 1 3 4 5 6 9 10 )
#  @param   {range}    input range
#  @return  list of build nubers
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
