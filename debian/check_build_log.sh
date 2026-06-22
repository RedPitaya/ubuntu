#!/bin/bash

# Build log analyzer script
# Searches for errors and warnings in build log and outputs results to screen and file

# Define ROOT_DIR (current directory if not set)
ROOT_DIR="${ROOT_DIR:-.}"

# File paths
BUILDLOG="${ROOT_DIR}/buildlog.txt"
OUTPUT_FILE="${ROOT_DIR}/buildlog_ew.txt"

# Color codes for terminal output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if build log file exists
if [ ! -f "$BUILDLOG" ]; then
    echo "Error: File $BUILDLOG not found!"
    exit 1
fi

echo "Analyzing file: $BUILDLOG"
echo "Results will be saved to: $OUTPUT_FILE"
echo "========================================"

# Clear output file and add header
echo "BUILD LOG ANALYSIS: $BUILDLOG" > "$OUTPUT_FILE"
echo "Analysis date: $(date)" >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Function to print colored output to screen and plain text to file
print_result() {
    echo -e "$1"
    # Remove color codes for file output
    echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g' >> "$OUTPUT_FILE"
}

# Initialize counters
ERROR_COUNT=0
WARNING_COUNT=0

# Search for errors with line numbers
echo "=== ERRORS ==="
print_result "${RED}=== ERRORS ===${NC}"

# Error patterns to match
ERROR_PATTERNS="error:|fatal:|Error:|FATAL:|FAILURE|FAILED|undefined reference|No such file|cannot find|cannot stat|not found|compilation terminated|No space left"

# Find error lines with line numbers
while IFS= read -r line; do
    if echo "$line" | grep -qiE "$ERROR_PATTERNS"; then
        # Extract line number if grep -n format, or count manually
        LINE_NUM=$(grep -nF "$line" "$BUILDLOG" | head -1 | cut -d: -f1)
        ERROR_COUNT=$((ERROR_COUNT + 1))
        print_result "${RED}[ERROR] Line ${LINE_NUM}: $line${NC}"
    fi
done < <(grep -iE "$ERROR_PATTERNS" "$BUILDLOG")

if [ $ERROR_COUNT -eq 0 ]; then
    print_result "${GREEN}No errors found${NC}"
fi

echo ""
print_result ""

# Search for warnings with line numbers
echo "=== WARNINGS ==="
print_result "${YELLOW}=== WARNINGS ===${NC}"

# Warning patterns to match
WARNING_PATTERNS="warning:|Warning:|WARNING:|note:|deprecated|unused|overflow|implicit|falling back"

# Find warning lines (excluding lines already matched as errors)
while IFS= read -r line; do
    if echo "$line" | grep -qiE "$WARNING_PATTERNS" && ! echo "$line" | grep -qiE "error:|fatal:|Error:|FATAL:"; then
        LINE_NUM=$(grep -nF "$line" "$BUILDLOG" | head -1 | cut -d: -f1)
        WARNING_COUNT=$((WARNING_COUNT + 1))
        print_result "${YELLOW}[WARNING] Line ${LINE_NUM}: $line${NC}"
    fi
done < <(grep -iE "$WARNING_PATTERNS" "$BUILDLOG" | grep -ivE "error:|fatal:|Error:|FATAL:")

if [ $WARNING_COUNT -eq 0 ]; then
    print_result "${GREEN}No warnings found${NC}"
fi

echo ""
print_result ""

# Summary statistics
echo "========================================"
print_result "${CYAN}=== SUMMARY ===${NC}"
print_result "Errors: ${RED}$ERROR_COUNT${NC}"
print_result "Warnings: ${YELLOW}$WARNING_COUNT${NC}"
print_result "========================================"

# Save statistics to output file
echo "" >> "$OUTPUT_FILE"
echo "STATISTICS:" >> "$OUTPUT_FILE"
echo "Errors: $ERROR_COUNT" >> "$OUTPUT_FILE"
echo "Warnings: $WARNING_COUNT" >> "$OUTPUT_FILE"
echo "Analysis date: $(date)" >> "$OUTPUT_FILE"

# Return exit code based on errors found
if [ $ERROR_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi