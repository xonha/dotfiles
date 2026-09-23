#!/usr/bin/env bash
# Install or update lazypodman from its latest GitHub release.
# Works piped from curl on a fresh machine: needs only bash, curl, tar, sha256sum.

set -Eeuo pipefail

repo="lil5/lazypodman"
bin_dir="${DIR:-$HOME/.local/bin}"

case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  armv7*) arch=armv7 ;;
  armv6*) arch=armv6 ;;
  i386 | i686) arch=386 ;;
  *)
    echo "update-lazypodman: unsupported architecture $(uname -m)" >&2
    exit 1
    ;;
esac

# /releases/latest redirects to /releases/tag/<tag>; avoids the rate-limited API.
tag=$(curl --fail --silent --show-error --head --output /dev/null \
  --write-out '%{redirect_url}' "https://github.com/$repo/releases/latest")
tag=${tag##*/}
if [[ -z "$tag" ]]; then
  echo "update-lazypodman: could not resolve latest release" >&2
  exit 1
fi
version=${tag#v}

if [[ -x "$bin_dir/lazypodman" ]] &&
  "$bin_dir/lazypodman" --version 2>/dev/null | grep -Fqx "Version: $version"; then
  echo "lazypodman $version already installed"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

file="lazypodman_${version}_linux_${arch}.tar.gz"
base="https://github.com/$repo/releases/download/$tag"

curl --fail --location --silent --show-error --retry 3 --output "$tmp/$file" "$base/$file"
curl --fail --location --silent --show-error --retry 3 \
  --output "$tmp/checksums.txt" "$base/lazypodman_${version}_checksums.txt"

(cd "$tmp" && grep " $file\$" checksums.txt | sha256sum --check --quiet)

tar -xzf "$tmp/$file" -C "$tmp" lazypodman
install -Dm755 "$tmp/lazypodman" "$bin_dir/lazypodman"

echo "Installed lazypodman $version in $bin_dir"
case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) echo "Note: $bin_dir is not in PATH" >&2 ;;
esac
