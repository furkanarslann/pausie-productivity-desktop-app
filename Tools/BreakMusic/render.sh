#!/bin/zsh
# Rebuilds Pausie's break-over music (Pausie/Resources/Sounds/*.m4a) from compose.swift.
# Needs Xcode's swiftc and ffmpeg (`brew install ffmpeg`). Each track is normalized to -18 LUFS with a
# -3 dB true peak (two-pass loudnorm, like the earlier bundled music) and encoded as AAC at 128 kbps.
set -euo pipefail

here=${0:A:h}
out=${1:-$here/../../Pausie/Resources/Sounds}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

swiftc -O "$here/compose.swift" -o "$work/compose"
"$work/compose" "$work"

for wav in "$work"/*.wav; do
  name=${wav:t:r}
  measured=$(ffmpeg -hide_banner -nostats -i "$wav" -af loudnorm=I=-18:TP=-3:LRA=11:print_format=json -f null - 2>&1 \
    | sed -n '/^{/,/^}/p')
  read -r input_i input_tp input_lra input_thresh offset <<<"$(print -r -- "$measured" | python3 -c '
import json, sys
m = json.load(sys.stdin)
print(m["input_i"], m["input_tp"], m["input_lra"], m["input_thresh"], m["target_offset"])')"
  ffmpeg -hide_banner -loglevel error -y -i "$wav" \
    -af "loudnorm=I=-18:TP=-3:LRA=11:measured_I=${input_i}:measured_TP=${input_tp}:measured_LRA=${input_lra}:measured_thresh=${input_thresh}:offset=${offset}:linear=true" \
    -ar 44100 -c:a aac -b:a 128k "$out/$name.m4a"
  echo "Wrote $out/$name.m4a"
done
