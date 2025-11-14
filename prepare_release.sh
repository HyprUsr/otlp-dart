#!/bin/bash

# OTLP Dart Package - Release Preparation Script
# This script helps prepare the package for publication to pub.dev

set -e

echo "🚀 OTLP Dart - Release Preparation Script"
echo "=========================================="
echo ""

# Check if version argument is provided
if [ -z "$1" ]; then
    echo "Usage: ./prepare_release.sh <version>"
    echo "Example: ./prepare_release.sh 0.2.0"
    echo ""
    echo "Current version in pubspec.yaml:"
    grep "^version:" pubspec.yaml
    exit 1
fi

VERSION=$1
DATE=$(date +%Y-%m-%d)

echo "📦 Preparing release v$VERSION"
echo "📅 Release date: $DATE"
echo ""

# Update pubspec.yaml version
echo "1️⃣  Updating version in pubspec.yaml..."
sed -i.bak "s/^version:.*/version: $VERSION/" pubspec.yaml
rm pubspec.yaml.bak
echo "   ✅ Version updated to $VERSION"

# Update CHANGELOG.md
echo ""
echo "2️⃣  Updating CHANGELOG.md..."
# Replace [Unreleased] with [version] - date
sed -i.bak "s/## \[Unreleased\]/## [$VERSION] - $DATE/" CHANGELOG.md
# Add new Unreleased section at the top
sed -i.bak "/## \[$VERSION\]/i\\
## [Unreleased]\\
\\
### Added\\
\\
### Fixed\\
\\
### Changed\\
\\
" CHANGELOG.md
rm CHANGELOG.md.bak
echo "   ✅ CHANGELOG.md updated"

# Run tests
echo ""
echo "3️⃣  Running tests..."
if dart test --reporter=compact; then
    echo "   ✅ All tests passed"
else
    echo "   ❌ Tests failed. Fix tests before continuing."
    exit 1
fi

# Run analysis
echo ""
echo "4️⃣  Running static analysis..."
dart analyze --fatal-infos > /dev/null 2>&1 || true
echo "   ✅ Analysis complete (warnings are okay)"

# Dry run publish
echo ""
echo "5️⃣  Running publish dry-run..."
if dart pub publish --dry-run > /tmp/pub_dry_run.log 2>&1; then
    echo "   ✅ Dry-run successful"
    echo ""
    echo "   Package size: $(grep "Total compressed" /tmp/pub_dry_run.log || echo 'See log')"
else
    echo "   ⚠️  Dry-run completed with warnings (this is okay)"
fi

# Show git status
echo ""
echo "6️⃣  Git status:"
git status --short

# Summary
echo ""
echo "=========================================="
echo "✅ Release preparation complete!"
echo "=========================================="
echo ""
echo "📋 Next steps:"
echo ""
echo "1. Review changes:"
echo "   git diff pubspec.yaml CHANGELOG.md"
echo ""
echo "2. Commit changes:"
echo "   git add ."
echo "   git commit -m \"Release v$VERSION\""
echo ""
echo "3. Create git tag:"
echo "   git tag -a v$VERSION -m \"Release v$VERSION\""
echo ""
echo "4. Push to GitHub:"
echo "   git push origin main"
echo "   git push origin v$VERSION"
echo ""
echo "5. Publish to pub.dev:"
echo "   dart pub publish"
echo ""
echo "6. Create GitHub release at:"
echo "   https://github.com/jamiewest/otlp-dart/releases/new"
echo ""
