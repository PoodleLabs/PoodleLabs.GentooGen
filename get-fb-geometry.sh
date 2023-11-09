#!/bin/bash
set -e

read -ra garr <<< $(fbset -s | grep geometry)
x=${garr[1]}
y=${garr[2]}
echo "$x $y"
