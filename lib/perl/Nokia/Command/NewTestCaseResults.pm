package Nokia::Command::NewTestCaseResults;
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );
use XML::Simple;

use Nokia::Handler::Database;

use parent qw( Nokia::Command );

sub prepare {
    my $self = shift;
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

    my $xml = XMLin( $self->{opt_resultFile}, ForceArray => 1 );
    $handler->newTestResult(
        buildName     => $self->{opt_name},
        testSuiteName => $self->{opt_testSuiteName},
        targetName    => $self->{opt_targetName},
        targetType    => $self->{opt_targetType},
        jobName       => $self->{opt_jobName},
        buildNumber   => $self->{opt_buildNumber},
        entries       => $xml->{suites}->[0]->{suite}->[0]->{cases}->[0]->{case}, );

    return;
}

1;
