package Nokia::Parser::Locations; # {{{
use strict;
use warnings;

use Data::Dumper;

use Nokia::Parser::Locations::Models::PhysicalLocations;
use Nokia::Parser::Locations::Models::PhysicalLocations;
use Nokia::Parser::Locations::Models::SearchTag;
use Nokia::Parser::Locations::Models::SearchTrunk;
use Nokia::Parser::Locations::Models::SearchBranch;

use parent qw( Nokia::Parser );

sub dir             { my $self = shift; push @{ $self->{data}->{dir} }, @_; return; }
sub local_directory {
    my $self = shift;
    push @{ $self->{data}->{physicalLocations} }, Nokia::Parser::Locations::Models::PhysicalLocations->new( src => $_[0], dst => $_[1], type => "local" );
    return;
}

sub svn_repository {
    my $self = shift;
    push @{ $self->{data}->{physicalLocations} }, Nokia::Parser::Locations::Models::PhysicalLocations->new( src => $_[0], dst => $_[1], type => "svn" );
    return;
}

sub search_tag      {
    my $self = shift;
    push @{ $self->{data}->{searchTag} }, Nokia::Parser::Locations::Models::SearchTag->new( src => $_[0], dst => $_[1] );
    return;
}

sub search_trunk {
    my $self = shift;
    push @{ $self->{data}->{searchTrunk} }, Nokia::Parser::Locations::Models::SearchTrunk->new( src => $_[0], dst => $_[1] );
    return;
}

# not supported any more
sub search_branch {
    my $self = shift;
    push @{ $self->{data}->{searchBranch} }, Nokia::Parser::Locations::Models::SearchBranch->new( src => $_[0], dst => $_[1] );
    return;
}

sub getReporitoryOrLocation {
    my $self   = shift;
    my $param  = { @_ };

    my $subDir = $param->{subDir};
    my $tag    = $param->{tag};

    # todo add support for hints here

    foreach my $model (
                           @{ $self->{data}->{searchBranch} },
                    $tag ? @{ $self->{data}->{searchTag}    } : (),
                           @{ $self->{data}->{searchTrunk}  }
                      ) {
        if( $model->match( $subDir ) ) {
            return $model;
        }

    }
    return;
}

1;
