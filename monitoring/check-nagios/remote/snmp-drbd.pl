#!/usr/bin/perl
use NetSNMP::OID (':all');
use NetSNMP::agent (':all');
use NetSNMP::ASN (':all');

my $rootOID = ".1.3.6.1.4.1.1000.1";
my $regoid = new NetSNMP::OID($rootOID); 
my $lastDisk;

open(DRBDADM, "drbdadm status |");
my @drbdadmdata = <DRBDADM>;	
close(DRBDADM);

sub typeOf {
	my $val = shift;

	use Carp qw(confess);
	if ( ! defined $val ) {
		return 'null';
	} elsif ( ! ref($val) ) {
		if ( $val =~ /^-?\d+$/ ) {
			return 'int';
		} elsif ( $val =~ /^-?\d+(\.\d+)?$/ ) {
			return 'float';
		} else {
			return 'string';
		}
	} else {
		my $type = ref($val);
		if ( $type eq 'HASH' || $type eq 'ARRAY' ) {
			return 'array';
		} elsif ( $type eq 'CODE' || $type eq 'REF' || $type eq 'GLOB' || $type eq 'LVALUE' ) {
			return $type;
		} else {
			# Object...
			return 'obj';
		}
	}
}

sub getResourceName {
	my $id = shift;
	if( ! defined $id ) {
		return 'null';
	}
	#print STDERR "Search resource name for id $id\n";
	foreach $line (@drbdadmdata) {
		chomp $line;
		#print STDERR $line."\n";
		if ( $line =~ m/minor="$id" name="([a-z0-9\-]*)"/ ) {
			#print STDERR "Resource name : $1\n";
			return "$1";
		}
	}
}

sub myhandler {
	my ($handler, $registration_info, $request_info, $requests) = @_;
	my $drbd_proc = '/proc/drbd';
	my @drbddata;

	open(DRBD,$drbd_proc); 
	@drbddata = <DRBD>; 
	close(DRBD); 

	my $curoid = "";
	$oid = new NetSNMP::OID($rootOID . ".0");
	#print STDERR "Oid Base : $oid\n";
	my %tabOid;
	$tabOid{$oid} = "DRBD 8.7";
	my $index = 1;
	my $nbrDisk = 0;
	my $oidNbrDisk = $oid . ".1";
	foreach $line (@drbddata) { 
		chomp $line;
		#print STDERR "Line : $line\n";
		if( $line =~ m/^\s*([0-9]{1,3}): (.*)/) {
			$id = $1;
			my @values = split(/ /, $2);
			$curoid = new NetSNMP::OID($rootOID . "." . $id);
			$oidBase = $curoid + ".0";
			$tabOid{$oidBase} = getResourceName($id);
			if(length $tabOid{$oidBase} > 0){
				for $value (@values) {
					$theOid = $curoid + ".$index";
					if ( $value =~ m/:([a-zA-Z0-9\/]*)/) {
						my $tmp = $1;
						if ( $tmp =~ m/(.*)\//){
							$tmp = $1;
						}
						$tabOid{$theOid}="$tmp";
					} else {
						$tabOid{$theOid}="$value";
					}
					$index++;
				}
			}else{
				$tabOid{$curoid+".1"} = 'Unconfigured';
				for( my $i = 2; $i <= 18; $i++){
					$tabOid{$curoid+".$i"} = 'null';
			 	}
			}
			$lastDisk = int($id);
			$nbrDisk++;
		} elsif ( $line =~ m/^\s*(ns:[0-9]*)/) {
			for $value (split(/ /, $line)) {
				if( $value =~ m/:([0-9a-zA-Z\/]*)/) {
					$theOid = $curoid + ".$index";
					$tabOid{$theOid}="$1";
					$index++;
				}
			}
			$index = 1;
		}
	}
	my $request;
	#print STDERR "My last disk is $lastDisk";
	for($request = $requests; $request; $request = $request->next()) {
		my $oid = $request->getOID();
		#print STDERR "Request Mode : ".$request_info->getMode()."\n";
		if ($request_info->getMode() == MODE_GET) {
			# ... generally, you would calculate value from oid
			#print STDERR "Get request OID : $oid\n";
			if (exists $tabOid{$oid}) {
				$request->setValue(ASN_OCTET_STR, $tabOid{$oid});
			}
		} elsif ($request_info->getMode() == MODE_GETNEXT) {
			# ... generally, you would calculate value from oid
			#print STDERR "GetNext Request OID : $oid\n";
			if ($oid < new NetSNMP::OID($rootOID . ".0")) {
				#print STDERR "oid < new netsnmp::oid\n";
				$request->setOID(new NetSNMP::OID($rootOID . ".0"));
				$request->setValue(ASN_OCTET_STR, $tabOid{new NetSNMP::OID($rootOID.".0")});
			} elsif ( $oid == new NetSNMP::OID($rootOID . ".0") ) {
				#print STDERR "oid > new netsnmp::oid\n";
				$request->setOID($rootOID . ".1.0");
				$request->setValue(ASN_OCTET_STR, $tabOid{$request->getOID()});
			} elsif($oid =~ /$regoid\.([0-9]+)[\.]?([0-9]+)?$/) {
				#print STDERR "oid =~ regexp\n";
				my $diskId=$1;
				my $valueDisk=$2;
				my $newOid;
				if ( ! defined($valueDisk) or int($valueDisk) == 0) {
					$valueDisk = 0;
				}
				
				if ( $valueDisk < 18 ) {
					$nextDisk = int($valueDisk + 1);
					$newOid = $regoid . ".$diskId." . $nextDisk;
				}else{
					my $addInd = 1;
					my $sum = int($diskId + $addInd);
					$newOid = $regoid.".".$sum;
					while( !defined($tabOid{new NetSNMP::OID($newOid.".0")}) ){
						$addInd++;
						$sum = int($diskId + $addInd);
						if( $sum > $lastDisk ){
							last;
						}
						$newOid = $regoid.".".$sum;
					}
					$valueDisk = 0;
					$newOid = $newOid . ".0";
					#print STDERR "NewOID = $newOid, Oid : $oid, DiskId=$diskId, IndexValueDisk=$valueDisk\n";
				}
				if( defined($tabOid{$newOid}) ) {
					$request->setOID(new NetSNMP::OID($newOid));
					$request->setValue(ASN_OCTET_STR, $tabOid{$newOid});
				}
			}
			#print STDERR "Return value : ".$request->getValue()."\n";
			#print STDERR "Next request OID : ".$request->getOID()."\n";
		}
	}
}

{
#
# Associate the handler with a particular OID tree
#
	$agent->register("my_agent_name", $regoid, \&myhandler);
}

