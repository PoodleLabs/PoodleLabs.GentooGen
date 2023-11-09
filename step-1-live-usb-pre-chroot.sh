#!/bin/bash
set -e

# Check all required variables are set.
if [ -z "$INSTALL_DEVICE" ];
then
    echo "INSTALL_DEVICE is unset"
    exit 343924300
fi

if [ -z "$VIDEO_CARDS" ];
then
    echo "VIDEO_CARDS is unset"
    exit 343924301
fi

if [ -z "$LIB_DRM_FLAGS" ];
then
    echo "LIB_DRM_FLAGS is unset"
    exit 343924302
fi

if [ -z "$STAGE3_AUTOBUILD_DIR" ];
then
    echo "STAGE3_AUTOBUILD_DIR is unset"
    exit 343924303
fi

if [ -z "$TIMEZONE" ];
then 
    echo "TIMEZONE is unset"
    exit 343924304
fi

if [ -z "$LANGUAGE" ];
then 
    echo "LANGUAGE is unset"
    exit 343924305
fi

if [ -z "$HOSTNAME" ];
then 
    echo "HOSTNAME is unset"
    exit 343924306
fi

# Sync the time.
chronyd -q

# Create a random keyfile for the Swap partition.
dd bs=512 count=16 if=/dev/random of=/swap.key iflag=fullblock
chown root:root /swap.key
chmod -v 0400 /swap.key

# Get the memory size in GB.
read -ra marr <<< $(free --giga | grep Mem)
memory_gb="${marr[1]}"

# The EFI boot partition will be 128 MB in size.
efi_size=128

# Calculate the end of the swap partition; the swap partition will be (memory_gb * 2)GB in size.
read -ra marr <<< $(free --mega | grep Mem)
mmb="${marr[1]}"
swap_end=$(expr $mmb + $mmb + $efi_size)

# Partition the install device (boot:fat32, swap:linux-swap, root:btrfs).
echo "Installation device format:"
parted "/dev/$INSTALL_DEVICE" -a optimal mklabel gpt

echo "Boot partition creation:"
parted "/dev/$INSTALL_DEVICE" -a optimal mkpart boot fat32 0%  "${efi_size}M"

echo "Swap partition creation:"
parted "/dev/$INSTALL_DEVICE" -a optimal mkpart swap linux-swap "${efi_size}M" "${swap_end}M"

echo "Root partition creation:"
parted "/dev/$INSTALL_DEVICE" -a optimal mkpart root btrfs "${swap_end}M" 100%
parted "/dev/$INSTALL_DEVICE" set 1 boot on
parted "/dev/$INSTALL_DEVICE" set 2 swap on

# We've created our partitions and all subsequent uses of INSTALL_DEVICE refer to those partitions.
# For sdX devices, partitions are sdXY, and for nvme0nX devices, partitions are nvme0nXpY.
# Update INSTALL_DEVICE to include the `p` suffix if necessary.
if [[ $INSTALL_DEVICE == nvme* ]] && [[ $INSTALL_DEVICE != nvme*p ]]
then
  INSTALL_DEVICE="${INSTALL_DEVICE}p"
fi

# Encrypt the root partition, prompting for a password.
echo "Root filesystem encryption:"
cryptsetup luksFormat -s256 -c aes-xts-plain64 "/dev/${INSTALL_DEVICE}3"

# Encrypt the swap partition with the keyfile we generated earlier.
cryptsetup luksFormat --key-file "/swap.key" "/dev/${INSTALL_DEVICE}2"

# Make the boot partition's filesystem (fat32).
mkfs.vfat -F 32 "/dev/${INSTALL_DEVICE}1"

# Make the swap partition's filesystem (linux-swap), and enable it.
cryptsetup luksOpen "/dev/${INSTALL_DEVICE}2" --key-file "/swap.key" Swap
mkswap /dev/mapper/Swap
swapon /dev/mapper/Swap

# Make the root partition's filesystem (btrfs).
echo "Root filesystem decryption:"
cryptsetup luksOpen "/dev/${INSTALL_DEVICE}3" Space
mkfs.btrfs -L BTROOT /dev/mapper/Space

# Mount the root parition.
mkdir -p /mnt/btrfsmirror
mount -t btrfs -o defaults,noatime,compress=lzo,autodefrag /dev/mapper/Space /mnt/btrfsmirror

# Create the root partition's root subvolume.
btrfs subvol create /mnt/btrfsmirror/activeroot
mount -t btrfs -o defaults,noatime,compress=lzo,autodefrag,subvol=activeroot /dev/mapper/Space /mnt/gentoo

# Create 'home', 'boot' and 'efi' directories on the root partition.
mkdir /mnt/gentoo/home
mkdir /mnt/gentoo/boot
mkdir /mnt/gentoo/efi

# Create a home subvolume on the root partition, and mount it to the 'home' directory.
btrfs subvol create /mnt/btrfsmirror/home
mount -t btrfs -o defaults,noatime,compress=lzo,autodefrag,subvol=home /dev/mapper/Space /mnt/gentoo/home

# Mount the boot partition to the 'efi' and 'boot' directories.
mount "/dev/${INSTALL_DEVICE}1" /mnt/gentoo/efi
mount "/dev/${INSTALL_DEVICE}1" /mnt/gentoo/boot

# Download the stage3 tar (amd64 hardened openrc) to the installation root, along with signatures and hashes.
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/$STAGE3_AUTOBUILD_DIR/stage3-amd64-hardened-openrc-$STAGE3_AUTOBUILD_DIR.tar.xz -O /mnt/gentoo/stage3.tar.xz
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/$STAGE3_AUTOBUILD_DIR/stage3-amd64-hardened-openrc-$STAGE3_AUTOBUILD_DIR.tar.xz.asc -O /mnt/gentoo/stage3.tar.xz.asc
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/$STAGE3_AUTOBUILD_DIR/stage3-amd64-hardened-openrc-$STAGE3_AUTOBUILD_DIR.tar.xz.sha256 -O /mnt/gentoo/stage3.tar.xz.sha256
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/$STAGE3_AUTOBUILD_DIR/stage3-amd64-hardened-openrc-$STAGE3_AUTOBUILD_DIR.tar.xz.DIGESTS -O /mnt/gentoo/stage3.tar.xz.DIGESTS

# Verify the stage3 tar.
gpg --import /usr/share/openpgp-keys/gentoo-release.asc
gpg --verify /mnt/gentoo/stage3.tar.xz.asc
gpg --verify /mnt/gentoo/stage3.tar.xz.sha256
gpg --verify /mnt/gentoo/stage3.tar.xz.DIGESTS

# Extract the stage3 tar to the installation root.
tar xpvf /mnt/gentoo/stage3.tar.xz --xattrs-include="*.*" --numeric-owner -C /mnt/gentoo/

# Delete the stage3 tar, signatures and hashes.
rm /mnt/gentoo/stage3.tar.xz
rm /mnt/gentoo/stage3.tar.xz.asc
rm /mnt/gentoo/stage3.tar.xz.sha256
rm /mnt/gentoo/stage3.tar.xz.DIGESTS

# Move the swap key into the installation root's 'etc' directory.
mv /swap.key /mnt/gentoo/etc/

# Calculate the number of threads Portage should use when emerging packages.
# j = min(thread_count, gb_of_ram / 2)
t=$(nproc)
mh=$(expr $memory_gb / 2)
j=$(( t > mh ? mh : t ))

# Write Portage's make.conf file.
cat >/mnt/gentoo/etc/portage/make.conf <<EOL
# Clear use flags.
USE="-*"

# Basic compilation options.
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"
LC_MESSAGES=C.utf8

# Accept only free licenses by default.
ACCEPT_LICENSE="-* @FREE"

# GRUB is configured for EFI only.
GRUB_PLATFORMS="efi-64"

# The number of threads to use when compiling.
MAKEOPTS="-j${j} -l${j}"

# Global use flags.
VIDEO_CARDS="${VIDEO_CARDS}"
USE="\${USE} alsa brotli bzip2 cet cli crypt dbus dri drm ffmpeg fontconfig \
    hardened iconv idn kmod libdrm libsamplerate lm-sensors lzma \
    man multilib ncurses nls nptl openmp openssl pam pcre pie \
    readline seccomp split-usr ssh ssl ssp threads truetype udev unicode \
    vaapi vdpai vulkan wayland wayland-only xattr xtpax zip zlib zstd"

# Programming language targets.
PYTHON_SINGLE_TARGET="python3_11"
PYTHON_TARGETS="python3_11"

LUA_SINGLE_TARGET="lua5-1"
LUA_TARGETS="lua5-1"

ADA_TARGET="gnat_2021"

PHP_TARGETS="php8-1"

RUBY_TARGETS="ruby31"

POSTGRES_TARGETS="postgres15"

# System flags.
INPUT_DEVICES="libinput" 
LCD_DEVICES="ncurses text"
# The following LCD devices have been removed from the default value for the hardened OpenRC profile:
# bayrad cfontz cfontz633 glk hd44780 lb216 lcdm001 mtxorb

# 'Office' flags.
# LIBREOFFICE_EXTENSIONS="presenter-console presenter-minimizer"
# CALLIGRA_FEATURES="karbon sheets words"
# OFFICE_IMPLEMENTATION="libreoffice"

# GPS flags.
# GPSD_PROTOCOLS="ashtech aivdm earthmate evermore fv18 garmin garmintxt gpsclock greis isync itrax mtk3301 nmea ntrip navcom oceanserver oldstyle oncore rtcm104v2 rtcm104v3 sirf skytraq superstar2 timing tsip tripmate tnt ublox ubx"

# Collectd flags.
# COLLECTD_PLUGINS="df interface irq load memory rrdtool swap syslog"

# xtables flags.
# XTABLES_ADDONS="quota2 psd pknock lscan length2 ipv4options ipset ipp2p iface geoip fuzzy condition tee tarpit sysrq proto steal rawnat logmark ipmark dhcpmac delude chaos account"
EOL

# Write Portage's package.license file.
cat >/mnt/gentoo/etc/portage/package.license <<EOL
# Accept binary redistributable licenses for linux-firmware; this is for drivers.
sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE
EOL

# Write Portage's package.accept_keywords file.
rm /mnt/gentoo/etc/portage/package.accept_keywords -r
cat >/mnt/gentoo/etc/portage/package.accept_keywords <<EOL
gui-apps/tuigreet ~amd64
EOL

# Prompt the user to select Portage mirrors, appending them to the end of the make.conf file.
mirrorselect -i -o >> /mnt/gentoo/etc/portage/make.conf

# Copy Portage's repos.conf into the installation.
mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf

# Copy DNS information into the installation.
cp --dereference /etc/resolv.conf /mnt/gentoo/etc

# Get the UUID for the boot partition.
read -ra barr <<< $(blkid /dev/${INSTALL_DEVICE}1 -s UUID)
boot_part_uuid=${barr[1]};
boot_part_uuid=${boot_part_uuid:6:9}

# Write an fstab for the installed linux environment.
cat >/mnt/gentoo/etc/fstab <<EOL
LABEL=BTROOT            /       btrfs   defaults,noatime,compress=lzo,autodefrag,discard=async,subvol=activeroot    0   0
LABEL=BTROOT            /home   btrfs   defaults,noatime,compress=lzo,autodefrag,discard=async,subvol=home          0   0
UUID=${boot_part_uuid}  /efi    vfat    umask=077                                                                   0   1
UUID=${boot_part_uuid}  /boot   vfat    umask=077                                                                   0   1
EOL

# Set up bindings for the impending chroot.
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

# Copy the second step script to the chroot target.
cp "$(dirname -- "${BASH_SOURCE[0]}")/step-2-live-usb-post-chroot.sh" "/mnt/gentoo"

# Copy the first boot script to the chroot target.
cp "$(dirname -- "${BASH_SOURCE[0]}")/step-3-first-boot.sh" "/mnt/gentoo/bin/step-3-first-boot"

# Copy the optional Sway script to the chroot target.
cp "$(dirname -- "${BASH_SOURCE[0]}")/step-4-optional-sway-wm.sh" "/mnt/gentoo/bin/step-4-optional-sway-wm"

# Copy the make user script to the chroot target.
cp "$(dirname -- "${BASH_SOURCE[0]}")/make-user.sh" "/mnt/gentoo/bin/make-user"

# Copy the display image script to the chroot target.
cp "$(dirname -- "${BASH_SOURCE[0]}")/display-image.sh" "/mnt/gentoo/bin/display-image"

# Copy the play-video script to the chroot target.
cp "$(dirname -- "${BASH_SOURCE[0]}")/play-video.sh" "/mnt/gentoo/bin/play-video"

# Copy the get-fb-geometry script to the chroot target.
cp "$(dirname -- "${BASH_SOURCE[0]}")/get-fb-geometry.sh" "/mnt/gentoo/bin/get-fb-geometry"

# Copy the scale-to-fit script to the chroot target.
cp "$(dirname -- "${BASH_SOURCE[0]}")/scale-to-fit.sh" "/mnt/gentoo/bin/scale-to-fit"

# Copy the scale-to-fill script to the chroot target.
cp "$(dirname -- "${BASH_SOURCE[0]}")/scale-to-fill.sh" "/mnt/gentoo/bin/scale-to-fill"

# Change the root directory and run the second step script.
chroot "/mnt/gentoo/" "./step-2-live-usb-post-chroot.sh"
