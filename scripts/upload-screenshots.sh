#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
SCREENSHOTS_DIR="$REPO_ROOT/screenshots"
GIST_ID_FILE="$REPO_ROOT/.screenshots-gist-id"

if [ ! -f "$GIST_ID_FILE" ]; then
  echo "Creating screenshots gist..."
  GIST_ID=$(gh api /gists --method POST \
    --field description="Agent Session Manager screenshots" \
    --field public=false \
    --field "files[placeholder.txt][content]=screenshots will appear here" \
    --jq '.id')
  echo "$GIST_ID" > "$GIST_ID_FILE"
  echo "Created gist $GIST_ID — committing .screenshots-gist-id to repo"
  git -C "$REPO_ROOT" add "$GIST_ID_FILE"
  git -C "$REPO_ROOT" -c user.email="ci@local" -c user.name="screenshots-bot" \
    commit -q -m "chore: store screenshots gist id"
else
  GIST_ID=$(cat "$GIST_ID_FILE")
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

TOKEN=$(gh auth token)
git clone --quiet "https://${TOKEN}@gist.github.com/${GIST_ID}.git" "$tmpdir/gist"
cp "$SCREENSHOTS_DIR"/*.png "$tmpdir/gist/"
cd "$tmpdir/gist"

git checkout --orphan fresh
git add .
git -c user.email="ci@local" -c user.name="screenshots-bot" \
  commit -q -m "screenshots: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

DEFAULT_BRANCH=$(git -C "$tmpdir/gist" remote show origin | awk '/HEAD branch/ {print $NF}')
git push --quiet --force origin "HEAD:$DEFAULT_BRANCH"

echo "Pushed screenshots to gist $GIST_ID"
echo "$GIST_ID"
