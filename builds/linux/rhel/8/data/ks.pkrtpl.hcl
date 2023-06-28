# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Red Hat Enterprise Linux 8

### Installs from the first attached CD-ROM/DVD on the system.
cdrom

### Performs the kickstart installation in text mode.
### By default, kickstart installations are performed in graphical mode.
text

### Don't runt he Setup Agent on first boot.
firstboot --disabled

### Accepts the End User License Agreement.
eula --agreed

### Sets the language to use during installation and the default language to use on the installed system.
lang ${ vm_guest_os_language }

### Sets the default keyboard type for the system.
keyboard ${ vm_guest_os_keyboard }

### Configure network information for target system and activate network devices in the installer environment (optional)
### --onboot	  enable device at a boot time
### --device	  device to be activated and / or configured with the network command
### --bootproto	  method to obtain networking configuration for device (default dhcp)
### --noipv6	  disable IPv6 on this device
###
### network  --bootproto=static --ip=172.16.11.200 --netmask=255.255.255.0 --gateway=172.16.11.200 --nameserver=172.16.11.4 --hostname centos-linux-8
network --bootproto=dhcp --hostname=${ vm_guest_os_hostname }

### Lock the root account.
rootpw --lock

### The selected profile will restrict root login.
### Add a user that can login and escalate privileges.
user --name=${ build_username } --iscrypted --password=${ build_password_encrypted } --groups=wheel

### Insert SSH public keys for the build user.
%{ for ssh_key in ssh_keys ~}
sshkey --username=${ build_username } "${ ssh_key }"
%{ endfor }

### Configure firewall settings for the system.
### --enabled	reject incoming connections that are not in response to outbound requests
### --ssh		allow sshd service through the firewall
firewall --enabled --ssh

### Sets up the authentication options for the system.
### The SSDD profile sets sha512 to hash passwords. Passwords are shadowed by default
### See the manual page for authselect-profile for a complete list of possible options.
authselect select sssd

### Sets the state of SELinux on the installed system.
### Defaults to enforcing.
selinux --enforcing

### Sets the system time zone.
timezone ${ vm_guest_os_timezone }

### Sets how the boot loader should be installed.
bootloader --location=mbr

### Initialize any invalid partition tables found on disks.
zerombr

### Removes partitions from the system, prior to creation of new partitions.
### By default, no partitions are removed.
### --linux	erases all Linux partitions.
### --initlabel Initializes a disk (or disks) by creating a default disk label for all disks in their respective architecture.
clearpart --all --initlabel

### Modify partition sizes for the virtual machine hardware.
### Create primary system partitions.
part /boot --fstype xfs --size=${ vm_guest_part_boot } --label=BOOTFS
part pv.01 --size=100 --grow

### Create a logical volume management (LVM) group.
volgroup sysvg --pesize=4096 pv.01

### Modify logical volume sizes for the virtual machine hardware.
### Create logical volumes.
logvol swap --fstype swap --name=lv_swap --vgname=sysvg --size=${ vm_guest_part_swap } --label=SWAPFS
logvol /home --fstype xfs --name=lv_home --vgname=sysvg --size=${ vm_guest_part_home } --label=HOMEFS --fsoptions="nodev,nosuid,usrquota,grpquota"
logvol /tmp --fstype xfs --name=lv_tmp --vgname=sysvg --size=${ vm_guest_part_tmp } --label=TMPFS --fsoptions="nodev,noexec,nosuid"
logvol /var --fstype xfs --name=lv_var --vgname=sysvg --size=${ vm_guest_part_var } --label=VARFS --fsoptions="nodev,noexec,nosuid"
logvol /var/log --fstype xfs --name=lv_log --vgname=sysvg --size=${ vm_guest_part_log } --label=LOGFS --fsoptions="nodev,noexec,nosuid"
logvol /var/log/audit --fstype xfs --name=lv_audit --vgname=sysvg --size=${ vm_guest_part_audit } --label=AUDITFS --fsoptions="nodev,noexec,nosuid"
logvol /var/tmp --fstype xfs --name=lv_vartmp --vgname=sysvg --size=${ vm_guest_part_vartmp } --label=VARTMPFS --fsoptions="nodev,noexec,nosuid"
%{ if vm_guest_part_root == 0 ~}
logvol / --fstype xfs --name=lv_root --vgname=sysvg --percent=100 --label=ROOTFS
%{ else ~}
logvol / --fstype xfs --name=lv_root --vgname=sysvg --size=${ vm_guest_part_root } --label=ROOTFS
%{ endif ~}

### Modifies the default set of services that will run under the default runlevel.
services --enabled=NetworkManager,sshd

### Do not configure X on the installed system.
skipx

### Packages selection
%packages --ignoremissing --excludedocs
@core
%{ for rpm_package in rpm_packages ~}
${rpm_package}
%{ endfor }

#### Remove unneeded firmware
-aic94xx-firmware
-atmel-firmware
-b43-openfwwf
-bfa-firmware
-ipw2100-firmware
-ipw2200-firmware
-ivtv-firmware
-iwl*firmware
-libertas-usb8388-firmware
-ql*-firmware
-rt61pci-firmware
-rt73usb-firmware
-xorg-x11-drv-ati-firmware
-zd1211-firmware
### Remove other unneeded packages
-cockpit
-quota
-alsa-*
-fprintd-pam
-intltool
-microcode_ctl
%end

### Disable RH kdump
%addon com_redhat_kdump --disable
%end

### Post-installation commands.
%post
/usr/sbin/subscription-manager syspurpose role --set "Red Hat Enterprise Linux Server"
if [ -z "${rhsm_pool}" ]; then
  /usr/sbin/subscription-manager register --username ${rhsm_username} --password ${rhsm_password} --auto-attach --force
else
  /usr/sbin/subscription-manager register --username ${rhsm_username} --password ${rhsm_password} --force
  /usr/sbin/subscription-manager attach --pool ${rhsm_pool}
fi
/usr/sbin/subscription-manager repos --enable "codeready-builder-for-rhel-8-x86_64-rpms"
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
dnf makecache
dnf install -y sudo open-vm-tools dnf-utils
echo "${ build_username } ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/${ build_username }
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
%end

### Reboot after the installation is complete.
### --eject attempt to eject the media before rebooting.
reboot --eject
