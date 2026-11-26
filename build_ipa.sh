#!/usr/bin/env bash
# 在 macOS 上打包 IPA。需要：Xcode + xcodegen（brew install xcodegen）
#
# 用法：
#   ./build_ipa.sh <你的10位TeamID> [BundleID]
# 例：
#   ./build_ipa.sh ABCDE12345 com.yourname.taskpilot
#
# Team ID 在 developer.apple.com → Account → Membership details 里。

set -euo pipefail

TEAM_ID="${1:-}"
BUNDLE_ID="${2:-com.taskpilot.app}"
SCHEME="TaskPilot"
OUT="build"

if [[ -z "$TEAM_ID" ]]; then
  echo "用法: ./build_ipa.sh <TeamID> [BundleID]"
  exit 1
fi

command -v xcodegen >/dev/null 2>&1 || {
  echo "缺少 xcodegen，先执行：brew install xcodegen"
  exit 1
}

mkdir -p "$OUT"
rm -rf "$OUT/TaskPilot.xcarchive" "$OUT/ipa"

echo "==> 生成 Xcode 工程"
xcodegen generate --spec project.yml

echo "==> Archive（自动签名，会联网拉描述文件）"
xcodebuild archive \
  -project TaskPilot.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$OUT/TaskPilot.xcarchive" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"

echo "==> 导出 IPA"
cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>development</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>compileBitcode</key>
  <false/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$OUT/TaskPilot.xcarchive" \
  -exportPath "$OUT/ipa" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -allowProvisioningUpdates

echo "==> 完成"
ls -lh "$OUT/ipa"
