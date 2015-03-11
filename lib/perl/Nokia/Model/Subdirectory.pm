package Nokia::Model::Subdirectory; 
## @fn    Model::Subdirectory
#  @brief this class represents a subdirectory of the build. It's a src- or a bld/bld- directory

use strict;
use warnings;

use File::Basename;
use Data::Dumper;

use Nokia::Singleton;
use Nokia::Parser::Dependencies;
use Nokia::Usecase::GetLocation;

use parent qw( Nokia::Object );

## @fn     isSubversion()
#  @brief  checks, if the subdirectory is based / in subversion
#  @param  <none>
#  @return 1 if subdirectory is from svn, otherwise 0
sub isSubversion {
    my $self = shift;
    return 0 if $self->{repos} =~ m|^/|;
    return 1 if $self->{repos} =~ m|^https://|;
    return 1 if $self->{repos} =~ m|^http://|;
    return 1 if $self->{repos} =~ m|^file://|;
    return 0;
}

## @fn      getHeadRevision()
#  @brief   get the head revision
#  @param   <none>
#  @return  head revision
sub getHeadRevision {
    my $self = shift;
    if( $self->isSubversion() ) {
        my $svn = Nokia::Singleton::svn();
        $self->{revision} = $svn->info( url => $self->{repos} )->{entry}->{commit}->{revision};
    }
    return $self->{revision};
}

## @fn     checkDependencies()
#  @brief  checks dependencies of a subdirectory and get the required dependencies
#  @param  <none>
#  @return <none>
sub checkDependencies {
    my $self = shift;

    my $dependencyParser = Nokia::Parser::Dependencies->new( fileName => sprintf( "%s/Dependencies", $self->{directory} ) );
    $dependencyParser->parse();

    # check use
    my $locationParser = Nokia::Usecase::GetLocation->new();
    foreach my $useLine ( @{ $dependencyParser->{data}->{use} } ) {

        my $childLocation = $locationParser->getLocation( subDir => $useLine->{src} );

        $childLocation->checkout();
        $childLocation->checkDependencies();

        push @{ $self->{dependencies} }, $childLocation;
    }

    # check use-readonly
    foreach my $use_readonly ( @{ $dependencyParser->{data}->{useReadonly} } ) {

        $use_readonly->cleanup() if -l $use_readonly->src();
        next                     if $use_readonly->hasSourceParameter();
        next                     if $use_readonly->existsDirectory();

        my $childLocation = $locationParser->getLocation( subDir => $use_readonly->src(),
                                                          tag    => $use_readonly->tag() );
        $childLocation->createSymlink();
        push @{ $self->{dependencies} }, $childLocation;
    }

    foreach my $target ( @{ $dependencyParser->{data}->{target} } ) {
        $target->cleanup();
        push @{ $self->{targets} }, $target;
    }

    return;
}

## @fn     loadDependencyTree()
#  @brief  load the dependencies of a source directory
#  @param  <none>
#  @return <none>
sub loadDependencyTree {
    my $self = shift;

    my $dependencyParser;
    my $svn = Nokia::Singleton::svn();
    $self->{tag} =\ "";

    # hack
    if( $self->{directory} eq "src-bos" and $self->{tag} eq "EMPTY" ) {
        warn "skipping src-bos with tag EMPTY";
        return;
    }

    if( -f sprintf( "%s/Dependencies", $self->{directory} ) ) {
        # Dependency file exists in the local workspace
        $dependencyParser = Nokia::Parser::Dependencies->new( fileName => sprintf( "%s/Dependencies", $self->{directory} ) );
    } elsif ( $self->isSubversion() ) {
        # load Dependency file from subversion
        $dependencyParser = Nokia::Parser::Dependencies->new(
            fileContent => $svn->cat( url      => sprintf( "%s/Dependencies", $self->{repos} ),
                                      revision => $self->{revision}                             ) );
    } elsif ( -f sprintf( "%s/Dependencies", $self->{repos} ) )  {
        # Dependency file exists on the share...
        $dependencyParser = Nokia::Parser::Dependencies->new( fileName => sprintf( "%s/Dependencies", $self->{repos} ) );
    }
    else {
        return;
    }

    # parse the depdendency file
    $dependencyParser->parse();

    my $locationParser = Nokia::Usecase::GetLocation->new();

    foreach my $hint ( @{ $dependencyParser->{data}->{hint} } ) {
            push @{ $self->{hints} }, $hint;
            Nokia::Singleton::hint()->addHint( $hint->{src} => $hint->{dst}[0] );
    }

    foreach my $useLine ( @{ $dependencyParser->{data}->{use} } ) {
        my $childLocation = $locationParser->getLocation( subDir => $useLine->{src} );
        $childLocation->loadDependencyTree();
        push @{ $self->{dependencies} }, $childLocation;
    }

    foreach my $use_readonly ( @{ $dependencyParser->{data}->{useReadonly} } ) {
        my $src = $use_readonly->hasSourceParameter()
            ? $use_readonly->sourceParameter()
            : $use_readonly->{src};

        my $childLocation = $locationParser->getLocation( subDir => $src,
                                                          tag    => $use_readonly->tag() );

        if( $childLocation ) {
            $childLocation->{sourceExistsInFileSystem} = $use_readonly->hasSourceDirectory();
            $childLocation->loadDependencyTree();
            push @{ $self->{dependencies} }, $childLocation;
        }
    }

    foreach my $target ( @{ $dependencyParser->{data}->{target} } ) {
            push @{ $self->{targets} }, $target;
    }

    return;
}

## @fn     getSourceDirectoriesFromDependencies()
#  @brief
#  @param  <none>
#  @return list of source directories
sub getSourceDirectoriesFromDependencies {
    my $self = shift;

    my @deps = ();

    foreach my $location ( @{ $self->{dependencies} } ) {
        push @deps, $location->getSourceDirectoriesFromDependencies();
        # we push ourself also on the list
        push @deps, $location->{directory};
    }

    my %tmp = map  { $_ => undef }
              grep { /src-/ }
              @deps;
    return sort keys %tmp;
}

## @fn      getDependencies()
#  @brief   get dependencies for this dependencies entry
#  @param   <none>
#  @return  list of dependencies
sub getDependencies {
    my $self = shift;
    return @{ $self->{dependencies} || [] };
}

sub matchingPlatform {
    my $self     = shift;
    my $platform = shift;
    my @targets  = @{ $self->{targets} || [] };
    my @matches = grep { $_ }
                  map  { $_->matchingPlatform( $platform ) }
                  @targets;
    return @matches;
}

## @fn      matchesPlatform( $value )
#  @brief   checks, if the platform is matching to the given one 
#  @param   {platform}    name of the platform to match
#  @return  1 if platform matches, 0 otherwise
sub matchesPlatform {
    my $self     = shift;
    my $platform = shift;
    my @targets  = @{ $self->{targets} || [] };
    my @matches = grep { $_ }
                  map  { $_->matchesPlatform( $platform ) }
                  @targets;
    return scalar( @matches ) > 0 ? 1 : 0;
}

## @fn      platforms()
#  @brief   get the list of platforms
#  @param   <none>
#  @return  list of platforms
sub platforms {
    my $self = shift;
    return map { $_->platforms() } @{ $self->{targets} };
}

sub directory {
    my $self = shift;
    return $self->{directory};
}

sub bldDirectory {
    my $self     = shift;
    my $platform = shift;

    my $bld = $self->directory();
    if( $bld =~ m/src-(.*)$/ ) {
        $bld = sprintf( "bld/bld-%s-%s", $1, $self->matchingPlatform( $platform ));
    }
    return $bld;
}

## @fn      targets()
#  @brief   get the list of targets
#  @param   <none>
#  @return  list of targets
sub targets {
    my $self = shift;
    return @{ $self->{targets} || [] };
}

## @fn     createSymlink
#  @brief  create a symlink for this directory from the share
#  @param  <none>
#  @return <none>
sub createSymlink {
    my $self = shift;

    return if $self->isSubversion();

    my $dirname = dirname( $self->{directory} );

    mkdir( $dirname );
    symlink( $self->{repos}, $self->{directory} );

    return;
}

## @fn     checkout
#  @brief  checkout the directory from subversion
#  @param  <none>
#  @return <none>
sub checkout {
    my $self = shift;

    return if not $self->isSubversion();

    my $basename = basename( $self->{repos} );  # src-fsmci
    my $dirname  = dirname( $self->{repos} );   # https://svne1.access.nsn.com/isource/svnroot/BTS_SC_LFS/os/KERNEL_3.4_DEV/trunk/ci
    my $svnUrl;

    my $svn = Nokia::Singleton::svn(); # the subversion client

    if( not -d ".svn" ) {
        $svn->checkout( url      => $self->{repos},
                        revision => $self->{revision},
                        args     => [ qw( -q --depth empty . ) ] );
    } else {

        my $svnInfo = $svn->info();
        # https://svne1.access.nsn.com/isource/svnroot/BTS_SC_LFS/os/KERNEL_3.4_DEV/trunk/fsmr3
        $svnUrl     = $svnInfo->{entry}->{url};
    }

    if( $svnUrl eq $self->{repos} && $basename eq $self->{directory} ) {
        $svn->update( dir      => $self->{directory},
                      revision => $self->{revision} );
    } else {
        $svn->checkout( dir      => $self->{directory},
                        url      => $self->{repos},
                        revision => $self->{revision} );
    }

    # 014-03-03 demx2fk3 TODO add need branch handling here

    return;
}
# }}} ------------------------------------------------------------------------------------------------------------------


1;
