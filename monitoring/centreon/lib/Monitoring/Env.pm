#!/usr/bin/env perl
package Monitoring::Env;

=head1 NAME

Monitoring::Env - Perl Constants for manage monitoring

=head1 SYNOPSIS

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
$urlInfoDomu = "cluster-v4";

# Variables Path
$configpath = "/etc/monitoring";
$configfile = "monitoring.ini";

1;
