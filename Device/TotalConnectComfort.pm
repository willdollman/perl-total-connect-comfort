#!/usr/bin/perl

use warnings;
use strict;

package Device::TotalConnectComfort;

use Carp;
use Data::Dumper;
use HTTP::Request;
use JSON qw( to_json );
use LWP::UserAgent;

use base qw( Exporter );
our @EXPORT_OK = qw( new );

sub new {
    my $self = shift;
    my $username = shift || croak "No username supplied";
    my $password = shift || croak "No password supplied";
    my $app_id   = shift || croak "No application id supplied";

    print "Doing some magic stuff. Stand back.\n";
    print "Username: $username\nPassword: $password\n";

    my $host = 'https://rs.alarmnet.com';
    #my $host = 'http://dollman.org';
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
    print "Request is ", Dumper $request;

    my $r = $ua->request($request);
    print "Response is ", $r->content;
}

1;
