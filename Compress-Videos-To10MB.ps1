#!/usr/bin/env pwsh
<#
    Compress-Videos-To10MB.ps1

    - Prompts for:
        1) Source directory (also where compressed files will live)
        2) Backup directory (where originals will be moved)

    - Recursively scans for video files
    - Compresses them using ffmpeg/ffprobe so each file is ~<= 10 MB
    - Replaces the source file with the compressed one
    - Moves the original into the backup directory, preserving folder structure
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-CommandExists {
    param(
        [Parameter(Mandatory)]
        [string] $Name
    )
    try {
        $null = Get-Command $Name -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

Write-Host "=== Compress videos to ~10 MB and back up originals ===" -ForegroundColor Cyan

# --- Check dependencies ---
if (-not (Test-CommandExists -Name 'ffmpeg')) {
    Write-Error "ffmpeg is not available in PATH. Please install it and try again."
    exit 1
}
if (-not (Test-CommandExists -Name 'ffprobe')) {
    Write-Error "ffprobe is not available in PATH. It usually comes with ffmpeg. Please ensure it's accessible."
    exit 1
}

# --- Ask for directories ---
$sourceRoot = Read-Host "Enter the SOURCE directory (videos live here and will be REPLACED with compressed ones)"
$backupRoot = Read-Host "Enter the BACKUP directory (originals will be MOVED here)"

$sourceRoot = [IO.Path]::GetFullPath($sourceRoot)
$backupRoot = [IO.Path]::GetFullPath($backupRoot)

if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    Write-Error "Source directory does not exist: $sourceRoot"
    exit 1
}
if (-not (Test-Path -LiteralPath $backupRoot -PathType Container)) {
    Write-Host "Backup directory does not exist. Creating: $backupRoot"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
}

if ($sourceRoot -eq $backupRoot) {
    Write-Error "Source and backup directories CANNOT be the same."
    exit 1
}

# Prevent backup being inside source (otherwise script will chase its own tail)
if ($backupRoot.StartsWith($sourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "Backup directory cannot be a subfolder of the source directory. Please choose a different backup location."
    exit 1
}

Write-Host "`nSource : $sourceRoot"
Write-Host "Backup : $backupRoot`n"

$confirm = Read-Host "Proceed? (Y/N)"
if ($confirm -notin @('Y','y','Yes','yes')) {
    Write-Host "Aborted by user."
    exit 0
}

# --- Settings ---
$maxSizeMB        = 10
$maxSizeBytes     = [int64]($maxSizeMB * 1MB)
# Use a safety factor so we stay comfortably below 10 MB
$targetSizeBytes  = [int64]($maxSizeBytes * 0.95)

# Min video bitrate to avoid absolutely cursed quality (in bits/sec)
$minVideoBitrate  = 200000      # 200 kbps
$audioBitrateBits = 128000      # 128 kbps (fixed)

# File extensions we treat as "video"
$videoExtensions = @(
    '.mp4', '.mkv', '.mov', '.avi', '.webm', '.m4v'
)

Write-Host "Scanning for video files..." -ForegroundColor Cyan

$files = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Where-Object {
    $_.Extension -match '\.(mp4|mkv|mov|avi|webm)$'
})

if (-not $files) {
    Write-Host "No video files found under $sourceRoot" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($files.Count) video file(s)." -ForegroundColor Green

# --- Helper: get duration in seconds via ffprobe ---
function Get-VideoDurationSeconds {
    param(
        [Parameter(Mandatory)]
        [string] $FilePath
    )

    $procInfo = New-Object System.Diagnostics.ProcessStartInfo
    $procInfo.FileName  = "ffprobe"
    $procInfo.Arguments = "-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 `"$FilePath`""
    $procInfo.RedirectStandardOutput = $true
    $procInfo.RedirectStandardError  = $true
    $procInfo.UseShellExecute        = $false
    $procInfo.CreateNoWindow         = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $procInfo
    $null = $proc.Start()
    $output = $proc.StandardOutput.ReadToEnd().Trim()
    $err    = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    if ([string]::IsNullOrWhiteSpace($output)) {
        throw "Could not get duration for '$FilePath'. ffprobe error: $err"
    }

    [double]$duration = 0
    if (-not [double]::TryParse($output, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$duration)) {
        throw "Failed to parse duration '$output' for '$FilePath'."
    }

    if ($duration -le 0) {
        throw "Invalid duration ($duration) for '$FilePath'."
    }

    return $duration
}

# --- Processing loop ---
$index = 0
$failures = @()

foreach ($file in $files) {
    $index++
    Write-Host "`n[$index/$($files.Count)] Processing: $($file.FullName)" -ForegroundColor Cyan

    try {
        $originalSizeBytes = $file.Length
        $originalSizeMB    = [Math]::Round($originalSizeBytes / 1MB, 2)

        Write-Host "  Original size: $originalSizeMB MB"

        # If the file is already <= 10 MB, we just back it up and skip re-encoding
        if ($originalSizeBytes -le $maxSizeBytes) {
            Write-Host "  Already <= ${maxSizeMB}MB. Backing up original without re-encoding..." -ForegroundColor Yellow

            $relativePath = $file.FullName.Substring($sourceRoot.Length).TrimStart('\','/')
            $backupPath   = Join-Path $backupRoot $relativePath
            $backupDir    = Split-Path $backupPath -Parent

            if (-not (Test-Path -LiteralPath $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }

            Copy-Item -LiteralPath $file.FullName -Destination $backupPath -Force
            Write-Host "  Backup created at: $backupPath"
            continue
        }

        # Get duration
        $duration = Get-VideoDurationSeconds -FilePath $file.FullName
        Write-Host ("  Duration: {0:N2} seconds" -f $duration)

        # Calculate target total bitrate for ~ targetSizeBytes
        # totalBits = targetSizeBytes * 8
        # bitrate   = totalBits / duration
        $totalBits   = [double]$targetSizeBytes * 8.0
        $maxBitrate  = [double]$totalBits / $duration    # bits/sec (video + audio)

        if ($maxBitrate -le $audioBitrateBits + $minVideoBitrate) {
            Write-Host "  WARNING: Video is too long to reasonably fit under ${maxSizeMB}MB with decent quality." -ForegroundColor Yellow
            Write-Host "           Will still attempt with minimum video bitrate." -ForegroundColor Yellow
            $videoBitrateBits = $minVideoBitrate
        }
        else {
            $videoBitrateBits = $maxBitrate - $audioBitrateBits
            if ($videoBitrateBits -lt $minVideoBitrate) {
                $videoBitrateBits = $minVideoBitrate
            }
        }

        $videoKbps = [int]([Math]::Floor($videoBitrateBits / 1000.0))
        $audioKbps = 128  # fixed for now

        Write-Host "  Target video bitrate: $videoKbps kbps"
        Write-Host "  Audio bitrate        : $audioKbps kbps"

        # Temp output path
        $tempPath = "$($file.FullName).tmp_compressed.mp4"

        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }

        # ffmpeg re-encode using HEVC (libx265) + AAC
        # NOTE: Change libx265 -> libx264 if you ever need wider compatibility over smaller size.
        Write-Host "  Running ffmpeg..."

        # Build a single argument string with proper quoting for paths
        $videoKbpsStr    = "${videoKbps}k"
        $bufsizeKbpsStr  = "$([int]($videoKbps * 2))k"
        $audioKbpsStr    = "${audioKbps}k"

        $ffmpegArgs = "-y -i `"$($file.FullName)`" " +
              "-c:v hevc_amf -usage transcoding -quality speed -rc cbr " +
              "-b:v $videoKbpsStr -maxrate $videoKbpsStr -bufsize $bufsizeKbpsStr " +
              "-c:a aac -b:a $audioKbpsStr -movflags +faststart " +
              "`"$tempPath`""

        Write-Host "  ffmpeg $ffmpegArgs" -ForegroundColor DarkGray

        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "ffmpeg"
        $processInfo.Arguments = $ffmpegArgs
        $processInfo.RedirectStandardOutput = $false
        $processInfo.RedirectStandardError  = $false
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $false

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $null = $process.Start()
        $process.WaitForExit()

        if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $tempPath)) {
           throw "ffmpeg failed with exit code $($process.ExitCode). See ffmpeg output above for details."
        }


        $compressedInfo = Get-Item -LiteralPath $tempPath
        $compressedSizeBytes = $compressedInfo.Length
        $compressedSizeMB    = [Math]::Round($compressedSizeBytes / 1MB, 2)

        Write-Host "  Compressed size: $compressedSizeMB MB"

        if ($compressedSizeBytes -gt $maxSizeBytes) {
            Write-Host "  WARNING: Compressed file is still > ${maxSizeMB}MB. Keeping it anyway, but you may want to re-check this file." -ForegroundColor Yellow
        }

        # Build backup path mirroring the original structure
        $relativePath = $file.FullName.Substring($sourceRoot.Length).TrimStart('\','/')
        $backupPath   = Join-Path $backupRoot $relativePath
        $backupDir    = Split-Path $backupPath -Parent

        if (-not (Test-Path -LiteralPath $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }

        # Move original to backup, then move temp compressed file to original location
        Move-Item -LiteralPath $file.FullName -Destination $backupPath -Force
        Move-Item -LiteralPath $tempPath -Destination $file.FullName -Force

        $savedMB = [Math]::Round(($originalSizeBytes - $compressedSizeBytes) / 1MB, 2)
        Write-Host "  ✅ Done. Saved ~${savedMB} MB. Original moved to: $backupPath" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
        $failures += $file.FullName
        # Clean up temp if it exists
        try {
            if (Test-Path -LiteralPath $tempPath) {
                Remove-Item -LiteralPath $tempPath -Force
            }
        } catch {}
    }
}

Write-Host "`n=== Completed ===" -ForegroundColor Cyan

if ($failures.Count -gt 0) {
    Write-Host "The following files failed to process:" -ForegroundColor Yellow
    $failures | ForEach-Object { Write-Host " - $_" }
}
else {
    Write-Host "All files processed successfully." -ForegroundColor Green
}
