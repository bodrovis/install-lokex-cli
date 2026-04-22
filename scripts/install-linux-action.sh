#!/usr/bin/env sh
set -eu

: "${ACTION_PATH:?missing ACTION_PATH}"
: "${INPUT_REPO:?missing INPUT_REPO}"
: "${INPUT_BIN_NAME:?missing INPUT_BIN_NAME}"
: "${INPUT_VERSION:?missing INPUT_VERSION}"
: "${INPUT_ADD_TO_PATH:?missing INPUT_ADD_TO_PATH}"
: "${GITHUB_OUTPUT:?missing GITHUB_OUTPUT}"
: "${GITHUB_PATH:?missing GITHUB_PATH}"

INSTALLER_REPO="bodrovis/lokex-cli"
INSTALLER_COMMIT="8baa06defa404d39510d56e0a045f838b89fd944"
INSTALLER_SHA256="b492ac1551f61011127f9196649e2f3ad25ffaa02c8f466fd524fa151e2265e7"

RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-3}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-2}"

if [ -n "${INPUT_INSTALL_DIR:-}" ]; then
  install_dir="$INPUT_INSTALL_DIR"
else
  install_dir="$HOME/.local/bin"
fi

installer_url="https://raw.githubusercontent.com/${INSTALLER_REPO}/${INSTALLER_COMMIT}/install.sh"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    echo "need sha256sum, shasum, or openssl" >&2
    exit 1
  fi
}

fetch_file() {
  url="$1"
  out="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
  else
    echo "need curl or wget" >&2
    exit 1
  fi
}

retry() {
  attempts="$1"
  delay="$2"
  shift 2

  n=1
  while :; do
    if "$@"; then
      return 0
    fi

    if [ "$n" -ge "$attempts" ]; then
      echo "command failed after ${attempts} attempts: $*" >&2
      return 1
    fi

    echo "attempt ${n}/${attempts} failed, retrying in ${delay}s: $*" >&2
    sleep "$delay"
    n=$((n + 1))
  done
}

need_cmd awk
need_cmd chmod
need_cmd mktemp
need_cmd sleep

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

installer_path="$tmpdir/install.sh"

echo "downloading pinned installer from ${INSTALLER_REPO}@${INSTALLER_COMMIT}"
retry "$RETRY_ATTEMPTS" "$RETRY_DELAY_SECONDS" fetch_file "$installer_url" "$installer_path"

actual_sha256="$(sha256_file "$installer_path")"

if [ "$actual_sha256" != "$INSTALLER_SHA256" ]; then
  echo "installer checksum mismatch" >&2
  echo "expected: $INSTALLER_SHA256" >&2
  echo "actual:   $actual_sha256" >&2
  exit 1
fi

chmod +x "$installer_path"

retry "$RETRY_ATTEMPTS" "$RETRY_DELAY_SECONDS" \
  env \
    REPO="$INPUT_REPO" \
    BIN_NAME="$INPUT_BIN_NAME" \
    VERSION="$INPUT_VERSION" \
    INSTALL_DIR="$install_dir" \
    "$installer_path"

if [ "$INPUT_ADD_TO_PATH" = "true" ]; then
  echo "$install_dir" >> "$GITHUB_PATH"
fi

echo "install-dir=$install_dir" >> "$GITHUB_OUTPUT"
echo "bin-path=$install_dir/$INPUT_BIN_NAME" >> "$GITHUB_OUTPUT"