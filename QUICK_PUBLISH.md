# Quick Publish Guide

Fast-track commands to publish `otlp_dart` to pub.dev.

## Option 1: Publish Current Version (0.1.0)

If you want to publish the current version as-is:

```bash
# 1. Commit all changes
git add .
git commit -m "Add comprehensive metrics SDK and improve test coverage"

# 2. Push to GitHub
git push origin main

# 3. Publish to pub.dev
dart pub publish
```

## Option 2: Publish as New Version (0.2.0) - RECOMMENDED

For the new metrics features, bumping to 0.2.0 is recommended:

```bash
# 1. Update version in pubspec.yaml
# Change: version: 0.1.0
# To:     version: 0.2.0

# 2. Update CHANGELOG.md
# Move [Unreleased] section to [0.2.0] - 2025-01-14

# 3. Commit changes
git add .
git commit -m "Release v0.2.0 - Comprehensive metrics SDK implementation"

# 4. Tag the release
git tag -a v0.2.0 -m "Release v0.2.0 - Full metrics SDK with all instrument types"

# 5. Push everything
git push origin main
git push origin v0.2.0

# 6. Publish to pub.dev
dart pub publish
```

## Pre-Publish Checks (Quick)

```bash
# Run all tests
dart test

# Check for issues
dart analyze

# Preview what will be published
dart pub publish --dry-run
```

## After Publishing

1. **Verify on pub.dev**: https://pub.dev/packages/otlp_dart
2. **Create GitHub Release**: https://github.com/jamiewest/otlp-dart/releases/new
3. **Share the news!**

## Current Status ✅

- ✅ README.md - Complete with examples
- ✅ CHANGELOG.md - Updated with new features
- ✅ LICENSE - MIT License
- ✅ Tests - 22 comprehensive metrics tests passing
- ✅ Examples - 4 working examples
- ✅ .pubignore - Configured
- ✅ Package size - 81 KB (optimized)
- ⚠️ Git state - Modified files (will be resolved after commit)

## What You're Publishing

### New Features (since 0.1.0)
- Full metrics SDK with Counter, UpDownCounter, Histogram, ObservableGauge, ObservableCounter
- PeriodicMetricReader with configurable intervals
- Delta temporality support
- HTTP/2 with Protobuf for Aspire
- Comprehensive test suite (22 tests)
- Production-ready metrics example

### Bug Fixes
- Critical Aspire Dashboard compatibility fixes
- Attribute serialization improvements
- Metric lifecycle fixes

## Need Help?

See [PUBLISHING.md](PUBLISHING.md) for detailed instructions.
