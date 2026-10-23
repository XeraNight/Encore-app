#!/bin/zsh
# Archives Encore and uploads it to App Store Connect, from where it goes to TestFlight.
# The build number is the git commit count, the same for the app and the widget, so it always grows and
# tells which code a build has. Signing and the upload use the Apple account signed in to Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

build=$(git rev-list --count HEAD)
out="${TMPDIR:-/tmp}/encore-testflight-$build"
rm -rf "$out"
mkdir -p "$out"

cat > "$out/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>teamID</key>
	<string>2MD5BS4DLM</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST

echo "Archiving build $build…"
xcodebuild -project Encore.xcodeproj -scheme Encore -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$out/Encore.xcarchive" \
  CURRENT_PROJECT_VERSION="$build" -allowProvisioningUpdates archive

echo "Uploading build $build…"
xcodebuild -exportArchive -archivePath "$out/Encore.xcarchive" \
  -exportOptionsPlist "$out/ExportOptions.plist" -exportPath "$out/export" -allowProvisioningUpdates

echo "Build $build is uploaded. App Store Connect processes it in 10 to 20 minutes."
