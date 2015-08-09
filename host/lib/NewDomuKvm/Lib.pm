#!/usr/bin/env perl
package NewDomuKvm::Lib;

require NewDomuKvm::Env;
use MIME::Base64;

=head1 NAME

NewDomuKvm::Lib - Perl Library for init_domu

=head1 SYNOPSIS

    use NewDomuKvm::Lib
    my $fqdn = NewDomuKvm::Lib->getFqdn($disk);
    my $domu = NewDomuKvm::Lib->getDomUInfos($fqdn);

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
        my $json_text = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($content);
        return $json_text;
    }elsif ($response->is_error){
        return ();
    } 
}

sub getFqdn {
    my ($disk) = @_;
    my $url = $NewDomuKvm::Env::urlInfoFqdn;
    $url = "$url?key=\"$disk\"";
    my ($infos) = getJson($url);
    if( scalar(@{$infos->{rows}}) == 0 ){
        die "Unable find $disk in couchdb";
    }
    return @{$infos->{rows}}[0]->{value};
}

sub getDomUInfos {
    my ($fqdn) = @_;
    my $url = $NewDomuKvm::Env::urlInfoDomu;
    $url = "$url/$fqdn";
    my $infos = getJson($url);
    return $infos;
}

sub getSourcesList {
    my ($repo) = @_;
    my $url = $NewDomuKvm::Env::urlInfoDomu;
    $url = "$url/$repo";
    my ($infos) = getJson($url);
    return $infos->{template};
}

sub writeToFile {
    my ($content, $file) = @_;
    open(MYOUTFILE, ">$file");
    print MYOUTFILE $content."\n";
    close(MYOUTFILE);
}

sub searchSourcesList {
    my ($os) = @_;
    return "template:repository:" . $os->{editor} . ":" . $os->{version};
}

sub processSourcesList {
    my ($os) = @_;
    print "\nSet sources.list :";
    my $sourceslist = getSourcesList($os->{repository});
    if( !defined($sourceslist) ){
        my $repository = NewDomuKvm::Lib::searchSourcesList($os);
        $sourceslist = getSourcesList($repository);
    }
    NewDomuKvm::Lib::writeToFile($sourceslist, $NewDomuKvm::Env::sourcespath);
    print " done";
}

sub processNetwork {
    my @networks = @_;
    @networks = sort { $a->{iface} cmp $b->{iface} } @{@networks[0]};
    my $loop = {'iface' => 'lo','ip' => 'loopback'};
    my $cnt = "";
    unshift(@networks, $loop);
    my $nbrGateway=0;
    print "\nSet network configuration :";
    foreach $net (@networks){
        $cnt .= "auto " . $net->{iface} . "\n";
        $cnt .= "iface ". $net->{iface} ." inet ";
        if( $net->{ip} == 'loopback' || $net->{ip} == 'dhcp' ){
           $cnt .= $net->{ip} . "\n"; 
        } else {
            $cnt .= "static\n";
            $cnt .= "\taddress " . $net->{ip} . "\n";
            $cnt .= "\tnetmask " . $net->{netmask} . "\n";
            if( exists $net->{gateway} and $net->{gateway} != "0.0.0.0"){
                if ( $nbrGateway == 0 ){
                    $cnt .= "\tup echo 'Adding last resort default route with iproute2 in table 253 (default)'\n";
                    $cnt .= "\tup /sbin/ip route add table default default via " . $net->{gateway} . "\n";
                    $cnt .= "\tdown echo 'Removing last resort default route with iproute2 in table 253 (default)'\n";
                    $cnt .= "\tdown /sbin/ip route del table default default via " . $net->{gateway} . "\n";
                    $nbrGateway++;
                }else{
                    print STDERR "Gateway : " . $net->{gateway} . " not defined\nAnother gateway is already define";
                }
            }
            if( scalar(@{$net->{route}}) > 0 ){
                foreach $route (@{$net->{route}}){
                    $cnt .= "\tup echo 'Adding route to " . $route->{route} ."/". $route->{netmask}." via ".$route->{gateway}."'\n";
                    $cnt .= "\tup route add -net " . $route->{route} . " netmask " . $route->{netmask} . " gw " . $route->{gateway} . "\n";
                    $cnt .= "\tdown echo 'Removing route to " . $route->{route} ."/". $route->{netmask}." via ".$route->{gateway}."'\n";
                    $cnt .= "\tdown route del -net " . $route->{route} . " netmask " . $route->{netmask} . " gw " . $route->{gateway} . "\n";
                }
            }
        }
        $cnt .= "\n";
    }
    writeToFile($cnt, $NewDomuKvm::Env::networkpath);
    print " done";
}

sub processResolv {
    my ($dns) = @_;
    my $cnt = "";
    print "\nSet resolver configuration :";
    foreach $ns (@{$dns}){
        $cnt .= "nameserver $ns \n";
    }
    writeToFile($cnt, $NewDomuKvm::Env::resolvpath);
    print " done";
}

sub processHostname {
    my ($hostname) = @_;
    print "\nSet hostname \"$hostname\" :";
    writeToFile($hostname, $NewDomuKvm::Env::hostnamepath);
    print " done";
}

sub processHosts {
    my ($domu) = @_;
    print "\nSet hosts : ";
    my @nets = $domu->{NETWORK};
    @nets = sort { $a->{iface} cmp $b->{iface} } @{@nets[0]};
    my $ip = @nets[0]->{ip};
    my $cnt="";
    $cnt .= "127.0.0.1\tlocalhost\n";
    $cnt .= $ip . "\t" . $domu->{FQDN} . "\t" . $domu->{NAME} . "\n";
    $cnt .= "\n# The following lines are desirable for IPv6 capable hosts\n::1\tlocalhost ip6-localhost ip6-loopback";
    $cnt .= "\nfe00::0 ip6-localnet";
    $cnt .= "\nff00::0 ip6-mcastprefix";
    $cnt .= "\nff02::1 ip6-allnodes";
    $cnt .= "\nff02::2 ip6-allrouters";
    $cnt .= "\nff02::3 ip6-allhosts";
    writeToFile($cnt, $NewDomuKvm::Env::hostspath);
    print " done";
}

sub processMonitoring {
    my ($fqdn) = @_;
    print "\nSet monitoring for $fqdn : ";
    my $URL = $NewDomuKvm::Env::monitoringurl;
    my $agent = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1, timeout => 30);
    my $header = HTTP::Request->new(GET => $URL."?name=$fqdn");
    my $token = encode_base64("$NewDomuKvm::Env::monitoringuser:$NewDomuKvm::Env::monitoringpass");
    $header->header( Authorization => "Basic $token" );
    my $request = HTTP::Request->new('GET', $URL."?name=$fqdn", $header);
    my $response = $agent->request($request);
    my $json = new JSON;
    my $content = "";
    if ($response->is_success){
       $content = $response->decoded_content;
    }else{
       $content = "{'status': 'error', 'error':'error json'}";
    }
    my $json_text = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($content);
    if ($json_text->{status} == "error" )
    {
        print "failed. Error : ".$json_text->{error};
    }else{
        print $json_text->{status};
    }
}

sub processQuagga {
    my ($hostname, $routing) = @_;
    print "\nSet quagga configuration : ";
    if ( $routing->{protocol} eq "fixed" ){
        print " no quagga configuration. Mode fixed";
    }elsif ($routing->{protocol} eq "quagga" ){
        my $daemons = "zebra=yes\nbgpd=no\nospfd=no\nospf6d=no\nripd=yes\nripngd=no\nisisd=no";
        my $ripd = "!
hostname $hostname.ripd
password cisco
enable password linuxcisco
!
interface lo
!
interface eth0
!
router rip
network eth0
timers basic 30 45 180
!
access-list admin permit 127.0.0.1/32
!
line vty
 access-class admin
!";
    my $zebra = "!
hostname $hostname.zebra
password cisco
enable password linuxcisco
!
interface lo
!
interface eth0
!
!
access-list admin permit 127.0.0.1/32
!
line vty
 access-class admin";
        if( ! -d $NewDomuKvm::Env::quaggapath ){
            mkdir($NewDomuKvm::Env::quaggapath);
        }
        writeToFile($daemons, $NewDomuKvm::Env::quaggapath."daemons");
        writeToFile($ripd, $NewDomuKvm::Env::quaggapath."ripd.conf");
        writeToFile($zebra, $NewDomuKvm::Env::quaggapath."zebra.conf");
        print " done";
    }
}

1;
