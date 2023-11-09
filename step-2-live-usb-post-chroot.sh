#!/bin/bash
set -e

# Check all required variables are set.
if [ -z "$INSTALL_DEVICE" ];
then
    echo "INSTALL_DEVICE is unset"
    exit 343924300
fi

if [ -z "$LIB_DRM_FLAGS" ];
then
    echo "LIB_DRM_FLAGS is unset"
    exit 343924302
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

# Load the bash profile.
source /etc/profile

# Ensure INSTALL_DEVICE has the partition suffix if necessary.
if [[ $INSTALL_DEVICE == nvme* ]] && [[ $INSTALL_DEVICE != nvme*p ]]
then
  INSTALL_DEVICE="${INSTALL_DEVICE}p"
fi

# Prompt to set the root account password.
echo "Root Account Password:"
passwd

# Prompt to select system locales.
nano /etc/locale.gen

# Prompt for hwclock configuration.
nano /etc/conf.d/hwclock

# Prompt for keymap selection.
nano /etc/conf.d/keymaps

# Sync Portage in preparation for package installation and configuration.
emerge-webrsync
emerge --sync --quiet

# Set the system timezone.
echo "$TIMEZONE" > /etc/timezone
emerge --config sys-libs/timezone-data

# Generate the system locales and set the preferred language.
locale-gen
cat >/etc/locale.conf <<EOL
LANG="${LANGUAGE}"
LC_COLLATE="C.UTF-8"
EOL

# Set the system hostname.
echo "$HOSTNAME" > /etc/hostname

# Reload the shell now we've set locale and timezone.
env-update && source /etc/profile

# Build cpuflags according to the system's cpuid.
emerge app-portage/cpuid2cpuflags
cpu_flags=$(cpuid2cpuflags)

# Write Portage's package.use file.
rm /etc/portage/package.use -r
cat >/etc/portage/package.use <<EOL
# CPU Flags
*/* ${cpu_flags}

# System
net-misc/networkmanager bluetooth concheck connection-sharing iptables gnutls modemmanager lto tools wifi
net-misc/curl pop3 smtp websockets adns curl_ssl_openssl
sys-kernel/linux-firmware redistributable
sys-kernel/installkernel-gentoo grub
app-shells/bash-completion eselect
sys-kernel/gentoo-sources symlink
sys-apps/systemd-utils tmpfiles
app-alternatives/yacc reference
net-wireless/wpa_supplicant ap
app-alternatives/bzip2 lbzip2
sys-kernel/genkernel firmware
sys-auth/seatd buildin server
app-i18n/fbterm gpm filecaps
sys-boot/grub device-mapper
app-alternatives/lex reflex
app-alternatives/gzip pigz
app-alternatives/cpio gnu
app-alternatives/awk gawk
app-alternatives/tar gnu
app-alternatives/sh bash
sys-fs/cryptsetup argon2
app-misc/tmux vim-syntax
app-alternatives/bc gnu
app-crypt/pinentry caps
net-misc/iputils arping
sys-apps/pciutils kmod
sys-apps/openrc bash
dev-libs/openssl asm

# video_cards_radeon needed for radeon_si in video flags.
x11-libs/libdrm ${LIB_DRM_FLAGS}

# Utilities
app-crypt/gnupg smartcard tools
sys-block/parted device-mapper
dev-vcs/git gpg highlight

# Programs
media-video/ffmpeg amf bluray mzip2 cdio cpudetection encode gpl iconv jpeg2k jpegxl kvazaar libaribb24 libass libcaca libplacebo libsoxr libv4l libxml2 mipsdsarl mipsdspr2 mipsfpu mmal modplug mp3 network openh264 postproc sdl srt svt-av1 v4l vorbis vpx x265 xvid zvbi
media-video/mplayer bluray cdio cpudetection dvd fbcon jpeg libass libcaca lzo mad mp3 network png v4l vorbis x264
media-sound/cmus aac ao flac mad modplug mp4 vorbis wavpack
www-client/elinks bittorrent ftp gpm javasript mouse
app-editors/nano justify magic
sys-process/htop caps

# Libs
media-libs/harfbuzz icu glib # For cmus and ffmpeg (and Sway)
media-libs/libsdl2 sound video gles2 # For cmus and ffmpeg
net-dns/dnsmasq dhcp dhcp-tools # For networkmanager
media-libs/mesa llvm gles2 # For ffmpeg (and Sway)
gui-libs/wlroots drm libinput session # For Sway
media-libs/libplacebo shaderc # For ffmpeg
net-libs/libssh sftp # For cmus
EOL

# Emerge core packages.
emerge \
    app-alternatives/awk \
    app-shells/bash-completion \
    app-alternatives/bc \
    app-alternatives/cpio \
    sys-fs/cryptsetup \
    net-misc/curl \
    app-admin/doas \
    app-i18n/fbterm \
    sys-kernel/genkernel \
    sys-kernel/gentoo-sources \
    gui-libs/greetd \
    sys-boot/grub \
    app-alternatives/gzip \
    sys-kernel/installkernel-gentoo \
    app-alternatives/bzip2 \
    app-alternatives/lex \
    sys-kernel/linux-firmware \
    net-misc/networkmanager \
    sys-apps/openrc \
    dev-libs/openssl \
    sys-apps/pciutils \
    app-crypt/pinentry \
    sys-auth/seatd \
    app-alternatives/sh \
    app-alternatives/tar \
    app-misc/tmux \
    gui-apps/tuigreet \
    net-wireless/wpa_supplicant \
    app-alternatives/yacc

# Compile the Linux kernel.
eselect kernel set 1
genkernel \
    --luks \
    --btrfs \
    --keymap \
    --no-splash \
    --bootloader=grub \
    --oldconfig --save-config --menuconfig \
    --install all

# Extract the UUID for the root partition.
read -ra rarr <<< $(blkid /dev/${INSTALL_DEVICE}3 -s UUID)
root_part_uuid=${rarr[1]};
root_part_uuid=${root_part_uuid:6:36}

# Write grub configuration.
cat >/etc/default/grub <<EOL
GRUB_DISABLE_LINUX_PARTUUID=false
GRUB_DISTRIBUTOR="Gentoo"
GRUB_TIMEOUT=3

GRUB_ENABLE_CRYPTODISK=y
GRUB_CMDLINE_LINUX_DEFAULT=" crypt_root=UUID=${root_part_uuid} quiet splash"
EOL

# Install grub to the boot partition.
grub-install --target=x86_64-efi --efi-directory=/boot --removable --recheck
mkdir -p /boot/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Disable the default hostname service
rc-update delete hostname boot

# Enable the networkmanager service for boot time.
rc-update add NetworkManager boot

# Enable the dbus service for boot time.
rc-update add dbus boot

# Enable the seatd service for boot time.
rc-update add seatd boot

# Extract the UUID for the swap partition.
read -ra sarr <<< $(blkid /dev/${INSTALL_DEVICE}2 -s UUID)
swap_part_uuid=${sarr[1]};
swap_part_uuid=${swap_part_uuid:6:36}

# Create the crypt-swap service.
cat >/etc/init.d/crypt-swap <<EOL
#!/sbin/openrc-run

start() {
    cryptsetup luksOpen UUID="${swap_part_uuid}" Swap --key-file /etc/swap.key
    swapon /dev/mapper/Swap
}

stop() {
    swapoff /dev/mapper/Swap
    cryptsetup luksClose /dev/mapper/Swap
}
EOL
chmod a+x /etc/init.d/crypt-swap

# Enable the crypt-swap service for boot time.
rc-update add crypt-swap boot

# Write fbterm start script for greetd to execute.
cat >/etc/greetd/fbterm <<EOL
#!/bin/bash

# Generate a temporary session directory.
export XDG_RUNTIME_DIR="/tmp/fbses/\${uuidgen}"
mkdir -p \$XDG_RUNTIME_DIR
chmod 0700 \$XDG_RUNTIME_DIR
exec /usr/bin/fbterm "\$@"
EOL
chmod a+x /etc/greetd/fbterm

# Write greetd config.
cat >/etc/greetd/config.toml <<EOL
[terminal]
vt = current

[default_session]
command = "tuigreet --cmd /etc/greetd/fbterm"
user = "greetd"
EOL

# Give fbterm 'cap_sys_tty_config' capability
setcap cap_sys_tty_config+ep /usr/bin/fbterm

# Create the greetd service.
cat >/etc/init.d/greetd <<EOL
#!/sbin/openrc-run

start() {
    greetd
}

stop() {
    echo "Exiting greetd."
}
EOL
chmod a+x /etc/init.d/greetd

# Enable the greetd service in the default runlevel.
rc-update add greetd default

# Add the greetd user to the relevant groups.
usermod "greetd" -aG video -aG input -aG seat

# Write the doas config.
cat >/etc/doas.conf <<EOF
permit setenv {PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin} :wheel
EOF
chown -c root:root /etc/doas.conf
chmod -c 0400 /etc/doas.conf

# Trigger a global recompile.
emerge --update --deep --newuse @world

# Clean up dependencies.
emerge --depclean

echo "Live USB completed; please reboot into the installed gentoo environment to execute remaining steps."

# Remove the script, now that we've completed execution.
rm "${BASH_SOURCE[0]}"

# Finally, drop out to a shell inside the chroot.
PS1="(chroot) {PS1}" /bin/bash
