package Nokia::Command::NewTestResults;
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );

use Nokia::Handler::Database::Events;

use parent qw( Nokia::Command; );

sub prepare {
    my $self = shift;
    $self->{opt_name} = "";
    $self->{opt_changelog} = "";
    GetOptions( 'buildName=s',     \$self->{opt_name},
                'resultFile=s',    \$self->{opt_resultFile},
                'testSuiteName=s', \$self->{opt_testSuiteName},
                'targetName=s',    \$self->{opt_targetName},
                'targetType=s',    \$self->{opt_targetType},
            ) or LOGDIE "invalid option";
    return;
}

sub execute {
    my $self = shift;
    my $handler = Nokia::Handler::Database::Events->new();

    my $id = $handler->newTestExecution( 
        buildName     => $self->{opt_name},
        testSuiteName => $self->{opt_testSuiteName},
        targetName    => $self->{opt_targetName},
        targetType    => $self->{opt_targetType}, );

    open FILE, $opt_resultFile 
        or LOGDIE sprintf( "can not open %s", $self->{opt_resultFile});

    while( <FILE> ) {
        chomp;
        next if m/^#/;
        my ( $resultName, $resultValue ) = split( ";", $_ );
        $handler->newTestResult( testExecutionId => $id,
                                 testResultName  => $resultName,
                                 testResultValue => $resultValue );
    }
    close FILE;

    return;
}

1;
