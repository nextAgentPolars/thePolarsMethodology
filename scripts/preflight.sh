#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$ROOT"

test -z "$(git status --porcelain)" || {
  echo "preflight: worktree is not clean" >&2
  exit 1
}

git diff --check HEAD --

python3 - <<'PY'
from pathlib import Path
import re

root = Path.cwd()
readme = (root / "README.md").read_text(encoding="utf-8")

links = re.findall(r"\[[^]]+\]\(([^)]+)\)", readme)
missing = [link for link in links if "://" not in link and not (root / link).is_file()]
if missing:
    raise SystemExit(f"preflight: missing README targets: {missing}")

articles = sorted((root / "docs").glob("[0-9][0-9]-*.md"))
if not articles:
    raise SystemExit("preflight: no articles found")

for article in articles:
    text = article.read_text(encoding="utf-8")
    first = text.splitlines()[0] if text else ""
    if not first.startswith("# "):
        raise SystemExit(f"preflight: missing H1: {article}")
    if "<<<<<<<" in text or "=======" in text or ">>>>>>>" in text:
        raise SystemExit(f"preflight: conflict marker: {article}")
PY

HEAD=$(git rev-parse HEAD)
TREE=$(git rev-parse HEAD^{tree})
printf '{"schema_version":"the_polars_methodology.preflight.v1","status":"passed","head":"%s","tree":"%s"}\n' "$HEAD" "$TREE"
