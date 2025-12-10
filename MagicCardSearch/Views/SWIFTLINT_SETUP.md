# SwiftLint Setup Guide for MagicCardSearch

## What is SwiftLint?

SwiftLint is a tool to enforce Swift style and conventions, loosely based on the [Swift Style Guide](https://google.github.io/swift/). It helps maintain consistent code quality across your project.

## Installation

### Option 1: Homebrew (Recommended for personal development)

```bash
brew install swiftlint
```

### Option 2: CocoaPods (If you're already using CocoaPods)

Add to your `Podfile`:

```ruby
pod 'SwiftLint'
```

Then run:

```bash
pod install
```

### Option 3: Mint (Package manager for Swift command-line tools)

```bash
brew install mint
mint install realm/SwiftLint
```

### Option 4: Download from GitHub Releases

Download the latest `.pkg` file from [SwiftLint Releases](https://github.com/realm/SwiftLint/releases) and install it.

## Verify Installation

After installation, verify SwiftLint is available:

```bash
swiftlint version
```

## Xcode Integration

### Automatic Linting with Build Phase

1. **Open your Xcode project**
2. **Select your target** (MagicCardSearch)
3. **Go to Build Phases tab**
4. **Click the '+' button** and select "New Run Script Phase"
5. **Name the phase** "SwiftLint" (by expanding the new phase)
6. **Add the following script**:

```bash
if [[ "$(uname -m)" == arm64 ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

if which swiftlint > /dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

7. **Drag the SwiftLint phase** to be just after "Dependencies" (before "Compile Sources")

### For CocoaPods Installation

If you installed via CocoaPods, use this script instead:

```bash
"${PODS_ROOT}/SwiftLint/swiftlint"
```

### Build Phase Script with Auto-Fix (Optional)

If you want SwiftLint to automatically fix some issues during build:

```bash
if [[ "$(uname -m)" == arm64 ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

if which swiftlint > /dev/null; then
  swiftlint --fix && swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

**Note:** Auto-fix during build can modify your files, so use with caution.

## Command Line Usage

### Lint your entire project
```bash
swiftlint
```

### Auto-fix violations
```bash
swiftlint --fix
```

### Lint specific files
```bash
swiftlint lint --path Sources/
```

### Lint and display full rule descriptions
```bash
swiftlint lint --verbose
```

### Generate HTML report
```bash
swiftlint lint --reporter html > swiftlint-report.html
```

## Xcode Warnings and Errors

After integration, SwiftLint violations will appear as:
- **Warnings** (yellow) - Issues to fix but won't prevent building
- **Errors** (red) - Critical issues that prevent building (based on configuration)

Click on any warning/error to jump directly to the problematic code.

## Configuration

The `.swiftlint.yml` file in your project root controls SwiftLint's behavior. The configuration provided includes:

### Key Features:
- **Balanced rules** for code quality without being overly restrictive
- **SwiftUI-friendly** settings
- **Modern Swift practices** encouraged (async/await over callbacks)
- **Reasonable limits** for file/function lengths
- **Opt-in advanced rules** for better code quality
- **Custom rules** to encourage Swift Concurrency

### Common Customizations:

#### Disable a rule globally
Add to the `disabled_rules` section:
```yaml
disabled_rules:
  - trailing_whitespace
```

#### Disable a rule in specific code
Use comments in your Swift files:
```swift
// swiftlint:disable force_cast
let myVar = someValue as! MyType
// swiftlint:enable force_cast
```

Or for a single line:
```swift
let myVar = someValue as! MyType // swiftlint:disable:this force_cast
```

#### Adjust rule severity
```yaml
force_cast: error  # Change from warning to error
```

## Continuous Integration

For CI/CD pipelines, you can make warnings fail the build:

```yaml
# In .swiftlint.yml
strict: true
```

Or use the command line flag:
```bash
swiftlint --strict
```

## Pre-commit Hook (Optional)

To lint staged files before committing:

1. Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash

if which swiftlint > /dev/null; then
  swiftlint --strict --quiet
else
  echo "warning: SwiftLint not installed"
fi
```

2. Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Viewing All Available Rules

```bash
swiftlint rules
```

## Common Issues and Solutions

### Issue: "swiftlint: command not found"
**Solution:** Ensure SwiftLint is in your PATH. For Apple Silicon Macs, add the export PATH line to the build script.

### Issue: Too many warnings initially
**Solution:** Start by running `swiftlint --fix` to auto-correct simple issues. For remaining issues, gradually enable rules or adjust thresholds.

### Issue: Build phase doesn't show violations
**Solution:** Ensure the SwiftLint phase runs before "Compile Sources" and that the script has proper permissions.

### Issue: Different results in Xcode vs command line
**Solution:** Ensure you're using the same SwiftLint version. Check with `swiftlint version`.

## Next Steps

1. Install SwiftLint using your preferred method
2. Add the build phase to your Xcode project
3. Build your project to see current violations
4. Run `swiftlint --fix` to auto-fix simple issues
5. Review remaining violations and fix manually
6. Adjust `.swiftlint.yml` as needed for your team's preferences

## Resources

- [SwiftLint GitHub](https://github.com/realm/SwiftLint)
- [SwiftLint Rules Reference](https://realm.github.io/SwiftLint/rule-directory.html)
- [Swift Style Guide](https://google.github.io/swift/)

---

**Pro Tip:** Start with lenient settings and gradually make them stricter as your team gets comfortable with the tool. The provided configuration is already quite reasonable for most projects.
