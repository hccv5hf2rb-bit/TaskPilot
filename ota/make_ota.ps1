# 生成企业分发用的 OTA 页面（manifest.plist + index.html）
#
# 用法（在 Windows PowerShell 里跑）：
#   .\make_ota.ps1 -BaseUrl "https://你的域名/taskpilot/" -IpaPath "C:\path\to\TaskPilot.ipa"
#
# 生成的 ota-dist\ 目录里会有三个文件，一起传到你自己的 HTTPS 站点上：
#   manifest.plist
#   index.html
#   TaskPilot.ipa
#
# 然后手机用 Safari 打开  https://你的域名/taskpilot/  点「安装」即可。

param(
    [Parameter(Mandatory = $true)][string]$BaseUrl,
    [string]$Title    = 'TaskPilot',
    [string]$BundleId = 'com.taskpilot.app',
    [string]$Version  = '1.0',
    [string]$IpaName  = 'TaskPilot.ipa',
    [string]$IpaPath  = '',
    [string]$OutDir   = 'ota-dist'
)

if (-not $BaseUrl.StartsWith('https://')) {
    Write-Warning "苹果要求分发地址必须是 HTTPS，当前 $BaseUrl 在手机端会被拒绝安装。"
}
if (-not $BaseUrl.EndsWith('/')) { $BaseUrl = $BaseUrl + '/' }

$ManifestUrl = $BaseUrl + 'manifest.plist'
$IpaUrl      = $BaseUrl + $IpaName

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# ---- manifest.plist ----
$manifestTemplate = @'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>items</key>
    <array>
        <dict>
            <key>assets</key>
            <array>
                <dict>
                    <key>kind</key>
                    <string>software-package</string>
                    <key>url</key>
                    <string>@IPA_URL@</string>
                </dict>
            </array>
            <key>metadata</key>
            <dict>
                <key>bundle-identifier</key>
                <string>@BUNDLE_ID@</string>
                <key>bundle-version</key>
                <string>@VERSION@</string>
                <key>kind</key>
                <string>software</string>
                <key>title</key>
                <string>@TITLE@</string>
            </dict>
        </dict>
    </array>
</dict>
</plist>
'@

$manifest = $manifestTemplate.Replace('@IPA_URL@', $IpaUrl).
    Replace('@BUNDLE_ID@', $BundleId).
    Replace('@VERSION@', $Version).
    Replace('@TITLE@', $Title)

Set-Content -Path (Join-Path $OutDir 'manifest.plist') -Value $manifest -Encoding utf8

# ---- index.html ----
$htmlTemplate = @'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>@TITLE@ 安装</title>
<style>
*{box-sizing:border-box}
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0b0c10;color:#f2f2f7;font-family:-apple-system,"SF Pro Text","PingFang SC",sans-serif;padding:24px}
.card{width:100%;max-width:420px;background:#16181d;border-radius:24px;padding:34px 24px;text-align:center;box-shadow:0 20px 60px rgba(0,0,0,.5)}
.icon{width:88px;height:88px;border-radius:22px;background:linear-gradient(145deg,#ff9f0a,#ff6a00);display:flex;align-items:center;justify-content:center;margin:0 auto 20px;font-size:40px}
h1{font-size:22px;margin:0 0 6px}
.sub{color:#8e8e93;font-size:14px;margin:0 0 28px}
.btn{display:block;padding:16px;border-radius:16px;background:#0a84ff;color:#fff;text-decoration:none;font-size:17px;font-weight:600}
.btn:active{opacity:.7}
.tip{margin-top:22px;font-size:13px;color:#8e8e93;line-height:1.65;text-align:left}
.tip b{color:#f2f2f7;font-weight:600}
</style>
</head>
<body>
<div class="card">
  <div class="icon">⚡️</div>
  <h1>@TITLE@</h1>
  <p class="sub">版本 @VERSION@ · 企业签名</p>
  <a class="btn" href="itms-services://?action=download-manifest&amp;url=@MANIFEST_URL@">安装</a>
  <div class="tip">
    必须用 <b>Safari</b> 打开本页，微信 / QQ 的内置浏览器不支持安装。<br><br>
    首次打开若提示「未受信任的企业级开发者」，到 <b>设置 → 通用 → VPN 与设备管理</b> 信任对应证书后再打开。
  </div>
</div>
</body>
</html>
'@

$html = $htmlTemplate.Replace('@TITLE@', $Title).
    Replace('@VERSION@', $Version).
    Replace('@MANIFEST_URL@', $ManifestUrl)

Set-Content -Path (Join-Path $OutDir 'index.html') -Value $html -Encoding utf8

# ---- 拷贝 ipa ----
if ($IpaPath -and (Test-Path $IpaPath)) {
    Copy-Item -LiteralPath $IpaPath -Destination (Join-Path $OutDir $IpaName) -Force
    Write-Host "已复制 ipa 到 $OutDir\$IpaName"
} else {
    Write-Host "记得把签好名的 $IpaName 也放进 $OutDir\"
}

Write-Host ""
Write-Host "完成，$OutDir 里应包含：manifest.plist / index.html / $IpaName"
Write-Host "上传到你自己的 HTTPS 站点后，手机 Safari 打开： $BaseUrl"
