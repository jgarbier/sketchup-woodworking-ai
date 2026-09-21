#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$repo_root/dist"
archive="$repo_root/dist/woodworking-ai-0.1.0.rbz"
staging=$(mktemp -d "${TMPDIR:-/tmp}/woodworking-package.XXXXXX")
trap 'rm -rf "$staging"' EXIT HUP INT TERM
cd "$repo_root/sketchup-extension"
/usr/bin/zip -q -r "$staging/extension.rbz" woodworking_ai.rb woodworking_ai -x '*.DS_Store'
mv "$staging/extension.rbz" "$archive"
echo "$archive"
