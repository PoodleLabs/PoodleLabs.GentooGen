#!/bin/bash
set -e

if [ -z "$USERNAME" ];
then 
    echo "USERNAME is unset"
    exit 343924300
fi

# Create a user account.
useradd "$USERNAME"

# Add the user to the necessary groups.
usermod "$USERNAME" -aG users
usermod "$USERNAME" -aG wheel
usermod "$USERNAME" -aG disk
usermod "$USERNAME" -aG cdrom
usermod "$USERNAME" -aG floppy
usermod "$USERNAME" -aG audio
usermod "$USERNAME" -aG video
usermod "$USERNAME" -aG input
usermod "$USERNAME" -aG seat

# Prompt to set the password for the user.
echo "User Account (${USERNAME}) Password:"
passwd "$USERNAME"

# Ensure a .config folder is created for the user.
config_folder="/home/$USERNAME/.config"
mkdir -p "$config_folder"

# Copy the default Sway config, if one exists.
default_sway_config="/etc/sway/config"
if [ -f $default_sway_config ]
then
    sway_config_folder="$config_folder/sway"
    mkdir -p "$sway_config_folder"
    cp "$default_sway_config" "$sway_config_folder"
fi

# Make the user the owner of their own config files
chown -R "$USERNAME" "$config_folder"
