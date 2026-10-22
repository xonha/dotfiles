#!/usr/bin/env bash
set -euo pipefail

staging_dir=/var/home/henrique/immich-staging
backup_dir=/var/home/henrique/immich-backups/pre-fork-2026-10-21
media_dir="$staging_dir/media"
database_dir="$staging_dir/postgres"
environment_file="$staging_dir/.env"

[[ -d "$media_dir" && -f "$backup_dir/immich-db.dump" ]] || {
  printf 'Missing isolated media copy or database dump\n' >&2
  exit 1
}
[[ "$(realpath "$media_dir")" != /run/media/system/hd/immich/library &&
   "$(realpath "$media_dir")" != "$backup_dir/media" ]] || {
  printf 'Refusing to use production or backup media directly\n' >&2
  exit 1
}
[[ ! -e "$environment_file" ]] || {
  printf 'Staging .env already exists; refusing to overwrite it\n' >&2
  exit 1
}

install -d -m 0700 "$staging_dir" "$database_dir"
password="$(openssl rand -hex 24)"
umask 077
{
  printf 'UPLOAD_LOCATION=%s\n' "$media_dir"
  printf 'DB_DATA_LOCATION=%s\n' "$database_dir"
  printf 'DB_USERNAME=postgres\n'
  printf 'DB_DATABASE_NAME=immich\n'
  printf 'DB_PASSWORD=%s\n' "$password"
  printf 'IMMICH_VERSION=v3.3.1\n'
  printf 'IMMICH_SERVER_IMAGE=ghcr.io/immich-app/immich-server:v3.3.1\n'
} > "$environment_file"
printf 'Created isolated staging configuration in %s\n' "$environment_file"
