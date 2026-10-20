# Uploads new or changed WAVs in assets/audio/*.wav to Roblox as Audio assets via the Open Cloud
# Assets API and records the IDs in assets/audio-ids.json (name -> { assetId, hash }).
# A changed file is uploaded as a new asset (audio can't be updated in place).
#
# Usage:  powershell -ExecutionPolicy Bypass -File tools/upload-audio.ps1
# Needs:  .roblox-api-key (Assets read+write) and assets/upload.config.json.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$audioDir = Join-Path $root "assets\audio"
$idsPath = Join-Path $root "assets\audio-ids.json"
$configPath = Join-Path $root "assets\upload.config.json"
$keyPath = Join-Path $root ".roblox-api-key"
$api = "https://apis.roblox.com/assets/v1"

if (-not (Test-Path $keyPath)) { throw "Missing .roblox-api-key" }
$config = Get-Content $configPath -Raw | ConvertFrom-Json
# The key goes to curl through a header file so it never appears on a command line.
$headerFile = [IO.Path]::GetTempFileName()
$key = (Get-Content $keyPath -Raw).Trim()
[IO.File]::WriteAllText($headerFile, "x-api-key: $key`n")
$key = $null

function Invoke-Curl([string[]]$curlArgs) {
	$out = & curl.exe -s -w "`n%{http_code}" -H "@$headerFile" @curlArgs
	$lines = ($out -join "`n") -split "`n"
	$code = [int]$lines[-1]
	$body = ($lines[0..($lines.Length - 2)] -join "`n")
	if ($code -lt 200 -or $code -ge 300) { throw "HTTP $code : $body" }
	return $body | ConvertFrom-Json
}

function Wait-Operation($op) {
	$id = ($op.path -split "/")[-1]
	for ($i = 0; $i -lt 90; $i++) {
		if ($op.done) {
			if ($op.error) { throw "Upload failed: $($op.error | ConvertTo-Json -Compress)" }
			return $op.response
		}
		Start-Sleep -Seconds 2
		$op = Invoke-Curl @("$api/operations/$id")
	}
	throw "Timed out waiting for operation $id"
}

$ids = [ordered]@{}
if (Test-Path $idsPath) {
	(Get-Content $idsPath -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object {
		$ids[$_.Name] = [ordered]@{ assetId = [string]$_.Value.assetId; hash = [string]$_.Value.hash }
	}
}
$creator = if ($config.creatorType -eq "group") { @{ groupId = [string]$config.creatorId } } else { @{ userId = [string]$config.creatorId } }

try {
	foreach ($file in Get-ChildItem $audioDir -Filter *.wav) {
		$name = $file.BaseName
		$hash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash
		if ($ids[$name] -and $ids[$name].hash -eq $hash) { Write-Host "unchanged  $name"; continue }
		$requestFile = [IO.Path]::GetTempFileName()
		$request = @{
			assetType = "Audio"
			displayName = "Monopoly $name"
			description = "Monopoly board game sound effects."
			creationContext = @{ creator = $creator }
		}
		[IO.File]::WriteAllText($requestFile, ($request | ConvertTo-Json -Depth 5 -Compress))
		try {
			$op = Invoke-Curl @("-X", "POST", "$api/assets", "-F", "request=<$requestFile;type=application/json", "-F", "fileContent=@$($file.FullName);type=audio/wav")
		} finally {
			Remove-Item $requestFile -ErrorAction SilentlyContinue
		}
		$result = Wait-Operation $op
		$ids[$name] = [ordered]@{ assetId = [string]$result.assetId; hash = $hash }
		Write-Host "uploaded   $name -> $($result.assetId)"
		[IO.File]::WriteAllText($idsPath, ($ids | ConvertTo-Json -Depth 5))
	}
} finally {
	Remove-Item $headerFile -ErrorAction SilentlyContinue
}
