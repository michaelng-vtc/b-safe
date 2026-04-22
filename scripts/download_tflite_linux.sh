#!/usr/bin/env bash
# Build libtensorflowlite_c-linux.so from source and place it in blobs/
# Required by tflite_flutter ^0.12.x on Linux desktop.
# Run from the project root: bash scripts/download_tflite_linux.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEST="$PROJECT_DIR/blobs/libtensorflowlite_c-linux.so"

if [[ -f "$DEST" ]]; then
  echo "Already present: $DEST"
  exit 0
fi

mkdir -p "$PROJECT_DIR/blobs"

TF_TAG="v2.21.0-rc0"
BUILD_DIR="$(mktemp -d)"
trap "rm -rf '$BUILD_DIR'" EXIT

echo "==> Cloning TensorFlow $TF_TAG (shallow, ~1 GB)..."
git clone --depth=1 --branch "$TF_TAG" \
  https://github.com/tensorflow/tensorflow.git "$BUILD_DIR/tensorflow-src"

echo "==> Configuring cmake..."
mkdir -p "$BUILD_DIR/build"
cmake "$BUILD_DIR/tensorflow-src/tensorflow/lite/c" \
  -B "$BUILD_DIR/build" \
  -DTFLITE_C_BUILD_SHARED_LIBS=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DTF_SOURCE_DIR="$BUILD_DIR/tensorflow-src" \
  -DFETCHCONTENT_SOURCE_DIR_TENSORFLOW="$BUILD_DIR/tensorflow-src"

echo "==> Building (this takes ~10-20 min with $(nproc) cores)..."
cmake --build "$BUILD_DIR/build" --target tensorflowlite_c --parallel "$(nproc)"

cp "$BUILD_DIR/build/libtensorflowlite_c.so" "$DEST"
echo "==> Done: $DEST"
