package Nokia::Parser::Dependencies::Models::UseReadonly; # {{{
use strict;
use warnings;

use parent qw( Nokia::Parser::Model );

sub hasSourceDirectory {
    my $self = shift;
    return 1 if( $self->hasSourceParameter() && -d $self->sourceParameter() );
    return 0;
}

sub sourceParameter {
    my $self = shift;

    # check for --source
    # TODO: demx2fk3 2014-06-24 fixme
    if( $self->{src} =~ m:bld/bld-([a-z0-9]*)-.*: ) {
        if( -d sprintf( "src-%s", $1 ) ) {
            return sprintf( "src-%s", $1 );
        }
    }

    return;
}

sub hasSourceParameter {
    my $self = shift;
    return $self->sourceParameter() ? 1 : 0;
}

sub existsDirectory {
    my $self = shift;
    if( -d $self->{src} ) {
        warn sprintf( "%s exists", $self->{src} );
        return 1;
    }

    return 0;
}

sub cleanup {
    my $self = shift;
    if( -l $self->{src} ) {
        # printf( "cleanup %s\n", $self->{src} );
        unlink( $self->{src} )
    }
    return;
}

sub src { my $self = shift; return $self->{src}; }
sub tag { my $self = shift; return $self->{dst}->[0]; }


1;
