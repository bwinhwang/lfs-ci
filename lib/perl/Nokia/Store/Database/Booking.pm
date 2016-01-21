package Nokia::Store::Database::Booking;
use strict;
use warnings;

use parent qw( Nokia::Store::Database );

use DBI;
use Log::Log4perl qw( :easy );

sub reserveTarget {
    my $self  = shift;
    my $param = { @_ };

    my $targetName = $param->{targetName} || "not_a_valid_target_name";
    my $userName   = $param->{userName};
    my $comment    = $param->{comment}   || "no comment";

    my $sth = $self->prepare( 
        'CALL reserveTarget( ?, ?, ? )'
    );
    $sth->execute( $targetName, $userName, $comment ) 
        or LOGDIE sprintf( "can not reserve target : %s, %s, %s", $targetName, $userName, $comment);

    return;
}

sub unreserveTarget {
    my $self  = shift;
    my $param = { @_ };

    my $targetName = $param->{targetName};

    my $sth = $self->prepare( 
        'CALL unreserveTarget( ? )'
    );
    $sth->execute( $targetName )
        or LOGDIE sprintf( "can not unreserve target: %s", $targetName );

    return;
}

sub searchTarget {
    my $self  = shift;
    my $param = { @_ };

    my @attributes = split( /\s+/, $param->{attributes} || qw( not_a_valid_features ) );
    my $targetName = $param->{targetName}    || 'not_a_valid_target_name';

    # match with regex due to word bondary
    # see http://stackoverflow.com/questions/656951/search-for-whole-word-match-in-mysql
    my $sqlString = join( " ", map {
                                         if( $_ eq 'or' ) {
                                             sprintf( " OR " ); 
                                         } elsif ( $_ eq 'and' ) {
                                             sprintf( " AND " );
                                         } elsif ( $_ eq ')' ) {
                                             sprintf( " ) " ); 
                                         } elsif ( $_ eq '(' ) {
                                             sprintf( " ( " ); 
                                         } elsif ( $_ eq 'not' ) {
                                             sprintf( " NOT " );
                                         } else {
                                             sprintf( " ( target_features REGEXP '[[:<:]]%s[[:>:]]' or target_name = '%s' ) ", $_, $_ );
                                         }
                                       }
                                   @attributes );

    DEBUG "sql search string = $sqlString";

    my $sth = $self->prepare( 
        "select * from targets where ( ( $sqlString ) or target_name = '$targetName' ) and status = 'free'"
    );
    $sth->execute()
        or LOGDIE sprintf( "can not search target: %s, %s", $targetName, $sqlString );
    my @results;
    while ( my $row = $sth->fetchrow_hashref() ) {
         push @results, $row;
    }
    return @results;
}

sub unusedTargets {
    my $self  = shift;
    my $param = { @_ };

    my $sth = $self->prepare( 
        "SELECT 
            target_name 
        FROM bookings b 
        RIGHT OUTER JOIN targets t 
            ON b.target_id = t.id 
            AND b.id in ( SELECT MAX(id) 
                          FROM bookings 
                          GROUP BY target_id) 
        WHERE endTime IS NOT NULL 
              AND status = 'free' 
              AND TIME_TO_SEC( TIMEDIFF(now(), endTime) ) > 3600 
              AND comment NOT LIKE 'Admin_-_target_poweroff'
        ORDER BY target_name"
    );
    $sth->execute()
        or LOGDIE "can not get unused targets";
    my @results;
    while ( my $row = $sth->fetchrow_hashref() ) {
         push @results, $row->{target_name};
    }
    return @results;
}

1;
