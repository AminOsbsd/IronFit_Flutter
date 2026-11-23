#!/usr/bin/env bash
# Contact sheet of still frames: scripts/sheet.sh <composition> <outfile> <cols> <width> frame frame ...
comp=$1; out=$2; cols=$3; w=$4; shift 4
rm -rf out/stills; mkdir -p out/stills; [ -d out/bundle ] && [ -z "$REUSE" ] && rm -rf out/bundle
[ -d out/bundle ] || npx remotion bundle src/index.ts --out-dir out/bundle --log=error >/dev/null
i=0; for f in "$@"; do n=$(printf %02d $i); npx remotion still out/bundle "$comp" "out/stills/$n.png" --frame=$f --scale=0.5 --log=error >/dev/null & i=$((i+1)); [ $((i%4)) = 0 ] && wait; done; wait
ffmpeg -y -v error -framerate 1 -i out/stills/%02d.png -vf "scale=$w:-1,tile=${cols}x$(( (i+cols-1)/cols )):padding=8:color=gray" -frames:v 1 "$out"
