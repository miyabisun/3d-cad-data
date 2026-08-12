#!/usr/bin/env bash
set -euo pipefail

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
HOME_DIR="$ROOT/home"
CONFIG_DIR="$HOME_DIR/.config/scad-live"
UNIT_DIR="$HOME_DIR/.config/systemd/user"
LOG="$ROOT/systemctl.log"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
mkdir -p "$CONFIG_DIR" "$UNIT_DIR" "$ROOT/bin"
touch "$UNIT_DIR/scad-live-watch.service" "$UNIT_DIR/scad-live-server.service"

cat > "$ROOT/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"
[ "${FAIL_RESTART:-0}" -eq 0 ]
EOF
chmod +x "$ROOT/bin/systemctl"

cat > "$CONFIG_DIR/env" <<'EOF'
# Keep this comment and unrelated setting.
UNRELATED=value
SCAD_LIVE_SRC=/old/projects
SCAD_LIVE_MODULES=/old/modules
SCAD_LIVE_DIST=/old/dist
SCAD_LIVE_BIND=0.0.0.0
SCAD_LIVE_PORT=3000
EOF

run_setup() {
  env HOME="$HOME_DIR" SYSTEMCTL="$ROOT/bin/systemctl" SYSTEMCTL_LOG="$LOG" \
    FAIL_RESTART="${FAIL_RESTART:-0}" \
    "$PROJECT_ROOT/bin/use-scad-live"
}

run_setup
grep -Fxq '# Keep this comment and unrelated setting.' "$CONFIG_DIR/env"
grep -Fxq 'UNRELATED=value' "$CONFIG_DIR/env"
grep -Fxq "SCAD_LIVE_SRC=\"$PROJECT_ROOT/src/projects\"" "$CONFIG_DIR/env"
grep -Fxq "SCAD_LIVE_MODULES=\"$PROJECT_ROOT/src/modules\"" "$CONFIG_DIR/env"
grep -Fxq "SCAD_LIVE_DIST=\"$PROJECT_ROOT/dist\"" "$CONFIG_DIR/env"
grep -Fxq 'SCAD_LIVE_BIND=0.0.0.0' "$CONFIG_DIR/env"
grep -Fxq 'SCAD_LIVE_PORT=3000' "$CONFIG_DIR/env"
[ "$(grep -c '^SCAD_LIVE_SRC=' "$CONFIG_DIR/env")" -eq 1 ]
[ "$(grep -c '^SCAD_LIVE_MODULES=' "$CONFIG_DIR/env")" -eq 1 ]
[ "$(grep -c '^SCAD_LIVE_DIST=' "$CONFIG_DIR/env")" -eq 1 ]
grep -Fxq -- '--user restart scad-live-watch scad-live-server' "$LOG"

cp "$CONFIG_DIR/env" "$ROOT/first-env"
run_setup
cmp -s "$ROOT/first-env" "$CONFIG_DIR/env"
[ "$(wc -l < "$LOG")" -eq 2 ]

sed -i 's#^SCAD_LIVE_SRC=.*#SCAD_LIVE_SRC=/keep/on/failure#' "$CONFIG_DIR/env"
cp "$CONFIG_DIR/env" "$ROOT/before-failure"
if FAIL_RESTART=1 run_setup > "$ROOT/stdout" 2> "$ROOT/stderr"; then
  echo 'expected a failed restart to fail setup' >&2
  exit 1
fi
cmp -s "$ROOT/before-failure" "$CONFIG_DIR/env"
grep -Fq 'restored the previous configuration' "$ROOT/stderr"
[ "$(wc -l < "$LOG")" -eq 4 ]

rm "$CONFIG_DIR/env"
if run_setup > "$ROOT/stdout" 2> "$ROOT/stderr"; then
  echo 'expected setup to fail when scad-live is not configured' >&2
  exit 1
fi
grep -Fq 'make -C systemd setup-scad-live' "$ROOT/stderr"
[ "$(wc -l < "$LOG")" -eq 4 ]

echo 'scad-live sharing tests passed'
