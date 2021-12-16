#!/bin/bash
#
# 7/16/2021 Dusan Baljevic provided some very good updates which this edition has below.  Namely, adding RHEL/CentOS 8 (and it's varieties).  
# There is a previous edition at discussion https://access.redhat.com/discussions/3487481 which has an uninstall routine (Thanks Dusan).
# To uninstall fips on RHEL/Cent 7, you'd just remove dracut-fips and eliminate the fips=1 directives in /etc/default/grub and do a grub2-mkconfig.
# RHEL/Cent 8 is different in removing fips and we may include that at a later time.  

# 10/17/2018 changed uname directives to use "uname -r" which works better in some environments.  Additionally ensured quotes were paired (some were not in echo statements)
#
# this script was posted originally at https://access.redhat.com/discussions/3487481 and the most current edition is most likely (maybe) posted there... maybe.  
# updated 8/24/2018 (thanks for those who  provided inputs for update)
# 
# Purpose, implement FIPS 140-2 compliance using the below article as a reference
# See Red Hat Article https://access.redhat.com/solutions/137833
##   --  I suspect Red-Hatter Ryan Sawhill https://access.redhat.com/user/2025843 put that solution together (Thanks Ryan).
# see original article, consider "yum install dracut-fips-aesni"
# --> And special thanks to Dusan Baljevic who identified typos and tested this on UEFI
# NOTE: You can create a Red Hat Login for free if you are a developer, 
# - Go to access.redhat.com make an account and then sign into 
# - developers.redhat.com with the same credentials and then check your email and accept the Developer's agreement.
# Risks...  1) Make sure ${mygrub} (defined in script) is backed up as expected and the directives are in place prior to reboot
# Risks...  2) Make sure /etc/default/grub is backed up as expected and the proper directives are in place prior to reboot
# Risks...  3) Check AFTER the next kernel upgrade to make sure the ${mygrub} (defined in script) is properly populated with directives
# Risks...  4) Be warned that some server roles either do not work with FIPS enabled (like a Satellite Server) or of other issues, and you've done your research
# Risks...  5) There are more risks, use of this script is at your own risk and without any warranty
# Risks...  6) The above list of risks is -not- exhaustive and you might have other issues, use at your own risk.
# Recommend using either tmux or screen session if you are using a remote session, in case your client gets disconnected. 
#

##### Where I found most of the directives... some was through my own pain with the cross of having to do stig compliance.
rhsolution="https://access.redhat.com/solutions/137833"
manualreview="Please manually perform the steps found at $rhsolution"

####### check if root is running this script, and bail if not root
# be root or exit
if [ "$EUID" -ne 0 ]; then
   echo -e "\tPlease run as root"
   exit 1
fi

## Dusan's suggestion...
myrhelcheck="$(rpm -qa --queryformat '%{VERSION}\n' '(redhat|sl|slf|centos|oraclelinux)-release(|-server|-workstation|-client|-computenode)')"

##### and bail if it is not RHEL 7 or 8
if [ "$(echo $myrhelcheck | egrep "^7|^8")" = "" ] ; then
   echo "\n\tScript is intended for RHEL 7 and 8 systems only, bailing...\n"
   exit 1
fi

## Dusan's suggestion...
echo -e "\n\tFIPS-140-2 Validation\n"
echo -e "\tChecking Linux Kernel parameters of currently booted system\n"
CMDLINE=$(cat /proc/cmdline)
if [ "$(echo $CMDLINE | egrep "fips=1")" = "" ]
then
   echo -e "\tFIPS is not enabled in kernel (fips=1)\n"
else
   echo -e "\tFIPS is enabled in kernel (fips=1)\n"
fi

## Dusan's suggestion...
FIPSCK="$(fipscheck 2>/dev/null)"
if [ "$FIPSCK" != "" ]
then
   if [ "$(echo $FIPSCK | grep -i off)" != "" ]
   then
      echo -e "\tFIPS is not enabled (verified by fipscheck)\n"
   else
      echo -e "\tFIPS is already enabled (verified by fipscheck)\n"
      exit 0
   fi
else
   answer=`sysctl crypto.fips_enabled`
   yes="crypto.fips_enabled = 1"
   configured="The sysctl crypto.fips_enabled command has detected FIPS is already configured, bailing..."
   notconfigured="FIPS not currently activated, so proceeding with script."

   if [ "$answer" == "$yes" ] ; then
      echo -e "\tFIPS is already enabled (verified by sysctl)\n"
      exit 0
   else
      echo -e "\tFIPS is not enabled (verified by sysctl)\n"
   fi
fi

## Dusan's suggestion...
if [[ "$myrhelcheck" =~ ^8.* ]]
then
   echo -e "\n\tRHEL 8 detected"
   echo -e "\tEnabling FIPS mode"
   fips-mode-setup --enable 
   echo -e "\n\tScript has completed.\n\t--AFTER--REBOOT--as-root-- run fipscheck\n"
   exit 0
fi

echo -e "\n\tRHEL 7 detected"
echo -e "\tEnabling FIPS mode"

##### uefi check, bail if uefi (I do not have a configured uefi system to test this on)
######- Added 7/5/2018, do not proceed if this is a UEFI system... until we can test it reliably
[ -d /sys/firmware/efi ] && fw="UEFI" || fw="BIOS"
echo -e "$fw"
if [ "$fw" == "UEFI" ] ; then
   echo -e "\n\tUEFI detected, this is a ($fw) system.\n\setting \$fw variable to ($fw)..."
   mygrub='/boot/efi/EFI/redhat/grub.cfg'  
   ### Thanks Dusan Baljevic for testing this.  
   ### exit 1
else
   echo -e "\n\t($fw) system detected, proceeding...\n"
   mygrub='/boot/grub2/grub.cfg'
fi

######- add a second to $mydate variable
sleep 1
mydate=`date '+%Y%m%d_%H_%M_%S'`;echo $mydate

##### make backup copy $mygrub defined earlier
cp -v ${mygrub}{,.$mydate}

##### check fips in grub, if it's there, bail, if not proceed
myfipscheckingrub=`grep fips $mygrub | grep linux16 | egrep -v \# | head -1`
if [ "$myfipscheckingrub" != "" ] ; then
   echo -e "FIPS directives detected in ($mygrub), \n\t\t($myfipscheckingrub)\n\tSo, recommend AGAINST running this script\n\t$manualreview"
   exit 1
else
   echo -e "\n\tFIPS directives not detected in ($mygrub)\n\tproceeding..."
fi

##### fips should not be in /etc/default/grub, if so, bail
etcdefgrub='/etc/default/grub'
myfipschecketcdefgrub=`grep fips $etcdefgrub | grep -v \#`
if [ "$myfipschecketcdefgrub" != "" ] ; then
   echo -e "FIPS directives detected in ($etcdefgrub), \n\t\t($myfipschecketcdefgrub)\n\tSo, recommend AGAINST running this script\n\t$manualreview"
   echo exit 1
else
   echo -e "\n\tFIPS directives not detected in ($etcdefgrub)\n\tproceeding..."
fi

##### verify that this system is actually in the same kernel as we're going to install this in..., or bail
# if they don't match, the script bails.
mydefkern=`grubby --default-kernel | sed 's/.*vmlinuz\-//g'| awk '{print $1}'`
myuname=`uname -r`
if [ "$mydefkern" != "$myuname" ] ; then
   echo -e "\n\tKernel Mismatch between running and installed kernel...\n\tThe default kernel is: $mydefkern\n\tThe running kernel is $myuname\n\n\tPlease reboot this system and then re-run this script\n\tBailing...\n"
   exit 1
else
 echo "Default Kernel ($mydefkern) and Current Running Kernel ($myuname) match, proceeding"
fi

##### overkill, yes
# yes, there's an number of checks above, but I'm still persisting with this, just in case someone runs this script twice.  
# it will never reach this if it fails any of the previous checks, but I'll leave it.
#####  a file named "/root/fipsinstalled" is created at the end of this script.  So I'll check for it at the beginning so that this script is only ran once.
if [ -f /root/fipsinstalled ] ; then
   sysctl crypto.fips_enabled
   echo -e "\tThis script was ran previously,\n\t nothing to do, \n\texiting..."
   exit 1
else
   echo "continuing" >/dev/null
   echo proceeding...
fi
############################################################################################
############################################################################################
############################################################################################

##### this is where the script actually begins to make modifications.  
# -- everything before was either a check, or a backup of a config
# Only install dracut-fips if it is not installed (that's the "||" below)
rpm -q dracut-fips > /dev/null || yum -y install dracut-fips

if [ "$(egrep -qw aes /proc/cpuinfo && echo YES || echo no)" == "YES" ]; then
   yum -y install dracut-fips-aesni
fi

##### warn people not to bail at this point, pause 4 seconds so they might see it if they're watching the screen.
echo -e "\n\n\n\tWARNING!!!: \n\tWARNING!!!DO NOT INTERRUPT THIS SCRIPT OR IT CAN CAUSE \n\tTHE SYSTEM TO BECOME UNBOOTABLE!!!!\n\tPlease be patient it will take some time...\n\tWARNING!!!\n\tWARNING\n\n\n"
sleep 4
##### next disable prelinking
rpm -q prelink >/dev/null && grep PRELINKING /etc/sysconfig/prelink 

##### slightly lesser known use of sed, it only flips PRELINKING to "no"
# this flips "yes" to "no" in the prelink config file, next kills prelinking
rpm -q prelink >/dev/null && sed -i '/^PRELINKING/s,yes,no,' /etc/sysconfig/prelink
rpm -q prelink >/dev/null && prelink -uav 2>/tmp/err
/bin/cp -v /etc/aide.conf{,.undofips}
rpm -q prelink >/dev/null && sed -i 's/^NORMAL.*/NORMAL = FIPSR+sha512/' /etc/aide.conf

##### update the $mydate variable which is used to copy off backups of various configs throughout the rest of this script.
mydate=`date '+%Y%m%d_%H_%M_%S'`;echo $mydate

###-----###
# back up existing initramfs
mv -v /boot/initramfs-$(uname -r).img{,.$mydate}

##### warn people not to bail at this point, pause 4 seconds so they might see it if they're watching the screen.
##### really, don't interrupt this portion.
echo -e "\n\n\n\tWARNING!!!: \n\tWARNING!!!DO NOT INTERRUPT THIS SCRIPT OR IT CAN CAUSE \n\tTHE SYSTEM TO BECOME UNBOOTABLE!!!!\n\tPlease be patient it will take some time...\n\tWARNING!!!\n\tWARNING!!!\n\n\n"
# this pauses as before so the person running this script gets a chance to see the above, it also is to allow the $mydate variable below to get a new value
sleep 3
# run dracut
dracut
mydate=`date '+%Y%m%d_%H_%M_%S'`
###-----###

###### The Red Hat solution I cited earlier in the comments, this is where this came from
# this section below updates /boot/grub/grub.cfg with fips and the uuid of the boot device
# first back it up
/bin/cp ${mygrub}{,.$mydate}
grubby --update-kernel=$(grubby --default-kernel) --args=fips=1

###### this displays the kernel lines in grub with fips
grep fips ${mygrub} | grep linux16

###### that Red Hat solution I cited earlier in the comments, this is where this came from
# set the uuid variable to be used later
uuid=$(findmnt -no uuid /boot)
echo -e "\n\t Just for reference, the /boot uuid is: ($uuid)\n"

###### that Red Hat solution I cited earlier in the comments, this is where this came from
# update  the boot uuid for fips in ${mygrub}
# the 2nd line is to satisfy the disa stig checker which checks every single menu entry linux16 line.  without it, the check fails.
[[ -n $uuid ]] && grubby --update-kernel=$(grubby --default-kernel) --args=boot=UUID=${uuid}
# update 7/23/2019.  The next line is excessive.  The impact of the next line, when the system goes to emergency mode, and you select **any** kernel at grub, you are faced with a system that **will not** accept any password.  I've removed it for the rescue kernel.
## so maybe your security people require this. **IF** the do, then know that when you go to emergency mode, you **will** require the grub password (know it in advance!) and you ought to set **one time only** the grub line to fips=0 **for a one time only boot**
# 
#sed -i "/linux16 \/vmlinuz-0-rescue/ s/$/ fips=1 boot=UUID=${uuid}/"  ${mygrub}

###### that Red Hat solution I cited earlier in the comments, this is where this came from
# update /etc/default/grub for subsequent kernel updates. this APPENDS to the end of the line.  
sed -i "/^GRUB_CMDLINE_LINUX/ s/\"$/  fips=1 boot=UUID=${uuid}\"/" /etc/default/grub
grep -q GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub || echo 'GRUB_CMDLINE_LINUX_DEFAULT="fips=1"' >> /etc/default/grub
echo -e "\n\tThe next line shows the new grub line with fips in the two locations below:\n"
grep $uuid ${mygrub} | grep linux16
echo;grep $uuid /etc/default/grub

### warning ### warning ###
### Note, if you do not change Ciphers and MACs prior to reboot, you will NOT be able to ssh to the system.  That could be a problem depending on the distance or difficulty of getting a console or physical access to fix after reboot.  Be warned.
###
mydate=`date '+%Y%m%d_%H_%M_%S'`;echo $mydate
cp -v /etc/ssh/sshd_config{,.$mydate}

# without this, no ssh, really, ask me how I know
sed -i 's/^Cipher.*/Ciphers aes128-ctr,aes192-ctr,aes256-ctr/' /etc/ssh/sshd_config
sed -i 's/^MACs.*/MACs hmac-sha2-256,hmac-sha2-512/' /etc/ssh/sshd_config


###### the command to check this after reboot is: sysctl crypto.fips_enabled
echo -e "\n\tScript has completed.  \n\tSystem must be rebooted for fips to be enabled.  \n\tPlease check the following 2 files for sane entries:\n\t/etc/default/grub \n\t${mygrub}.  \n\n\tAlso, --AFTER--REBOOT--as-root-- run sysctl crypto.fips_enabled and the output must be \n\t'crypto.fips_enabled = 1' \n"

##### without this, the disa provided stig checker fails fips compliance, you're welcome
rpm -q prelink > /dev/null && rpm -e prelink > /dev/null
##### Same with this...
/bin/chmod 0600 /etc/ssh/ssh_host*key

exit 0