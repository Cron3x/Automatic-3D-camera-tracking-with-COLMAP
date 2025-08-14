#!/bin/sh

#==================================================================
##  BATCH SCRIPT FOR AUTOMATED PHOTOGRAMMETRY TRACKING WORKFLOW
#   By polyfjord - https://youtube.com/polyfjord
#   Linux version by Cron3x - https://github.com/cron3x
#==================================================================
##  USAGE
#     • Double-click this `.sh` or run it from a command prompt.
#     • Frames are extracted, features matched, and a sparse
#       reconstruction is produced automatically.
#     • Videos that have already been processed are skipped on
#       subsequent runs.
#
##  USAGE TERMINAL
#   All Folders can be set using the FOLDER LAYOUT name as
#   enivronment variable or via commandline arguments
#   (use -h or look at the cmd_usage string below)
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
              script instead of one folder above (./ instead of ../)
 -C           Set the the COLMAP executable
 -F           Set the the FFMPEG executable
 -V           Set the the VIDEOS directory
 -S           Set the the SCENES directory
 -cpu         Use the CPU instead of GPU (usefull if CUDA is not availabe)
 -img-size    Change the image size, can reduce the RAM usage [Default: 4096]
 
 Defaults can be found in the header of the script
"

# ---------- Resolve top-level folder (one up from this script) -----
TOP="$(dirname "$(realpath "$0")")/.."

# ---------- Variables for COLMAP on CUDA ---------------------------
USE_GPU=1
IMG_SIZE=4096

# ---------- Handle Commandline args --------------------------------
for option in "$@"; do
  case "$option" in
  -h)
    echo "$cmd_usage"
    exit 0
    ;;
  -C)
    shift
    exe="$(realpath $1)"
    echo "[INFO] Setting COLMAP executable to \`$exe\`"
    COLMAP="$exe"
    shift
    ;;
  -F)
    shift
    exe="$(realpath $1)"
    echo "[INFO] Setting FFMPEG executable to \`$exe\`"
    FFMPEG="$exe"
    shift
    ;;
  -V)
    shift
    dir="$(realpath "$1")"
    echo "[INFO] Setting VIDEOS directory to \`$dir\`"
    VIDEOS_DIR="$dir"
    shift
    ;;
  -S)
    shift
    dir="$(realpath $1)"
    echo "[INFO] Setting SCENES directory to \`$dir\`"
    SCENES_DIR="$dir"
    shift
    ;;
  -c)
    TOP="$(dirname "$(realpath "$0")")"
    echo "[INFO] Setting the working directory to \`$TOP\`"
    shift
    ;;
  -cpu)
    USE_GPU=0
    if [[ USE_GPU -eq 0 ]]; then
      echo "[INFO] Disabling the use of GPU for colmap"
    else
      echo "[INFO] Enabling the use of GPU for colmap (Can lead to problems on non CUDA cards - use $0 -h for help)"
    fi
    shift
    ;;
  -img-size)
    shift
    IMG_SIZE=$1
    echo "[INFO] Setting the image size to \`$IMG_SIZE\`"
    shift
    ;;
  esac
done
shift $((OPTIND - 1))

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
    printf "[ERROR] ffmpeg not found inside \"$FFMPEG_DIR\"." >&2
    exit 1
  fi
fi

# ---------- Locate colmap ---------------------------------------
if [[ -z "$COLMAP" ]]; then
  if [[ -f "$COLMAP_DIR/colmap" ]]; then
    COLMAP="$COLMAP_DIR/colmap"
  elif [[ -f "$COLMAP_DIR/bin/colmap" ]]; then
    COLMAP="$COLMAP_DIR/bin/colmap"
  else
    printf "[ERROR] colmap not found inside \"$COLMAP_DIR\"." >&2
    exit 1
  fi
fi

# ---------- Ensure required folders exist ------------------------
if [[ ! -d "$VIDEOS_DIR" ]]; then
  printf "[ERROR] Input folder \"$VIDEOS_DIR\" missing." >&2
  exit 1
fi

if [[ ! -d "$VIDEOS_DIR" ]]; then
  new_dir "$SCENES_DIR"
fi

# ---------- Count videos for progress bar ------------------------
TOTAL=$(find "$VIDEOS_DIR" -maxdepth 1 -type f | wc -l)
if [[ "$TOTAL" -eq 0 ]]; then
  printf "[WARNING] No video files found in \"$VIDEOS_DIR\"." >&2
  exit 1
fi

echo "=============================================================="
echo " Starting COLMAP on $TOTAL video(s) ..."
echo "=============================================================="

starting() {
  idx=0

  for VIDEO in "$VIDEOS_DIR"/*; do
    if [[ -f "$VIDEO" ]]; then
      IDX=$((idx + 1))
      process_video "$VIDEO" "$idx" "$TOTAL"
    fi
  done

  echo "--------------------------------------------------------------"
  echo " All jobs finished – results are in \"$SCENES_DIR\"."
  echo "--------------------------------------------------------------"
}

new_dir() {
  mkdir -p "$1"
  if [ $? -ne 0 ]; then
    printf "[ERROR] Failed to create directories: $1" >&2
    exit 1
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

  echo
  echo "[$NUM/$TOT] === Processing \"$BASE.$EXT\" ==="

  # -------- Directory layout for this scene -----------------------
  SCENE="$SCENES_DIR/$BASE"
  IMG_DIR="$SCENE/images"
  SPARSE_DIR="$SCENE/sparse"

  # -------- Skip if already reconstructed -------------------------
  if [ -f "$SCENE/database.db" ]; then
    echo "        ↻ Skipping \"$BASE\" – already reconstructed."
    return
  fi

  # Clean slate
  new_dir "$IMG_DIR"
  new_dir "$SPARSE_DIR"

  # -------- 1) Extract every frame --------------------------------
  echo "        [1/4] Extracting frames ..."
  "$FFMPEG" -loglevel error -stats -i "$VIDEO" -qscale:v 2 "$IMG_DIR/frame_%06d.jpg"
  if [ $? -ne 0 ]; then
    echo "        ✖ FFmpeg failed – skipping \"$BASE\"."
    return
  fi

  # Check at least one frame exists
  if [ ! "$(ls -A "$IMG_DIR"/*.jpg 2>/dev/null)" ]; then
    echo "        ✖ No frames extracted – skipping \"$BASE\"."
    return
  fi

  # -------- 2) Feature extraction ---------------------------------
  echo "        [2/4] COLMAP feature_extractor ..."
  "$COLMAP" feature_extractor \
    --ImageReader.single_camera 1 \
    --SiftExtraction.max_image_size $IMG_SIZE \
    --SiftExtraction.use_gpu $USE_GPU \
    --database_path "$SCENE/database.db" \
    --image_path "$IMG_DIR"
  if [ $? -ne 0 ]; then
    echo "        ✖ feature_extractor failed – skipping \"$BASE\"."
    echo "            try using -cpu or reduce the image size via -image-size"
    return
  fi

  # -------- 3) Sequential matching --------------------------------
  echo "        [3/4] COLMAP sequential_matcher ..."
  "$COLMAP" sequential_matcher \
    --SiftMatching.use_gpu $USE_GPU \
    --database_path "$SCENE/database.db" \
    --SequentialMatching.overlap 15
  if [ $? -ne 0 ]; then
    echo "        ✖ sequential_matcher failed – skipping \"$BASE\"."
    return
  fi

  # -------- 4) Sparse reconstruction ------------------------------
  echo "        [4/4] COLMAP mapper ..."
  "$COLMAP" mapper \
    --Mapper.num_threads "$(nproc)" \
    --Mapper.ba_use_gp $USE_GPU \
    --database_path "$SCENE/database.db" \
    --image_path "$IMG_DIR" \
    --output_path "$SPARSE_DIR"
  if [ $? -ne 0 ]; then
    echo "        ✖ mapper failed – skipping \"$BASE\"."
    return
  fi

  # -------- Export best model to TXT ------------------------------
  if [ -d "$SPARSE_DIR/0" ]; then
    "$COLMAP" model_converter \
      --input_path "$SPARSE_DIR/0" \
      --output_path "$SPARSE_DIR" \
      --output_type TXT >/dev/null
  fi

  echo "        ✔ Finished \"$BASE\"  ($NUM/$TOT)"
}

starting
