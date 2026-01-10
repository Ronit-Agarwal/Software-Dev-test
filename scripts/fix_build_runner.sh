#!/bin/bash
# Script to fix build_runner conflicts by deleting conflicting generated files
# and completing code generation.

set -e

echo "=== Fixing build_runner conflicts ==="

# Navigate to project directory
cd "$(dirname "$0")"

# Step 1: Delete conflicting generated files
echo ""
echo "Step 1: Checking for conflicting generated files..."

# Check and delete permission_retry_test.mocks.dart if it exists
if [ -f "test/permission_retry_test.mocks.dart" ]; then
    echo "Deleting: test/permission_retry_test.mocks.dart"
    rm -f test/permission_retry_test.mocks.dart
else
    echo "test/permission_retry_test.mocks.dart not found (already deleted or never created)"
fi

# Check for any other .mocks.dart files
MOCKS_FILES=$(find test -name "*.mocks.dart" 2>/dev/null || true)
if [ -n "$MOCKS_FILES" ]; then
    echo "Found other .mocks.dart files:"
    echo "$MOCKS_FILES"
    for file in $MOCKS_FILES; do
        echo "Deleting: $file"
        rm -f "$file"
    done
fi

# Check for other generated files that might conflict
echo ""
echo "Checking for other potential conflicting files..."

# Delete .dart_tool folder if it exists (common cause of conflicts)
if [ -d ".dart_tool" ]; then
    echo "Deleting .dart_tool folder..."
    rm -rf .dart_tool
fi

# Delete build folder if it exists
if [ -d "build" ]; then
    echo "Deleting build folder..."
    rm -rf build
fi

echo ""
echo "Step 2: Running build_runner with delete option..."

# Step 2: Run build_runner with delete-conflicting-outputs
flutter packages pub run build_runner build --delete-conflicting-outputs

echo ""
echo "Step 3: Verifying generated files..."

# Step 3: Verify generated files exist
if [ -f "test/permission_retry_test.mocks.dart" ]; then
    echo "✓ test/permission_retry_test.mocks.dart exists"
else
    echo "✗ test/permission_retry_test.mocks.dart not found"
fi

# Check for lib/generated files
GENERATED_FILES=$(find lib -name "*.freezed.dart" -o -name "*.g.dart" 2>/dev/null | wc -l)
if [ "$GENERATED_FILES" -gt 0 ]; then
    echo "✓ Found $GENERATED_FILES generated files in lib/"
else
    echo "No generated files found in lib/ (may be expected if no freezed/json_serializable models exist)"
fi

echo ""
echo "=== Build runner fix completed successfully ==="
