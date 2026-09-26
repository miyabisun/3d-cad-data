#!/bin/bash
# bin/check の positive / negative テスト。fixture は一時 directory に作り、
# repo 本体の ledger/ には触れない。
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CHECK="$SCRIPT_DIR/../bin/check"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

make_fixture() {
  root="$WORK/$1"
  mkdir -p "$root/ledger/designs"
  printf -- '---\nokf_version: "0.2"\n---\n\n# ledger\n' > "$root/ledger/index.md"
  printf '# log\n' > "$root/ledger/log.md"
  echo "$root"
}

make_design() {
  path=$1 status=$2 scope=$3
  cat > "$path" <<EOF
---
type: Design
title: test design
description: test design concept
status: $status
tags: [test]
scope: $scope
---

# test design

## user 原文 (verbatim)

> test statement
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

# 2. scope が実在する Design は PASS
root=$(make_fixture design-valid)
mkdir -p "$root/assets/frame"
make_design "$root/ledger/designs/frame.md" active assets/frame
expect "valid design" pass "$root"

# 3. designs/ に置かれた type 違い (旧 Print) は FAIL
root=$(make_fixture design-wrong-type)
mkdir -p "$root/assets/frame"
make_design "$root/ledger/designs/mistyped.md" active assets/frame
sed -i 's/^type: Design$/type: Print/' "$root/ledger/designs/mistyped.md"
expect "design with wrong type" fail "$root"

# 4. scope 欠落は FAIL (retired でも必須)
root=$(make_fixture design-no-scope)
cat > "$root/ledger/designs/scopeless.md" <<'EOF'
---
type: Design
title: scopeless
description: design without scope
status: retired
---

## user 原文 (verbatim)

> test
EOF
expect "design missing scope" fail "$root"

# 5. assets/ の外へ抜ける scope (path traversal) は FAIL
root=$(make_fixture design-traversal)
mkdir -p "$root/evil"
make_design "$root/ledger/designs/evil.md" active "assets/../evil"
expect "design scope traversal" fail "$root"

# 6. 現役 Design の scope 不在は FAIL
root=$(make_fixture design-ghost-scope)
make_design "$root/ledger/designs/ghost.md" active assets/ghost
expect "design scope not found" fail "$root"

# 7. retired Design は scope が消えていても PASS
root=$(make_fixture design-retired)
make_design "$root/ledger/designs/old.md" retired assets/gone
expect "retired design without scope dir" pass "$root"

# 8. 同一 scope を持つ Design の重複は FAIL (1 design area = 1 scope)
root=$(make_fixture design-dup)
mkdir -p "$root/assets/frame"
make_design "$root/ledger/designs/one.md" active assets/frame
make_design "$root/ledger/designs/two.md" active assets/frame
expect "duplicate design scope" fail "$root"

# 9. scope が通常ファイルを指す Design は FAIL (design area = directory の契約)
root=$(make_fixture design-file-scope)
mkdir -p "$root/assets"
printf 'cube(1);\n' > "$root/assets/single.scad"
make_design "$root/ledger/designs/single.md" active assets/single.scad
expect "design scope is a file" fail "$root"

# 10. user 原文 (verbatim) 見出しの欠落は FAIL (provenance の契約)
root=$(make_fixture design-no-verbatim)
mkdir -p "$root/assets/frame"
cat > "$root/ledger/designs/hearsay.md" <<'EOF'
---
type: Design
title: hearsay
description: design without verbatim statement
status: active
tags: [test]
scope: assets/frame
---

# summary only
EOF
expect "design missing verbatim" fail "$root"

echo "ledger check tests passed"
