package Nokia::Command::GetBranchInformation;
use strict;
use warnings;

use parent qw( Nokia::Command );
use Nokia::Handler::Database;
use Data::Dumper;

sub prepare() {
    return;
}

sub execute {
    my $self = shift;
    my $result = Nokia::Handler::Database->new()->branchInformation();
    
    print "# this file is automatically generated by $0\n";
    print "# do not edit it by hand\n";
    foreach my $row ( sort { $a->{name} cmp $b->{name} or $a->{tags} cmp $b->{tags} } @{ $result } ) {
        printf( "%-45s < %-50s > = %s\n",
                    $row->{name},
                    $row->{tags}  || "",
                    $row->{value} || "",
        );
    }
    print "# this file is automatically generated by $0\n";
    print "# do not edit it by hand\n";
    
    return;
}

1;
