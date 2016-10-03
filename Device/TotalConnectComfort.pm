#!/usr/bin/perl

use warnings;
use strict;

package Device::TotalConnectComfort;

use Carp;
use Data::Dumper;
use JSON;
use LWP::UserAgent;
use URI::Escape qw( uri_escape );

use base qw( Exporter );
our @EXPORT_OK = qw( new );

my $DEBUG = 0;
$\ = "\n";

my $BASE_PATH = '/WebAPI/emea/api/v1/';

# Hardcoded version of the app
my $app_id = '2ff150b4-a385-40d5-8899-5c6d88d2cbc2';

sub new {
    shift;
    my %params = @_;

    unless ( exists($params{refresh_token}) || ( exists($params{username}) && exists($params{password})) ) {
        croak "Must supply either username/password or refresh_token";
    }

    my $is_test  = $params{test} || 0;
    delete $params{test};

    my $self = bless {};

    my $test_file = 't/login_response';
    my $login_response;

    if ($is_test) {
        print "Using cached response" if $DEBUG;

        open( my $test_file_fh, '<', $test_file )
          or die "Unable to open test input file";
        my $response_body = read_file($test_file_fh);
        $login_response = from_json($response_body);
    }
    else {
        print "Actually logging in" if $DEBUG;

        $login_response = $self->do_login( %params );

        if ($DEBUG) {
            open( my $response_fh, '>', $test_file )
              or die "Unable to open file for writing: $!";
            print $response_fh to_json($login_response);
        }
    }

    die "Error during login. Server response did not contain a session id token"
      unless $self->{access_token};

    print "Successfully authenticated - got session token:\n" . $self->{access_token} if $DEBUG;

    return $self;
}

# Helper function
sub uri_encode_params {
    my $params = shift;
    my $uri = join '&', map { uri_escape($_) . '=' . uri_escape($params->{$_}) } keys %$params;
}

# Perform login to API
sub do_login {
    my $self         = shift;
    my %login_params = @_;

    # grant_type is either 'password' and sent username/password
    # or set 'refresh_token' and send refresh_token from previous login response.
    if (exists($login_params{refresh_token})) {
        %login_params = (
            %login_params,
            'grant_type' => 'refresh_token',
            'scope'      => 'EMEA-V1-Basic EMEA-V1-Anonymous EMEA-V1-Get-Current-User-Account EMEA-V1-Contractor-Connections',
        );
    } else {
        %login_params = (
            %login_params,
            'grant_type' => 'password',
            'scope'      => 'EMEA-V1-Basic EMEA-V1-Anonymous EMEA-V1-Get-Current-User-Account EMEA-V1-Contractor-Connections',
        );
    }

    my $query_body = uri_encode_params(\%login_params);

    # Ensure we erase our old access token. It should be recreated when we login successfully
    delete $self->{access_token};

    my $login_response = $self->_api_call(
        method => 'POST',
        path   => '/Auth/OAuth/Token',
        body   => $query_body,
    );

    $self->{access_token} = $login_response->{access_token};
    $self->{refresh_token} = $login_response->{refresh_token};
    $self->{token_expires}    = time + $login_response->{expires_in};

    return $login_response;
}

# Creates a LWP::UserAgent request with the correct headers
sub _setup_request {
    my $self   = shift;
    # method, path, url_params (url parameters), body (body content)
    my %params = @_;

    # Setup location
    my $host      = 'https://tccna.honeywell.com';
    # conditionally add default $BASE_PATH unless passed an absolute uri
    my $base_path = (substr($params{path}, 0, 1) eq '/') ? '' : $BASE_PATH;
    my $url       = URI->new( $host . $base_path . $params{path} );
    $url->query_form( $params{url_params} ) if $params{url_params};

    # Add useragent string
    my $ua = LWP::UserAgent->new;
    $ua->agent('User-Agent: RestSharp 104.4.0.0');

    my $request = HTTP::Request->new( $params{method} => $url );
    $request->header( 'Accept' => 'application/json' );
    $request->header( 'Content-Type' => 'application/json');

    $request->header( 'applicationId', $app_id );
    $request->content( $params{body} ) if $params{body};

    if ($self->{access_token}) {
        $request->header( 'Authorization' => "bearer $self->{access_token}" ); # Actual auth token
    }
    else {
        $request->header( 'Authorization' => 'Basic MmZmMTUwYjQtYTM4NS00MGQ1LTg4OTktNWM2ZDg4ZDJjYmMyOjZGODhCOTgwLUI5OTUtNDUxRC04RTJBLTY2REMyQkNCRDU3MQ==' ); # Base64 Encoded App Token
    }

    return ( $ua, $request );
}

# Actually make the request, handle errors and return JSON-decoded body
sub _handle_request {
    my $self                   = shift;
    my ($ua, $request, $debug) = @_;

    my $r = $ua->request($request);

    print "\nFull error message:\n\n" . $r->as_string if $r->code >= 300;

    die "Invalid username/password, or session timed out" if $r->code == 401;
    die "App id is incorrect (or similar error)"          if $r->code == 400;
    die "Unknown error occurred: ", $r->code              if $r->code >= 300;

    my $response_body = $r->content;

    return from_json($response_body);
}

# Put setup and requesting together
# API parameters in, JSON out.
sub _api_call {
    my $self   = shift;
    my %params = @_;

    # Setup request
    my ( $ua, $request ) = $self->_setup_request(%params);

    print "Making request:\n", $request->as_string if $params{debug};

    # Make request, return JSON
    return $self->_handle_request( $ua, $request );
}

# Get user account data
#   API implies that an account might have multiple users?
#   get data on all of them, or get the data of each if one is specified
sub get_user_account {
    my $self    = shift;
    my $user_id = shift;

    my $url_params = {};
    if (defined $user_id) {
        $url_params = { userId => $user_id, }
    }

    my $account_data = $self->_api_call(
        method     => 'GET',
        path       => 'userAccount',
        url_params => $url_params,
    );

    if (!defined($user_id)) {
        $self->{user_id}    = $account_data->{userId};
        $self->{username}  = $account_data->{username};
    }

    return $account_data;
}

# Get data for all thermostats in all locations.
#   If you have multiple locations, you can use this get either
#   get data on all of them, or get the IDs of each
sub get_locations {
    my $self = shift;

    # Must ensure we have retrieved our user_id value
    if (!defined($self->{user_id})) {
        $self->get_user_account;
    }

    my $location_data = $self->_api_call(
        method     => 'GET',
        path       => 'location/installationInfo',
        url_params => { userId => $self->{user_id}, includeTemperatureControlSystems => 'True', },
    );

    return $location_data;
}

# Get data for a specific location
#   Does not include any sensor data
sub get_location {
    my $self        = shift;
    my $location_id = shift;

    my $location_data = $self->_api_call(
        method     => 'GET',
        path       => 'location/' . $location_id . '/installationInfo',
        url_params => { includeTemperatureControlSystems => 'True', },
    );

    return $location_data;
}

# Get data for a specific location
#   Includes temperatures in all zones and zone definitions
sub get_status {
    my $self        = shift;
    my $location_id = shift;

    my $status_data = $self->_api_call(
        method     => 'GET',
        path       => 'location/' . $location_id . '/status',
        url_params => { includeTemperatureControlSystems => 'True', },
    );

    return $status_data;
}

# Get data on gateways at a given location
sub get_gateways {
    my $self        = shift;
    my $location_id = shift;

    my $gateway_data = $self->_api_call(
        method     => 'GET',
        path       => 'gateway',
        url_params => { locationId => $location_id, },
    );

    return $gateway_data;
}

# Get schedule for a specific temperature zone
sub get_schedules {
    my $self    = shift;
    my $zone_id = shift;

    my $zone_data = $self->_api_call(
        method     => 'GET',
        path       => 'temperatureZone/' . $zone_id . '/schedule',
        url_params => { },
    );

    return $zone_data;
}

# Set schedule for a specific temperature zone
# Send a complete JSON schedule as returned by get_schedule()
# Difference from get_schedule seems to be that dayOfWeek is a numeral 0-6 when set by the app
# But it's returned as english "Monday", etc from the server in get_schedule...?
sub set_schedule {
    my $self     = shift;
    my $zone_id  = shift;
    my $schedule = shift;

    my $zone_data = $self->_api_call(
        method     => 'PUT',
        path       => 'temperatureZone/' . $zone_id . '/schedule',
        url_params => { },
        body       => $schedule,
    );

    return $zone_data;
}

# Set override mode for a specific temperature zone
# Send a complete JSON schedule as returned by get_schedule()
# Returns an id... Not sure what this is for
# $system_mode is one of the options from get_location
# $time_until is in RFC format, eg "2015-09-06T06:00:00Z"
sub set_mode {
    my $self    = shift;
    my $zone_id = shift;
    my ($permanent, $system_mode, $time_until) = @_;

    my $body = to_json( { "Permanent"  => $permanent,
                          "SystemMode" => $system_mode,
                          "TimeUntil"  => $time_until } );

    my $zone_data = $self->_api_call(
        method     => 'PUT',
        path       => 'temperatureZone/' . $zone_id . '/mode',
        url_params => { },
        body       => $body,
    );

    return $zone_data;
}

# Set heat setpoint for a specific temperature zone
# Returns an id... Not sure what this is for
# FIXME: Is there a cool setpoint call..?
# Mode = 0 - cancel
# Mode = 1 - permanent?
# Mode = 2 - set until
sub set_heat_setpoint {
    my $self    = shift;
    my $zone_id = shift;
    my ($heat_setpoint_value, $setpoint_mode, $time_until) = @_;

    my $body = to_json( { HeatSetpointValue => $heat_setpoint_value,
                          SetpointMode      => $setpoint_mode,
                          TimeUntil         => $time_until } );

    my $zone_data = $self->_api_call(
        method     => 'PUT',
        path       => 'temperatureZone/' . $zone_id . '/heatSetpoint',
        url_params => { },
        body       => $body,
    );

    return $zone_data;
}


1;
