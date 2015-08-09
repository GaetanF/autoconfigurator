#!/usr/bin/env perl
package NewDomuKvm::Env;

=head1 NAME

NewDomuKvm::Env - Perl Constants for init_domu

=head1 SYNOPSIS

    $user - couchdb-cv4 user
    $pass - couchdb-cv4 password
    $couchdb - base url to access couchdb
    $urlInfoFqdn - url to access view to obtain FQDN from a disk name
    $urlInfoDomu - url to access domU document 

=head1 DESCRIPTION

This lib contains some variables use in init_domu.pl

=head1 AUTHOR

Gaëtan FEREZ (gferez@citic74.fr)

=head1 COPYRIGHT

Copyright 2011 Gaëtan FEREZ CITIC74.  All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1).

=cut
my $user = 'usercv4';
my $pass = 'usercv4';
my $couchdb = "http://$user:$pass\@couchdb-cv4.citic74.net:5984";
$urlInfoFqdn = "$couchdb/cluster-v4/_design/disks/_view/vm";
$urlInfoDomu = "$couchdb/cluster-v4";

$monitoringurl = "http://centreon.citic74.net/cgi-bin/citic-add-monitoring.cgi";
$monitoringuser = "monit";
$monitoringpass = "monit";

# Variables Path
$sourcespath = "/etc/apt/sources.list";
$networkpath = "/etc/network/interfaces";
$resolvpath = "/etc/resolv.conf";
$hostnamepath = "/etc/hostname";
$hostspath = "/etc/hosts";
$quaggapath = "/etc/quagga/";

# Variables Path for test
#$sourcespath = "test/sources.list";
#$networkpath = "test/interfaces";
#$resolvpath = "test/resolv.conf";
#$hostnamepath = "test/hostname";
#$hostspath = "test/hosts";
#$quaggapath = "test/quagga/";

1;
