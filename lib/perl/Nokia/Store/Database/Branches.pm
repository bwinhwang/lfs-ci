package Nokia::Store::Database::Branches;
use strict;
use warnings;

use Log::Log4perl qw( :easy);
use Data::Dumper;

use parent qw( Nokia::Store::Database );

sub branchInformation {
    my $self  = shift;
    my $param = { @_ };

    my $sth = $self->prepare( 
        "select * from branches"
    );
    $sth->execute()
        or LOGDIE sprintf( "can not get branch information" );
    my @results;
    while ( my $row = $sth->fetchrow_hashref() ) {
         push @results, $row;
    }
    return @results;
}

1;
