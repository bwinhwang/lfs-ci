package Nokia::Parser::Model; # {{{
# @brief generic class to store information from the parser

use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use Nokia::Parser::Replacer;

use parent qw( Nokia::Object );

## @fn      match( $string )
#  @brief   checks, if the given strings matches to the src regex
#  @param   {string}    string to match
#  @return  1 if string matches to regex, 0 otherwise
sub match {
    my $self   = shift;
    my $string = shift;
    my $regex  = $self->{src};
    $regex =~ s/\*/\.\*/g;

    return $string =~ m/$regex/ ? 1 : 0
}

## @fn      replaceLocations( $param )
#  @brief   replace the placeholders in the location with the real value
#  @param   {locations}    list of all locations
#  @return  <none>
sub replaceLocations {
    my $self = shift;
    my $param = { @_ };
    my @locations = @{ $param->{locations} || [] };

    foreach my $location (
                            map  { $_->[0]                     }
                            sort { $b->[1] cmp $a->[1]         }
                            map  { [ $_, length( $_->{src} ) ] }
                            @locations
    ) {
        $self->{dst} =~ s/$location->{src}/$location->{dst}/ge;
    }

    my $replacer = Nokia::Parser::Replacer->new();

    $self->{dst} = $replacer->replace( replace => "TAG",
                                       value   => $param->{tag},
                                       string  => $self->{dst} );

    $self->{dst} = $replacer->replace( replace => "BRANCH",
                                       value   => $param->{branch},
                                       string  => $self->{dst} );

    $self->{dst} = $replacer->replace( replace => "DIR",
                                       value   => $param->{dir},
                                       string  => $self->{dst} );

    $self->{dst} = $replacer->replace( replace => "BUILD_HOST",
                                       value   => $ENV{BUILD_HOST} || "",
                                       string  => $self->{dst} );

    return;
}

1;
