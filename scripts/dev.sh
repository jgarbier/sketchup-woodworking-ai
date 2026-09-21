#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"
exec "$repo_root/node_modules/node/bin/node" "$repo_root/dist/index.js"
