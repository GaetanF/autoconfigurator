#!/usr/bin/env perl
package Monitoring::Centreon;

require Monitoring::Env;

use strict;
use DateTime;
use Data::Dumper;
use DBI;
BEGIN {
    use Exporter (); 
    @Monitoring::Centreon::ISA = qw(Exporter);
    @Monitoring::Cenreon::EXPORT = qw(getHostGroups addHost addHostgroupToHost reconfigureNagios);
    @Monitoring::Centreon::EXPORT_OK = qw();
}

=head1 NAME

Monitoring::Centreon - Perl Configrary for manage centreon 

=head1 SYNOPSIS

    use Monitoring::Centreon

=head1 DESCRIPTION

This lib contains some variables use in management of Centreon

=head1 AUTHOR

Gaëtan FEREZ (gferez@citic74.fr)

=head1 COPYRIGHT

Copyright 2011 Gaëtan FEREZ CITIC74.  All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1).

=cut

use vars qw ($db);

sub getConnection {
   my $config = $Monitoring::Lib::config->{database};
   my $uri = "DBI:".$config->{type}.":dbname=".$config->{base}.";host=".$config->{host};
   $db = DBI->connect(
      $uri,
      $config->{user},
      $config->{pass}
   );
}

sub getServer {
  my $query = $db->prepare("SELECT id FROM nagios_server WHERE name='".$Monitoring::Lib::config->{centreon}->{defaultNagios}."'");
  $query->execute();
  my ($id) = $query->fetchrow();
  return $id;
}

sub getIdForHostTemplate {
  my $query = $db->prepare("SELECT host_id FROM host WHERE host_name='".$Monitoring::Lib::config->{centreon}->{defaultTemplateHost}."'");
  $query->execute();
  my ($id) = $query->fetchrow();
  return $id;
}

sub getHostGroups {
   my $query = $db->prepare( "SELECT hg_id, hg_name from hostgroup WHERE hg_activate = '1' ");
   $query->execute();   
   my @hostgroups = ();
   while(my @record = $query->fetchrow())
   {
      $hostgroups[$record[0]] = $record[1];
   }
   return @hostgroups;
}

sub getIpForHost {
   my ($host) = @_;
   my $ip = "";
   foreach my $net (@{$host->{NETWORK}})
   {
      if( exists $net->{gateway} and $net->{gateway} != "0.0.0.0")
      {
         $ip = $net->{ip};
      }elsif( $net->{ip} =~ /^195\.202/ ){
         $ip = $net->{ip};
      }
   }
   return $ip;
}

sub addHost {
   my ($host) = @_;
   my $dt = DateTime->now();
   my $commentDate = $dt->datetime();
   my $sqlQuery = "INSERT INTO host (`host_id`, `host_template_model_htm_id`,`host_name`,`host_alias`,`host_address`, `host_active_checks_enabled`, `host_passive_checks_enabled`, `host_checks_enabled`, `host_obsess_over_host`, `host_check_freshness`, `host_event_handler_enabled`, `host_flap_detection_enabled`, `host_process_perf_data`, `host_retain_status_information`, `host_retain_nonstatus_information`, `host_notifications_enabled`, `host_register`, `host_activate`, `host_comment`) VALUES ('',?, ?, ?, ?,'2','2','2','2','2','2','2','2','2','2','2','1','1', ?);";
   my $query = $db->prepare($sqlQuery);
   $query->execute(getIdForHostTemplate(), $host->{NAME}, $host->{NAME}, getIpForHost($host), $commentDate);
   my $idHost = $db->last_insert_id(undef, undef, undef, undef);
   $sqlQuery = "INSERT INTO extended_host_information (`host_host_id`) VALUES ('".$idHost."')";
   $query = $db->prepare($sqlQuery);
   $query->execute();
   $sqlQuery = "INSERT INTO host_template_relation (`host_host_id`, `host_tpl_id`) VALUES ('".$idHost."', '244')";
   $query = $db->prepare($sqlQuery);
   $query->execute();
   return $idHost;
}

sub addHostgroupToHost {
   my ($idHost, @aHostGroup) = @_;
   my $sqlQuery = "INSERT INTO hostgroup_relation (`hgr_id`, `hostgroup_hg_id`, `host_host_id`) VALUES ";
   foreach my $idHG (@aHostGroup)
   {
      $sqlQuery .= "('','".$idHG."','".$idHost."'),"; 
   }
   $sqlQuery = substr $sqlQuery, 0, -1;
   my $query = $db->prepare($sqlQuery);
   $query->execute();
}

sub addHostToServer {
   my ($idHost) = @_;
   my $query = $db->prepare("INSERT INTO ns_host_relation (`nagios_server_id`, `host_host_id`) VALUES ('".getServer()."', '".$idHost."')");
   $query->execute();
}

sub addHostToParent {
   my ($idHost, $host) = @_;
   my $sqlQuery = "SELECT host_id FROM host WHERE host_name LIKE '%".$host->{MAIN}."%'";
   my $query = $db->prepare($sqlQuery);
   $db->execute();
   
   my $sqlQuery = "INSERT INTO (``) VALUES ()"; 
}

sub reconfigureNagios {
   my $user = $Monitoring::Lib::config->{centreon}->{user};
   my $pass = $Monitoring::Lib::config->{centreon}->{pass};
   system("/usr/local/centreon/www/modules/centreon-clapi/core/centreon -u $user -p $pass -a POLLERGENERATE -v ".getServer(). " 2>&1 1>/dev/null");
   if( $? != 0 )
   {
      print '{"status": "error", "error": "pollergenerate"}';
      exit;
   }
   system("/usr/local/centreon/www/modules/centreon-clapi/core/centreon -u $user -p $pass -a POLLERTEST -v ".getServer(). " 2>&1 1>/dev/null");
   if( $? != 0 )
   {
      print '{"status": "error", "error": "pollertest"}';
      exit;
   }
   system("/usr/local/centreon/www/modules/centreon-clapi/core/centreon -u $user -p $pass -a POLLERRELOAD -v ".getServer() . " 2>&1 1>/dev/null");
   if( $? != 0 )
   {
      print '{"status": "error", "error": "pollerreload"}';
      exit;
   }
   print '{"status": "ok"}';
}

1;
