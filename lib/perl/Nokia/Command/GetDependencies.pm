package Nokia::Command::GetDependencies; 
use strict;
use warnings;

use Data::Dumper;

use Nokia::Usecase::GetLocation;

use parent qw( Nokia::Command );

sub prepare {
    my $self = shift;
    my @args = @_;

    $self->{dir}      = shift @args || die "no src dir";
    $self->{tag}      = shift @args || undef;
    $self->{revision} = shift @args || undef;

    return;
}

sub execute {
    my $self     = shift;
    my $subDir   = $self->{dir};
    my $tag      = $self->{tag};
    my $revision = $self->{revision};

    my $loc = Nokia::Usecase::GetLocation->new();
    my $dir = $loc->getLocation( subDir   => $subDir,
                                 tag      => $tag,
                                 revision => $revision );
    $dir->loadDependencyTree();

    # use YAML;
    # print STDERR Dumper($dir);

    printf( "%s %s", join( " ", $dir->getSourceDirectoriesFromDependencies() ),
                     $subDir,
          );
    return;
}

1;
