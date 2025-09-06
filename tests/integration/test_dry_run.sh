#!/bin/bash

# Integration test for dry-run functionality

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_DIR/bin/emoji-sad"

# Test configuration
TEST_DIR="/tmp/emoji_test_dry_run_$$"
EXPECTED_FILES_WITH_EMOJIS=5  # emojis.txt, mixed.md, data.json, example.go, nested.txt

echo "=== Testing Dry Run Functionality ==="

# Setup test data
echo "Setting up test data..."
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# File with various emojis
echo "Hello 😊 World 🌍 Test 🚀 More emojis: ✨ 🎉 💯" > "$TEST_DIR/emojis.txt"

# File with no emojis
echo "This is a clean file with no emojis at all." > "$TEST_DIR/clean.txt"

# File with mixed content
cat > "$TEST_DIR/mixed.md" << 'EOF'
# My Project 🚀

This is a markdown file with some emojis.

## Features
- Fast processing ⚡
- User friendly 😊
- Cross platform 🌐

## Installation
```bash
go install myproject
```

Regular text without emojis here.
EOF

# JSON file with emojis
cat > "$TEST_DIR/data.json" << 'EOF'
{
  "message": "Welcome 👋",
  "status": "success ✅",
  "emoji_count": 2,
  "description": "This JSON has emojis 🎯"
}
EOF

# Code file with emojis in comments
cat > "$TEST_DIR/example.go" << 'EOF'
package main

import "fmt"

// This is a sample Go file 🔥
func main() {
    // Print hello message 👋
    fmt.Println("Hello World") // Clean code here
    
    // Some emoji in string 🚀
    message := "No emojis in this string"
    fmt.Println(message)
}
EOF

# Empty file
touch "$TEST_DIR/empty.txt"

# Binary-like file to test skipping
echo -e "\x00\x01\x02\x03" > "$TEST_DIR/binary.bin"

# Subdirectory with files
mkdir -p "$TEST_DIR/subdir"
echo "Subdirectory file with emoji 🎈" > "$TEST_DIR/subdir/nested.txt"
echo "Clean subdirectory file" > "$TEST_DIR/subdir/clean_nested.txt"

# Verify test data was created
if [ ! -d "$TEST_DIR" ]; then
    echo "FAIL: Test directory was not created"
    exit 1
fi

# Count files before
files_before=$(find "$TEST_DIR" -type f | wc -l)
echo "Files created: $files_before"

# Run dry-run (default behavior)
echo "Running dry-run..."
output=$("$BINARY" "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Dry-run command failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

echo "Dry-run output:"
echo "$output"
echo

# Verify output contains expected elements
if ! echo "$output" | grep -q "DRY RUN:"; then
    echo "FAIL: Output should contain 'DRY RUN:'"
    exit 1
fi

if ! echo "$output" | grep -q "Would remove.*emoji"; then
    echo "FAIL: Output should mention emojis would be removed"
    exit 1
fi

if ! echo "$output" | grep -q "Run with --no-dry-run"; then
    echo "FAIL: Output should suggest running with --no-dry-run"
    exit 1
fi

# Verify no files were actually modified
echo "Checking that files were not modified..."

# Check that files still contain emojis
if ! grep -q "😊" "$TEST_DIR/emojis.txt"; then
    echo "FAIL: emojis.txt should still contain emojis after dry-run"
    exit 1
fi

if ! grep -q "🚀" "$TEST_DIR/mixed.md"; then
    echo "FAIL: mixed.md should still contain emojis after dry-run"
    exit 1
fi

if ! grep -q "👋" "$TEST_DIR/data.json"; then
    echo "FAIL: data.json should still contain emojis after dry-run"
    exit 1
fi

if ! grep -q "🔥" "$TEST_DIR/example.go"; then
    echo "FAIL: example.go should still contain emojis after dry-run"
    exit 1
fi

if ! grep -q "🎈" "$TEST_DIR/subdir/nested.txt"; then
    echo "FAIL: nested.txt should still contain emojis after dry-run"
    exit 1
fi

# Verify file count hasn't changed
files_after=$(find "$TEST_DIR" -type f | wc -l)
if [ $files_before -ne $files_after ]; then
    echo "FAIL: File count changed from $files_before to $files_after"
    exit 1
fi

# Clean up
rm -rf "$TEST_DIR"

echo "PASS: Dry-run functionality works correctly"
echo "✓ Files were not modified"
echo "✓ Output format is correct"
echo "✓ Exit code is success"
echo