#!/bin/bash
# bin/check の positive / negative テスト。fixture は一時 directory に作り、
# repo 本体の print/ と ledger/ には触れない。
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CHECK="$SCRIPT_DIR/../bin/check"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

make_fixture() {
  root="$WORK/$1"
  mkdir -p "$root/print" "$root/ledger/prints"
  printf -- '---\nokf_version: "0.2"\n---\n\n# ledger\n' > "$root/ledger/index.md"
  printf '# log\n' > "$root/ledger/log.md"
  echo "$root"
}

make_3mf() {
  printf 'dummy 3mf payload: %s\n' "$1" > "$2"
}

make_concept() {
  path=$1 status=$2 artifact=$3 sha=$4
  cat > "$path" <<EOF
---
type: Print
title: test
description: test concept
status: $status
tags: [test]
artifact: $artifact
content_sha256: $sha
---

body
EOF
}

expect() {
  name=$1 want=$2 root=$3
  if "$CHECK" "$root" > /dev/null 2>&1; then
    got=pass
  else
    got=fail
  fi
  if [ "$got" != "$want" ]; then
    echo "FAIL: $name (expected $want, got $got)" >&2
    "$CHECK" "$root" >&2 || true
    exit 1
  fi
  echo "ok: $name ($want)"
}

# 1. 空の初期状態は PASS
root=$(make_fixture empty)
expect "empty ledger" pass "$root"

# 2. .3mf と concept が 1:1 で hash 一致なら PASS
root=$(make_fixture valid)
make_3mf a "$root/print/widget.3mf"
sha=$(sha256sum "$root/print/widget.3mf" | cut -d' ' -f1)
make_concept "$root/ledger/prints/widget.md" active print/widget.3mf "$sha"
expect "valid pair" pass "$root"

# 3. 台帳の無い .3mf は FAIL (保存直後の未登録状態)
root=$(make_fixture orphan-3mf)
make_3mf b "$root/print/stray.3mf"
expect "orphan 3mf" fail "$root"

# 4. 実体の無い現役 concept は FAIL
root=$(make_fixture orphan-concept)
make_concept "$root/ledger/prints/ghost.md" active print/ghost.3mf \
  "$(printf 'x' | sha256sum | cut -d' ' -f1)"
expect "orphan concept" fail "$root"

# 5. 不正な status は FAIL
root=$(make_fixture bad-status)
make_3mf c "$root/print/thing.3mf"
sha=$(sha256sum "$root/print/thing.3mf" | cut -d' ' -f1)
make_concept "$root/ledger/prints/thing.md" printing print/thing.3mf "$sha"
expect "invalid status" fail "$root"

# 6. hash 不一致 (上書き保存後に台帳未更新) は FAIL
root=$(make_fixture stale-hash)
make_3mf d "$root/print/plate.3mf"
make_concept "$root/ledger/prints/plate.md" active print/plate.3mf \
  "$(printf 'old' | sha256sum | cut -d' ' -f1)"
expect "stale hash" fail "$root"

# 7. retired concept は .3mf が消えていても PASS (identity は保持したまま)
root=$(make_fixture retired)
make_concept "$root/ledger/prints/old-part.md" retired print/old-part.3mf \
  "$(printf 'gone' | sha256sum | cut -d' ' -f1)"
expect "retired without file" pass "$root"

# 8. print/ の外へ抜ける artifact (path traversal) は FAIL
root=$(make_fixture traversal)
make_3mf e "$root/evil.3mf"
sha=$(sha256sum "$root/evil.3mf" | cut -d' ' -f1)
make_concept "$root/ledger/prints/evil.md" active "print/../evil.3mf" "$sha"
expect "artifact traversal" fail "$root"

# 9. retired でも artifact 欠落は FAIL (identity の契約)
root=$(make_fixture retired-no-artifact)
cat > "$root/ledger/prints/lost.md" <<'EOF'
---
type: Print
title: lost
description: retired without artifact
status: retired
---

body
EOF
expect "retired missing artifact" fail "$root"

# 10. retired でも content_sha256 の欠落・不正形式は FAIL
root=$(make_fixture retired-no-sha)
cat > "$root/ledger/prints/unhashed.md" <<'EOF'
---
type: Print
title: unhashed
description: retired without content_sha256
status: retired
artifact: print/unhashed.3mf
---

body
EOF
expect "retired missing sha" fail "$root"

echo "ledger check tests passed"
