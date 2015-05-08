package Nokia::Command::SortBuildsFromDependencies; # {{{
use strict;
use warnings;

use Data::Dumper;

use Nokia::Usecase::GetLocation;

use parent qw( Nokia::Command );

sub prepare {
    my $self = shift;
    my @args = @_;

    $self->{goal}  = shift @args || die "no src dir";
    $self->{style} = shift @args || "makefile";
    $self->{label} = shift @args;

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

sub execute {
    my $self = shift;
    my $goal = $self->{goal};


    my @sources = sort { $a->{directory} cmp $b->{directory} } @{ $self->{sources} };
    my %seen;
        print Dumper( $self );

SOURCES:
    while( scalar( @sources > 0 ) ) {
        my $source = shift @sources;
        next if not $source;


        my @deps = map  { $_->{directory} }
                   # grep { $_->{sourceExistsInFileSystem} }
                   $source->getDependencies();

        foreach my $dep ( sort @deps ) {
            next if not $dep =~ /src-/;
            if( not $seen{ $dep } ) {
                push @sources, $source;
                next SOURCES;
            }
        }

        my %duplicate;
        my @filteredDeps = sort 
                           grep { /src-/ } 
                           grep { not $duplicate{$_}++; } 
                           @deps;

        if( $self->{style} eq "makefile" ) {
            # t: t-1 t-2
            # t-1:
            #     build -C t 1

            # print label information for different components
            my $label = $self->{label};
            if( grep { $_ eq $source->{directory} } qw ( src-bos src-fsmbos src-fsmbos35 src-mbrm src-fsmbrm src-fsmbrm35 src-tools35 ) ) {
                $label =~ s/PS_LFS_OS/LFS/g;
                $label =~ s/PS_LFS_BT/LBT/g;
                $label =~ s/_20(\d\d)_/$1/g;
                $label =~ s/_//g;
            }

            printf "%s: LABEL := %s\n\n", $source->{directory}, $label;

            if( $source->matchesPlatform( $goal ) ) {
                printf ".PHONY: %s\n\n", $source->{directory};
                printf "%s: ", $source->{directory};
                foreach my $platform ( sort $source->matchingPlatform( $goal ) ) {
                    printf "%s-%s ", $source->{directory}, $platform;
                }
                printf "\n";
            }

            foreach my $target ( sort $source->targets() ) {
                my $platform = $target->platform();
                foreach my $p ( $target->targetsParameter() ) {
                    if( $p ne $platform ) {
                        printf "%s-%s: %s-%s\n\n", $source->{directory}, $p, $source->{directory}, $platform;
                    }

                }
                printf "%s-%s: %s\n", $source->{directory}, $platform, join( " ", @filteredDeps );
                printf "\t/usr/bin/time -v build -L \$@.log -C %s %s --label=\$(LABEL)\n\n", $source->{directory}, $platform;
            }
        } elsif( $self->{style} eq "legacy" ) {
            my %duplicate2;
            printf "%s %s - %s\n",
                    $source->{directory},
                    join( ",", sort grep { not $duplicate2{ $_ }++ } $source->platforms() ),
                    join( ",", sort 
                               @filteredDeps 
                    );
        } else {
            die "style is unknown";
        }

        $seen{ $source->{directory} } ++;
    }

    return 0;
}

1;
