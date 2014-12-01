#!/usr/bin/perl 
package Object;

use strict; 
use warnings;

sub new {
    my $class = shift;
    my $param = { @_ };
    my $self  = bless $param, $class;

    if( $self->can( "init" ) ) {
        $self->init();
    }
    return $self;
}


package Store::Database;
use strict;
use warnings;

use parent qw( -norequire Object );

use DBI;
use Log::Log4perl qw( :easy);

sub prepare {
    my $self = shift;
    my $sql  = shift;

    if( not $self->{dbi} ) {

        my $dbiString = sprintf( "DBI:%s:%s:%s:%s",
                "mysql",   # database driver
                "lfspt",   # database
                "ulwiki02",  # database host
                3306,      # db port
                );
        my $userName = "lfspt";
        my $password = "pt";
        my $dbiArgs  = { AutoCommit => 1,
                         PrintError => 1 };

            $self->{dbi} = DBI->connect( $dbiString, $userName, $password, $dbiArgs ) or LOGDIE $DBI::errstr;
    }

    return $self->{dbi}->prepare( $sql ) or LOGDIE $DBI::errstr;
}

sub createNewReleaseInDatabase {
    my $self = shift;
    my $param = { @_ };
    my $baselineName = $param->{baselineName};
    my $creationDate = $param->{creationDate};
    my $branchName   = $param->{branchName};

    my $sth = $self->prepare( 
        "insert into Releases ( Name, DateTime, Branch ) values ( ?, ?, ? )"
    );

    $sth->execute( $baselineName, $creationDate, $branchName ) or LOGDIE sprintf( "can not insert data\n%s\n", $sth->errstr() );

    return;
}

package Handler::Database;

use strict;
use warnings;
use parent qw( -norequire Object );

sub createNewRelease {
    my $self = shift;
    my $param = { @_ };
    my $release = $param->{release};

    if( not $self->{store} ) {
        $self->{store} = Store::Database->new();
    }

    $self->{store}->createNewReleaseInDatabase( baselineName => $release->baselineName(),
                                                creationDate => $release->creationDate(),
                                                branchName   => $release->branchName() );
    return;
}

package Model::Release;

use strict;
use warnings;
use parent qw( -norequire Object );

sub baselineName { my $self = shift; return $self->{baselineName}; }
sub branchName   { my $self = shift; return $self->{branchName}; }
sub creationDate { my $self = shift; return $self->{creationDate}; }

package main;

use strict;
use warnings;
use Log::Log4perl qw( :easy );
use Getopt::Long;

my %l4p_config = (
    'log4perl.category'                                  => 'TRACE, Screen',
    'log4perl.appender.Screen'                            => 'Log::Log4perl::Appender::Screen',
    'log4perl.appender.Screen.stderr'                     => '0',
    'log4perl.appender.Screen.Threshold'                  => 'TRACE',
    'log4perl.appender.Screen.layout'                     => 'Log::Log4perl::Layout::SimpleLayout',
);

Log::Log4perl::init( \%l4p_config );

my $opt_name   = "";
my $opt_branch = "";
my $opt_date   = "";

GetOptions( 'n=s', \$opt_name,
            'b=s', \$opt_branch,
            'd=s', \$opt_date,
        ) or LOGDIE "invalid option";

if( not $opt_name or not $opt_branch or not $opt_date ) {
    ERROR "wrong usage: $0 -n <name> -b <branch> -d <date>";
    exit 0
}

my $release = Model::Release->new( baselineName => $opt_name, 
                                branchName   => $opt_branch, 
                                creationDate => $opt_date, );
my $handler = Handler::Database->new();

$handler->createNewRelease( release => $release );

exit 0;
