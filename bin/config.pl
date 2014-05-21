#!/usr/bin/perl

package Object;

use warnings;
use strict;

our $AUTOLOAD;

sub new {
    my $class = shift;
    my $param = { @_ };
    my $self  = bless $param, $class;

    if( $self->can( "init" ) ) {
        $self->init();
    }
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
      or die "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://;    # strip fully-qualified portion

    if( not exists $self->{$name} ) {
        die "Can't access `$name' field in class $type";
    }

    if( @_ ) {
        return $self->{$name} = shift;
    }
    else {
        return $self->{$name};
    }
}

sub DESTROY {
    return;
}

package Model::Config;

use warnings;
use strict;
use parent qw( -norequire Object );

sub matches {
    my $self    = shift;
    my $matches = 0;

    foreach my $tag ( @{ $self->{tags} } ) {
        if( $tag->value() eq $self->{handler}->getConfig( name => $tag->name() ) ) {
            # printf "matching tag %s / %s found...\n", $tag->name(), $tag->value();
            $matches ++;
        } else {
            # printf "NOT matching tag %s / %s found...\n", $tag->name(), $tag->value();
            return 0;
        }
    }

    return scalar( @{ $self->{tags} } ) == $matches ? 1 : 0;
}

package Store::ConfigEnvironment;

use warnings;
use strict;
use parent qw( -norequire Object );

sub readConfig {
    my $self = shift;
    my $data;

    foreach my $key ( keys %ENV ) {
        push @{ $data }, {
                            name  => $key,
                            value => $ENV{$key} || "",
                            tags  => "",
                            }
    }
    return $data;
}

package Store::ConfigFile;

use warnings;
use strict;
use parent qw( -norequire Object );

sub readConfig {
    my $self  = shift;
    my $param = { @_ };
    my $file  = $self->{file};

    return if not -e $file;

    my $data = [];
    open FILE, $file or die "can not open file";
    while ( my $line = <FILE> ) {
        chomp( $line );
        next if $line =~ m/^#/;
        next if $line =~ m/^\s*$/;

        if( $line =~ /^(\w+)\s+\<\s*([^>]*)\s*\>\s+=\s+(.*)$/ ) {
            push @{ $data }, {
                                name  => $1 || "",
                                tags  => $2 || "",
                                value => $3 || "",
                             }
        }
    }
    close FILE;

    return $data;
}

package Handler;

use warnings;
use strict;
use parent qw( -norequire Object );

use Data::Dumper;

sub init {
    my $self = shift;
    $self->{configObjects} = [];
}

sub getConfig {
    my $self  = shift;
    my $param = { @_ };
    my $name  = $param->{name};

    my @canidates = grep { $_->matches()       }
                    grep { $_->name() eq $name }
                    @{ $self->{configObjects} };

    if( scalar( @canidates ) > 1 ) {
        die "error: more than one canidate found...";
    } elsif ( scalar( @canidates ) == 0 ) {
        # we are only handling strings, no undefs!
        # print "empty $name\n";
        return "";
    } else {
        # print "name $name " .  $canidates[0]->value() . "\n";
        return $canidates[0]->value();
    } 
    return;
}

sub loadData {
    my $self = shift;

    my @dataList;
    foreach my $store ( Store::ConfigFile->new( file => $self->{configFileName} ),
                        Store::ConfigEnvironment->new(), 
                      ) {
        push @dataList, @{ $store->readConfig() };
    }

    foreach my $cfg ( @dataList ) {
        # handling tags in an extra section here
        my @tags = ();
        foreach my $tag (split( /\s*,\s*/, $cfg->{tags} ) ) {
            if( $tag =~ m/(\w+):([^:\s]+)/ ) {
                push @tags, Model::Config->new( handler => $self,
                                                name    => $1, 
                                                value   => $2, 
                                              );
            } else {
                die "tag $tag does not match to syntax";
            }
        }
        
        push @{ $self->{configObjects} }, Model::Config->new(
                                                             handler => $self,
                                                             value   => $cfg->{value},
                                                             name    => $cfg->{name},
                                                             tags    => \@tags,
                                                            );
    }
    return
}

package main;

use strict;
use warnings;

use Data::Dumper;

my $configFileName = $ARGV[1] || $ENV{LFS_CI_CONFIG_FILE};
my $handler = Handler->new( configFileName => $configFileName );
$handler->loadData();

# print Dumper( $handler );
my $value = $handler->getConfig( name => $ARGV[0] );
print $value;
