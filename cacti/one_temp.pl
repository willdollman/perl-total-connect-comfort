#!/usr/bin/perl

# Simple script with one output for cacti testing

use warnings;
use strict;

use Device::TotalConnectComfort qw( new );

my ($username, $password) = @ARGV;
#my ($username, $password) = ('username', 'password'); # optionally hardcode user/pass

# Log in
my $cn = Device::TotalConnectComfort->new($username, $password);

# Get data for all our locations
my $locations_data = $cn->get_locations;

# Dump cacti output
cacti_output($locations_data);

sub cacti_output {
    my $locations_data = shift;

    my $location = $locations_data->[0];

    my $output;
    for my $device (@{$location->{devices}}) {
        $device->{name} =~ s/\s/_/g;
        $device->{name} = lc $device->{name};
        $output .= "$device->{thermostat}->{indoorTemperature} "; 
        last;
    }

    print $output;
}
