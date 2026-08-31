#!/usr/bin/env bash
set -euo pipefail

validate_deployment_id() {
  local value=$1
  [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]
}

acquire_install_lock() {
  local lock_path=$1

  if [[ "$lock_path" != /* || "$lock_path" == */../* || "$lock_path" == */.. || "$lock_path" == */./* || "$lock_path" == */. ]]; then
    echo "install lock path must be absolute and normalized" >&2
    return 1
  fi
  if [[ -L "$lock_path" ]]; then
    echo "refusing symlink install lock: $lock_path" >&2
    return 1
  fi

  mkdir -p "$(dirname "$lock_path")"
  exec 9>>"$lock_path"
  if ! flock -n 9; then
    echo "another USGiftCardHub installation is already running" >&2
    return 1
  fi
}

assert_fresh_install_target() {
  local existing_path
  local -a existing_paths=()

  for existing_path in "$@"; do
    if [[ "$existing_path" != /* || "$existing_path" == */../* || "$existing_path" == */.. || "$existing_path" == */./* || "$existing_path" == */. ]]; then
      echo "managed install paths must be absolute and normalized: $existing_path" >&2
      return 1
    fi
    if [[ -e "$existing_path" || -L "$existing_path" ]]; then
      existing_paths+=("$existing_path")
    fi
  done

  if (( ${#existing_paths[@]} > 0 )); then
    printf 'refusing to run the fresh-install script over an existing installation:\n' >&2
    printf '  %s\n' "${existing_paths[@]}" >&2
    printf 'use a reviewed upgrade procedure that preserves config.yml, encryption keys, and the live database\n' >&2
    return 1
  fi
}

if [[ ${USGIFTCARDHUB_INSTALL_TESTING:-0} == 1 ]]; then
  return 0 2>/dev/null || exit 0
fi

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <staging-directory> <deployment-id>  # fresh installs only" >&2
  exit 2
fi

staging_dir=$1
deployment_id=$2
install_dir=/opt/usgiftcardhub
service_name=usgiftcardhub
worker_service_name=usgiftcardhub-worker
service_user=usgiftcardhub
service_unit_file=/etc/systemd/system/usgiftcardhub.service
worker_service_unit_file=/etc/systemd/system/usgiftcardhub-worker.service
credential_file=/root/usgiftcardhub-admin-credentials.txt
failover_ready_file=/var/lib/usgiftcardhub-replica/current/READY
install_lock_file=/run/lock/usgiftcardhub-install.lock

if ! validate_deployment_id "$deployment_id"; then
  echo "deployment-id must match [A-Za-z0-9][A-Za-z0-9._-]{0,63}" >&2
  exit 2
fi

acquire_install_lock "$install_lock_file"

for required_file in usgiftcardhub dujiao.db config.yml.template usgiftcardhub.service; do
  test -f "$staging_dir/$required_file"
done

assert_fresh_install_target \
  "$install_dir/usgiftcardhub" \
  "$install_dir/usgiftcardhub-api" \
  "$install_dir/config.yml" \
  "$install_dir/db/dujiao.db" \
  "$service_unit_file" \
  "$worker_service_unit_file" \
  "$credential_file" \
  "$failover_ready_file"

for existing_service in "$service_name" "$worker_service_name"; do
  if systemctl is-active --quiet "$existing_service.service" 2>/dev/null; then
    echo "refusing to replace active service: $existing_service.service" >&2
    exit 1
  fi
done

if ! getent group "$service_user" >/dev/null; then
  groupadd --system "$service_user"
fi
if ! id "$service_user" >/dev/null 2>&1; then
  useradd --system --gid "$service_user" --home-dir "$install_dir" --shell /usr/sbin/nologin "$service_user"
fi

mkdir -p "$install_dir/backups" "$install_dir/db" "$install_dir/uploads" "$install_dir/logs"

app_secret=$(openssl rand -hex 32)
jwt_secret=$(openssl rand -hex 32)
user_jwt_secret=$(openssl rand -hex 32)
admin_password=$(openssl rand -hex 20)
admin_path="/manage-$(openssl rand -hex 12)"

install -o root -g "$service_user" -m 0750 "$staging_dir/usgiftcardhub" "$install_dir/usgiftcardhub"
install -o "$service_user" -g "$service_user" -m 0600 "$staging_dir/dujiao.db" "$install_dir/db/dujiao.db"

sed \
  -e "s/__APP_SECRET__/$app_secret/" \
  -e "s/__JWT_SECRET__/$jwt_secret/" \
  -e "s/__USER_JWT_SECRET__/$user_jwt_secret/" \
  -e "s|__ADMIN_PATH__|$admin_path|" \
  "$staging_dir/config.yml.template" > "$install_dir/config.yml"
chown "$service_user:$service_user" "$install_dir/config.yml"
chmod 0600 "$install_dir/config.yml"
chown -R "$service_user:$service_user" "$install_dir/db" "$install_dir/uploads" "$install_dir/logs"
chmod 0700 "$install_dir/uploads"

install -o root -g root -m 0644 "$staging_dir/usgiftcardhub.service" "$service_unit_file"
systemctl daemon-reload
systemctl stop "$service_name" 2>/dev/null || true

printf '%s\n' "$admin_password" | runuser -u "$service_user" -- bash -c 'cd /opt/usgiftcardhub && ./usgiftcardhub admin reset-password --username usgiftadmin' >/dev/null

umask 077
{
  printf 'Site URL: https://usgiftcardhub.com\n'
  printf 'Admin URL: https://usgiftcardhub.com%s\n' "$admin_path"
  printf 'Username: usgiftadmin\n'
  printf 'Password: %s\n' "$admin_password"
} > "$credential_file"
chmod 0600 "$credential_file"

systemctl enable --now "$service_name"

for _ in {1..30}; do
  if curl --fail --silent --show-error http://127.0.0.1:8080/health >/dev/null; then
    break
  fi
  sleep 1
done

systemctl is-active --quiet "$service_name"
curl --fail --silent --show-error http://127.0.0.1:8080/health >/dev/null
database_check=$(python3 - "$install_dir/db/dujiao.db" <<'PY'
import sqlite3
import sys

connection = sqlite3.connect(sys.argv[1])
print(connection.execute("PRAGMA quick_check").fetchone()[0])
PY
)
test "$database_check" = ok

database_products=$(python3 - "$install_dir/db/dujiao.db" <<'PY'
import sqlite3
import sys

connection = sqlite3.connect(sys.argv[1])
print(connection.execute("SELECT COUNT(*) FROM products").fetchone()[0])
PY
)

printf 'deployment_id=%s\n' "$deployment_id"
printf 'service_status=%s\n' "$(systemctl is-active "$service_name")"
printf 'listen_status=%s\n' "$(ss -lntH 'sport = :8080' | awk '{print $4}' | head -1)"
printf 'database_products=%s\n' "$database_products"
printf 'credentials_file=%s\n' "$credential_file"
