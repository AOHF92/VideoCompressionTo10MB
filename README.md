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

### Windows
#### 1. Install PowerShell 7.5+
```powershell
winget install Microsoft.PowerShell
```
#### 2. Install FFmpeg (Full Build)

Download from the official Gyan.dev builds:

https://www.gyan.dev/ffmpeg/builds/

##### Extract FFmpeg to a permanent folder:
C:\Tools\ffmpeg\

##### Add FFmpeg to your PATH:
C:\Tools\ffmpeg\bin


##### Verify installation:
```powershell
ffmpeg -version
ffprobe -version
```
#### 3. Place the Script Somewhere Convenient
Ex. C:\Scripts\Compress-Videos-To10MB\scripts\

### 🐧 Linux / 🍎 macOS
#### 1. Clone the repository
```bash
git clone https://github.com/AOHF92/VideoCompressionTo10MB.git
cd VideoCompressionTo10MB
```
#### 2. Install FFmpeg
##### Ubuntu / Debian:
```bash
sudo apt update
sudo apt install ffmpeg
```
##### Fedora:
```bash
sudo dnf install ffmpeg
```
##### Arch / Manjaro:
```bash
sudo pacman -S ffmpeg
```
##### macOS (Homebrew):
```bash
brew install ffmpeg
```
Then Verify:
```bash
ffmpeg -version
ffprobe -version
```
#### 3. Option A – Use the Bash script (.sh)

##### 3.1. Make it executable
From the repo root:
```bash
cd scripts    # or wherever you placed it
chmod +x compress-videos-to-10mb.sh
```
(If it’s at the repo root, just run chmod +x ./compress-videos-to-10mb.sh.)

##### 3.2. Run the script
```bash
./compress-videos-to-10mb.sh
```
Then follow the prompts:

 - SOURCE directory → where your original videos are
 - BACKUP directory → where originals will be moved

You can use absolute paths, for example:
```text
/home/john/Videos/Raw
/home/john/Videos/Backup
```
or on macOS:
```text
/Users/john/Videos/Raw
/Users/john/Videos/Backup
```
The script will:

 - Detects GPU encoders (NVENC / VAAPI)
 - Falls back to CPU libx265 if needed
 - Preserves folder structure
 - Moves originals to the backup folder

#### 4. Option B – Use the PowerShell script (.ps1) via pwsh
If you prefer to use PowerShell on Linux/macOS:

##### 4.1. Install PowerShell Core
Ubuntu / Debian:
```bash
sudo apt-get update
sudo apt-get install -y powershell
```

Fedora:
```bash
sudo dnf install -y powershell
```
Arch:
```bash
sudo pacman -S powershell-bin
```
macOS (Homebrew):
```bash
brew install --cask powershell
```
Run:
```bash
pwsh
```
##### 4.2. Run your .ps1 script
From inside PowerShell (pwsh), in the repo folder:
```powershell
cd ./scripts   # or wherever the script lives
./Compress-Videos-To10MB.ps1
```
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

## Notes:
> **(GPU acceleration on Linux):**
> This project’s Bash script tries to auto-detect GPU encoders (hevc_nvenc, hevc_vaapi, h264_qsv).
> To use hardware acceleration, your FFmpeg build must be compiled with those encoders enabled and
> your GPU drivers must be installed correctly. If no hardware encoder is found or an error occurs,
> the script automatically falls back to CPU encoding with libx265.

## 📚 References
PowerShell install:
https://learn.microsoft.com/powershell/

FFmpeg builds (Gyan.dev):
https://www.gyan.dev/ffmpeg/builds/

AMD AMF Encoder Docs:
https://github.com/GPUOpen-LibrariesAndSDKs/AMF
