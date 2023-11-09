#!/bin/bash
set -e

# Set hostname; NetworkManager doesn't use /etc/hostname despite docs claiming otherwise.
cat /etc/hostname | { read -r hostname; nmcli general hostname $hostname; }

# Emerge remaining core packages.
emerge \
    media-sound/cmus \
    www-client/elinks \
    sys-apps/fbset \
    media-video/ffmpeg \
    dev-vcs/git \
    app-crypt/gnupg \
    sys-process/htop \
    media-video/mplayer \
    app-editors/nano \
    sys-block/parted

# Remove the script, now that we've completed execution.
rm "${BASH_SOURCE[0]}"
