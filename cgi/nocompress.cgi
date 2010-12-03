#!/bin/env perl

# ------------------------------------
#
# Project:	OAC 4.0
#
# Name:		nocompress.cgi
#
# Function:	Take a URL as a query string, and send it to the web site
#		without the "Accept-Encoding:  gzip,deflate" header, so
#		that Resin doesn't automatically compress it.
#
# Command line parameters:  none (CGI script)
#
# Author:	Michael A. Russell
#
# Revision History:
#		2009/3/16 - MAR - Initial writing
#		2009/3/20 - MAR - mod_security appeared to be complaining
#			about a missing "Accept:" header.  Added one, and
#			it seems happy now.
#
# ------------------------------------

use strict;
use warnings;

# Pull in code we'll need.
use LWP::UserAgent;
use HTTP::Request;

# Declare our variables.
use vars qw(
	$headers
	$request
	$response
	$url
	$user_agent
	);

# Set up a new user agent.
$user_agent = LWP::UserAgent->new( );
$user_agent->agent("nocompress.cgi");

# Create the URL we'll want to use.
$url = "http://" . $ENV{"HTTP_HOST"} . $ENV{"QUERY_STRING"};

# Create a new HTTP request with that URL.
$request = HTTP::Request->new(GET => $url);
$request->header("Accept" => "text/html");

# Process the URL.
$response = $user_agent->request($request);

# Display most of the headers.
$headers = $$response{"_headers"};
foreach (keys %$headers) {
	next if (lc("$_") eq "cache-control");
	next if (lc("$_") eq "client-response-num");
	next if (lc("$_") eq "connection");

	print "$_: $$headers{$_}\r\n";
	}

# Signal the end of the headers.
print "\r\n";

# Send the content.
print $response->content( );
