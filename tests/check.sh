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
  mkdir -p "$root/print" "$root/ledger/prints" "$root/ledger/designs"
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

# 11. scope が実在する Design は PASS
root=$(make_fixture design-valid)
mkdir -p "$root/assets/frame"
make_design "$root/ledger/designs/frame.md" active assets/frame
expect "valid design" pass "$root"

# 12. designs/ に置かれた type 違い (Print) は FAIL
root=$(make_fixture design-wrong-type)
mkdir -p "$root/assets/frame"
make_concept "$root/ledger/designs/mistyped.md" active print/x.3mf \
  "$(printf 'x' | sha256sum | cut -d' ' -f1)"
expect "design with wrong type" fail "$root"

# 13. scope 欠落は FAIL (retired でも必須)
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

# 14. assets/ の外へ抜ける scope (path traversal) は FAIL
root=$(make_fixture design-traversal)
mkdir -p "$root/evil"
make_design "$root/ledger/designs/evil.md" active "assets/../evil"
expect "design scope traversal" fail "$root"

# 15. 現役 Design の scope 不在は FAIL
root=$(make_fixture design-ghost-scope)
make_design "$root/ledger/designs/ghost.md" active assets/ghost
expect "design scope not found" fail "$root"

# 16. retired Design は scope が消えていても PASS
root=$(make_fixture design-retired)
make_design "$root/ledger/designs/old.md" retired assets/gone
expect "retired design without scope dir" pass "$root"

# 17. 同一 scope を持つ Design の重複は FAIL (1 design area = 1 scope)
root=$(make_fixture design-dup)
mkdir -p "$root/assets/frame"
make_design "$root/ledger/designs/one.md" active assets/frame
make_design "$root/ledger/designs/two.md" active assets/frame
expect "duplicate design scope" fail "$root"

# 18. scope が通常ファイルを指す Design は FAIL (design area = directory の契約)
root=$(make_fixture design-file-scope)
mkdir -p "$root/assets"
printf 'cube(1);\n' > "$root/assets/single.scad"
make_design "$root/ledger/designs/single.md" active assets/single.scad
expect "design scope is a file" fail "$root"

# 19. user 原文 (verbatim) 見出しの欠落は FAIL (provenance の契約)
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
