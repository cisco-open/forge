$ErrorActionPreference = "Stop"

Write-Host "Cleaning Windows image before AMI capture"

$paths = @(
  "C:\Temp",
  "C:\Windows\Temp",
  "C:\ProgramData\Amazon\EC2Launch\log",
  "C:\ProgramData\Amazon\EC2-Windows\Launch\Log",
  "C:\ProgramData\Amazon\SSM\Logs"
)

foreach ($path in $paths) {
  if (Test-Path $path) {
    Write-Host "Cleaning $path"
    Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Start-Sleep -Seconds 5

$v1Init = "C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts\InitializeInstance.ps1"
$v1Sysprep = "C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts\SysprepInstance.ps1"
$v2Exe = "C:\Program Files\Amazon\EC2Launch\ec2launch.exe"

if (Test-Path $v1Init) {
  Write-Host "Detected EC2Launch v1"
  & $v1Init -Schedule

  if (-not (Test-Path $v1Sysprep)) {
    throw "SysprepInstance.ps1 not found for EC2Launch v1"
  }

  & $v1Sysprep -NoShutdown
}
elseif (Test-Path $v2Exe) {
  Write-Host "Detected EC2Launch v2"
  & $v2Exe reset --block
  & $v2Exe sysprep --shutdown --block
}
else {
  throw "Unsupported EC2Launch version"
}
