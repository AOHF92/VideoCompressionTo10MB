# 🛠️ Patch Notes
## [1.1] - 11-16-2025

✔ Paths with spaces in folder names.  
Fixed by fully quoting ffmpeg paths.

✔ FFmpeg freezing + slowdown  
Switched from CPU libx265 to GPU hevc_amf.

✔ “Unable to infer output format”  
Fixed by adding .mp4 to temp file.

✔ Long videos still > 10MB  
Script warns you but continues with safety bitrate.

✔ Powershell script hardcoded to amd encoder
Added auto gpu detection functionality
