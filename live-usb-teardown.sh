#!/bin/bash

if [ ! -d /mnt/gentoo/ ]
then
    echo "/mnt/gentoo doesn't exist; you're probably in the chroot; run 'exit' then try again."
    exit 1
fi

umount /mnt/gentoo/home
umount /mnt/gentoo/efi
umount /mnt/gentoo/boot
umount /mnt/btrfsmirror
swapoff /dev/mapper/Swap
cryptsetup luksClose Swap
umount -l /mnt/gentoo
cryptsetup luksClose Space
