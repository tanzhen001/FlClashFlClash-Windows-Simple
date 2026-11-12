$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

foreach ($tool in @('flutter', 'dart', 'go', 'cargo', 'rustc', 'git')) {
    if (!(Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Required tool is missing from PATH - $tool. See WINDOWS_README.md."
    }
}

if (!(Test-Path 'core/Clash.Meta/go.mod')) {
    git submodule set-url core/Clash.Meta https://github.com/chen08209/Clash.Meta.git
    if ($LASTEXITCODE -ne 0) { throw 'Cannot configure core source.' }
    git submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch core source.' }
}

$env:PATH += ";$env:LOCALAPPDATA\Pub\Cache\bin;${env:ProgramFiles(x86)}\Inno Setup 6"

flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed.' }

$original = Get-Content pubspec.yaml -Raw
try {
    $original.Replace('build_assets: true', 'build_assets: false') | Set-Content pubspec.yaml -Encoding utf8
    flutter test test/views/dashboard/windows_dashboard_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'Windows interface tests failed.' }
} finally {
    [System.IO.File]::WriteAllText((Join-Path $PWD 'pubspec.yaml'), $original)
}

dart setup.dart windows --targets exe,zip
if ($LASTEXITCODE -ne 0) { throw 'Windows packaging failed.' }
Write-Host 'Build succeeded. Installer and portable package are under dist/.'
