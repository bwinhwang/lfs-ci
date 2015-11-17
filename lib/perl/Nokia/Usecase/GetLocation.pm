package Nokia::Usecase::GetLocation; # {{{
use strict;
use warnings;

use Data::Dumper;
use Storable qw( dclone );

use Nokia::Parser::Locations;
use Nokia::Singleton;
use Nokia::Model::Subdirectory;

use parent qw( Nokia::Object );

sub init {
    my $self = shift;

    my $locations = Nokia::Parser::Locations->new();

    if( not $self->{fileName} ) {
        my @tmp = glob("locations/*/Dependencies");
        $self->{fileName} = shift @tmp;
    }

    $locations->{fileName} = $self->{fileName};
    $locations->parse();
    $self->{locations} = $locations;

    return;
}

sub getDirEntries {
    my $self = shift;
    return @{ $self->{locations}->{data}->{dir} || []};
}

sub getLocation {
    my $self  = shift;
    my $param = { @_ };

    my $subDir   = $param->{subDir};
    my $tag      = $param->{tag};
    my $revision = $param->{revision};

    if( Nokia::Singleton::hint()->hint( $subDir ) ) {
        $tag = Nokia::Singleton::hint()->hint( $subDir );
    }

    # printf STDERR "LOCATION HINT %s %s -- %s\n", $subDir, $tag // "undef tag", Singleton::hint()->hint( $subDir ) // "undef";
    
    my $tmp = $self->{locations}->getReporitoryOrLocation( subDir => $subDir,
                                                           tag    => $tag );
    if( $tmp ) {
        my $repos = dclone ( # create a deep clone copy of the object
                            $tmp
                           );

        $repos->{subDir} = $subDir;
        $repos->replaceLocations( locations => $self->{locations}->{data}->{physicalLocations},
                                  dir       => $subDir,
                                  tag       => $tag );

        my $subDirectory = Nokia::Model::Subdirectory->new(
                                                    directory => $subDir,
                                                    tag       => $tag,
                                                    revision  => $revision,
                                                    repos     => Nokia::Singleton::svn()->replaceMasterByUlmServer( $repos->{dst} ),
                                                );
        return $subDirectory;
    }
    else {
        if( not $subDir eq "bldtools/bld-buildtools-common" ) {
            # we know the problem with bldtools/bld-buildtools-common
            warn "can not find location $subDir";
        }
    }

    return;
}

## @fn      prepare()
#  @brief   prepare the usecase
#  @param   <none>
#  @return  <none>
sub prepare {
    my $self  = shift;
    # NOOP
    return;
}

## @fn      execute()
#  @brief   execute the usecase
#  @param   <none>
#  @return  <none>
sub execute {
    my $self = shift;
    # NOOP
    return;
}

1;
