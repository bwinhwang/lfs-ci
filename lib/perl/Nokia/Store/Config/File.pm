package Nokia::Store::Config::File; 

use warnings;
use strict;

use Log::Log4perl qw( :easy );

use parent qw( Nokia::Object );

## @fn      readConfig()
#  @brief   read the configuration file for this config store
#  @details the format of the configuration file is:
#           name = value
#           name <> = value
#           name < tagName:tagValue > = value
#           name < tagName~tagRegex > = value
#           name < tagName:tagValue, tagName:tagValue > = value
#  @return  ref array with all possible configuratoin values for this store
sub readConfig {
    my $self  = shift;
    my $param = { @_ };
    my $file  = $self->{file};

    return if not -e $file;

    DEBUG "reading config file $file";

    my $tagsRE  = qr/ \s*
                       < (?<tags>[^>]*) >
                       \s*
                    /x;
    my $nameRE  = qr/ \s* 
                      (?<name>[\w_-]+) 
                      \s* 
                    /x;
    my $valueRE = qr/ \s* 
                      (?<value>.*)
                      \s* 
                    /x;
    my $includeRE = qr/ \s*
                        include\s*(?<fileName>.*)
                        \s*
                      /x;

    my $data = [];
    open my $fh, $file or die "can not open file \'$file\'";
    while ( my $line = <$fh> ) {
        chomp( $line );
        next if $line =~ m/^#/;
        next if $line =~ m/^\s*$/;

        if( $line =~ /^ $nameRE (?: $tagsRE | ) = $valueRE $/x ) {
            push @{ $data }, {
                                name  => $+{name}  || "",
                                value => $+{value} || "",
                                tags  => $+{tags}  || "",
                             }
        } elsif ( $line =~ /^ $includeRE $/x ) {
            my $fileName = $+{fileName};

            if ( ! -e $fileName ) {
                use File::Basename;
                $fileName = sprintf( "%s/%s", dirname( $self->{file} ), $fileName );
            }
            push @{ $data }, @{ Nokia::Store::Config::File->new( file => $fileName )->readConfig() || [] };
        }
    }
    close $fh;

    return $data;
}


1;
