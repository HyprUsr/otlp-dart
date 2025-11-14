# Publishing Checklist for otlp_dart

This document outlines the steps to publish the `otlp_dart` package to pub.dev.

## Pre-Publication Checklist

### ✅ Completed Items

- [x] **README.md** - Comprehensive documentation with examples
- [x] **CHANGELOG.md** - Detailed changelog following Keep a Changelog format
- [x] **LICENSE** - MIT License file present
- [x] **pubspec.yaml** - All metadata fields properly filled
- [x] **Examples** - Multiple working examples in `/example` directory
- [x] **Tests** - Comprehensive test suite (22 test cases for metrics)
- [x] **.pubignore** - Excludes proto source files and old test files
- [x] **Code Quality** - Unused imports removed
- [x] **Git Cleanup** - Removed deleted test files from git tracking

### 📋 Before Publishing

1. **Update Version Number** (if needed)
   ```bash
   # Edit pubspec.yaml - currently at 0.1.0
   # Consider bumping to 0.2.0 for metrics improvements
   ```

2. **Update CHANGELOG.md**
   - Move items from `[Unreleased]` to a new version section
   - Add release date
   - Example:
     ```markdown
     ## [0.2.0] - 2025-01-14

     ### Added
     - Full metrics SDK implementation...

     [0.2.0]: https://github.com/jamiewest/otlp-dart/releases/tag/v0.2.0
     ```

3. **Commit All Changes**
   ```bash
   git add .
   git commit -m "Prepare for v0.2.0 release - Add comprehensive metrics SDK"
   ```

4. **Run Final Checks**
   ```bash
   # Run tests
   dart test

   # Run analysis
   dart analyze

   # Dry run publish
   dart pub publish --dry-run
   ```

5. **Tag the Release**
   ```bash
   git tag -a v0.2.0 -m "Release v0.2.0 - Full metrics SDK"
   git push origin v0.2.0
   git push origin main
   ```

## Publishing Steps

### 1. Final Validation
```bash
dart pub publish --dry-run
```

Expected output:
- Package size: ~81 KB
- All critical warnings resolved
- Only informational messages about code style

### 2. Publish to pub.dev
```bash
dart pub publish
```

This will:
1. Show package contents
2. Ask for confirmation
3. Upload to pub.dev
4. Make the package publicly available

### 3. Post-Publication

1. **Verify on pub.dev**
   - Visit: https://pub.dev/packages/otlp_dart
   - Check that documentation renders correctly
   - Verify examples are visible

2. **Create GitHub Release**
   - Go to: https://github.com/jamiewest/otlp-dart/releases
   - Create a new release from the tag
   - Copy changelog content into release notes
   - Publish release

3. **Update Documentation**
   - Consider creating a docs site or wiki
   - Add usage examples to GitHub README
   - Create tutorial blog posts

4. **Announce**
   - Share on social media
   - Post in Dart/Flutter communities
   - Consider writing a blog post

## Known Warnings (Safe to Ignore)

The following warnings are informational and do not block publication:

1. **Code Style (`info`)** - Constructor ordering, const usage, trailing commas
   - These are style preferences, not errors
   - Can be addressed in future updates

2. **Example Code (`avoid_print`)** - Print statements in examples
   - Acceptable for example code
   - Examples are meant to be simple and educational

3. **Git State** - Modified files warning
   - Expected when making pre-publication changes
   - Will be resolved after final commit

## Package Metadata

Current package details:
- **Name**: otlp_dart
- **Version**: 0.1.0 (consider bumping to 0.2.0)
- **Description**: OpenTelemetry Protocol (OTLP) client library for Dart
- **Repository**: https://github.com/jamiewest/otlp-dart
- **License**: MIT
- **SDK**: '>=3.0.0 <4.0.0'

## What's New in This Release

### Major Features Added
- ✅ Full metrics SDK implementation
- ✅ All instrument types (Counter, UpDownCounter, Histogram, ObservableGauge, ObservableCounter)
- ✅ HTTP/2 with Protobuf support for Aspire
- ✅ Comprehensive test coverage (22 tests)
- ✅ Delta temporality support
- ✅ Production-ready metrics example

### Bug Fixes
- Fixed critical SDK bugs for .NET Aspire Dashboard compatibility
- Fixed attribute serialization for metric grouping
- Fixed metric collection lifecycle

### Improvements
- Enhanced documentation with detailed metrics examples
- Added comprehensive test suite
- Improved error handling

## Troubleshooting

### Issue: "Package validation failed"
- Run `dart pub publish --dry-run` to see specific issues
- Address any warnings or errors shown
- Most common: missing LICENSE, README, or CHANGELOG

### Issue: "Authentication failed"
- Run `dart pub login` to authenticate with pub.dev
- Follow the OAuth flow in your browser

### Issue: "Version already published"
- Increment version number in pubspec.yaml
- Update CHANGELOG.md with new version
- Create new git tag

### Issue: "Package too large"
- Check `.pubignore` is excluding unnecessary files
- Current size: 81 KB (well under 100 MB limit)
- Proto source files are excluded via .pubignore

## Support

For issues or questions:
- GitHub Issues: https://github.com/jamiewest/otlp-dart/issues
- pub.dev Page: https://pub.dev/packages/otlp_dart (after publishing)

## References

- [Publishing packages](https://dart.dev/tools/pub/publishing)
- [Package layout conventions](https://dart.dev/tools/pub/package-layout)
- [Pubspec format](https://dart.dev/tools/pub/pubspec)
- [Semantic versioning](https://semver.org/)
