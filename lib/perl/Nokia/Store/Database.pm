package Nokia::Store::Database;
use strict;
use warnings;

use DBI;
use Log::Log4perl qw( :easy );

use Nokia::Singleton;

use parent qw( Nokia::Object );

sub prepare {
    my $self = shift;
    my $sql  = shift;

    if( not $self->{dbi} ) {

        my $dbDriver   = Singleton::config->getConfig( "MYSQL_db_driver" );
        my $dbName     = Singleton::config->getConfig( "MYSQL_db_name" );
        my $dbHostname = Singleton::config->getConfig( "MYSQL_db_hostname" );
        my $dbPort     = Singleton::config->getConfig( "MYSQL_db_port" );

        my $dbiString = sprintf( "DBI:%s:%s:%s:%s",
                $dbDriver,                    # database driver
                $dbName,                      # database
                $dbHostname,                  # database host
                $dbPort,                      # database port
                );
        my $userName = Singleton::config->getConfig( "MYSQL_db_username" );
        my $password = Singleton::config->getConfig( "MYSQL_db_password" );
        my $dbiArgs  = { AutoCommit => 1,
                         PrintError => 1 };

        $self->{dbi} = DBI->connect( $dbiString, $userName, $password, $dbiArgs ) 
            or LOGDIE $DBI::errstr;
    }

    return $self->{dbi}->prepare( $sql ) or LOGDIE $DBI::errstr;
}

1;
