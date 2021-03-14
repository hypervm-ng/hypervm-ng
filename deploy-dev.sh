#!/usr/bin/env bash
#    HyperVM, Server Virtualization GUI for OpenVZ and Xen
#
#    Copyright (C) 2000-2009	LxLabs
#    Copyright (C) 2009-2014	LxCenter
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#	 author: Ángel Guzmán Maeso <angel.guzman@lxcenter.org>
#
#    Install and deploy a develoment version on a local enviroment
#
#    Version 1.0 remake the script with preset options and more funtionality [ Dionysis Kladis <dkladis@hotmail.com> ]
#    Version 0.6 Added local [ Krzysztof Taraszka <krzysztof.taraszka@hypervm-ng.org> ]
#    Version 0.5 Added legacy & NG [ Krzysztof Taraszka <krzysztof.taraszka@hypervm-ng.org> ]
#    Version 0.4 Added which, zip and unzip as requirement [ Danny Terweij <d.terweij@lxcenter.org> ]
#    Version 0.3 Added perl-ExtUtils-MakeMaker as requirement to install_GIT [ Danny Terweij <d.terweij@lxcenter.org> ]
#    Version 0.2 Changed git version [ Danny Terweij <d.terweij@lxcenter.org> ]
#    Version 0.1 Initial release [ Ángel Guzmán Maeso <angel.guzman@lxcenter.org> ]
#
set -e

if [[ -z "${DEBUG}" ]]; then
    set -x
fi

HYPERVM_PATH='/usr/local/lxlabs'
REPO="hypervm-ng"
BRANCH="dev"
LOCAL=""

usage(){
    echo "Usage: $0 [BRANCH] [REPOSITORY] [-h]"
    echo "-b : BRANCH (optional): git branch (like: $BRANCH) "
    echo "-r : REPOSITORY (optional): the repo you want to use  (like: $REPO)"
	echo "-l : if you want to use local installation at "$HYPERVM_PATH" path"
    echo '-h: shows this help.'
    exit 1
}

while getopts “h:r:b:l” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
		 l)
			LOCAL="ON" 
			 ;;	 
         r)
             REPO="$OPTARG"
             ;;
         b)
             BRANCH="$OPTARG"
			 ;;
         ?)
             usage
             exit
             ;;
     esac
done

if [[ -z $LOCAL ]] 
then
	echo "Using as defaults REPO: $REPO BRANCH: $BRANCH " 
else
	echo "Using local as source the local folder:" "$HYPERVM_PATH" 
fi

read -p "Do you agree with the above selections? Y or N: " -n 1 -r
echo    # (optional) move to a new line

if [[ ! $REPLY =~ ^[Yy]$ ]]
then
     echo -'h: shows the commands help.'
	exit 1
fi


install_GIT()
{
	if [ -f /etc/redhat-release ] ; then
		yum install -y git
	fi
}

require_root()
{
	if [ `/usr/bin/id -u` -ne 0 ]; then
    	echo 'Please, run this script as root.'
    	usage
	fi
}

require_requirements()
{
    #
    # without them, it will compile each run git and does not create/unzip the development files.
    #
    yum -y install which zip unzip
}


require_root

require_requirements

echo 'Installing HyperVM-NG development version.'

if which git >/dev/null; then
	echo 'GIT support detected.'
else
    echo 'No GIT support detected. Installing GIT.'
    install_GIT
fi

 

if [[ -n $LOCAL  ]] 
		then	
		
		# Clone from GitHub the last version using git transport (no http or https)
		echo "Preparing for install the local branch of hypervm" "${HYPERVM_PATH}"
        if [ ! -f ${HYPERVM_PATH}/.git ]
        then
    		touch ${HYPERVM_PATH}/.git
    	fi
		cd ${HYPERVM_PATH}/hypervm-install
		sh ./make-distribution.sh
		cd ..//hypervm
		sh ./make-development.sh
		cp hypervm-current.zip ${HYPERVM_PATH}/hypervm
		printf "Done.\nInstall HyperVM-NG:\n cd hypervm-install/hypervm-linux/\nsh hypervm-install-[master|slave].sh with args\n"
fi		

if [[ -z $LOCAL ]] 
then
# Clone from GitHub the last version using git transport (no http or https)
echo "Cleaning up old insmake-development.installs"
rm -Rf /usr/local/lxlabs.bak-old
		if [  -d ${HYPERVM_PATH}.bak ]
		then
		mv /usr/local/lxlabs.bak /usr/local/lxlabs.bak-old
		fi


	if [  -d ${HYPERVM_PATH}/hypervm ]
	then
		read -p "Do you want the existing installation as a development version of REPO: $REPO and BRANCH: $BRANCH  ? Y or N: " -n 1 -r
		echo    # (optional) move to a new line

		if [[  $REPLY =~ ^[Yy]$ ]]
		then
     			if [  ! -f ${HYPERVM_PATH}/.git ]
				then
		
					cd ${HYPERVM_PATH}
					git init
					git remote add origin git://github.com/$REPO/hypervm-ng.git
					git fetch origin
					git checkout origin/$BRANCH -ft
				else
					echo "This is already a development version, Updating from origin"
					git fetch origin
				fi
		fi
	else
	

	if [  -d ${HYPERVM_PATH} ]
	then
		mv /usr/local/lxlabs /usr/local/lxlabs.bak
	fi	

	if [ ! -d ${HYPERVM_PATH} ]
	then
		mkdir -p ${HYPERVM_PATH}
	fi
	echo "Installing branch $BRANCH from $REPO repository"
	git clone -b $BRANCH --single-branch git://github.com/$REPO/hypervm-ng.git  ${HYPERVM_PATH}

	if [ $? -ne 0 ]; then
		echo "Git checkout failed. Exiting."
	exit 1;
	fi
fi

cd ${HYPERVM_PATH}/hypervm-install
sh ./make-distribution.sh
cd ${HYPERVM_PATH}/hypervm
sh ./make-development.sh
printf "Done.\nInstall HyperVM-NG:\n cd "${HYPERVM_PATH}"/hypervm-install/hypervm-linux/\nsh hypervm-install-[master|slave].sh with args\n"
fi
