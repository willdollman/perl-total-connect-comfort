#!/usr/bin/perl

use warnings;
use strict;

use Device::TotalConnectComfort qw( new );

my $username = '';
my $password = '';
my $app_id   = '';

my $cn = Device::TotalConnectComfort->new($username, $password, $app_id, 'test_enabled');
