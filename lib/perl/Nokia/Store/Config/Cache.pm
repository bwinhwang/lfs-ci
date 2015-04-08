package Nokia::Store::Config::Cache; 

use warnings;
use strict;

use parent qw( Nokia::Object );

## @fn      readConfig()
#  @brief   read the "configuration" file for this config store
#  @details this store has no configuration file, it just generate all possible configuration values
#           and store it in a array 
#  @return  ref array with all possible configuration values for this store
sub readConfig {
    my $self = shift;
    my $data = [];

    foreach my $key ( keys %{ $self->{data} || {} } ) {
        push @{ $data }, {
                            name  => $key,
                            value => $self->{data}{$key} || "",
                            tags  => "",
                            }
    }
    return $data;
}


1;
