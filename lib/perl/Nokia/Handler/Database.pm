package Nokia::Handler::Database;

use strict;
use warnings;

use parent qw( Nokia::Object );

use Nokia::Store::Database::Events;
use Nokia::Store::Database::Branches;

sub newTestResult {
    my $self  = shift;
    my $param = { @_ };

    my $testExecutionId = $param->{testExecutionId};
    my $testResultName  = $param->{testResultName};
    my $testResultValue = $param->{testResultValue};

    if( not $self->{store} ) {
        $self->{store} = Nokia::Store::Database::Events->new();
    }

    $self->{store}->newTestResult( testExecutionId => $testExecutionId,
                                   testResultName  => $testResultName,
                                   testResultValue => $testResultValue, );
    return;
}
sub newTestExecution {
    my $self  = shift;
    my $param = { @_ };

    my $buildName     = $param->{buildName};
    my $testSuiteName = $param->{testSuiteName};
    my $targetName    = $param->{targetName};
    my $targetType    = $param->{targetType};

    if( not $self->{store} ) {
        $self->{store} = Nokia::Store::Database::Events->new();
    }

    my $id = $self->{store}->newTestExecution( buildName     => $param->{buildName},
                                               testSuiteName => $param->{testSuiteName},
                                               targetName    => $param->{targetName},
                                               targetType    => $param->{targetType},);
    return $id;
}

sub newBuildEvent {
    my $self = shift;
    my $param = { @_ };
    my $release = $param->{release};

    if( not $self->{store} ) {
        $self->{store} = Nokia::Store::Database::Events->new();
    }

    $self->{store}->newBuildEvent( baselineName => $release->baselineName(),
                                   branchName   => $release->branchName(),
                                   revision     => $release->revision(),
                                   action       => $param->{action},
                                   comment      => $release->comment() );
    return;
}

sub newSubversionCommit {
    my $self  = shift;
    my $param = { @_ };

    if( not $self->{store} ) {
        $self->{store} = Nokia::Store::Database::Events->new();
    }

    $self->{store}->newSubversionCommit( baselineName => $param->{baselineName},
                                         msg          => $param->{logentry}->{msg}->[0],
                                         author       => $param->{logentry}->{author}->[0],
                                         date         => $param->{logentry}->{date}->[0],
                                         revision     => $param->{logentry}->{revision}, );
    return;
}

sub branchInformation {
    my $self = shift;

    if( not $self->{store} ) {
        $self->{store} = Nokia::Store::Database::Branches->new();
    }

    my @data = $self->{store}->branchInformation();

    printf "# This file was automatically created by %s.\n", $0;
    printf "# Do not edit it by hand.\n";
    print "\n";
    printf "LFS_CI_internal_config_file_branch_cfg = %d\n", time();
    print "\n";
    foreach my $row ( @data ) {
        printf "\n# %s\n", "-"x80;
        printf "# branch id %d\n", $row->{id};
        printf "# branch creation date: %s\n", $row->{date_created};
        printf "# branch close date   : %s\n", $row->{date_closed};
        printf "# branch comment      : %s\n", $row->{comment} || "<none>";
        printf "#\n";
        printf "LFS_PROD_branch_to_tag_regex          < productName:LFS, location:%s > = %s\n",          
               $row->{location_name}, $row->{release_name_regex}; 
        printf "LFS_CI_branch_status                  < productName:LFS, location:%s > = %s\n",                  
               $row->{location_name}, $row->{status}; 
        printf "LFS_PROD_tag_to_branch                < productName:LFS, tagName~%s > = %s\n",                 
               $row->{release_name_regex}, $row->{location_name} || "";
        printf "LFS_CI_uc_update_ecl_url              < productName:LFS, location:%s > = %s\n",              
               $row->{location_name}, $row->{ps_branch_name} || "";
        printf "LFS_PROD_uc_release_based_on          < productName:LFS, location:%s > = %s\n",          
               $row->{location_name}, $row->{based_on_release} || "";
        printf "LFS_PROD_uc_release_based_on_revision < productName:LFS, location:%s > = %s\n", 
               $row->{location_name}, $row->{based_on_revision} || "";
    }
    return;
}

1;
