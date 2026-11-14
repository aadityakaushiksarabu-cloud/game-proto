#!/bin/bash
# Compile and launch Lunar Hold. A local proxy forces IPv4 to NASA CCMC DONKI
# because the IPv6 route to ccmc.gsfc.nasa.gov stalls from this machine.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
RT="/home/aaditya/.local/share/GameMakerStudio2-Beta/Cache/runtimes/runtime-2026.100.0.1133"
IGOR="$RT/bin/igor/linux/x64/Igor"
PT="/opt/GameMaker-Beta/x86_64/packages/gm-tools/project-tool-linux-x64/ProjectTool"
USERDIR="/home/aaditya/.config/GameMakerStudio2-Beta"
CACHE="/tmp/lunar-hold-cache"
TEMP="/tmp/lunar-hold-temp"
OUT="/tmp/lunar-hold-out"
mkdir -p "$CACHE" "$TEMP" "$OUT"

if ! ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ':8771$'; then
  python3 "$ROOT/donki_proxy.py" >/tmp/lunar-hold-donki.log 2>&1 &
  echo $! >/tmp/lunar-hold-donki.pid
  echo "DONKI proxy on 127.0.0.1:8771"
fi

cd "$OUT"
exec "$IGOR" \
  --runtime=VM \
  -j=8 \
  --ic \
  --user="$USERDIR" \
  --project="$ROOT/Lunar Hold.yyp" \
  --runtimePath="$RT" \
  --cache="$CACHE" \
  --temp="$TEMP" \
  --projectool="$PT" \
  linux Run
