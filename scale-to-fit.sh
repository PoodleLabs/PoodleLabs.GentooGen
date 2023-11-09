#!/bin/bash
set -e

sx=$1
sy=$2

dx=$3
dy=$4

ar=$(bc -l <<< "$sx/$sy")
rx=$(bc -l <<< "$dx/$sx")
ry=$(bc -l <<< "$dy/$sy")
if [ $(bc -l <<< "$rx > $ry") -eq 1 ]
then
    # Fit to height.
    dx=$(bc -l <<< "$dy*$ar")
else
    # Fit to width.
    dy=$(bc -l <<< "$dx/$ar")
fi

echo "$(printf %.0f $dx) $(printf %.0f $dy)"
