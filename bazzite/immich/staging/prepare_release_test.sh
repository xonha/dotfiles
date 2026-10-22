#!/usr/bin/env bash
set -euo pipefail

test_dir=/var/home/henrique/immich-staging-v334
backup_dir=/var/home/henrique/immich-backups/pre-fork-2026-10-21
media_dir="$test_dir/media"
database_dir="$test_dir/postgres"
environment_file="$test_dir/.env"

[[ -d "$backup_dir/media" && -f "$backup_dir/immich-db.dump" ]] || {
  printf 'Missing verified pre-fork backup\n' >&2
  exit 1
}
[[ ! -e "$test_dir" ]] || {
  printf 'Release test directory already exists; refusing to overwrite it\n' >&2
  exit 1
}
[[ "$(findmnt -T "$backup_dir/media" -n -o FSTYPE)" == btrfs ]] || {
  printf 'Backup media must be on Btrfs for a reflink clone\n' >&2
  exit 1
}

install -d -m 0700 "$test_dir"
cp -a --reflink=always "$backup_dir/media" "$media_dir"
install -d -m 0700 "$database_dir"

password="$(openssl rand -hex 24)"
umask 077
{
  printf 'UPLOAD_LOCATION=%s\n' "$media_dir"
  printf 'DB_DATA_LOCATION=%s\n' "$database_dir"
  printf 'DB_USERNAME=postgres\n'
  printf 'DB_DATABASE_NAME=immich\n'
  printf 'DB_PASSWORD=%s\n' "$password"
  printf 'IMMICH_SERVER_CONTAINER=immich_staging_v334_server\n'
  printf 'IMMICH_ML_CONTAINER=immich_staging_v334_machine_learning\n'
  printf 'IMMICH_REDIS_CONTAINER=immich_staging_v334_redis\n'
  printf 'IMMICH_DB_CONTAINER=immich_staging_v334_postgres\n'
  printf 'IMMICH_HTTP_PORT=2285\n'
  printf 'IMMICH_SERVER_IMAGE=ghcr.io/immich-app/immich-server:v3.3.4\n'
  printf 'IMMICH_ML_IMAGE=ghcr.io/immich-app/immich-machine-learning:v3.3.4\n'
} > "$environment_file"
printf 'Prepared isolated v3.3.4 test in %s\n' "$test_dir"
