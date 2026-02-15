#!/usr/bin/env bash
set -euo pipefail

DEFAULT_VERSION="0.1.0"
DEFAULT_OUT_DIR="$HOME/Desktop"
DEFAULT_VOL_NAME="HeadBird"
STATE_FILE="$HOME/.headbird-dmg-wizard.defaults"

APP_PATH=""
VERSION=""
OUT_DIR=""
VOL_NAME=""
BACKGROUND_PATH=""
NON_INTERACTIVE=0
FORCE_OVERWRITE=0

STEP_TOTAL=8
STEP_NUM=0
INPUT_TOTAL=5
INPUT_NUM=0

STAGE_DIR=""
RW_DMG=""
FINAL_DMG=""
VOL_PATH=""
MOUNTED_DEV=""
SUCCESS=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_BLUE=$'\033[94m'
  C_CYAN=$'\033[96m'
  C_GREEN=$'\033[92m'
  C_YELLOW=$'\033[93m'
  C_RED=$'\033[91m'
else
  C_RESET=""
  C_BOLD=""
  C_BLUE=""
  C_CYAN=""
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
fi

print_usage() {
  cat <<'EOF'
HeadBird DMG Wizard

Usage:
  scripts/make-release-dmg.sh
  scripts/make-release-dmg.sh [options]

Interactive mode (recommended for beginners):
  Run with no flags. The wizard asks for:
  - Absolute path to HeadBird.app
  - Version (SemVer)
  - Output folder
  - DMG volume name
  - Optional background image

Options:
  --app-path <absolute-path>         Path to HeadBird.app
  --version <semver>                 Version (example: 0.1.0)
  --output-dir <absolute-path>       Output folder (default: ~/Desktop)
  --volume-name <name>               DMG volume name (default: HeadBird)
  --background-image <absolute-path> Optional PNG/JPG background image
  --non-interactive                  Disable prompts (all required values must be provided)
  --force                            Overwrite existing final DMG without prompt
  -h, --help                         Show this help

Examples:
  scripts/make-release-dmg.sh

  scripts/make-release-dmg.sh \
    --app-path "/Users/you/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/HeadBird.app" \
    --version "0.1.0" \
    --output-dir "$HOME/Desktop" \
    --volume-name "HeadBird"

  scripts/make-release-dmg.sh \
    --app-path "/Users/you/.../HeadBird.app" \
    --version "0.1.0-beta.1" \
    --output-dir "$HOME/Desktop" \
    --volume-name "HeadBird" \
    --background-image "/Users/you/Pictures/dmg-background.png" \
    --non-interactive
EOF
}

print_step() {
  STEP_NUM=$((STEP_NUM + 1))
  echo
  printf "%s%s[STEP %s/%s]%s %s\n" "$C_BOLD" "$C_BLUE" "$STEP_NUM" "$STEP_TOTAL" "$C_RESET" "$1"
}

print_input_step() {
  INPUT_NUM=$((INPUT_NUM + 1))
  echo
  printf "%s%s[INPUT %s/%s]%s %s\n" "$C_BOLD" "$C_CYAN" "$INPUT_NUM" "$INPUT_TOTAL" "$C_RESET" "$1"
}

log_info() {
  printf "%s[INFO]%s %s\n" "$C_BLUE" "$C_RESET" "$1"
}

log_warn() {
  printf "%s[WARN]%s %s\n" "$C_YELLOW" "$C_RESET" "$1" >&2
}

log_success() {
  printf "%s[SUCCESS]%s %s\n" "$C_GREEN" "$C_RESET" "$1"
}

fail() {
  printf "%s[ERROR]%s %s\n" "$C_RED" "$C_RESET" "$1" >&2
  exit 1
}

is_absolute_path() {
  [[ "$1" = /* ]]
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

is_yes() {
  local v
  v="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "$v" == "y" || "$v" == "yes" ]]
}

validate_version() {
  local v="$1"
  [[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?(\+[0-9A-Za-z.]+)?$ ]]
}

validate_app_path() {
  local p="$1"
  is_absolute_path "$p" || return 1
  [[ "$p" == *.app ]] || return 1
  [[ -d "$p" ]] || return 1
  [[ -f "$p/Contents/Info.plist" ]] || return 1
}

validate_output_dir() {
  local p="$1"
  is_absolute_path "$p" || return 1
  mkdir -p "$p" 2>/dev/null || return 1
  [[ -d "$p" ]] || return 1
}

validate_background_path() {
  local p="$1"
  [[ -f "$p" ]] || return 1
  case "${p,,}" in
    *.png|*.jpg|*.jpeg) return 0 ;;
    *) return 1 ;;
  esac
}

load_defaults() {
  local line key value
  [[ -f "$STATE_FILE" ]] || return 0
  while IFS= read -r line; do
    case "$line" in
      LAST_APP_PATH=*)
        value="${line#LAST_APP_PATH=}"
        if [[ -n "$value" ]]; then
          APP_PATH="${APP_PATH:-$value}"
        fi
        ;;
      LAST_VERSION=*)
        value="${line#LAST_VERSION=}"
        if [[ -n "$value" ]]; then
          VERSION="${VERSION:-$value}"
        fi
        ;;
      LAST_OUTPUT_DIR=*)
        value="${line#LAST_OUTPUT_DIR=}"
        if [[ -n "$value" ]]; then
          OUT_DIR="${OUT_DIR:-$value}"
        fi
        ;;
      LAST_VOL_NAME=*)
        value="${line#LAST_VOL_NAME=}"
        if [[ -n "$value" ]]; then
          VOL_NAME="${VOL_NAME:-$value}"
        fi
        ;;
      LAST_BACKGROUND_PATH=*)
        value="${line#LAST_BACKGROUND_PATH=}"
        if [[ -n "$value" ]]; then
          BACKGROUND_PATH="${BACKGROUND_PATH:-$value}"
        fi
        ;;
      *)
        key=""
        ;;
    esac
  done < "$STATE_FILE"
}

save_defaults() {
  local tmp_file
  tmp_file="$(mktemp)"
  {
    printf 'LAST_APP_PATH=%s\n' "$APP_PATH"
    printf 'LAST_VERSION=%s\n' "$VERSION"
    printf 'LAST_OUTPUT_DIR=%s\n' "$OUT_DIR"
    printf 'LAST_VOL_NAME=%s\n' "$VOL_NAME"
    printf 'LAST_BACKGROUND_PATH=%s\n' "$BACKGROUND_PATH"
  } > "$tmp_file"
  mv "$tmp_file" "$STATE_FILE"
}

prompt_with_default() {
  local label="$1"
  local example="$2"
  local default_value="$3"
  local input

  while true; do
    if [[ -n "$default_value" ]]; then
      printf "%s\n  Example: %s\n  Default: %s\n> " "$label" "$example" "$default_value" >&2
    else
      printf "%s\n  Example: %s\n> " "$label" "$example" >&2
    fi
    read -r input
    input="$(trim "$input")"
    if [[ -n "$input" ]]; then
      printf '%s\n' "$input"
      return 0
    fi
    if [[ -n "$default_value" ]]; then
      printf '%s\n' "$default_value"
      return 0
    fi
    printf "%s[WARN]%s Input is required.\n" "$C_YELLOW" "$C_RESET" >&2
  done
}

prompt_optional() {
  local label="$1"
  local example="$2"
  local default_value="$3"
  local input
  if [[ -n "$default_value" ]]; then
    printf "%s\n  Example: %s\n  Default: %s\n  Leave blank to skip.\n> " "$label" "$example" "$default_value" >&2
  else
    printf "%s\n  Example: %s\n  Leave blank to skip.\n> " "$label" "$example" >&2
  fi
  read -r input
  input="$(trim "$input")"
  if [[ -n "$input" ]]; then
    printf '%s\n' "$input"
    return 0
  fi
  printf '%s\n' ""
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --app-path)
        [[ $# -ge 2 ]] || fail "--app-path requires a value"
        APP_PATH="$2"
        shift 2
        ;;
      --version)
        [[ $# -ge 2 ]] || fail "--version requires a value"
        VERSION="$2"
        shift 2
        ;;
      --output-dir)
        [[ $# -ge 2 ]] || fail "--output-dir requires a value"
        OUT_DIR="$2"
        shift 2
        ;;
      --volume-name)
        [[ $# -ge 2 ]] || fail "--volume-name requires a value"
        VOL_NAME="$2"
        shift 2
        ;;
      --background-image)
        [[ $# -ge 2 ]] || fail "--background-image requires a value"
        BACKGROUND_PATH="$2"
        shift 2
        ;;
      --non-interactive)
        NON_INTERACTIVE=1
        shift
        ;;
      --force)
        FORCE_OVERWRITE=1
        shift
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        fail "Unknown argument: $1"
        ;;
    esac
  done
}

collect_inputs_interactive() {
  echo
  printf "%s%sHeadBird DMG Wizard%s\n" "$C_BOLD" "$C_CYAN" "$C_RESET"
  log_info "This wizard packages an existing HeadBird.app into a release DMG."
  echo

  APP_PATH="${APP_PATH:-}"
  VERSION="${VERSION:-$DEFAULT_VERSION}"
  OUT_DIR="${OUT_DIR:-$DEFAULT_OUT_DIR}"
  VOL_NAME="${VOL_NAME:-$DEFAULT_VOL_NAME}"
  BACKGROUND_PATH="${BACKGROUND_PATH:-}"

  print_input_step "App bundle path"
  while true; do
    APP_PATH="$(prompt_with_default \
      "Enter absolute path to HeadBird.app" \
      "/Users/you/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/HeadBird.app" \
      "$APP_PATH")"
    if validate_app_path "$APP_PATH"; then
      break
    fi
    log_warn "Invalid app path. It must be absolute, end with .app, and contain Contents/Info.plist."
  done

  print_input_step "Version"
  while true; do
    VERSION="$(prompt_with_default \
      "Enter release version (SemVer)" \
      "0.1.0" \
      "$VERSION")"
    if validate_version "$VERSION"; then
      break
    fi
    log_warn "Invalid version format. Expected patterns like 0.1.0, 0.1.0-beta.1, or 0.1.0+build1."
  done

  print_input_step "Output folder"
  while true; do
    OUT_DIR="$(prompt_with_default \
      "Enter output directory (absolute path)" \
      "/Users/you/Desktop" \
      "$OUT_DIR")"
    if validate_output_dir "$OUT_DIR"; then
      break
    fi
    log_warn "Invalid output directory. Use an absolute path you can write to."
  done

  print_input_step "DMG volume name"
  while true; do
    VOL_NAME="$(prompt_with_default \
      "Enter DMG volume name" \
      "HeadBird" \
      "$VOL_NAME")"
    if [[ -n "$VOL_NAME" ]]; then
      break
    fi
    log_warn "Volume name cannot be empty."
  done

  print_input_step "Optional background image"
  while true; do
    BACKGROUND_PATH="$(prompt_optional \
      "Optional: background image path (PNG/JPG)" \
      "/Users/you/Pictures/headbird-dmg-bg.png" \
      "$BACKGROUND_PATH")"
    if [[ -z "$BACKGROUND_PATH" ]] || validate_background_path "$BACKGROUND_PATH"; then
      break
    fi
    log_warn "Invalid background image. Path must exist and end with .png, .jpg, or .jpeg."
  done
}

validate_non_interactive_inputs() {
  [[ -n "$APP_PATH" ]] || fail "--app-path is required with --non-interactive"
  [[ -n "$VERSION" ]] || fail "--version is required with --non-interactive"
  OUT_DIR="${OUT_DIR:-$DEFAULT_OUT_DIR}"
  VOL_NAME="${VOL_NAME:-$DEFAULT_VOL_NAME}"

  validate_app_path "$APP_PATH" || fail "Invalid --app-path. Must be absolute .app path with Contents/Info.plist."
  validate_version "$VERSION" || fail "Invalid --version. Use SemVer, for example: 0.1.0 or 0.1.0-beta.1."
  validate_output_dir "$OUT_DIR" || fail "Invalid --output-dir. Use an absolute writable path."
  [[ -n "$VOL_NAME" ]] || fail "--volume-name cannot be empty."
  if [[ -n "$BACKGROUND_PATH" ]]; then
    validate_background_path "$BACKGROUND_PATH" || fail "Invalid --background-image. Must exist and be PNG/JPG/JPEG."
  fi
}

preflight_detach_volume() {
  local existing_dev
  existing_dev="$(hdiutil info | awk -v vol="$VOL_PATH" '$0 ~ vol {print dev; exit} {if ($1 ~ /^\/dev\//) dev=$1}')"
  if [[ -n "${existing_dev:-}" ]]; then
    log_warn "Found existing mounted volume at $VOL_PATH. Detaching..."
    hdiutil detach "$existing_dev" >/dev/null 2>&1 || hdiutil detach "$existing_dev" -force >/dev/null 2>&1 || true
    sleep 1
  fi
}

prepare_paths() {
  local safe_vol_name
  safe_vol_name="$(printf '%s' "$VOL_NAME" | tr ' /' '__')"
  STAGE_DIR="/tmp/${safe_vol_name}-dmg-stage"
  RW_DMG="/tmp/${safe_vol_name}-${VERSION}-rw.dmg"
  FINAL_DMG="${OUT_DIR}/${VOL_NAME}-${VERSION}-macos-arm64.dmg"
  VOL_PATH="/Volumes/${VOL_NAME}"
}

confirm_overwrite_if_needed() {
  local answer
  if [[ ! -e "$FINAL_DMG" ]]; then
    return 0
  fi

  if [[ "$FORCE_OVERWRITE" -eq 1 ]]; then
    rm -f "$FINAL_DMG"
    return 0
  fi

  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    fail "Final DMG already exists at $FINAL_DMG. Re-run with --force to overwrite."
  fi

  log_warn "Final DMG already exists:"
  printf "  %s\n" "$FINAL_DMG"
  read -r -p "Overwrite it? [y/N]: " answer
  if is_yes "$answer"; then
    rm -f "$FINAL_DMG"
  else
    fail "Aborted by user."
  fi
}

create_rw_dmg() {
  rm -rf "$STAGE_DIR" "$RW_DMG"
  mkdir -p "$STAGE_DIR/.background"

  cp -R "$APP_PATH" "$STAGE_DIR/HeadBird.app"
  ln -s /Applications "$STAGE_DIR/Applications"

  if [[ -n "$BACKGROUND_PATH" ]]; then
    cp "$BACKGROUND_PATH" "$STAGE_DIR/.background/background.png"
  fi

  hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE_DIR" -ov -format UDRW "$RW_DMG"
}

mount_dmg() {
  local attach_out
  attach_out="$(hdiutil attach "$RW_DMG")"
  MOUNTED_DEV="$(echo "$attach_out" | awk '/^\/dev\// {print $1; exit}')"
  [[ -n "$MOUNTED_DEV" ]] || fail "Failed to mount RW DMG."
}

wait_for_layout() {
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    log_info "Non-interactive mode: skipping Finder layout pause."
    return 0
  fi

  echo
  echo "Arrange the DMG window in Finder:"
  echo "1) Opened volume: $VOL_PATH"
  echo "2) Switch to Icon View (Cmd+1)"
  echo "3) Show View Options (Cmd+J)"
  echo "4) Move HeadBird.app to left, Applications alias to right"
  echo "5) Optional: set background to .background/background.png"
  echo "6) Close Finder window for this volume"
  echo
  open "$VOL_PATH"
  read -r -p "Press Enter after Finder layout is complete..."
}

detach_dmg() {
  if [[ "$PWD" == "$VOL_PATH"* ]]; then
    cd "$HOME"
  fi

  sync
  sleep 1

  if hdiutil detach "$MOUNTED_DEV"; then
    MOUNTED_DEV=""
    return 0
  fi

  log_warn "Normal detach failed. Trying force detach..."
  hdiutil detach "$MOUNTED_DEV" -force
  MOUNTED_DEV=""
}

convert_dmg() {
  local convert_log
  convert_log="$(mktemp)"
  if ! hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >"$convert_log" 2>&1; then
    cat "$convert_log" >&2
    rm -f "$convert_log"
    echo >&2
    printf "%s[ERROR]%s hdiutil convert failed.\n" "$C_RED" "$C_RESET" >&2
    if command -v lsof >/dev/null 2>&1; then
      printf "%s[WARN]%s Open handles on RW DMG (if any):\n" "$C_YELLOW" "$C_RESET" >&2
      lsof "$RW_DMG" >&2 || true
    fi
    printf "%s[INFO]%s Recovery:\n" "$C_BLUE" "$C_RESET" >&2
    echo "  1) Ensure volume is detached: hdiutil detach <device> -force" >&2
    echo "  2) Retry convert command manually:" >&2
    echo "     hdiutil convert \"$RW_DMG\" -format UDZO -imagekey zlib-level=9 -o \"$FINAL_DMG\"" >&2
    return 1
  fi
  rm -f "$convert_log"
}

print_checksum() {
  [[ -f "$FINAL_DMG" ]] || fail "Final DMG was not created: $FINAL_DMG"
  shasum -a 256 "$FINAL_DMG"
}

cleanup() {
  if [[ -n "${MOUNTED_DEV:-}" ]]; then
    hdiutil detach "$MOUNTED_DEV" >/dev/null 2>&1 || hdiutil detach "$MOUNTED_DEV" -force >/dev/null 2>&1 || true
  fi
  if [[ -n "${STAGE_DIR:-}" && -d "$STAGE_DIR" ]]; then
    rm -rf "$STAGE_DIR"
  fi
  if [[ "$SUCCESS" -eq 1 && -n "${RW_DMG:-}" && -f "$RW_DMG" ]]; then
    rm -f "$RW_DMG"
  fi
}

main() {
  trap cleanup EXIT

  load_defaults
  parse_args "$@"

  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    validate_non_interactive_inputs
  else
    collect_inputs_interactive
  fi

  prepare_paths
  confirm_overwrite_if_needed

  print_step "Preflight checks and stale mount cleanup"
  preflight_detach_volume

  print_step "Creating read-write DMG staging"
  create_rw_dmg

  print_step "Mounting DMG volume"
  mount_dmg

  print_step "Finder layout step"
  wait_for_layout

  print_step "Detaching mounted volume"
  detach_dmg

  print_step "Converting to compressed UDZO DMG"
  convert_dmg

  print_step "Calculating SHA-256 checksum"
  print_checksum

  print_step "Saving wizard defaults"
  save_defaults

  SUCCESS=1
  echo
  log_success "Done."
  printf "%sFinal DMG:%s\n  %s\n" "$C_BOLD" "$C_RESET" "$FINAL_DMG"
}

main "$@"
