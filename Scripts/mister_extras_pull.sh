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

echo "[1/3] Downloading latest ButtHole repository..."
git clone --depth 1 --branch main https://github.com/modology/ButtHole.git "$CHECKOUT" || { echo "ERROR: Download failed."; exit 1; }
echo "[2/3] Copying files to /media/fat..."
cd "$CHECKOUT" || exit 1
find . -type f -not -path './.git/*' -print0 | while IFS= read -r -d '' f; do
  rel="${f#./}"
  case "$rel" in
    .github_token|mister_extras_report.json|EXTRAS_SHA256SUMS) continue ;;
  esac
  mkdir -p "$SD_ROOT/$(dirname "$rel")"
  cp -f "$f" "$SD_ROOT/$rel"
done

echo "[3/3] Pull complete."
echo "New files and updates from modology/ButtHole are now on the SD card."
