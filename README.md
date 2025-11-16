# Compress Videos to ~10 MB (PowerShell + FFmpeg + AMD AMF)

A PowerShell automation script that batch-compresses videos to approximately **10 MB or less**, while preserving folder structure, backing up originals, and using **AMD AMF hardware-accelerated HEVC encoding** for fast results.

Ideal for users who need small, shareable video files without sacrificing too much quality.

---

## 📌 Features

- 🔄 **Batch process entire folders + subfolders**
- 🎥 Supports common formats: `.mp4`, `.mkv`, `.mov`, `.avi`, `.webm`, `.m4v`
- ⚡ **Hardware-accelerated HEVC compression** using `hevc_amf`
- 🧮 Automatic bitrate calculation based on **duration + target size**
- 📁 Preserves full folder structure
- 💾 Moves original files to a backup directory
- 🚫 Skips videos already ≤ 10 MB (moves them to backup unchanged)
- 📊 Warns when files cannot realistically fit under 10 MB
- 🧼 Handles file paths with spaces safely
- 🛑 Aborts if backup folder is inside source folder (loop prevention)

---


---

## 🖥 Requirements

| Component | Version | Notes |
|----------|---------|-------|
| **PowerShell Core (pwsh)** | 7.5+ | Script uses strict mode + modern features |
| **FFmpeg** | Full build (2025 or later) | Must include `ffprobe` |
| **AMD Drivers** | Latest | Required for `hevc_amf` encoder |
| **Windows 10 / 11** | Any | Tested on both |

---

## 🔧 Installation Guide

### 1. Install PowerShell 7.5+
```powershell
winget install Microsoft.PowerShell
```
### 2. Install FFmpeg (Full Build)

Download from the official Gyan.dev builds:

https://www.gyan.dev/ffmpeg/builds/

#### Extract FFmpeg to a permanent folder:
C:\Tools\ffmpeg\

#### Add FFmpeg to your PATH:
C:\Tools\ffmpeg\bin


#### Verify installation:
```powershell
ffmpeg -version
ffprobe -version
```
### 3. Place the Script Somewhere Convenient
Ex. C:\Scripts\Compress-Videos-To10MB\scripts\

## 🚀 Usage
### Run From PowerShell 7:
```powershell
pwsh ./Compress-Videos-To10MB.ps1
```
The script will:
1. Ask for a source folder
2. Ask for a backup folder
3. Scan all subfolders
4. Compress or skip based on size
5. Move originals to the backup directory

Example:
```powershell
=== Compress videos to ~10 MB and back up originals ===
Enter the SOURCE directory: Z:\Videos\Raw
Enter the BACKUP directory: Z:\Videos\Backup

Found X video file(s).

[1/X] Processing: Z:\Videos\Raw\clip001.mp4
  Original size: 85.32 MB
  Duration: 14.32 seconds
  Target video bitrate: 420 kbps
  Running ffmpeg...
  Compressed size: 9.58 MB
     Done. Saved ~75.7 MB. Original moved to backup.
```
## 🛠 How It Works (Technical Overview)
The script performs the following:
### 1. Scans for supported video extensions
```powershell
'.mp4', '.mkv', '.mov', '.avi', '.webm', '.m4v'
```
### 2. Uses ffprobe to calculate duration of video
This is Required to compute thee correct bitrate

### 3. Determines a target size
The Default is ~95% of 10MB to avoid going over.

### 4. Calculates bitrate
```powershell
bitrate = (targetSizeBytes * 8) / duration
```
Then:
. Reserve ~128 kbps for audio
. Enforce minimum video bitrate (200 kbps)

### 5. Generates the FFmpeg command
Example:
```powershell
-c:v hevc_amf -usage transcoding -quality speed -rc cbr
-b:v 420k -maxrate 420k -bufsize 840k
-c:a aac -b:a 128k -movflags +faststart
```

### 6. Encodes to a temporary file
Example:
```powershell
clip001.mp4.tmp_compressed.mp4
```
### 7. Moves original -> backup
Then moves the compressed file -> original's place.

## 🐞 Common Issues found during initial build & Solutions
✔ Paths with spaces  
Fixed by fully quoting ffmpeg paths.

✔ FFmpeg freezing + slowdown  
Switched from CPU libx265 to GPU hevc_amf.

✔ “Unable to infer output format”  
Fixed by adding .mp4 to temp file.

✔ Long videos still > 10MB  
Script warns you but continues with safety bitrate.

## 📚 References
PowerShell install:
https://learn.microsoft.com/powershell/

FFmpeg builds (Gyan.dev):
https://www.gyan.dev/ffmpeg/builds/

AMD AMF Encoder Docs:
https://github.com/GPUOpen-LibrariesAndSDKs/AMF
