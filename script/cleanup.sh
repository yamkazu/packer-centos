#!/bin/bash -eux
echo "==> Clear out machine id"
rm -f /etc/machine-id
touch /etc/machine-id

echo "==> Cleaning up temporary network addresses"
# Better fix that persists package updates: http://serverfault.com/a/485689
touch /etc/udev/rules.d/75-persistent-net-generator.rules
for ndev in `ls -1 /etc/sysconfig/network-scripts/ifcfg-*`; do
    if [ "`basename $ndev`" != "ifcfg-lo" ]; then
        sed -i '/^HWADDR/d' "$ndev";
        sed -i '/^UUID/d' "$ndev";
    fi
done
rm -rf /dev/.udev/

DISK_USAGE_BEFORE_CLEANUP=$(df -h)

echo "==> Removing tools used to build virtual machine drivers"
yum -y remove gcc libmpc mpfr cpp kernel-devel kernel-headers

echo "==> Clean up yum cache of metadata and packages to save space"
yum -y --enablerepo='*' clean all

echo "==> Removing temporary files used to build box"
rm -rf /tmp/*

echo "==> Rebuild RPM DB"
rpmdb --rebuilddb
rm -f /var/lib/rpm/__db*

# delete any logs that have built up during the install
find /var/log/ -name *.log -exec rm -f {} \;

echo '==> Clear out swap and disable until reboot'
set +e
swapuuid=$(/sbin/blkid -o value -l -s UUID -t TYPE=swap)
case "$?" in
	2|0) ;;
	*) exit 1 ;;
esac
set -e
if [ "x${swapuuid}" != "x" ]; then
    # Whiteout the swap partition to reduce box size
    # Swap is disabled till reboot
    swappart=$(readlink -f /dev/disk/by-uuid/$swapuuid)
    /sbin/swapoff "${swappart}"
    dd if=/dev/zero of="${swappart}" bs=1M || echo "dd exit code $? is suppressed"
    /sbin/mkswap -U "${swapuuid}" "${swappart}"
fi

echo '==> Zeroing out empty area to save space in the final image'
# Zero out the free space to save space in the final image.  Contiguous
# zeroed space compresses down to nothing.
dd if=/dev/zero of=/EMPTY bs=1M || echo "dd exit code $? is suppressed"
rm -f /EMPTY

# Block until the empty file has been removed, otherwise, Packer
# will try to kill the box while the disk is still full and that's bad
sync

echo "==> Disk usage before cleanup"
echo "${DISK_USAGE_BEFORE_CLEANUP}"

echo "==> Disk usage after cleanup"
df -h
