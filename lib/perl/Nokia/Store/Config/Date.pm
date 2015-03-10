package Nokia::Store::Config::Date; 

use warnings;
use strict;

use Data::Dumper;

use parent qw( Nokia::Object );

## @fn      readConfig()
#  @brief   read the "configuration" file for this config store
#  @details this store has no configuration file, it just generate all possible configuration values
#           and store it in a array 
#  @return  ref array with all possible configuration values for this store
sub readConfig {
    my $self  = shift;

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime( time() );
    $year += 1900;
    $mon  += 1;

    my $data = [];

    push @{ $data }, { name => "date_%Ymd", value => sprintf( "%04d%02d%02d", $year, $mon, $mday ), tags => "" };
    push @{ $data }, { name => "date_%Y",   value => sprintf( "%04d", $year ), tags => "" };
    push @{ $data }, { name => "date_%y",   value => sprintf( "%02d", ( $year - 2000 )), tags => "" };
    push @{ $data }, { name => "date_%m",   value => sprintf( "%02d", $mon  ), tags => "" };

    return $data;
}

1;
