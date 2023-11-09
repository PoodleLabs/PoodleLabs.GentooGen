export INSTALL_DEVICE="nvme0n1" # For SATA or other devices, this should probably be sdX; do lsblk to determine the device you want to install to.
export VIDEO_CARDS="amdgpu radeonsi" # See https://wiki.gentoo.org/wiki/Handbook:AMD64/Full/Installation#VIDEO_CARDS
export LIB_DRM_FLAGS="video_cards_radeon" # To clear, set to a space (eg: " "); if your video_cards value includes radeonsi, you will need this sample value.
export STAGE3_AUTOBUILD_DIR="20231029T164701Z" # Look for the newest autobuild folder at https://distfiles.gentoo.org/releases/arm64/autobuilds/
export TIMEZONE="Europe/London"
export LANGUAGE="en_GB.UTF-8"
export HOSTNAME="my-computer"
./step-1-live-usb-pre-chroot.sh
