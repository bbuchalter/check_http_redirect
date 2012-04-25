#!/usr/bin/env perl

#------------------------------------------------------------------------------
# Nagios check_http_redirect
#       retrieve an http/s url and checks its header for a given redirects
#       if the redirect exists and equal to the redirect you entered then exits with OK, otherwise exits with CRITICAL (if not equal) or CRITICAL ( if doesn't exist)
#
# Copyright 2009, Eugene L Kovalenja, http://www.purple.org.ua/
# Copyright 2012, Version 2 revised by Brian Buchalter, http://www.endpoint.com
# Licensed under GPLv2
#     This program is free software; you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation; either version 2 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with Opsview; if not, write to the Free Software
#     Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# -----------------------------------------------------------------------------

use warnings;
use strict;
use Getopt::Std;
use LWP::UserAgent;

my $plugin_name = 'Nagios check_http_redirect';
my $VERSION             = '3.00';

# getopt module config
$Getopt::Std::STANDARD_HELP_VERSION = 1;

# nagios exit codes
use constant EXIT_OK            => 0;
use constant EXIT_WARNING       => 1;
use constant EXIT_CRITICAL      => 2;
use constant EXIT_UNKNOWN       => 3;

# parse cmd opts
my %opts;
getopts('vU:R:t:c:S:', \%opts);
$opts{t} = 5 unless (defined $opts{t});
$opts{c} = 10 unless (defined $opts{c});
if (not (defined $opts{U} ) or not (defined $opts{R} ) or not (defined $opts{S})) {
        print "ERROR: INVALID USAGE\n";
        HELP_MESSAGE();
        exit EXIT_CRITICAL;
}

#ASSUME A CRITICAL EXIT
my $status = EXIT_CRITICAL;

my $ua = LWP::UserAgent->new;

$ua->agent('Redirect Bot ' . $VERSION);
$ua->protocols_allowed( [ 'http', 'https'] );
$ua->parse_head(0);
$ua->timeout($opts{t});
$ua->max_redirect(int($opts{c}));
$ua->ssl_opts(SSL_ca_path => '/etc/ssl/certs');

my $response = $ua->get($opts{U});
my $count_redirects = $response->redirects;

if ( $response->is_redirect )
{
  print "There were more redirects to follow than currently permitted ($opts{c}).";
  exit $status;
}
else
{
        if ($response->base =~ $opts{U}) {
                print "ERROR: Expected to be redirected, but response from original URL $opts{U}\n";
        }
        elsif ($response->base =~ $opts{R})
        {
                print "It took $count_redirects redirect(s) to reach ", $response->base, "\n";

                $status = EXIT_OK; #we've reached the correct destination


                foreach my $my_redirect ($response->redirects){
                        if ($my_redirect->code != $opts{S}) {
                                $status = EXIT_CRITICAL;
                                print "ERROR: Redirects did not return correct HTTP status\n";
                        }
                }


        }
        else
        {
                print "ERROR: Expected to be redirected to $opts{R} but was redirected to ", $response->base, "\n";
        }
}

print "[redirect chain: $opts{U} > ";
foreach my $my_redirect ($response->redirects){
print $my_redirect->header('Location'), " (", $my_redirect->code, ") > ";
}
print "done]\n";


exit $status;


sub HELP_MESSAGE 
{
        print <<EOHELP
        Retrieve an http/s url and checks its header for a given redirects.
        If the redirect exists and equal to the redirect you entered then exits with OK, otherwise exits with CRITICAL (if not equal) or CRITICAL ( if doesn't exist)

        --help      shows this message
        --version   shows version information

        -U          URL to retrieve (http or https)
        -R          URL that must be equal to Header Location Redirect URL
        -S          The HTTP status code that is expected
        -t          Timeout in seconds to wait for the URL to load. If the page fails to load, 
                    $plugin_name will exit with UNKNOWN state (default 60)
        -c          Depth of redirects to follow (default 10)

EOHELP
;
}

sub VERSION_MESSAGE 
{
        print <<EOVM
$plugin_name v. $VERSION
Copyright 2009, Eugene L Kovalenja, http://www.purple.org.ua/ - Licensed under GPLv2
Revisions Copyright 2012, Brian Buchalter
EOVM
;
}
