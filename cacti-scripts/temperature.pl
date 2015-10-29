#!/usr/bin/env perl

# Script for use with Cacti's Data Input Methods
# Usage: ./temperature.pl <username> <password>
# Don't forget to put single quotes round any values that contain shell metacharacters
# Returns all temperatures and setpoints for the first location it finds

# Example output:
# living_room:21 living_room_setpoint:5 bedroom_1:19.5 bedroom_1_setpoint:5

use warnings;
use strict;

use Device::TotalConnectComfort qw( new );

# AUTHENTICATION:
# This can be passed in via the commandline (beware visible to ps..),
# Or preferably set environment variable TCC_USERNAME & TCC_PASSWORD
my ( $username, $password ) = @ARGV;
#my ($username, $password) = ('username', 'password'); # optionally hardcode user/pass
$username = $ENV{TCC_USERNAME} unless $username;
$password = $ENV{TCC_PASSWORD} unless $password;

# Log in
my $cn = Device::TotalConnectComfort->new( username => $username,
                                           password => $password );

# Get data for all our locations
my $locations_data = $cn->get_locations;
# Set default location id for other requests
my $location_id = $locations_data->[0]->{locationInfo}->{locationId};

# Get data on the default location
my $status_data = $cn->get_status($location_id);

# Dump cacti output
cacti_output($status_data);

sub cacti_output {
    my $status_data = shift;

    my $gateway = $status_data->{gateways}->[0];

    my $output;
    my $boiler_on = 0;
    for my $zone ( @{ $gateway->{temperatureControlSystems}->[0]->{zones} } ) {
        my $name = lc $zone->{name};
        $name =~ s/\s/_/g;
        my $temperature = $zone->{temperatureStatus}->{temperature};
        my $setpoint    = $zone->{setpointStatus}->{targetHeatTemperature},;

        $output .= "$name:$temperature ${name}_setpoint:$setpoint ";

        $boiler_on = 1 if ( $setpoint > $temperature );
    }

    $output .= "boiler_status:$boiler_on ";

    print $output;
}
