#!/bin/bash
# MiSTer Extras Scanner launcher.
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PYTHON="${PYTHON:-python3}"
exec "$PYTHON" "$SCRIPT_DIR/mister_extras_scan.py" "$@"
