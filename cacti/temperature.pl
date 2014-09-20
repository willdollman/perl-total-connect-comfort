#!/usr/bin/perl

use warnings;
use strict;

use Device::TotalConnectComfort qw( new );

my $username = '';
my $password = '';
my $app_id   = '';

my $is_test;
#$is_test = 1;

# Log in
my $cn = Device::TotalConnectComfort->new($username, $password, $app_id, $is_test);

# Get data for all our locations
my $locations_data = $cn->get_locations;

# Dump cacti output
cacti_output($locations_data);

sub cacti_output {
    my $locations_data = shift;

    my $location = $locations_data->[0];

    my $output;
    my $boiler_on = 0;
    for my $device (@{$location->{devices}}) {
        $device->{name} =~ s/\s/_/g;
        my $name = lc $device->{name};
        my $temperature = $device->{thermostat}->{indoorTemperature};
        my $setpoint = $device->{thermostat}->{changeableValues}->{heatSetpoint}->{value};

        $output .= "$name:$temperature ";
        $output .= $name . "_setpoint:$setpoint ";

        $boiler_on = 1 if ($setpoint > $temperature);
    }

    $output .= "boiler_status:$boiler_on ";

    print $output;
}
