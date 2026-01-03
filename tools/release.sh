#!/usr/bin/env bash
set -euo pipefail

# Release helper for Strakatá Turistika
# - Bumps version in pubspec.yaml (patch by default; supports minor/major)
# - Runs flutter clean && flutter pub get
# - Runs tools/adb_check.sh (sanity checks) if exists
# - Builds Android App Bundle (.aab) for release
# - Git add/commit/push with provided message
#
# Usage:
#   tools/release.sh "Commit message here"
#   tools/release.sh --minor "Commit message here"
#   tools/release.sh --major "Commit message here"
#

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$PROJECT_DIR/pubspec.yaml"

if [[ ! -f "$PUBSPEC" ]]; then
  echo "error: pubspec.yaml not found at $PUBSPEC" >&2
  exit 1
fi

BUMP="patch"
if [[ "${1:-}" == "--minor" || "${1:-}" == "-m" ]]; then
  BUMP="minor"; shift
elif [[ "${1:-}" == "--major" || "${1:-}" == "-M" ]]; then
  BUMP="major"; shift
fi

if [[ $# -lt 1 ]]; then
  echo "error: commit message required" >&2
  echo "Usage: tools/release.sh [--minor|--major] \"Commit message\"" >&2
  exit 1
fi
COMMIT_MSG="$1"

echo "== Bumping version ($BUMP) in pubspec.yaml =="
current_line=$(grep -E '^version:' "$PUBSPEC" || true)
if [[ -z "$current_line" ]]; then
  echo "error: could not find version: line in pubspec.yaml" >&2
  exit 1
fi

# Parse version: x.y.z+build
version_str=$(echo "$current_line" | awk '{print $2}')
IFS='+.' read -r major minor patch build <<< "$(echo "$version_str" | sed 's/+/\./')"
major=${major:-0}; minor=${minor:-0}; patch=${patch:-0}; build=${build:-0}

case "$BUMP" in
  major) major=$((major+1)); minor=0; patch=0 ;;
  minor) minor=$((minor+1)); patch=0 ;;
  patch) patch=$((patch+1)) ;;
esac
build=$((build+1))
new_version="${major}.${minor}.${patch}+${build}"

# Replace line in-place (portable for macOS/BSD sed)
sed -i '' -E "s/^version: .*/version: ${new_version}/" "$PUBSPEC"
echo "version: ${new_version}"

echo "== Flutter clean & pub get =="
(
  cd "$PROJECT_DIR"
  flutter clean
  flutter pub get
)

echo "== Sanity checks (ADB/keystore) =="
if [[ -x "$PROJECT_DIR/tools/adb_check.sh" ]]; then
  "$PROJECT_DIR/tools/adb_check.sh" || true
else
  echo "warn: tools/adb_check.sh not found or not executable; skipping checks"
fi

echo "== Building Android App Bundle (.aab) =="
(
  cd "$PROJECT_DIR"
  if [[ ! -f "$PROJECT_DIR/android/key.properties" ]]; then
    echo "error: android/key.properties missing. Create it for release signing." >&2
    echo "       Example:" >&2
    echo "       storePassword=YOUR_STORE_PASSWORD" >&2
    echo "       keyPassword=YOUR_KEY_PASSWORD" >&2
    echo "       keyAlias=upload" >&2
    echo "       storeFile=/absolute/path/to/upload-keystore.jks" >&2
    exit 1
  fi
  flutter build appbundle --release -t lib/main.dart
)

echo "== Git commit & push =="
(
  cd "$PROJECT_DIR"
  git add -A
  git commit -m "$COMMIT_MSG" || true
  git push
)

echo "Done. AAB located under: build/app/outputs/bundle/release/"
