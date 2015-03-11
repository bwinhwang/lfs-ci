package Nokia::Singleton; 
## @fn    Singleton
#  @brief class which just provide a singelton - just one instance of this class
use strict;
use warnings;

use Log::Log4perl qw( :easy );

use Nokia::Config;
use Nokia::Store::Config::Cache;
use Nokia::Store::Config::File;
use Nokia::Hints;
use Nokia::Svn;

my $obj = bless {}, __PACKAGE__;

## @fn      svn()
#  @brief   return the svn handler
#  @param   <none>
#  @return  svn handler object
sub svn {
    if( not $obj->{svn} ) {
        $obj->{svn} = Nokia::Svn->new();
    }
    return $obj->{svn};
}

## @fn      hint()
#  @brief   return the hint handler
#  @param   <none>
#  @return  hint handler object
sub hint {
    if( not $obj->{hint} ) {
        $obj->{hint} = Nokia::Hints->new();
    }
    return $obj->{hint};
}

sub configStore {
    my $storeName  = shift;
    my $param      = { @_ };
    my $storeClass =  $param->{storeClass};
    if( not $obj->{config}{ $storeName } ) {
        if( $storeClass eq "cache" ) {
            $obj->{config}{ $storeName } = Nokia::Store::Config::Cache->new();
        } elsif( $storeClass eq "file" ) {
            my $fileName = $param->{configFileName};
            $obj->{config}{ $storeName } = Nokia::Store::Config::File->new( file => $fileName ),
        }
    }
    return $obj->{config}{ $storeName };
}

## @fn      config()
#  @brief   return the config handler
#  @param   <none>
#  @return  config handler object
sub config {
    if( not $obj->{config}{handler} ) {
        DEBUG "creating config handler";
        $obj->{config}{handler} = Nokia::Config->new();
        Nokia::Singleton::config->loadData( configFileName => $ENV{"LFS_CI_CONFIG_FILE"} );
    }
    return $obj->{config}{handler};
}

1;
