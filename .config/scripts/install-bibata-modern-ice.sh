#!/usr/bin/env bash
set -euo pipefail

# Keep the cursor reproducible without committing generated cursor binaries.
bibata_version="2.0.7"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
icons_dir="$repo_root/.local/share/icons"
archive="$(mktemp --suffix=.tar.xz)"

cleanup() {
  rm -f "$archive"
}
trap cleanup EXIT

mkdir -p "$icons_dir"
curl --fail --location --retry 3 \
  --output "$archive" \
  "https://github.com/ful1e5/Bibata_Cursor/releases/download/v${bibata_version}/Bibata.tar.xz"

tar -xJf "$archive" -C "$icons_dir" Bibata-Modern-Ice

echo "Installed Bibata-Modern-Ice in $icons_dir"
