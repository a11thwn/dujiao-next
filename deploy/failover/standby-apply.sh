#!/usr/bin/env bash
set -euo pipefail

incoming=/var/lib/usghsync/incoming
app_dir=/opt/usgiftcardhub
state_dir=/var/lib/usgiftcardhub-replica
state_file="$state_dir/applied-snapshot"
active_marker=/etc/usgiftcardhub-failover-active
lock_file=/run/lock/usgiftcardhub-replica-apply.lock

[[ $EUID -eq 0 ]] || { echo "must run as root" >&2; exit 1; }
[[ "$incoming" == /var/lib/usghsync/incoming ]] || exit 1
[[ "$app_dir" == /opt/usgiftcardhub ]] || exit 1
[[ -f "$active_marker" ]] && { echo "standby is active; replica apply skipped"; exit 0; }
[[ -f "$incoming/READY" ]] || { echo "no complete incoming snapshot"; exit 0; }

mkdir -p "$(dirname "$lock_file")" "$state_dir"
exec 9>"$lock_file"
flock -n 9 || { echo "another apply run is active" >&2; exit 0; }

snapshot_id=$(<"$incoming/READY")
[[ "$snapshot_id" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || { echo "invalid snapshot id" >&2; exit 1; }
if [[ -f "$state_file" && $(<"$state_file") == "$snapshot_id" ]]; then
  echo "snapshot already applied: $snapshot_id"
  exit 0
fi

(
  cd "$incoming"
  sha256sum -c SHA256SUMS
)

if ! getent group usgiftcardhub >/dev/null; then
  groupadd --system usgiftcardhub
fi
if ! id usgiftcardhub >/dev/null 2>&1; then
  useradd --system --gid usgiftcardhub --home-dir "$app_dir" --shell /usr/sbin/nologin usgiftcardhub
fi

systemctl disable --now usgiftcardhub.service usgiftcardhub-worker.service >/dev/null 2>&1 || true
systemctl disable --now redis-server.service >/dev/null 2>&1 || true

install -d -o root -g usgiftcardhub -m 0750 "$app_dir"
install -d -o usgiftcardhub -g usgiftcardhub -m 0700 \
  "$app_dir/db" "$app_dir/uploads" "$app_dir/logs" "$app_dir/backups"

if [[ -f "$app_dir/db/dujiao.db" ]]; then
  cp -a "$app_dir/db/dujiao.db" "$app_dir/backups/replica-before-$snapshot_id.db"
  mapfile -d '' replica_backups < <(
    find "$app_dir/backups" -maxdepth 1 -type f -name 'replica-before-*.db' -print0 | sort -z
  )
  if (( ${#replica_backups[@]} > 16 )); then
    remove_count=$((${#replica_backups[@]} - 16))
    for ((index = 0; index < remove_count; index++)); do
      unlink "${replica_backups[$index]}"
    done
  fi
fi

install -o root -g usgiftcardhub -m 0750 "$incoming/app/usgiftcardhub-api" "$app_dir/usgiftcardhub-api"
install -o root -g usgiftcardhub -m 0750 "$incoming/app/usgiftcardhub" "$app_dir/usgiftcardhub"
install -o usgiftcardhub -g usgiftcardhub -m 0600 "$incoming/app/config.yml" "$app_dir/config.yml"
install -o usgiftcardhub -g usgiftcardhub -m 0600 "$incoming/app/db/dujiao.db" "$app_dir/db/dujiao.db"
rsync -a --delete "$incoming/app/uploads/" "$app_dir/uploads/"
chown -R usgiftcardhub:usgiftcardhub "$app_dir/uploads"

install -o root -g root -m 0644 "$incoming/systemd/usgiftcardhub.service" /etc/systemd/system/usgiftcardhub.service
install -o root -g root -m 0644 "$incoming/systemd/usgiftcardhub-worker.service" /etc/systemd/system/usgiftcardhub-worker.service
if [[ -d "$incoming/systemd/usgiftcardhub.service.d" ]]; then
  install -d -o root -g root -m 0755 /etc/systemd/system/usgiftcardhub.service.d
  rsync -a --delete "$incoming/systemd/usgiftcardhub.service.d/" /etc/systemd/system/usgiftcardhub.service.d/
fi
if [[ -d "$incoming/systemd/redis-server.service.d" ]]; then
  install -d -o root -g root -m 0755 /etc/systemd/system/redis-server.service.d
  rsync -a --delete "$incoming/systemd/redis-server.service.d/" /etc/systemd/system/redis-server.service.d/
fi

install -o root -g root -m 0644 "$incoming/redis/redis.conf" /etc/redis/redis.conf
install -d -o redis -g redis -m 0750 /var/lib/redis
install -o redis -g redis -m 0640 "$incoming/redis/dump.rdb" /var/lib/redis/dump.rdb

install -d -o tls-shunt-proxy -g tls-shunt-proxy -m 0700 \
  /etc/ssl/tls-shunt-proxy/certificates/acme-v02.api.letsencrypt.org-directory/usgiftcardhub.com \
  /etc/ssl/tls-shunt-proxy/acme/acme-v02.api.letsencrypt.org-directory/users/default
if [[ -d "$incoming/tls/certificates/usgiftcardhub.com" ]]; then
  rsync -a --delete "$incoming/tls/certificates/usgiftcardhub.com/" \
    /etc/ssl/tls-shunt-proxy/certificates/acme-v02.api.letsencrypt.org-directory/usgiftcardhub.com/
fi
if [[ -d "$incoming/tls/acme/default" ]]; then
  rsync -a --delete "$incoming/tls/acme/default/" \
    /etc/ssl/tls-shunt-proxy/acme/acme-v02.api.letsencrypt.org-directory/users/default/
fi
chown -R tls-shunt-proxy:tls-shunt-proxy /etc/ssl/tls-shunt-proxy
chmod -R go-rwx /etc/ssl/tls-shunt-proxy

systemctl daemon-reload

db_check=$(python3 - "$app_dir/db/dujiao.db" <<'PY'
import sqlite3
import sys

connection = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
print(connection.execute("PRAGMA quick_check").fetchone()[0])
PY
)
[[ "$db_check" == ok ]] || { echo "replica database check failed: $db_check" >&2; exit 1; }

printf '%s\n' "$snapshot_id" > "$state_file.tmp"
mv "$state_file.tmp" "$state_file"
chmod 0600 "$state_file"

echo "applied_snapshot=$snapshot_id"
echo "database_check=ok"
echo "standby_services=stopped"
