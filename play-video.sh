#!/bin/bash
set -e

read -ra fbgeometry <<< $(get-fb-geometry)
fbx=${fbgeometry[0]}
fby=${fbgeometry[1]}

read -ra vgeometry <<< $(ffprobe -v error -select_streams v -show_entries stream=width,height -of "csv=p=0:s=' '" "$1")
vx=${vgeometry[0]}
vy=${vgeometry[1]}

read -ra sgeometry <<< $(scale-to-fit $vx $vy $fbx $fby)
sx=${sgeometry[0]}
sy=${sgeometry[1]}

mplayer -vo fbdev2 -framedrop -vf "scale=$sx:$sy" -msglevel all=0 "$1"
