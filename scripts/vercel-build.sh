#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(pwd)"
FLUTTER_VERSION="3.24.0"
FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "Installing Flutter ${FLUTTER_VERSION}..."
  git clone https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

cd "$FLUTTER_DIR"
git fetch --tags
git checkout "${FLUTTER_VERSION}"

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version
flutter config --enable-web

cd "$PROJECT_DIR"
flutter pub get
flutter build web --release --base-href /
