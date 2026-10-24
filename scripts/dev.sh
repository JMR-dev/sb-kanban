#!/usr/bin/env bash
# Runs the pinned SilverBullet on a fresh scratch copy of the fixture space
# with the built library page installed (`make dev` builds it first), for
# trying boards by hand. Edits made in the browser stay in the scratch copy.
#
#   SB_DEV_PORT=3001 scripts/dev.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
space="${repo_root}/.sbtest-tmp/dev-space"
port="${SB_DEV_PORT:-3000}"

rm -rf "$space"
mkdir -p "$(dirname "$space")"
cp -r "${repo_root}/sbtest/space" "$space"
mkdir -p "${space}/Library/JMR-dev"
cp "${repo_root}/dist/Library/JMR-dev/Kanban.md" "${space}/Library/JMR-dev/Kanban.md"

echo "Scratch space: ${space}"
echo "Open http://127.0.0.1:${port}/  (Ctrl-C to stop)"
exec "${repo_root}/.tools/bin/silverbullet" -L 127.0.0.1 -p "$port" "$space"
