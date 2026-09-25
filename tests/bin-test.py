#!/usr/bin/env python3
"""bin/test が git status の変更から依存するテストだけを選ぶことを、一時 repo の fixture で確かめる。"""

from pathlib import Path
import subprocess
import tempfile

RUNNER = Path(__file__).resolve().parents[1] / "bin/test"


def write(root, path, text):
    file = root / path
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(text)


def git(root, *args):
    subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True)


def selected(root, *args):
    result = subprocess.run([str(RUNNER), "--list", *args, str(root)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    return result.stdout.splitlines()


with tempfile.TemporaryDirectory(prefix="bin-test-") as temp:
    root = Path(temp)
    write(root, "modules/shared.scad", "module shared() {}\n")
    write(root, "modules/unused.scad", "module unused() {}\n")
    write(root, "assets/fixture-a/part.scad", "use <../../modules/shared.scad>\nshared();\n")
    write(root, "assets/fixture-b/part.scad", "cube(1);\n")
    write(root, "assets/fixture-c/inner.scad", "cube(1);\n")
    write(root, "tests/helper.py", '"""共通処理 (shebang が無いのでテストとして実行しない)。"""\n')
    write(root, "tests/a.py", '#!/usr/bin/env python3\nfrom helper import x\nSOURCE = "assets/fixture-a/part.scad"\n')
    write(root, "tests/b.sh", '#!/bin/bash\nopenscad assets/fixture-b/part.scad\n')
    write(root, "tests/c.py", '#!/usr/bin/env python3\nSOURCE = ROOT / "assets/fixture-c"\n')
    git(root, "init", "-q")
    git(root, "add", ".")
    git(root, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "fixture")

    check = "bin/check"
    a, b, c = "python3 tests/a.py", "tests/b.sh", "python3 tests/c.py"

    # 変更が無ければ台帳検査だけ。
    assert selected(root) == [check], selected(root)
    # 全件指定は変更に関係なく全テスト。
    assert selected(root, "--all") == [check, a, b, c], selected(root, "--all")

    def case(edit, want):
        edit()
        got = selected(root)
        assert got == [check, *want], (edit.__name__, got, want)
        git(root, "stash", "-qu")

    # SCAD の use を辿り、module の変更はそれを使う asset のテストだけを選ぶ。
    def module_used(): write(root, "modules/shared.scad", "module shared() { cube(1); }\n")
    def module_unused(): write(root, "modules/unused.scad", "module unused() { cube(1); }\n")
    # テストが参照する directory 配下の新規ファイル (untracked) も対象。
    def new_file_in_dir(): write(root, "assets/fixture-c/new/deep.scad", "cube(2);\n")
    # テスト自身・import する共通処理の変更。shebang の無い共通処理は実行しない。
    def test_itself(): write(root, "tests/b.sh", "#!/bin/bash\n# edited\nopenscad assets/fixture-b/part.scad\n")
    def helper(): write(root, "tests/helper.py", "x = 1\n")
    # rename は新旧どちらの path でも選ぶ。
    def renamed(): git(root, "mv", "assets/fixture-b/part.scad", "assets/fixture-b/renamed.scad")
    def unrelated(): write(root, "docs/note.md", "memo\n")

    case(module_used, [a])
    case(module_unused, [])
    case(new_file_in_dir, [c])
    case(test_itself, [b])
    case(helper, [a])
    case(renamed, [b])
    case(unrelated, [])

    # 実行時は選んだテストが1本でも失敗すれば非0で終わり、残りも最後まで回す。
    write(root, "bin/check", "#!/bin/bash\n")
    (root / "bin/check").chmod(0o755)
    write(root, "tests/b.sh", "#!/bin/bash\necho boom\nexit 1\n")
    (root / "tests/b.sh").chmod(0o755)
    write(root, "tests/c.py", '#!/usr/bin/env python3\nopen("ran", "w")\n')
    for jobs in (["-j", "1"], []):  # 直列でも、既定の並列でも同じ結果
        (root / "ran").unlink(missing_ok=True)
        result = subprocess.run([str(RUNNER), *jobs, str(root)], capture_output=True, text=True, cwd=root)
        assert result.returncode != 0, result.stdout
        assert (root / "ran").exists(), "tests after a failure must still run"
        # 失敗したテストの出力は、並列でも失敗の一覧と一緒に残す。
        assert "boom" in result.stdout and "FAILED: tests/b.sh" in result.stderr, (result.stdout, result.stderr)

print("bin-test: git status selection, scad use graph, helpers, renames and failure exit passed")
