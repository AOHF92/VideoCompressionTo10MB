# ⚙️ Seup Guide

---
## Windows
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

---

## 🐧 Linux / 🍎 macOS
### 1. Clone the repository
```bash
git clone https://github.com/AOHF92/VideoCompressionTo10MB.git
cd VideoCompressionTo10MB
```
### 2. Install FFmpeg
#### Ubuntu / Debian:
```bash
sudo apt update
sudo apt install ffmpeg
```
#### Fedora:
```bash
sudo dnf install ffmpeg
```
#### Arch / Manjaro:
```bash
sudo pacman -S ffmpeg
```
#### macOS (Homebrew):
```bash
brew install ffmpeg
```
Then Verify:
```bash
ffmpeg -version
ffprobe -version
```
### 3. Option A – Use the Bash script (.sh)

#### 3.1. Make it executable
From the repo root:
```bash
cd scripts    # or wherever you placed it
chmod +x compress-videos-to-10mb.sh
```
(If it’s at the repo root, just run chmod +x ./compress-videos-to-10mb.sh.)

#### 3.2. Run the script
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

### 4. Option B – Use the PowerShell script (.ps1) via pwsh
If you prefer to use PowerShell on Linux/macOS:

#### 4.1. Install PowerShell Core
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
#### 4.2. Run your .ps1 script
From inside PowerShell (pwsh), in the repo folder:
```powershell
cd ./scripts   # or wherever the script lives
./Compress-Videos-To10MB.ps1
```
