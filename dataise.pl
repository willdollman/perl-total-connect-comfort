#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;
use Text::Table;

use Device::TotalConnectComfort qw( new );

my $username = '';
my $password = '';
my $app_id   = '';

my $is_test;
#$is_test = 1;

# Log in
my $cn = Device::TotalConnectComfort->new($username, $password, $app_id, $is_test);
print "Logged in as $cn->{username}";

# Get data for all our locations
my $location_data = $cn->get_locations;
# ... and do something interesting with it
describe_locations($location_data);

# Print some info
sub describe_locations {
    my $location_data = shift;

    print "Got ", scalar @$location_data, " locations:";
    for my $locations (@$location_data) {
        print "  ID: $locations->{locationID}";
    }

    # Let's just look at the first location
    print "\nGot ", scalar @{$location_data->[0]->{devices}}, " devices:";
    my $tb = Text::Table->new('Location', 'Temperature', 'Status');
    for my $device (@{$location_data->[0]->{devices}}) {
        $tb->load([
            "$device->{name} ",
            "$device->{thermostat}->{indoorTemperature}°C",
            $device->{thermostat}->{changeableValues}->{mode},
        ]);
    }

    print $tb;
}
