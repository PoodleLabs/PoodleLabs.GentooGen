#!/bin/bash
set -e

cat >>/etc/portage/package.use <<EOL

# Sway
x11-libs/gdk-pixbuf png jpeg # For Sway backgrounds
media-libs/freetype png # For bemenu
gui-wm/sway swaybar swaynag
dev-libs/bemenu ncurses
EOL

# Emerge Sway packages
emerge dev-libs/bemenu \
    gui-apps/foot \
    gui-apps/grim \
    gui-apps/slurp \
    gui-wm/sway \
    gui-apps/swaylock

# Write Sway start script for greetd to execute.
cat >/etc/greetd/sway <<EOL
#!/bin/bash

# Generate a temporary session directory.
export XDG_RUNTIME_DIR="/tmp/swses/\${uuidgen}"
mkdir -p \$XDG_RUNTIME_DIR
chmod 0700 \$XDG_RUNTIME_DIR

# Launch Sway
sway
EOL
chmod a+x /etc/greetd/sway

# Overwrite greetd config to load Sway.
cat >/etc/greetd/config.toml <<EOL
[terminal]
vt = current

[default_session]
command = "tuigreet --cmd /etc/greetd/sway"
user = "greetd"
EOL

# Write the default Sway WM config.
sway_conf_dir="/etc/sway"
mkdir -p $sway_conf_dir
cat >"$sway_conf_dir/config" <<EOL
# Input configuration
input * {
    # Keyboard Layout
    xkb_layout gb 
}

# Output configuration
# output * bg ~/background.png fill
# output LVDS-1 mode 1600x900@59.995HZ position 1920,0
# output DP-1 mode 1920x1080@143.996002HZ position 0,0

# Logo key. Use Mod1 for Alt.
set \$mod Mod4

# Preferred Terminal
set \$term foot

# Preferred App Launcher
set \$menu bemenu-run | xargs swaymsg exec --

# Preferred Browser
set \$browser librewolf --enable-features=UseOzonePlatform --ozone-platform=wayland

# Preferred Text Editor
set \$editor codium --enable-features=UseOzonePlatform --ozone-platform=wayland

# Preferred File Explorer
set \$explorer thunar

# Screenshot Command
set \$screenshot grim -g "\$(slurp)" - | wl-copy

include /etc/sway/config-vars.d/*

# Idle configuration
exec swayidle -w timeout 180 'swaylock -f -c 000000' before-sleep 'swaylock -f -c 000000'
exec swayidle -w timeout 10 'if pgrep -x swaylock; then swaymsg "output * dpms off"; fi' resume 'swaymsg "output * dpms on"'
exec swayidle -w timeout 600 'if pgrep -x swaylock; then systemctl suspend; fi'

# Keybinds
# Basic:
    # Quit
    bindsym \$mod+q kill

    # Start terminal
    bindsym \$mod+t exec \$term

    # Start launcher
    bindsym \$mod+a exec \$menu

    # Start browser
    bindsym \$mod+w exec \$browser

    # Start text editor
    bindsym \$mod+c exec \$editor

    # Start explorer
    bindsym \$mod+e exec \$explorer

    # Lock the screen
    bindsym \$mod+l exec "swaylock -f -c 000000"

    # Screenshot
    bindsym \$mod+s exec \$screenshot

    # Drag floating windows by holding down \$mod and left mouse button.
    # Resize them with right mouse button + \$mod.
    # Despite the name, also works for non-floating windows.
    floating_modifier \$mod normal

    # Reload the configuration file
    bindsym \$mod+Shift+c reload

    # Exit sway (logs you out of your Wayland session)
    bindsym \$mod+Shift+q exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' 'swaymsg exit'
# Moving around:
    # Move your focus around
    bindsym \$mod+Left focus left
    bindsym \$mod+Down focus down
    bindsym \$mod+Up focus up
    bindsym \$mod+Right focus right

    # Move the focused window with the same, but add Shift
    bindsym \$mod+Shift+Left move left
    bindsym \$mod+Shift+Down move down
    bindsym \$mod+Shift+Up move up
    bindsym \$mod+Shift+Right move right

# Workspaces:
    # Switch to workspace
    bindsym \$mod+1 workspace number 1
    bindsym \$mod+2 workspace number 2
    bindsym \$mod+3 workspace number 3
    bindsym \$mod+4 workspace number 4
    bindsym \$mod+5 workspace number 5
    bindsym \$mod+6 workspace number 6
    bindsym \$mod+7 workspace number 7
    bindsym \$mod+8 workspace number 8
    bindsym \$mod+9 workspace number 9
    bindsym \$mod+0 workspace number 10

    # Move focused container to workspace
    bindsym \$mod+Shift+1 move container to workspace number 1
    bindsym \$mod+Shift+2 move container to workspace number 2
    bindsym \$mod+Shift+3 move container to workspace number 3
    bindsym \$mod+Shift+4 move container to workspace number 4
    bindsym \$mod+Shift+5 move container to workspace number 5
    bindsym \$mod+Shift+6 move container to workspace number 6
    bindsym \$mod+Shift+7 move container to workspace number 7
    bindsym \$mod+Shift+8 move container to workspace number 8
    bindsym \$mod+Shift+9 move container to workspace number 9
    bindsym \$mod+Shift+0 move container to workspace number 10

# Layout stuff:
    # Split current focus.
    bindsym \$mod+p splith
    bindsym \$mod+o splitv

    # Switch the current container between different layout styles
    bindsym \$mod+Mod2+l layout stacking
    bindsym \$mod+Shift+l layout tabbed
    bindsym \$mod+Mod1+l layout toggle split

    # Make the current focus fullscreen
    bindsym \$mod+Return fullscreen

    # Toggle the current focus between tiling and floating mode
    bindsym \$mod+Shift+space floating toggle

    # Swap focus between the tiling area and the floating area
    bindsym \$mod+space focus mode_toggle

    # Move focus to the parent container
    bindsym \$mod+Mod1+space focus parent

# Scratchpad:
    # Sway has a "scratchpad", which is a bag of holding for windows.
    # You can send windows there and get them back later.

    # Move the currently focused window to the scratchpad
    bindsym \$mod+Shift+minus move scratchpad

    # Show the next scratchpad window or hide the focused scratchpad window.
    # If there are multiple scratchpad windows, this command cycles through them.
    bindsym \$mod+minus scratchpad show

# Audio
    # Output
    # bindsym XF86AudioMute exec pactl set-sink-mute @DEFAULT_SINK@ toggle
    # bindsym XF86AudioRaiseVolume exec pactl set-sink-volume @DEFAULT_SINK@ +5%
    # bindsym XF86AudioLowerVolume exec pactl set-sink-volume @DEFAULT_SINK@ -5%

    # Input
    # bindsym Shift+XF86AudioMute exec pactl set-source-mute @DEFAULT_SOURCE@ toggle
    # bindsym XF86AudioMicMute exec pactl set-source-mute @DEFAULT_SOURCE@ toggle
    # bindsym Shift+XF86AudioRaiseVolume exec pactl set-source-volume @DEFAULT_SOURCE@ +5%
    # bindsym Shift+XF86AudioLowerVolume exec pactl set-source-volume @DEFAULT_SOURCE@ -5%
# Resizing containers:
mode "resize" {
    # left will shrink the containers width
    # right will grow the containers width
    # up will shrink the containers height
    # down will grow the containers height
    bindsym Left resize shrink width 10px
    bindsym Down resize grow height 10px
    bindsym Up resize shrink height 10px
    bindsym Right resize grow width 10px

    # Return to default mode
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym \$mod+r mode "resize"

# Status Bar:
bar {
    position top
}

# Floating Apps:
# for_window [app_id="abc"] floating enable
# for_window [title="def"] floating enable
# for_window [class="ghi"] floating enable

# Idle Inhibition
# for_window [title="abc"] inhibit_idle focus
# for_window [class="def"] inhibit_idle fullscreen

# Enable XWayland support
# xwayland enable

include /etc/sway/config.d/*
EOL

# Bring up the default sway config to edit preferred applications, keyboard layout and display settings.
nano "$sway_conf_dir/config"

# Copy the default sway config for the root user.
mkdir -p "/root/.config/sway"
cp "$sway_conf_dir/config" "/root/.config/sway/config"

# Remove the script, now that we've completed execution.
rm "${BASH_SOURCE[0]}"
