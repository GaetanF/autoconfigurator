#!/usr/bin/env perl
package Monitoring::Lib;

use strict;
use Data::Dumper;
use MIME::Base64;
use LWP::UserAgent;
use HTTP::Request;
require Monitoring::Env;
require Monitoring::Config;
require Monitoring::Centreon;

BEGIN {
    use Exporter ();
    @Monitoring::Lib::ISA = qw(Exporter);
    @Monitoring::Lib::EXPORT = qw(parseRemoteUser verifAuth getHostInfo processHost);
    @Monitoring::Lib::EXPORT_OK = qw();
}

=head1 NAME

Monitoring::Lib - Perl Library for manage monitoring of domu

=head1 SYNOPSIS

    use Monitoring::Lib
    my $fqdn = NewDomuKvm::Lib->getFqdn($disk);

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

use vars qw ($config $centreon);

sub getJson {
    my ($URL) = @_ ;
    my $agent = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1, timeout => 30);
    my $header = HTTP::Request->new(GET => $URL);
    my $request = HTTP::Request->new('GET', $URL, $header);
    my $response = $agent->request($request);
    # Check the outcome of the response
    if ($response->is_success){
        my $content = $response->decoded_content;
        my $json = new JSON;

        # these are some nice json options to relax restrictions a bit:
        my $json_text = $json->allow_nonref->utf8->relaxed->decode($content);
        if( defined($json_text->{"id_trans"}) )
        {
		delete($json_text->{"id_trans"});
        }
        return $json_text;
    }elsif ($response->is_error){
        return ();
    }
}

sub getUrl {
   my ($baseUrl) = @_;
   my $couchdbcv4 = $config->{couchdbcv4};
   return $couchdbcv4->{proto}."://".$couchdbcv4->{user}.":".$couchdbcv4->{pass}."@".$couchdbcv4->{host}.":".$couchdbcv4->{port}."/".$baseUrl;
}

sub getHostInfo {
    my ($host) = @_;
    my $url = getUrl($Monitoring::Env::urlInfoDomu);
    $url = "$url/$host";
    my $infos = getJson($url);
    return $infos;
}

sub parseRemoteUser {
   my $remoteUser = shift;
   $remoteUser =~ m/Basic\s+(.*)$/;
   my $hash = decode_base64($1);   
   return split(':', $hash);
}

sub verifAuth {
   my ($user, $pass) = @_;
   if( $config->{security}->{user} eq $user and $config->{security}->{pass} eq $pass )
   {
      return 1;
   }else{
      return 0;
   }
}

sub processHost {
   my ($host) = @_;
   my @aMyHostGroup =  parseTags($host->{TAGS}[0], Monitoring::Centreon::getHostGroups());
   my $id = Monitoring::Centreon::addHost($host);
   Monitoring::Centreon::addHostgroupToHost($id, @aMyHostGroup);
   Monitoring::Centreon::addHostToServer($id);
   Monitoring::Centreon::reconfigureNagios();
}

sub getIndexArray {
   my ($search, @array) = @_;
   my( $index )= grep { $array[$_] =~ /$search/i } 0..$#array;
   return $index;
}

sub parseTags {
   my ($tags, @hostgroups) = @_;
   my @arrayMyIndex = ();
   while (my ($key,$value) = each(%{$config->{parsing}}))
   {
      my @aSearchFor = split( ',', $value );
      foreach my $searchFor (@aSearchFor)
      {
         if ( $tags =~ /$searchFor/i )
         {
            my $indexForSearch = getIndexArray($key, @hostgroups);
            if (!(grep $_ == $indexForSearch, @arrayMyIndex)) 
            {
               $arrayMyIndex[@arrayMyIndex] = $indexForSearch;
            }
         }
      }
   }
   return @arrayMyIndex;
}

1;
