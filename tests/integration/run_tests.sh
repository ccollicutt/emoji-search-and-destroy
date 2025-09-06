#!/bin/bash

# Simple table-based test runner for emoji-search-and-destroy

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$PROJECT_DIR/bin/emoji-sad"

# Parse arguments
LOG_FILE=""
VERBOSE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--log FILE] [--verbose]"
            exit 1
            ;;
    esac
done

# Setup logging
if [ -n "$LOG_FILE" ]; then
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1
    echo "==================== Test Run: $(date) ====================" 
fi

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    echo "Please build the project first: make build"
    exit 1
fi

# Test configuration
TESTS=(
    "test_dry_run.sh"
    "test_emoji_removal.sh"
    "test_edge_cases.sh"
    "test_default_behavior.sh"
    "test_special_files.sh"
    "test_list_and_stdin.sh"
    "test_version.sh"
    "test_exclude_flag.sh"
    "test_json_output.sh"
    "test_quiet_mode.sh"
    "test_allow_file.sh"
)

# Test descriptions
declare -A TEST_DESCRIPTIONS=(
    ["test_dry_run.sh"]="Dry-run functionality"
    ["test_emoji_removal.sh"]="Emoji removal"
    ["test_edge_cases.sh"]="Edge cases"
    ["test_default_behavior.sh"]="Default behavior"
    ["test_special_files.sh"]="Special files"
    ["test_list_and_stdin.sh"]="List & stdin"
    ["test_version.sh"]="Version info"
    ["test_exclude_flag.sh"]="Exclude functionality"
    ["test_json_output.sh"]="JSON output"
    ["test_quiet_mode.sh"]="Quiet mode"
    ["test_allow_file.sh"]="Allow file"
)

PASSED=0
FAILED=0
FAILED_TESTS=()

# Print header
echo ""
printf "${CYAN}%-30s %-15s %-10s${NC}\n" "TEST" "STATUS" "TIME"
printf "${CYAN}%-30s %-15s %-10s${NC}\n" "$(printf '%.0s-' {1..30})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..10})"

# Run each test
for test in "${TESTS[@]}"; do
    test_path="$SCRIPT_DIR/$test"
    
    if [ ! -f "$test_path" ]; then
        printf "%-30s ${RED}%-15s${NC} %-10s\n" "${TEST_DESCRIPTIONS[$test]}" "NOT FOUND" "N/A"
        FAILED=$((FAILED + 1))
        FAILED_TESTS+=("$test")
        continue
    fi
    
    # Run test and capture time
    START_TIME=$(date +%s)
    
    if [ "$VERBOSE" = true ]; then
        echo ""
        echo -e "${YELLOW}Running $test...${NC}"
        if bash "$test_path"; then
            STATUS="${GREEN}✓ PASS${NC}"
            STATUS_RAW="✓ PASS"
            PASSED=$((PASSED + 1))
        else
            STATUS="${RED}✗ FAIL${NC}"
            STATUS_RAW="✗ FAIL"
            FAILED=$((FAILED + 1))
            FAILED_TESTS+=("$test")
        fi
    else
        if bash "$test_path" >/dev/null 2>&1; then
            STATUS="${GREEN}✓ PASS${NC}"
            STATUS_RAW="✓ PASS"
            PASSED=$((PASSED + 1))
        else
            STATUS="${RED}✗ FAIL${NC}"
            STATUS_RAW="✗ FAIL"
            FAILED=$((FAILED + 1))
            FAILED_TESTS+=("$test")
        fi
    fi
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    printf "%-30s %-15b %-10s\n" "${TEST_DESCRIPTIONS[$test]}" "$STATUS" "${DURATION}s"
done

# Summary
echo ""
printf "${CYAN}%-30s %-15s %-10s${NC}\n" "$(printf '%.0s-' {1..30})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..10})"
printf "${BLUE}%-30s${NC} " "TOTAL"
if [ $FAILED -eq 0 ]; then
    printf "${GREEN}%d passed, %d failed${NC}\n" "$PASSED" "$FAILED"
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    printf "${YELLOW}%d passed, ${RED}%d failed${NC}\n" "$PASSED" "$FAILED"
    echo ""
    echo -e "${RED}Failed tests:${NC}"
    for failed_test in "${FAILED_TESTS[@]}"; do
        echo -e "  ${RED}- $failed_test${NC}"
    done
    exit 1
fi