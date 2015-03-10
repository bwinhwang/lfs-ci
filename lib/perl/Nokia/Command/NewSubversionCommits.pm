package Nokia::Command::GetBranchInformationFile;
use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use Log::Log4perl qw( :easy );

use Nokia::Handler::Database;

use parent qw( Nokia::Command; );

sub prepare {
    my $self = shift;
    $self->{opt_name} = "";
    $self->{opt_changelog} = "";
    GetOptions( 'buildName=s',     \$self->{opt_name},
                'changelog=s',     \$self->{opt_changelog},
            ) or LOGDIE "invalid option";
    return;
}

sub execute {
    my $self = shift;
    my $handler = Nokia::Handler::Database->new();
    my $xml = XMLin( $self->{opt_changelog}, ForceArray => 1 );

    foreach my $logentry ( @{ $xml->{logentry} } ) {
        $handler->newSubversionCommit( baselineName => $self->{pt_name},
                                       logentry     => $logentry );
    return;
}

1;
