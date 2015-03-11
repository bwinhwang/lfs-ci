package Nokia::Model::Config; 
## @fn     Model::Config
#  @brief  model for a configuration value

use strict;
use warnings;

use parent qw( Nokia::Model );

our $AUTOLOAD;

## @fn      AUTOLOAD( $value )
#  @brief   generic method to get/set a value form the configuration model
#  @warning It is possible that AUTOLOAD is a little bit inefficent and cause a performance problem
#  @param   {value}    value to set for this member
#  @return  value of the member
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

## @fn      matches()
#  @brief   checks, if all tags of the model are matching.
#  @param   <none>
#  @return  number of matches of tags. 0 means, that no tag is matching
sub matches {
    my $self    = shift;
    my $matches = 1;

    # printf STDERR "CHECK START - %s %s\n", $self->name(), $self->value();
    foreach my $tag ( @{ $self->{tags} } ) {
        my $value = $tag->value();
        # printf STDERR "check %s -- %s %s\n", $tag->name(), $value, $tag->operator();
        if( $tag->operator() eq "eq" 
            and $value eq $self->{handler}->getConfig( name => $tag->name() ) ) {
            # printf STDERR "matching tag %s / %s found...\n", $tag->name(), $value;
            $matches ++;
        } elsif ( $tag->operator() eq "regex" and $self->{handler}->getConfig( name => $tag->name()) =~ m/$value/ ) {
            # printf STDERR "matching tag %s / %s via regex found...\n", $tag->name(), $value;
            $matches ++;
        } else {
            # printf STDERR "NOT matching tag %s / %s found...\n", $tag->name(), $tag->value();
            return 0;
        }
    }
    $self->{matches} = $matches;

    # printf STDERR "CHECK END   - %s %s %s\n", $self->name(), $self->value(), $matches;

    return $matches;
}

1;
