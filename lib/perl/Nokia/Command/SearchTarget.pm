package Nokia::Command::GetConfig; 
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
    my @attributes = ();

    GetOptions( 'targetName=s', \$self->{opt_targetName},
                'attributes=s', \@attributes,
            ) or LOGDIE "invalid option";

    $self->{opt_attributes} = \@attributes;

    return;
}

sub execute {
    my $self = shift;

    my @targets = Nokia::Store::Database::Booking->new()->searchTarget( 
        targetName => $self->{opt_targetName}, 
        attributes => $self->{opt_attributes} );

    printf join( "\n", map { $_->{target_name} } @targets );
    printf "\n";

    return;
}

1;
