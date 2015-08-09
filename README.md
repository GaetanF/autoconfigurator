# autoconfigurator
Autoconfigurator script for minimal configuration of Host
Create Centreon monitoring for the specific host
Initialize network and basic network services for host

check-nagios :
- check_snmp_drbd : check drbd disk state using SNMP
- check_libvirt_domu : check virtual machine state using LibvirtD
- check-multipath : check path from multipath
