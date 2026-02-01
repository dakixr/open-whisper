#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-OpenWhisper.xcodeproj}"
SCHEME="${SCHEME:-OpenWhisper}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/openwhisper-derived}"
OUT_DIR="${OUT_DIR:-./dist}"
DMG_NAME="${DMG_NAME:-OpenWhisper.dmg}"

echo "Building ${SCHEME} (${CONFIGURATION})…"
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  build

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/OpenWhisper.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "App not found at: ${APP_PATH}" >&2
  exit 1
fi

STAGING="${DERIVED_DATA_PATH}/dmg-staging"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"
cp -R "${APP_PATH}" "${STAGING}/OpenWhisper.app"
ln -s /Applications "${STAGING}/Applications"

mkdir -p "${OUT_DIR}"

DMG_PATH="${OUT_DIR}/${DMG_NAME}"
rm -f "${DMG_PATH}"

echo "Creating DMG: ${DMG_PATH}"
hdiutil create \
  -volname "OpenWhisper" \
  -srcfolder "${STAGING}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

echo "Done: ${DMG_PATH}"

