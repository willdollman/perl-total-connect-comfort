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

my $DEBUG = 1;
$\ = "\n";

sub new {
    my $username = shift || croak "No username supplied";
    my $password = shift || croak "No password supplied";
    my $app_id   = shift || croak "No application id supplied";
    my $is_test  = shift || 0;

    my $test_file = 't/login_response';
    my $response_body;

    if ($is_test) {
        print "Using cached response" if $DEBUG;

        open(my $test_file_fh, '<', $test_file)
            or die "Unable to open test input file";
        $response_body = read_file($test_file_fh);
    }
    else {
        my $r = do_login($username, $password, $app_id);
        # save to file so we can reuse it
        open(my $response_fh, '>', $test_file)
            or die "Unable to save to file: $!";
        $response_body = $r->content;
    }

    my $login_response = from_json($response_body);
    die "Server response did not contain a session id token"
        unless $login_response->{sessionId};

    my $self;
    $self->{sessionId} = $login_response->{sessionId};
    $self->{username}  = $login_response->{userInfo}->{username};
    # include a valid_until counter - unsure how long sessions are valid for
    bless $self;
}

sub do_login {
    my $username = shift || die "No username supplied";
    my $password = shift || croak "No password supplied";
    my $app_id   = shift || croak "No application id supplied";

    print "Performing login on server" if $DEBUG;

    my $host = 'https://rs.alarmnet.com';
    my $path = '/TotalConnectComfort/WebAPI/api/Session';
    my $url = URI->new($host . $path);

    my $login_params = {
        'Username' => $username,
        'Password' => $password,
        'ApplicationId' => $app_id,
    };
    my $login_json = to_json($login_params);

    my $ua = LWP::UserAgent->new;
    $ua->agent('User-Agent: RestSharp 104.1.0.0');

    my $request = HTTP::Request->new(POST => $url);
    $request->header('Content-Type' => 'application/json');
    $request->content($login_json);

    my $r = $ua->request($request);

    die "Invalid username/password" if $r->code == '401';
    die "App id is incorrect"       if $r->code == '400';
    die "Unknown error occurred"    if $r->code != '200';

    return $r;
}

1;
