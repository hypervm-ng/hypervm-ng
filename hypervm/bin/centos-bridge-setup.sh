#!/bin/bash
#
# (c) Dionysis Kladis, 2021 dkladis@hotmail.com
# 
#
# This file come from xen project
# https://wiki.xenproject.org/wiki/Scripts/centos-bridge-setup.sh
# 


default_netdev="NONE"
netdevs=()

function os-get-network-devices()
{
    local line
    
    while read line ; do
	local reg="^default.* dev ([0-9a-zA-Z]*) "
	if [[ $line =~ $reg  ]] ; then
	    default_netdev=${BASH_REMATCH[1]}
	fi
	reg="^[0-9./]* dev ([0-9a-zA-Z]*) "
	if [[ $line =~ $reg  ]] ; then
	    netdevs=(${netdevs[@]} ${BASH_REMATCH[1]})
	fi
    done < <(ip route show)
}

# This function is not used at this moment nmcli some times does not give correct output 
function centos-host-setup-bridge-c7-tgt() {
    local dev
    local default_con_uuid
    local slave_mac
    local slave_type
    local br="xenbr0"

    os-get-main-network-device var=dev
    
    if [[ ! "$dev" ]]; then
	fail "Couldn't find any active network devices during installation to configure."
    fi

    default_con_uuid=`/usr/bin/nmcli -t --fields UUID,DEVICE con show | grep $dev | awk -F: '{print $1}'`

    slave_mac=`/usr/bin/nmcli dev show $dev | grep HWADDR | awk '{print $2}'`

    slave_type=`/usr/bin/nmcli -t --fields TYPE,DEVICE con show | grep $dev | awk -F: '{print $1}'`

    xinfo "Creating $br"
    /usr/bin/nmcli con add type bridge con-name $br ifname $br
    /usr/bin/nmcli con modify $br bridge.stp no
    /usr/bin/nmcli con modify $br bridge.hello-time 0

    #info "adding $dev to bridge $br"
    #/usr/bin/nmcli con add type bridge-slave con-name $br-slave_$dev ifname $dev master $br
    #/usr/bin/nmcli con modify $br-slave_$dev $slave_type.mac-address $slave_mac

    #stopping the default connection to get hold of default device
    #/usr/bin/nmcli con modify $default_con_uuid connection.autoconnect no

    xinfo "Reconfiguguring $dev"
    # Make sure *any* ethernet-style device gets identified as the main connection
    /usr/bin/nmcli con modify $default_con_uuid connection.interface-name ""
    /usr/bin/nmcli con modify $default_con_uuid connection.master $br connection.slave-type bridge

    xinfo "Restarting network"
    service network restart
}

changed="false"

function make-bridge-for-network
{
    local dev=$1
    local br=$2
    local default_con_uuid
    local slave_mac
    local slave_type

    echo Setting up bridge $br for netdev $dev

    default_con_uuid=$(/usr/bin/nmcli -t --fields UUID,DEVICE con show | grep $dev | awk -F: '{print $1}')

    echo "Creating $br"
    /usr/bin/nmcli con add type bridge con-name $br ifname $br
    /usr/bin/nmcli con modify $br bridge.stp no
    /usr/bin/nmcli con modify $br bridge.hello-time 0

    /usr/bin/nmcli con modify $default_con_uuid connection.master $br connection.slave-type bridge

    changed="true"
}

os-get-network-devices

# Find 'primary' interface, make xenbr0

if [[ ! $default_netdev =~ xenbr* || ! $default_netdev =~ virbr* ]] ; then
    make-bridge-for-network $default_netdev xenbr0
else
    echo $default_netdev already set up
fi

# Find other interfaces, make xenbrN
count=0
for netdev in ${netdevs[@]} ; do
    if [[ "$netdev" = "$default_netdev" ]] ; then
	continue
    fi
    if [[ ! $netdev =~ xenbr* || ! $netdev =~ virbr* ]] ; then
	count=$(($count+1))
	br="xenbr$count"
	make-bridge-for-network $netdev $br
    else
	echo $netdev already set up
    fi
done

if $changed ; then
    echo "Network bridge(s) created succesfully"
 	
fi
