#!/usr/bin/perl
# Rev : 0.1
# Author : Gaëtan FEREZ
# Date : 05/05/2011

use strict 'vars';
use LWP::UserAgent;
use HTTP::Request;
use JSON -support_by_pp;
require NewDomuKvm::Lib;
require NewDomuKvm::Env;

if( ! defined($ARGV[0]) ){
    die("Args : disk-name");
}

my $disk=$ARGV[0];

my $fqdn = NewDomuKvm::Lib::getFqdn($disk);
my $domu = NewDomuKvm::Lib::getDomUInfos($fqdn);

print "FQDN : $fqdn\n";
print "HOSTNAME : " . $domu->{NAME};
#print "DNS : " . Dumper($domu->{DNS});
#print "NETWORK : " . Dumper($domu->{NETWORK});
#print "ROUTING : " . Dumper($domu->{ROUTING});
#print "REPOSITORY : " . Dumper($domu->{OS}->{repository});

NewDomuKvm::Lib::processSourcesList($domu->{OS});
NewDomuKvm::Lib::processNetwork($domu->{NETWORK});
NewDomuKvm::Lib::processResolv($domu->{DNS});
NewDomuKvm::Lib::processHostname($domu->{NAME});
NewDomuKvm::Lib::processHosts($domu);
NewDomuKvm::Lib::processQuagga($domu->{NAME}, $domu->{ROUTING});
NewDomuKvm::Lib::processMonitoring($fqdn);

print "\n";
