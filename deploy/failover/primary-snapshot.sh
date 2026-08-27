#!/usr/bin/env bash
set -euo pipefail

app_dir=/opt/usgiftcardhub
export_root=/var/lib/usgiftcardhub-replica
current_dir="$export_root/current"
previous_dir="$export_root/previous"
archive_dir="$export_root/archives"
target_file=/etc/usgiftcardhub-backup/targets
ssh_key=/root/.ssh/usgiftcardhub-replica-ed25519
backup_key=/root/.config/usgiftcardhub-backup/backup.key
lock_file=/run/lock/usgiftcardhub-replica.lock
local_archive_retention_minutes=2880

usage() {
  echo "usage: $0 [--snapshot] [--push] [--archive]" >&2
}

[[ $EUID -eq 0 ]] || { echo "must run as root" >&2; exit 1; }
[[ "$app_dir" == /opt/usgiftcardhub ]] || exit 1
[[ "$export_root" == /var/lib/usgiftcardhub-replica ]] || exit 1

do_snapshot=false
do_push=false
do_archive=false
if [[ $# -eq 0 ]]; then
  do_snapshot=true
  do_push=true
fi
for arg in "$@"; do
  case "$arg" in
    --snapshot) do_snapshot=true ;;
    --push) do_push=true ;;
    --archive) do_archive=true ;;
    *) usage; exit 2 ;;
  esac
done

mkdir -p "$(dirname "$lock_file")" "$export_root" "$archive_dir"
exec 9>"$lock_file"
flock -n 9 || { echo "another backup run is active" >&2; exit 0; }

snapshot_id=""

create_snapshot() {
  local staging db_check redis_keys
  staging=$(mktemp -d "$export_root/.snapshot.XXXXXX")
  trap '[[ -n ${staging:-} && -d ${staging:-} ]] && rm -rf -- "$staging"' EXIT
  snapshot_id=$(date -u +%Y%m%dT%H%M%SZ)

  install -d -m 0700 \
    "$staging/app/db" \
    "$staging/app/uploads" \
    "$staging/systemd" \
    "$staging/redis" \
    "$staging/tls/certificates" \
    "$staging/tls/acme"

  install -m 0750 "$app_dir/usgiftcardhub-api" "$staging/app/usgiftcardhub-api"
  install -m 0750 "$app_dir/usgiftcardhub" "$staging/app/usgiftcardhub"
  install -m 0600 "$app_dir/config.yml" "$staging/app/config.yml"
  if [[ -d "$app_dir/uploads" ]]; then
    rsync -a --delete "$app_dir/uploads/" "$staging/app/uploads/"
  fi

  python3 - "$app_dir/db/dujiao.db" "$staging/app/db/dujiao.db" <<'PY'
import sqlite3
import sys

source_path, destination_path = sys.argv[1:3]
source = sqlite3.connect(f"file:{source_path}?mode=ro", uri=True, timeout=30)
destination = sqlite3.connect(destination_path, timeout=30)
source.backup(destination)
destination.execute("PRAGMA journal_mode=DELETE")
destination.close()
source.close()

check = sqlite3.connect(f"file:{destination_path}?mode=ro", uri=True)
result = check.execute("PRAGMA quick_check").fetchone()[0]
check.close()
if result != "ok":
    raise SystemExit(f"sqlite quick_check failed: {result}")
PY
  chmod 0600 "$staging/app/db/dujiao.db"

  redis-cli --rdb "$staging/redis/dump.rdb" >/dev/null
  chmod 0600 "$staging/redis/dump.rdb"
  install -m 0644 /etc/redis/redis.conf "$staging/redis/redis.conf"

  install -m 0644 /etc/systemd/system/usgiftcardhub.service "$staging/systemd/usgiftcardhub.service"
  install -m 0644 /etc/systemd/system/usgiftcardhub-worker.service "$staging/systemd/usgiftcardhub-worker.service"
  if [[ -d /etc/systemd/system/usgiftcardhub.service.d ]]; then
    rsync -a /etc/systemd/system/usgiftcardhub.service.d/ "$staging/systemd/usgiftcardhub.service.d/"
  fi
  if [[ -d /etc/systemd/system/redis-server.service.d ]]; then
    rsync -a /etc/systemd/system/redis-server.service.d/ "$staging/systemd/redis-server.service.d/"
  fi

  if [[ -d /etc/ssl/tls-shunt-proxy/certificates/acme-v02.api.letsencrypt.org-directory/usgiftcardhub.com ]]; then
    rsync -a \
      /etc/ssl/tls-shunt-proxy/certificates/acme-v02.api.letsencrypt.org-directory/usgiftcardhub.com/ \
      "$staging/tls/certificates/usgiftcardhub.com/"
  fi
  if [[ -d /etc/ssl/tls-shunt-proxy/acme/acme-v02.api.letsencrypt.org-directory/users/default ]]; then
    rsync -a \
      /etc/ssl/tls-shunt-proxy/acme/acme-v02.api.letsencrypt.org-directory/users/default/ \
      "$staging/tls/acme/default/"
  fi

  db_check=$(python3 - "$staging/app/db/dujiao.db" <<'PY'
import json
import sqlite3
import sys

connection = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
tables = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")}
counts = {}
for table in ("admins", "products", "orders", "card_secrets", "payments", "settings"):
    if table in tables:
        counts[table] = connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
print(json.dumps(counts, sort_keys=True, separators=(",", ":")))
PY
  )
  redis_keys=$(redis-cli --raw INFO keyspace | awk -F'[:,=]' '/^db[0-9]+:/ {sum += $3} END {print sum + 0}')

  {
    printf 'snapshot_id=%s\n' "$snapshot_id"
    printf 'created_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'source_host=%s\n' "$(hostname)"
    printf 'database_counts=%s\n' "$db_check"
    printf 'redis_keys=%s\n' "$redis_keys"
  } > "$staging/MANIFEST"

  (
    cd "$staging"
    find . -type f ! -name SHA256SUMS ! -name READY -print0 \
      | sort -z \
      | xargs -0 sha256sum > SHA256SUMS
  )
  printf '%s\n' "$snapshot_id" > "$staging/READY"

  rm -rf -- "$previous_dir"
  if [[ -d "$current_dir" ]]; then
    mv "$current_dir" "$previous_dir"
  fi
  mv "$staging" "$current_dir"
  staging=""
  trap - EXIT
  echo "snapshot_id=$snapshot_id"
}

push_snapshot() {
  [[ -f "$current_dir/READY" ]] || { echo "current snapshot is missing" >&2; exit 1; }
  [[ -f "$target_file" ]] || { echo "target file is missing: $target_file" >&2; exit 1; }
  [[ -f "$ssh_key" ]] || { echo "replica SSH key is missing: $ssh_key" >&2; exit 1; }

  local host port attempt pushed line
  local -a targets
  mapfile -t targets < "$target_file"
  for line in "${targets[@]}"; do
    read -r host port <<< "$line"
    [[ -n "${host:-}" && ${host:0:1} != "#" ]] || continue
    [[ "$port" =~ ^[0-9]+$ ]] || { echo "invalid target port for $host" >&2; exit 1; }
    pushed=false
    for attempt in 1 2 3; do
      if ssh -n -i "$ssh_key" -p "$port" \
          -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=yes \
          "$host" 'rm -f /var/lib/usghsync/incoming/READY' \
        && rsync -az --delete --delay-updates --exclude READY \
          -e "ssh -i $ssh_key -p $port -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=yes" \
          "$current_dir/" "$host:/var/lib/usghsync/incoming/" \
        && rsync -az \
          -e "ssh -i $ssh_key -p $port -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=yes" \
          "$current_dir/READY" "$host:/var/lib/usghsync/incoming/READY"; then
        pushed=true
        break
      fi
      sleep $((attempt * 3))
    done
    $pushed || { echo "replica push failed after retries: $host" >&2; exit 1; }
    echo "replica_pushed=$host"
  done
}

create_archive() {
  [[ -f "$current_dir/READY" ]] || create_snapshot
  [[ -s "$backup_key" ]] || { echo "backup encryption key is missing: $backup_key" >&2; exit 1; }
  snapshot_id=$(<"$current_dir/READY")
  [[ "$snapshot_id" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "invalid snapshot id" >&2; exit 1; }

  local archive temp_archive archive_listing
  archive="$archive_dir/usgiftcardhub-full-$snapshot_id.tar.gz.enc"
  temp_archive="$archive.tmp"
  tar -C "$current_dir" -czf - . \
    | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 200000 -md sha256 \
        -pass file:"$backup_key" -out "$temp_archive"
  mv "$temp_archive" "$archive"
  chmod 0600 "$archive"
  archive_listing=$(mktemp "$archive_dir/.archive-list.XXXXXX")
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -md sha256 \
      -pass file:"$backup_key" -in "$archive" \
    | tar -tzf - > "$archive_listing"
  grep -Fxq './app/config.yml' "$archive_listing"
  grep -Fxq './app/db/dujiao.db' "$archive_listing"
  grep -Fxq './app/usgiftcardhub-api' "$archive_listing"
  grep -Fxq './app/usgiftcardhub' "$archive_listing"
  grep -Fxq './redis/dump.rdb' "$archive_listing"
  grep -Fxq './systemd/usgiftcardhub.service' "$archive_listing"
  grep -Fxq './systemd/usgiftcardhub-worker.service' "$archive_listing"
  grep -Fxq './tls/certificates/usgiftcardhub.com/usgiftcardhub.com.crt' "$archive_listing"
  grep -Fxq './tls/certificates/usgiftcardhub.com/usgiftcardhub.com.key' "$archive_listing"
  rm -f "$archive_listing"
  (cd "$archive_dir" && sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256")
  cp "$current_dir/MANIFEST" "$archive.manifest"
  chmod 0600 "$archive.manifest" "$archive.sha256"
  # Hourly archives are retained locally for 48 hours. Google Drive keeps the
  # uploaded history, while this bound prevents 14 days of hourly archives from
  # exhausting the production filesystem.
  find "$archive_dir" -maxdepth 1 -type f \
    -name 'usgiftcardhub-full-*' \
    -mmin "+$local_archive_retention_minutes" -delete
  echo "archive=$archive"
}

if $do_snapshot; then
  create_snapshot
fi
if $do_push; then
  push_snapshot
fi
if $do_archive; then
  create_archive
fi
