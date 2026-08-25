#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <archive.tar.gz.enc> <archive.sha256> <backup-key-file>" >&2
}

[[ $EUID -eq 0 ]] || { echo "must run as root" >&2; exit 1; }
[[ $# -eq 3 ]] || { usage; exit 2; }

archive=$1
checksum_file=$2
backup_key=$3
incoming=/var/lib/usghsync/incoming
apply_command=/usr/local/sbin/usgiftcardhub-standby-apply

[[ -f "$archive" && -f "$checksum_file" && -s "$backup_key" ]] || {
  echo "archive, checksum, or key is missing" >&2
  exit 1
}
[[ -x "$apply_command" ]] || { echo "standby apply command is missing" >&2; exit 1; }

archive_dir=$(cd "$(dirname "$archive")" && pwd)
archive_name=$(basename "$archive")
checksum_name=$(basename "$checksum_file")
(
  cd "$archive_dir"
  sha256sum -c "$checksum_name"
)

staging=$(mktemp -d /var/lib/usghsync/.restore.XXXXXX)
listing=$(mktemp /var/lib/usghsync/.restore-list.XXXXXX)
cleanup() {
  [[ -f "$listing" ]] && unlink "$listing"
  if [[ -d "$staging" ]]; then
    find "$staging" -mindepth 1 -delete
    rmdir "$staging"
  fi
}
trap cleanup EXIT

openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -md sha256 \
    -pass file:"$backup_key" -in "$archive_dir/$archive_name" \
  | tar -tzf - > "$listing"
if grep -Eq '(^/|(^|/)\.\.(/|$))' "$listing"; then
  echo "archive contains an unsafe path" >&2
  exit 1
fi

openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -md sha256 \
    -pass file:"$backup_key" -in "$archive_dir/$archive_name" \
  | tar --no-same-owner -xzf - -C "$staging"

for required in \
  READY MANIFEST SHA256SUMS \
  app/config.yml app/db/dujiao.db app/usgiftcardhub-api app/usgiftcardhub \
  redis/dump.rdb systemd/usgiftcardhub.service systemd/usgiftcardhub-worker.service; do
  [[ -f "$staging/$required" ]] || { echo "archive is missing $required" >&2; exit 1; }
done
(
  cd "$staging"
  sha256sum -c SHA256SUMS
)

install -d -o usghsync -g usghsync -m 0700 "$incoming"
rsync -a --delete "$staging/" "$incoming/"
chown -R usghsync:usghsync "$incoming"
chmod -R go-rwx "$incoming"
"$apply_command"

echo "restored_archive=$archive_name"
echo "applied_snapshot=$(</var/lib/usgiftcardhub-replica/applied-snapshot)"
echo "standby_services=stopped"
