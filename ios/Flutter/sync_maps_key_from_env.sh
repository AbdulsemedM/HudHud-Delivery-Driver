#!/bin/sh
# Writes ios/Flutter/LocalSecrets.xcconfig from the project-root .env
# so Xcode can substitute $(GOOGLE_MAPS_API_KEY) into Info.plist.

set -e

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
FLUTTER_DIR="$SCRIPT_DIR"
IOS_DIR="$(CDPATH= cd -- "$FLUTTER_DIR/.." && pwd)"
PROJECT_ROOT="$(CDPATH= cd -- "$IOS_DIR/.." && pwd)"

if [ -n "${SRCROOT:-}" ]; then
  PROJECT_ROOT="$(CDPATH= cd -- "$SRCROOT/.." && pwd)"
  FLUTTER_DIR="$SRCROOT/Flutter"
fi

ENV_FILE="$PROJECT_ROOT/.env"
OUT_FILE="$FLUTTER_DIR/LocalSecrets.xcconfig"

KEY=""
if [ -f "$ENV_FILE" ]; then
  KEY="$(grep -E '^[[:space:]]*GOOGLE_MAPS_API_KEY[[:space:]]*=' "$ENV_FILE" | tail -n 1 | sed -E 's/^[[:space:]]*GOOGLE_MAPS_API_KEY[[:space:]]*=[[:space:]]*//; s/[[:space:]]*$//; s/^["'\'']//; s/["'\'']$//')"
fi

{
  echo "// Generated from project-root .env — do not commit."
  echo "GOOGLE_MAPS_API_KEY=${KEY}"
} > "$OUT_FILE"
