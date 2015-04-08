package Nokia::Object; 
## @fn    Object
#  @brief base class of all other classes.

use strict;
use warnings;

## @fn     new( %param )
#  @brief  this class is the base of all objects
#  @detail in basic it's just the new method to avoid to write this method every time
sub new {
    my $class = shift;
    my $param = { @_ };
    my $self  = bless $param, $class;

    if( $self->can( "init" ) ) {
        $self->init();
    }
    return $self;
}

1;
