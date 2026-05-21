#!/bin/sh
# Re-sign Flutter native-asset frameworks (e.g. objective_c.framework).
#
# Flutter's native-assets build pipeline only ad-hoc signs these frameworks.
# Xcode does NOT re-sign them, because they are not embedded via an
# "Embed Frameworks" / Code-Sign-On-Copy build phase — Flutter's "Thin Binary"
# script rsyncs them in. The result is an ad-hoc signature that the device
# rejects at install time: 0xe8008014 "The executable contains an invalid
# signature."
#
# This phase runs after "Thin Binary" (which embeds the native-asset
# frameworks) and re-signs every embedded framework with the build's real
# code-signing identity. Re-signing an already-correctly-signed framework with
# the same identity is harmless, so sweeping all of them is fine and
# future-proofs against the next native-assets package.
#
# Upstream: flutter/flutter#148051 (native-asset code signing covers macOS
# only, not iOS).

[ "${CODE_SIGNING_REQUIRED:-}" = "NO" ] && exit 0
[ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ] && exit 0

FRAMEWORKS="${CODESIGNING_FOLDER_PATH}/Frameworks"
[ -d "$FRAMEWORKS" ] || exit 0

for FW in "$FRAMEWORKS"/*.framework; do
  [ -d "$FW" ] || continue
  echo "Re-signing $(basename "$FW") with ${EXPANDED_CODE_SIGN_IDENTITY}"
  /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --timestamp=none "$FW" || exit 1
done
