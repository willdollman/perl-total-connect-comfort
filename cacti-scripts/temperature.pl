#!/usr/bin/perl

# Script for use with Cacti's Data Input Methods
# Usage: ./temperature.pl <username> <password>
# Don't forget to put single quotes round any values that contain shell metacharacters
# Returns all temperatures and setpoints for the first location it finds

# Example output:
# living_room:21 living_room_setpoint:5 bedroom_1:19.5 bedroom_1_setpoint:5

use warnings;
use strict;

use Device::TotalConnectComfort qw( new );

my ( $username, $password ) = @ARGV;
#my ($username, $password) = ('username', 'password'); # optionally hardcode user/pass

# Log in
my $cn = Device::TotalConnectComfort->new( $username, $password );

# Get data for all our locations
my $locations_data = $cn->get_locations;

# Dump cacti output
cacti_output($locations_data);

sub cacti_output {
    my $locations_data = shift;

    my $location = $locations_data->[0];

    my $output;
    my $boiler_on = 0;
    for my $device ( @{ $location->{devices} } ) {
        $device->{name} =~ s/\s/_/g;
        my $name        = lc $device->{name};
        my $temperature = $device->{thermostat}->{indoorTemperature};
        my $setpoint =
          $device->{thermostat}->{changeableValues}->{heatSetpoint}->{value};

        $output .= "$name:$temperature ";
        $output .= $name . "_setpoint:$setpoint ";

        $boiler_on = 1 if ( $setpoint > $temperature );
    }

    $output .= "boiler_status:$boiler_on ";

    print $output;
}
