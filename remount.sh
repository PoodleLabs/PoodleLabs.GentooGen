#!/bin/bash
set -e

if [ -z "$INSTALL_DEVICE" ];
then 
    echo "INSTALL_DEVICE is unset"
    exit 343924300
fi

# Ensure INSTALL_DEVICE has partition suffix.
if [[ $INSTALL_DEVICE == nvme* ]] && [[ $INSTALL_DEVICE != nvme*p ]]
then
  INSTALL_DEVICE="${INSTALL_DEVICE}p"
fi

# Open root fs.
echo "Root filesystem decryption:"
cryptsetup luksOpen "/dev/${INSTALL_DEVICE}3" Space

# Mount root partition.
mkdir /mnt/btrfsmirror
mount -t btrfs -o defaults,noatime,compress=lzo,autodefrag /dev/mapper/Space /mnt/btrfsmirror
mount -t btrfs -o defaults,noatime,compress=lzo,autodefrag,subvol=activeroot /dev/mapper/Space /mnt/gentoo
mount -t btrfs -o defaults,noatime,compress=lzo,autodefrag,subvol=home /dev/mapper/Space /mnt/gentoo/home

# Mount boot partition.
mount "/dev/${INSTALL_DEVICE}1" /mnt/gentoo/boot

# Open swap partition.
cryptsetup luksOpen "/dev/${INSTALL_DEVICE}2" Swap --key-file /mnt/gentoo/etc/swap.key
swapon "/dev/mapper/Swap"

# Set up bindings for incoming chroot.
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

echo "About to chroot..."
chroot /mnt/gentoo /bin/bash
