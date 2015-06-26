package Nokia::Command::ReserveTarget; 
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
    $self->{opt_userName} = $ENV{"USER"};

    GetOptions( 'targetName=s', \$self->{opt_targetName},
                'comment=s',    \$self->{opt_comment},
                'userName=s',   \$self->{opt_userName},
            ) or LOGDIE "invalid option";

    Nokia::Singleton::config()->addConfig( 
            name  => "databaseName",
            value => "booking" );

    return;
}

sub execute {
    my $self = shift;

    Nokia::Store::Database::Booking->new()->reserveTarget( 
        userName   => $self->{opt_userName},
        comment    => $self->{opt_comment},
        targetName => $self->{opt_targetName} );

    return;
}

1;
