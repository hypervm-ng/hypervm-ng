<?php 
// 
// This file is part of the HyperVM installer
// dterweij 17aug09
// Installing OS Templates, OpenVZ yum/up2date repo
// 
//
include_once "htmllib/lib/include.php"; 

virt_install_main();

function virt_install_main()
{

	global $argv;

	$opt = parse_opt($argv);

	$virtualization = $opt['virtualization-type'];
	$installtype = $opt['install-type'];
	$skipostemplate = false;
	if (isset($opt['skipostemplate'])) { $skipostemplate = true; }


	if ($virtualization === 'openvz') {
		openvz_install($installtype);
	} else if ($virtualization === 'xen') {
		xen_install($installtype);
	}

	if ($installtype !== 'slave' && !$skipostemplate) {
		installOstemplates($virtualization);
	}

	print("Executing Update Cleanup... Will take a long time to finish....\n");
	lxshell_return("__path_php_path", "../bin/common/updatecleanup-installer.php", "--type=$installtype");

}

function openvz_install($installtype)
{
	$arch = `arch`;
	$arch = trim($arch);

	if ($arch === 'x86_64') {
		$list = array("vzctl.x86_64", "vzquota.x86_64", "ovzkernel.x86_64");
	} else {
		$list = array("vzctl", "vzquota", "ovzkernel-PAE");
	}

    if (is_centossix()) {
        lxfile_cp("../file/centos-6-openvz.repo.template", "/etc/yum.repos.d/openvz.repo");
    } else {
        lxfile_cp("../file/centos-5-openvz.repo.template", "/etc/yum.repos.d/openvz.repo");
    }

	run_package_installer($list);

	if (is_centossix()) {
		lxfile_cp("../file/sysfile/openvz/centos-6-openvz-ve-vswap-hypervm.conf-sample", "/etc/vz/conf/ve-vswap-hypervm.conf-sample");
	}

}

function installOstemplates($virtualization)
{
	system("mkdir -p /home/hypervm/xen/template/ ; cd /home/hypervm/xen/template/ ; wget -nd -np -c -r http://download.hypervm-ng.org/download/xentemplates/base/;");
	system("mkdir -p /vz/template/cache ; cd /vz/template/cache/ ; wget -nd -np -c -r http://download.hypervm-ng.org/download/openvztemplates/base/;");
}

function xen_install($installtype)
{

    // If openvz.repo file exist remove it imediately before install Xen
    if (file_exists("/etc/yum.repos.d/openvz.repo")) {
        unlink("/etc/yum.repos.d/openvz.repo");
    }

    if (is_centossix()) {
        $arch = `arch`;
        $arch = trim($arch);

        if ($arch === 'x86_64') {
            $list = array("centos-release-xen");
            run_package_installer($list);

        } else {
            echo "Sorry, installation aborted. Xen is not supported at CentOS 6 32bit.";
            exit;
        }
    }
	if (is_centosfive()) {
		$list = array("kernel-xen", "xen", "virt-manager");
	} else {
		$list = array("kernel-xen", "xen", "virt-manager", "lxmkinitrd", "lxkernel-domU-xen");
	}
    run_package_installer($list);
    if (file_exists("/boot/vmlinuz-2.6-xen") && !file_exists("/boot/hypervm-xen-vmlinuz")) {
        system("cd /boot ; ln -s vmlinuz-2.6-xen hypervm-xen-vmlinuz; ln -s initrd-2.6-xen.img hypervm-xen-initrd.img");
    }
    if (file_exists("/etc/init.d/libvirtd")) {
        system("chkconfig libvirtd off");
    }

    if (is_centosfive() || is_centossix()) {

        if (file_exists("/etc/init.d/xendomains")) {
            system("chkconfig xendomains on");
        }
        if (file_exists("/etc/init.d/xend")) {
            system("chkconfig xend on");
        }
    }

    if (is_centossix()) {
        system("../bin/grub-bootxen.sh");
		system("sh /script/fixxenkernel");
    }
}

function run_package_installer($list)
{
	$package = implode(" ", $list);
	print("Installing packages $package...\n");
	if (file_exists("/usr/bin/yum")) {
		system("yum -y install $package", $return_value);
	} else {
		system("PATH=\$PATH:/usr/sbin up2date --nosig $package", $return_value);
	}
}


