#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;
use Text::Table;

use Device::TotalConnectComfort qw( new );

my ($username, $password) = @ARGV;
#my ($username, $password) = ('username', 'password'); # optionally hardcode user/pass

# Log in
my $cn = Device::TotalConnectComfort->new( $username, $password );
print "Logged in as $cn->{username}";

# Get data for all our locations
my $locations_data = $cn->get_locations;
describe_locations($locations_data);

# Set default location id for other requests
my $location_id = $locations_data->[0]->{locationID};
print "Setting default location ID to $location_id\n";

# Get data on the default location
my $location_data = $cn->get_location($location_id);
describe_devices( $location_data->[0] );

# Describe gateways
my $gateway_data = $cn->get_gateways($location_id);
describe_gateways($gateway_data);

# Describe each location found
sub describe_locations {
    my $locations_data = shift;

    print "Found ", scalar @$locations_data, ' ',
      ( scalar @$locations_data == 1 ) ? 'location' : 'locations', "\n";
    for my $location (@$locations_data) {
        print
          "Location $location->{locationID} ($location->{streetAddress})\n---";
        describe_devices($location);
    }
}

# Describe devices at a given location
sub describe_devices {
    my $location_data = shift;

    #print "\n", scalar @{$location_data->{devices}}, " devices:";
    my $tb =
      Text::Table->new( 'Location', 'Temperature', 'Status', 'Setpoint' );
    for my $device ( @{ $location_data->{devices} } ) {
        $tb->load(
            [
                "$device->{name} ",
                "$device->{thermostat}->{indoorTemperature}°C",
                $device->{thermostat}->{changeableValues}->{mode},
                $device->{thermostat}->{changeableValues}->{heatSetpoint}
                  ->{value},
            ]
        );
    }

    print $tb;
}

# Describe all gateway devices found
sub describe_gateways {
    my $gateway_data = shift;

    for my $gw (@$gateway_data) {
        print "Found gateway ID $gw->{gatewayID} at location $gw->{locationId}";
    }
}
