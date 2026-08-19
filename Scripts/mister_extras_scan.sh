#!/bin/bash
set -u
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SD_ROOT="/media/fat"
PYTHON="${PYTHON:-python3}"
TOKEN_FILE="$SCRIPT_DIR/.github_token"
CHECKOUT="$SD_ROOT/.mister_extras_github"
TMP_TOKEN="/tmp/.mister_extras_github_token"
TMP_CHECKOUT="/tmp/.mister_extras_github_checkout"
STAGE="$SD_ROOT/MiSTer_Extras"
TOKEN_MOVED=0
CHECKOUT_MOVED=0
restore_state() {
  if [ "$TOKEN_MOVED" = 1 ] && [ -f "$TMP_TOKEN" ]; then mv -f "$TMP_TOKEN" "$TOKEN_FILE"; fi
  if [ "$CHECKOUT_MOVED" = 1 ] && [ -d "$TMP_CHECKOUT" ]; then mv -f "$TMP_CHECKOUT" "$CHECKOUT"; fi
}
trap restore_state EXIT INT TERM
if [ -f "$TOKEN_FILE" ]; then mv -f "$TOKEN_FILE" "$TMP_TOKEN"; TOKEN_MOVED=1; fi
if [ -d "$CHECKOUT" ]; then mv -f "$CHECKOUT" "$TMP_CHECKOUT"; CHECKOUT_MOVED=1; fi

echo "========================================"
echo "       MiSTer Extras Scanner"
echo "========================================"
echo
echo "This scanner will scan the ENTIRE SD card."
echo
echo "[1/2] Scanning and staging extras..."
"$PYTHON" "$SCRIPT_DIR/mister_extras_scan.py" --stage
scan_rc=$?
restore_state
TOKEN_MOVED=0
CHECKOUT_MOVED=0
[ "$scan_rc" -eq 0 ] || { echo; echo "Scan failed. Nothing was uploaded."; exit "$scan_rc"; }

echo
echo "========================================"
echo "Scan and staging complete."
echo "========================================"
echo
echo "Staged files are in: $STAGE"
echo "Do you want to commit these files to the ButtHole GitHub repository?"
echo "This will create a Git commit and push it to modology/ButtHole."
echo
echo -n "Commit and push to GitHub? [y/N]: "
read -r answer
case "$answer" in
  y|Y|yes|YES|Yes) ;;
  *) echo "No upload selected. Files remain staged locally."; exit 0;;
esac

if [ ! -f "$TOKEN_FILE" ]; then
  echo "ERROR: $TOKEN_FILE was not found."
  echo "Copy your GitHub token to that location before committing."
  exit 1
fi
TOKEN="$(tr -d '\r\n' < "$TOKEN_FILE")"
[ -n "$TOKEN" ] || { echo "ERROR: GitHub token file is empty."; exit 1; }
chmod 600 "$TOKEN_FILE" 2>/dev/null || true

ASKPASS="/tmp/.mister_extras_askpass_$$"
cat > "$ASKPASS" <<'ASKPASS_EOF'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' "git" ;;
  *Password*) printf '%s\n' "$GITHUB_TOKEN" ;;
  *) printf '%s\n' "$GITHUB_TOKEN" ;;
esac
ASKPASS_EOF
chmod 700 "$ASKPASS"
export GITHUB_TOKEN="$TOKEN"
export GIT_ASKPASS="$ASKPASS"
export GIT_TERMINAL_PROMPT=0
REPO="https://github.com/modology/ButtHole.git"

cleanup_askpass() { rm -f "$ASKPASS"; unset GITHUB_TOKEN GIT_ASKPASS GIT_TERMINAL_PROMPT; }
trap cleanup_askpass EXIT INT TERM

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is not installed on this MiSTer."
  exit 1
fi

echo
echo "[GitHub 1/5] Checking repository..."
if [ -d "$CHECKOUT/.git" ]; then
  echo "Existing ButtHole checkout found. Pulling latest main..."
  if ! git -C "$CHECKOUT" pull --ff-only origin main; then
    echo "ERROR: Could not update the local ButtHole checkout."
    exit 1
  fi
else
  rm -rf "$CHECKOUT"
  echo "First upload: cloning modology/ButtHole..."
  if ! git clone --depth 1 --branch main "$REPO" "$CHECKOUT"; then
    echo "ERROR: Could not clone the ButtHole repository."
    exit 1
  fi
fi

echo "[GitHub 2/5] Copying staged files into repository..."
mkdir -p "$CHECKOUT"
cp -a "$STAGE/." "$CHECKOUT/"
rm -f "$CHECKOUT/.github_token" "$CHECKOUT/mister_extras_report.json" "$CHECKOUT/EXTRAS_SHA256SUMS"

cd "$CHECKOUT" || exit 1
if [ -z "$(git status --porcelain)" ]; then
  echo "[GitHub] No changes to commit."
  exit 0
fi

echo "[GitHub 3/5] Staging changes..."
git add -A

echo "[GitHub 4/5] Creating commit..."
git config user.name "ButtHole MiSTer Scanner"
git config user.email "scanner@butthole.invalid"
git commit -m "Add MiSTer extras from SD card"

echo "[GitHub 5/5] Pushing to modology/ButtHole..."
git push origin main

echo
echo "========================================"
echo "       GitHub upload complete!"
echo "========================================"
