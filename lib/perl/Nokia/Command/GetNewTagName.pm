package Nokia::Command::GetNewTagName; # {{{
## @brief generate new tag
use strict;
use warnings;

use Getopt::Std;
use Data::Dumper;
use Log::Log4perl qw( :easy );

use Nokia::Object;

use parent qw( Nokia::Object );

sub prepare {
    my $self = shift;

    getopts( "r:i:o:", \my %opts );
    $self->{regex}  = $opts{r} or LOGDIE "no regex";
    $self->{oldTag} = $opts{o} or LOGDIE "no old tag";
    $self->{incr}   = $opts{i} // 1;

    return;
}

sub execute {
    my $self = shift;

    my $regex = $self->{regex};
    my $oldTag = $self->{oldTag};

    my $newTag         = $regex;
    my $newTagLastByte = "0001";

    if( $oldTag =~ m/^$regex$/ ) {
        $newTagLastByte = sprintf( "%04d", $1 + $self->{incr} );
    }
    $newTag =~ s/\(.*\)/$newTagLastByte/g;

    INFO "new tag will be $newTag based on $regex";
    printf $newTag;
    return;
}

1;
