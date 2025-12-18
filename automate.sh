#!/bin/sh

#==================================================================
##  BATCH SCRIPT FOR AUTOMATED PHOTOGRAMMETRY TRACKING WORKFLOW
#   Original by polyfjord - https://youtube.com/polyfjord
#   Linux version by Cron3x - https://github.com/cron3x
#==================================================================
##  USAGE TERMINAL
#   All Folders can be set using the FOLDER LAYOUT name as
#   enivronment variable or via commandline arguments
#   (use -h or look at the cmd_usage string below)
#
##  USAGE double-click
#     • Double-click this `.sh` or run it from a command prompt.
#     • Frames are extracted, features matched, and a sparse
#       reconstruction is produced automatically.
#     • Videos that have already been processed are skipped on
#       subsequent runs.
#
##  PURPOSE
#     This is a fully automated photogrammetry tracker for turning
#     videos into COLMAP sparse models with robust error handling,
#     clean directory setup, and clear ✖ / ✔ logging.
#
##  FOLDER LAYOUT (all folders sit side-by-side):
#     01 COLMAP   – Download the latest release from
#                    https://github.com/colmap/colmap
#                    and place colmap.bat (plus its dlls) here.
#
#     02 VIDEOS   – Put your input video files (.mp4, .mov, …) here.
#                    All framerates and aspect ratios are supported.
#
#     03 FFMPEG   – Drop a **static build** of FFmpeg
#                    (either ffmpeg.exe or bin\ffmpeg.exe) here.
#
#     04 SCENES   – The script creates one sub-folder per video
#                    containing extracted frames, the COLMAP
#                    database, sparse model, and TXT export.
#
#     05 SCRIPTS  – This batch file lives here.
#
#
#==================================================================

cmd_usage="
 ARGUMENT     DESCRIPTION
 -h           print this help
 -c           set the working to the level of the shell
              script instead of one folder above ( ./ instead of ../) 
 -C           Set the the COLMAP executable   [Default: '../01 COLMAP/colmap' or '../01 COLMAP/bin/colmap']
 -F           Set the the FFMPEG executable   [Default: '../03 FFMPEG/ffmpeg' or '../03 FFMPEG/bin/ffmpeg']
 -V           Set the the VIDEOS directory    [Default: '../02 VIDEOS/']
 -S           Set the the SCENES directory    [Default: '../04 SCENES/']
 -j           Sets the amount of threads used by COLMAP   [Default: -1 (Use as many as possible)]
 -G           Use Glowmap as mapper
 -cpu         Use the CPU instead of GPU      [Default: dependent on if the script could find CUDA]
 -gpu         Force execution on GPU (CUDA). If you have it but the script does not find it.
 -img-size    Change the image size, can reduce the RAM usage   [Default: 4096]
 -libs        set LD_LIBRARY_PATH for the COLMAP executable
 
 Defaults can also be found in the header of the script
"

#TODO: Replace old printf with custom functions, maybe introduce 'trap'
# Also add multi error functionality
#
ebye() {
  printf "[ERROR] $1\n" >&2
  exit 1
}
info() {
  printf "[INFO] $1\n" >&1
}

# Get the Platform the script is running on
PLATFORM="Unknown"
case "$(uname -s)" in
Linux*)
  PLATFORM="Linux"
  ;;
Darwin*)
  PLATFORM="macOS"
  ;;
esac

if [[ "$PLATFORM" == "macOS" ]]; then
  realpath() {
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
  }
fi

# ---------- Resolve top-level folder (one up from this script) -----
TOP="$(dirname "$(realpath "$0")")/.."

#TODO: set working directory to be able to have one instsance of the script with multiple projects

# ---------- Variables for COLMAP on CUDA ---------------------------
USE_GPU=0
IMG_SIZE=4096
THREADS=$(nproc)

# Check if cuda is available and gpu is working
# TODO: test with ZLUDA
if command -v nvidia-smi >/dev/null 2>&1; then
  if nvidia-smi >/dev/null 2>&1; then
    USE_GPU=1
  fi
fi

# ---------- Handle Commandline args --------------------------------
for option in "$@"; do
  case "$option" in
  -h)
    printf "$cmd_usage\n"
    exit 0
    ;;
  -C)
    shift
    exe="$(realpath $1)"
    printf "[INFO] Setting COLMAP executable to \`$exe\`\n"
    COLMAP="$exe"
    shift
    ;;
  -F)
    shift
    exe="$(realpath $1)"
    printf "[INFO] Setting FFMPEG executable to \`$exe\`\n"
    FFMPEG="$exe"
    shift
    ;;
  -V)
    shift
    dir="$(realpath "$1")"
    printf "[INFO] Setting VIDEOS directory to \`$dir\`\n"
    VIDEOS_DIR="$dir"
    shift
    ;;
  -S)
    shift
    dir="$(realpath $1)"
    printf "[INFO] Setting SCENES directory to \`$dir\`\n"
    SCENES_DIR="$dir"
    shift
    ;;
  -j)
    shift
    #TODO: Does this need to do a number check + what happens if you provide more?
    if [[ "$1" != -* ]]; then
      THREADS="$1"
    fi
    printf "[INFO] COLMAP now uses $THREADS threads\n"
    shift
    ;;
  -c)
    TOP="$(dirname "$(realpath "$0")")"
    printf "[INFO] Setting the working directory to \`$TOP\`\n"
    shift
    ;;
  -G)
    shift
    exe="$(realpath $1)"
    printf "[INFO] Enabeling Glowmap\n"
    GLOMAP="$exe"
    shift
    ;;
  -cpu)
    USE_GPU=0
    printf "[INFO] Forcing COLMAP to run on the CPU\n"
    shift
    ;;
  -gpu)
    USE_GPU=1
    printf "[WARN] Forcing CUDA even though its doesn't seem to be supported - could couse errors\n"
    shift
    ;;
  -img-size)
    shift
    IMG_SIZE=$1
    printf "[INFO] Setting the image size to \`$IMG_SIZE\`\n"
    shift
    ;;
  -libs)
    shift
    LD_LIBRARIES=$1
    printf "[INFO] Setting Colmap LD_LIBRARY_PATH \`$LD_LIBRARIES\`\n"
    shift
    ;;
  esac
done
shift $((OPTIND - 1))

info "Detected Platform: $PLATFORM"
if [[ USE_GPU -eq 1 ]]; then
  info "COLMAP will run on the GPU"
else
  info "COLMAP will run on the CPU"
fi

# ---------- Key paths -------------------------------------------
COLMAP_DIR="$TOP/01 COLMAP"
if [[ -z $VIDEOS_DIR ]]; then
  VIDEOS_DIR="${VIDEOS:-$TOP/02 VIDEOS}"
fi
FFMPEG_DIR="$TOP/03 FFMPEG"
if [[ -z $SCENES_DIR ]]; then
  SCENES_DIR="${SCENES:-$TOP/04 SCENES}"
fi

# ---------- Locate ffmpeg ---------------------------------------
if [[ -z "$FFMPEG" ]]; then
  if [[ -f "$FFMPEG_DIR/ffmpeg" ]]; then
    FFMPEG="$FFMPEG_DIR/ffmpeg"
  elif [[ -f "$FFMPEG_DIR/bin/ffmpeg" ]]; then
    FFMPEG="$FFMPEG_DIR/bin/ffmpeg"
  else
    ebye "ffmpeg not found inside \"$FFMPEG_DIR\"."
  fi
fi

# ---------- Locate colmap ---------------------------------------
if [[ -z "$COLMAP" ]]; then
  if [[ -f "$COLMAP_DIR/colmap" ]]; then
    COLMAP="$COLMAP_DIR/colmap"
  elif [[ -f "$COLMAP_DIR/bin/colmap" ]]; then
    COLMAP="$COLMAP_DIR/bin/colmap"
  else
    ebye "colmap not found inside \"$COLMAP_DIR\"."
  fi
fi

# ---------- Ensure required folders exist ------------------------
if [[ ! -d "$VIDEOS_DIR" ]]; then
  ebye "Input folder \"$VIDEOS_DIR\" missing."
fi

if [[ ! -d "$VIDEOS_DIR" ]]; then
  new_dir "$SCENES_DIR"
fi

# ---------- Count videos for progress bar ------------------------
TOTAL=$(find "$VIDEOS_DIR" -maxdepth 1 -type f | wc -l)
if [[ "$TOTAL" -eq 0 ]]; then
  printf "[WARNING] No video files found in \"$VIDEOS_DIR\".\n" >&2
  exit 1
fi

printf "==============================================================\n"
printf " Starting COLMAP on $TOTAL video(s) ...\n"
printf "==============================================================\n"

starting() {
  idx=0

  for VIDEO in "$VIDEOS_DIR"/*; do
    if [[ -f "$VIDEO" ]]; then
      IDX=$((idx + 1))
      process_video "$VIDEO" "$idx" "$TOTAL"
    fi
  done

  printf "==============================================================\n"
  printf " All jobs finished – results are in \"$SCENES_DIR\".\n"
  printf "==============================================================\n"
}

new_dir() {
  mkdir -p "$1"
  if [ $? -ne 0 ]; then
    ebye "Failed to create directories: $1"
  fi
}

process_video() {
  # ----------------------------------------------------------------
  #  $1 = full path to video   $2 = current index   $3 = total
  # ----------------------------------------------------------------
  VIDEO="$1"
  NUM="$2"
  TOT="$3"

  BASE=$(basename "$VIDEO")
  EXT="${BASE##*.}"
  BASE="${BASE%.*}"

  printf "[$NUM/$TOT] === Processing \"$BASE.$EXT\" ===\n"

  # -------- Directory layout for this scene -----------------------
  SCENE="$SCENES_DIR/$BASE"
  IMG_DIR="$SCENE/images"
  SPARSE_DIR="$SCENE/sparse"

  # -------- Skip if already reconstructed -------------------------
  if [ -f "$SCENE/database.db" ]; then
    printf "        ↻ Skipping \"$BASE\" – already reconstructed.\n"
    return
  fi

  # Clean slate
  new_dir "$IMG_DIR"
  new_dir "$SPARSE_DIR"

  # -------- 1) Extract every frame --------------------------------
  printf "        [1/4] Extracting frames ...\n"
  "$FFMPEG" -loglevel error -stats -i "$VIDEO" -qscale:v 2 "$IMG_DIR/frame_%06d.jpg"
  if [ $? -ne 0 ]; then
    printf "        ✖ FFmpeg failed – skipping \"$BASE\".\n"
    return
  fi

  # Check at least one frame exists
  if [ ! "$(ls -A "$IMG_DIR"/*.jpg 2>/dev/null)" ]; then
    printf "        ✖ No frames extracted – skipping \"$BASE\".\n"
    return
  fi

  # -------- 2) Feature extraction ---------------------------------
  printf "        [2/4] COLMAP feature_extractor ...\n"
  printf "\t libs: $LD_LIBRARIES \n"
  LD_LIBRARY_PATH=$LD_LIBRARIES "$COLMAP" feature_extractor \
    --ImageReader.single_camera 1 \
    --SiftExtraction.max_image_size $IMG_SIZE \
    --FeatureExtraction.gpu_index 1 \
    --FeatureExtraction.use_gpu $USE_GPU \
    --database_path "$SCENE/database.db" \
    --image_path "$IMG_DIR"
  if [ $? -ne 0 ]; then
    printf "        ✖ feature_extractor failed – skipping \"$BASE\".\n"
    printf "          try using -cpu or reduce the image size via -image-size\n"
    return
  fi

  # -------- 3) Sequential matching --------------------------------
  printf "        [3/4] COLMAP sequential_matcher ...\n"
  LD_LIBRARY_PATH=$LD_LIBRARIES "$COLMAP" sequential_matcher \
    --FeatureMatching.use_gpu $USE_GPU \
    --database_path "$SCENE/database.db" \
    --SequentialMatching.overlap 15
  if [ $? -ne 0 ]; then
    printf "        ✖ sequential_matcher failed – skipping \"$BASE\".\n"
    return
  fi

  # -------- 4) Sparse reconstruction ------------------------------
  printf "        [4/4] COLMAP mapper ...\n"
  MAPPER="$COLMAP"
  if [ -n "$GLOMAP" ]; then
    MAPPER="$GLOMAP"
  fi
  printf "+> $SCENE\n+> $IMG_DIR"
  LD_LIBRARY_PATH=$LD_LIBRARIES "$MAPPER" mapper \
    --Mapper.num_threads "$THREADS" \
    --Mapper.ba_use_gpu $USE_GPU \
    --database_path "$SCENE/database.db" \
    --image_path "$IMG_DIR" \
    --output_path "$SPARSE_DIR"
  if [ $? -ne 0 ]; then
    printf "        ✖ mapper failed – skipping \"$BASE\".\n"
    return
  fi

  # -------- Export best model to TXT ------------------------------
  if [ -d "$SPARSE_DIR/0" ]; then
    LD_LIBRARY_PATH=$LD_LIBRARIES "$COLMAP" model_converter \
      --input_path "$SPARSE_DIR/0" \
      --output_path "$SPARSE_DIR" \
      --output_type TXT >/dev/null
  fi

  printf "        ✔ Finished \"$BASE\"  ($NUM/$TOT)\n"
}

starting
