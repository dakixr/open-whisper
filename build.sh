#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-OpenWhisper.xcodeproj}"
SCHEME="${SCHEME:-OpenWhisper}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/openwhisper-derived}"
DIST_DIR="${DIST_DIR:-./dist}"

echo "Building ${SCHEME} (${CONFIGURATION})…"
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  build

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/OpenWhisper.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "Build succeeded but app not found at: ${APP_PATH}" >&2
  exit 1
fi

mkdir -p "${DIST_DIR}"
rm -rf "${DIST_DIR}/OpenWhisper.app"
cp -R "${APP_PATH}" "${DIST_DIR}/OpenWhisper.app"

echo "App: ${DIST_DIR}/OpenWhisper.app"

