#!/bin/bash
# We need to call this script after centos-bridge-setup.sh in order to transfer the static ip adresses to the bridge interface
#
#
# initial version of the script by Dionydis Kladis dkladis@hotmail.com
# for hypervm-ng 
#
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

# We have to set the network paths and filename for centos 
NWSYSPATH='/etc/sysconfig/network-scripts/'
SCRIPTNM='ifcfg-'

function set-network-ips()
{
os-get-network-devices

for netdev in ${netdevs[@]} ; do
    
  	#we need to verify we are not parsing bridge files
    if [[ ! $netdev =~ virbr* ]] ; then
	if [[ ! $netdev =~ xenbr* ]] ; then
		# cheking wich interface has static ip
		
		while read line ; do
                    local reg="static"
                    if [[ $line =~ $reg  ]] ; then
			# since we found it lets make the filename we need to read
			netconf_filename="$NWSYSPATH$SCRIPTNM$netdev"
			if [[ -f $netconf_filename ]] ; then
                            while read line ; do
                            # We need to make sure we dont touch bridge interfaces
                            local reg="TYPE=Bridge"
                            if [[ ! $line =~ $reg ]] ; then
                                # Bellow we parse the Ip adress details and store them		
                                local reg="IPADDR="
                                
                                if [[ $line =~ $reg  ]] ; then
                                    ipaddress=${line[@]}		
                                fi
                                local reg="PREFIX="
                                
                                if [[ $line =~ $reg  ]] ; then
                                    prefix=${line[@]}
                                fi
                                local reg="GATEWAY="
                                
                                if [[ $line =~ $reg  ]] ; then
                                    gateway=${line[@]}
                                fi
                                local reg="DNS[0-9]="
				
                                declare -a dn
				
                                if [[ $line =~ $reg  ]] ; then
                                    dns=${line[@]}
                                    for val in $dns ; do
                                        dn+=($val)
                                    done
                                fi
                                # Here we need to find where that network file which bridge was assigned
                                local reg="BRIDGE="
                            if [[ $line =~ $reg ]] ; then
                                    vbrdg=${line[@]}
                                    brdg=$(echo $vbrdg | tr "=" "\n")
                                    for i in $brdg ; do
					cfgbridge=$i
                                    done
                                    # we need to make sure the name is in lower letters for filename processing
                                    bridge=$(echo $cfgbridge | tr [:upper:] [:lower:])
                                    brdgconf_file="$NWSYSPATH$SCRIPTNM$bridge"
                                    # we read the bridge file and check the default setting bootproto and store it
                                    while read a_line ; do
					local reg="BOOTPROTO="
					if [[ $a_line =~ $reg ]] ; then
                                            vbrcfg=${a_line[@]}
                                            brcfg=$(echo $vbrcfg | tr "=" "\n")
                                            for i in $brcfg ; do
						state=$i
                                            done
					fi
                                    done < $brdgconf_file
				# since we are ready we process the file and write what we need if the values are not null
				# that way we may also protect from accidental alterations 
                                if [[ -n "$ipaddress" || -n "$prefix" || -n "$gateway" ]]; then
                                    if [[ $state =~ "dhcp" ]] ; then
                                        sed -i~ 's/BOOTPROTO=dhcp/BOOTPROTO=static/' $brdgconf_file
					echo "$ipaddress" >>  $brdgconf_file
					echo "$prefix" >> $brdgconf_file
					echo "$gateway" >> $brdgconf_file
					for k in "${dn[@]}"; do echo "$k" >> $brdgconf_file ; done
                                            assigned="true"
                                    fi
				fi	
                            fi
                	fi
                    done < $netconf_filename
		
			else 
                            echo "Network config file $netconf_filename is missing for interface $netdev"
                            echo "Please verify network config"
			fi
                    else
			echo "No static ip address detected for  $netdev interface"
                    fi	
		done < <(ip route show | grep "static")
	else
		echo "This $netdev is a bridge interface. Please verify network configuration"
	fi
    else
	echo "This $netdev is a bridge interface. Please verify network configuration"
    fi	
done
}

# We need to call the function and set the flag for services restart
assigned="false"
set-network-ips

if $assigned ; then
    echo "Restarting network"
    service network restart
fi