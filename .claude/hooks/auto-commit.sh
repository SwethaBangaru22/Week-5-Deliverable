#!/usr/bin/env bash
# Commits and pushes all changes when the last commit is at least INTERVAL seconds old.
set -euo pipefail

INTERVAL="${AUTO_COMMIT_INTERVAL:-600}"
cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel)}"

[ -z "$(git status --porcelain)" ] && exit 0

last=$(git log -1 --format=%ct 2>/dev/null || echo 0)
now=$(date +%s)
[ $((now - last)) -lt "$INTERVAL" ] && exit 0

lock=".git/auto-commit.lock"
mkdir "$lock" 2>/dev/null || exit 0
trap 'rmdir "$lock"' EXIT

git add -A
git commit -q -m "Auto-commit: $(date '+%Y-%m-%d %H:%M')"
git push -q origin HEAD
echo '{"systemMessage": "Auto-committed and pushed changes to GitHub"}'
