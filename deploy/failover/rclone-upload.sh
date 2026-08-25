#!/usr/bin/env bash
set -euo pipefail

archive_dir=/var/lib/usgiftcardhub-replica/archives
rclone_config=/root/.config/rclone/rclone.conf
rclone_remote='gdbaby:USGiftCardHub Backups'
lock_file=/run/lock/usgiftcardhub-rclone-upload.lock

[[ $EUID -eq 0 ]] || { echo "must run as root" >&2; exit 1; }
[[ -x /usr/local/bin/rclone ]] || { echo "rclone is not installed" >&2; exit 1; }
[[ -s "$rclone_config" ]] || { echo "rclone config is missing" >&2; exit 1; }
[[ "$archive_dir" == /var/lib/usgiftcardhub-replica/archives ]] || exit 1

mkdir -p "$(dirname "$lock_file")"
exec 9>>"$lock_file"
flock -n 9 || { echo "another rclone upload is active" >&2; exit 0; }

mapfile -d '' archives < <(
  find "$archive_dir" -maxdepth 1 -type f -name 'usgiftcardhub-full-*.tar.gz.enc' -print0 | sort -z
)
(( ${#archives[@]} > 0 )) || { echo "no encrypted archive found" >&2; exit 1; }

archive=${archives[-1]}
archive_name=$(basename "$archive")
checksum="$archive.sha256"
manifest="$archive.manifest"
[[ -f "$checksum" && -f "$manifest" ]] || { echo "archive sidecars are missing" >&2; exit 1; }

(
  cd "$archive_dir"
  sha256sum -c "$(basename "$checksum")"
)

rclone_common=(
  --config "$rclone_config"
  --contimeout 15s
  --timeout 5m
  --retries 8
  --low-level-retries 20
  --retries-sleep 15s
  --transfers 1
  --checkers 2
  --tpslimit 2
  --tpslimit-burst 2
)

/usr/local/bin/rclone mkdir "$rclone_remote" "${rclone_common[@]}"
for source_file in "$archive" "$checksum" "$manifest"; do
  file_name=$(basename "$source_file")
  /usr/local/bin/rclone copyto "$source_file" "$rclone_remote/$file_name" \
    "${rclone_common[@]}" --no-traverse
done

/usr/local/bin/rclone check "$archive_dir" "$rclone_remote" \
  "${rclone_common[@]}" --one-way \
  --include "$archive_name" \
  --include "$archive_name.sha256" \
  --include "$archive_name.manifest"

local_size=$(stat -c %s "$archive")
remote_size=$(/usr/local/bin/rclone size "$rclone_remote/$archive_name" \
  "${rclone_common[@]}" --json \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["bytes"])')
[[ "$local_size" == "$remote_size" ]] || {
  echo "remote size mismatch: local=$local_size remote=$remote_size" >&2
  exit 1
}

echo "rclone_remote=$rclone_remote"
echo "uploaded_archive=$archive_name"
echo "uploaded_size=$remote_size"
echo "rclone_check=ok"
