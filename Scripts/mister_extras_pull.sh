#!/bin/bash
set -u
SD_ROOT="/media/fat"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TOKEN_FILE="$SCRIPT_DIR/.github_token"
CHECKOUT="/tmp/.butthole_pull_$$"
ASKPASS="/tmp/.butthole_askpass_$$"
cleanup(){ rm -rf "$CHECKOUT" "$ASKPASS"; unset GITHUB_TOKEN GIT_ASKPASS GIT_TERMINAL_PROMPT; }
trap cleanup EXIT INT TERM

echo "========================================"
echo "       ButtHole GitHub Pull"
echo "========================================"
echo
if [ ! -f "$TOKEN_FILE" ]; then
  echo "ERROR: $TOKEN_FILE was not found."
  echo "Copy the GitHub token into /media/fat/Scripts/.github_token first."
  exit 1
fi
TOKEN="$(tr -d '\r\n' < "$TOKEN_FILE")"
[ -n "$TOKEN" ] || { echo "ERROR: GitHub token file is empty."; exit 1; }
chmod 600 "$TOKEN_FILE" 2>/dev/null || true
if ! command -v git >/dev/null 2>&1; then echo "ERROR: git is not installed."; exit 1; fi
cat > "$ASKPASS" <<'ASKPASS_EOF'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' "git" ;;
  *Password*) printf '%s\n' "$GITHUB_TOKEN" ;;
  *) printf '%s\n' "$GITHUB_TOKEN" ;;
esac
ASKPASS_EOF
chmod 700 "$ASKPASS"
export GITHUB_TOKEN="$TOKEN" GIT_ASKPASS="$ASKPASS" GIT_TERMINAL_PROMPT=0

echo "[1/4] Reading latest ButtHole repository..."
git clone --depth 1 --branch main https://github.com/modology/ButtHole.git "$CHECKOUT" >/dev/null 2>&1 || { echo "ERROR: Download failed."; exit 1; }

# Only files under the repository root are considered. Local files that are not
# in ButtHole are never deleted. Existing files are compared using SHA-256 so
# unchanged files are skipped without being copied again.
echo "[2/4] Comparing repository files with /media/fat..."
NEW_COUNT=0
CHANGED_COUNT=0
UNCHANGED_COUNT=0
TOTAL_COUNT=0
TOTAL_BYTES=0

cd "$CHECKOUT" || exit 1
while IFS= read -r -d '' f; do
  rel="${f#./}"
  case "$rel" in
    .git/*|.github_token|mister_extras_report.json|EXTRAS_SHA256SUMS) continue ;;
  esac
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  src="$CHECKOUT/$rel"
  dst="$SD_ROOT/$rel"
  size=$(stat -c '%s' "$src" 2>/dev/null || stat -f '%z' "$src" 2>/dev/null || echo 0)

  if [ -f "$dst" ]; then
    dst_hash=$(sha256sum "$dst" 2>/dev/null | awk '{print $1}')
    src_hash=$(sha256sum "$src" 2>/dev/null | awk '{print $1}')
    if [ -n "$dst_hash" ] && [ -n "$src_hash" ] && [ "$dst_hash" = "$src_hash" ]; then
      UNCHANGED_COUNT=$((UNCHANGED_COUNT + 1))
      continue
    fi
    echo "  UPDATE: $rel"
    CHANGED_COUNT=$((CHANGED_COUNT + 1))
  else
    echo "  NEW:    $rel"
    NEW_COUNT=$((NEW_COUNT + 1))
  fi

  mkdir -p "$dst" 2>/dev/null || mkdir -p "$(dirname "$dst")"
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst" || { echo "ERROR: Could not copy $rel"; exit 1; }
  TOTAL_BYTES=$((TOTAL_BYTES + size))
done < <(find . -type f -not -path './.git/*' -print0)

echo "[3/4] Updating files..."
echo "  New files:       $NEW_COUNT"
echo "  Changed files:   $CHANGED_COUNT"
echo "  Unchanged files: $UNCHANGED_COUNT"
echo "  Total repository files checked: $TOTAL_COUNT"
echo "  Downloaded/copied this run: $((NEW_COUNT + CHANGED_COUNT))"

if [ "$TOTAL_BYTES" -gt 0 ]; then
  awk -v b="$TOTAL_BYTES" 'BEGIN { printf "  Data copied: %.2f GiB\n", b/1024/1024/1024 }'
else
  echo "  Data copied: 0 bytes"
fi

echo "[4/4] Pull complete."
if [ "$NEW_COUNT" -eq 0 ] && [ "$CHANGED_COUNT" -eq 0 ]; then
  echo "Everything from ButtHole is already up to date on this SD card."
else
  echo "Only new/changed files were copied."
  echo "Local files that are not in ButtHole were NOT deleted."
fi
