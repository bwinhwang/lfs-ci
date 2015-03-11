package Nokia::Store::Database;
use strict;
use warnings;

use parent qw( Nokia::Object );

use DBI;
use Log::Log4perl qw( :easy);

sub prepare {
    my $self = shift;
    my $sql  = shift;

    if( not $self->{dbi} ) {

        my $dbiString = sprintf( "DBI:%s:%s:%s:%s",
                "mysql",                      # database driver
                "lfspt",                      # database
                "ulwiki02.emea.nsn-net.net",  # database host
                3306,                         # database port
                );
        my $userName = "lfspt";
        my $password = "pt";
        my $dbiArgs  = { AutoCommit => 1,
                         PrintError => 1 };

        $self->{dbi} = DBI->connect( $dbiString, $userName, $password, $dbiArgs ) or LOGDIE $DBI::errstr;
    }

    return $self->{dbi}->prepare( $sql ) or LOGDIE $DBI::errstr;
}

sub reserveTarget {
    my $self  = shift;
    my $param = { @_ };

    my $targetName = $param->{targetName} || "not_a_valid_target_name";
    my $userName   = $param->{userName};
    my $comment    = $param->{comment};

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

    my @attributes = @{ $param->{attributes} || [ qw ( not_a_valid_features )] };
    my $targetName = $param->{targetName};

    my $sqlString = join( " and ", map { sprintf( "target_features like '%%%s%%'", $_ ) } @attributes );

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

1;
