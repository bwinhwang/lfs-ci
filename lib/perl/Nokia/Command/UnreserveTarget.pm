package Nokia::Command::UnreserveTarget; 
use strict;
use warnings;

use Nokia::Singleton;
use Nokia::Store::Database::Booking;

use parent qw( Nokia::Object );

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );

sub prepare {
    my $self = shift;
    $self->{opt_userName} = $ENV{"USER"};

    GetOptions( 'targetName=s', \$self->{opt_targetName},
                'userName=s',   \$self->{opt_userName},
            ) or LOGDIE "invalid option";

    Nokia::Singleton::config()->addConfig( 
            name  => "databaseName",
            value => "booking" );

    return;
}

sub execute {
    my $self = shift;
    Nokia::Store::Database::Booking->new()->unreserveTarget( 
        userName   => $self->{opt_userName},
        targetName => $self->{opt_targetName} );

    return;
}

1;
