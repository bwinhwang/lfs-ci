package Nokia::Command::DependenciesForMakefile; 
use strict;
use warnings;

use Nokia::Command;
use Nokia::Usecase::GetLocation;

use parent qw( Nokia::Command );

sub prepare {
    my $self = shift;
    my @args = @_;

    $self->{src}   = shift @args || die "no src";
    $self->{goal}  = shift @args || die "no cfg";

    @{ $self->{sourcesDirectories} } = <src-*>;
    @{ $self->{sources} } = ();

    my $loc = Nokia::Usecase::GetLocation->new();
    foreach my $subDir ( @{ $self->{sourcesDirectories} } ) {
        my $dir = $loc->getLocation( subDir   => $subDir );
        $dir->loadDependencyTree();
        push @{ $self->{sources} }, $dir;
    }

    return;
}

sub createMakefileEntry {
    my $self = shift;
    my $obj  = shift;
    my $goal = $self->{goal};

    return if $self->{seen}->{ $obj->directory() }++;

    my @deps;
    foreach my $dependency ( $obj->getDependencies() ) {
        next if not $dependency->matchesPlatform( $goal );
        push @deps, $dependency->bldDirectory( $goal );
        $self->createMakefileEntry( $dependency );
    }

    my %duplicates;
    printf "%s/%s/Version: %s\n", $ENV{BUILD_WORKDIR} || ".",
                                  $obj->bldDirectory( $goal ), 
                                  join( " ", grep { not $duplicates{ $_ }++ } 
                                             map { sprintf( "%s/%s/Version", $ENV{BUILD_WORKDIR} || ".", $_ ) } @deps );

    if( $obj->directory() ne $self->{src} ) {
        printf( "\t%s -C %s/%s %s --label=\$\(LABEL\) NOAUTOBUILD=1\n\n", $ENV{BUILD} || "build",
                                        $ENV{BUILD_WORKDIR} || ".",
                                        $obj->directory(), 
                                        $obj->matchingPlatform( $goal ) );
    } else {
        printf( "\n" );
    }

    return;
}

sub execute {
    my $self = shift;
    my $goal = $self->{goal};
    my $src  = $self->{src};

    my @sources = sort { $a->directory() cmp $b->directory() } @{ $self->{sources} };
    my %seen;

	print "ifneq \(\$\(NOAUTOBUILD\),1\)\n\n";
    foreach my $source ( @sources ) {
        next if not $source->matchesPlatform( $goal );
        next if $seen{ $source->directory() }++;

        $self->createMakefileEntry( $source );

    }
	print "endif\n\n";

    return 0;
}

1;
