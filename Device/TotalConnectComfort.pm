#!/usr/bin/perl

use warnings;
use strict;

package Device::TotalConnectComfort;

use Carp;
use Data::Dumper;
use File::Slurp;
use JSON;
use LWP::UserAgent;

use base qw( Exporter );
our @EXPORT_OK = qw( new );

my $DEBUG = 0;
$\ = "\n";

# Make the auth token globally accessible
my $auth_token;

# Requests:
#   .../Session : Login to service, get user detains
#   .../locations?userId=377023&allData=True : Get data on all thermostats. If you have multiple locations, you use this to get data on them all.
#   .../gateways?locationId=364809&allData=False : get data on base station/gateway
#   .../evoTouchSystems?locationId=364809&allData=True : return all data for a location

sub new {
    shift;
    my $username = shift || croak "No username supplied";
    my $password = shift || croak "No password supplied";
    my $is_test  = shift || 0;

    # Hardcoded version of the app
    my $app_id = '91db1612-73fd-4500-91b2-e63b069b185c';

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

        $login_response = do_login(
            Username => $username,
            Password => $password,
            ApplicationId => $app_id,
        );

        if ($DEBUG) {
            open( my $response_fh, '>', $test_file )
            or die "Unable to open file for writing: $!";
            print $response_fh to_json($login_response);
        }
    }

    die "Server response did not contain a session id token"
      unless $login_response->{sessionId};

    my $self;
    $self->{sessionId} = $login_response->{sessionId};
    $self->{username}  = $login_response->{userInfo}->{username};
    $self->{userID}    = $login_response->{userInfo}->{userID};

    # include a valid_until counter - unsure how long sessions are valid for

    # store auth token
    $auth_token = $self->{sessionId};

    bless $self;
}

# Perform login to API
sub do_login {
    my %login_params = @_;

    return _api_call(
        method => 'POST',
        path   => 'Session',
        body   => to_json( \%login_params ),
    );
}

# Creates a LWP::UserAgent request with the correct headers
sub _setup_request {
    my %params = @_;
    # method, path, url_params (url parameters), body (body content)

    # Setup location
    my $host      = 'https://rs.alarmnet.com';
    my $base_path = '/TotalConnectComfort/WebAPI/api/';
    my $url       = URI->new( $host . $base_path . $params{path} );
    $url->query_form($params{url_params}) if $params{url_params};

    # Add useragent string
    my $ua = LWP::UserAgent->new;
    $ua->agent('User-Agent: RestSharp 104.1.0.0');

    my $request = HTTP::Request->new( $params{method} => $url );
    $request->header( 'Content-Type' => 'application/json' );
    $request->header( 'sessionId' => $auth_token ) if $auth_token;
    $request->content( $params{body} ) if $params{body};

    return ( $ua, $request );
}

# Actually make the request, handle errors and return JSON-decoded body
sub _handle_request {
    my $ua = shift;
    my $request = shift;
    my $debug = shift;

    my $r = $ua->request($request);

    die "Invalid username/password, or session timed out" if $r->code == '401';
    die "App id is incorrect (or similar error)" if $r->code == '400';
    die "Unknown error occurred: ", $r->code if $r->code != '200';

    my $response_body = $r->content;

    return from_json($response_body);
}

# Put setup and requesting together
# API parameters in, JSON out.
sub _api_call {
    my %params = @_;

    # Setup request
    my ($ua, $request) = _setup_request(%params);

    print "Making request:\n", $request->as_string if $params{debug};

    # Make request, return JSON
    return _handle_request($ua, $request);
}

# Get data for all thermostats in all locations.
#   If you have multiple locations, you can use this get either
#   get data on all of them, or get the IDs of each
sub get_locations {
    my $self = shift;

    my $location_data = _api_call(
        method => 'GET',
        path   => 'locations',
        url_params => { userId => $self->{userID}, allData => 'True', }, # consistent casing, say what?
    );

    return $location_data;
}

# Get data for a specific location
sub get_location {
    my $self = shift;
    my $location_id = shift;

    my $location_data = _api_call(
        method => 'GET',
        path   => 'evoTouchSystems',
        url_params => { locationId => $location_id, allData => 'True', },
    );

    return $location_data;
}

# Get data on gateways at a given location
sub get_gateways {
    my $self = shift;
    my $location_id = shift;

    my $gateway_data = _api_call(
        method => 'GET',
        path   => 'gateways',
        url_params => { locationId => $location_id, allData => 'False', },
    );

    return $gateway_data;
}


1;
