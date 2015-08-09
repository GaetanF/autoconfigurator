#!/usr/bin/env perl
package Monitoring::Config;

require Monitoring::Env;

use strict;
use Config::Tiny;

BEGIN {
    use Exporter (); 
    @Monitoring::Config::ISA = qw(Exporter);
    @Monitoring::Config::EXPORT = qw(getConfig);
    @Monitoring::Config::EXPORT_OK = qw();
}

=head1 NAME

Monitoring::Config - Perl Configrary for manage monitoring of domu

=head1 SYNOPSIS

    use Monitoring::Config
    my $fqdn = Monitoring::Config->getFqdn($disk);

=head1 DESCRIPTION

This lib contains some variables use in management of monitoring

=head1 AUTHOR

Gaëtan FEREZ (gferez@citic74.fr)

=head1 COPYRIGHT

Copyright 2011 Gaëtan FEREZ CITIC74.  All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1).

=cut

sub getConfig {
   $Monitoring::Lib::config = new Config::Tiny;
   $Monitoring::Lib::config = Config::Tiny->read( $Monitoring::Env::configpath . "/" . $Monitoring::Env::configfile );
   Monitoring::Centreon::getConnection();
}

1;
