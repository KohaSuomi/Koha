package Koha::Exceptions::Holding;

use Modern::Perl;

use Exception::Class (

    'Koha::Exceptions::Holding' => {
        description => 'Something went wrong!',
    },
    'Koha::Exceptions::Holding::MissingProperty' => {
        isa         => 'Koha::Exceptions::Holding',
        description => "Missing a property",
        fields      => [ "path" ],
    },

);

1;
