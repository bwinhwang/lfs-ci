package Nokia::Model::Build;

use strict;
use warnings;

use parent qw( Nokia::Object );

sub baselineName { my $self = shift; return $self->{baselineName}; }
sub branchName   { my $self = shift; return $self->{branchName};   }
sub revision     { my $self = shift; return $self->{revision};     }
sub comment      { my $self = shift; return $self->{comment};      }

1;
