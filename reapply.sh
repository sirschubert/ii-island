#!/usr/bin/env bash
# Re-wires ii-island into the end-4 "ii" config after an update.
# Usage: ./reapply.sh [IIDIR]   (default ~/.config/quickshell/ii)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IIDIR="${1:-$HOME/.config/quickshell/ii}"

ln -sfn "$HERE/src" "$IIDIR/modules/island"
echo "linked $IIDIR/modules/island -> $HERE/src"

cd "$IIDIR"
if patch -p1 --reverse --dry-run --silent < "$HERE/upstream.patch" >/dev/null 2>&1; then
    echo "upstream.patch already applied"
    exit 0
fi
if ! out=$(patch -p1 --forward --dry-run < "$HERE/upstream.patch" 2>&1); then
    echo "upstream.patch no longer applies cleanly; nothing was changed:" >&2
    echo "$out" >&2
    exit 1
fi
patch -p1 --forward --silent < "$HERE/upstream.patch"
echo "upstream.patch applied"
