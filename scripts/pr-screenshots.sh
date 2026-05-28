#!/usr/bin/env bash
set -euo pipefail

exec bash "$(dirname "$0")/ship.sh" --screenshots-only
