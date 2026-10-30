#!/bin/sh
# Builds "Roast Room.app" on the Desktop (macOS, needs Xcode or its command line tools).
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$HOME/Desktop/Roast Room.app"
TMP="$(mktemp -d)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$TMP/icon.iconset"
swiftc -O "$ROOT/app/desktop/RoastRoom.swift" -o "$APP/Contents/MacOS/RoastRoom"

# Icon: the brand mark, white on the room's dark canvas.
sips -s format png -Z 600 "$ROOT/app/public/brand/ais-symbol-white.svg" --out "$TMP/mark.png" >/dev/null
sips -p 1024 1024 --padColor 07121C "$TMP/mark.png" --out "$TMP/icon.png" >/dev/null 2>&1
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon.png" --out "$TMP/icon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$TMP/icon.png" --out "$TMP/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/icon.iconset" -o "$APP/Contents/Resources/icon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Roast Room</string>
  <key>CFBundleIdentifier</key><string>local.roastroom</string>
  <key>CFBundleExecutable</key><string>RoastRoom</string>
  <key>CFBundleIconFile</key><string>icon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
  <key>RoastRoomRoot</key><string>$ROOT</string>
</dict></plist>
EOF

codesign --force --sign - "$APP" >/dev/null 2>&1
rm -rf "$TMP"
echo "Built $APP"
