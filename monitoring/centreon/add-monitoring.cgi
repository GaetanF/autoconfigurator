#!/usr/bin/env perl
# Rev : 0.1
# Author : Gaëtan FEREZ
# Date : 12/08/2011

use strict;
use CGI;
use JSON;
use Data::Dumper;
use Monitoring::Lib;
use Monitoring::Config;

my $q = new CGI;
getConfig();

if( $Monitoring::Lib::config->{_}->{enabled} == 0 )
{
   print $q->header(
      '-type' => 'text/html',
      '-status' => '403 Forbidden'
   );
}elsif ( $Monitoring::Lib::config->{security}->{htauth} ){
   my ($user, $password) = parseRemoteUser($ENV{REMOTE_USER});
   if( verifAuth($user, $password) )
   {
      print $q->header('application/json');
   }else{
   	print $q->header(
           '-type' => 'application/json',
           '-status' => '401 Authentication required',
           '-auth-type' => 'Basic realm="Monitoring Access"',
           -WWW_Authenticate => 'Basic realm="Monitoring Access"'
        );
        exit;
   }
}else{
   print $q->header('application/json');
}

if( ! defined($q->param("name")) ){
   exit;
}
my $hostInfo = getHostInfo($q->param("name"));
processHost($hostInfo);
