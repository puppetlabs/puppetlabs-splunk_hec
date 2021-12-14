#!/bin/bash
#
# Script to enable FIPS on centos/rhel. This has been tested on centos-7.

# Step 1: Disable PRELINKING.
if [ ! -f /etc/sysconfig/prelink ]; then
    echo "PRELINKING=no" > /etc/sysconfig/prelink
else
    echo "PRELINKING=no" >> /etc/sysconfig/prelink
fi

if [ -f /usr/sbin/prelink ]; then
    prelink -u -a
fi

# Step 1.5: Experimental 
# Install updated version of system openssl that is aligned with what gets installed
# as part of openssl-devel install
yum -y install openssl-1.0.2k-8.el7.x86_64

# Step 2: Install dracut-fips, dracut-fips-aesni and haveged packages
yum -y install dracut-fips
yum -y install dracut-fips-aesni

[ "$CLOUD_CI" =  PROD ] &&
   SERVER_LOGIN=foobar123@prod.example.com ||
   SERVER_LOGIN=foobar987@test.example.com

if [ -n $CLOUD_CI ]
then
  if [ $CLOUD_CI == "true" ]
  then
    yum install -y haveged
  else
    yum -y install https://artifactory.delivery.puppetlabs.net/artifactory/rpm__remote_epel/8/Everything/x86_64/Packages/h/haveged-1.9.14-1.el8.x86_64.rpm
  fi
fi

# Step 3: Find out the device details (BLOCK ID) of boot partition
boot_blkid=$(blkid `df /boot | grep "/dev" | awk 'BEGIN{ FS=" "}; {print $1}'` | awk 'BEGIN{ FS=" "}; {print $2}' | sed 's/"//g')

init_ramfs="/boot/initramfs-2.6.32-358.el6.x86_64.img"

# Step 4: Backup initramfs image and run dracut -v -f
#cp $init_ramfs "$init_ramfs".back
dracut -v -f

# Step 5: Manipulate /etc/default/grub to enable FIPs 
grub_file="/etc/default/grub"

fips_bootblk="fips=1 boot="$boot_blkid
grub_linux_cmdline=`grep -e "^GRUB_CMDLINE_LINUX" $grub_file | sed "s/\"$/ $fips_bootblk\"/"`

grep -v GRUB_CMDLINE_LINUX $grub_file > "$grub_file".bak; cp $grub_file.bak $grub_file

# Now bring in the modified line back
sed -i "/GRUB_DISABLE_RECOVERY/i \
  $grub_linux_cmdline" $grub_file

# Step 6: Generate /etc/grub2.cfg
grub2-mkconfig -o /boot/grub2/grub.cfg 

# Update rngd config to seed /dev/random from /dev/urandom - needed for testing, bad idea for production
# Taken from https://developers.redhat.com/blog/2017/10/05/entropy-rhel-based-cloud-instances/
systemctl enable haveged.service
systemctl enable rngd.service
mkdir -p /etc/systemd/system/rngd.d/
cat <<'DOWNWITHENTROPY' > /etc/systemd/system/rngd.d/customexec.conf
[Service]
ExecStart=
ExecStart=/sbin/rngd -f -r /dev/urandom
DOWNWITHENTROPY
