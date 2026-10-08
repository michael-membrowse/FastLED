#!/usr/bin/env bash
# Export the linker script fbuild used for a board's Blink build to a stable path.
#
# FastLED builds every board through fbuild, which downloads the toolchain and
# framework into a cache whose directory names include content hashes. The
# memory-region linker script lives inside that cache, so its absolute path
# changes whenever a platform pin moves. MemBrowse needs a stable path to parse
# memory regions, so after `bash compile <board> --examples Blink` this script
# reads the build_info JSON fbuild wrote, locates the exact script that build
# used, and copies it to `.build/fbuild/<board>/membrowse.ld`.
#
# Usage: bash .github/membrowse/export-linker-script.sh <board> [example]
set -euo pipefail

board="${1:?usage: $0 <board> [example]}"
example="${2:-Blink}"
build_dir=".build/fbuild/$board"
info="$build_dir/build_info_$example.json"
dest="$build_dir/membrowse.ld"

if [ ! -f "$info" ]; then
  echo "export-linker-script: $info not found; run 'bash compile $board --examples $example' first" >&2
  exit 1
fi

case "$board" in
  esp32*)
    # Arduino-ESP32 ships the preprocessed ESP-IDF memory map per chip under
    # tools/esp32-arduino-libs/<chip>/ld/memory.ld. The include paths in
    # build_info point at that same <chip> directory.
    libs="$(grep -oE '/[^"]*/tools/esp32-arduino-libs/'"$board"'\b' "$info" | head -n 1 || true)"
    src="$libs/ld/memory.ld"
    ;;
  teensy41)
    core="$(grep -oE '/[^"]*/cores/teensy4\b' "$info" | head -n 1 || true)"
    src="$core/imxrt1062_t41.ld"
    ;;
  teensy40)
    core="$(grep -oE '/[^"]*/cores/teensy4\b' "$info" | head -n 1 || true)"
    src="$core/imxrt1062.ld"
    ;;
  uno)
    # avr-gcc links against its built-in avr5.x script. Its region sizes are
    # placeholders; membrowse-targets.json overrides them via linker_vars.
    gcc="$(grep -oE '/[^"]*/avr/bin/avr-gcc\b' "$info" | head -n 1 || true)"
    src="$(dirname "$(dirname "$gcc")")/avr/lib/ldscripts/avr5.x"
    ;;
  *)
    echo "export-linker-script: no linker script rule for board '$board'" >&2
    exit 1
    ;;
esac

if [ ! -f "$src" ]; then
  echo "export-linker-script: linker script not found at '$src' (derived from $info)" >&2
  exit 1
fi

cp "$src" "$dest"
echo "export-linker-script: $src -> $dest"
