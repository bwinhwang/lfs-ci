package Nokia::Store::Database::Branches;
use strict;
use warnings;

use Log::Log4perl qw( :easy);
use Data::Dumper;

use parent qw( Nokia::Store::Database );

sub branchInformation {
    my $self = shift;

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

sub platformBranchInformation {
    my $self = shift;

    my $sth = $self->prepare( 
        "select * from v_ps_branches"
    );
    $sth->execute()
        or LOGDIE sprintf( "can not get ps branch information" );

    my $results;
    while ( my $row = $sth->fetchrow_hashref() ) {
         push @{ $results->{ $row->{branch_name} } }, $row;
    }
    return $results;
}

sub md5sumOfAllEntries() {
    my $self = shift;

    my $sth = $self->prepare( 
        'select MD5(GROUP_CONCAT( id SEPARATOR " " )) as md5 from branches';
    );
    $sth->execute()
        or LOGDIE sprintf( "can not get ps branch information" );

    my $hashref = $sth->fetchall_arrayref();
    print Dumper( $hashref );
    return $hashref;
}
1;
