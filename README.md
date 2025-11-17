# 📦 Universal 10MB Video Compressor (PowerShell & Bash)

A cross-platform automation tool (PowerShell & Bash) that batch-compresses videos to approximately 10 MB or less, while preserving folder structure, backing up originals, and using FFmpeg with optional hardware-accelerated HEVC encoding for fast results.

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

## 🧰 Requirements

| Component                  | Version           | Notes                                   |
|---------------------------|-------------------|-----------------------------------------|
| PowerShell Core (`pwsh`)  | 7.5+              | Uses strict mode + modern features      |
| FFmpeg (full build)       | 2025 or later     | Must include `ffprobe`                  |
| AMD Drivers               | Latest            | Required for `hevc_amf` hardware encode |
| Windows                   | 10 / 11           | Tested on both                          |

---
## ⚙️ Installation & Setup Guide

For the full detailed setup steps, see:  

➡️ [📦 Full Installation & Setup Guide](docs/SETUP_GUIDE.md)

---
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
### Run from Bash (Linux/macOS)

```bash
chmod +x ./compress-videos-to-10mb.sh
./compress-videos-to-10mb.sh
```
---
## 🧠 How It Works (Technical Overview)
The script performs the following:
### 1. Scans for supported video extensions
```powershell
'.mp4', '.mkv', '.mov', '.avi', '.webm', '.m4v'
```
### 2. Uses ffprobe to calculate duration of video
This is Required to compute the correct bitrate

### 3. Determines a target size
The default is ~95% of 10MB to avoid going over.

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

---

## Notes:
> **(GPU acceleration on Linux):**
> This project’s Bash script tries to auto-detect GPU encoders (hevc_nvenc, hevc_vaapi, h264_qsv).
> To use hardware acceleration, your FFmpeg build must be compiled with those encoders enabled and
> your GPU drivers must be installed correctly. If no hardware encoder is found or an error occurs,
> the script automatically falls back to CPU encoding with libx265.

---
## 🛠️ Changelog

See detailed patch notes and version history in:

➡️ [CHANGELOG](CHANGELOG.md)

--- 
## 📚 References
PowerShell install:  
https://learn.microsoft.com/powershell/

FFmpeg builds (Gyan.dev):  
https://www.gyan.dev/ffmpeg/builds/

FFmpeg Documentation:  
https://ffmpeg.org/documentation.html

AMD AMF Encoder Docs:  
https://github.com/GPUOpen-LibrariesAndSDKs/AMF


