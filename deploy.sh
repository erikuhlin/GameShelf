#
//  deploy.sh
//  Gameshelf
//
//  Created by Erik Uhlin on 2026-08-26.
//
#!/usr/bin/env bash
set -e

# Rensa alltid Finder-metadata innan bygge
xattr -cr .
# Inställningar
SCHEME_NAME="Gameshelf"        # Byt mot ditt scheme i Xcode
BUNDLE_ID="com.erikuhlin.gameshelf"  # Byt mot din App Bundle ID
UDID="00008120-000C05C41444201E"    # Byt mot ditt iPhone UDID



echo "🔨 Bygger appen..."
xcodebuild build \
  -scheme "$SCHEME_NAME" \
  -destination "id=$UDID" \
  -derivedDataPath ./build \
  -allowProvisioningUpdates

APP_PATH=$(find ./build/Build/Products/Debug-iphoneos -name "*.app" -maxdepth 1)

echo "📲 Installerar på iPhone..."
xcrun devicectl device install app \
  --device "$UDID" \
  "$APP_PATH"

echo "🚀 Startar appen..."
xcrun devicectl device process launch \
  --device "$UDID" \
  "$BUNDLE_ID"

echo "✅ Klart!"
