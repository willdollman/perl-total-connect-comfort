#!/usr/bin/env perl

# Simple script with one output for cacti testing

use warnings;
use strict;

use Device::TotalConnectComfort qw( new );

# Zone name to print the temperature for
my $ZONE = 'living room';

# AUTHENTICATION:
# This can be passed in via the commandline (beware visible to ps..),
# Or preferably set environment variable TCC_USERNAME & TCC_PASSWORD
my ( $username, $password ) = @ARGV;
#my ($username, $password) = ('username', 'password'); # optionally hardcode user/pass
$username = $ENV{TCC_USERNAME} unless $username;
$password = $ENV{TCC_PASSWORD} unless $password;

# Log in
my $cn = Device::TotalConnectComfort->new( $username, $password );

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
        if ($name eq $ZONE) {
            my $temperature = $zone->{temperatureStatus}->{temperature};
            $output = $temperature;
            last
        }
    }

    print $output;
}

