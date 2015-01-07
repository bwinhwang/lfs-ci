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
                "mysql",     # database driver
                "lfspt",     # database
                "ulwiki02",  # database host
                3306,        # db port
                );
        my $userName = "lfspt";
        my $password = "pt";
        my $dbiArgs  = { AutoCommit => 1,
                         PrintError => 1 };

            $self->{dbi} = DBI->connect( $dbiString, $userName, $password, $dbiArgs ) or LOGDIE $DBI::errstr;
    }

    return $self->{dbi}->prepare( $sql ) or LOGDIE $DBI::errstr;
}

sub newBuildEvent {
    my $self         = shift;
    my $param        = { @_ };
    my $baselineName = $param->{baselineName};
    my $branchName   = $param->{branchName};
    my $revision     = $param->{revision};
    my $comment      = $param->{comment};
    my $action       = $param->{action};
    my $method       = "";

    if( $action eq "build_started" ) {
        $method = "build_started( ?, ?, ?, ? )";
    } elsif ( $action eq "build_finished" ) {
        $method = "build_finished( ?, ? )",
    } elsif ( $action eq "build_failed" ) {
        $method = "build_failed( ?, ? )",
    } elsif ( $action eq "release_started" ) {
        $method = "release_started( ?, ? )",
    } elsif ( $action eq "release_finished" ) {
        $method = "release_finished( ?, ? )",
    }

    my $sth = $self->prepare( 
        "call $method" 
    );

    if( $action eq "build_started" ) {
        $sth->execute( $baselineName, $comment, $branchName, $revision ) or LOGDIE sprintf( "can not insert data\n%s\n", $sth->errstr() );
    } else {
        $sth->execute( $baselineName, $comment ) or LOGDIE sprintf( "can not insert data\n%s\n", $sth->errstr() );
    }

    return;
}

package Handler::Database;

use strict;
use warnings;
use parent qw( -norequire Object );

sub newBuildEvent {
    my $self = shift;
    my $param = { @_ };
    my $release = $param->{release};

    if( not $self->{store} ) {
        $self->{store} = Store::Database->new();
    }

    $self->{store}->newBuildEvent( baselineName => $release->baselineName(),
                                   branchName   => $release->branchName(),
                                   revision     => $release->revision(),
                                   action       => $param->{action},
                                   comment      => $release->comment() );
    return;
}

package Model::Release;

use strict;
use warnings;
use parent qw( -norequire Object );

sub baselineName { my $self = shift; return $self->{baselineName}; }
sub branchName   { my $self = shift; return $self->{branchName};   }
sub revision     { my $self = shift; return $self->{revision};     }
sub comment      { my $self = shift; return $self->{comment};     }

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

my $opt_name     = "";
my $opt_branch   = "";
my $opt_revision = "";
my $opt_action   = "";
my $opt_comment   = "";

GetOptions( 'n=s', \$opt_name,
            'b=s', \$opt_branch,
            'r=s', \$opt_revision,
            'a=s', \$opt_action,
            'c=s', \$opt_comment,
        ) or LOGDIE "invalid option";

if( not $opt_name or not $opt_action ) {
    ERROR "wrong usage: $0 -n <name> -b <branch> -r <revision> -a <action>";
    exit 0
}

Handler::Database->new()->newBuildEvent( action  => $opt_action,
                                         release => Model::Release->new( baselineName => $opt_name, 
                                                                         branchName   => $opt_branch, 
                                                                         revision     => $opt_revision,
                                                                         comment      => $opt_comment ) );
exit 0;
