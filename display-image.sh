#!/bin/bash
set -e

read -ra fbgeometry <<< $(get-fb-geometry)
fbx=${fbgeometry[0]}
fby=${fbgeometry[1]}

filename=$(basename "$1")
extension="${filename##*.}"
uuid=$(uuidgen)

tdir="/tmp/image-display/$uuid"
tvid="$tdir/v.mp4"

mkdir -p "$tdir"
cp -f "$1" "$tdir/img001.$extension"
cp -f "$1" "$tdir/img002.$extension"
ffmpeg -i "$tdir/img%03d.$extension" -framerate 0.00001 -vcodec copy "$tvid"

read -ra vgeometry <<< $(ffprobe -v error -select_streams v -show_entries stream=width,height -of "csv=p=0:s=' '" "$tvid")
vx=${vgeometry[0]}
vy=${vgeometry[1]}

read -ra sgeometry <<< $(scale-to-fit $vx $vy $fbx $fby)
sx=${sgeometry[0]}
sy=${sgeometry[1]}

mplayer -nosound -vo fbdev2 -loop 0 -framedrop -vf "scale=$sx:$sy" -fps 0.00001 -msglevel all=0 "$tvid"
rm -rf "$tdir"
