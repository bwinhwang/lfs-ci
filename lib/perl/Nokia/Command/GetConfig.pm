package Nokia::Command::GetConfig; 
use strict;
use warnings;

use Nokia::Object;
use Nokia::Singleton;

use parent qw( Nokia::Object );

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );

sub prepare {
    my $self = shift;

    my $opt_f = $ENV{LFS_CI_CONFIG_FILE} || undef;
    my $opt_k = undef;
    my $opt_t = [];
    GetOptions( 'k=s',  \$opt_k,
                'f=s',  \$opt_f,
                't=s@', \$opt_t,
                ) or LOGDIE "invalid option";

    $self->{configKeyName}  = $opt_k || die "no key";

    if( $opt_f and -e $opt_f ) { 
        $self->{configFileName} = $opt_f;
    } else {
        LOGDIE sprintf( "config file %s does not exist.", $self->{configFileName} || "<undef>" );
    }

    DEBUG sprintf( "using config file %s", $self->{configFileName} );

    foreach my $value ( @{ $opt_t } ) {
        if( $value =~ m/([\w_]+):(.*)/ ) {
            DEBUG "adding setting $1 (value: $2)";
            Nokia::Singleton::configStore( "cache", storeClass => "cache" )->{data}->{ $1 } = $2;
        }
    }
    return;
}

sub execute {
    my $self = shift;

    Nokia::Singleton::config()->loadData( configFileName => $self->{configFileName} );
    my $value = Nokia::Singleton::config()->getConfig( name => $self->{configKeyName} );
    DEBUG sprintf( "config %s = %s", $self->{configKeyName}, $value );

    print $value;

    return;
}

1;
