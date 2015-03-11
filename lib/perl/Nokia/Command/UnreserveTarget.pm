package Nokia::Command::GetConfig; 
use strict;
use warnings;

use Nokia::Singleton;
use Nokia::Sotre::Database::Booking;

use parent qw( Nokia::Object );

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );

sub prepare {
    my $self = shift;
    my $opt_userName = $ENV{"USER"};

    GetOptions( 'targetName=s', \$self->{opt_targetName},
                'userName=s',   \$self->{opt_userName},
            ) or LOGDIE "invalid option";

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
