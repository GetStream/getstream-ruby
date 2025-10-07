#!/bin/bash

# Version bump script for GetStream Ruby SDK
# Usage: ./scripts/version-bump.sh [major|minor|patch] [release_notes]

set -e

VERSION_TYPE="${1:-patch}"
RELEASE_NOTES="${2:-}"

if [[ ! "$VERSION_TYPE" =~ ^(major|minor|patch)$ ]]; then
    echo "Error: Version type must be major, minor, or patch"
    echo "Usage: $0 [major|minor|patch] [release_notes]"
    exit 1
fi

# Get current version
CURRENT_VERSION=$(ruby -r "./lib/getstream_ruby/version.rb" -e "puts GetStreamRuby::VERSION")
echo "Current version: $CURRENT_VERSION"

# Parse version components
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"

# Calculate new version
case "$VERSION_TYPE" in
    "major")
        NEW_VERSION="$((major + 1)).0.0"
        ;;
    "minor")
        NEW_VERSION="$major.$((minor + 1)).0"
        ;;
    "patch")
        NEW_VERSION="$major.$minor.$((patch + 1))"
        ;;
esac

echo "New version: $NEW_VERSION"

# Update version.rb
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/VERSION = '[^']*'/VERSION = '$NEW_VERSION'/" "lib/getstream_ruby/version.rb"
    sed -i '' "s/spec\.version\s*=\s*'[^']*'/spec.version       = '$NEW_VERSION'/" "getstream-ruby.gemspec"
else
    # Linux/CI
    sed -i "s/VERSION = '[^']*'/VERSION = '$NEW_VERSION'/" "lib/getstream_ruby/version.rb"
    sed -i "s/spec\.version\s*=\s*'[^']*'/spec.version       = '$NEW_VERSION'/" "getstream-ruby.gemspec"
fi

echo "Updated version files to $NEW_VERSION"

# Update CHANGELOG
CHANGELOG_FILE="CHANGELOG.md"

# Create CHANGELOG.md if it doesn't exist
if [ ! -f "$CHANGELOG_FILE" ]; then
    cat > "$CHANGELOG_FILE" << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF
fi

# Add new version entry
TEMP_FILE=$(mktemp)
echo "## [$NEW_VERSION] - $(date +%Y-%m-%d)" >> "$TEMP_FILE"
echo "" >> "$TEMP_FILE"

if [ -n "$RELEASE_NOTES" ]; then
    echo "$RELEASE_NOTES" >> "$TEMP_FILE"
else
    echo "### $VERSION_TYPE^2 changes" >> "$TEMP_FILE"
    echo "- " >> "$TEMP_FILE"
fi

echo "" >> "$TEMP_FILE"
cat "$CHANGELOG_FILE" >> "$TEMP_FILE"
mv "$TEMP_FILE" "$CHANGELOG_FILE"

echo "Updated CHANGELOG.md"

echo "✅ Version bump complete: $CURRENT_VERSION → $NEW_VERSION"
echo "Files updated:"
echo "  - lib/getstream_ruby/version.rb"
echo "  - getstream-ruby.gemspec"
echo "  - CHANGELOG.md"
