#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <staging-directory> <deployment-id>" >&2
  exit 2
fi

staging_dir=$1
deployment_id=$2
install_dir=/opt/usgiftcardhub
service_name=usgiftcardhub
service_user=usgiftcardhub
credential_file=/root/usgiftcardhub-admin-credentials.txt

for required_file in usgiftcardhub dujiao.db config.yml.template usgiftcardhub.service; do
  test -f "$staging_dir/$required_file"
done

if ! getent group "$service_user" >/dev/null; then
  groupadd --system "$service_user"
fi
if ! id "$service_user" >/dev/null 2>&1; then
  useradd --system --gid "$service_user" --home-dir "$install_dir" --shell /usr/sbin/nologin "$service_user"
fi

mkdir -p "$install_dir/backups" "$install_dir/db" "$install_dir/logs"
backup_dir="$install_dir/backups/$deployment_id"
mkdir -p "$backup_dir"
for existing_file in usgiftcardhub config.yml db/dujiao.db; do
  if [[ -f "$install_dir/$existing_file" ]]; then
    mkdir -p "$backup_dir/$(dirname "$existing_file")"
    cp -a "$install_dir/$existing_file" "$backup_dir/$existing_file"
  fi
done
if [[ -f /etc/systemd/system/usgiftcardhub.service ]]; then
  cp -a /etc/systemd/system/usgiftcardhub.service "$backup_dir/usgiftcardhub.service"
fi
if [[ -f "$credential_file" ]]; then
  cp -a "$credential_file" "$backup_dir/admin-credentials.txt"
fi

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
chown -R "$service_user:$service_user" "$install_dir/db" "$install_dir/logs"

install -o root -g root -m 0644 "$staging_dir/usgiftcardhub.service" /etc/systemd/system/usgiftcardhub.service
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
