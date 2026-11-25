#!/usr/bin/env bash
# Exports the web build and zips it for itch: build/red-flash-web.zip.
#   tools/export_web.sh [path/to/godot]
# After the export, one patch to Godot 4.3's web audio (index.js): each time a
# sound plays it copied the sound's whole decoded buffer (the music: ~43 MB a
# play, and garbage for the browser to collect on every sound effect). The
# copy is never changed, so every play now shares the one buffer.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --export-release "Web" build/web/index.html
python3 - <<'PY'
p = "build/web/index.js"
s = open(p).read()
old = "getAudioBuffer(){return this._duplicateAudioBuffer()}"
assert s.count(old) == 1, "web audio patch: Godot's index.js changed, check tools/export_web.sh"
open(p, "w").write(s.replace(old, "getAudioBuffer(){return this._audioBuffer}"))
print("patched web audio: sounds share their buffer")
PY
# A crash log: the page keeps the last console errors and the game's beats
# (main.gd _crashlog_beat) in localStorage, so they survive the tab being
# killed; after a crash, open the game with ?crashlog=1 to see them.
python3 - <<'PY'
p = "build/web/index.html"
s = open(p).read()
script = open("tools/crashlog.js").read()
assert s.count("<head>") == 1, "crash log: no <head> in index.html"
open(p, "w").write(s.replace("<head>", "<head>\n<script>\n" + script + "\n</script>", 1))
print("added the crash log (?crashlog=1)")
PY
rm -f build/red-flash-web.zip
(cd build/web && zip -qr ../red-flash-web.zip .)
echo "build/red-flash-web.zip"
