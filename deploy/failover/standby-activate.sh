#!/usr/bin/env bash
set -euo pipefail

active_marker=/etc/usgiftcardhub-failover-active
tls_config=/etc/tls-shunt-proxy/config.yaml
begin_marker='# BEGIN USGIFTCARDHUB_FAILOVER'
end_marker='# END USGIFTCARDHUB_FAILOVER'
tls_backup=""
rollback_required=false

rollback_activation() {
  local exit_code=$?
  if $rollback_required; then
    if [[ -n "$tls_backup" && -f "$tls_backup" ]]; then
      cp -a "$tls_backup" "$tls_config"
      systemctl restart tls-shunt-proxy.service >/dev/null 2>&1 || true
    fi
    systemctl disable --now usgiftcardhub-worker.service usgiftcardhub.service redis-server.service >/dev/null 2>&1 || true
    rm -f "$active_marker"
    if [[ "$mode" == --confirm-primary-down ]]; then
      systemctl enable --now usgiftcardhub-replica-apply.timer >/dev/null 2>&1 || true
    fi
  fi
  exit "$exit_code"
}

trap rollback_activation ERR

[[ $EUID -eq 0 ]] || { echo "must run as root" >&2; exit 1; }
mode=${1:-}
[[ "$mode" == --confirm-primary-down || "$mode" == --test-only ]] || {
  echo "usage: $0 --confirm-primary-down | --test-only" >&2
  echo "refusing to activate without an explicit single-writer confirmation" >&2
  exit 2
}
[[ -f /var/lib/usgiftcardhub-replica/applied-snapshot ]] || {
  echo "no applied replica snapshot" >&2
  exit 1
}

if [[ "$mode" == --confirm-primary-down ]]; then
  systemctl stop usgiftcardhub-replica-apply.timer >/dev/null 2>&1 || true
fi

tls_backup="$tls_config.before-usgiftcardhub-$(date -u +%Y%m%dT%H%M%SZ)"
cp -a "$tls_config" "$tls_backup"
rollback_required=true
if ! grep -Fq "$begin_marker" "$tls_config"; then
  cat >> "$tls_config" <<'YAML'
# BEGIN USGIFTCARDHUB_FAILOVER
  - name: usgiftcardhub.com
    tlsoffloading: true
    managedcert: true
    keytype: p256
    alpn: http/1.1
    protocols: tls12,tls13
    http:
      handler: proxyPass
      args: 127.0.0.1:8080
# END USGIFTCARDHUB_FAILOVER
YAML
fi

systemctl enable --now redis-server.service
systemctl enable --now usgiftcardhub.service
for _ in {1..30}; do
  if curl --fail --silent --show-error --max-time 3 http://127.0.0.1:8080/health >/dev/null; then
    break
  fi
  sleep 1
done
if ! curl --fail --silent --show-error --max-time 5 http://127.0.0.1:8080/health >/dev/null; then
  echo "API failed health check; activation will roll back" >&2
  false
fi

if ! systemctl restart tls-shunt-proxy.service; then
  echo "TLS proxy failed; activation will roll back" >&2
  false
fi

tls_ready=false
for _ in {1..30}; do
  if curl --fail --silent --show-error --max-time 3 \
      --noproxy '*' \
      --resolve usgiftcardhub.com:443:127.0.0.1 \
      https://usgiftcardhub.com/health >/dev/null; then
    tls_ready=true
    break
  fi
  sleep 1
done
$tls_ready || { echo "local HTTPS health check failed" >&2; false; }

if [[ "$mode" == --test-only ]]; then
  cp -a "$tls_backup" "$tls_config"
  systemctl restart tls-shunt-proxy.service
  systemctl disable --now usgiftcardhub.service redis-server.service >/dev/null 2>&1 || true
  rollback_required=false
  trap - ERR
  echo "failover_test=passed"
  echo "worker_started=no"
  echo "standby_services=stopped"
  exit 0
fi

systemctl enable --now usgiftcardhub-worker.service
printf 'activated_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$active_marker"
printf 'snapshot_id=%s\n' "$(</var/lib/usgiftcardhub-replica/applied-snapshot)" >> "$active_marker"
chmod 0600 "$active_marker"
rollback_required=false
trap - ERR

echo "failover_status=active"
echo "snapshot_id=$(</var/lib/usgiftcardhub-replica/applied-snapshot)"
echo "public_ip=$(hostname -I | awk '{print $1}')"
echo "dns_action=point usgiftcardhub.com to this public IP"
