#!/bin/bash

# Integration test for default dry-run behavior and --no-dry-run flag

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_DIR/bin/emoji-sad"

# Test configuration
TEST_DIR="/tmp/emoji_test_default_$$"

echo "=== Testing Default Dry-Run Behavior ==="

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

# Test 1: Default behavior should be dry-run
echo "Testing default behavior (should be dry-run)..."
output=$("$BINARY" "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Default command failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

# Verify output contains dry-run indicators
if ! echo "$output" | grep -q "DRY RUN:"; then
    echo "FAIL: Default behavior should be dry-run (missing 'DRY RUN:')"
    exit 1
fi

if ! echo "$output" | grep -q "Run with --no-dry-run"; then
    echo "FAIL: Should suggest using --no-dry-run"
    exit 1
fi

# Verify files were not modified - check multiple files to be thorough
if ! grep -q "😊" "$TEST_DIR/emojis.txt"; then
    echo "FAIL: emojis.txt should not be modified in default mode"
    exit 1
fi

if ! grep -q "🚀" "$TEST_DIR/mixed.md"; then
    echo "FAIL: mixed.md should not be modified in default mode"
    exit 1
fi

if ! grep -q "👋" "$TEST_DIR/data.json"; then
    echo "FAIL: data.json should not be modified in default mode"
    exit 1
fi

if ! grep -q "🔥" "$TEST_DIR/example.go"; then
    echo "FAIL: example.go should not be modified in default mode"
    exit 1
fi

if ! grep -q "🎈" "$TEST_DIR/subdir/nested.txt"; then
    echo "FAIL: nested.txt should not be modified in default mode"
    exit 1
fi

echo "✓ Default behavior is dry-run"

# Test 2: --no-dry-run should actually modify files
echo "Testing --no-dry-run flag..."
output=$("$BINARY" --no-dry-run "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: --no-dry-run command failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

# Verify output does not contain dry-run indicators
if echo "$output" | grep -q "DRY RUN:"; then
    echo "FAIL: --no-dry-run should not show 'DRY RUN:'"
    exit 1
fi

if echo "$output" | grep -q "Would remove"; then
    echo "FAIL: --no-dry-run should not show 'Would remove'"
    exit 1
fi

if ! echo "$output" | grep -q "Removed.*emoji"; then
    echo "FAIL: --no-dry-run should show 'Removed' messages"
    exit 1
fi

# Verify files were actually modified
if grep -q "😊" "$TEST_DIR/emojis.txt"; then
    echo "FAIL: Files should be modified with --no-dry-run"
    exit 1
fi

echo "✓ --no-dry-run modifies files"

# Test 3 removed since --dry-run flag no longer exists

# Clean up
rm -rf "$TEST_DIR"

echo "PASS: All default behavior tests passed"
echo "✓ Default behavior is dry-run"
echo "✓ --no-dry-run enables modifications"
echo