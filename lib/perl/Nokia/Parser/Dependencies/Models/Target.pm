package Nokia::Parser::Dependencies::Models::Target; 
use strict;
use warnings;

use Data::Dumper;

use parent qw( Nokia::Parser::Model );

sub cleanup {
    my $self = shift;
    if( -l $self->{target} ) {
        unlink( $self->{target} );
    }
    return;
}

sub platform {
    my $self   = shift;
    my $target = $self->{target};
    $target =~ s:bld/bld-\w+-(\w+):$1:;
    return $target;
}

sub platforms {
    my $self   = shift;
    my $target = $self->{target};
    my @platforms;
    $target =~ s:bld/bld-\w+-(\w+):$1:;
    push @platforms, $target;
    push @platforms, $self->targetsParameter();

    return @platforms;
}

## @fn      matchingPlatform( $platform )
#  @brief   return the name of the matching platform
#  @param   {platform}    name of the requested platform
#  @return  name of the platform
sub matchingPlatform {
    my $self     = shift;
    my $platform = shift;
    
    return $self->platform() if $self->hasTargetsParameter() and scalar( grep { $platform eq $_ or $_ eq "all" } $self->targetsParameter() ) > 0;
    return $self->platform() if $self->{target} =~ m/-$platform/;
    return;
}

sub matchesPlatform {
    my $self     = shift;
    my $platform = shift;

    return 1 if $self->matchingPlatform( $platform );
    return 0;
}

sub hasTargetsParameter {
    my $self = shift;
    return 1 if( $self->targetsParameter() );
    return 0;
}

sub targetsParameter {
    my $self = shift;

    return if scalar( @{ $self->{params} } ) != 1;

    if(  $self->{params}->[0] =~ m/^--cfgs=(.*)/ ) {
        return split( ",", $1 );
    }
    return;
}

1;
