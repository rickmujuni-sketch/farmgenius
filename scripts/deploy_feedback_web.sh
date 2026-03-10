#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is required but not found in PATH." >&2
  exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "Firebase CLI is required. Install with: npm install -g firebase-tools" >&2
  exit 1
fi

PROJECT_ID="${1:-}"
if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: ./scripts/deploy_feedback_web.sh <firebase-project-id>" >&2
  exit 1
fi

echo "Building Flutter web release..."
flutter build web --release

echo "Deploying to Firebase Hosting project: $PROJECT_ID"
firebase deploy --only hosting --project "$PROJECT_ID"

echo "Done. Share the Hosting URL shown above with trusted reviewers."
