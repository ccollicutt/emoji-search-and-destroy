#!/bin/bash

# Integration test for actual emoji removal functionality

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_DIR/bin/emoji-sad"

# Test configuration
TEST_DIR="/tmp/emoji_test_removal_$$"

echo "=== Testing Emoji Removal Functionality ==="

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

# Store original content for comparison
original_emojis=$(cat "$TEST_DIR/emojis.txt")
original_mixed=$(cat "$TEST_DIR/mixed.md")
original_json=$(cat "$TEST_DIR/data.json")
original_go=$(cat "$TEST_DIR/example.go")
original_nested=$(cat "$TEST_DIR/subdir/nested.txt")
original_clean=$(cat "$TEST_DIR/clean.txt")

echo "Original files created and content stored"

# Run emoji removal (not dry-run)
echo "Running emoji removal..."
output=$("$BINARY" --no-dry-run "$TEST_DIR" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "FAIL: Emoji removal command failed with exit code $exit_code"
    echo "Output: $output"
    exit 1
fi

echo "Removal output:"
echo "$output"
echo

# Verify output format
if echo "$output" | grep -q "DRY RUN:"; then
    echo "FAIL: Output should not contain 'DRY RUN:' in actual removal"
    exit 1
fi

if ! echo "$output" | grep -q "Processed.*file"; then
    echo "FAIL: Output should mention processed files"
    exit 1
fi

if ! echo "$output" | grep -q "Removed.*emoji"; then
    echo "FAIL: Output should mention removed emojis"
    exit 1
fi

# Verify emojis were actually removed
echo "Checking that emojis were removed from files..."

# Check emojis.txt
new_emojis=$(cat "$TEST_DIR/emojis.txt")
if echo "$new_emojis" | grep -q "😊\|🌍\|🚀\|✨\|🎉\|💯"; then
    echo "FAIL: emojis.txt still contains emojis: $new_emojis"
    exit 1
fi

if [ "$new_emojis" != "Hello  World  Test  More emojis:   " ]; then
    echo "FAIL: emojis.txt content is not as expected: '$new_emojis'"
    exit 1
fi

# Check mixed.md
new_mixed=$(cat "$TEST_DIR/mixed.md")
if echo "$new_mixed" | grep -q "🚀\|⚡\|😊\|🌐"; then
    echo "FAIL: mixed.md still contains emojis"
    exit 1
fi

# Check data.json
new_json=$(cat "$TEST_DIR/data.json")
if echo "$new_json" | grep -q "👋\|✅\|🎯"; then
    echo "FAIL: data.json still contains emojis"
    exit 1
fi

# Check example.go
new_go=$(cat "$TEST_DIR/example.go")
if echo "$new_go" | grep -q "🔥\|👋\|🚀"; then
    echo "FAIL: example.go still contains emojis"
    exit 1
fi

# Check nested file
new_nested=$(cat "$TEST_DIR/subdir/nested.txt")
if echo "$new_nested" | grep -q "🎈"; then
    echo "FAIL: nested.txt still contains emojis"
    exit 1
fi

# Verify clean files were not modified
new_clean=$(cat "$TEST_DIR/clean.txt")
if [ "$new_clean" != "$original_clean" ]; then
    echo "FAIL: clean.txt was modified when it shouldn't have been"
    echo "Original: $original_clean"
    echo "New: $new_clean"
    exit 1
fi

clean_nested=$(cat "$TEST_DIR/subdir/clean_nested.txt")
if [ "$clean_nested" != "Clean subdirectory file" ]; then
    echo "FAIL: clean_nested.txt was modified when it shouldn't have been"
    exit 1
fi

# Verify empty file remains empty
if [ -s "$TEST_DIR/empty.txt" ]; then
    echo "FAIL: empty.txt should remain empty"
    exit 1
fi

# Verify binary files were not processed
binary_content=$(cat "$TEST_DIR/binary.bin")
if [ ${#binary_content} -eq 0 ]; then
    echo "FAIL: binary.bin appears to have been processed (content is empty)"
    exit 1
fi

# Test that reasonable text remains after emoji removal
if ! echo "$new_emojis" | grep -q "Hello.*World.*Test"; then
    echo "FAIL: Essential text was removed from emojis.txt"
    exit 1
fi

if ! echo "$new_mixed" | grep -q "# My Project"; then
    echo "FAIL: Essential text was removed from mixed.md"
    exit 1
fi

if ! echo "$new_json" | grep -q '"message":\|"status":'; then
    echo "FAIL: Essential JSON structure was removed"
    exit 1
fi

if ! echo "$new_go" | grep -q "package main\|func main"; then
    echo "FAIL: Essential Go code was removed"
    exit 1
fi

# Clean up
rm -rf "$TEST_DIR"

echo "PASS: Emoji removal functionality works correctly"
echo "✓ Emojis were removed from files containing them"
echo "✓ Files without emojis were left unchanged"
echo "✓ Binary files were skipped"
echo "✓ Text content was preserved after emoji removal"
echo "✓ Output format is correct"
echo