#!/bin/bash

# Integration test for edge cases and error conditions

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_DIR/bin/emoji-sad"

echo "=== Testing Edge Cases and Error Conditions ==="

# Test 1: Non-existent directory
echo "Test 1: Non-existent directory"
output=$("$BINARY" "/non/existent/directory" 2>&1 || true)
if echo "$output" | grep -q "directory does not exist"; then
    echo "✓ Correctly handles non-existent directory"
else
    echo "FAIL: Should report non-existent directory error"
    echo "Output: $output"
    exit 1
fi

# Test 2: Empty directory
echo "Test 2: Empty directory"
empty_dir="/tmp/emoji_test_empty_$$"
mkdir -p "$empty_dir"
output=$("$BINARY" "$empty_dir" 2>&1)
if echo "$output" | grep -q "No emojis found"; then
    echo "✓ Correctly handles empty directory"
else
    echo "FAIL: Should report no emojis found for empty directory"
    echo "Output: $output"
    exit 1
fi
rm -rf "$empty_dir"

# Test 3: Directory with only binary files
echo "Test 3: Directory with only binary files"
binary_dir="/tmp/emoji_test_binary_$$"
mkdir -p "$binary_dir"
echo -e "\x00\x01\x02\x03" > "$binary_dir/file.bin"
echo -e "\xFF\xFE\xFD\xFC" > "$binary_dir/file.exe"
dd if=/dev/zero of="$binary_dir/file.jpg" bs=1024 count=1 2>/dev/null
output=$("$BINARY" "$binary_dir" 2>&1)
if echo "$output" | grep -q "No emojis found"; then
    echo "✓ Correctly skips binary files"
else
    echo "FAIL: Should skip binary files and report no emojis"
    echo "Output: $output"
    exit 1
fi
rm -rf "$binary_dir"

# Test 4: Directory with only clean text files
echo "Test 4: Directory with only clean text files"
clean_dir="/tmp/emoji_test_clean_$$"
mkdir -p "$clean_dir"
echo "No emojis here" > "$clean_dir/clean1.txt"
echo "Just plain text" > "$clean_dir/clean2.txt"
echo "function main() { return 0; }" > "$clean_dir/code.c"
output=$("$BINARY" "$clean_dir" 2>&1)
if echo "$output" | grep -q "No emojis found"; then
    echo "✓ Correctly handles directory with no emojis"
else
    echo "FAIL: Should report no emojis found"
    echo "Output: $output"
    exit 1
fi
rm -rf "$clean_dir"

# Test 5: File with only emoji characters
echo "Test 5: File with only emoji characters"
emoji_only_dir="/tmp/emoji_test_only_$$"
mkdir -p "$emoji_only_dir"
echo "😊🌍🚀✨" > "$emoji_only_dir/only_emojis.txt"
output=$("$BINARY" --no-dry-run "$emoji_only_dir" 2>&1)
if echo "$output" | grep -q "Removed.*emoji" && echo "$output" | grep -q "4"; then
    echo "✓ Correctly handles file with only emojis"
    # Check that file is now empty or nearly empty
    content=$(cat "$emoji_only_dir/only_emojis.txt")
    if [ -z "$content" ] || [ "$content" = " " ]; then
        echo "✓ File correctly emptied after emoji removal"
    else
        echo "FAIL: File should be empty after removing all emojis, but contains: '$content'"
        exit 1
    fi
else
    echo "FAIL: Should remove emojis from emoji-only file"
    echo "Output: $output"
    exit 1
fi
rm -rf "$emoji_only_dir"

# Test 6: Very large file with emojis
echo "Test 6: Large file with emojis"
large_dir="/tmp/emoji_test_large_$$"
mkdir -p "$large_dir"
# Create a file with repeated content including emojis
for i in {1..1000}; do
    echo "Line $i with emoji 🚀 and text"
done > "$large_dir/large.txt"
output=$("$BINARY" "$large_dir" 2>&1)
if echo "$output" | grep -q "🚀" && echo "$output" | grep -q "large.txt"; then
    echo "✓ Correctly handles large files"
else
    echo "FAIL: Should handle large files correctly"
    echo "Output: $output"
    exit 1
fi
rm -rf "$large_dir"

# Test 7: File with Unicode characters that are not emojis
echo "Test 7: Unicode non-emoji characters"
unicode_dir="/tmp/emoji_test_unicode_$$"
mkdir -p "$unicode_dir"
echo "Café résumé naïve 中文 العربية русский" > "$unicode_dir/unicode.txt"
original_content=$(cat "$unicode_dir/unicode.txt")
output=$("$BINARY" --no-dry-run "$unicode_dir" 2>&1)
new_content=$(cat "$unicode_dir/unicode.txt")
if [ "$original_content" = "$new_content" ]; then
    echo "✓ Correctly preserves non-emoji Unicode characters"
else
    echo "FAIL: Non-emoji Unicode characters were modified"
    echo "Original: $original_content"
    echo "New: $new_content"
    exit 1
fi
rm -rf "$unicode_dir"

# Test 8: Mixed emoji and Unicode
echo "Test 8: Mixed emoji and Unicode"
mixed_unicode_dir="/tmp/emoji_test_mixed_unicode_$$"
mkdir -p "$mixed_unicode_dir"
echo "Café 😊 résumé 🚀 naïve" > "$mixed_unicode_dir/mixed.txt"
original_content=$(cat "$mixed_unicode_dir/mixed.txt")
output=$("$BINARY" --no-dry-run "$mixed_unicode_dir" 2>&1)
new_content=$(cat "$mixed_unicode_dir/mixed.txt")
if echo "$new_content" | grep -q "Café.*résumé.*naïve" && ! echo "$new_content" | grep -q "😊\|🚀"; then
    echo "✓ Correctly removes emojis while preserving other Unicode"
else
    echo "FAIL: Should remove emojis but preserve other Unicode characters"
    echo "Original: $original_content"
    echo "New: $new_content"
    exit 1
fi
rm -rf "$mixed_unicode_dir"

# Test 9: Help flag
echo "Test 9: Help flag"
help_output=$("$BINARY" --help 2>&1)
if echo "$help_output" | grep -q "Usage:" && echo "$help_output" | grep -q "no-dry-run"; then
    echo "✓ Help flag works correctly"
else
    echo "FAIL: Help output should contain usage and no-dry-run information"
    echo "Output: $help_output"
    exit 1
fi

# Test 10: Invalid flag
echo "Test 10: Invalid flag"
invalid_output=$("$BINARY" --invalid-flag 2>&1 || true)
if echo "$invalid_output" | grep -q "unknown flag\|Error"; then
    echo "✓ Correctly handles invalid flags"
else
    echo "FAIL: Should report error for invalid flags"
    echo "Output: $invalid_output"
    exit 1
fi

echo "PASS: All edge case tests passed"
echo "✓ Non-existent directory handling"
echo "✓ Empty directory handling"
echo "✓ Binary file skipping"
echo "✓ Clean file preservation"
echo "✓ Emoji-only file handling"
echo "✓ Large file processing"
echo "✓ Unicode character preservation"
echo "✓ Mixed emoji/Unicode handling"
echo "✓ Help flag functionality"
echo "✓ Invalid flag handling"
echo