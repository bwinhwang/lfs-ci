package Nokia::Config; 

use warnings;
use strict;

use Data::Dumper;
use Log::Log4perl qw( :easy );

use Nokia::Model::Config;
use Nokia::Store::Config::Environment;
use Nokia::Store::Config::File;
use Nokia::Store::Config::Cache;
use Nokia::Store::Config::Date;

use parent qw( Nokia::Object );

## @fn      init()
#  @brief   initialize the config handler object
#  @param   <none>
#  @return  <none>
sub init {
    my $self = shift;
    $self->{configObjects} = [];
    return;
}

## @fn      getConfig( $param )
#  @brief   get the configuration value for a specified name
#  @param   {name}    name of the config
#  @return  value of the config
sub getConfig {
    my $self  = shift;
    my $param = { @_ };
    my $name  = $param->{name};

    my @candidates = map  { $_->[0]               } # schwarzian transform
                     sort { $b->[1] <=> $a->[1]   } 
                     grep { $_->[1]               }
                     map  { [ $_, $_->matches() ] }
                     grep { $_->name() eq $name   }
                     @{ $self->{configObjects} };

    if( scalar( @candidates ) > 1 ) {
        # TODO: demx2fk3 2014-06-18 warning -- die "error: more than one canidate found...";
    } elsif ( scalar( @candidates ) == 0 ) {
        # we are only handling strings, no undefs!
        # print "empty $name\n";
        return "";
    } 
    my $value = $candidates[0]->value();
    $value =~ s:
                    \$\{
                        ( [^}]+ )
                      \}
                :
                        $self->getConfig( name => $1 ) || "\${$1}"
                :xgie;
    DEBUG sprintf( "key name %s => %s", $name, $value || '<undef>' );
    return $value;
}

## @fn      loadData( $param )
#  @brief   load the data for a config store
#  @param   {configFileName}    name of the configu file
#  @return  <none>
sub loadData {
    my $self  = shift;
    my $param = { @_ };

    # TODO: demx2fk3 2014-10-06 FIXME
    my $fileName = $param->{configFileName} || $ENV{LFS_CI_CONFIG_FILE} || sprintf( "%s/etc/global.cfg", $ENV{LFS_CI_ROOT} || "." );
    # DEBUG "used config file in handler: $fileName";
    Nokia::Singleton::invalidateConfigStore( "file" );

    my @dataList;
    # TODO: demx2fk3 2014-10-06 this should be somehow configurable
    foreach my $store ( 
                        Nokia::Store::Config::Environment->new(), 
                        Nokia::Store::Config::Date->new(), 
                        Nokia::Singleton::configStore( "cache", storeClass => "cache" ),
                        Nokia::Singleton::configStore( "file",  storeClass => "file", configFileName => $fileName ),
                      ) {
        push @dataList, @{ $store->readConfig() || [] };
    }


    foreach my $cfg ( @dataList ) {
        # handling tags in an extra section here
        my @tags = ();
        foreach my $tag (split( /\s*,\s*/, $cfg->{tags} ) ) {
            if( $tag =~ m/(\w+):([^:\s]+)/ ) {
                push @tags, Nokia::Model::Config->new( 
                                                handler  => $self,
                                                name     => $1, 
                                                value    => $2, 
                                                operator => "eq"
                                              );
            } elsif( $tag =~ m/(\w+)~([^:\s]+)/ ) {
                push @tags, Nokia::Model::Config->new( 
                                                handler  => $self,
                                                name     => $1, 
                                                value    => $2, 
                                                operator => "regex"
                                              );
            } elsif( $tag =~ m/^\s*$/ ) {
                # skip empty string
            } else {
                die "tag $tag does not match to syntax";
            }
        }
        
        push @{ $self->{configObjects} }, Nokia::Model::Config->new(
                                                             handler => $self,
                                                             value   => $cfg->{value},
                                                             name    => $cfg->{name},
                                                             tags    => \@tags,
                                                            );
    }

    return
}

sub addConfig {
    my $self  = shift;
    my $param = { @_ };
    push @{ $self->{configObjects} }, Nokia::Model::Config->new(
                                                            handler => $self,
                                                            value   => $param->{value} || "",
                                                            name    => $param->{name}  || "",
                                                            tags    => $param->{tags} || [],
                                                        );
    return
}

1;
