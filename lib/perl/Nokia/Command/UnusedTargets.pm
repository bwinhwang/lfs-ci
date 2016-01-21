package Nokia::Command::UnusedTargets;
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );

use Nokia::Singleton;
use Nokia::Store::Database::Booking;

use parent qw( Nokia::Object );

sub prepare {
    my $self = shift;

    Nokia::Singleton::config()->addConfig( 
            name  => "databaseName",
            value => "booking" );

    return;
}

sub execute {
    my $self = shift;

    printf join( "\n", Nokia::Store::Database::Booking->new()->unusedTargets() );
    printf "\n";

    return;
}

1;
