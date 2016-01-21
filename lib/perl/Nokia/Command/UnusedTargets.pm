package Nokia::Command::UnusedTargets;
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );

use Nokia::Singleton;
use Nokia::Store::Database::Booking;

use parent qw( Nokia::Object );

## @fn      prepare()
#  @brief   prepare the usecase / command
#  @param   <none>
#  @return  <none>
sub prepare {
    my $self = shift;

    Nokia::Singleton::config()->addConfig( 
            name  => "databaseName",
            value => "booking" );

    return;
}

## @fn      execute()
#  @brief   execute the usecase "unused targets"
#  @details prints all unused targets from booking database
#  @param   <none>
#  @return  <none>
sub execute {
    my $self = shift;

    printf join( "\n", Nokia::Store::Database::Booking->new()->unusedTargets() );
    printf "\n";

    return;
}

1;
