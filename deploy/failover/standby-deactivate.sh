#!/usr/bin/env bash
set -euo pipefail

active_marker=/etc/usgiftcardhub-failover-active
tls_config=/etc/tls-shunt-proxy/config.yaml

[[ $EUID -eq 0 ]] || { echo "must run as root" >&2; exit 1; }
systemctl disable --now usgiftcardhub-worker.service usgiftcardhub.service redis-server.service >/dev/null 2>&1 || true

if grep -Fq '# BEGIN USGIFTCARDHUB_FAILOVER' "$tls_config"; then
  tls_backup="$tls_config.before-failover-deactivate-$(date -u +%Y%m%dT%H%M%SZ)"
  cp -a "$tls_config" "$tls_backup"
  awk '
    /^# BEGIN USGIFTCARDHUB_FAILOVER$/ {skip=1; next}
    /^# END USGIFTCARDHUB_FAILOVER$/ {skip=0; next}
    !skip {print}
  ' "$tls_config" > "$tls_config.tmp"
  mv "$tls_config.tmp" "$tls_config"
  if ! systemctl restart tls-shunt-proxy.service; then
    cp -a "$tls_backup" "$tls_config"
    systemctl restart tls-shunt-proxy.service || true
    echo "TLS rollback restored the previous configuration" >&2
    exit 1
  fi
fi

rm -f "$active_marker"
systemctl enable --now usgiftcardhub-replica-apply.timer
echo "failover_status=standby"
echo "standby_services=stopped"
