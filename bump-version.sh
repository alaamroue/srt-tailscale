#!/bin/bash
set -e

# Determine bump type (default: patch)
BUMP=${1:-patch}

# Get the latest tag or default to v0.0.0
CURRENT_TAG=$(git describe --tags `git rev-list --tags --max-count=1` 2>/dev/null || echo "v0.0.0")

echo "Current version: $CURRENT_TAG"

# Remove the leading v and split into components
VERSION=${CURRENT_TAG#v}
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

case "$BUMP" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "Usage: ./bump-version.sh [major|minor|patch]"
    exit 1
    ;;
esac

NEW_TAG="v${MAJOR}.${MINOR}.${PATCH}"
echo "New version: $NEW_TAG"

# Check if okay
read -p "Switch to new tag? " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "Aborting."
  exit 1
fi

# Create and push new tag
git tag "$NEW_TAG"
