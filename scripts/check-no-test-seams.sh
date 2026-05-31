#!/bin/sh
# Fails if any production source file contains forbidden test-seam patterns.
# These patterns must never appear in Sources/ — test isolation is achieved
# solely through the dev build's separate app-support directory.
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
SOURCES="$REPO_ROOT/Sources"

PATTERNS='isUITesting\|--uitesting\|--inject-\|uiTestActivityStateOverride\|ForUITesting\|simulate.*UITesting\|NSTemporaryDirectory.*UITest'

if grep -rn "$PATTERNS" "$SOURCES" 2>/dev/null; then
    echo ""
    echo "ERROR: Production sources contain forbidden test-seam patterns."
    echo "Remove these patterns — test isolation must use only the dev build's"
    echo "separate app-support directory, never runtime flags or fake state."
    exit 1
fi

echo "check-no-test-seams: OK"
