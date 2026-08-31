#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
INSTALL_SCRIPT=$(cd "${SCRIPT_DIR}/../.." && pwd)/deploy/vps200/install.sh

TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/vps200-install-test.XXXXXX")
trap 'rm -rf -- "$TEST_TMP"' EXIT

passed=0
failed=0

pass() {
  printf 'ok - %s\n' "$1"
  passed=$((passed + 1))
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  failed=$((failed + 1))
}

assert_success() {
  local name=$1
  shift
  if "$@"; then
    pass "$name"
  else
    fail "$name"
  fi
}

assert_failure() {
  local name=$1
  shift
  if "$@"; then
    fail "$name"
  else
    pass "$name"
  fi
}

export USGIFTCARDHUB_INSTALL_TESTING=1
# shellcheck source=../../deploy/vps200/install.sh
source "$INSTALL_SCRIPT"

flock() {
  return 0
}

fresh_dir="$TEST_TMP/fresh"
mkdir -p "$fresh_dir"
assert_success "accepts an empty fresh-install target" \
  assert_fresh_install_target "$fresh_dir/usgiftcardhub" "$fresh_dir/config.yml" "$fresh_dir/db/dujiao.db"
assert_success "accepts a safe deployment id" validate_deployment_id "release-20260825_0810"
assert_failure "rejects a traversal deployment id" validate_deployment_id "../../escape"
assert_failure "rejects an absolute deployment id" validate_deployment_id "/tmp/escape"
assert_failure "rejects an overlong deployment id" validate_deployment_id "$(printf 'a%.0s' {1..65})"

for marker in \
  usgiftcardhub \
  usgiftcardhub-api \
  config.yml \
  db/dujiao.db; do
  target_dir="$TEST_TMP/target-${marker//\//-}"
  mkdir -p "$target_dir/$(dirname "$marker")"
  printf 'preserve-me\n' > "$target_dir/$marker"
  before_hash=$(shasum -a 256 "$target_dir/$marker" | awk '{print $1}')

  assert_failure "rejects existing $marker" \
    assert_fresh_install_target "$target_dir/$marker"

  after_hash=$(shasum -a 256 "$target_dir/$marker" | awk '{print $1}')
  if [[ "$before_hash" == "$after_hash" ]]; then
    pass "preserves existing $marker"
  else
    fail "preserves existing $marker"
  fi
done

service_unit="$TEST_TMP/usgiftcardhub.service"
credential_file="$TEST_TMP/usgiftcardhub-admin-credentials.txt"
printf 'service\n' > "$service_unit"
printf 'credentials\n' > "$credential_file"
assert_failure "rejects an existing service unit" \
  assert_fresh_install_target "$service_unit"
assert_failure "rejects an existing credential file" \
  assert_fresh_install_target "$credential_file"

dangling_marker="$TEST_TMP/dangling-config.yml"
ln -s "$TEST_TMP/missing-target" "$dangling_marker"
assert_failure "rejects a dangling managed symlink" assert_fresh_install_target "$dangling_marker"

alias_target="$TEST_TMP/alias-target"
mkdir -p "$alias_target"
printf 'existing-binary\n' > "$alias_target/usgiftcardhub"
assert_failure "rejects a non-normalized managed path" \
  assert_fresh_install_target "$alias_target/missing/../usgiftcardhub"

lock_sentinel="$TEST_TMP/lock-sentinel"
printf 'must-not-be-truncated\n' > "$lock_sentinel"
lock_hash_before=$(shasum -a 256 "$lock_sentinel" | awk '{print $1}')
assert_success "opens an existing regular lock without truncation" acquire_install_lock "$lock_sentinel"
lock_hash_after=$(shasum -a 256 "$lock_sentinel" | awk '{print $1}')
if [[ "$lock_hash_before" == "$lock_hash_after" ]]; then
  pass "preserves existing lock-file contents"
else
  fail "preserves existing lock-file contents"
fi

symlink_lock="$TEST_TMP/symlink-lock"
ln -s "$lock_sentinel" "$symlink_lock"
assert_failure "rejects a symlink install lock" acquire_install_lock "$symlink_lock"
assert_failure "rejects a non-normalized install lock" acquire_install_lock "$TEST_TMP/missing/../lock"

assert_success "fresh install creates the uploads directory" \
  grep -Fq 'mkdir -p "$install_dir/backups" "$install_dir/db" "$install_dir/uploads" "$install_dir/logs"' "$INSTALL_SCRIPT"
assert_success "fresh install grants the service account ownership of uploads" \
  grep -Fq 'chown -R "$service_user:$service_user" "$install_dir/db" "$install_dir/uploads" "$install_dir/logs"' "$INSTALL_SCRIPT"
assert_success "fresh install keeps uploads private on disk" \
  grep -Fq 'chmod 0700 "$install_dir/uploads"' "$INSTALL_SCRIPT"

printf 'passed=%d failed=%d\n' "$passed" "$failed"
(( failed == 0 ))
