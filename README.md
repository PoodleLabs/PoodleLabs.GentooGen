# PoodleLabs.GentooGen

A set of scripts for raising and configuring a Gentoo environment on fully encrypted BTRFS with a feature-rich console environment, and optional Sway/Wayland graphical environment. The hardened OpenRC profile is used as a base, but these scripts use a heavily modified set of Portage flags.

The goal is not to provide a one-size-fits-all envrionment, nor is it to make installing Gentoo as easy as possible. The entire point of Gentoo is configuring an environment to your specific needs. Instead, these scripts may be used as a jumping off point for repeatably installing and configuring your own Gentoo environments.

## Networking
The network manager installed on the system is `NetworkManager`. You can use `nmtui` or `nmcli` to configure the network. You may want to install `nm-applet` if you install Sway, but note the additional dependencies it pulls in are significant.

## Console Environment

The console environment (built atop `fbterm`) includes standard utilities included in basically all Linux distros, such as Git, SSH and GNUPG.

The notable additions are:
- `termux`: A multiplexing terminal for window and workspace-like behaviour.
- `neovim`: A highly extensible terminal text editor based on VIM.
- `ranger`: A terminal file explorer with VIM-style bindings.
- `elinks`: A terminal web browser with VIM-style bindings.
- `ffmpeg`: Image and video processing CLI tools.
- `fbset`: Framebuffer management cli.
- `mplayer`: A terminal video player.
- `cmus`: A terminal music player.

Many of the above programs are highly configurable. No non-default configuration is included.

In addition, the following permanent scripts are included:
- `make-user` which takes creates a user in the `USERNAME` environment variable, adds it to all relevant groups, and copies any existing default Sway config.
- `get-fb-geometry` which returns `{framebufferwidth} {framebufferheight}`, eg `1920 1080`.
- `scale-to-fit` which takes four numbers: source x, source y, destination x, and destination y, and outputs an x and y value scaled to fit source to the destination as best as possible while preserving the source aspect ratio; for example, `scale-to-fit 1920 800 1920 1080` returns `1920 800` and `scale-to-fit 600 800 1920 1080` returns `810 1080`.
- `scale-to-fill` which takes four numbers: source x, source y, destination x, and destination y, and outputs and x and y value scale to fill the destination with the source as best as possible while preserving the source aspect ratio; for example, `scale-to-fill 1920 800 1920 1080` returns `2592 1080` and `scale-to-fill 600 800 1920 1080` returns `1920 2560`. Note: this cannot be directly used for displaying an image as mplayer requires output scale values to be <= the size of the framebuffer.
- `display-image` which takes a single positional filepath to an image, and renders it to the framebuffer via ffmpeg's slideshow generation and mplayer.
- `play-video` which takes a single positional filepath to a video, and renders it to the framebuffer via mplayer, automatically setting the scaling parameters to fill the screen as closely as possible while preserving the source aspect ratio.

At the expense of pulling in QT, `qutebrowser` (a webkit-based web browser with VIM style bindings) should be able to run in the framebuffer. Like the other framebuffer-based programs, however, it will not play nicely with termux's windows/workspaces. If there is interest, I'll throw together a script.

The `step-3-first-boot` and `step-4-optional-sway` scripts are also added to `/bin/`, but delete themselves upon completion. If you do not wish to install Sway, you may want to remove the latter manually.

## SwayWM

The SwayWM installation script is fairly minimal, with the extra included packages being:
- `sway`: The window manager itself.
- `swaylock`: A screen locker you can launch with `WIN + L` by default. Wake up your computer (if it fell asleep) and start typing to unlock. Press `ESC` to clear a partially-typed password.
- `foot`: The default Sway terminal. Launch with `WIN + T` by default.
- `grim` and `slurp`: Used to take screenshots. `WIN + S` by default, then region selection. The screenshot is written to the clipboard.

There are non-trivial additions to the Sway package's default configuration; you may wish to remove these changes and use the original base config as a base.

## Usage

1. Read and modify the scripts in this repository as you see fit.
2. Download and format a Gentoo minimal live USB.
3. Download this repo and copy to a USB stick.
4. Boot into the Gentoo minimal live USB (with both USBs inserted).
5. Select your keyboard layout.
6. `lsblk` and find the device holding this repository (alternately you may `git clone` it).
7. `mkdir /mnt/scripts`.
8. `mount /dev/[repo device] /mnt/scripts`.
9. `cd /mnt/scripts`.
10. `nano example.launcher.sh` and modify the values inside to suit your needs.
11. `source example.launcher.sh`.
12. The script will install Gentoo, pausing at times for user input. This comes in multiple forms, from cryptsetup key prompts, to TUIs, to `nano` being launched so you can edit a configuration file. Read the output when you are prompted for input; it should be clear what is needed of you. When the kernel menuconfig is presented, at a minimum, you should set 'btrfs' inside 'filesystems' to be built in (`[*]`). Eventually, you will be prompted to reboot. Remove the USB stick, and type `reboot`.
13. Boot into your new gentoo system, and log in as root.
14. `step-3-first-boot`.
15. If you want Sway WM: `step-4-optional-sway-wm`. You will be prompted to modify the default Sway configuration file set by the next step's `make-user` script; the top of the file includes keyboard layout, display configuration, and default applications associated with various keyboard shortcuts. The default programs include my own graphical environment preferences which are not installed by the script.
16. Run `USERNAME="[insert your desired username] make-user`; you can repeat this with different values for `USERNAME` to create multiple users. Note: they are automatically added to the `wheel` group, allowing them to `doas -u root`; non-admin users should be removed from this group.
17. Reboot one more time, and enjoy.
