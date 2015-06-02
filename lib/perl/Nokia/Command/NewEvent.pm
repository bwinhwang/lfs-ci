package Nokia::Command::NewEvent;
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );

use Nokia::Handler::Database;
use Nokia::Model::Build;

use parent qw( Nokia::Command );

sub prepare {
    my $self = shift;
    GetOptions( 'buildName=s',     \$self->{opt_name},
                'branchName=s',    \$self->{opt_branch},
                'revision=s',      \$self->{opt_revision},
                'action=s',        \$self->{opt_action},
                'comment=s',       \$self->{opt_comment},
                'productName=s',   \$self->{opt_productName},
                'taskName=s',      \$self->{opt_taskName},
                'jobName=s',       \$self->{opt_jobName},
                'buildNumber=s',   \$self->{opt_buildNumber},
            ) or LOGDIE "invalid option";
    return;
}

sub execute {
    my $self = shift;
    Nokia::Handler::Database->new()->newBuildEvent( 
        action  => $self->{opt_action},
        release => Nokia::Model::Build->new( 
            baselineName => $self->{opt_name},
            branchName   => $self->{opt_branch},
            revision     => $self->{opt_revision},
            comment      => $self->{opt_comment},
            productName  => $self->{opt_productName},
            taskName     => $self->{opt_taskName},
            jobName      => $self->{opt_jobName},
            buildNumber  => $self->{opt_buildNumber}, ) 
        );
    return;
}

1;
