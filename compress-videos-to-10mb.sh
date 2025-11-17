#!/usr/bin/env bash
set -euo pipefail

# compress-videos-to-10mb.sh
#
# Batch compress videos to ~<= 10 MB using ffmpeg + ffprobe.
# - Preserves folder structure
# - Moves originals to a backup directory
# - Auto-detects GPU encoder (NVENC/VAAPI) and falls back to CPU libx265

# ---------- Config ----------

MAX_SIZE_MB=10              # Hard limit per file
SAFETY_FACTOR=0.95          # Aim for 95% of 10 MB
MIN_VIDEO_BITRATE=200000    # 200 kbps (bits/sec)
AUDIO_BITRATE_BITS=128000   # 128 kbps

VIDEO_EXTENSIONS=("mp4" "mkv" "mov" "avi" "webm" "m4v")

# Globals for encoder choice
VIDEO_ENCODER="libx265"
ENCODER_MODE="cpu"  # cpu | nvenc | vaapi

# ---------- Helpers ----------

err() {
  echo "ERROR: $*" >&2
}

prompt_dir() {
  local prompt_text="$1"
  local var_name="$2"
  local dir_path=""

  while :; do
    read -rp "$prompt_text" dir_path
    dir_path="${dir_path/#\~/$HOME}"   # expand ~
    if [[ -d "$dir_path" ]]; then
      eval "$var_name=\"$(realpath "$dir_path")\""
      return 0
    else
      echo "Directory does not exist: $dir_path"
    fi
  done
}

check_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "'$cmd' is not available in PATH. Please install it and try again."
    exit 1
  fi
}

detect_encoder() {
  echo "Detecting available video encoders..."

  local encoders
  encoders="$(ffmpeg -hide_banner -encoders 2>/dev/null || true)"

  if grep -q "hevc_nvenc" <<<"$encoders"; then
    VIDEO_ENCODER="hevc_nvenc"
    ENCODER_MODE="nvenc"
    echo "  Using NVIDIA NVENC encoder: hevc_nvenc"
  elif grep -q "hevc_vaapi" <<<"$encoders"; then
    VIDEO_ENCODER="hevc_vaapi"
    ENCODER_MODE="vaapi"
    echo "  Using VAAPI encoder: hevc_vaapi (AMD/Intel GPU via /dev/dri)"
  else
    VIDEO_ENCODER="libx265"
    ENCODER_MODE="cpu"
    echo "  No hardware HEVC encoder found. Using CPU encoder: libx265"
  fi
}

get_video_duration() {
  local file="$1"
  local duration

  if ! duration="$(ffprobe -v error -show_entries format=duration \
                    -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)"; then
    return 1
  fi

  # Trim & validate
  duration="$(printf '%s' "$duration" | tr -d '[:space:]')"
  if [[ -z "$duration" ]]; then
    return 1
  fi

  # Basic numeric check
  if ! awk "BEGIN {exit !($duration > 0)}"; then
    return 1
  fi

  printf '%s' "$duration"
}

human_mb() {
  # bytes -> MB rounded to 2 decimals
  awk "BEGIN {printf \"%.2f\", $1/1024/1024}"
}

# Run ffmpeg with the selected encoder. If hardware encoding fails,
# we fall back to CPU libx265 for that file.
run_ffmpeg_encode() {
  local input="$1"
  local output="$2"
  local video_kbps="$3"
  local audio_kbps="$4"
  local bufsize_kbps="$5"

  local exit_code=0

  case "$ENCODER_MODE" in
    nvenc)
      echo "  Using hardware encoder: $VIDEO_ENCODER (NVENC)"
      if ! ffmpeg -y -i "$input" \
          -c:v "$VIDEO_ENCODER" -preset fast -rc:v vbr_hq \
          -b:v "${video_kbps}k" -maxrate:v "${video_kbps}k" -bufsize:v "${bufsize_kbps}k" \
          -c:a aac -b:a "${audio_kbps}k" -movflags +faststart \
          "$output"; then
        exit_code=$?
      fi
      ;;
    vaapi)
      echo "  Using hardware encoder: $VIDEO_ENCODER (VAAPI)"
      # Note: assumes /dev/dri/renderD128 and a working VAAPI setup.
      if ! ffmpeg -y -init_hw_device vaapi=va:/dev/dri/renderD128 \
          -filter_hw_device va -i "$input" \
          -vf 'format=nv12,hwupload' \
          -c:v "$VIDEO_ENCODER" \
          -b:v "${video_kbps}k" -maxrate:v "${video_kbps}k" -bufsize:v "${bufsize_kbps}k" \
          -c:a aac -b:a "${audio_kbps}k" -movflags +faststart \
          "$output"; then
        exit_code=$?
      fi
      ;;
    cpu|*)
      echo "  Using CPU encoder: libx265"
      if ! ffmpeg -y -i "$input" \
          -c:v libx265 -preset medium \
          -b:v "${video_kbps}k" -maxrate:v "${video_kbps}k" -bufsize:v "${bufsize_kbps}k" \
          -c:a aac -b:a "${audio_kbps}k" -movflags +faststart \
          "$output"; then
        exit_code=$?
      fi
      ;;
  esac

  # If hardware encoding failed, retry with CPU libx265
  if [[ $exit_code -ne 0 || ! -f "$output" ]]; then
    if [[ "$ENCODER_MODE" != "cpu" ]]; then
      echo "  Hardware encode failed (exit $exit_code). Falling back to CPU libx265..."
      if ! ffmpeg -y -i "$input" \
          -c:v libx265 -preset medium \
          -b:v "${video_kbps}k" -maxrate:v "${video_kbps}k" -bufsize:v "${bufsize_kbps}k" \
          -c:a aac -b:a "${audio_kbps}k" -movflags +faststart \
          "$output"; then
        return 1
      fi
    else
      return 1
    fi
  fi

  return 0
}

# ---------- Main ----------

echo "=== Compress videos to ~${MAX_SIZE_MB} MB and back up originals (Bash version) ==="

# Check dependencies
check_command ffmpeg
check_command ffprobe
check_command awk
check_command find
check_command stat

# Prompt for directories
prompt_dir "Enter the SOURCE directory (videos will be REPLACED here): " SOURCE_ROOT
prompt_dir "Enter the BACKUP directory (originals will be MOVED here): " BACKUP_ROOT

if [[ "$SOURCE_ROOT" == "$BACKUP_ROOT" ]]; then
  err "Source and backup directories CANNOT be the same."
  exit 1
fi

# Prevent backup being inside source
case "$BACKUP_ROOT" in
  "$SOURCE_ROOT"/*)
    err "Backup directory cannot be a subfolder of the source directory."
    exit 1
    ;;
esac

echo
echo "Source : $SOURCE_ROOT"
echo "Backup : $BACKUP_ROOT"
echo

read -rp "Proceed? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]([Ee][Ss])?$ ]]; then
  echo "Aborted by user."
  exit 0
fi

# Detect encoder
detect_encoder
echo

MAX_SIZE_BYTES=$(( MAX_SIZE_MB * 1024 * 1024 ))
TARGET_SIZE_BYTES=$(awk -v max="$MAX_SIZE_BYTES" -v s="$SAFETY_FACTOR" 'BEGIN {printf "%.0f", max*s}')

# Build the find expression for video extensions
find_expr=()
for ext in "${VIDEO_EXTENSIONS[@]}"; do
  find_expr+=( -iname "*.${ext}" -o )
done
# Remove trailing -o
unset 'find_expr[${#find_expr[@]}-1]'

echo "Scanning for video files..."
mapfile -t files < <(find "$SOURCE_ROOT" -type f \( "${find_expr[@]}" \))

if ((${#files[@]} == 0)); then
  echo "No video files found under $SOURCE_ROOT"
  exit 0
fi

echo "Found ${#files[@]} video file(s)."
echo

index=0
failures=()

for file in "${files[@]}"; do
  index=$((index+1))
  echo
  echo "[$index/${#files[@]}] Processing: $file"

  # Size
  size_bytes=$(stat -c '%s' "$file")
  size_mb=$(human_mb "$size_bytes")
  echo "  Original size: ${size_mb} MB"

  # Already small enough?
  if (( size_bytes <= MAX_SIZE_BYTES )); then
    echo "  Already <= ${MAX_SIZE_MB}MB. Backing up original without re-encoding..."

    rel="${file#$SOURCE_ROOT/}"
    backup_path="$BACKUP_ROOT/$rel"
    backup_dir="$(dirname "$backup_path")"

    mkdir -p "$backup_dir"
    cp -f -- "$file" "$backup_path"

    echo "  Backup created at: $backup_path"
    continue
  fi

  # Duration
  if ! duration="$(get_video_duration "$file")"; then
    err "  Could not get duration for '$file'. Skipping."
    failures+=("$file")
    continue
  fi
  printf "  Duration: %.2f seconds\n" "$duration"

  # Bitrate calculation
  total_bits=$(awk -v t="$TARGET_SIZE_BYTES" 'BEGIN {print t*8.0}')
  max_bitrate=$(awk -v bits="$total_bits" -v d="$duration" 'BEGIN {print bits/d}')

  video_bitrate_bits=""
  if awk -v m="$max_bitrate" -v audio="$AUDIO_BITRATE_BITS" -v minv="$MIN_VIDEO_BITRATE" \
        'BEGIN {exit !(m <= audio+minv)}'; then
    # Too long; just use minimum
    echo "  WARNING: Video is long relative to target size. Using minimum video bitrate."
    video_bitrate_bits="$MIN_VIDEO_BITRATE"
  else
    video_bitrate_bits=$(awk -v m="$max_bitrate" -v audio="$AUDIO_BITRATE_BITS" \
                           'BEGIN {print m-audio}')
    # Enforce minimum
    if ! awk -v v="$video_bitrate_bits" -v min="$MIN_VIDEO_BITRATE" \
           'BEGIN {exit !(v >= min)}'; then
      video_bitrate_bits="$MIN_VIDEO_BITRATE"
    fi
  fi

  video_kbps=$(awk -v v="$video_bitrate_bits" 'BEGIN {printf "%.0f", v/1000.0}')
  audio_kbps=128
  bufsize_kbps=$(( video_kbps * 2 ))

  echo "  Target video bitrate: ${video_kbps} kbps"
  echo "  Audio bitrate       : ${audio_kbps} kbps"

  temp_path="${file}.tmp_compressed.mp4"
  rm -f -- "$temp_path"

  echo "  Running ffmpeg..."
  if ! run_ffmpeg_encode "$file" "$temp_path" "$video_kbps" "$audio_kbps" "$bufsize_kbps"; then
    err "  ffmpeg failed for '$file'."
    rm -f -- "$temp_path" || true
    failures+=("$file")
    continue
  fi

  if [[ ! -f "$temp_path" ]]; then
    err "  Temp file not created for '$file'."
    failures+=("$file")
    continue
  fi

  compressed_size_bytes=$(stat -c '%s' "$temp_path")
  compressed_size_mb=$(human_mb "$compressed_size_bytes")
  echo "  Compressed size: ${compressed_size_mb} MB"

  if (( compressed_size_bytes > MAX_SIZE_BYTES )); then
    echo "  WARNING: Compressed file is still > ${MAX_SIZE_MB}MB. Keeping it anyway."
  fi

  # Backup path
  rel="${file#$SOURCE_ROOT/}"
  backup_path="$BACKUP_ROOT/$rel"
  backup_dir="$(dirname "$backup_path")"
  mkdir -p "$backup_dir"

  mv -f -- "$file" "$backup_path"
  mv -f -- "$temp_path" "$file"

  saved_mb=$(awk -v o="$size_bytes" -v c="$compressed_size_bytes" 'BEGIN {printf "%.2f", (o-c)/1024/1024}')
  echo "     Done. Saved ~${saved_mb} MB. Original moved to: $backup_path"
done

echo
echo "=== Completed ==="

if ((${#failures[@]} > 0)); then
  echo "The following files failed to process:"
  for f in "${failures[@]}"; do
    echo "  - $f"
  done
else
  echo "All files processed successfully."
fi

