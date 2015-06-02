package Nokia::Command::DumpConfig; 
use strict;
use warnings;

use Nokia::Object;
use Nokia::Singleton;

use parent qw( Nokia::Object );

use Getopt::Long;
use Log::Log4perl qw( :easy );

sub prepare {
    my $self = shift;

    my $opt_f = $ENV{LFS_CI_CONFIG_FILE} || undef;
    GetOptions( 'f=s',  \$opt_f,) or LOGDIE "invalid option";

    if( $opt_f and -e $opt_f ) { 
        $self->{configFileName} = $opt_f;
    } else {
        LOGDIE sprintf( "config file %s does not exist.", $self->{configFileName} || "<undef>" );
    }
    return;
}

sub execute {
    my $self = shift;
    foreach my $entry ( sort { $a->name() cmp $b->name() } @{ Nokia::Singleton::config()->{configObjects} } ) {
        printf( "%80s | %-50s | %s\n", 
            $entry->name(), 
            join( ",", map { sprintf( "%s:%s", $_->name(), $_->value() ) } @{ $entry->tags() } ), 
            $entry->value(), 
            );
    }
    return;
}

1;
