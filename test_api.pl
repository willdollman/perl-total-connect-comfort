#!/usr/bin/env perl

use warnings;
use strict;

use Data::Dumper;
use Text::Table;

use Device::TotalConnectComfort;

# AUTHENTICATION:
# This can be passed in via the commandline (beware visible to ps..),
# Or preferably set environment variable TCC_USERNAME & TCC_PASSWORD
my ($username, $password) = @ARGV;
#my ($username, $password) = ('username', 'password'); # optionally hardcode user/pass
$username = $ENV{TCC_USERNAME} unless $username;
$password = $ENV{TCC_PASSWORD} unless $password;

# Log in
my $cn = Device::TotalConnectComfort->new( username => $username,
                                           password => $password );
print "Logged in\n";
my $account = $cn->get_user_account;

# Get data for all our locations
my $locations_data = $cn->get_locations;
describe_locations($locations_data);

# Set default location id for other requests
my $location_id = $locations_data->[0]->{locationInfo}->{locationId};
print "Setting default location ID to $location_id\n";

# Get data on the default location
my $status_data = $cn->get_status($location_id);
describe_status( $status_data );

# Describe gateways
my $gateway_data = $cn->get_gateways($location_id);
describe_gateways($gateway_data);

# Refresh/re-login with the login token... (just to show how)
$cn->do_login(refresh_token => $cn->{refresh_token});

# print Dumper($locations_data);
# print Dumper($status_data);

# Describe each location found
sub describe_locations {
    my $locations_data = shift;

    print "Found ", scalar @$locations_data, ' ',
      ( scalar @$locations_data == 1 ) ? 'location' : 'locations', "\n";
    for my $location (@$locations_data) {
        print "Location $location->{locationInfo}->{locationId} ($location->{locationInfo}->{streetAddress})\n---\n";
        # describe_devices($location);
    }
}

# Describe status at a given location
sub describe_status {
    my $status_data = shift;

    #print "\n", scalar @{$status_data->{devices}}, " devices:";
    my $tb =
      Text::Table->new( 'Location', 'Temperature °C', 'Status', 'Setpoint °C', 'ZoneId' );
    for my $zone ( @{ $status_data->{gateways}->[0]->{temperatureControlSystems}->[0]->{zones} } ) {
        $tb->load(
            [
                $zone->{name},
                $zone->{temperatureStatus}->{temperature},
                $zone->{setpointStatus}->{setpointMode},
                $zone->{setpointStatus}->{targetHeatTemperature},
                $zone->{zoneId},
            ]
        );
    }

    print $tb;
}

# Describe all gateway devices found
sub describe_gateways {
    my $gateway_data = shift;

    for my $gw (@$gateway_data) {
        print "Found gateway ID: $gw->{gatewayId}, MAC address: $gw->{mac}\n";
    }
}

