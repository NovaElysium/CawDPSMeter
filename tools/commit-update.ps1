#Requires -Version 5
<#
  commit-update.ps1  --  publish a colleague drop to GitHub

  Workflow:
    1. Colleague sends a ZIP of the whole addon folder via Discord.
    2. Extract it INTO C:\...\Interface\AddOns\CawDPSMeter and overwrite.
       Never delete the folder first, that would remove the .git directory.
    3. Run this script from anywhere:

         .\tools\commit-update.ps1 -Message "rc50: fixed CC segment bug"

  What it does:
    - Restores the .toc metadata lines the ZIP overwrites
      (## Version / ## Author / ## X-License / ## X-Website).
    - Reads the version from the ## Title line and writes it into ## Version.
    - Warns if D.version in the .lua does not match the Title.
    - Shows you the diff, then commits and pushes after you confirm.
#>
param(
    [string]$Message
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

$toc = Join-Path $repo 'CawDPSMeter.toc'
$lua = Join-Path $repo 'CawDPSMeter.lua'

if (-not (Test-Path $toc)) { throw "CawDPSMeter.toc not found in $repo" }

# --- 1. work out the version from the Title line -------------------------------
$tocLines  = [System.IO.File]::ReadAllLines($toc)
$titleLine = $tocLines | Where-Object { $_ -match '^\s*##\s*Title\s*:' } | Select-Object -First 1
if (-not $titleLine) { throw "No '## Title:' line in CawDPSMeter.toc" }

$base = if ($titleLine -match 'v?(\d+\.\d+(?:\.\d+)?)') { $Matches[1] } else { $null }
$rc   = if ($titleLine -match '[Rr][Cc]\s*(\d+)')       { $Matches[1] } else { $null }

if     ($base -and $rc) { $version = "$base-rc$rc" }
elseif ($base)          { $version = $base }
else {
    Write-Warning "Could not read a version from the Title. '## Version:' will be left out."
    $version = $null
}

# --- 2. rebuild the managed metadata block ------------------------------------
$meta = @()
if ($version) { $meta += "## Version: $version" }
$meta += '## Author: NovaElysium'
$meta += '## X-License: MIT'
$meta += '## X-Website: https://github.com/NovaElysium/Caw-DPS-Meter'

$managed  = '^\s*##\s*(Version|Author|X-License|X-Website)\s*:'
$out      = New-Object System.Collections.Generic.List[string]
$inserted = $false
foreach ($line in $tocLines) {
    if ($line -match $managed) { continue }        # drop any old managed lines
    $out.Add($line)
    if (-not $inserted -and $line -match '^\s*##\s*Notes\s*:') {
        $meta | ForEach-Object { $out.Add($_) }
        $inserted = $true
    }
}
if (-not $inserted) {                              # no Notes line: fall back to after Title
    $tmp = New-Object System.Collections.Generic.List[string]
    foreach ($line in $out) {
        $tmp.Add($line)
        if ($line -match '^\s*##\s*Title\s*:') { $meta | ForEach-Object { $tmp.Add($_) } }
    }
    $out = $tmp
}

# --- 3. write .toc back as UTF-8 without BOM, LF endings ---------------------
$text = ($out -join "`n").TrimEnd("`n") + "`n"
[System.IO.File]::WriteAllText($toc, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "toc  -> ## Version: $version, metadata block restored" -ForegroundColor Green

# --- 4. sanity-check D.version in the lua -----------------------------------
if ($version -and (Test-Path $lua)) {
    $luaText = [System.IO.File]::ReadAllText($lua)
    if ($luaText -match 'D\.version\s*=\s*"([^"]*)"') {
        $cur = $Matches[1]
        if ($cur -ne $version) {
            Write-Warning "lua  -> D.version is `"$cur`" but the Title says `"$version`". Not changed automatically."
        } else {
            Write-Host "lua  -> D.version matches ($version)" -ForegroundColor Green
        }
    }
}

# --- 5. show what changed --------------------------------------------------
Write-Host "`n--- git status ---" -ForegroundColor Cyan
git status --short
Write-Host "`n--- diff stat ---" -ForegroundColor Cyan
git diff --stat

# --- 6. confirm, commit, push -------------------------------------------
if (-not $Message) { $Message = Read-Host "`nCommit message" }
if (-not $Message) { Write-Host 'No message given. Nothing committed.' -ForegroundColor Yellow; return }

$answer = Read-Host "`nCommit everything above and push? (y/n)"
if ($answer -ne 'y') { Write-Host 'Stopped. Nothing committed.' -ForegroundColor Yellow; return }

git add -A
git commit -m $Message
git push
Write-Host "`nPushed to origin/main." -ForegroundColor Green
