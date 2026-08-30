#!/usr/bin/env bash
# Sync assets/sound/notification_sound.mp3 to native notification resources.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/assets/sound/notification_sound.mp3"
ANDROID_DST="$ROOT/android/app/src/main/res/raw/notification_sound.mp3"
IOS_DST="$ROOT/ios/Runner/notification_sound.caf"

if [[ ! -f "$SRC" ]]; then
  echo "Missing source: $SRC" >&2
  exit 1
fi

mkdir -p "$(dirname "$ANDROID_DST")"
cp "$SRC" "$ANDROID_DST"
echo "Synced Android raw: $ANDROID_DST"

if command -v afconvert >/dev/null 2>&1; then
  afconvert "$SRC" "$IOS_DST" -d ima4 -f caff -v
  echo "Synced iOS caf: $IOS_DST"
elif command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -y -i "$SRC" -c:a pcm_s16le "$IOS_DST"
  echo "Synced iOS caf via ffmpeg: $IOS_DST"
else
  echo "Install afconvert (macOS) or ffmpeg to regenerate $IOS_DST" >&2
  exit 1
fi
