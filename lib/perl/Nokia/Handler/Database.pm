package Nokia::Handler::Database;

use strict;
use warnings;

use parent qw( Nokia::Object );

use Nokia::Store::Database::Events;
use Nokia::Store::Database::Branches;
use Nokia::Singleton;

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
    my $self    = shift;
    my $param   = { @_ };
    my $release = $param->{release};

    if( not $self->{store} ) {
        $self->{store} = Nokia::Store::Database::Events->new();
    }

    $self->{store}->newBuildEvent( 
                                   action       => $param->{action},
                                   baselineName => $release->baselineName(),
                                   branchName   => $release->branchName(),
                                   comment      => $release->comment(),
                                   revision     => $release->revision(),
                                   jobName      => $release->jobName(),
                                   buildNumber  => $release->buildNumber(),
                                   productName  => $release->productName(),
                                   taskName     => $release->taskName(),
                                 );
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

## @fn      branchInformation()
#  @brief   get all information from database about branches and ps branches and convert them
#           into a datastructure for a config file
#  @param   <none>
#  @return  hash ref with data
sub branchInformation {
    my $self = shift;

    if( not $self->{store} ) {
        $self->{store} = Nokia::Store::Database::Branches->new();
    }

    my @branchData = $self->{store}->branchInformation();
    my $psBranches = $self->{store}->platformBranchInformation();
    my $result;

    # in case, we are lfs-sandbox, we add the prefix
    my $prefix     = uc Nokia::Singleton::config()->getConfig( name => "LFS_PROD_label_prefix" );

    foreach my $row ( @branchData ) {
        my $locationTagString = sprintf( "productName:%s, location:%s", $row->{product_name}, $row->{location_name} );

        # mapping between the branches and the svn delivery repos
        my $reposName = $row->{release_name_regex};
        $reposName =~ s/.*PS_LFS_.._(\$\{[^\}]+})_(\$\{[^\}]+})_.*/$1_$2/g;
        $reposName =~ s/.*PS_LFS_.._(\d+)_(\d+)_.*/$1_$2/g;

        push @{ $result }, { name  => "LFS_PROD_svn_delivery_repos_name",
                             tags  => $locationTagString,
                             value => sprintf( "BTS_D_SC_LFS_%s", $reposName ) };

        push @{ $result }, { name  => "LFS_CI_global_mapping_location",
                             tags  => $locationTagString,
                             value => $row->{branch_name} };

        push @{ $result }, { name  => "LFS_CI_global_mapping_location_branch",
                             tags  => $locationTagString,
                             value => $row->{branch_name} };

        push @{ $result }, { name  => "LFS_CI_global_mapping_branch_location",
                             tags  => sprintf( 'productName:LFS, branchName:%s', $row->{branch_name} ),
                             value => $row->{location_name} };

        push @{ $result }, { name  => "LFS_PROD_branch_to_tag_regex",
                             tags  => $locationTagString,
                             value => $row->{release_name_regex} };

        my $regex = $row->{release_name_regex} || "";
        $regex =~ s/\$\{date_%Y\}/(\\d\\d\\d\\d\)/g;
        $regex =~ s/\$\{date_%m\}/(\\d\\d\)/g;
        push @{ $result }, { name  => "LFS_PROD_tag_to_branch",
                             tags  => sprintf( 'productName:LFS, tagName~^%s%s$', $prefix, $regex ),
                             value => $row->{location_name} };

        push @{ $result }, { name  => "LFS_CI_uc_update_ecl_url",
                             tags  => $locationTagString,
                             value => join (" ", map  { sprintf( '${BTS_SCM_PS_url}/ECL/%s/ECL_BASE', $_->{ps_branch_name} ) } 
                                                 grep { $_->{status} ne "closed" } 
                                                 @{ $psBranches->{ $row->{branch_name} } || [] } ) || "" };
        push @{ $result }, { name  => "LFS_PROD_uc_release_based_on",
                             tags  => $locationTagString,
                             value => $row->{based_on_release} };
        push @{ $result }, { name  => "LFS_PROD_uc_release_based_on_revision",
                             tags  => $locationTagString,
                             value => $row->{based_on_revision} };
        push @{ $result }, { name  => "LFS_PROD_ps_scm_branch_name",
                             tags  => $locationTagString,
                             value => $psBranches->{ $row->{branch_name} }->[0]->{ps_branch_name} || "" };
        push @{ $result }, { name  => "LFS_CI_branch_status",
                             tags  => $locationTagString,
                             value => $row->{status} };
        push @{ $result }, { name  => "CUSTOM_SCM_svn_trigger_svn_is_maintenance",
                             tags  => $locationTagString,
                             value => $row->{status} ne "open" ? 1 : "" };

        my $pkgpoolPrefix = $row->{release_name_regex};
        $pkgpoolPrefix =~ s/_\(.*//;
        $pkgpoolPrefix =~ s/_\$.*//;
        $pkgpoolPrefix =~ s/PS_LFS_../PS_LFS_PKG/;
        push @{ $result }, { name  => "PKGPOOL_PROD_release_prefix",
                             tags  => sprintf( "branchName:%s", $row->{branch_name} ), 
                             value => $pkgpoolPrefix };
    }
    return $result;
}

sub locationsText {
    my $self = shift;

    if( not $self->{store} ) {
        $self->{store} = Nokia::Store::Database::Branches->new();
    }

    my @data = $self->{store}->branchInformation();

    printf "# This file was automatically created by %s.\n", $0;
    printf "# Do not edit it by hand.\n";
    print "\n";
    printf "%-20s %-10s %40s\n", "location", "status", "description";
    print  "-"x20 . " " . "-"x10 . " " . "-"x80 . "\n";
    foreach my $row ( sort { $a->{location_name} cmp $b->{location_name} } @data ) {
        next if $row->{status} eq "closed";
        printf "%-20s %-10s %-80s\n", $row->{location_name}, $row->{status}, $row->{branch_description} || sprintf( "Feature Build (all %s)", $row->{release_name_regex} );
    }
    print  "-"x20 . " " . "-"x10 . " " . "-"x80 . "\n";
    print "\n";
    print "Remarks \n";
    print "*) Please contact Wolfgang Adlassnig for current policy\n";
    print "\n";
    print "For Branch policy\n";
    print "https://confluence.inside.nokiasiemensnetworks.com/display/BtsScmUlm/PS+Releases+in+the+Pipe\n";

    return
}

1;
