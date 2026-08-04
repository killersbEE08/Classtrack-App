<#
    build_release.ps1 - Repeatable ClassTrack release build for Google Play.

    Why this exists:
      ClassTrack reads its RevenueCat PUBLIC key at build time via
      --dart-define (see lib/features/subscription/domain/pro_constants.dart).
      If you forget to pass it, ProConstants.enabled is false and the app ships
      with NO paywall (everything free forever). This script makes the correct
      build the only build you run.

    The RevenueCat PUBLIC SDK key (goog_... / appl_...) is NOT a secret. It is
    safe to ship inside the client binary. It is different from the RevenueCat
    SECRET API key and from the webhook auth secret; never put those here.

    USAGE (PowerShell, from the project root):

      # Recommended: keep the key in an env var so it is not in your history.
      $env:REVENUECAT_ANDROID_KEY = "goog_xxxxxxxxxxxxxxxxxxxx"
      ./tool/build_release.ps1

      # Or pass it explicitly:
      ./tool/build_release.ps1 -AndroidKey "goog_xxxxxxxxxxxxxxxxxxxx"

      # Build an APK instead of an AAB (for sideloading during testing):
      ./tool/build_release.ps1 -Apk

    OUTPUT:
      AAB (upload to Play):  build/app/outputs/bundle/release/app-release.aab
      APK (-Apk):            build/app/outputs/flutter-apk/app-release.apk
#>

[CmdletBinding()]
param(
    [string]$AndroidKey = $env:REVENUECAT_ANDROID_KEY,
    [string]$IosKey = $env:REVENUECAT_IOS_KEY,
    [switch]$Apk,
    [switch]$Ios
)

$ErrorActionPreference = "Stop"

# Always run from the project root (the folder that contains pubspec.yaml).
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Fail($msg) {
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
}

# --- Validate the RevenueCat key ------------------------------------------
$key = if ($Ios) { $IosKey } else { $AndroidKey }
$expectedPrefix = if ($Ios) { "appl_" } else { "goog_" }
$envVarName = if ($Ios) { "REVENUECAT_IOS_KEY" } else { "REVENUECAT_ANDROID_KEY" }
$paramName = if ($Ios) { "-IosKey" } else { "-AndroidKey" }

if ([string]::IsNullOrWhiteSpace($key)) {
    Fail "No RevenueCat key provided. Set env var $envVarName or pass $paramName. Building without it would ship the app with NO paywall."
}

if ($key.StartsWith("test_")) {
    Fail "That looks like a RevenueCat TEST key (test_...). A test key makes the SDK show a Wrong API Key dialog and force-close a real build. Use the platform PUBLIC key ($expectedPrefix...)."
}

if (-not $key.StartsWith($expectedPrefix)) {
    Write-Host "WARNING: key does not start with $expectedPrefix -- double-check you are using the correct platform PUBLIC key." -ForegroundColor Yellow
}

# --- Build ----------------------------------------------------------------
Write-Host "==> flutter pub get" -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { Fail "flutter pub get failed." }

$defines = @("--dart-define=REVENUECAT_ANDROID_KEY=$AndroidKey")
if (-not [string]::IsNullOrWhiteSpace($IosKey)) {
    $defines += "--dart-define=REVENUECAT_IOS_KEY=$IosKey"
}

if ($Ios) {
    Write-Host "==> flutter build ipa (release)" -ForegroundColor Cyan
    flutter build ipa --release @defines
}
elseif ($Apk) {
    Write-Host "==> flutter build apk (release)" -ForegroundColor Cyan
    flutter build apk --release @defines
}
else {
    Write-Host "==> flutter build appbundle (release)" -ForegroundColor Cyan
    flutter build appbundle --release @defines
}
if ($LASTEXITCODE -ne 0) { Fail "flutter build failed." }

# --- Report artifact path -------------------------------------------------
$artifact = if ($Ios) {
    "build/ios/ipa/*.ipa"
}
elseif ($Apk) {
    "build/app/outputs/flutter-apk/app-release.apk"
}
else {
    "build/app/outputs/bundle/release/app-release.aab"
}

Write-Host ""
Write-Host "Build complete." -ForegroundColor Green
Write-Host "Artifact: $artifact"
Write-Host "Upload the .aab to Play Console -> Test and release -> your track."
