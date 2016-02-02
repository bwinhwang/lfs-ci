package Nokia::Command::NewTestResults;
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );

use Nokia::Handler::Database;

use parent qw( Nokia::Command );

sub prepare {
    my $self = shift;
    $self->{opt_name} = "";
    GetOptions( 'buildName=s',     \$self->{opt_name},
                'resultFile=s',    \$self->{opt_resultFile},
                'testSuiteName=s', \$self->{opt_testSuiteName},
                'targetName=s',    \$self->{opt_targetName},
                'targetType=s',    \$self->{opt_targetType},
                'jobName=s',       \$self->{opt_jobName},
                'buildNumber=s',   \$self->{opt_buildNumber},
            ) or LOGDIE "invalid option";
    return;
}

sub execute {
    my $self = shift;
    my $handler = Nokia::Handler::Database->new();

    my $id = $handler->newTestExecution( 
        buildName     => $self->{opt_name},
        testSuiteName => $self->{opt_testSuiteName},
        targetName    => $self->{opt_targetName},
        targetType    => $self->{opt_targetType}, 
        jobName       => $self->{opt_jobName},
        buildNumber   => $self->{opt_buildNumber},
        );

    open FILE, $self->{opt_resultFile} 
        or LOGDIE sprintf( "can not open %s", $self->{opt_resultFile});

    while( <FILE> ) {
        chomp;
        next if m/^#/;
        if( not m/[a-z0-9-_\/.]+;[0-9]+/i ) {
            LOGWARN "line '$_' does not match to regex => ignoring line";
            next;
        }
        my ( $resultName, $resultValue ) = split( ";", $_ );
        $handler->newTestResult( testExecutionId => $id,
                                 testResultName  => $resultName,
                                 testResultValue => $resultValue );
    }
    close FILE;

    return;
}

1;
