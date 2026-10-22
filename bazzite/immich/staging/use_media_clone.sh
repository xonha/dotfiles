#!/usr/bin/env bash
set -euo pipefail

environment_file=/var/home/henrique/immich-staging/.env
backup_media=/var/home/henrique/immich-backups/pre-fork-2026-10-21/media
staging_media=/var/home/henrique/immich-staging/media

[[ -f "$environment_file" && -d "$staging_media" ]] || {
  printf 'Missing staging configuration or media clone\n' >&2
  exit 1
}
[[ "$(realpath "$staging_media")" != "$(realpath "$backup_media")" &&
   "$(realpath "$staging_media")" != /run/media/system/hd/immich/library ]] || {
  printf 'Staging media must be separate from backup and production\n' >&2
  exit 1
}
grep -Fxq "UPLOAD_LOCATION=$backup_media" "$environment_file" || {
  printf 'Unexpected UPLOAD_LOCATION; refusing to change .env\n' >&2
  exit 1
}

sed -i "s#^UPLOAD_LOCATION=$backup_media\$#UPLOAD_LOCATION=$staging_media#" "$environment_file"
chmod 600 "$environment_file"
printf 'Staging now points to the writable media clone\n'
