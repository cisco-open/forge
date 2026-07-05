Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $env:RUNNER_VERSION -or [string]::IsNullOrWhiteSpace($env:RUNNER_VERSION)) {
    throw "RUNNER_VERSION environment variable must be set."
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$runnerRoot = "C:\actions-runner"
$tempRoot = if (-not $env:TEMP -or [string]::IsNullOrWhiteSpace($env:TEMP)) {
    [System.IO.Path]::GetTempPath()
} else {
    $env:TEMP
}
$tempDir = Join-Path $tempRoot "gh-runner-install"
$zipPath = Join-Path $tempDir "actions-runner.zip"
$runnerArch = if (-not $env:RUNNER_ARCH -or [string]::IsNullOrWhiteSpace($env:RUNNER_ARCH)) {
    "x64"
} else {
    $env:RUNNER_ARCH
}
$runnerTarballUrl = if (-not $env:RUNNER_TARBALL_URL -or [string]::IsNullOrWhiteSpace($env:RUNNER_TARBALL_URL)) {
    "https://github.com/actions/runner/releases/download/v$($env:RUNNER_VERSION)/actions-runner-win-$runnerArch-$($env:RUNNER_VERSION).zip"
} else {
    $env:RUNNER_TARBALL_URL
}

if (Test-Path -Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

if (Test-Path -Path $runnerRoot) {
    Remove-Item -Path $runnerRoot -Recurse -Force
}
New-Item -Path $runnerRoot -ItemType Directory -Force | Out-Null

Write-Host "Downloading GitHub Actions runner package from $runnerTarballUrl"
if ($PSVersionTable.PSEdition -eq "Desktop") {
    Invoke-WebRequest -Uri $runnerTarballUrl -OutFile $zipPath -UseBasicParsing
} else {
    Invoke-WebRequest -Uri $runnerTarballUrl -OutFile $zipPath
}

Write-Host "Extracting runner archive to $runnerRoot"
Expand-Archive -Path $zipPath -DestinationPath $runnerRoot -Force

if (-not (Test-Path -Path (Join-Path $runnerRoot "config.cmd"))) {
    throw "Runner archive extracted, but config.cmd was not found in $runnerRoot."
}

Remove-Item -Path $tempDir -Recurse -Force
Write-Host "GitHub Actions runner installed to $runnerRoot"
